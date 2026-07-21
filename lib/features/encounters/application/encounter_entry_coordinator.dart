import 'package:earth_nova/core/domain/content/encounter_content.dart';
import 'package:earth_nova/core/domain/content/stable_content_id.dart';
import 'package:earth_nova/core/observability/trace_context.dart';
import 'package:earth_nova/features/encounters/application/encounter_engine_mode.dart';
import 'package:earth_nova/features/encounters/domain/entities/encounter_entities.dart';
import 'package:earth_nova/features/encounters/domain/repositories/encounter_repository.dart';
import 'package:earth_nova/features/encounters/domain/use_cases/resolve_cell_visit_encounter_selector.dart';
import 'package:earth_nova/features/map/domain/entities/cell_visit.dart';
import 'package:earth_nova/features/map/domain/entities/encounter.dart';

/// The known border crossing that produced the exact persisted Cell Visit.
final class EncounterBorderContext {
  const EncounterBorderContext({
    required this.enteredCellId,
    required this.previousCellId,
  });

  final String enteredCellId;
  final String? previousCellId;
}

/// All inputs whose values may affect one Cell Visit's compatibility resolution.
///
/// Construction rejects a context that is not tied to the supplied persisted
/// visit. The coordinator never receives a border event or an unpersisted visit.
final class EncounterEntryContext {
  EncounterEntryContext({
    required this.rootTrace,
    required this.persistedCellVisit,
    required String userId,
    required String mapEntryId,
    required String deterministicSeed,
    required this.isFirstVisit,
    required this.hasLootCompatibility,
    required this.borderContext,
  })  : userId = _nonBlank(userId, 'userId'),
        mapEntryId = _nonBlank(mapEntryId, 'mapEntryId'),
        deterministicSeed = _nonBlank(deterministicSeed, 'deterministicSeed') {
    if (persistedCellVisit.userId != this.userId) {
      throw ArgumentError.value(
        userId,
        'userId',
        'must match persistedCellVisit.userId',
      );
    }
    if (persistedCellVisit.cellId != borderContext.enteredCellId) {
      throw ArgumentError.value(
        borderContext.enteredCellId,
        'borderContext.enteredCellId',
        'must match persistedCellVisit.cellId',
      );
    }
  }

  /// The root trace for the player action that persisted this visit.
  final TraceContext rootTrace;

  /// The exact durable event. No planning or write occurs before this exists.
  final CellVisit persistedCellVisit;
  final String userId;
  final String mapEntryId;
  final String deterministicSeed;
  final bool isFirstVisit;
  final bool hasLootCompatibility;
  final EncounterBorderContext borderContext;
}

/// The read-only compatibility result from the legacy encounter calculation.
final class LegacyEncounterComputation {
  const LegacyEncounterComputation.noSelection()
      : isEligible = false,
        selectorCandidateId = null,
        definitionId = null,
        legacyEncounter = null;

  factory LegacyEncounterComputation.selected({
    required SelectorCandidateId selectorCandidateId,
    required StableContentId<EncounterContent> definitionId,
    required Encounter legacyEncounter,
  }) =>
      LegacyEncounterComputation._(
        isEligible: true,
        selectorCandidateId: selectorCandidateId,
        definitionId: definitionId,
        legacyEncounter: legacyEncounter,
      );

  const LegacyEncounterComputation._({
    required this.isEligible,
    required this.selectorCandidateId,
    required this.definitionId,
    required this.legacyEncounter,
  });

  final bool isEligible;
  final SelectorCandidateId? selectorCandidateId;
  final StableContentId<EncounterContent>? definitionId;

  /// The computed legacy presentation payload; never a new Item mutation.
  final Encounter? legacyEncounter;
}

/// The versioned planner result, including whether this selected Version is
/// automatic and therefore safe for the coordinator to resolve immediately.
final class VersionedEncounterPlan {
  factory VersionedEncounterPlan.none(
    CellVisitEncounterSelectionPlan selection,
  ) {
    if (selection is! NoEncounterCellVisitPlan) {
      throw ArgumentError.value(
        selection,
        'selection',
        'none plans require an explicit NoEncounterCellVisitPlan',
      );
    }
    return VersionedEncounterPlan._(selection: selection, isAutomatic: false);
  }

