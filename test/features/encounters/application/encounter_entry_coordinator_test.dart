import 'package:earth_nova/core/domain/content/base_item_content.dart';
import 'package:earth_nova/core/domain/content/content_version_id.dart';
import 'package:earth_nova/core/domain/content/encounter_content.dart';
import 'package:earth_nova/core/domain/content/exact_version_ref.dart';
import 'package:earth_nova/core/domain/content/stable_content_id.dart';
import 'package:earth_nova/core/domain/content/venue_content.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/domain/entities/venue_id.dart';
import 'package:earth_nova/core/observability/trace_context.dart';
import 'package:earth_nova/features/encounters/application/encounter_engine_mode.dart';
import 'package:earth_nova/features/encounters/application/encounter_entry_coordinator.dart';
import 'package:earth_nova/features/encounters/domain/entities/encounter_entities.dart';
import 'package:earth_nova/features/encounters/domain/repositories/encounter_repository.dart';
import 'package:earth_nova/features/encounters/domain/use_cases/resolve_cell_visit_encounter_selector.dart';
import 'package:earth_nova/features/map/domain/entities/cell_visit.dart';
import 'package:earth_nova/features/map/domain/entities/encounter.dart';
import 'package:flutter_test/flutter_test.dart';

final _definitionId = StableContentId<EncounterContent>('encounter:warbler');
final _definitionVersion = ExactVersionRef<EncounterContent>(
  stableId: _definitionId,
  versionId: ContentVersionId<EncounterContent>('version:warbler:1'),
  revision: 1,
);
final _baseItemId = StableContentId<BaseItemContent>('item:warbler');
final _baseItemVersion = ExactVersionRef<BaseItemContent>(
  stableId: _baseItemId,
  versionId: ContentVersionId<BaseItemContent>('version:item:warbler:1'),
  revision: 1,
);
final _venueId = VenueId('venue-1');
final _venueVersion = ExactVersionRef<VenueContent>(
  stableId: StableContentId<VenueContent>(_venueId.value),
  versionId: ContentVersionId<VenueContent>('version:venue-1:1'),
  revision: 1,
);

CellVisit _visit() => CellVisit(
      id: 'visit-1',
      cellId: 'cell-1',
      userId: 'player-1',
      visitedAt: DateTime.utc(2026, 7, 20),
    );

EncounterEntryContext _context() => EncounterEntryContext(
      rootTrace: TraceContext(
        traceId: 'root-trace',
        spanId: 'root-span',
        startTime: DateTime.utc(2026, 7, 20),
      ),
      persistedCellVisit: _visit(),
      userId: 'player-1',
      mapEntryId: 'map-entry-1',
      deterministicSeed: 'seed-1',
      isFirstVisit: true,
      hasLootCompatibility: false,
      borderContext: const EncounterBorderContext(
        enteredCellId: 'cell-1',
        previousCellId: 'cell-0',
      ),
    );

EncounterSelectedCellVisitPlan _selectionPlan(CellVisit visit) =>
    EncounterSelectedCellVisitPlan(
      cellVisit: visit,
      selectorId: SelectorId('selector:legacy-cell-encounter'),
      selectorCandidateId: SelectorCandidateId('candidate:warbler'),
      definitionId: _definitionId,
      definitionVersion: _definitionVersion,
      isAutomatic: true,
    );

NoEncounterCellVisitPlan _nonePlan(CellVisit visit) => NoEncounterCellVisitPlan(
      cellVisit: visit,
      selectorId: SelectorId('selector:legacy-cell-encounter'),
      selectorCandidateId: SelectorCandidateId('candidate:none'),
    );

final _legacyEncounter = Encounter(
  type: EncounterType.species,
  speciesId: 'amberwing_warbler',
  displayName: 'Amberwing Warbler',
  cellId: 'cell-1',
  seed: 'seed-1',
);

