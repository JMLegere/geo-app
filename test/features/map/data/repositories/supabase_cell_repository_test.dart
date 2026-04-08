import 'package:earth_nova/features/map/data/repositories/supabase_cell_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupabaseCellRepository trace logging', () {
    test('logs query started/completed with trace_id and row_count', () async {
      final events = <Map<String, dynamic>>[];

      final repository = SupabaseCellRepository(
        client: null,
        fetchCellsQuery: (_, __, ___) async => [
          {'cell_id': 'a', 'habitats': <String>[], 'location_id': 'loc_a'},
          {'cell_id': 'b', 'habitats': <String>[], 'location_id': 'loc_b'},
        ],
        logEvent: (event, category, {data}) {
          events
              .add({'event': event, 'category': category, 'data': data ?? {}});
        },
      );

      final cells = await repository.fetchCellsInRadius(
        1,
        2,
        3,
        traceId: 'trace-123',
      );

      expect(cells, hasLength(2));
      expect(events, hasLength(2));
      expect(events[0]['event'], 'db.query_started');
      expect(events[0]['data']['trace_id'], 'trace-123');
      expect(events[1]['event'], 'db.query_completed');
      expect(events[1]['data']['trace_id'], 'trace-123');
      expect(events[1]['data']['row_count'], 2);
      expect(events[1]['data']['duration_ms'], isA<int>());
    });

    test('logs query failed with trace_id', () async {
      final events = <Map<String, dynamic>>[];

      final repository = SupabaseCellRepository(
        client: null,
        recordVisitQuery: (_, __) async => throw StateError('boom'),
        logEvent: (event, category, {data}) {
          events
              .add({'event': event, 'category': category, 'data': data ?? {}});
        },
      );

      await expectLater(
        () => repository.recordVisit('u1', 'c1', traceId: 'trace-999'),
        throwsA(isA<StateError>()),
      );

      expect(events, hasLength(2));
      expect(events[0]['event'], 'db.query_started');
      expect(events[1]['event'], 'db.query_failed');
      expect(events[1]['data']['trace_id'], 'trace-999');
    });
  });
}
