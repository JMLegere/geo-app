import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_visit.dart';

import 'package:earth_nova/features/map/domain/repositories/cell_repository.dart';

class MockCellRepository implements CellRepository {
  MockCellRepository({this.cells = const [], this.shouldThrow = false});

  final List<Cell> cells;
  final bool shouldThrow;
  final _visits = <String, Set<String>>{};
  final _visitsByClientEvent = <String, Map<String, CellVisit>>{};
  var _visitSequence = 0;

  @override
  Future<List<Cell>> fetchCellsInRadius(
      double lat, double lng, double radiusMeters,
      {String? traceId}) async {
    if (shouldThrow) throw Exception('Mock fetch error');
    return cells;
  }

  @override
  Future<CellVisit> recordVisit(
    String userId,
    String cellId,
    String clientEventId, {
    String? traceId,
  }) async {
    if (shouldThrow) throw Exception('Mock record error');

    final userVisits =
        _visitsByClientEvent.putIfAbsent(userId, () => <String, CellVisit>{});
    final existingVisit = userVisits[clientEventId];
    if (existingVisit != null) {
      if (existingVisit.cellId != cellId) {
        throw StateError('Cell Visit client event belongs to a different cell');
      }
      return existingVisit;
    }

    _visits.putIfAbsent(userId, () => {}).add(cellId);
    final visit = CellVisit(
      id: 'mock-visit-${++_visitSequence}',
      cellId: cellId,
      userId: userId,
      clientEventId: clientEventId,
      visitedAt: DateTime.now().toUtc(),
    );
    userVisits[clientEventId] = visit;
    return visit;
  }

  @override
  Future<Set<String>> getVisitedCellIds(String userId,
      {String? traceId}) async {
    if (shouldThrow) throw Exception('Mock get error');
    return _visits[userId] ?? {};
  }

  @override
  Future<bool> isFirstVisit(String userId, String cellId,
      {String? traceId}) async {
    if (shouldThrow) throw Exception('Mock isFirstVisit error');
    return !(_visits[userId]?.contains(cellId) ?? false);
  }
}
