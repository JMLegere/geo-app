import 'package:earth_nova/core/domain/content/base_item_content.dart';
import 'package:earth_nova/core/domain/content/content_version_id.dart';
import 'package:earth_nova/core/domain/content/encounter_content.dart';
import 'package:earth_nova/core/domain/content/exact_version_ref.dart';
import 'package:earth_nova/core/domain/content/stable_content_id.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/core/observability/trace_context.dart';
import 'package:earth_nova/features/encounters/domain/entities/encounter_entities.dart';
import 'package:earth_nova/features/encounters/domain/repositories/encounter_repository.dart';
import 'package:earth_nova/features/encounters/domain/use_cases/resolve_cell_visit_encounter_selector.dart';
import 'package:earth_nova/features/encounters/domain/use_cases/resolve_pending_encounter.dart';
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
final _retryTrace = TraceContext(
  traceId: '0123456789abcdef0123456789abcdef',
  spanId: '0123456789abcdef',
  startTime: DateTime.utc(2026, 7, 20),
);

PendingEncounter _pending({
  String encounterId = 'encounter-1',
  Iterable<PendingEncounterOption>? options,
}) =>
    PendingEncounter(
      cellId: 'cell-1',
      encounter: _encounter(
        id: encounterId,
        status: EncounterResolutionStatus.pending,
      ),
      definitionDisplayName: 'Amberwing Warbler',
      options: options ?? [_option()],
    );

PendingEncounterOption _option({String id = 'option-1'}) =>
    PendingEncounterOption(
      id: EncounterOptionId(id),
      ordinal: 0,
      displayName: 'Observe',
    );

EncounterOccurrence _encounter({
  String id = 'encounter-1',
  required EncounterResolutionStatus status,
  String selectedOptionId = 'option-1',
}) =>
    EncounterOccurrence(
      id: EncounterId(id),
      cellVisitId: CellVisitId('visit-1'),
      cellVisitResolutionId: CellVisitResolutionId('resolution-1'),
      definitionVersion: _definitionVersion,
      status: status,
      createdAt: DateTime.utc(2026, 7, 20),
      selectedOptionId: status == EncounterResolutionStatus.resolved
          ? EncounterOptionId(selectedOptionId)
          : null,
      resolvedAt: status == EncounterResolutionStatus.resolved
          ? DateTime.utc(2026, 7, 20, 0, 1)
          : null,
      failure: status == EncounterResolutionStatus.failed
          ? EncounterFailure(code: 'outcome_failed')
          : null,
    );

GenerateItemOutcomeResult _outcome({
  String encounterId = 'encounter-1',
  String suffix = '1',
  int ordinal = 0,
}) =>
    GenerateItemOutcomeResult(
      id: EncounterOutcomeResultId('result-$suffix'),
      encounterId: EncounterId(encounterId),
      outcomeId: EncounterOutcomeId('outcome-$suffix'),
      ordinal: ordinal,
      createdAt: DateTime.utc(2026, 7, 20, 0, 1),
      resolvedBaseItemVersion: _baseItemVersion,
    );

