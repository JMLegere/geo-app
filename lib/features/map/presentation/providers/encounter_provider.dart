import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/observability/observable_notifier.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/entities/encounter.dart';
import 'package:earth_nova/features/map/domain/use_cases/compute_encounter.dart';

// Provider for observability service (must be overridden)
final encounterObservabilityProvider = Provider<ObservabilityService>((ref) {
  throw UnimplementedError('Must be overridden with overrideWithValue');
});

// Provider for ComputeEncounter use case
final computeEncounterProvider = Provider<ComputeEncounter>((ref) {
  return ComputeEncounter(ref.watch(encounterObservabilityProvider));
});

// Main provider
final encounterProvider = NotifierProvider<EncounterNotifier, EncounterState>(
  EncounterNotifier.new,
);

class EncounterState {
  const EncounterState({this.currentEncounter});

  final Encounter? currentEncounter;

  EncounterState copyWith(
      {Encounter? currentEncounter, bool clearEncounter = false}) {
    return EncounterState(
      currentEncounter:
          clearEncounter ? null : (currentEncounter ?? this.currentEncounter),
    );
  }
}

class EncounterNotifier extends ObservableNotifier<EncounterState> {
  @override
  ObservabilityService get obs => ref.watch(encounterObservabilityProvider);

  @override
  String get category => 'map';

  @override
  EncounterState build() {
    return const EncounterState();
  }

  /// Called when player enters a cell.
  ///
  /// - First visit: computes species encounter
  /// - Revisit with loot: computes critter encounter
  /// - Revisit without loot: no encounter
  void onCellEntered({
    required String cellId,
    required bool isFirstVisit,
    String seed = '',
    bool hasLoot = false,
  }) {
    final computeEncounter = ref.read(computeEncounterProvider);

    // For now, use daily seed if not provided
    final effectiveSeed = seed.isEmpty ? _getDailySeed() : seed;

    final encounter = computeEncounter.call(
      (
        cellId: cellId,
        seed: effectiveSeed,
        isFirstVisit: isFirstVisit,
        hasLoot: hasLoot,
      ),
    );

    if (encounter != null) {
      transition(
        state.copyWith(currentEncounter: encounter),
        'map.encounter_triggered',
        data: {
          'cellId': cellId,
          'encounterType': encounter.type.name,
          'speciesId': encounter.speciesId,
        },
      );
    }
  }

  /// Dismiss the current encounter (player clears popup/toast)
  void dismissEncounter() {
    if (state.currentEncounter != null) {
      final cellId = state.currentEncounter!.cellId;
      transition(
        state.copyWith(clearEncounter: true),
        'map.encounter_dismissed',
        data: {'cellId': cellId},
      );
    }
  }

  /// Get current daily seed (in real impl, this would be server-synced)
  String _getDailySeed() {
    final now = DateTime.now();
    return 'seed_${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}';
  }
}
