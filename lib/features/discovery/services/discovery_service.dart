import 'dart:async';

import 'package:earth_nova/core/cells/cell_service.dart';
import 'package:flutter/foundation.dart';
import 'package:earth_nova/features/world/services/event_resolver.dart';
import 'package:earth_nova/core/fog/fog_event.dart';
import 'package:earth_nova/core/fog/fog_state_resolver.dart';
import 'package:earth_nova/core/models/cell_event.dart';
import 'package:earth_nova/core/models/cell_properties.dart';
import 'package:earth_nova/core/models/climate.dart';
import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/fog_state.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/models/iucn_status.dart';
import 'package:earth_nova/core/models/item_definition.dart';
import 'package:earth_nova/core/services/daily_seed_service.dart';
import 'package:earth_nova/core/species/continent_resolver.dart';
import 'package:earth_nova/core/species/species_service.dart';
import 'package:earth_nova/features/world/services/biome_service.dart';
import 'package:earth_nova/core/models/discovery_event.dart';
import 'package:earth_nova/features/calendar/services/season_service.dart';
import 'package:earth_nova/shared/constants.dart';

/// Listens to fog events and emits [DiscoveryEvent]s when a player enters a
/// new cell (FogState.present).
///
/// Plain Dart class (not a widget). Constructor-injected dependencies keep
/// this fully testable without Riverpod.
///
/// ## Lifecycle
/// 1. Create with a [FogStateResolver], a [SpeciesService], a
///    [HabitatService], and a [CellService].
/// 2. Subscribe to [onDiscovery] in the UI layer.
/// 3. Call [dispose] when the screen is torn down.
///
/// ## Biome detection
/// When a new cell is entered, [DiscoveryService] resolves the cell centre via
/// [CellService.getCellCenter], then queries [HabitatService.classifyLocation]
/// to obtain the full set of habitats present within 5 km. Species are drawn
/// from the union of all matching habitat pools.
///
/// ## Collection tracking
/// An internal `Set` of collected species IDs determines whether a discovered
/// species is new ([DiscoveryEvent.isNew] = true) or already in the player's
/// collection. Seed this set at construction time with
/// `initialCollectedIds` to restore persisted collection state.
class DiscoveryService {
  final FogStateResolver _fogResolver;
  final SpeciesService _speciesService;
  final HabitatService _habitatService;
  final CellService? _cellService;

  /// Optional lazy getter for [SpeciesService].
  ///
  /// When provided, the service reads the current [SpeciesService] at event
  /// time instead of using the instance captured at construction. This breaks
  /// the Riverpod rebuild chain: `discoveryServiceProvider` doesn't need to
  /// `ref.watch(speciesServiceProvider)`, so the entire GameCoordinator
  /// doesn't get torn down when species data finishes loading.
  ///
  /// When null, falls back to the constructor-injected [_speciesService].
  final SpeciesService Function()? _speciesServiceGetter;

  /// Optional lazy getter for [HabitatService].
  ///
  /// Same pattern as [_speciesServiceGetter]. When provided, the service reads
  /// the current [HabitatService] at event time instead of using the instance
  /// captured at construction. This breaks the rebuild chain caused by
  /// `biomeFeatureIndexProvider` (FutureProvider) transitioning from loading
  /// to data, which would otherwise tear down the entire GameCoordinator.
  ///
  /// When null, falls back to the constructor-injected [_habitatService].
  final HabitatService Function()? _habitatServiceGetter;

  /// Optional [SeasonService] for filtering out-of-season species.
  ///
  /// When non-null, species returned by [SpeciesService.getSpeciesForCell] are
  /// filtered through [SeasonService.filterBySeason] before events are emitted.
  /// When null, all species are available (backward-compatible default).
  final SeasonService? _seasonService;

  /// Optional [DailySeedService] for daily seed rotation.
  ///
  /// When non-null, encounters use the daily seed for rotation.
  /// When null, falls back to a static offline seed.
  final DailySeedService? _dailySeedService;

