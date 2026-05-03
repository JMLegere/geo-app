import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/habitat.dart';
import 'package:earth_nova/features/map/data/repositories/mock_cell_repository.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/repositories/cell_repository.dart';

Cell _testCell(String id) => Cell(
      id: id,
      habitats: [Habitat.forest],
      polygons: const [[[(lat: 1.0, lng: 2.0)]]],
      districtId: 'district-1',
      cityId: 'city-1',
      stateId: 'state-1',
      countryId: 'country-1',
    );

void main() {
  group('MockCellRepository', () {
    test('implements CellRepository interface', () {
      final repo = MockCellRepository();
      expect(repo, isA<CellRepository>());
    });

    group('fetchCellsInRadius', () {
      test('returns configured cells', () async {
        final cells = [_testCell('cell-1'), _testCell('cell-2')];
        final repo = MockCellRepository(cells: cells);
        final result = await repo.fetchCellsInRadius(1.0, 2.0, 2000);
        expect(result, cells);
      });

      test('returns empty list when no cells configured', () async {
        final repo = MockCellRepository();
        final result = await repo.fetchCellsInRadius(0.0, 0.0, 1000);
        expect(result, isEmpty);
      });

      test('throws when configured to throw', () async {
        final repo = MockCellRepository(shouldThrow: true);
        expect(
          () => repo.fetchCellsInRadius(0.0, 0.0, 1000),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('recordVisit', () {
      test('records a visit and makes it retrievable', () async {
        final repo = MockCellRepository();
        await repo.recordVisit('user-1', 'cell-1');
        final visited = await repo.getVisitedCellIds('user-1');
        expect(visited, contains('cell-1'));
      });

      test('recording multiple visits for same cell still returns cell once',
          () async {
        final repo = MockCellRepository();
        await repo.recordVisit('user-1', 'cell-1');
        await repo.recordVisit('user-1', 'cell-1');
        final visited = await repo.getVisitedCellIds('user-1');
        expect(visited.where((id) => id == 'cell-1').length, 1);
      });

      test('visits are scoped per user', () async {
        final repo = MockCellRepository();
        await repo.recordVisit('user-1', 'cell-1');
        await repo.recordVisit('user-2', 'cell-2');
        final user1Visited = await repo.getVisitedCellIds('user-1');
        final user2Visited = await repo.getVisitedCellIds('user-2');
        expect(user1Visited, contains('cell-1'));
        expect(user1Visited, isNot(contains('cell-2')));
        expect(user2Visited, contains('cell-2'));
        expect(user2Visited, isNot(contains('cell-1')));
      });

      test('throws when configured to throw', () async {
        final repo = MockCellRepository(shouldThrow: true);
        expect(
          () => repo.recordVisit('user-1', 'cell-1'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('getVisitedCellIds', () {
      test('returns empty set for user with no visits', () async {
        final repo = MockCellRepository();
        final result = await repo.getVisitedCellIds('user-unknown');
        expect(result, isEmpty);
      });

      test('returns set of visited cell ids', () async {
        final repo = MockCellRepository();
        await repo.recordVisit('user-1', 'cell-a');
        await repo.recordVisit('user-1', 'cell-b');
        final result = await repo.getVisitedCellIds('user-1');
        expect(result, {'cell-a', 'cell-b'});
      });
    });

    group('isFirstVisit', () {
      test('returns true for unvisited cell', () async {
        final repo = MockCellRepository();
        final result = await repo.isFirstVisit('user-1', 'cell-new');
        expect(result, isTrue);
      });

      test('returns false after cell has been visited', () async {
        final repo = MockCellRepository();
        await repo.recordVisit('user-1', 'cell-1');
        final result = await repo.isFirstVisit('user-1', 'cell-1');
        expect(result, isFalse);
      });
    });
  });
}
