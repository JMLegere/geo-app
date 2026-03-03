import 'dart:async';

import 'package:fog_of_world/core/fog/fog_event.dart';
import 'package:fog_of_world/core/fog/fog_state_resolver.dart';
import 'package:fog_of_world/core/models/continent.dart';
import 'package:fog_of_world/core/models/fog_state.dart';
import 'package:fog_of_world/core/models/habitat.dart';
import 'package:fog_of_world/core/species/species_service.dart';
import 'package:fog_of_world/features/discovery/models/discovery_event.dart';
import 'package:fog_of_world/features/seasonal/services/season_service.dart';

/// Listens to fog events and emits [DiscoveryEvent]s when a player enters a
/// new cell (FogState.observed).
///
/// Plain Dart class (not a widget). Constructor-injected dependencies keep
/// this fully testable without Riverpod.
///
/// ## Lifecycle
/// 1. Create with a [FogStateResolver] and a [SpeciesService].
/// 2. Subscribe to [onDiscovery] in the UI layer.
/// 3. Call [dispose] when the screen is torn down.
///
/// ## Collection tracking
/// An internal `Set` of collected species IDs determines whether a discovered
/// species is new ([DiscoveryEvent.isNew] = true) or already in the player's
/// collection. Seed this set at construction time with
/// `initialCollectedIds` to restore persisted collection state.
class DiscoveryService {
  final FogStateResolver _fogResolver;
  final SpeciesService _speciesService;

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
  /// [initialCollectedIds] seeds the already-collected set from persisted
  /// state. Defaults to empty (fresh game).
  ///
  /// [seasonService] enables seasonal filtering. When provided, only species
  /// available in the current season are emitted. When null (default), all
  /// species from [SpeciesService.getSpeciesForCell] are emitted unchanged.
  ///
  /// Habitat and continent default to `Habitat.forest` and
  /// `Continent.northAmerica` — appropriate for SF Bay Area simulation.
  DiscoveryService({
    required FogStateResolver fogResolver,
    required SpeciesService speciesService,
    Set<String>? initialCollectedIds,
    SeasonService? seasonService,
  })  : _fogResolver = fogResolver,
        _speciesService = speciesService,
        _seasonService = seasonService,
        _collectedSpeciesIds = Set.from(initialCollectedIds ?? const <String>{}) {
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

    // SF Bay Area simulation defaults — T21 will wire real habitat/continent.
    var species = _speciesService.getSpeciesForCell(
      cellId: event.cellId,
      habitat: Habitat.forest,
      continent: Continent.northAmerica,
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
          species: s,
          cellId: event.cellId,
          isNew: isNew,
          timestamp: event.timestamp,
        ),
      );
    }
  }
}
