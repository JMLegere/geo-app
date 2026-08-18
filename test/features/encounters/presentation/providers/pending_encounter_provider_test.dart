import 'dart:async';
import 'dart:io';

import 'package:earth_nova/app/readiness/app_readiness.dart';
import 'package:earth_nova/core/domain/content/base_item_content.dart';
import 'package:earth_nova/core/domain/content/content_identity.dart';
import 'package:earth_nova/core/domain/content/encounter_content.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/encounters/domain/entities/encounter_entities.dart';
import 'package:earth_nova/features/encounters/domain/repositories/encounter_repository.dart';
import 'package:earth_nova/features/encounters/domain/use_cases/resolve_cell_visit_encounter_selector.dart';
import 'package:earth_nova/features/encounters/presentation/providers/encounter_entry_provider.dart';
import 'package:earth_nova/features/encounters/presentation/providers/pending_encounter_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/exploration_eligibility_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/exploration_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _definitionVersion = ExactVersionRef<EncounterContent>(
  stableId: StableContentId<EncounterContent>('encounter:red_fox'),
  versionId: ContentVersionId<EncounterContent>('version:red_fox:2'),
  revision: 2,
);

final class _NoopObservabilityService extends ObservabilityService {
  _NoopObservabilityService() : super(sessionId: 'pending-encounter-test');

  @override
  void log(String event, String category, {Map<String, dynamic>? data}) {}
}

final class _FakeEncounterRepository implements EncounterRepository {
  _FakeEncounterRepository(this.onRead, {this.onResolve});

  final Future<PendingEncounter?> Function(String cellId) onRead;
  final Future<EncounterRuntimeAggregate> Function(
    EncounterId encounterId, {
    required String traceId,
    EncounterOptionId? selectedOptionId,
  })? onResolve;
  final List<String> readCellIds = [];
  final resolveCalls = <({
    EncounterId encounterId,
    EncounterOptionId? optionId,
    String traceId
  })>[];

  @override
  Future<EncounterRuntimeAggregate> commitCellVisitSelection(
    CellVisitEncounterSelectionPlan plan, {
    required String traceId,
  }) =>
      Future<EncounterRuntimeAggregate>.error(
        StateError('pending state must not commit'),
      );

  @override
  Future<PendingEncounter?> readPendingEncounterForCell(
    String cellId, {
    required String traceId,
  }) {
    readCellIds.add(cellId);
    return onRead(cellId);
  }

  @override
  Future<EncounterRuntimeAggregate> resolveEncounterOutcomes(
    EncounterId encounterId, {
    required String traceId,
    EncounterOptionId? selectedOptionId,
  }) {
    resolveCalls.add((
      encounterId: encounterId,
      optionId: selectedOptionId,
      traceId: traceId,
    ));
    return onResolve?.call(
          encounterId,
          traceId: traceId,
          selectedOptionId: selectedOptionId,
        ) ??
        Future<EncounterRuntimeAggregate>.error(
          StateError('pending state must not resolve'),
        );
  }
}

final class _TestExplorationNotifier extends ExplorationNotifier {
  static _TestExplorationNotifier? current;

  @override
  ExplorationStateData build() {
    current = this;
    return const ExplorationStateData();
  }

  void showCell(String? cellId) {
    transition(
      ExplorationStateData(currentCellId: cellId),
      'test.exploration.cell_changed',
    );
  }
}

final class _TestAppReadinessNotifier extends AppReadinessNotifier {
  _TestAppReadinessNotifier(this.phase);

  final AppReadinessPhase phase;

  @override
  AppReadinessState build() => AppReadinessState(
        phase: phase,
        completedCheckpoints: AppReadinessState.requiredCheckpoints,
      );

  @override
  Future<void> start(String userId) async {}
}

