import 'dart:async';

import 'package:geobase/geobase.dart';
import 'package:uuid/uuid.dart';

import 'package:earth_nova/domain/cells/cell_service.dart';
import 'package:earth_nova/domain/fog/fog_resolver.dart';
import 'package:earth_nova/domain/items/stats_service.dart';
import 'package:earth_nova/domain/seed/daily_seed.dart';
import 'package:earth_nova/domain/species/encounter_roller.dart';
import 'package:earth_nova/domain/world/cell_property_resolver.dart';
import 'package:earth_nova/domain/world/event_resolver.dart';
import 'package:earth_nova/engine/engine_input.dart';
import 'package:earth_nova/engine/game_event.dart';
import 'package:earth_nova/models/affix.dart';
import 'package:earth_nova/models/animal_size.dart';
import 'package:earth_nova/models/cell_event.dart';
import 'package:earth_nova/models/cell_properties.dart';
import 'package:earth_nova/models/item_definition.dart';
import 'package:earth_nova/models/item_instance.dart';
import 'package:earth_nova/shared/constants.dart';

/// Resolves location hierarchy for a cell ID.
/// Returns null if hierarchy data is not available.
typedef LocationResolver = ({
  String? district,
  String? city,
  String? state,
  String? country,
  String? countryCode,
})?
    Function(String cellId);

/// Central game logic engine. Pure Dart — no Flutter, no Riverpod.
///
/// Merges the responsibilities of the old GameCoordinator and DiscoveryService
/// into a single event-emitting core. All game state changes become
/// [GameEvent]s on the [events] stream. Downstream consumers (persistence,
/// UI, analytics) subscribe and react independently.
///
/// ## Dual-Position Model
///
/// | Field              | Source                     | Used for                        |
/// |--------------------|----------------------------|---------------------------------|
/// | [rawGpsPosition]   | GPS stream (1 Hz)          | Rubber-band target, accuracy UI |
/// | [playerPosition]   | Rubber-band (60 fps)       | All game logic — fog, discovery |
///
/// ## Data Flow
///
/// ```
/// GPS (1 Hz) → start(gpsStream) → _onRawGps → broadcasts rawGpsPosition
///                                                        ↓
/// MapScreen reads rawGpsPosition → RubberBand interpolates (60 fps)
///                                                        ↓
/// RubberBand → send(PositionUpdate) → throttled to ~10 Hz → game logic
/// ```
///
/// ## Dependency Injection
///
/// Hard dependencies ([fogResolver], [cellService]) are required at
/// construction. Optional services ([speciesServiceGetter],
/// [dailySeedService], [statsService], [cellPropertyResolver]) are
/// wired after construction by the provider layer, allowing lazy
/// initialization as data sources become ready.
///
/// ## Thread Safety
///
/// All methods are called on the main thread. Do not call from isolates.
class GameEngine {
  // ---------------------------------------------------------------------------
  // Required dependencies (injected at construction)
  // ---------------------------------------------------------------------------

  final FogStateResolver _fogResolver;
  final CellService _cellService;

  // ---------------------------------------------------------------------------
  // Optional lazy-wired dependencies (set after construction)
  // ---------------------------------------------------------------------------

  /// Returns the active [SpeciesService]. Called lazily when a discovery is
  /// attempted, so the species cache can load after the engine starts.
  SpeciesService Function()? speciesServiceGetter;

  /// Provides the current daily seed for deterministic encounter rolling.
  DailySeedService? dailySeedService;

  /// Rolls per-instance stat affixes from species base stats.
  StatsService? statsService;

  /// Resolves geo-derived cell properties (habitat, climate, continent).
  CellPropertyResolver? cellPropertyResolver;

  /// Optional location resolver — set by the provider layer after hierarchy data loads.
  LocationResolver? locationResolver;

  /// Optional lookup for AI-enriched base stats + size by definition ID.
  ///
  /// When set, stat affixes are derived from real-world biology rather than
  /// hash values. Returns null when no enrichment is cached for that species.
  ({int speed, int brawn, int wit, AnimalSize? size})? Function(
      String definitionId)? enrichedStatsLookup;

  // ---------------------------------------------------------------------------
  // GPS error notification callback
  // ---------------------------------------------------------------------------

