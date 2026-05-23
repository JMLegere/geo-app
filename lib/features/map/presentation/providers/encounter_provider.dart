import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/observability/observable_notifier.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/identification/domain/entities/discovery_item_draft.dart';
import 'package:earth_nova/features/identification/presentation/providers/items_provider.dart';
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

const _encounterStateUnset = Object();

class EncounterState {
  const EncounterState({
    this.currentEncounter,
    this.flyingReward,
    this.queuedRewards = const [],
    this.packImpactCount = 0,
  });

  final Encounter? currentEncounter;
  final Encounter? flyingReward;
  final List<Encounter> queuedRewards;
  final int packImpactCount;

  bool get hasActiveReward => currentEncounter != null || flyingReward != null;

  EncounterState copyWith({
    Object? currentEncounter = _encounterStateUnset,
    Object? flyingReward = _encounterStateUnset,
    List<Encounter>? queuedRewards,
    int? packImpactCount,
  }) {
    return EncounterState(
      currentEncounter: identical(currentEncounter, _encounterStateUnset)
          ? this.currentEncounter
          : currentEncounter as Encounter?,
      flyingReward: identical(flyingReward, _encounterStateUnset)
          ? this.flyingReward
          : flyingReward as Encounter?,
      queuedRewards: queuedRewards ?? this.queuedRewards,
      packImpactCount: packImpactCount ?? this.packImpactCount,
    );
  }
}

class EncounterNotifier extends ObservableNotifier<EncounterState> {
  @override
  ObservabilityService get obs => ref.watch(encounterObservabilityProvider);

  @override
  String get category => 'map';

  final _processedMapCellEntryIds = <String>{};
  @override
  EncounterState build() {
    return const EncounterState();
  }

  /// Called when player enters a cell.
  ///
  /// - First visit: computes species encounter
  /// - Revisit with loot: computes critter encounter
  /// - Revisit without loot: no encounter
  Future<void> onCellEntered({
    required String cellId,
    required bool isFirstVisit,
    String seed = '',
    bool hasLoot = false,
    String? userId,
    String? mapCellEntryId,
  }) async {
    final computeEncounter = ref.read(computeEncounterProvider);

    // For now, use daily seed if not provided
    final effectiveSeed = seed.isEmpty ? _getDailySeed() : seed;

    final effectiveMapCellEntryId = mapCellEntryId ??
        'legacy-map-cell-entry-$cellId-${isFirstVisit ? 'first' : 'revisit'}-$effectiveSeed';
    if (_processedMapCellEntryIds.contains(effectiveMapCellEntryId)) {
      return;
    }

    final encounter = await computeEncounter.call(
      (
        cellId: cellId,
        seed: effectiveSeed,
        isFirstVisit: isFirstVisit,
        hasLoot: hasLoot,
      ),
    );

    if (encounter == null) return;

    obs.log(
      'discovery.result_resolved',
      category,
      data: {
        'cell_id': cellId,
        'map_cell_entry_id': effectiveMapCellEntryId,
        'result_id': encounter.speciesId,
        'result_type': encounter.type == EncounterType.species
            ? 'unidentified_fauna'
            : encounter.type.name,
        'unidentified_category': encounter.type == EncounterType.species
            ? ItemCategory.fauna.name
            : null,
      },
    );

    var resolvedEncounter = encounter;
    if (encounter.type == EncounterType.species &&
        userId != null &&
        userId.isNotEmpty) {
      try {
        final ownedItem = await ref.read(acquireDiscoveryItemProvider).call(
              DiscoveryItemDraft(
                userId: userId,
                definitionId: encounter.speciesId,
                displayName: 'Unidentified fauna specimen',
                scientificName: null,
                category: ItemCategory.fauna,
                rarity: encounter.rarity,
                acquiredInCellId: encounter.cellId,
                mapCellEntryId: effectiveMapCellEntryId,
                identificationState: ItemIdentificationState.unidentified,
                identifiedDisplayName: encounter.displayName,
                identifiedScientificName: encounter.scientificName,
                identifiedTaxonomicClass: encounter.taxonomicClass,
                identifiedHabitats: encounter.habitats,
                identifiedContinents: encounter.continents,
              ),
            );
        ref.read(itemsProvider.notifier).registerOwnedDiscovery(ownedItem);
        resolvedEncounter = encounter.copyWith(acquiredItem: ownedItem);
        obs.log(
          'discovery.acquisition_committed',
          category,
          data: {
            'cell_id': cellId,
            'map_cell_entry_id': effectiveMapCellEntryId,
            'result_id': encounter.speciesId,
            'owned_item_id': ownedItem.id,
            'unidentified_category': ItemCategory.fauna.name,
          },
        );
      } catch (error, stack) {
        obs.logError(error, stack, event: 'discovery.acquisition_failed');
        obs.log(
          'discovery.acquisition_failed',
          category,
          data: {
            'cell_id': cellId,
            'map_cell_entry_id': effectiveMapCellEntryId,
            'result_id': encounter.speciesId,
            'error_type': error.runtimeType.toString(),
            'error_message': error.toString(),
          },
        );
        return;
      }
    }

    _processedMapCellEntryIds.add(effectiveMapCellEntryId);
    final isQueued = state.hasActiveReward;
    if (isQueued) {
      final queued = [...state.queuedRewards, resolvedEncounter];
      obs.log(
        'discovery.reward_queued',
        category,
        data: {
          'cell_id': cellId,
          'map_cell_entry_id': effectiveMapCellEntryId,
          'result_id': resolvedEncounter.speciesId,
          'owned_item_id': resolvedEncounter.acquiredItem?.id,
          'queue_depth': queued.length,
        },
      );
      transition(
        state.copyWith(queuedRewards: queued),
        'discovery.reward_queued',
        data: {
          'cellId': cellId,
          'map_cell_entry_id': effectiveMapCellEntryId,
          'encounterType': resolvedEncounter.type.name,
          'speciesId': resolvedEncounter.speciesId,
          'owned_item_id': resolvedEncounter.acquiredItem?.id,
          'queue_depth': queued.length,
        },
      );
      return;
    }

    _logRewardPresented(resolvedEncounter, effectiveMapCellEntryId);
    transition(
      state.copyWith(currentEncounter: resolvedEncounter),
      'map.encounter_triggered',
      data: {
        'cellId': cellId,
        'map_cell_entry_id': effectiveMapCellEntryId,
        'encounterType': resolvedEncounter.type.name,
        'speciesId': resolvedEncounter.speciesId,
        'display_name': resolvedEncounter.acquiredItem?.visibleDisplayName ??
            resolvedEncounter.displayName,
        'owned_item_id': resolvedEncounter.acquiredItem?.id,
      },
    );
  }

