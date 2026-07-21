import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_visit.dart';
import 'package:earth_nova/features/map/domain/repositories/cell_repository.dart';
import 'package:earth_nova/features/map/domain/use_cases/record_cell_visit.dart';

class TestObservabilityService extends ObservabilityService {
  TestObservabilityService() : super(sessionId: 'test-session');

  final logs = <Map<String, Object?>>[];

  @override
  void log(String event, String category, {Map<String, dynamic>? data}) {
    logs.add({'event': event, 'category': category, 'data': data});
  }
}

class FakeCellRepository implements CellRepository {
  FakeCellRepository({this.shouldThrow = false});

  final bool shouldThrow;
  final _visits = <String, Set<String>>{};
  var _sequence = 0;
  String? lastRecordTraceId;
  var recordVisitCalls = 0;
  String? lastRecordClientEventId;
  CellVisit? lastRecordedVisit;
  @override
  Future<List<Cell>> fetchCellsInRadius(
          double lat, double lng, double radiusMeters,
          {String? traceId}) async =>
      [];

  @override
  Future<CellVisit> recordVisit(
    String userId,
    String cellId,
    String clientEventId, {
    String? traceId,
  }) async {
    recordVisitCalls++;
    lastRecordTraceId = traceId;
    lastRecordClientEventId = clientEventId;
    if (shouldThrow) throw Exception('Fake record error');
    _visits.putIfAbsent(userId, () => {}).add(cellId);
    final visit = CellVisit(
      id: 'visit-${++_sequence}',
      userId: userId,
      cellId: cellId,
      clientEventId: clientEventId,
      visitedAt: DateTime.utc(2026, 7, 20, 12, 34, _sequence),
    );
    lastRecordedVisit = visit;
    return visit;
  }

  @override
  Future<Set<String>> getVisitedCellIds(String userId,
      {String? traceId}) async {
    return _visits[userId] ?? {};
  }

  @override
  Future<bool> isFirstVisit(String userId, String cellId,
      {String? traceId}) async {
    return !(_visits[userId]?.contains(cellId) ?? false);
  }
}

void main() {
  group('RecordCellVisit', () {
    test('forwards the client event and returns the exact repository visit',
        () async {
      final repo = FakeCellRepository();
      final obs = TestObservabilityService();
      final useCase = RecordCellVisit(repo, obs);

      final visit = await useCase.call(
        (
          userId: 'user-1',
          cellId: 'cell-1',
          clientEventId: 'event-1',
        ),
      );

      expect(visit, same(repo.lastRecordedVisit));
      expect(visit.id, 'visit-1');
      expect(visit.userId, 'user-1');
      expect(visit.cellId, 'cell-1');
      expect(visit.visitedAt, DateTime.utc(2026, 7, 20, 12, 34, 1));
      expect(visit.clientEventId, 'event-1');
      expect(repo.lastRecordClientEventId, 'event-1');
      expect(obs.logs[0]['event'], 'operation.started');
      expect(obs.logs[1]['event'], 'operation.completed');
      expect(repo.lastRecordTraceId, isNotNull);
    });

    test('propagates repository exceptions', () async {
      final repo = FakeCellRepository(shouldThrow: true);
      final obs = TestObservabilityService();
      final useCase = RecordCellVisit(repo, obs);

      await expectLater(
        () => useCase.call(
          (userId: 'user-1', cellId: 'cell-1', clientEventId: 'event-1'),
        ),
        throwsException,
      );
      expect(obs.logs[0]['event'], 'operation.started');
      expect(obs.logs[1]['event'], 'operation.failed');
    });

    test('rejects blank or untrimmed client events before recording', () async {
      final repo = FakeCellRepository();
      final obs = TestObservabilityService();
      final useCase = RecordCellVisit(repo, obs);

      for (final clientEventId in ['  ', ' event-1', 'event-1 ']) {
        await expectLater(
          () => useCase.call(
            (
              userId: 'user-1',
              cellId: 'cell-1',
              clientEventId: clientEventId,
            ),
          ),
          throwsArgumentError,
        );
      }

      expect(repo.recordVisitCalls, 0);
      expect(
        obs.logs.where((log) => log['event'] == 'operation.failed'),
        hasLength(3),
      );
    });
  });
}