  /// Called when GPS accuracy changes above/below [kGpsAccuracyThreshold].
  /// Only fires for real GPS (not simulation). `null` error = GPS is fine.
  void Function(String? error, double accuracy)? onGpsErrorChanged;

  // ---------------------------------------------------------------------------
  // Dual-position state
  // ---------------------------------------------------------------------------

  Geographic? _rawGpsPosition;
  double _rawGpsAccuracy = 0.0;
  Geographic? _playerPosition;

  /// Timestamp of the most recent [send(PositionUpdate)] call.
  DateTime? _lastPositionUpdateTime;

  /// Raw GPS position from the location service (1 Hz).
  Geographic? get rawGpsPosition => _rawGpsPosition;

  /// GPS accuracy in metres from the most recent raw fix.
  double get rawGpsAccuracy => _rawGpsAccuracy;

  /// Interpolated player position from rubber-band (60 fps).
  /// This is the source of truth for fog, discovery, and cell resolution.
  Geographic? get playerPosition => _playerPosition;

  /// Timestamp of the most recent position update from the rubber-band.
  DateTime? get lastPositionUpdateTime => _lastPositionUpdateTime;

  // ---------------------------------------------------------------------------
  // Game tick throttle
  // ---------------------------------------------------------------------------

  /// Frame counter for throttling game logic in [send(PositionUpdate)].
  /// Game logic runs at ~10 Hz (every 6th frame at 60 fps).
  int _frameCount = 0;

  /// Throttle interval: run game logic every Nth display frame.
  static const int _kGameLogicInterval = 6;

  // ---------------------------------------------------------------------------
  // Cell tracking
  // ---------------------------------------------------------------------------

  /// The cell ID the player marker is currently in.
  String? _currentCellId;

  /// Cells the player has visited (populated at hydration + during play).
  final Set<String> _visitedCellIds = {};

  // ---------------------------------------------------------------------------
  // Cell properties cache
  // ---------------------------------------------------------------------------

  /// In-memory cache of resolved cell properties, keyed by cell ID.
  /// Populated ahead-of-time for current cell + ring-1 neighbors.
  final Map<String, CellProperties> _cellPropertiesCache = {};

  /// Read-only view of the cell properties cache.
  Map<String, CellProperties> get cellPropertiesCache =>
      Map.unmodifiable(_cellPropertiesCache);

  // ---------------------------------------------------------------------------
  // Exploration guard
  // ---------------------------------------------------------------------------

  bool _explorationDisabled = false;

  /// Whether exploration is currently blocked because the rubber-band marker
  /// has drifted beyond the player's real GPS cell (anti-teleport guard).
  bool get explorationDisabled => _explorationDisabled;

  // ---------------------------------------------------------------------------
  // Auth state
  // ---------------------------------------------------------------------------

  /// Authenticated user ID. Stamped onto all emitted events.
  String? currentUserId;

  // ---------------------------------------------------------------------------
  // Whether GPS source is real hardware (vs simulation)
  // ---------------------------------------------------------------------------

  /// When true, GPS accuracy is checked against [kGpsAccuracyThreshold]
  /// and a `gps_error_changed` event is emitted when it changes.
  final bool isRealGps;

  // ---------------------------------------------------------------------------
  // Output — event stream
  // ---------------------------------------------------------------------------

  /// Session identifier — generated once per [start] call, stamped onto
  /// every emitted event for correlation.
  late String _sessionId;

  final StreamController<GameEvent> _eventController =
      StreamController<GameEvent>.broadcast(sync: true);

  /// Single broadcast stream of all game events.
  ///
  /// Multiple consumers can listen concurrently. New listeners do NOT receive
  /// past events.
  Stream<GameEvent> get events => _eventController.stream;

  // ---------------------------------------------------------------------------
  // Raw GPS broadcast (for rubber-band controller)
  // ---------------------------------------------------------------------------

  final StreamController<({Geographic position, double accuracy})>
      _rawGpsController =
      StreamController<({Geographic position, double accuracy})>.broadcast(
          sync: true);

  /// Raw GPS position updates (1 Hz). MapScreen subscribes to feed the
  /// rubber-band interpolation controller.
  Stream<({Geographic position, double accuracy})> get onRawGpsUpdate =>
      _rawGpsController.stream;