  /// Optional lookup for pre-resolved cell properties from GameCoordinator's
  /// cell properties cache.
  ///
  /// When set, uses cached habitats/continent/climate instead of re-resolving
  /// via HabitatService + ContinentResolver. Also enables cell event detection
  /// (Migration, Nesting Site) which replaces normal encounters.
  ///
  /// Wired by gameCoordinatorProvider after construction to avoid circular
  /// dependency: both discoveryServiceProvider and gameCoordinatorProvider
  /// exist in the same provider graph.
  CellProperties? Function(String cellId)? cellPropertiesLookup;

  /// Internal set of species IDs the player has already collected.
  ///
  /// Updated via [markCollected] as new species are added to the collection.
  final Set<String> _collectedSpeciesIds;

  /// Broadcast stream controller for discovery events.
  ///
  /// sync: true matches [FogStateResolver]'s stream semantics — events are
  /// delivered synchronously in the same call stack, which simplifies testing
  /// and keeps the render-loop integration predictable.
  final StreamController<DiscoveryEvent> _discoveryController =
      StreamController<DiscoveryEvent>.broadcast(sync: true);

  late final StreamSubscription<FogStateChangedEvent> _fogSubscription;

  /// Creates a [DiscoveryService].
  ///
  /// [habitatService] and [cellService] enable real biome detection. When
  /// [cellService] is null the service falls back to `{Habitat.plains}` (and
  /// still uses [habitatService] with lat=0/lon=0 as a worst-case fallback).
  ///
  /// [initialCollectedIds] seeds the already-collected set from persisted
  /// state. Defaults to empty (fresh game).
  ///
  /// [seasonService] enables seasonal filtering. When provided, only species
  /// available in the current season are emitted. When null (default), all
  /// species from [SpeciesService.getSpeciesForCell] are emitted unchanged.
  ///
  /// [speciesServiceGetter] enables lazy species service resolution. When
  /// provided, the getter is called at event time to obtain the current
  /// [SpeciesService]. This decouples the service from the Riverpod rebuild
  /// chain. When null, uses the [speciesService] passed at construction.
  DiscoveryService({
    required FogStateResolver fogResolver,
    required SpeciesService speciesService,
    HabitatService? habitatService,
    CellService? cellService,
    Set<String>? initialCollectedIds,
    SeasonService? seasonService,
    DailySeedService? dailySeedService,
    SpeciesService Function()? speciesServiceGetter,
    HabitatService Function()? habitatServiceGetter,
  })  : _fogResolver = fogResolver,
        _speciesService = speciesService,
        _habitatService = habitatService ?? HabitatService(),
        _cellService = cellService,
        _seasonService = seasonService,
        _dailySeedService = dailySeedService,
        _speciesServiceGetter = speciesServiceGetter,
        _habitatServiceGetter = habitatServiceGetter,
        _collectedSpeciesIds =
            Set.from(initialCollectedIds ?? const <String>{}) {
    _fogSubscription =
        _fogResolver.onVisitedCellAdded.listen(_onFogStateChanged);
  }

  /// Stream of discovery events — one per species found in a new cell.
  ///
  /// Only emits for [FogState.present] state transitions (new cell entries).
  Stream<DiscoveryEvent> get onDiscovery => _discoveryController.stream;

  /// Records [speciesId] as collected so future discoveries mark it correctly.
  ///
  /// Call this after the UI confirms a discovery, keeping the internal set
  /// in sync with the collection provider.
  void markCollected(String speciesId) {
    _collectedSpeciesIds.add(speciesId);
  }

