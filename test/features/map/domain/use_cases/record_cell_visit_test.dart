import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/repositories/cell_repository.dart';
import 'package:earth_nova/features/map/domain/use_cases/record_cell_visit.dart';

class FakeCellRepository implements CellRepository {
  FakeCellRepository({this.shouldThrow = false});

  final bool shouldThrow;
  final _visits = <String, Set<String>>{};

  @override
  Future<List<Cell>> fetchCellsInRadius(
    double lat,
    double lng,
    double radiusMeters,
  ) async =>
      [];

  @override
  Future<void> recordVisit(String userId, String cellId) async {
    if (shouldThrow) throw Exception('Fake record error');
    _visits.putIfAbsent(userId, () => {}).add(cellId);
  }

  @override
  Future<Set<String>> getVisitedCellIds(String userId) async {
    return _visits[userId] ?? {};
  }

  @override
  Future<bool> isFirstVisit(String userId, String cellId) async {
    return !(_visits[userId]?.contains(cellId) ?? false);
  }
}

void main() {
  group('RecordCellVisit', () {
    test('delegates to repository recordVisit', () async {
      final repo = FakeCellRepository();
      final useCase = RecordCellVisit(repo);

      await useCase.call(userId: 'user-1', cellId: 'cell-1');

      final visited = await repo.getVisitedCellIds('user-1');
      expect(visited, contains('cell-1'));
    });

    test('propagates repository exceptions', () async {
      final repo = FakeCellRepository(shouldThrow: true);
      final useCase = RecordCellVisit(repo);

      expect(
        () => useCase.call(userId: 'user-1', cellId: 'cell-1'),
        throwsException,
      );
    });
  });
}