  factory VersionedEncounterPlan.selected({
    required EncounterSelectedCellVisitPlan selection,
    required bool isAutomatic,
  }) =>
      VersionedEncounterPlan._(
        selection: selection,
        isAutomatic: isAutomatic,
      );

  const VersionedEncounterPlan._({
    required this.selection,
    required this.isAutomatic,
  });

  final CellVisitEncounterSelectionPlan selection;
  final bool isAutomatic;
}

typedef LegacyEncounterCompute = Future<LegacyEncounterComputation> Function(
  EncounterEntryContext context,
);
typedef LegacyEncounterWriter = Future<void> Function(
  EncounterEntryContext context,
  LegacyEncounterComputation computation,
);
typedef VersionedEncounterPlanner = Future<VersionedEncounterPlan> Function(
  EncounterEntryContext context,
);
typedef CommittedRewardsPresenter = Future<void> Function(
  EncounterEntryContext context,
  LegacyEncounterComputation legacyComputation,
  List<GeneratedItemCommit> generatedItems,
);
typedef EncounterTraceSink = void Function(EncounterEntryTrace trace);

/// Which durable mutation owner produced the terminal runtime evidence.
enum EncounterItemMutationOwner {
  none,
  legacy,
  encounterRepository,
  encounterRepositoryRevealVenue,
  unknown,
}

enum EncounterEligibilityComparison { matched, mismatch }

enum EncounterCandidateComparison { matched, mismatch, bothNoSelection }

enum EncounterDefinitionComparison { matched, mismatch, bothNoSelection }

/// Exact Versions cannot be compared because legacy does not bind one.
enum EncounterExactVersionComparison {
  notApplicableNoDefinition,
  notComparableLegacyDoesNotBindExactVersion,
}

/// The complete comparison emitted in shadow and authoritative modes.
final class EncounterPlanComparison {
  const EncounterPlanComparison({
    required this.eligibility,
    required this.candidate,
    required this.definition,
    required this.exactVersion,
  });

  final EncounterEligibilityComparison eligibility;
  final EncounterCandidateComparison candidate;
  final EncounterDefinitionComparison definition;
  final EncounterExactVersionComparison exactVersion;

  bool get hasStableDefinitionMismatch =>
      definition == EncounterDefinitionComparison.mismatch;

  /// Authoritative writes require agreement on every comparable selection fact.
  bool get hasSelectionMismatch =>
      eligibility == EncounterEligibilityComparison.mismatch ||
      candidate == EncounterCandidateComparison.mismatch ||
      definition == EncounterDefinitionComparison.mismatch;
}

sealed class EncounterEntryTrace {
  const EncounterEntryTrace({required this.context, required this.mode});

  final EncounterEntryContext context;
  final EncounterEngineModeResolution mode;
}

final class EncounterComparisonTrace extends EncounterEntryTrace {
  const EncounterComparisonTrace({
    required super.context,
    required super.mode,
    required this.comparison,
  });

  final EncounterPlanComparison comparison;
}

final class EncounterTerminalTrace extends EncounterEntryTrace {
  const EncounterTerminalTrace({
    required super.context,
    required super.mode,
    required this.terminal,
    required this.itemMutationOwner,
  });

  final EncounterEntryTerminal terminal;
  final EncounterItemMutationOwner itemMutationOwner;
}

enum EncounterEntryTerminal {
  coordinationFailed,
  legacyExecuted,
  shadowPlanningExecutedLegacy,
  shadowPlanningFailedLegacyExecuted,
  selectionMismatch,
  definitionMismatch,
  explicitNone,
  missingCommittedEncounter,
  pendingOutcomeResolution,
  failedOutcomeResolution,
  committedOutcomeEvidenceMismatch,
  missingGeneratedItemCommit,
  revealedVenueCommitted,
  presentedCommittedItems,
}

/// Typed result for one coordinator entry. It contains no UI state and no
/// mutable service reference, so caller adapters choose how to surface it.
final class EncounterEntryResult {
  const EncounterEntryResult({
    required this.mode,
    required this.terminal,
    required this.itemMutationOwner,
    required this.legacyComputation,
    required this.comparison,
    required this.presentedGeneratedItems,
  });