  // ---------------------------------------------------------------------------
  // Lifecycle state
  // ---------------------------------------------------------------------------

  bool _isRunning = false;

  StreamSubscription<dynamic>? _gpsSubscription;
  StreamSubscription<dynamic>? _fogCellSubscription;

  static const _uuid = Uuid();

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------

  GameEngine({
    required FogStateResolver fogResolver,
    required CellService cellService,
    this.isRealGps = false,
  })  : _fogResolver = fogResolver,
        _cellService = cellService;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Starts the game loop.
  ///
  /// [gpsStream] — raw GPS position updates from the location service.
  /// When provided, the engine subscribes and re-emits on [onRawGpsUpdate].
  ///
  /// Call [loadVisitedCells] and [loadCellProperties] before [start] so
  /// discovery history is available from the first tick.
  void start({
    Stream<({Geographic position, double accuracy})>? gpsStream,
  }) {
    if (_isRunning) return;
    _isRunning = true;
    _sessionId = _uuid.v4();

    // Subscribe to raw GPS updates.
    if (gpsStream != null) {
      _gpsSubscription = gpsStream.listen(_onRawGps);
    }

    // Subscribe to fog resolver cell-visit events so we can emit
    // cell_visited and fog_changed GameEvents.
    _fogCellSubscription = _fogResolver.onVisitedCellAdded.listen((fogEvent) {
      _emit(GameEvent.cellVisited(
        sessionId: _sessionId,
        userId: currentUserId,
        cellId: fogEvent.cellId,
      ));
      _emit(GameEvent.fogChanged(
        sessionId: _sessionId,
        userId: currentUserId,
        cellId: fogEvent.cellId,
        oldState: fogEvent.oldState.name,
        newState: fogEvent.newState.name,
      ));
    });
  }

  /// Stops all subscriptions. The engine can be restarted with [start].
  void stop() {
    _gpsSubscription?.cancel();
    _gpsSubscription = null;
    _fogCellSubscription?.cancel();
    _fogCellSubscription = null;
    _frameCount = 0;
    _isRunning = false;
  }

  /// Permanently releases all resources. The engine is unusable after this.
  void dispose() {
    stop();
    _rawGpsController.close();
    _eventController.close();
  }

  /// Whether the game loop is currently running.
  bool get isRunning => _isRunning;

  // ---------------------------------------------------------------------------
  // Hydration (call before start)
  // ---------------------------------------------------------------------------

  /// Pre-populate visited cell history from persistence.
  ///
  /// Called once at startup. Forwards to [FogStateResolver] so fog
  /// state is correctly initialized before the first tick.
  void loadVisitedCells(Set<String> cells) {
    _visitedCellIds.addAll(cells);
    _fogResolver.loadVisitedCells(cells);
  }

  /// Pre-populate the cell properties cache from persistence.
  ///
  /// Called once at startup so the first discovery attempt has
  /// cell context without waiting for the resolver.
  void loadCellProperties(Map<String, CellProperties> props) {
    _cellPropertiesCache.addAll(props);
  }

  /// Update the locationId on a cached cell's properties.
  ///
  /// Called by the provider layer when Nominatim enrichment resolves
  /// a locationId for a previously-cached cell.
  void updateCellPropertyLocationId(String cellId, String locationId) {
    final existing = _cellPropertiesCache[cellId];
    if (existing != null) {
      _cellPropertiesCache[cellId] = existing.copyWith(locationId: locationId);
    }
  }

  // ---------------------------------------------------------------------------
  // Input
  // ---------------------------------------------------------------------------

  /// Route an [EngineInput] command to the appropriate handler.
  ///
  /// Called by the provider layer and the rubber-band controller.
  /// All processing is synchronous on the calling thread.
  void send(EngineInput input) {
    try {
      switch (input) {
        case PositionUpdate(:final lat, :final lon, :final accuracy):
          _onPositionUpdate(lat, lon, accuracy);

        case AuthChanged(:final userId):
          currentUserId = userId;

        case CellTapped():
          break; // future: cell inspection UI

        case AppLifecycleChanged(isActive: final active):
          // Forward to future use (flush queues, pause animations).
          // Currently a no-op — LogFlushService handles persistence flush.
          if (!active) {
          } else {}
      }
    } catch (e, stack) {
      _emitError(e.toString(),
          context: 'send(${input.runtimeType})', stackTrace: stack);
    }
  }

