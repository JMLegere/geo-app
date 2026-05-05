import 'package:earth_nova/features/identification/data/repositories/supabase_item_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupabaseItemRepository trace logging', () {
    test('logs query started/completed with trace_id and row_count', () async {
      final events = <Map<String, dynamic>>[];

      final repository = SupabaseItemRepository(
        client: null,
        fetchItemsQuery: (_) async => [
          {
            'id': 'item_1',
            'definition_id': 'species_101',
            'display_name': 'A',
            'category': 'fauna',
            'status': 'active',
            'acquired_at': DateTime(2026).toIso8601String(),
            'habitats_json': '[]',
            'continents_json': '[]',
          }
        ],
        logEvent: (event, category, {data}) {
          events
              .add({'event': event, 'category': category, 'data': data ?? {}});
        },
      );

      final items = await repository.fetchItems('u1', traceId: 'trace-item');

      expect(items, hasLength(1));
      expect(events, hasLength(2));
      expect(events[0]['event'], 'db.query_started');
      expect(events[1]['event'], 'db.query_completed');
      expect(events[0]['data']['operation'], 'fetch_items');
      expect(events[1]['data']['trace_id'], 'trace-item');
      expect(events[1]['data']['row_count'], 1);
      expect(events[1]['data']['operation'], 'fetch_items');
      expect(events[1]['data']['duration_ms'], isA<int>());
    });

    test('logs query failure with operation and error details', () async {
      final events = <Map<String, dynamic>>[];
      final repository = SupabaseItemRepository(
        client: null,
        fetchItemsQuery: (_) async => throw StateError('items broken'),
        logEvent: (event, category, {data}) {
          events
              .add({'event': event, 'category': category, 'data': data ?? {}});
        },
      );

      await expectLater(
        () => repository.fetchItems('u1', traceId: 'trace-item-fail'),
        throwsStateError,
      );

      expect(events.map((event) => event['event']), [
        'db.query_started',
        'db.query_failed',
      ]);
      expect(events.last['data']['operation'], 'fetch_items');
      expect(events.last['data']['trace_id'], 'trace-item-fail');
      expect(events.last['data']['error_type'], 'StateError');
      expect(events.last['data']['error_message'], contains('items broken'));
    });
  });
}
