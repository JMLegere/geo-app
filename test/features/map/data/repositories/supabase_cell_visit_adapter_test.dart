import 'package:earth_nova/features/map/data/repositories/supabase_cell_visit_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupabaseCellVisitAdapter', () {
    test('recordVisit delegates to injected query', () async {
      final calls = <({String userId, String cellId})>[];
      final adapter = SupabaseCellVisitAdapter(
        client: null,
        recordVisitQuery: (userId, cellId) async {
          calls.add((userId: userId, cellId: cellId));
        },
      );

      await adapter.recordVisit(userId: 'user-1', cellId: 'cell-1');

      expect(calls, [(userId: 'user-1', cellId: 'cell-1')]);
    });

    test('getVisitedCellIds maps injected rows to unique ids', () async {
      final adapter = SupabaseCellVisitAdapter(
        client: null,
        visitedCellIdsQuery: (userId) async {
          expect(userId, 'user-1');
          return [
            {'cell_id': 'cell-1'},
            {'cell_id': 'cell-2'},
            {'cell_id': 'cell-1'},
          ];
        },
      );

      final result = await adapter.getVisitedCellIds(userId: 'user-1');

      expect(result, {'cell-1', 'cell-2'});
    });

    test('isFirstVisit returns true when injected lookup returns no rows', () async {
      final adapter = SupabaseCellVisitAdapter(
        client: null,
        firstVisitQuery: (userId, cellId) async {
          expect(userId, 'user-1');
          expect(cellId, 'cell-new');
          return [];
        },
      );

      final result = await adapter.isFirstVisit(
        userId: 'user-1',
        cellId: 'cell-new',
      );

      expect(result, isTrue);
    });

    test('isFirstVisit returns false when injected lookup finds a row', () async {
      final adapter = SupabaseCellVisitAdapter(
        client: null,
        firstVisitQuery: (_, __) async => [
          {'id': 'visit-1'},
        ],
      );

      final result = await adapter.isFirstVisit(
        userId: 'user-1',
        cellId: 'cell-known',
      );

      expect(result, isFalse);
    });

    test('throws when recordVisit has neither client nor injected query', () async {
      final adapter = SupabaseCellVisitAdapter(client: null);

      await expectLater(
        () => adapter.recordVisit(userId: 'user-1', cellId: 'cell-1'),
        throwsA(isA<StateError>()),
      );
    });

    test('throws when visited ids lookup has neither client nor injected query',
        () async {
      final adapter = SupabaseCellVisitAdapter(client: null);

      await expectLater(
        () => adapter.getVisitedCellIds(userId: 'user-1'),
        throwsA(isA<StateError>()),
      );
    });

    test('throws when first visit lookup has neither client nor injected query',
        () async {
      final adapter = SupabaseCellVisitAdapter(client: null);

      await expectLater(
        () => adapter.isFirstVisit(userId: 'user-1', cellId: 'cell-1'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
