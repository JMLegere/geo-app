import 'package:earth_nova/features/map/data/repositories/supabase_cell_visit_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupabaseCellVisitAdapter', () {
    test('recordVisit invokes the canonical RPC without user ownership params',
        () async {
      final calls = <({String functionName, Map<String, Object?> params})>[];
      final visitedAt = DateTime.utc(2026, 7, 20, 12, 34, 56);
      final adapter = SupabaseCellVisitAdapter(
        client: null,
        rpcQuery: (functionName, params) async {
          calls.add((functionName: functionName, params: params));
          return {
            'id': 'visit-1',
            'user_id': 'user-1',
            'cell_id': 'cell-1',
            'client_event_id': 'event-1',
            'visited_at': visitedAt.toIso8601String(),
          };
        },
      );

      final visit = await adapter.recordVisit(
        userId: 'user-1',
        cellId: 'cell-1',
        clientEventId: 'event-1',
      );

      expect(calls, hasLength(1));
      expect(calls.single.functionName, 'record_v3_cell_visit');
      expect(calls.single.params, {
        'p_cell_id': 'cell-1',
        'p_client_event_id': 'event-1',
      });
      expect(calls.single.params.containsKey('user_id'), isFalse);
      expect(visit.id, 'visit-1');
      expect(visit.userId, 'user-1');
      expect(visit.cellId, 'cell-1');
      expect(visit.clientEventId, 'event-1');
      expect(visit.visitedAt, visitedAt);
    });

    test(
        'recordVisit accepts the same canonical response for an idempotent retry',
        () async {
      var calls = 0;
      final row = <String, Object?>{
        'id': 'visit-1',
        'user_id': 'user-1',
        'cell_id': 'cell-1',
        'client_event_id': 'event-1',
        'visited_at': DateTime.utc(2026, 7, 20, 12, 34).toIso8601String(),
      };
      final adapter = SupabaseCellVisitAdapter(
        client: null,
        rpcQuery: (_, __) async {
          calls++;
          return row;
        },
      );

      final first = await adapter.recordVisit(
        userId: 'user-1',
        cellId: 'cell-1',
        clientEventId: 'event-1',
      );
      final retry = await adapter.recordVisit(
        userId: 'user-1',
        cellId: 'cell-1',
        clientEventId: 'event-1',
      );

      expect(calls, 2);
      expect(retry.id, first.id);
      expect(retry.clientEventId, first.clientEventId);
      expect(retry.visitedAt, first.visitedAt);
    });

    test('recordVisit rejects RPC rows with mismatched ownership or identity',
        () async {
      final canonical = <String, Object?>{
        'id': 'visit-1',
        'user_id': 'user-1',
        'cell_id': 'cell-1',
        'client_event_id': 'event-1',
        'visited_at': DateTime.utc(2026).toIso8601String(),
      };
      final mismatches = <String, Map<String, Object?>>{
        'user': {...canonical, 'user_id': 'other-user'},
        'cell': {...canonical, 'cell_id': 'other-cell'},
        'client event': {...canonical, 'client_event_id': 'other-event'},
      };

      for (final mismatch in mismatches.entries) {
        final adapter = SupabaseCellVisitAdapter(
          client: null,
          rpcQuery: (_, __) async => mismatch.value,
        );

        await expectLater(
          () => adapter.recordVisit(
            userId: 'user-1',
            cellId: 'cell-1',
            clientEventId: 'event-1',
          ),
          throwsA(isA<StateError>()),
          reason: '${mismatch.key} mismatches must fail closed',
        );
      }
    });

    test('recordVisit rejects malformed RPC payloads', () async {
      final adapter = SupabaseCellVisitAdapter(
        client: null,
        rpcQuery: (_, __) async => ['not a row object'],
      );

      await expectLater(
        () => adapter.recordVisit(
          userId: 'user-1',
          cellId: 'cell-1',
          clientEventId: 'event-1',
        ),
        throwsA(isA<FormatException>()),
      );
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

    test('isFirstVisit returns true when injected lookup returns no rows',
        () async {
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

    test('isFirstVisit returns false when injected lookup finds a row',
        () async {
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

    test('throws when recordVisit has neither client nor injected RPC',
        () async {
      final adapter = SupabaseCellVisitAdapter(client: null);

      await expectLater(
        () => adapter.recordVisit(
          userId: 'user-1',
          cellId: 'cell-1',
          clientEventId: 'event-1',
        ),
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
