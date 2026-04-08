import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/repositories/cell_repository.dart';
import 'package:earth_nova/features/map/domain/use_cases/get_visited_cells.dart';
import 'package:flutter_test/flutter_test.dart';

class TestObservabilityService extends ObservabilityService {
  TestObservabilityService() : super(sessionId: 'test-session');

  final logs = <Map<String, Object?>>[];

  @override
  void log(String event, String category, {Map<String, dynamic>? data}) {
    logs.add({'event': event, 'category': category, 'data': data});
  }
}

class FakeCellRepository implements CellRepository {
  FakeCellRepository({
    this.visitedCellIds = const {},
    this.shouldThrow = false,
  });

  final Set<String> visitedCellIds;
  final bool shouldThrow;

  @override
  Future<List<Cell>> fetchCellsInRadius(
    double lat,
    double lng,
    double radiusMeters, {
    String? traceId,
  }) async {
    return const [];
  }

  @override
  Future<Set<String>> getVisitedCellIds(String userId,
      {String? traceId}) async {
    if (shouldThrow) throw Exception('Fake get visited error');
    return visitedCellIds;
  }

  @override
  Future<bool> isFirstVisit(String userId, String cellId,
      {String? traceId}) async {
    return !visitedCellIds.contains(cellId);
  }

  @override
  Future<void> recordVisit(String userId, String cellId,
      {String? traceId}) async {}
}

void main() {
  group('GetVisitedCells', () {
    test('delegates to repository and logs operation lifecycle', () async {
      final obs = TestObservabilityService();
      final useCase = GetVisitedCells(
        FakeCellRepository(visitedCellIds: {'c1', 'c2'}),
        obs,
      );

      final result = await useCase.call((userId: 'u1'));

      expect(result, {'c1', 'c2'});
      expect(obs.logs[0]['event'], 'operation.started');
      expect(obs.logs[1]['event'], 'operation.completed');
    });

    test('logs failure and rethrows repository exceptions', () async {
      final obs = TestObservabilityService();
      final useCase = GetVisitedCells(
        FakeCellRepository(shouldThrow: true),
        obs,
      );

      await expectLater(() => useCase.call((userId: 'u1')), throwsException);
      expect(obs.logs[0]['event'], 'operation.started');
      expect(obs.logs[1]['event'], 'operation.failed');
    });
  });
}