  final EncounterEngineModeResolution mode;
  final EncounterEntryTerminal terminal;
  final EncounterItemMutationOwner itemMutationOwner;
  final LegacyEncounterComputation legacyComputation;
  final EncounterPlanComparison? comparison;
  final List<GeneratedItemCommit> presentedGeneratedItems;
}

/// Pure application orchestration for the already-persisted Cell Visit.
///
/// All effects enter through narrow typed seams. Shadow planning never invokes
/// [EncounterRepository], while authoritative mode never invokes the legacy
/// writer. This makes the Item mutation owner unambiguous per Cell Visit.
final class EncounterEntryCoordinator {
  const EncounterEntryCoordinator({
    required this.mode,
    required LegacyEncounterCompute legacyCompute,
    required LegacyEncounterWriter legacyWriter,
    required VersionedEncounterPlanner versionedPlanner,
    required EncounterRepository repository,
    required CommittedRewardsPresenter committedRewardsPresenter,
    required EncounterTraceSink traceSink,
  })  : _legacyCompute = legacyCompute,
        _legacyWriter = legacyWriter,
        _versionedPlanner = versionedPlanner,
        _repository = repository,
        _committedRewardsPresenter = committedRewardsPresenter,
        _traceSink = traceSink;

  final EncounterEngineModeResolution mode;
  final LegacyEncounterCompute _legacyCompute;
  final LegacyEncounterWriter _legacyWriter;
  final VersionedEncounterPlanner _versionedPlanner;
  final EncounterRepository _repository;
  final CommittedRewardsPresenter _committedRewardsPresenter;
  final EncounterTraceSink _traceSink;

  Future<EncounterEntryResult> enter(EncounterEntryContext context) async {
    final legacy = await _legacyCompute(context);
    switch (mode.effectiveMode) {
      case EncounterEngineMode.legacy:
        await _legacyWriter(context, legacy);
        return _complete(
          context: context,
          terminal: EncounterEntryTerminal.legacyExecuted,
          itemMutationOwner: EncounterItemMutationOwner.legacy,
          legacy: legacy,
        );
      case EncounterEngineMode.shadowPlanning:
        late final EncounterPlanComparison comparison;
        try {
          final versioned = await _versionedPlanner(context);
          _requirePlanMatchesPersistedVisit(versioned.selection, context);
          comparison = _compare(legacy, versioned.selection);
          _traceSink(
            EncounterComparisonTrace(
              context: context,
              mode: mode,
              comparison: comparison,
            ),
          );
        } catch (_) {
          await _legacyWriter(context, legacy);
          return _complete(
            context: context,
            terminal: EncounterEntryTerminal.shadowPlanningFailedLegacyExecuted,
            itemMutationOwner: EncounterItemMutationOwner.legacy,
            legacy: legacy,
          );
        }
        await _legacyWriter(context, legacy);
        return _complete(
          context: context,
          terminal: EncounterEntryTerminal.shadowPlanningExecutedLegacy,
          itemMutationOwner: EncounterItemMutationOwner.legacy,
          legacy: legacy,
          comparison: comparison,
        );
      case EncounterEngineMode.v3Authoritative:
        return _enterAuthoritative(context, legacy);
    }
  }