LegacyEncounterComputation _legacySelection() =>
    LegacyEncounterComputation.selected(
      selectorCandidateId: SelectorCandidateId('candidate:warbler'),
      definitionId: _definitionId,
      legacyEncounter: _legacyEncounter,
    );

LegacyEncounterComputation _legacyNone() =>
    const LegacyEncounterComputation.noSelection();

EncounterRuntimeAggregate _aggregate({
  required CellVisit visit,
  required CellVisitEncounterSelectionPlan selection,
  EncounterOccurrence? encounter,
  Iterable<EncounterOutcomeResult> results = const [],
  Iterable<GeneratedItemCommit> commits = const [],
  Iterable<RevealedVenueCommit> revealedVenueCommits = const [],
}) =>
    EncounterRuntimeAggregate(
      cellVisitResolution: selection is NoEncounterCellVisitPlan
          ? CellVisitResolution.none(
              id: CellVisitResolutionId('resolution-1'),
              cellVisitId: CellVisitId(visit.id),
              selectorId: selection.selectorId,
              selectorCandidateId: selection.selectorCandidateId,
              resolvedAt: visit.visitedAt,
            )
          : CellVisitResolution.selectedDefinition(
              id: CellVisitResolutionId('resolution-1'),
              cellVisitId: CellVisitId(visit.id),
              selectorId: selection.selectorId,
              selectorCandidateId: selection.selectorCandidateId,
              definitionId:
                  (selection as EncounterSelectedCellVisitPlan).definitionId,
              resolvedAt: visit.visitedAt,
            ),
      encounter: encounter,
      outcomeResults: results,
      generatedItemCommits: commits,
      revealedVenueCommits: revealedVenueCommits,
    );

EncounterOccurrence _encounter(EncounterResolutionStatus status) =>
    EncounterOccurrence(
      id: EncounterId('encounter-1'),
      cellVisitId: CellVisitId('visit-1'),
      cellVisitResolutionId: CellVisitResolutionId('resolution-1'),
      definitionVersion: _definitionVersion,
      status: status,
      createdAt: DateTime.utc(2026, 7, 20),
      selectedOptionId: status == EncounterResolutionStatus.resolved
          ? EncounterOptionId('option-1')
          : null,
      resolvedAt: status == EncounterResolutionStatus.resolved
          ? DateTime.utc(2026, 7, 20, 0, 1)
          : null,
      failure: status == EncounterResolutionStatus.failed
          ? EncounterFailure(code: 'outcome_failed')
          : null,
    );

GeneratedItemCommit _itemCommit({
  String suffix = '1',
  int ordinal = 0,
}) {
  final result = GenerateItemOutcomeResult(
    id: EncounterOutcomeResultId('result-$suffix'),
    encounterId: EncounterId('encounter-1'),
    outcomeId: EncounterOutcomeId('outcome-$suffix'),
    ordinal: ordinal,
    createdAt: DateTime.utc(2026, 7, 20, 0, 1),
    resolvedBaseItemVersion: _baseItemVersion,
  );
  return GeneratedItemCommit(
    outcomeResult: result,
    item: Item(
      id: 'item-$suffix',
      definitionId: _baseItemId.value,
      displayName: 'Amberwing Warbler $suffix',
      category: ItemCategory.fauna,
      acquiredAt: DateTime.utc(2026, 7, 20, 0, 1),
      status: ItemStatus.active,
    ),
  );
}

RevealedVenueCommit _revealedVenueCommit() {
  final result = RevealVenueOutcomeResult(
    id: EncounterOutcomeResultId('result:reveal-venue'),
    encounterId: EncounterId('encounter-1'),
    outcomeId: EncounterOutcomeId('outcome:reveal-venue'),
    ordinal: 0,
    createdAt: DateTime.utc(2026, 7, 20, 0, 1),
    venueId: _venueId,
    resolvedVenueVersion: _venueVersion,
  );
  return RevealedVenueCommit(
    outcomeResult: result,
    knownAt: DateTime.utc(2026, 7, 20, 0, 1),
  );
}

