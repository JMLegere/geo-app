import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/repositories/cell_repository.dart';
import 'package:earth_nova/features/map/domain/use_cases/record_cell_visit.dart';
import 'package:earth_nova/features/map/presentation/providers/visit_queue_provider.dart';

class TestObservabilityService extends ObservabilityService {
  TestObservabilityService() : super(sessionId: 'test-session');

  final List<({String event, String category, Map<String, dynamic>? data})>
      events = [];

  @override
  void log(String event, String category, {Map<String, dynamic>? data}) {
    events.add((event: event, category: category, data: data));
    super.log(event, category, data: data);
  }

  List<String> get eventNames => events.map((e) => e.event).toList();
}

class _ControlledCellRepository implements CellRepository {
  bool shouldThrow = false;
  final List<({String userId, String cellId})> recordedVisits = [];

  @override
  Future<List<Cell>> fetchCellsInRadius(
          double lat, double lng, double radiusMeters,
          {String? traceId}) async =>
      [];

  @override
  Future<void> recordVisit(String userId, String cellId,
      {String? traceId}) async {
    if (shouldThrow) throw Exception('network error');
    recordedVisits.add((userId: userId, cellId: cellId));
  }

  @override
  Future<Set<String>> getVisitedCellIds(String userId,
          {String? traceId}) async =>
      {};

  @override
  Future<bool> isFirstVisit(String userId, String cellId,
          {String? traceId}) async =>
      true;
}

