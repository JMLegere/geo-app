import 'package:earth_nova/core/domain/content/content_identity.dart';
import 'package:earth_nova/core/domain/content/current_encounter_version_binding_repository.dart';
import 'package:earth_nova/core/domain/content/encounter_content.dart';
import 'package:earth_nova/core/domain/rules/selector.dart';
import 'package:earth_nova/core/observability/trace_context.dart';
import 'package:earth_nova/features/encounters/application/encounter_engine_mode.dart';
import 'package:earth_nova/features/encounters/application/encounter_entry_coordinator.dart';
import 'package:earth_nova/features/encounters/data/repositories/supabase_current_encounter_version_binding_repository.dart';
import 'package:earth_nova/features/encounters/data/repositories/supabase_encounter_repository.dart';
import 'package:earth_nova/features/encounters/domain/entities/encounter_entities.dart';
import 'package:earth_nova/features/encounters/domain/repositories/encounter_repository.dart';
import 'package:earth_nova/features/encounters/domain/use_cases/resolve_cell_visit_encounter_selector.dart';
import 'package:earth_nova/features/encounters/presentation/providers/pending_encounter_provider.dart';
import 'package:earth_nova/features/map/domain/entities/cell_border_crossing_event.dart';
import 'package:earth_nova/features/map/domain/entities/cell_visit.dart';
import 'package:earth_nova/features/map/domain/rules/legacy_encounter_eligibility.dart';
import 'package:earth_nova/features/map/presentation/providers/encounter_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The optional client is intentionally the only Encounter runtime dependency
/// overridden by application bootstrap. Legacy execution remains available when
/// Supabase has not been configured.
final nullableSupabaseClientProvider = Provider<SupabaseClient?>((ref) => null);

final encounterEngineModeResolutionProvider =
    Provider<EncounterEngineModeResolution>((ref) {
  return EncounterEngineModeResolution.fromCompileTimeDefines();
});

/// One stable daily input shared by both the legacy compute and compatibility
/// planner for a persisted Cell Visit.
final encounterDailySeedProvider = Provider<String>((ref) {
  final now = DateTime.now();
  return 'seed_${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}';
});

final currentEncounterVersionBindingRepositoryProvider =
    Provider<CurrentEncounterVersionBindingRepository>((ref) {
  final client = ref.watch(nullableSupabaseClientProvider);
  if (client == null) {
    return const _UnavailableCurrentEncounterVersionBindingRepository();
  }
  final obs = ref.watch(encounterObservabilityProvider);
  return SupabaseCurrentEncounterVersionBindingRepository.fromSupabase(
    client,
    logEvent: obs.log,
  );
});

final encounterCommandRepositoryProvider = Provider<EncounterRepository>((ref) {
  final client = ref.watch(nullableSupabaseClientProvider);
  if (client == null) return const _UnavailableEncounterRepository();
  final obs = ref.watch(encounterObservabilityProvider);
  return SupabaseEncounterRepository.fromSupabase(
    client,
    logEvent: obs.log,
  );
});

final resolveCellVisitEncounterSelectorProvider = Provider<
        ResolveCellVisitEncounterSelector<LegacyEncounterEligibilityContext>>(
    (ref) {
  return ResolveCellVisitEncounterSelector(
    ref.watch(currentEncounterVersionBindingRepositoryProvider),
    ref.watch(encounterObservabilityProvider),
  );
});

final legacyEncounterComputationProvider =
    Provider<LegacyEncounterCompute>((ref) {
  final computeEncounter = ref.watch(computeEncounterProvider);
  final selector = buildLegacyCellEncounterCompatibilitySelector();
  return (context) async {
    final eligibilityContext = LegacyEncounterEligibilityContext(
      isFirstVisit: context.isFirstVisit,
      hasLegacyLoot: context.hasLootCompatibility,
    );
    final encounter = await computeEncounter.call((
      cellId: context.persistedCellVisit.cellId,
      seed: context.deterministicSeed,
      isFirstVisit: context.isFirstVisit,
      hasLoot: context.hasLootCompatibility,
    ));
    if (encounter == null) {
      return const LegacyEncounterComputation.noSelection();
    }

    final candidate = selector.resolveCandidate(
      eligibilityContext,
      () => legacyCellEncounterRoll(
        seed: context.deterministicSeed,
        cellId: context.persistedCellVisit.cellId,
      ),
    );
    final result = candidate.result;
    if (result is! SelectedValue<StableContentId<EncounterContent>>) {
      throw StateError(
          'Legacy encounter compute selected no compatible candidate.');
    }
    return LegacyEncounterComputation.selected(
      selectorCandidateId: SelectorCandidateId(candidate.id),
      definitionId: result.value,
      legacyEncounter: encounter,
    );
  };
});