ProviderContainer _containerFor(
  _FakeEncounterRepository repository, {
  required bool canRecordVisits,
  Future<void> Function(PendingEncounter, GeneratedItemCommit)? presentReward,
  AppReadinessPhase readiness = AppReadinessPhase.usable,
}) =>
    ProviderContainer(
      overrides: [
        appReadinessProvider.overrideWith(
          () => _TestAppReadinessNotifier(readiness),
        ),
        if (presentReward != null)
          committedPendingEncounterRewardPresenterProvider.overrideWithValue(
            presentReward,
          ),
        encounterCommandRepositoryProvider.overrideWithValue(repository),
        explorationProvider.overrideWith(_TestExplorationNotifier.new),
        explorationEligibilityProvider.overrideWithValue(
          ExplorationEligibility(
            canRecordVisits: canRecordVisits,
            isPaused: !canRecordVisits,
            reason: null,
          ),
        ),
        explorationObservabilityProvider.overrideWithValue(
          _NoopObservabilityService(),
        ),
      ],
    );

_TestExplorationNotifier _exploration(ProviderContainer container) {
  container.read(explorationProvider);
  return _TestExplorationNotifier.current!;
}

Future<void> _drain() => Future<void>.delayed(Duration.zero);

PendingEncounter _pending(String cellId) => PendingEncounter(
      cellId: cellId,
      encounter: EncounterOccurrence(
        id: EncounterId('encounter:$cellId'),
        cellVisitId: CellVisitId('visit:$cellId'),
        cellVisitResolutionId: CellVisitResolutionId('resolution:$cellId'),
        definitionVersion: _definitionVersion,
        status: EncounterResolutionStatus.pending,
        createdAt: DateTime.utc(2026, 8, 16),
      ),
      definitionDisplayName: 'Red Fox',
      options: [
        PendingEncounterOption(
          id: EncounterOptionId('option:observe'),
          ordinal: 0,
          displayName: 'Observe quietly',
        ),
      ],
    );

final _baseItemVersion = ExactVersionRef<BaseItemContent>(
  stableId: StableContentId<BaseItemContent>('item:red_fox'),
  versionId: ContentVersionId<BaseItemContent>('version:red_fox:2'),
  revision: 2,
);

EncounterRuntimeAggregate _resolvedAggregate(
  PendingEncounter pending, {
  EncounterOptionId? optionId,
  bool includeOutcomeEvidence = true,
  int generatedItemCount = 1,
}) {
  final selectedOptionId = optionId ?? pending.options.single.id;
  final results = List<GenerateItemOutcomeResult>.generate(
    generatedItemCount,
    (index) => GenerateItemOutcomeResult(
      id: EncounterOutcomeResultId('result:${pending.cellId}:$index'),
      encounterId: pending.encounter.id,
      outcomeId: EncounterOutcomeId('outcome:${pending.cellId}:$index'),
      ordinal: index,
      createdAt: DateTime.utc(2026, 8, 16, 0, 1),
      resolvedBaseItemVersion: _baseItemVersion,
    ),
  );
  final commits = results
      .map(
        (result) => GeneratedItemCommit(
          outcomeResult: result,
          item: Item(
            id: 'item:${pending.cellId}:${result.ordinal}',
            definitionId: _baseItemVersion.stableId.value,
            displayName: 'Red Fox Feather',
            category: ItemCategory.fauna,
            acquiredAt: result.createdAt,
            status: ItemStatus.active,
          ),
        ),
      )
      .toList();

  return EncounterRuntimeAggregate(
    cellVisitResolution: CellVisitResolution.selectedDefinition(
      id: pending.encounter.cellVisitResolutionId,
      cellVisitId: pending.encounter.cellVisitId,
      selectorId: SelectorId('selector:pending'),
      selectorCandidateId: SelectorCandidateId('candidate:pending'),
      definitionId: pending.encounter.definitionVersion.stableId,
      resolvedAt: DateTime.utc(2026, 8, 16, 0, 1),
    ),
    encounter: EncounterOccurrence(
      id: pending.encounter.id,
      cellVisitId: pending.encounter.cellVisitId,
      cellVisitResolutionId: pending.encounter.cellVisitResolutionId,
      definitionVersion: pending.encounter.definitionVersion,
      status: EncounterResolutionStatus.resolved,
      createdAt: pending.encounter.createdAt,
      selectedOptionId: selectedOptionId,
      resolvedAt: DateTime.utc(2026, 8, 16, 0, 1),
    ),
    outcomeResults: includeOutcomeEvidence ? results : const [],
    generatedItemCommits: commits,
    revealedVenueCommits: const [],
  );
}

