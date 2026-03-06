import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fog_of_world/core/models/habitat.dart';
import 'package:fog_of_world/core/models/item_definition.dart';
import 'package:fog_of_world/core/state/inventory_provider.dart';
import 'package:fog_of_world/core/state/player_provider.dart';
import 'package:fog_of_world/features/discovery/providers/discovery_provider.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Immutable snapshot of the sanctuary view state.
class SanctuaryState {
  /// Collected species grouped by their primary habitat.
  final Map<Habitat, List<FaunaDefinition>> speciesByHabitat;

  /// Total number of species the player has collected.
  final int totalCollected;

  /// Total number of species available in the pool (all known species).
  final int totalInPool;

  /// Player's current daily visit streak (from [PlayerState]).
  final int currentStreak;

  const SanctuaryState({
    this.speciesByHabitat = const <Habitat, List<FaunaDefinition>>{},
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
    Map<Habitat, List<FaunaDefinition>>? speciesByHabitat,
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

    // Listen to inventory changes to re-group species.
    ref.listen(inventoryProvider, (_, next) {
      _updateFromInventory(next);
    });

    // Listen to player streak changes.
    ref.listen(playerProvider, (_, next) {
      state = state.copyWith(currentStreak: next.currentStreak);
    });

    // Read inventory + player for initial state (listen handles ongoing).
    final inventoryState = ref.read(inventoryProvider);
    final playerState = ref.read(playerProvider);

    return _buildState(
      allSpecies: speciesService.all,
      collectedIds: inventoryState.uniqueDefinitionIds,
      streak: playerState.currentStreak,
    );
  }

  void _updateFromInventory(InventoryState inventoryState) {
    final speciesService = ref.read(speciesServiceProvider);
    final newState = _buildState(
      allSpecies: speciesService.all,
      collectedIds: inventoryState.uniqueDefinitionIds,
      streak: state.currentStreak,
    );
    state = newState;
  }

  static SanctuaryState _buildState({
    required List<FaunaDefinition> allSpecies,
    required Set<String> collectedIds,
    required int streak,
  }) {
    // Group collected species by primary habitat.
    final Map<Habitat, List<FaunaDefinition>> byHabitat = {};

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
