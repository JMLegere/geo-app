import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
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

  @override
  Future<List<Cell>> fetchCellsInRadius(
          double lat, double lng, double radiusMeters,
          {String? traceId}) async =>
      [];

  @override
  Future<void> recordVisit(String userId, String cellId,
      {String? traceId}) async {
    if (shouldThrow) throw Exception('Fake record error');
    _visits.putIfAbsent(userId, () => {}).add(cellId);
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
    test('delegates to repository recordVisit', () async {
      final repo = FakeCellRepository();
      final obs = TestObservabilityService();
      final useCase = RecordCellVisit(repo, obs);

      await useCase.call((userId: 'user-1', cellId: 'cell-1'));

      final visited = await repo.getVisitedCellIds('user-1');
      expect(visited, contains('cell-1'));
      expect(obs.logs[0]['event'], 'operation.started');
      expect(obs.logs[1]['event'], 'operation.completed');
    });

    test('propagates repository exceptions', () async {
      final repo = FakeCellRepository(shouldThrow: true);
      final obs = TestObservabilityService();
      final useCase = RecordCellVisit(repo, obs);

      await expectLater(
        () => useCase.call((userId: 'user-1', cellId: 'cell-1')),
        throwsException,
      );
      expect(obs.logs[0]['event'], 'operation.started');
      expect(obs.logs[1]['event'], 'operation.failed');
    });
  });
}