void main() {
  group('pending encounter provider', () {
    test('loads trusted initial Present cell and transitions loading to ready',
        () async {
      final pending = _pending('cell-1');
      final repository = _FakeEncounterRepository(
        (_) => Future<PendingEncounter?>.value(pending),
      );
      final container = _containerFor(repository, canRecordVisits: true);
      addTearDown(container.dispose);
      _exploration(container).showCell('cell-1');
      final states = <PendingEncounterState>[];
      container.listen<PendingEncounterState>(
        pendingEncounterProvider,
        (_, next) => states.add(next),
        fireImmediately: true,
      );

      await _drain();

      expect(repository.readCellIds, ['cell-1']);
      expect(states, contains(isA<PendingEncounterLoading>()));
      expect(states, contains(isA<PendingEncounterReady>()));
      final state = container.read(pendingEncounterProvider);
      expect(state, isA<PendingEncounterReady>());
      expect((state as PendingEncounterReady).pendingEncounter, same(pending));
    });

    test('ignores a pending encounter outside the trusted Present cell',
        () async {
      final pending = _pending('cell-2');
      final repository = _FakeEncounterRepository(
        (_) => Future<PendingEncounter?>.value(pending),
      );
      final container = _containerFor(repository, canRecordVisits: true);
      addTearDown(container.dispose);
      _exploration(container).showCell('cell-2');
      expect(container.read(pendingEncounterProvider),
          isA<PendingEncounterNone>());

      container
          .read(pendingEncounterProvider.notifier)
          .show(_pending('cell-1'));

      expect(container.read(pendingEncounterProvider),
          isA<PendingEncounterNone>());
      await _drain();
      final state = container.read(pendingEncounterProvider);
      expect(state, isA<PendingEncounterReady>());
      expect((state as PendingEncounterReady).pendingEncounter, same(pending));
    });

    test('untrusted or paused cell skips reads and stays typed none', () async {
      final untrustedRepository = _FakeEncounterRepository(
        (_) => Future<PendingEncounter?>.value(_pending('cell-1')),
      );
      final untrusted = _containerFor(
        untrustedRepository,
        canRecordVisits: true,
      );
      addTearDown(untrusted.dispose);

      expect(untrusted.read(pendingEncounterProvider),
          isA<PendingEncounterNone>());
      await _drain();
      expect(untrustedRepository.readCellIds, isEmpty);

      final pausedRepository = _FakeEncounterRepository(
        (_) => Future<PendingEncounter?>.value(_pending('cell-1')),
      );
      final paused = _containerFor(pausedRepository, canRecordVisits: false);
      addTearDown(paused.dispose);
      _exploration(paused).showCell('cell-1');
      expect(
          paused.read(pendingEncounterProvider), isA<PendingEncounterNone>());
      await _drain();
      expect(pausedRepository.readCellIds, isEmpty);
    });

    test('same-cell load is suppressed until an explicit refresh', () async {
      final firstRead = Completer<PendingEncounter?>();
      var reads = 0;
      final repository = _FakeEncounterRepository((_) {
        reads += 1;
        return reads == 1
            ? firstRead.future
            : Future<PendingEncounter?>.value(null);
      });
      final container = _containerFor(repository, canRecordVisits: true);
      addTearDown(container.dispose);
      _exploration(container).showCell('cell-1');
      container.read(pendingEncounterProvider);
      await _drain();

      final duplicateLoad =
          container.read(pendingEncounterProvider.notifier).load();
      expect(repository.readCellIds, ['cell-1']);
      firstRead.complete(_pending('cell-1'));
      await duplicateLoad;
      await _drain();

      await container.read(pendingEncounterProvider.notifier).refresh();
      expect(repository.readCellIds, ['cell-1', 'cell-1']);
    });

    test('stale completion cannot replace the current cell pending encounter',
        () async {
      final firstRead = Completer<PendingEncounter?>();
      final secondRead = Completer<PendingEncounter?>();
      final repository = _FakeEncounterRepository(
        (cellId) => cellId == 'cell-1' ? firstRead.future : secondRead.future,
      );
      final container = _containerFor(repository, canRecordVisits: true);
      addTearDown(container.dispose);
      final exploration = _exploration(container);
      exploration.showCell('cell-1');
      container.read(pendingEncounterProvider);
      await _drain();
      exploration.showCell('cell-2');
      await _drain();

      secondRead.complete(_pending('cell-2'));
      await _drain();
      firstRead.complete(_pending('cell-1'));
      await _drain();

      expect(repository.readCellIds, ['cell-1', 'cell-2']);
      final state = container.read(pendingEncounterProvider);
      expect(state, isA<PendingEncounterReady>());
      expect(
          (state as PendingEncounterReady).pendingEncounter.cellId, 'cell-2');
    });

    test('read failure has typed failure state', () async {
      final repository = _FakeEncounterRepository(
        (_) => Future<PendingEncounter?>.error(StateError('unavailable')),
      );
      final container = _containerFor(repository, canRecordVisits: true);
      addTearDown(container.dispose);
      _exploration(container).showCell('cell-1');
      container.read(pendingEncounterProvider);

      await _drain();

      expect(container.read(pendingEncounterProvider),
          isA<PendingEncounterFailure>());
    });

    test('degraded readiness blocks the encounter mutation boundary', () async {
      final pending = _pending('cell-1');
      final repository = _FakeEncounterRepository(
        (_) => Future<PendingEncounter?>.value(pending),
        onResolve: (_, {required traceId, selectedOptionId}) =>
            Future<EncounterRuntimeAggregate>.value(
          _resolvedAggregate(pending),
        ),
      );
      final container = _containerFor(
        repository,
        canRecordVisits: true,
        readiness: AppReadinessPhase.degraded,
      );
      addTearDown(container.dispose);
      _exploration(container).showCell(pending.cellId);
      container.read(pendingEncounterProvider);
      await _drain();

      await container
          .read(pendingEncounterProvider.notifier)
          .resolve(pending.options.single.id);

      expect(repository.resolveCalls, isEmpty);
      expect(
        container.read(pendingEncounterProvider),
        isA<PendingEncounterReady>(),
      );
    });

    test('resolves ready encounter through resolving to resolved then presents',
        () async {
      final pending = _pending('cell-1');
      final committed = Completer<EncounterRuntimeAggregate>();
      final presented =
          <({PendingEncounter pending, GeneratedItemCommit item})>[];
      final repository = _FakeEncounterRepository(
        (_) => Future<PendingEncounter?>.value(pending),
        onResolve: (_, {required traceId, selectedOptionId}) =>
            committed.future,
      );
      final container = _containerFor(
        repository,
        canRecordVisits: true,
        presentReward: (resolvedPending, item) async {
          presented.add((pending: resolvedPending, item: item));
        },
      );
      addTearDown(container.dispose);
      _exploration(container).showCell(pending.cellId);
      container.read(pendingEncounterProvider);
      await _drain();

      final resolution = container
          .read(pendingEncounterProvider.notifier)
          .resolve(pending.options.single.id);
      expect(container.read(pendingEncounterProvider),
          isA<PendingEncounterResolving>());
      expect(repository.resolveCalls, hasLength(1));

      committed.complete(_resolvedAggregate(pending));
      await resolution;
      expect(container.read(pendingEncounterProvider),
          isA<PendingEncounterResolved>());
      expect(presented.single.item.item.id, 'item:cell-1:0');
      expect(presented.single.pending, same(pending));
    });

    test('rejects unowned options and incomplete committed aggregates',
        () async {
      final pending = _pending('cell-1');
      final presented = <GeneratedItemCommit>[];
      final repository = _FakeEncounterRepository(
        (_) => Future<PendingEncounter?>.value(pending),
        onResolve: (_, {required traceId, selectedOptionId}) =>
            Future<EncounterRuntimeAggregate>.value(
          _resolvedAggregate(
            pending,
            includeOutcomeEvidence: false,
          ),
        ),
      );
      final container = _containerFor(
        repository,
        canRecordVisits: true,
        presentReward: (_, item) async => presented.add(item),
      );
      addTearDown(container.dispose);
      _exploration(container).showCell(pending.cellId);
      container.read(pendingEncounterProvider);
      await _drain();

      await container
          .read(pendingEncounterProvider.notifier)
          .resolve(EncounterOptionId('option:other'));
      expect(repository.resolveCalls, isEmpty);
      expect(container.read(pendingEncounterProvider),
          isA<PendingEncounterReady>());

      await container
          .read(pendingEncounterProvider.notifier)
          .resolve(pending.options.single.id);
      expect(container.read(pendingEncounterProvider),
          isA<PendingEncounterFailure>());
      expect(presented, isEmpty);
    });

    test('suppresses duplicate and inflight resolution commands', () async {
      final pending = _pending('cell-1');
      final committed = Completer<EncounterRuntimeAggregate>();
      var presentations = 0;
      final repository = _FakeEncounterRepository(
        (_) => Future<PendingEncounter?>.value(pending),
        onResolve: (_, {required traceId, selectedOptionId}) =>
            committed.future,
      );
      final container = _containerFor(
        repository,
        canRecordVisits: true,
        presentReward: (_, __) async => presentations += 1,
      );
      addTearDown(container.dispose);
      _exploration(container).showCell(pending.cellId);
      container.read(pendingEncounterProvider);
      await _drain();

      final first = container
          .read(pendingEncounterProvider.notifier)
          .resolve(pending.options.single.id);
      final duplicate = container
          .read(pendingEncounterProvider.notifier)
          .resolve(pending.options.single.id);
      expect(repository.resolveCalls, hasLength(1));

      committed.complete(_resolvedAggregate(pending));
      await Future.wait([first, duplicate]);
      expect(presentations, 1);
      expect(container.read(pendingEncounterProvider),
          isA<PendingEncounterResolved>());
    });

    test('suppresses stale and untrusted resolution completions', () async {
      final pending = _pending('cell-1');
      final staleCommit = Completer<EncounterRuntimeAggregate>();
      var presentations = 0;
      final repository = _FakeEncounterRepository(
        (cellId) => Future<PendingEncounter?>.value(_pending(cellId)),
        onResolve: (_, {required traceId, selectedOptionId}) =>
            staleCommit.future,
      );
      final container = _containerFor(
        repository,
        canRecordVisits: true,
        presentReward: (_, __) async => presentations += 1,
      );
      addTearDown(container.dispose);
      final exploration = _exploration(container);
      exploration.showCell(pending.cellId);
      container.read(pendingEncounterProvider);
      await _drain();

      final stale = container
          .read(pendingEncounterProvider.notifier)
          .resolve(pending.options.single.id);
      exploration.showCell('cell-2');
      await _drain();
      staleCommit.complete(_resolvedAggregate(pending));
      await stale;

      expect(container.read(pendingEncounterProvider),
          isA<PendingEncounterReady>());
      expect(
        (container.read(pendingEncounterProvider) as PendingEncounterReady)
            .pendingEncounter
            .cellId,
        'cell-2',
      );
      expect(presentations, 0);

      final untrusted = _containerFor(repository, canRecordVisits: true);
      addTearDown(untrusted.dispose);
      untrusted.read(pendingEncounterProvider);
      await untrusted
          .read(pendingEncounterProvider.notifier)
          .resolve(pending.options.single.id);
      expect(repository.resolveCalls, hasLength(1));
    });

    test('failure preserves exact command identity for retry', () async {
      final pending = _pending('cell-1');
      var attempts = 0;
      var presentations = 0;
      final repository = _FakeEncounterRepository(
        (_) => Future<PendingEncounter?>.value(pending),
        onResolve: (_, {required traceId, selectedOptionId}) {
          attempts += 1;
          return attempts == 1
              ? Future<EncounterRuntimeAggregate>.error(StateError('offline'))
              : Future<EncounterRuntimeAggregate>.value(
                  _resolvedAggregate(pending),
                );
        },
      );
      final container = _containerFor(
        repository,
        canRecordVisits: true,
        presentReward: (_, __) async => presentations += 1,
      );
      addTearDown(container.dispose);
      _exploration(container).showCell(pending.cellId);
      container.read(pendingEncounterProvider);
      await _drain();

      await container
          .read(pendingEncounterProvider.notifier)
          .resolve(pending.options.single.id);
      expect(container.read(pendingEncounterProvider),
          isA<PendingEncounterFailure>());

      await container.read(pendingEncounterProvider.notifier).retryResolution();

      expect(repository.resolveCalls, hasLength(2));
      expect(repository.resolveCalls[1].encounterId,
          repository.resolveCalls.first.encounterId);
      expect(repository.resolveCalls[1].optionId,
          repository.resolveCalls.first.optionId);
      expect(repository.resolveCalls[1].traceId,
          repository.resolveCalls.first.traceId);
      expect(presentations, 1);
      expect(container.read(pendingEncounterProvider),
          isA<PendingEncounterResolved>());
    });

    test('does not replay a committed result after resolve, retry, or refresh',
        () async {
      final pending = _pending('cell-1');
      var presentations = 0;
      final repository = _FakeEncounterRepository(
        (_) => Future<PendingEncounter?>.value(pending),
        onResolve: (_, {required traceId, selectedOptionId}) =>
            Future<EncounterRuntimeAggregate>.value(
                _resolvedAggregate(pending)),
      );
      final container = _containerFor(
        repository,
        canRecordVisits: true,
        presentReward: (_, __) async => presentations += 1,
      );
      addTearDown(container.dispose);
      _exploration(container).showCell(pending.cellId);
      container.read(pendingEncounterProvider);
      await _drain();

      await container
          .read(pendingEncounterProvider.notifier)
          .resolve(pending.options.single.id);
      await container
          .read(pendingEncounterProvider.notifier)
          .resolve(pending.options.single.id);
      await container.read(pendingEncounterProvider.notifier).retryResolution();
      await container.read(pendingEncounterProvider.notifier).refresh();

      expect(repository.resolveCalls, hasLength(1));
      expect(presentations, 1);
      expect(container.read(pendingEncounterProvider),
          isA<PendingEncounterResolved>());
    });

    test('depends only on trusted current cell and visit eligibility', () {
      final source = File(
        'lib/features/encounters/presentation/providers/pending_encounter_provider.dart',
      ).readAsStringSync();

      expect(source, contains('explorationProvider'));
      expect(source, contains('currentCellId'));
      expect(source, contains('explorationEligibilityProvider'));
      expect(source, contains('canRecordVisits'));
      expect(source, isNot(contains('cameraFollowProvider')));
      expect(source, isNot(contains('mapProvider')));
      expect(source, isNot(contains('locationProvider')));
      expect(source, isNot(contains('playerMarkerProvider')));
    });
  });
}