final class _FakeRepository implements EncounterRepository {
  _FakeRepository({required this.selectionResult, required this.outcomeResult});

  final EncounterRuntimeAggregate selectionResult;
  final EncounterRuntimeAggregate outcomeResult;
  int selectionCalls = 0;
  int outcomeCalls = 0;

  final List<String> selectionTraceIds = <String>[];
  final List<String> outcomeTraceIds = <String>[];

  @override
  Future<EncounterRuntimeAggregate> commitCellVisitSelection(
    CellVisitEncounterSelectionPlan plan, {
    required String traceId,
  }) async {
    selectionCalls += 1;
    selectionTraceIds.add(traceId);
    return selectionResult;
  }

  @override
  Future<EncounterRuntimeAggregate> resolveEncounterOutcomes(
    EncounterId encounterId, {
    required String traceId,
    EncounterOptionId? selectedOptionId,
  }) async {
    outcomeCalls += 1;
    outcomeTraceIds.add(traceId);
    return outcomeResult;
  }

  @override
  Future<PendingEncounter?> readPendingEncounterForCell(
    String cellId, {
    required String traceId,
  }) async =>
      null;
}

void main() {
  group('EncounterEntryCoordinator', () {
    test('VersionedEncounterPlan.none rejects a selected plan', () {
      expect(
        () => VersionedEncounterPlan.none(_selectionPlan(_visit())),
        throwsArgumentError,
      );
    });

    test('legacy computes and lets legacy remain the only item writer',
        () async {
      final context = _context();
      final plan = _selectionPlan(context.persistedCellVisit);
      final repository = _FakeRepository(
        selectionResult:
            _aggregate(visit: context.persistedCellVisit, selection: plan),
        outcomeResult:
            _aggregate(visit: context.persistedCellVisit, selection: plan),
      );
      var legacyWrites = 0;
      var planned = 0;
      final coordinator = EncounterEntryCoordinator(
        mode: EncounterEngineModeResolution.parse(
          requestedValue: 'legacy',
          clientVerifiedWriteAuthorized: false,
        ),
        legacyCompute: (_) async => _legacySelection(),
        legacyWriter: (_, __) async => legacyWrites += 1,
        versionedPlanner: (_) async {
          planned += 1;
          return VersionedEncounterPlan.selected(
              selection: plan, isAutomatic: true);
        },
        repository: repository,
        committedRewardsPresenter: (_, __, ___) async {},
        traceSink: (_) {},
      );

      final result = await coordinator.enter(context);

      expect(result.itemMutationOwner, EncounterItemMutationOwner.legacy);
      expect(legacyWrites, 1);
      expect(planned, 0);
      expect(repository.selectionCalls, 0);
      expect(repository.outcomeCalls, 0);
    });

    test('shadow planning compares plans but cannot mutate through v3',
        () async {
      final context = _context();
      final plan = _selectionPlan(context.persistedCellVisit);
      final repository = _FakeRepository(
        selectionResult:
            _aggregate(visit: context.persistedCellVisit, selection: plan),
        outcomeResult:
            _aggregate(visit: context.persistedCellVisit, selection: plan),
      );
      var legacyWrites = 0;
      final traces = <EncounterEntryTrace>[];
      final coordinator = EncounterEntryCoordinator(
        mode: EncounterEngineModeResolution.parse(
          requestedValue: 'shadowPlanning',
          clientVerifiedWriteAuthorized: false,
        ),
        legacyCompute: (_) async => _legacySelection(),
        legacyWriter: (_, __) async => legacyWrites += 1,
        versionedPlanner: (_) async =>
            VersionedEncounterPlan.selected(selection: plan, isAutomatic: true),
        repository: repository,
        committedRewardsPresenter: (_, __, ___) async {},
        traceSink: traces.add,
      );

      final result = await coordinator.enter(context);

      expect(result.itemMutationOwner, EncounterItemMutationOwner.legacy);
      expect(legacyWrites, 1);
      expect(repository.selectionCalls, 0);
      expect(repository.outcomeCalls, 0);
      expect(traces.whereType<EncounterComparisonTrace>(), hasLength(1));
      expect(
        result.comparison!.exactVersion,
        EncounterExactVersionComparison
            .notComparableLegacyDoesNotBindExactVersion,
      );
    });

    test('shadow planner failure still executes legacy exactly once', () async {
      final context = _context();
      final plan = _selectionPlan(context.persistedCellVisit);
      final repository = _FakeRepository(
        selectionResult:
            _aggregate(visit: context.persistedCellVisit, selection: plan),
        outcomeResult:
            _aggregate(visit: context.persistedCellVisit, selection: plan),
      );
      var legacyWrites = 0;
      final traces = <EncounterEntryTrace>[];
      final coordinator = EncounterEntryCoordinator(
        mode: EncounterEngineModeResolution.parse(
          requestedValue: 'shadowPlanning',
          clientVerifiedWriteAuthorized: false,
        ),
        legacyCompute: (_) async => _legacySelection(),
        legacyWriter: (_, __) async => legacyWrites += 1,
        versionedPlanner: (_) async => throw StateError('planner unavailable'),
        repository: repository,
        committedRewardsPresenter: (_, __, ___) async {},
        traceSink: traces.add,
      );

      final result = await coordinator.enter(context);

      expect(result.terminal,
          EncounterEntryTerminal.shadowPlanningFailedLegacyExecuted);
      expect(legacyWrites, 1);
      expect(repository.selectionCalls, 0);
      expect(traces.whereType<EncounterTerminalTrace>(), hasLength(1));
    });

    test(
        'authorized v3 validates, presents, and traces all generated Items in authored order',
        () async {
      final context = _context();
      final plan = _selectionPlan(context.persistedCellVisit);
      final first = _itemCommit(suffix: 'first', ordinal: 0);
      final second = _itemCommit(suffix: 'second', ordinal: 2);
      final reveal = _revealedVenueCommit();
      final repository = _FakeRepository(
        selectionResult: _aggregate(
          visit: context.persistedCellVisit,
          selection: plan,
          encounter: _encounter(EncounterResolutionStatus.pending),
        ),
        outcomeResult: _aggregate(
          visit: context.persistedCellVisit,
          selection: plan,
          encounter: _encounter(EncounterResolutionStatus.resolved),
          results: [
            first.outcomeResult,
            reveal.outcomeResult,
            second.outcomeResult
          ],
          commits: [first, second],
          revealedVenueCommits: [reveal],
        ),
      );
      var legacyWrites = 0;
      final presented = <GeneratedItemCommit>[];
      final traces = <EncounterEntryTrace>[];
      final coordinator = EncounterEntryCoordinator(
        mode: EncounterEngineModeResolution.parse(
          requestedValue: 'v3Authoritative',
          clientVerifiedWriteAuthorized: true,
        ),
        legacyCompute: (_) async => _legacySelection(),
        legacyWriter: (_, __) async => legacyWrites += 1,
        versionedPlanner: (_) async =>
            VersionedEncounterPlan.selected(selection: plan, isAutomatic: true),
        repository: repository,
        committedRewardsPresenter: (_, legacy, items) async {
          presented.addAll(items);
          expect(legacy.legacyEncounter, _legacyEncounter);
        },
        traceSink: traces.add,
      );

      final result = await coordinator.enter(context);

      expect(result.itemMutationOwner,
          EncounterItemMutationOwner.encounterRepository);
      expect(result.terminal, EncounterEntryTerminal.presentedCommittedItems);
      expect(legacyWrites, 0);
      expect(repository.selectionCalls, 1);
      expect(repository.outcomeCalls, 1);
      expect(presented, [first, second]);
      expect(result.presentedGeneratedItems, [first, second]);
      expect(
        [
          ...repository.selectionTraceIds,
          ...repository.outcomeTraceIds,
          ...traces.map((trace) => trace.context.rootTrace.traceId),
        ],
        everyElement('root-trace'),
      );
    });

    test('an unauthorized v3 request is gated into shadow planning', () async {
      final context = _context();
      final plan = _selectionPlan(context.persistedCellVisit);
      final repository = _FakeRepository(
        selectionResult:
            _aggregate(visit: context.persistedCellVisit, selection: plan),
        outcomeResult:
            _aggregate(visit: context.persistedCellVisit, selection: plan),
      );
      var legacyWrites = 0;
      final coordinator = EncounterEntryCoordinator(
        mode: EncounterEngineModeResolution.parse(
          requestedValue: 'v3Authoritative',
          clientVerifiedWriteAuthorized: false,
        ),
        legacyCompute: (_) async => _legacySelection(),
        legacyWriter: (_, __) async => legacyWrites += 1,
        versionedPlanner: (_) async =>
            VersionedEncounterPlan.selected(selection: plan, isAutomatic: true),
        repository: repository,
        committedRewardsPresenter: (_, __, ___) async {},
        traceSink: (_) {},
      );

      final result = await coordinator.enter(context);

      expect(result.mode.gateReason, isNotNull);
      expect(legacyWrites, 1);
      expect(repository.selectionCalls, 0);
    });

    test('explicit None commits no outcome and presents no reward', () async {
      final context = _context();
      final plan = _nonePlan(context.persistedCellVisit);
      final repository = _FakeRepository(
        selectionResult:
            _aggregate(visit: context.persistedCellVisit, selection: plan),
        outcomeResult:
            _aggregate(visit: context.persistedCellVisit, selection: plan),
      );
      var presented = 0;
      final coordinator = EncounterEntryCoordinator(
        mode: EncounterEngineModeResolution.parse(
          requestedValue: 'v3Authoritative',
          clientVerifiedWriteAuthorized: true,
        ),
        legacyCompute: (_) async => _legacyNone(),
        legacyWriter: (_, __) async => fail('legacy must not write'),
        versionedPlanner: (_) async => VersionedEncounterPlan.none(plan),
        repository: repository,
        committedRewardsPresenter: (_, __, ___) async => presented += 1,
        traceSink: (_) {},
      );

      final result = await coordinator.enter(context);

      expect(result.terminal, EncounterEntryTerminal.explicitNone);
      expect(result.itemMutationOwner, EncounterItemMutationOwner.none);
      expect(repository.selectionCalls, 1);
      expect(repository.outcomeCalls, 0);
      expect(presented, 0);
    });

    for (final status in [
      EncounterResolutionStatus.failed,
      EncounterResolutionStatus.pending,
    ]) {
      test('${status.name} final state produces no success reward', () async {
        final context = _context();
        final plan = _selectionPlan(context.persistedCellVisit);
        final repository = _FakeRepository(
          selectionResult: _aggregate(
            visit: context.persistedCellVisit,
            selection: plan,
            encounter: _encounter(EncounterResolutionStatus.pending),
          ),
          outcomeResult: _aggregate(
            visit: context.persistedCellVisit,
            selection: plan,
            encounter: _encounter(status),
          ),
        );
        var presented = 0;
        final coordinator = EncounterEntryCoordinator(
          mode: EncounterEngineModeResolution.parse(
            requestedValue: 'v3Authoritative',
            clientVerifiedWriteAuthorized: true,
          ),
          legacyCompute: (_) async => _legacySelection(),
          legacyWriter: (_, __) async => fail('legacy must not write'),
          versionedPlanner: (_) async => VersionedEncounterPlan.selected(
              selection: plan, isAutomatic: true),
          repository: repository,
          committedRewardsPresenter: (_, __, ___) async => presented += 1,
          traceSink: (_) {},
        );

        final result = await coordinator.enter(context);

        expect(
            result.terminal,
            status == EncounterResolutionStatus.failed
                ? EncounterEntryTerminal.failedOutcomeResolution
                : EncounterEntryTerminal.pendingOutcomeResolution);
        expect(presented, 0);
      });
    }

    test('definition mismatch fails closed before the repository can mutate',
        () async {
      final context = _context();
      final plan = _selectionPlan(context.persistedCellVisit);
      final repository = _FakeRepository(
        selectionResult:
            _aggregate(visit: context.persistedCellVisit, selection: plan),
        outcomeResult:
            _aggregate(visit: context.persistedCellVisit, selection: plan),
      );
      final coordinator = EncounterEntryCoordinator(
        mode: EncounterEngineModeResolution.parse(
          requestedValue: 'v3Authoritative',
          clientVerifiedWriteAuthorized: true,
        ),
        legacyCompute: (_) async => LegacyEncounterComputation.selected(
          selectorCandidateId: SelectorCandidateId('candidate:other'),
          definitionId: StableContentId<EncounterContent>('encounter:other'),
          legacyEncounter: _legacyEncounter,
        ),
        legacyWriter: (_, __) async => fail('legacy must not write'),
        versionedPlanner: (_) async =>
            VersionedEncounterPlan.selected(selection: plan, isAutomatic: true),
        repository: repository,
        committedRewardsPresenter: (_, __, ___) async =>
            fail('must not present'),
        traceSink: (_) {},
      );

      final result = await coordinator.enter(context);

      expect(result.terminal, EncounterEntryTerminal.definitionMismatch);
      expect(result.comparison!.definition,
          EncounterDefinitionComparison.mismatch);
      expect(repository.selectionCalls, 0);
    });

    test(
        'candidate-only mismatch fails closed before the repository can mutate',
        () async {
      final context = _context();
      final plan = _selectionPlan(context.persistedCellVisit);
      final repository = _FakeRepository(
        selectionResult:
            _aggregate(visit: context.persistedCellVisit, selection: plan),
        outcomeResult:
            _aggregate(visit: context.persistedCellVisit, selection: plan),
      );
      final coordinator = EncounterEntryCoordinator(
        mode: EncounterEngineModeResolution.parse(
          requestedValue: 'v3Authoritative',
          clientVerifiedWriteAuthorized: true,
        ),
        legacyCompute: (_) async => LegacyEncounterComputation.selected(
          selectorCandidateId: SelectorCandidateId('candidate:other'),
          definitionId: _definitionId,
          legacyEncounter: _legacyEncounter,
        ),
        legacyWriter: (_, __) async => fail('legacy must not write'),
        versionedPlanner: (_) async =>
            VersionedEncounterPlan.selected(selection: plan, isAutomatic: true),
        repository: repository,
        committedRewardsPresenter: (_, __, ___) async =>
            fail('must not present'),
        traceSink: (_) {},
      );

      final result = await coordinator.enter(context);

      expect(result.terminal, EncounterEntryTerminal.selectionMismatch);
      expect(
          result.comparison!.candidate, EncounterCandidateComparison.mismatch);
      expect(repository.selectionCalls, 0);
    });

    test('missing or duplicate generated Item evidence fails closed', () async {
      final context = _context();
      final plan = _selectionPlan(context.persistedCellVisit);
      final one = _itemCommit();
      for (final commits in <List<GeneratedItemCommit>>[
        [],
        [one, one],
      ]) {
        final repository = _FakeRepository(
          selectionResult: _aggregate(
            visit: context.persistedCellVisit,
            selection: plan,
            encounter: _encounter(EncounterResolutionStatus.pending),
          ),
          outcomeResult: _aggregate(
            visit: context.persistedCellVisit,
            selection: plan,
            encounter: _encounter(EncounterResolutionStatus.resolved),
            results: [one.outcomeResult],
            commits: commits,
          ),
        );
        var presented = 0;
        final coordinator = EncounterEntryCoordinator(
          mode: EncounterEngineModeResolution.parse(
            requestedValue: 'v3Authoritative',
            clientVerifiedWriteAuthorized: true,
          ),
          legacyCompute: (_) async => _legacySelection(),
          legacyWriter: (_, __) async => fail('legacy must not write'),
          versionedPlanner: (_) async => VersionedEncounterPlan.selected(
              selection: plan, isAutomatic: true),
          repository: repository,
          committedRewardsPresenter: (_, __, ___) async => presented += 1,
          traceSink: (_) {},
        );

        final result = await coordinator.enter(context);

        expect(
          result.terminal,
          EncounterEntryTerminal.committedOutcomeEvidenceMismatch,
        );
        expect(presented, 0);
      }
    });

    test('resolved Reveal Venue evidence succeeds without an Item presenter',
        () async {
      final context = _context();
      final plan = _selectionPlan(context.persistedCellVisit);
      final reveal = _revealedVenueCommit();
      final repository = _FakeRepository(
        selectionResult: _aggregate(
          visit: context.persistedCellVisit,
          selection: plan,
          encounter: _encounter(EncounterResolutionStatus.pending),
        ),
        outcomeResult: _aggregate(
          visit: context.persistedCellVisit,
          selection: plan,
          encounter: _encounter(EncounterResolutionStatus.resolved),
          results: [reveal.outcomeResult],
          revealedVenueCommits: [reveal],
        ),
      );
      var presented = 0;
      final coordinator = EncounterEntryCoordinator(
        mode: EncounterEngineModeResolution.parse(
          requestedValue: 'v3Authoritative',
          clientVerifiedWriteAuthorized: true,
        ),
        legacyCompute: (_) async => _legacySelection(),
        legacyWriter: (_, __) async => fail('legacy must not write'),
        versionedPlanner: (_) async =>
            VersionedEncounterPlan.selected(selection: plan, isAutomatic: true),
        repository: repository,
        committedRewardsPresenter: (_, __, ___) async => presented += 1,
        traceSink: (_) {},
      );

      final result = await coordinator.enter(context);

      expect(result.terminal, EncounterEntryTerminal.revealedVenueCommitted);
      expect(
        result.itemMutationOwner,
        EncounterItemMutationOwner.encounterRepositoryRevealVenue,
      );
      expect(presented, 0);
    });

    test('mismatched Reveal Venue evidence fails closed without presentation',
        () async {
      final context = _context();
      final plan = _selectionPlan(context.persistedCellVisit);
      final reveal = _revealedVenueCommit();
      final repository = _FakeRepository(
        selectionResult: _aggregate(
          visit: context.persistedCellVisit,
          selection: plan,
          encounter: _encounter(EncounterResolutionStatus.pending),
        ),
        outcomeResult: _aggregate(
          visit: context.persistedCellVisit,
          selection: plan,
          encounter: _encounter(EncounterResolutionStatus.resolved),
          revealedVenueCommits: [reveal],
        ),
      );
      var presented = 0;
      final coordinator = EncounterEntryCoordinator(
        mode: EncounterEngineModeResolution.parse(
          requestedValue: 'v3Authoritative',
          clientVerifiedWriteAuthorized: true,
        ),
        legacyCompute: (_) async => _legacySelection(),
        legacyWriter: (_, __) async => fail('legacy must not write'),
        versionedPlanner: (_) async =>
            VersionedEncounterPlan.selected(selection: plan, isAutomatic: true),
        repository: repository,
        committedRewardsPresenter: (_, __, ___) async => presented += 1,
        traceSink: (_) {},
      );

      final result = await coordinator.enter(context);

      expect(
        result.terminal,
        EncounterEntryTerminal.committedOutcomeEvidenceMismatch,
      );
      expect(result.itemMutationOwner, EncounterItemMutationOwner.unknown);
      expect(presented, 0);
    });
  });
}