  /// Continue the active discovery reward into the Pack animation.
  void continueDiscoveryReward() {
    final reward = state.currentEncounter;
    if (reward == null) return;

    obs.log(
      'discovery.reward_continued',
      category,
      data: _rewardData(reward),
    );
    transition(
      state.copyWith(
        currentEncounter: null,
        flyingReward: reward,
      ),
      'discovery.reward_continued',
      data: _rewardData(reward),
    );
  }

  /// Clear the completed card flight and present the next queued reward, if any.
  void completeRewardFlight() {
    final completedReward = state.flyingReward;
    if (completedReward == null) return;

    final nextReward =
        state.queuedRewards.isEmpty ? null : state.queuedRewards.first;
    final remainingQueue = state.queuedRewards.isEmpty
        ? const <Encounter>[]
        : state.queuedRewards.sublist(1);
    obs.log(
      'pack.reward_impact',
      'pack',
      data: _rewardData(completedReward),
    );
    if (nextReward != null) {
      _logRewardPresented(nextReward, null);
    }
    transition(
      state.copyWith(
        flyingReward: null,
        currentEncounter: nextReward,
        queuedRewards: remainingQueue,
        packImpactCount: state.packImpactCount + 1,
      ),
      'discovery.reward_flight_completed',
      data: {
        'completed_result_id': completedReward.speciesId,
        'next_result_id': nextReward?.speciesId,
        'queue_depth': remainingQueue.length,
      },
    );
  }

  /// Dismiss the current encounter (legacy/test helper; reward UI should continue).
  void dismissEncounter() {
    if (state.currentEncounter != null) {
      final cellId = state.currentEncounter!.cellId;
      transition(
        state.copyWith(currentEncounter: null),
        'map.encounter_dismissed',
        data: {'cellId': cellId},
      );
    }
  }

  void _logRewardPresented(Encounter reward, String? mapCellEntryId) {
    obs.log(
      'discovery.reward_presented',
      category,
      data: {
        ..._rewardData(reward),
        if (mapCellEntryId != null) 'map_cell_entry_id': mapCellEntryId,
      },
    );
  }

  Map<String, dynamic> _rewardData(Encounter reward) => {
        'cell_id': reward.cellId,
        'result_id': reward.speciesId,
        'result_type': reward.type == EncounterType.species
            ? 'unidentified_fauna'
            : reward.type.name,
        'unidentified_category': reward.type == EncounterType.species
            ? ItemCategory.fauna.name
            : null,
        'owned_item_id': reward.acquiredItem?.id,
      };

  /// Get current daily seed (in real impl, this would be server-synced)
  String _getDailySeed() {
    final now = DateTime.now();
    return 'seed_${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}';
  }
}