final versionedEncounterPlannerProvider =
    Provider<VersionedEncounterPlanner>((ref) {
  final resolveSelector = ref.watch(resolveCellVisitEncounterSelectorProvider);
  final selector = buildLegacyCellEncounterCompatibilitySelector();
  return (context) async {
    final selection = await resolveSelector.call(
      ResolveCellVisitEncounterSelectorInput<LegacyEncounterEligibilityContext>(
        cellVisit: context.persistedCellVisit,
        selectorId: legacyCellEncounterSelectorId,
        selector: selector,
        selectorContext: LegacyEncounterEligibilityContext(
          isFirstVisit: context.isFirstVisit,
          hasLegacyLoot: context.hasLootCompatibility,
        ),
        rollSource: () => legacyCellEncounterRoll(
          seed: context.deterministicSeed,
          cellId: context.persistedCellVisit.cellId,
        ),
      ),
      parent: context.rootTrace,
    );
    return switch (selection) {
      NoEncounterCellVisitPlan() => VersionedEncounterPlan.none(selection),
      EncounterSelectedCellVisitPlan() => VersionedEncounterPlan.selected(
          selection: selection,
          isAutomatic: selection.isAutomatic,
        ),
    };
  };
});

final legacyEncounterWriterProvider = Provider<LegacyEncounterWriter>((ref) {
  return (context, computation) {
    return ref.read(encounterProvider.notifier).writePrecomputedLegacyEncounter(
          encounter: computation.legacyEncounter,
          cellId: context.persistedCellVisit.cellId,
          mapCellEntryId: context.mapEntryId,
          userId: context.userId,
        );
  };
});

final committedRewardsPresenterProvider =
    Provider<CommittedRewardsPresenter>((ref) {
  return (context, legacyComputation, generatedItems) {
    return ref
        .read(encounterProvider.notifier)
        .presentCommittedEncounterRewards(
          context: context,
          legacyComputation: legacyComputation,
          generatedItems: generatedItems,
        );
  };
});

final committedPendingEncounterRewardPresenterProvider =
    Provider<Future<void> Function(PendingEncounter, GeneratedItemCommit)>(
  (ref) => (pendingEncounter, generatedItem) => ref
      .read(encounterProvider.notifier)
      .presentCommittedPendingEncounterReward(
        pendingEncounter: pendingEncounter,
        generatedItem: generatedItem,
      ),
);

final encounterTraceSinkProvider = Provider<EncounterTraceSink>((ref) {
  final obs = ref.watch(encounterObservabilityProvider);
  return (trace) {
    final mode = trace.mode;
    final data = <String, Object?>{
      'trace_id': trace.context.rootTrace.traceId,
      'persisted_cell_visit_id': trace.context.persistedCellVisit.id,
      'cell_id': trace.context.persistedCellVisit.cellId,
      'map_cell_entry_id': trace.context.mapEntryId,
      'selector_id': legacyCellEncounterSelectorId.value,
      'requested_mode': mode.requestedMode?.name,
      'effective_mode': mode.effectiveMode.name,
      'mode_gate': mode.gateReason?.name,
    };
    switch (trace) {
      case EncounterComparisonTrace(:final comparison):
        obs.log(
          'encounter.entry.comparison',
          'encounter',
          data: {
            ...data,
            'eligibility_comparison': comparison.eligibility.name,
            'candidate_comparison': comparison.candidate.name,
            'definition_comparison': comparison.definition.name,
            'exact_version_comparison': comparison.exactVersion.name,
          },
        );
      case EncounterTerminalTrace(:final terminal, :final itemMutationOwner):
        obs.log(
          'encounter.entry.terminal',
          'encounter',
          data: {
            ...data,
            'terminal': terminal.name,
            'item_mutation_owner': itemMutationOwner.name,
          },
        );
    }
  };
});

final encounterEntryCoordinatorProvider =
    Provider<EncounterEntryCoordinator>((ref) {
  return EncounterEntryCoordinator(
    mode: ref.watch(encounterEngineModeResolutionProvider),
    legacyCompute: ref.watch(legacyEncounterComputationProvider),
    legacyWriter: ref.watch(legacyEncounterWriterProvider),
    versionedPlanner: ref.watch(versionedEncounterPlannerProvider),
    repository: ref.watch(encounterCommandRepositoryProvider),
    committedRewardsPresenter: ref.watch(committedRewardsPresenterProvider),
    traceSink: ref.watch(encounterTraceSinkProvider),
  );
});

typedef PersistedCellVisitEncounterHandler = Future<void> Function(
  CellVisit persistedCellVisit,
  CellBorderCrossingEvent borderCrossingEvent, {
  TraceContext? rootTrace,
});

