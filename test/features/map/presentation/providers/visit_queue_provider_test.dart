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
          double lat, double lng, double radiusMeters) async =>
      [];

  @override
  Future<void> recordVisit(String userId, String cellId) async {
    if (shouldThrow) throw Exception('network error');
    recordedVisits.add((userId: userId, cellId: cellId));
  }

  @override
  Future<Set<String>> getVisitedCellIds(String userId) async => {};

  @override
  Future<bool> isFirstVisit(String userId, String cellId) async => true;
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
      final useCase = RecordCellVisit(repo);
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
      final useCase = RecordCellVisit(repo);
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
      final useCase = RecordCellVisit(partialRepo);
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
      final useCase = RecordCellVisit(repo);
      await notifier.flush(useCase);

      expect(testObs.eventNames, contains('visit_queue.flushed'));
    });

    test('flush emits queue.retry_failed event when all fail', () async {
      final notifier = container.read(visitQueueProvider.notifier);
      notifier.enqueue(userId: 'user-1', cellId: 'cell-1');

      repo.shouldThrow = true;
      final useCase = RecordCellVisit(repo);
      await notifier.flush(useCase);

      expect(testObs.eventNames, contains('visit_queue.retry_failed'));
    });

    test('flush on empty queue is a no-op', () async {
      final notifier = container.read(visitQueueProvider.notifier);
      final useCase = RecordCellVisit(repo);
      await notifier.flush(useCase);

      final state = container.read(visitQueueProvider);
      expect(state.pendingCount, equals(0));
    });

    test('enqueue emits visit_queue.enqueued event', () {
      final notifier = container.read(visitQueueProvider.notifier);
      notifier.enqueue(userId: 'user-1', cellId: 'cell-1');

      expect(testObs.eventNames, contains('visit_queue.enqueued'));
    });
  });
}

class _PartialFailRepo implements CellRepository {
  _PartialFailRepo({required this.failAfter});
  final int failAfter;
  int _callCount = 0;

  @override
  Future<List<Cell>> fetchCellsInRadius(
          double lat, double lng, double radiusMeters) async =>
      [];

  @override
  Future<void> recordVisit(String userId, String cellId) async {
    _callCount++;
    if (_callCount > failAfter) throw Exception('network error');
  }

  @override
  Future<Set<String>> getVisitedCellIds(String userId) async => {};

  @override
  Future<bool> isFirstVisit(String userId, String cellId) async => true;
}