  /// Cancels the fog event subscription and closes the discovery stream.
  void dispose() {
    _fogSubscription.cancel();
    _discoveryController.close();
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  void _onFogStateChanged(FogStateChangedEvent event) {
    debugPrint(
        '[DISCOVERY] fog_event cell=${event.cellId} state=${event.newState.name}');
    // Only react to a player entering a new cell for the first time.
    if (event.newState != FogState.present) return;

    // Stale seed guard — pause discoveries when seed is expired and came
    // from the server (offline fallback seeds never expire).
    final seedService = _dailySeedService;
    if (seedService != null && seedService.isDiscoveryPaused) {
      debugPrint('[SEED] discovery_paused stale_seed');
      return; // Seed >24h stale — skip discoveries until refreshed.
    }

    // Get the daily seed for encounter determinism.
    final dailySeed =
        seedService?.currentSeed?.seed ?? kDailySeedOfflineFallback;

    // Try to use pre-resolved cell properties from GameCoordinator's cache.
    // This provides habitats/continent/climate from the geo-resolution pipeline
    // and enables cell event detection (Migration, Nesting Site).
    final cellProps = cellPropertiesLookup?.call(event.cellId);

    // Resolve cell centre and biomes (fallback when no cached properties).
    final cellService = _cellService;
    final double lat;
    final double lon;
    if (cellService != null) {
      final center = cellService.getCellCenter(event.cellId);
      lat = center.lat;
      lon = center.lon;
    } else {
      lat = 0.0;
      lon = 0.0;
    }

    final Set<Habitat> habitats;
    final Continent continent;
    final Climate climate;
    if (cellProps != null) {
      habitats = cellProps.habitats;
      continent = cellProps.continent;
      climate = cellProps.climate;
    } else {
      // Fallback: resolve manually (pre-cell-properties behavior).
      final habitatService = _habitatServiceGetter?.call() ?? _habitatService;
      habitats = habitatService.classifyLocation(lat, lon);
      continent = ContinentResolver.resolve(lat, lon);
      climate = Climate.fromLatitude(lat);
    }

    // Use lazy getter when available (breaks Riverpod rebuild chain),
    // fall back to constructor-injected instance.
    final speciesService = _speciesServiceGetter?.call() ?? _speciesService;

    // Check for a cell event (Migration, Nesting Site). Events REPLACE
    // base encounters — they're not additive.
    final cellEvent = EventResolver.resolve(dailySeed, event.cellId);
    CellEventType? eventType;
    List<FaunaDefinition> species;

    final rollSw = Stopwatch()..start();

    if (cellEvent != null) {
      eventType = cellEvent.type;
      switch (cellEvent.type) {
        case CellEventType.migration:
          species = speciesService.getSpeciesForMigration(
            cellId: event.cellId,
            dailySeed: dailySeed,
            habitats: habitats,
            nativeContinent: continent,
            nativeClimate: climate,
          );
        case CellEventType.nestingSite:
          species = speciesService.getSpeciesForNestingSite(
            cellId: event.cellId,
            dailySeed: dailySeed,
            habitats: habitats,
            continent: continent,
          );
      }

      // If event-specific pool is empty, fall back to normal encounters.
      if (species.isEmpty) {
        eventType = null;
        species = speciesService.getSpeciesForCell(
          cellId: event.cellId,
          dailySeed: dailySeed,
          habitats: habitats,
          continent: continent,
        );
      }
    } else {
      // Normal encounter (no event).
      species = speciesService.getSpeciesForCell(
        cellId: event.cellId,
        dailySeed: dailySeed,
        habitats: habitats,
        continent: continent,
      );
    }

    rollSw.stop();
    debugPrint(
        '[DISCOVERY] species_rolled cell=${event.cellId} count=${species.length} habitats=${habitats.map((h) => h.name).join(",")} continent=${continent.name} event=${eventType?.name ?? "none"} duration=${rollSw.elapsedMilliseconds}ms');

    // Filter by current season when a SeasonService is wired in.
    // Capture in a local variable to enable null promotion (field promotion
    // is not available in Dart <3.2, and is unsafe for mutable fields).
    final seasonService = _seasonService;
    if (seasonService != null) {
      final beforeCount = species.length;
      final currentSeason = seasonService.getCurrentSeason();
      species = seasonService.filterBySeason(species, currentSeason);
      if (species.length != beforeCount) {
        debugPrint(
            '[DISCOVERY] season_filtered before=$beforeCount after=${species.length} season=${currentSeason.name}');
      }
    }

    for (final s in species) {
      final isNew = !_collectedSpeciesIds.contains(s.id);
      // Guard: skip extinct species the player already owns. EX species are
      // extremely rare by design (weight=1) — allowing duplicates lets nesting
      // sites flood the inventory with copies of the same extinct animal.
      if (!isNew && s.rarity == IucnStatus.extinct) continue;
      debugPrint(
          '[DISCOVERY] emitted cell=${event.cellId} species=${s.id} is_new=$isNew');
      _discoveryController.add(
        DiscoveryEvent(
          item: s,
          cellId: event.cellId,
          isNew: isNew,
          timestamp: event.timestamp,
          dailySeed: dailySeed,
          cellEventType: eventType,
        ),
      );
    }
  }
}