/// The sole runtime Encounter call site. It is deliberately typed to the exact
/// [CellVisit] returned by persistence and rejects unrelated border events.
final persistedCellVisitEncounterHandlerProvider =
    Provider<PersistedCellVisitEncounterHandler>((ref) {
  final coordinator = ref.watch(encounterEntryCoordinatorProvider);
  final mode = ref.watch(encounterEngineModeResolutionProvider);
  final seed = ref.watch(encounterDailySeedProvider);
  final obs = ref.watch(encounterObservabilityProvider);
  final repository = ref.watch(encounterCommandRepositoryProvider);
  return (persistedCellVisit, borderCrossingEvent, {rootTrace}) async {
    if (persistedCellVisit.cellId != borderCrossingEvent.enteredCellId) {
      throw ArgumentError.value(
        borderCrossingEvent.enteredCellId,
        'borderCrossingEvent.enteredCellId',
        'must match persistedCellVisit.cellId',
      );
    }
    final trace = rootTrace ?? TraceContext.start();
    obs.log(
      'encounter.entry.persisted_visit',
      'encounter',
      data: {
        'trace_id': trace.traceId,
        'persisted_cell_visit_id': persistedCellVisit.id,
        'cell_id': persistedCellVisit.cellId,
        'map_cell_entry_id': borderCrossingEvent.mapCellEntryId,
        'selector_id': legacyCellEncounterSelectorId.value,
        'requested_mode': mode.requestedMode?.name,
        'effective_mode': mode.effectiveMode.name,
        'mode_gate': mode.gateReason?.name,
      },
    );
    final context = EncounterEntryContext(
      rootTrace: trace,
      persistedCellVisit: persistedCellVisit,
      userId: persistedCellVisit.userId,
      mapEntryId: borderCrossingEvent.mapCellEntryId,
      deterministicSeed: seed,
      isFirstVisit: borderCrossingEvent.isFirstVisit,
      hasLootCompatibility: false,
      borderContext: EncounterBorderContext(
        enteredCellId: borderCrossingEvent.enteredCellId,
        previousCellId: borderCrossingEvent.previousCellId,
      ),
    );
    try {
      if (mode.effectiveMode == EncounterEngineMode.v3Authoritative) {
        final pendingEncounter = await repository.readPendingEncounterForCell(
          persistedCellVisit.cellId,
          traceId: trace.traceId,
        );
        if (pendingEncounter != null) {
          ref.read(pendingEncounterProvider.notifier).show(pendingEncounter);
          return;
        }
      }
      final result = await coordinator.enter(context);
      if (result.terminal == EncounterEntryTerminal.pendingOutcomeResolution) {
        await ref.read(pendingEncounterProvider.notifier).refresh();
      }
    } catch (error) {
      obs.log(
        'encounter.entry.terminal',
        'encounter',
        data: {
          'trace_id': trace.traceId,
          'persisted_cell_visit_id': persistedCellVisit.id,
          'cell_id': persistedCellVisit.cellId,
          'map_cell_entry_id': borderCrossingEvent.mapCellEntryId,
          'selector_id': legacyCellEncounterSelectorId.value,
          'requested_mode': mode.requestedMode?.name,
          'effective_mode': mode.effectiveMode.name,
          'mode_gate': mode.gateReason?.name,
          'terminal': EncounterEntryTerminal.coordinationFailed.name,
          'item_mutation_owner': EncounterItemMutationOwner.unknown.name,
          'error_type': error.runtimeType.toString(),
        },
      );
      rethrow;
    }
  };
});

final class _UnavailableCurrentEncounterVersionBindingRepository
    implements CurrentEncounterVersionBindingRepository {
  const _UnavailableCurrentEncounterVersionBindingRepository();

  @override
  Future<CurrentEncounterVersionBinding?>
      currentPublishedVersionForNewCellVisit(
    StableContentId<EncounterContent> definitionId, {
    String? traceId,
  }) {
    return Future<CurrentEncounterVersionBinding?>.error(
      StateError('Encounter Version binding requires Supabase.'),
    );
  }
}

final class _UnavailableEncounterRepository implements EncounterRepository {
  const _UnavailableEncounterRepository();

  @override
  Future<EncounterRuntimeAggregate> commitCellVisitSelection(
    CellVisitEncounterSelectionPlan plan, {
    required String traceId,
  }) {
    return Future<EncounterRuntimeAggregate>.error(
      StateError('Encounter commands require Supabase.'),
    );
  }

  @override
  Future<PendingEncounter?> readPendingEncounterForCell(
    String cellId, {
    required String traceId,
  }) {
    return Future<PendingEncounter?>.error(
      StateError('Encounter commands require Supabase.'),
    );
  }

  @override
  Future<EncounterRuntimeAggregate> resolveEncounterOutcomes(
    EncounterId encounterId, {
    required String traceId,
    EncounterOptionId? selectedOptionId,
  }) {
    return Future<EncounterRuntimeAggregate>.error(
      StateError('Encounter commands require Supabase.'),
    );
  }
}