  Future<EncounterEntryResult> _enterAuthoritative(
    EncounterEntryContext context,
    LegacyEncounterComputation legacy,
  ) async {
    final versioned = await _versionedPlanner(context);
    _requirePlanMatchesPersistedVisit(versioned.selection, context);
    final comparison = _compare(legacy, versioned.selection);
    _traceSink(
      EncounterComparisonTrace(
        context: context,
        mode: mode,
        comparison: comparison,
      ),
    );

    if (comparison.hasSelectionMismatch) {
      return _complete(
        context: context,
        terminal: comparison.hasStableDefinitionMismatch
            ? EncounterEntryTerminal.definitionMismatch
            : EncounterEntryTerminal.selectionMismatch,
        itemMutationOwner: EncounterItemMutationOwner.none,
        legacy: legacy,
        comparison: comparison,
      );
    }

    final selectionAggregate = await _repository.commitCellVisitSelection(
      versioned.selection,
      traceId: context.rootTrace.traceId,
    );
    if (versioned.selection is NoEncounterCellVisitPlan) {
      return _complete(
        context: context,
        terminal: EncounterEntryTerminal.explicitNone,
        itemMutationOwner: EncounterItemMutationOwner.none,
        legacy: legacy,
        comparison: comparison,
      );
    }

    final encounter = selectionAggregate.encounter;
    if (encounter == null) {
      return _complete(
        context: context,
        terminal: EncounterEntryTerminal.missingCommittedEncounter,
        itemMutationOwner: EncounterItemMutationOwner.encounterRepository,
        legacy: legacy,
        comparison: comparison,
      );
    }

    final finalAggregate = versioned.isAutomatic
        ? await _repository.resolveEncounterOutcomes(
            encounter.id,
            traceId: context.rootTrace.traceId,
          )
        : selectionAggregate;
    return _completeResolvedAggregate(
      context: context,
      aggregate: finalAggregate,
      legacy: legacy,
      comparison: comparison,
    );
  }

  Future<EncounterEntryResult> _completeResolvedAggregate({
    required EncounterEntryContext context,
    required EncounterRuntimeAggregate aggregate,
    required LegacyEncounterComputation legacy,
    required EncounterPlanComparison comparison,
  }) async {
    final encounter = aggregate.encounter;
    if (encounter == null) {
      return _complete(
        context: context,
        terminal: EncounterEntryTerminal.missingCommittedEncounter,
        itemMutationOwner: EncounterItemMutationOwner.encounterRepository,
        legacy: legacy,
        comparison: comparison,
      );
    }
    switch (encounter.status) {
      case EncounterResolutionStatus.pending:
        return _complete(
          context: context,
          terminal: EncounterEntryTerminal.pendingOutcomeResolution,
          itemMutationOwner: EncounterItemMutationOwner.encounterRepository,
          legacy: legacy,
          comparison: comparison,
        );
      case EncounterResolutionStatus.failed:
        return _complete(
          context: context,
          terminal: EncounterEntryTerminal.failedOutcomeResolution,
          itemMutationOwner: EncounterItemMutationOwner.encounterRepository,
          legacy: legacy,
          comparison: comparison,
        );
      case EncounterResolutionStatus.resolved:
        break;
    }

    if (!_hasExactCommittedOutcomeEvidence(aggregate)) {
      return _complete(
        context: context,
        terminal: EncounterEntryTerminal.committedOutcomeEvidenceMismatch,
        itemMutationOwner: EncounterItemMutationOwner.unknown,
        legacy: legacy,
        comparison: comparison,
      );
    }

    final commits = aggregate.generatedItemCommits;
    if (commits.isEmpty) {
      if (aggregate.revealedVenueCommits.isEmpty) {
        return _complete(
          context: context,
          terminal: EncounterEntryTerminal.missingGeneratedItemCommit,
          itemMutationOwner: EncounterItemMutationOwner.encounterRepository,
          legacy: legacy,
          comparison: comparison,
        );
      }
      return _complete(
        context: context,
        terminal: EncounterEntryTerminal.revealedVenueCommitted,
        itemMutationOwner:
            EncounterItemMutationOwner.encounterRepositoryRevealVenue,
        legacy: legacy,
        comparison: comparison,
      );
    }

    await _committedRewardsPresenter(context, legacy, commits);
    return _complete(
      context: context,
      terminal: EncounterEntryTerminal.presentedCommittedItems,
      itemMutationOwner: EncounterItemMutationOwner.encounterRepository,
      legacy: legacy,
      comparison: comparison,
      presentedGeneratedItems: commits,
    );
  }

  EncounterEntryResult _complete({
    required EncounterEntryContext context,
    required EncounterEntryTerminal terminal,
    required EncounterItemMutationOwner itemMutationOwner,
    required LegacyEncounterComputation legacy,
    EncounterPlanComparison? comparison,
    List<GeneratedItemCommit> presentedGeneratedItems =
        const <GeneratedItemCommit>[],
  }) {
    _traceSink(
      EncounterTerminalTrace(
        context: context,
        mode: mode,
        terminal: terminal,
        itemMutationOwner: itemMutationOwner,
      ),
    );
    return EncounterEntryResult(
      mode: mode,
      terminal: terminal,
      itemMutationOwner: itemMutationOwner,
      legacyComputation: legacy,
      comparison: comparison,
      presentedGeneratedItems: presentedGeneratedItems,
    );
  }
}