  // ---------------------------------------------------------------------------
  // Private — raw GPS handling
  // ---------------------------------------------------------------------------

  void _onRawGps(({Geographic position, double accuracy}) update) {
    _rawGpsPosition = update.position;
    _rawGpsAccuracy = update.accuracy;

    // Broadcast to MapScreen for rubber-band feeding (sync stream → immediate).
    if (!_rawGpsController.isClosed) {
      _rawGpsController.add(update);
    }

    // Accuracy guard — only for real hardware GPS.
    if (isRealGps) {
      final isLowAccuracy = update.accuracy > kGpsAccuracyThreshold;
      onGpsErrorChanged?.call(
          isLowAccuracy ? 'low_accuracy' : null, update.accuracy);

      _emit(GameEvent.gpsErrorChanged(
        sessionId: _sessionId,
        userId: currentUserId,
        error: isLowAccuracy ? 'low_accuracy' : 'none',
        accuracy: update.accuracy,
      ));
    }
  }

  // ---------------------------------------------------------------------------
  // Private — position update handling (rubber-band path, ~60 fps)
  // ---------------------------------------------------------------------------

  void _onPositionUpdate(double lat, double lon, double accuracy) {
    _lastPositionUpdateTime = DateTime.now();
    _playerPosition = Geographic(lat: lat, lon: lon);
    _rawGpsAccuracy = accuracy;

    // Throttle game logic to ~10 Hz. First call always runs.
    _frameCount++;
    if (_frameCount == 1 || _frameCount % _kGameLogicInterval == 0) {
      _processGameLogic(lat, lon);
    }
  }

  // ---------------------------------------------------------------------------
  // Private — game logic tick (~10 Hz)
  // ---------------------------------------------------------------------------

  void _processGameLogic(double lat, double lon) {
    // Exploration guard — compare rubber-band marker cell to raw GPS cell.
    // Before the first GPS fix, allow exploration (rawGps is null).
    final rawGps = _rawGpsPosition;
    if (rawGps != null) {
      final markerCellId = _cellService.getCellId(lat, lon);
      final gpsCellId = _cellService.getCellId(rawGps.lat, rawGps.lon);

      // Allow same cell OR any ring-1 neighbor (handles rubber-band lag
      // at cell boundaries).
      final isNearby = markerCellId == gpsCellId ||
          _cellService.getNeighborIds(gpsCellId).contains(markerCellId);

      if (!isNearby) {
        if (!_explorationDisabled) {
          _explorationDisabled = true;
          _emit(GameEvent.explorationDisabledChanged(
            sessionId: _sessionId,
            userId: currentUserId,
            disabled: true,
          ));
        }
        // Still update fog/position UI but skip discovery.
        _fogResolver.onLocationUpdate(lat, lon);
        return;
      }

      if (_explorationDisabled) {
        _explorationDisabled = false;
        _emit(GameEvent.explorationDisabledChanged(
          sessionId: _sessionId,
          userId: currentUserId,
          disabled: false,
        ));
      }
    }

    // 1. Update fog-of-war from player marker position.
    _fogResolver.onLocationUpdate(lat, lon);

    // 2. Resolve cell properties for current + ring-1 neighbors.
    _resolveCellProperties(lat, lon);

    // 3. Check if we entered a new cell — the core discovery trigger.
    final newCellId = _fogResolver.currentCellId;
    if (newCellId != null && newCellId != _currentCellId) {
      _checkNewCell(newCellId);
    }
  }

  // ---------------------------------------------------------------------------
  // Private — cell entry logic
  // ---------------------------------------------------------------------------

  /// Called when the player's cell changes to [newCellId].
  ///
  /// Only rolls encounters on cells that have NEVER been visited before.
  /// Revisiting a cell the player already explored produces no discovery.
  void _checkNewCell(String newCellId) {
    final wasUnvisited = !_visitedCellIds.contains(newCellId);
    _currentCellId = newCellId;

    if (wasUnvisited) {
      _visitedCellIds.add(newCellId);
      // Roll encounters — emits species_discovered events.
      _rollEncounters(newCellId);
    }
  }

  // ---------------------------------------------------------------------------
  // Private — species encounter rolling
  // ---------------------------------------------------------------------------