GeneratedItemCommit _itemCommit({
  String encounterId = 'encounter-1',
  String suffix = '1',
  int ordinal = 0,
}) {
  final outcome = _outcome(
    encounterId: encounterId,
    suffix: suffix,
    ordinal: ordinal,
  );
  return GeneratedItemCommit(
    outcomeResult: outcome,
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

EncounterRuntimeAggregate _aggregate({
  required EncounterOccurrence encounter,
  Iterable<EncounterOutcomeResult>? outcomeResults,
  Iterable<GeneratedItemCommit>? generatedItemCommits,
}) {
  final commits =
      generatedItemCommits ?? [_itemCommit(encounterId: encounter.id.value)];
  return EncounterRuntimeAggregate(
    cellVisitResolution: CellVisitResolution.selectedDefinition(
      id: CellVisitResolutionId('resolution-1'),
      cellVisitId: CellVisitId('visit-1'),
      selectorId: SelectorId('selector:encounter'),
      selectorCandidateId: SelectorCandidateId('candidate:warbler'),
      definitionId: _definitionId,
      resolvedAt: DateTime.utc(2026, 7, 20),
    ),
    encounter: encounter,
    outcomeResults:
        outcomeResults ?? commits.map((commit) => commit.outcomeResult),
    generatedItemCommits: commits,
    revealedVenueCommits: const [],
  );
}

ResolvePendingEncounterInput _input(
  PendingEncounter pendingEncounter, {
  EncounterOptionId? optionId,
}) =>
    ResolvePendingEncounterInput(
      pendingEncounter: pendingEncounter,
      optionId: optionId ?? EncounterOptionId('option-1'),
    );

ResolvePendingEncounter _useCase(_FakeEncounterRepository repository) =>
    ResolvePendingEncounter(
      repository,
      ObservabilityService(sessionId: 'resolve-pending-encounter-test'),
    );

final class _FakeEncounterRepository implements EncounterRepository {
  _FakeEncounterRepository(this.outcomeResult);

  final EncounterRuntimeAggregate outcomeResult;
  final List<EncounterId> resolvedEncounterIds = [];
  final List<EncounterOptionId?> selectedOptionIds = [];
  final List<String> traceIds = [];

  @override
  Future<EncounterRuntimeAggregate> commitCellVisitSelection(
    CellVisitEncounterSelectionPlan plan, {
    required String traceId,
  }) =>
      throw UnimplementedError();

  @override
  Future<EncounterRuntimeAggregate> resolveEncounterOutcomes(
    EncounterId encounterId, {
    required String traceId,
    EncounterOptionId? selectedOptionId,
  }) async {
    resolvedEncounterIds.add(encounterId);
    selectedOptionIds.add(selectedOptionId);
    traceIds.add(traceId);
    return outcomeResult;
  }

  @override
  Future<PendingEncounter?> readPendingEncounterForCell(
    String cellId, {
    required String traceId,
  }) =>
      throw UnimplementedError();
}

void main() {
  group('ResolvePendingEncounter', () {
    test('forwards the selected pending option and returns its exact aggregate',
        () async {
      final pending = _pending();
      final aggregate = _aggregate(
        encounter: _encounter(status: EncounterResolutionStatus.resolved),
      );
      final repository = _FakeEncounterRepository(aggregate);

      final result = await _useCase(repository)(
        _input(pending),
        parent: _retryTrace,
      );

      expect(result, same(aggregate));
      expect(repository.resolvedEncounterIds, [pending.encounter.id]);
      expect(
        repository.selectedOptionIds,
        [EncounterOptionId('option-1')],
      );
      expect(repository.traceIds, [_retryTrace.traceId]);
    });

    test(
        'rejects an option outside the pending encounter before repository use',
        () async {
      final aggregate = _aggregate(
        encounter: _encounter(status: EncounterResolutionStatus.resolved),
      );
      final repository = _FakeEncounterRepository(aggregate);

      await expectLater(
        _useCase(repository)(
          _input(
            _pending(),
            optionId: EncounterOptionId('option-foreign'),
          ),
          parent: _retryTrace,
        ),
        throwsArgumentError,
      );

      expect(repository.resolvedEncounterIds, isEmpty);
    });

    test('rejects a pending returned encounter', () async {
      final pending = _pending();
      final repository = _FakeEncounterRepository(
        _aggregate(
          encounter: _encounter(status: EncounterResolutionStatus.pending),
        ),
      );

      await expectLater(
        _useCase(repository)(_input(pending), parent: _retryTrace),
        throwsStateError,
      );
    });

    test('rejects a resolved encounter for a different occurrence', () async {
      final repository = _FakeEncounterRepository(
        _aggregate(
          encounter: _encounter(
            id: 'encounter-other',
            status: EncounterResolutionStatus.resolved,
          ),
        ),
      );

      await expectLater(
        _useCase(repository)(_input(_pending()), parent: _retryTrace),
        throwsStateError,
      );
    });

    test('rejects a resolved encounter with another selected option', () async {
      final repository = _FakeEncounterRepository(
        _aggregate(
          encounter: _encounter(
            status: EncounterResolutionStatus.resolved,
            selectedOptionId: 'option-other',
          ),
        ),
      );

      await expectLater(
        _useCase(repository)(_input(_pending()), parent: _retryTrace),
        throwsStateError,
      );
    });

    test('rejects a failed returned encounter', () async {
      final pending = _pending();
      final repository = _FakeEncounterRepository(
        _aggregate(
          encounter: _encounter(status: EncounterResolutionStatus.failed),
        ),
      );

      await expectLater(
        _useCase(repository)(_input(pending), parent: _retryTrace),
        throwsStateError,
      );
    });

    test('rejects an aggregate without committed outcome evidence', () async {
      final pending = _pending();
      final repository = _FakeEncounterRepository(
        _aggregate(
          encounter: _encounter(status: EncounterResolutionStatus.resolved),
          outcomeResults: const [],
        ),
      );

      await expectLater(
        _useCase(repository)(_input(pending), parent: _retryTrace),
        throwsStateError,
      );
    });

    test('rejects an aggregate without exactly one generated item', () async {
      final pending = _pending();
      final resolved = _encounter(status: EncounterResolutionStatus.resolved);
      final zeroItems = _aggregate(
        encounter: resolved,
        outcomeResults: [_outcome()],
        generatedItemCommits: const [],
      );
      final multipleItems = _aggregate(
        encounter: resolved,
        generatedItemCommits: [
          _itemCommit(),
          _itemCommit(suffix: '2', ordinal: 1),
        ],
      );

      for (final aggregate in [zeroItems, multipleItems]) {
        await expectLater(
          _useCase(_FakeEncounterRepository(aggregate))(
            _input(pending),
            parent: _retryTrace,
          ),
          throwsStateError,
        );
      }
    });

    test('preserves identical encounter, option, and trace across retries',
        () async {
      final pending = _pending();
      final aggregate = _aggregate(
        encounter: _encounter(status: EncounterResolutionStatus.resolved),
      );
      final repository = _FakeEncounterRepository(aggregate);
      final useCase = _useCase(repository);

      await useCase(_input(pending), parent: _retryTrace);
      await useCase(_input(pending), parent: _retryTrace);

      expect(
        repository.resolvedEncounterIds,
        [pending.encounter.id, pending.encounter.id],
      );
      expect(repository.selectedOptionIds, [
        EncounterOptionId('option-1'),
        EncounterOptionId('option-1'),
      ]);
      expect(
        repository.traceIds,
        [_retryTrace.traceId, _retryTrace.traceId],
      );
    });
  });
}
