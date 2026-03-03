import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fog_of_world/core/models/habitat.dart';
import 'package:fog_of_world/core/models/species.dart';
import 'package:fog_of_world/core/state/collection_provider.dart';
import 'package:fog_of_world/core/state/player_provider.dart';
import 'package:fog_of_world/features/discovery/providers/discovery_provider.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Immutable snapshot of the sanctuary view state.
class SanctuaryState {
  /// Collected species grouped by their primary habitat.
  final Map<Habitat, List<SpeciesRecord>> speciesByHabitat;

  /// Total number of species the player has collected.
  final int totalCollected;

  /// Total number of species available in the pool (all known species).
  final int totalInPool;

  /// Player's current daily visit streak (from [PlayerState]).
  final int currentStreak;

  const SanctuaryState({
    this.speciesByHabitat = const {},
    this.totalCollected = 0,
    this.totalInPool = 0,
    this.currentStreak = 0,
  });

  /// Completion fraction in the range [0.0, 1.0].
  ///
  /// Returns 0.0 when [totalInPool] is zero to avoid division by zero.
  double get healthPercentage =>
      totalInPool > 0 ? totalCollected / totalInPool : 0.0;

  SanctuaryState copyWith({
    Map<Habitat, List<SpeciesRecord>>? speciesByHabitat,
    int? totalCollected,
    int? totalInPool,
    int? currentStreak,
  }) {
    return SanctuaryState(
      speciesByHabitat: speciesByHabitat ?? this.speciesByHabitat,
      totalCollected: totalCollected ?? this.totalCollected,
      totalInPool: totalInPool ?? this.totalInPool,
      currentStreak: currentStreak ?? this.currentStreak,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class SanctuaryNotifier extends Notifier<SanctuaryState> {
  @override
  SanctuaryState build() {
    // Watch species service — rebuilds if the species pool ever changes.
    final speciesService = ref.watch(speciesServiceProvider);

    // Listen to collection changes to re-group species.
    ref.listen(collectionProvider, (_, next) {
      _updateFromCollection(next);
    });

    // Listen to player streak changes.
    ref.listen(playerProvider, (_, next) {
      state = state.copyWith(currentStreak: next.currentStreak);
    });

    // Read collection + player for initial state (listen handles ongoing).
    final collectionState = ref.read(collectionProvider);
    final playerState = ref.read(playerProvider);

    return _buildState(
      allSpecies: speciesService.all,
      collectedIds: collectionState.collectedSpeciesIds.toSet(),
      streak: playerState.currentStreak,
    );
  }

  void _updateFromCollection(CollectionState collectionState) {
    final speciesService = ref.read(speciesServiceProvider);
    final newState = _buildState(
      allSpecies: speciesService.all,
      collectedIds: collectionState.collectedSpeciesIds.toSet(),
      streak: state.currentStreak,
    );
    state = newState;
  }

  static SanctuaryState _buildState({
    required List<SpeciesRecord> allSpecies,
    required Set<String> collectedIds,
    required int streak,
  }) {
    // Group collected species by primary habitat.
    final Map<Habitat, List<SpeciesRecord>> byHabitat = {};

    for (final species in allSpecies) {
      if (!collectedIds.contains(species.id)) continue;

      final primaryHabitat =
          species.habitats.isNotEmpty ? species.habitats.first : Habitat.forest;
      (byHabitat[primaryHabitat] ??= []).add(species);
    }

    return SanctuaryState(
      speciesByHabitat: byHabitat,
      totalCollected: collectedIds.length,
      totalInPool: allSpecies.length,
      currentStreak: streak,
    );
  }
}

/// Global provider for [SanctuaryNotifier].
final sanctuaryProvider =
    NotifierProvider<SanctuaryNotifier, SanctuaryState>(SanctuaryNotifier.new);
