import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/pack/data/repositories/supabase_pack_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const _versionId = '11111111-1111-4111-8111-111111111111';

Map<String, dynamic> _activeItem({
  String baseItemId = 'fauna:red_fox',
  String baseItemVersionId = _versionId,
}) =>
    {
      'id': 'item-1',
      'user_id': 'user-1',
      'definition_id': 'fauna:red_fox',
      'display_name': 'Red fox',
      'scientific_name': 'Vulpes vulpes',
      'category': 'fauna',
      'rarity': 'leastConcern',
      'icon_url': null,
      'icon_url_frame2': null,
      'art_url': null,
      'acquired_at': '2026-04-12T10:30:00.000Z',
      'acquired_in_cell_id': 'cell-42',
      'status': 'active',
      'taxonomic_class': 'Mammalia',
      'habitats_json': '["forest"]',
      'continents_json': '["Europe"]',
      'identification_state': 'identified',
      'identified_at': '2026-04-12T10:30:00.000Z',
      'base_item_id': baseItemId,
      'base_item_version_id': baseItemVersionId,
    };

Map<String, dynamic> _unexaminedItem({
  required String id,
  required String acquiredAt,
}) =>
    {
      'id': id,
      'display_name': 'Unidentified fauna specimen',
      'category': 'fauna',
      'acquired_at': acquiredAt,
      'status': 'active',
      'identification_state': 'unidentified',
      'examination_state': 'unexamined',
    };

void main() {
  group('SupabasePackRepository', () {
    test(
        'fetches active owned Items through the read seam and preserves bindings',
        () async {
      String? receivedUserId;
      final events = <Map<String, dynamic>>[];
      final repository = SupabasePackRepository(
        client: null,
        fetchActiveItemsQuery: (userId) async {
          receivedUserId = userId;
          return [_activeItem()];
        },
        logEvent: (event, category, {data}) {
          events.add({
            'event': event,
            'category': category,
            'data': data ?? const <String, dynamic>{},
          });
        },
      );

      final items = await repository.fetchActiveItems(
        'user-1',
        traceId: 'trace-pack',
      );

      expect(receivedUserId, 'user-1');
      expect(items, hasLength(1));
      expect(items.single.baseItemId, 'fauna:red_fox');
      expect(items.single.baseItemVersionId, _versionId);
      expect(events.map((event) => event['event']), [
        'db.query_started',
        'db.query_completed',
      ]);
      expect(
          events.singleWhere(
                  (event) => event['event'] == 'db.query_completed')['data']
              ['row_count'],
          1);
      final completed = events.singleWhere(
        (event) => event['event'] == 'db.query_completed',
      )['data'] as Map<String, dynamic>;
      expect(completed['operation'], 'fetch_active_items');
      expect(completed['duration_ms'], isA<int>());
    });

    test('converts malformed projection responses into safe repository errors',
        () async {
      final events = <Map<String, dynamic>>[];
      final repository = SupabasePackRepository(
        client: null,
        fetchActiveItemsQuery: (_) async => [
          _activeItem(baseItemVersionId: 'not-a-uuid'),
        ],
        logEvent: (event, category, {data}) {
          events.add({'event': event, 'category': category, 'data': data});
        },
      );

      await expectLater(
        () => repository.fetchActiveItems('user-1'),
        throwsStateError,
      );
      expect(events.last['event'], 'db.query_failed');
      expect(
        (events.last['data'] as Map)['error_message'],
        'repository_operation_failed',
      );
    });

    test('uses the owner-bound Pack RPC and accepts a masked Item', () async {
      String? rpcName;
      Map<String, dynamic>? rpcParams;
      final repository = SupabasePackRepository(
        client: null,
        rpcCaller: (functionName, params) async {
          rpcName = functionName;
          rpcParams = params;
          return {
            'items': [
              {
                'id': 'item-1',
                'display_name': 'Unidentified fauna specimen',
                'category': 'fauna',
                'acquired_at': '2026-04-12T10:30:00.000Z',
                'acquired_in_cell_id': 'cell-42',
                'status': 'active',
                'identification_state': 'unidentified',
              },
            ],
          };
        },
      );

      final items = await repository.fetchActiveItems('user-1');

      expect(rpcName, 'fetch_v3_pack_items');
      expect(rpcParams, isEmpty);
      expect(items.single.definitionId, isNull);
      expect(items.single.baseItemId, isNull);
      expect(items.single.baseItemVersionId, isNull);
    });

    test(
        'keeps authoritative newest-first unexamined Items without a cap or dedupe',
        () async {
      final rows = <Map<String, dynamic>>[
        _unexaminedItem(
          id: 'newest',
          acquiredAt: '2026-04-14T10:30:00.000Z',
        ),
        ...List.generate(
          101,
          (index) => _unexaminedItem(
            id: 'item-$index',
            acquiredAt: '2026-04-13T10:30:00.000Z',
          ),
        ),
        _unexaminedItem(
          id: 'newest',
          acquiredAt: '2026-04-12T10:30:00.000Z',
        ),
      ];
      final repository = SupabasePackRepository(
        client: null,
        rpcCaller: (_, __) async => {'items': rows},
      );

      final items = await repository.fetchActiveItems('user-1');

      expect(items, hasLength(103));
      expect(items.first.id, 'newest');
      expect(items[1].id, 'item-0');
      expect(items.last.id, 'newest');
      expect(
        items.every(
          (item) =>
              item.examinationState == ItemExaminationState.unexamined &&
              item.isExamined == false,
        ),
        isTrue,
      );
    });
  });
}