EncounterPlanComparison _compare(
  LegacyEncounterComputation legacy,
  CellVisitEncounterSelectionPlan versioned,
) {
  final selected =
      versioned is EncounterSelectedCellVisitPlan ? versioned : null;
  final eligibility = legacy.isEligible == (selected != null)
      ? EncounterEligibilityComparison.matched
      : EncounterEligibilityComparison.mismatch;
  final candidate = _candidateComparison(
    legacy.selectorCandidateId,
    selected?.selectorCandidateId,
  );
  final definition = _definitionComparison(
    legacy.definitionId,
    selected?.definitionId,
  );
  return EncounterPlanComparison(
    eligibility: eligibility,
    candidate: candidate,
    definition: definition,
    exactVersion: selected != null
        ? EncounterExactVersionComparison
            .notComparableLegacyDoesNotBindExactVersion
        : EncounterExactVersionComparison.notApplicableNoDefinition,
  );
}

EncounterCandidateComparison _candidateComparison(
  SelectorCandidateId? legacy,
  SelectorCandidateId? versioned,
) {
  if (legacy == null && versioned == null) {
    return EncounterCandidateComparison.bothNoSelection;
  }
  return legacy == versioned
      ? EncounterCandidateComparison.matched
      : EncounterCandidateComparison.mismatch;
}

EncounterDefinitionComparison _definitionComparison(
  StableContentId<EncounterContent>? legacy,
  StableContentId<EncounterContent>? versioned,
) {
  if (legacy == null && versioned == null) {
    return EncounterDefinitionComparison.bothNoSelection;
  }
  return legacy == versioned
      ? EncounterDefinitionComparison.matched
      : EncounterDefinitionComparison.mismatch;
}

bool _hasExactCommittedOutcomeEvidence(EncounterRuntimeAggregate aggregate) {
  final generatedResults = aggregate.outcomeResults
      .whereType<GenerateItemOutcomeResult>()
      .toList(growable: false);
  final revealedVenueResults = aggregate.outcomeResults
      .whereType<RevealVenueOutcomeResult>()
      .toList(growable: false);
  if (generatedResults.length + revealedVenueResults.length !=
      aggregate.outcomeResults.length) {
    return false;
  }
  if (generatedResults.length != aggregate.generatedItemCommits.length ||
      revealedVenueResults.length != aggregate.revealedVenueCommits.length) {
    return false;
  }
  return _hasSameOutcomeResultIdsInOrder(
        generatedResults.map((result) => result.id),
        aggregate.generatedItemCommits.map((commit) => commit.outcomeResult.id),
      ) &&
      _hasSameOutcomeResultIdsInOrder(
        revealedVenueResults.map((result) => result.id),
        aggregate.revealedVenueCommits.map(
          (commit) => commit.outcomeResult.id,
        ),
      );
}

bool _hasSameOutcomeResultIdsInOrder(
  Iterable<EncounterOutcomeResultId> expected,
  Iterable<EncounterOutcomeResultId> actual,
) {
  final expectedIds = List<EncounterOutcomeResultId>.of(expected);
  final actualIds = List<EncounterOutcomeResultId>.of(actual);
  if (expectedIds.length != actualIds.length) return false;
  for (var index = 0; index < expectedIds.length; index += 1) {
    if (expectedIds[index] != actualIds[index]) return false;
  }
  return true;
}

void _requirePlanMatchesPersistedVisit(
  CellVisitEncounterSelectionPlan plan,
  EncounterEntryContext context,
) {
  if (plan.cellVisit != context.persistedCellVisit) {
    throw ArgumentError.value(
      plan.cellVisit,
      'plan.cellVisit',
      'must be the exact persisted Cell Visit supplied to the coordinator',
    );
  }
}

String _nonBlank(String value, String name) {
  final canonical = value.trim();
  if (canonical.isEmpty) {
    throw ArgumentError.value(value, name, 'must not be blank');
  }
  return canonical;
}
