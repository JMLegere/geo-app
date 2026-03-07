import 'dart:async';

import 'package:fog_of_world/core/cells/cell_service.dart';
import 'package:fog_of_world/core/fog/fog_event.dart';
import 'package:fog_of_world/core/fog/fog_state_resolver.dart';
import 'package:fog_of_world/core/models/fog_state.dart';
import 'package:fog_of_world/core/species/continent_resolver.dart';
import 'package:fog_of_world/core/species/species_service.dart';
import 'package:fog_of_world/features/biome/services/biome_service.dart';
import 'package:fog_of_world/core/models/discovery_event.dart';
import 'package:fog_of_world/features/seasonal/services/season_service.dart';

/// Listens to fog events and emits [DiscoveryEvent]s when a player enters a
/// new cell (FogState.observed).
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

  /// Optional [SeasonService] for filtering out-of-season species.
  ///
  /// When non-null, species returned by [SpeciesService.getSpeciesForCell] are
  /// filtered through [SeasonService.filterBySeason] before events are emitted.
  /// When null, all species are available (backward-compatible default).
  final SeasonService? _seasonService;

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
  DiscoveryService({
    required FogStateResolver fogResolver,
    required SpeciesService speciesService,
    HabitatService? habitatService,
    CellService? cellService,
    Set<String>? initialCollectedIds,
    SeasonService? seasonService,
  })  : _fogResolver = fogResolver,
        _speciesService = speciesService,
        _habitatService = habitatService ?? HabitatService(),
        _cellService = cellService,
        _seasonService = seasonService,
        _collectedSpeciesIds =
            Set.from(initialCollectedIds ?? const <String>{}) {
    _fogSubscription =
        _fogResolver.onVisitedCellAdded.listen(_onFogStateChanged);
  }

  /// Stream of discovery events — one per species found in a new cell.
  ///
  /// Only emits for [FogState.observed] state transitions (new cell entries).
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
    // Only react to a player entering a new cell for the first time.
    if (event.newState != FogState.observed) return;

    // Resolve the cell centre and look up biomes.
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
    final habitats = _habitatService.classifyLocation(lat, lon);
    final continent = ContinentResolver.resolve(lat, lon);

    var species = _speciesService.getSpeciesForCell(
      cellId: event.cellId,
      habitats: habitats,
      continent: continent,
    );

    // Filter by current season when a SeasonService is wired in.
    // Capture in a local variable to enable null promotion (field promotion
    // is not available in Dart <3.2, and is unsafe for mutable fields).
    final seasonService = _seasonService;
    if (seasonService != null) {
      final currentSeason = seasonService.getCurrentSeason();
      species = seasonService.filterBySeason(species, currentSeason);
    }

    for (final s in species) {
      final isNew = !_collectedSpeciesIds.contains(s.id);
      _discoveryController.add(
        DiscoveryEvent(
          item: s,
          cellId: event.cellId,
          isNew: isNew,
          timestamp: event.timestamp,
        ),
      );
    }
  }
}