  /// Roll encounters for a freshly-visited cell and emit [GameEvent]s.
  ///
  /// Returns early (silently) if:
  /// - Cell properties are not yet cached for this cell
  /// - Daily seed service is not wired
  /// - The seed is stale (server seed > 24h old) — discovery pauses
  /// - SpeciesService is not yet loaded
  void _rollEncounters(String cellId) {
    // Require cell context for habitat/continent/climate filtering.
    final cellProps = _cellPropertiesCache[cellId];
    if (cellProps == null) return;

    // Require seed service — encounters need a daily seed.
    final seedSvc = dailySeedService;
    if (seedSvc == null) return;
    final seedState = seedSvc.currentSeed;
    if (seedState == null) return;

    // Stale server seed → pause discoveries until refreshed.
    if (seedState.isStale && seedState.isServerSeed) return;

    final speciesSvc = speciesServiceGetter?.call();
    if (speciesSvc == null) return;

    final dailySeed = seedState.seed;
    final habitats = cellProps.habitats;
    final continent = cellProps.continent;
    final climate = cellProps.climate;

    // Resolve any daily cell event (migration / nesting site).
    final cellEvent = EventResolver.resolve(dailySeed, cellId);

    // Roll species based on event type.
    List<FaunaDefinition> species;
    try {
      switch (cellEvent?.type) {
        case CellEventType.nestingSite:
          species = speciesSvc.getSpeciesForNestingSite(
            cellId: cellId,
            dailySeed: dailySeed,
            habitats: habitats,
            continent: continent,
          );
          // Fall back to normal roll if no rare species are available here.
          if (species.isEmpty) {
            species = speciesSvc.getSpeciesForCell(
              cellId: cellId,
              dailySeed: dailySeed,
              habitats: habitats,
              continent: continent,
            );
          }

        case CellEventType.migration:
          species = speciesSvc.getSpeciesForMigration(
            cellId: cellId,
            dailySeed: dailySeed,
            habitats: habitats,
            nativeContinent: continent,
            nativeClimate: climate,
          );
          // Fall back to normal roll if the migration pool is empty.
          if (species.isEmpty) {
            species = speciesSvc.getSpeciesForCell(
              cellId: cellId,
              dailySeed: dailySeed,
              habitats: habitats,
              continent: continent,
            );
          }

        case null:
          species = speciesSvc.getSpeciesForCell(
            cellId: cellId,
            dailySeed: dailySeed,
            habitats: habitats,
            continent: continent,
          );
      }
    } catch (e, stack) {
      _emitError(e.toString(),
          context: '_rollEncounters($cellId)', stackTrace: stack);
      return;
    }

    if (species.isEmpty) return;

    // Build and emit a discovery event for each rolled species.
    for (final definition in species) {
      try {
        _emitDiscovery(
          definition: definition,
          cellId: cellId,
          cellProps: cellProps,
          cellEvent: cellEvent,
          dailySeed: dailySeed,
        );
      } catch (e, stack) {
        _emitError(e.toString(),
            context: '_emitDiscovery(${definition.id})', stackTrace: stack);
      }
    }
  }

