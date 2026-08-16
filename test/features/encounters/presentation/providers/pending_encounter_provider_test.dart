import 'dart:async';
import 'dart:io';

import 'package:earth_nova/core/domain/content/content_identity.dart';
import 'package:earth_nova/core/domain/content/encounter_content.dart';
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
  _FakeEncounterRepository(this.onRead);

  final Future<PendingEncounter?> Function(String cellId) onRead;
  final List<String> readCellIds = [];

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
  }) =>
      Future<EncounterRuntimeAggregate>.error(
        StateError('pending state must not resolve'),
      );
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

ProviderContainer _containerFor(
  _FakeEncounterRepository repository, {
  required bool canRecordVisits,
}) =>
    ProviderContainer(
      overrides: [
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
