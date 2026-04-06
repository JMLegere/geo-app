import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/repositories/cell_repository.dart';

class MockCellRepository implements CellRepository {
  MockCellRepository({this.cells = const [], this.shouldThrow = false});

  final List<Cell> cells;
  final bool shouldThrow;
  final _visits = <String, Set<String>>{};

  @override
  Future<List<Cell>> fetchCellsInRadius(
    double lat,
    double lng,
    double radiusMeters,
  ) async {
    if (shouldThrow) throw Exception('Mock fetch error');
    return cells;
  }

  @override
  Future<void> recordVisit(String userId, String cellId) async {
    if (shouldThrow) throw Exception('Mock record error');
    _visits.putIfAbsent(userId, () => {}).add(cellId);
  }

  @override
  Future<Set<String>> getVisitedCellIds(String userId) async {
    if (shouldThrow) throw Exception('Mock get error');
    return _visits[userId] ?? {};
  }

  @override
  Future<bool> isFirstVisit(String userId, String cellId) async {
    if (shouldThrow) throw Exception('Mock isFirstVisit error');
    return !(_visits[userId]?.contains(cellId) ?? false);
  }
}