  /// Build an [ItemInstance] and emit a `species_discovered` [GameEvent].
  void _emitDiscovery({
    required FaunaDefinition definition,
    required String cellId,
    required CellProperties cellProps,
    required CellEvent? cellEvent,
    required String dailySeed,
  }) {
    final instanceId = _uuid.v4();
    final stats = _statsService;

    // Roll stat affix when StatsService is available.
    final affixes = <Affix>[];
    if (stats != null) {
      // Prefer AI-enriched base stats; fall back to hash-derived stats.
      final enriched = enrichedStatsLookup?.call(definition.id);
      final baseStats = enriched != null
          ? (
              speed: enriched.speed,
              brawn: enriched.brawn,
              wit: enriched.wit,
            )
          : null;

      final intrinsic = stats.rollIntrinsicAffix(
        scientificName: definition.scientificName,
        instanceSeed: instanceId,
        enrichedBaseStats: baseStats,
      );

      final size = enriched?.size != null
          ? AnimalSize.fromString(enriched!.size!.name)
          : null;

      if (size != null) {
        final weightGrams = stats.rollWeightGrams(
          size: size,
          instanceSeed: instanceId,
        );
        affixes.add(Affix(
          id: intrinsic.id,
          type: intrinsic.type,
          values: {
            ...intrinsic.values,
            kSizeAffixKey: size.name,
            kWeightAffixKey: weightGrams,
          },
        ));
      } else {
        affixes.add(intrinsic);
      }
    }

    final now = DateTime.now();

    // Resolve location hierarchy synchronously from pre-cached ancestry.
    final location = locationResolver?.call(cellId);

    final instance = ItemInstance(
      id: instanceId,
      definitionId: definition.id,
      displayName: definition.displayName,
      scientificName: definition.scientificName,
      category: definition.category,
      rarity: definition.rarity,
      habitats: definition.habitats,
      continents: definition.continents,
      taxonomicClass: definition.taxonomicClass,
      acquiredAt: now,
      acquiredInCellId: cellId,
      dailySeed: dailySeed,
      affixes: affixes,
      // Snapshot enrichment fields from definition (may be null until enriched)
      animalClassName: definition.animalClass?.name,
      foodPreferenceName: definition.foodPreference?.name,
      climateName: definition.climate?.name,
      brawn: definition.brawn,
      wit: definition.wit,
      speed: definition.speed,
      sizeName: definition.size,
      iconUrl: definition.iconUrl,
      artUrl: definition.artUrl,
      // Snapshot cell properties at discovery time
      cellHabitatName:
          cellProps.habitats.isNotEmpty ? cellProps.habitats.first.name : null,
      cellClimateName: cellProps.climate.name,
      cellContinentName: cellProps.continent.name,
      // Location hierarchy stamped at discovery time
      locationDistrict: location?.district,
      locationCity: location?.city,
      locationState: location?.state,
      locationCountry: location?.country,
      locationCountryCode: location?.countryCode,
    );

    _emit(GameEvent.speciesDiscovered(
      sessionId: _sessionId,
      userId: currentUserId,
      cellId: cellId,
      definitionId: definition.id,
      displayName: definition.displayName,
      category: definition.category.name,
      rarity: definition.rarity?.name,
      dailySeed: dailySeed,
      cellEventType: cellEvent?.type.name,
      instance: instance,
      hasEnrichment: affixes.isNotEmpty,
      affixCount: affixes.length,
    ));
  }

  // ---------------------------------------------------------------------------
  // Private — cell property resolution
  // ---------------------------------------------------------------------------

  /// Resolve geo-derived properties for the current cell and ring-1 neighbors.
  ///
  /// Skips cells already in the cache. For each newly resolved cell, emits
  /// a `cell_properties_resolved` [GameEvent] so the provider layer can
  /// persist and enqueue for Supabase sync.
  void _resolveCellProperties(double lat, double lon) {
    final resolver = cellPropertyResolver;
    if (resolver == null) return;

    final currentCellId = _cellService.getCellId(lat, lon);
    final neighbors = _cellService.getNeighborIds(currentCellId);
    final cellIds = [currentCellId, ...neighbors];

    for (final cellId in cellIds) {
      if (_cellPropertiesCache.containsKey(cellId)) continue;

      final center = _cellService.getCellCenter(cellId);
      final properties = resolver.resolve(
        cellId: cellId,
        lat: center.lat,
        lon: center.lon,
      );

      _cellPropertiesCache[cellId] = properties;

      _emit(GameEvent.cellPropertiesResolved(
        sessionId: _sessionId,
        userId: currentUserId,
        cellId: properties.cellId,
        habitats: properties.habitats.map((h) => h.name).toList(),
        climate: properties.climate.name,
        continent: properties.continent.name,
        locationId: properties.locationId,
      ));
    }
  }

  // ---------------------------------------------------------------------------
  // Private — emit helpers
  // ---------------------------------------------------------------------------

  void _emit(GameEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  void _emitError(
    String message, {
    String? context,
    StackTrace? stackTrace,
  }) {
    _emit(GameEvent.error(
      sessionId: _sessionId,
      userId: currentUserId,
      message: message,
      context: context,
      stackTrace: stackTrace?.toString().split('\n').take(10).join('\n'),
    ));
  }

  // ---------------------------------------------------------------------------
  // Private — StatsService null-safe accessor
  // ---------------------------------------------------------------------------

  StatsService? get _statsService => statsService;
}
