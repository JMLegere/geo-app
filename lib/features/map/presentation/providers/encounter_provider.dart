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
        'display_name': encounter.displayName,
        'encounter_type': encounter.type.name,
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
                displayName: encounter.displayName,
                scientificName: encounter.scientificName,
                category: ItemCategory.fauna,
                rarity: encounter.rarity,
                acquiredInCellId: encounter.cellId,
                mapCellEntryId: effectiveMapCellEntryId,
                taxonomicClass: encounter.taxonomicClass,
                habitats: encounter.habitats,
                continents: encounter.continents,
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
    transition(
      state.copyWith(currentEncounter: resolvedEncounter),
      'map.encounter_triggered',
      data: {
        'cellId': cellId,
        'map_cell_entry_id': effectiveMapCellEntryId,
        'encounterType': resolvedEncounter.type.name,
        'speciesId': resolvedEncounter.speciesId,
        'display_name': resolvedEncounter.displayName,
        'owned_item_id': resolvedEncounter.acquiredItem?.id,
      },
    );
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