void main() {
  group('VisitQueueNotifier', () {
    late ProviderContainer container;
    late TestObservabilityService testObs;
    late _ControlledCellRepository repo;

    setUp(() {
      testObs = TestObservabilityService();
      repo = _ControlledCellRepository();
      container = ProviderContainer(
        overrides: [
          visitQueueObservabilityProvider.overrideWithValue(testObs),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state has empty queue', () {
      final state = container.read(visitQueueProvider);
      expect(state.pendingCount, equals(0));
      expect(state.items, isEmpty);
    });

    test('enqueue adds item to queue', () {
      final notifier = container.read(visitQueueProvider.notifier);
      notifier.enqueue(userId: 'user-1', cellId: 'cell-1');

      final state = container.read(visitQueueProvider);
      expect(state.pendingCount, equals(1));
      expect(state.items.first.userId, equals('user-1'));
      expect(state.items.first.cellId, equals('cell-1'));
    });

    test('enqueue multiple items accumulates queue', () {
      final notifier = container.read(visitQueueProvider.notifier);
      notifier.enqueue(userId: 'user-1', cellId: 'cell-1');
      notifier.enqueue(userId: 'user-1', cellId: 'cell-2');
      notifier.enqueue(userId: 'user-1', cellId: 'cell-3');

      final state = container.read(visitQueueProvider);
      expect(state.pendingCount, equals(3));
    });

    test('flush retries all queued items when network succeeds', () async {
      final notifier = container.read(visitQueueProvider.notifier);
      notifier.enqueue(userId: 'user-1', cellId: 'cell-1');
      notifier.enqueue(userId: 'user-1', cellId: 'cell-2');
      notifier.enqueue(userId: 'user-1', cellId: 'cell-3');

      repo.shouldThrow = false;
      final useCase = RecordCellVisit(repo, testObs);
      await notifier.flush(useCase);

      final state = container.read(visitQueueProvider);
      expect(state.pendingCount, equals(0));
      expect(repo.recordedVisits.length, equals(3));
    });

    test('flush keeps items in queue when network fails', () async {
      final notifier = container.read(visitQueueProvider.notifier);
      notifier.enqueue(userId: 'user-1', cellId: 'cell-1');
      notifier.enqueue(userId: 'user-1', cellId: 'cell-2');

      repo.shouldThrow = true;
      final useCase = RecordCellVisit(repo, testObs);
      await notifier.flush(useCase);

      final state = container.read(visitQueueProvider);
      expect(state.pendingCount, equals(2));
    });

    test('flush partial success: removes succeeded, keeps failed', () async {
      final notifier = container.read(visitQueueProvider.notifier);
      notifier.enqueue(userId: 'user-1', cellId: 'cell-1');
      notifier.enqueue(userId: 'user-1', cellId: 'cell-2');

      // First call succeeds, second fails
      final partialRepo = _PartialFailRepo(failAfter: 1);
      final useCase = RecordCellVisit(partialRepo, testObs);
      await notifier.flush(useCase);

      final state = container.read(visitQueueProvider);
      // First item removed, second kept
      expect(state.pendingCount, equals(1));
      expect(state.items.first.cellId, equals('cell-2'));
    });

    test('flush emits queue.flushed event on success', () async {
      final notifier = container.read(visitQueueProvider.notifier);
      notifier.enqueue(userId: 'user-1', cellId: 'cell-1');

      repo.shouldThrow = false;
      final useCase = RecordCellVisit(repo, testObs);
      await notifier.flush(useCase);

      expect(testObs.eventNames, contains('visit_queue.flushed'));
    });

    test('flush emits queue.retry_failed event when all fail', () async {
      final notifier = container.read(visitQueueProvider.notifier);
      notifier.enqueue(userId: 'user-1', cellId: 'cell-1');

      repo.shouldThrow = true;
      final useCase = RecordCellVisit(repo, testObs);
      await notifier.flush(useCase);

      expect(testObs.eventNames, contains('visit_queue.retry_failed'));
    });

    test('flush on empty queue is a no-op', () async {
      final notifier = container.read(visitQueueProvider.notifier);
      final useCase = RecordCellVisit(repo, testObs);
      await notifier.flush(useCase);

      final state = container.read(visitQueueProvider);
      expect(state.pendingCount, equals(0));
    });

    test('enqueue emits visit_queue.enqueued event', () {
      final notifier = container.read(visitQueueProvider.notifier);
      notifier.enqueue(userId: 'user-1', cellId: 'cell-1');

      expect(testObs.eventNames, contains('visit_queue.enqueued'));
    });

    test('enqueue emits map.visit_queue_enqueued with cell_id and queue_size',
        () {
      final notifier = container.read(visitQueueProvider.notifier);
      notifier.enqueue(userId: 'user-1', cellId: 'cell-1');
      notifier.enqueue(userId: 'user-1', cellId: 'cell-2');

      expect(testObs.eventNames, contains('map.visit_queue_enqueued'));
      final events = testObs.events
          .where((e) => e.event == 'map.visit_queue_enqueued')
          .toList();
      expect(events, hasLength(2));
      expect(events.last.data?['cell_id'], 'cell-2');
      expect(events.last.data?['queue_size'], 2);
    });

    test('flush emits map.visit_queue_flush_started with queue_size', () async {
      final notifier = container.read(visitQueueProvider.notifier);
      notifier.enqueue(userId: 'user-1', cellId: 'cell-1');
      notifier.enqueue(userId: 'user-1', cellId: 'cell-2');

      repo.shouldThrow = false;
      final useCase = RecordCellVisit(repo);
      await notifier.flush(useCase);

      expect(testObs.eventNames, contains('map.visit_queue_flush_started'));
      final event = testObs.events
          .firstWhere((e) => e.event == 'map.visit_queue_flush_started');
      expect(event.data?['queue_size'], 2);
    });

    test('flush emits map.visit_queue_flush_success on full success', () async {
      final notifier = container.read(visitQueueProvider.notifier);
      notifier.enqueue(userId: 'user-1', cellId: 'cell-1');
      notifier.enqueue(userId: 'user-1', cellId: 'cell-2');

      repo.shouldThrow = false;
      final useCase = RecordCellVisit(repo);
      await notifier.flush(useCase);

      expect(testObs.eventNames, contains('map.visit_queue_flush_success'));
      final event = testObs.events
          .firstWhere((e) => e.event == 'map.visit_queue_flush_success');
      expect(event.data?['flushed_count'], 2);
      expect(event.data?['remaining'], 0);
    });

    test('flush emits map.visit_queue_flush_success on partial success',
        () async {
      final notifier = container.read(visitQueueProvider.notifier);
      notifier.enqueue(userId: 'user-1', cellId: 'cell-1');
      notifier.enqueue(userId: 'user-1', cellId: 'cell-2');

      final partialRepo = _PartialFailRepo(failAfter: 1);
      final useCase = RecordCellVisit(partialRepo);
      await notifier.flush(useCase);

      expect(testObs.eventNames, contains('map.visit_queue_flush_success'));
      final event = testObs.events
          .firstWhere((e) => e.event == 'map.visit_queue_flush_success');
      expect(event.data?['flushed_count'], 1);
      expect(event.data?['remaining'], 1);
    });

    test('flush emits map.visit_queue_item_failed for each failed item',
        () async {
      final notifier = container.read(visitQueueProvider.notifier);
      notifier.enqueue(userId: 'user-1', cellId: 'cell-1');
      notifier.enqueue(userId: 'user-1', cellId: 'cell-2');

      repo.shouldThrow = true;
      final useCase = RecordCellVisit(repo);
      await notifier.flush(useCase);

      final failEvents = testObs.events
          .where((e) => e.event == 'map.visit_queue_item_failed')
          .toList();
      expect(failEvents, hasLength(2));
      expect(failEvents.first.data?['cell_id'], isNotEmpty);
      expect(failEvents.first.data?['error'], isNotEmpty);
    });

    test(
        'flush does not emit map.visit_queue_flush_success when all items fail',
        () async {
      final notifier = container.read(visitQueueProvider.notifier);
      notifier.enqueue(userId: 'user-1', cellId: 'cell-1');

      repo.shouldThrow = true;
      final useCase = RecordCellVisit(repo);
      await notifier.flush(useCase);

      expect(
        testObs.eventNames,
        isNot(contains('map.visit_queue_flush_success')),
      );
    });
  });
}

class _PartialFailRepo implements CellRepository {
  _PartialFailRepo({required this.failAfter});
  final int failAfter;
  int _callCount = 0;

  @override
  Future<List<Cell>> fetchCellsInRadius(
          double lat, double lng, double radiusMeters,
          {String? traceId}) async =>
      [];

  @override
  Future<void> recordVisit(String userId, String cellId,
      {String? traceId}) async {
    _callCount++;
    if (_callCount > failAfter) throw Exception('network error');
  }

  @override
  Future<Set<String>> getVisitedCellIds(String userId,
          {String? traceId}) async =>
      {};

  @override
  Future<bool> isFirstVisit(String userId, String cellId,
          {String? traceId}) async =>
      true;
}
