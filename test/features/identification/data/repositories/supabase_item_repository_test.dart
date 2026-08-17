import 'package:earth_nova/features/identification/data/repositories/supabase_item_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/identification/domain/entities/discovery_item_draft.dart';

const _acquiredAt = '2026-04-12T10:30:00.000Z';

DiscoveryItemDraft _draft() => DiscoveryItemDraft(
      userId: 'user-1',
      definitionId: 'species-101',
      displayName: 'Northern cardinal',
      category: ItemCategory.fauna,
      acquiredInCellId: 'cell-42',
      mapCellEntryId: 'entry-42',
      scientificName: 'Cardinalis cardinalis',
      rarity: 'common',
      taxonomicClass: 'Aves',
      habitats: const ['forest', 'garden'],
      continents: const ['North America'],
      identifiedAt: DateTime.utc(2026, 4, 13, 9),
      identifiedDisplayName: 'Identified cardinal',
      identifiedScientificName: 'Cardinalis cardinalis',
      identifiedTaxonomicClass: 'Aves',
      identifiedHabitats: const ['woodland'],
      identifiedContinents: const ['North America'],
    );

Map<String, dynamic> _acquiredItemResponse({
  String cellId = 'cell-42',
  String displayName = 'Unidentified fauna specimen',
  String category = 'fauna',
}) =>
    {
      'id': 'item-1',
      'display_name': displayName,
      'category': category,
      'acquired_at': _acquiredAt,
      'acquired_in_cell_id': cellId,
      'status': 'active',
      'identification_state': 'unidentified',
    };

Map<String, dynamic> _examinedItemResponse() => {
      'id': 'item-1',
      'definition_id': 'species-101',
      'base_item_id': 'fauna:northern_cardinal',
      'base_item_version_id': '123e4567-e89b-12d3-a456-426614174000',
      'display_name': 'Northern cardinal',
      'scientific_name': 'Cardinalis cardinalis',
      'category': 'fauna',
      'acquired_at': _acquiredAt,
      'status': 'active',
      'identification_state': 'unidentified',
      'examination_state': 'examined',
      'examined_at': '2026-04-13T09:00:00.000Z',
    };

void main() {
  group('SupabaseItemRepository trace logging', () {
    test('logs query started/completed with trace_id and row_count', () async {
      final events = <Map<String, dynamic>>[];

      final repository = SupabaseItemRepository(
        client: null,
        fetchItemsQuery: (_) async => [
          {
            'id': 'item_1',
            'display_name': 'Unidentified fauna specimen',
            'category': 'fauna',
            'status': 'active',
            'acquired_at': DateTime(2026).toIso8601String(),
            'identification_state': 'unidentified',
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

    test('logs query failure with safe diagnostic attributes', () async {
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
      expect(
        events.last['data']['error_message'],
        'invalid_repository_response',
      );
      expect(
          events.last['data'].values.join(), isNot(contains('items broken')));
    });
  });

  group('SupabaseItemRepository examination command', () {
    final unexaminedItem = Item(
      id: 'item-1',
      displayName: 'Unidentified fauna specimen',
      category: ItemCategory.fauna,
      acquiredAt: DateTime.utc(2026, 4, 12, 10, 30),
      status: ItemStatus.active,
      identificationState: ItemIdentificationState.unidentified,
      examinationState: ItemExaminationState.unexamined,
    );

    test('calls examine_v3_item with only the exact Item id and trace',
        () async {
      String? rpcName;
      Map<String, dynamic>? rpcParams;
      final events = <Map<String, dynamic>>[];
      final repository = SupabaseItemRepository(
        client: null,
        examineItemRpcCaller: (functionName, params) async {
          rpcName = functionName;
          rpcParams = params;
          return _examinedItemResponse();
        },
        logEvent: (event, category, {data}) {
          events
              .add({'event': event, 'category': category, 'data': data ?? {}});
        },
      );

      final examined = await repository.examineItem(unexaminedItem,
          traceId: 'trace-examine');

      expect(rpcName, 'examine_v3_item');
      expect(rpcParams, {'p_item_id': 'item-1'});
      expect(examined.id, unexaminedItem.id);
      expect(examined.isExamined, isTrue);
      expect(
          examined.identificationState, ItemIdentificationState.unidentified);
      expect(events.map((event) => event['event']), [
        'db.query_started',
        'db.query_completed',
      ]);
      expect(events.first['data']['operation'], 'examine_item');
      expect(events.first['data']['trace_id'], 'trace-examine');
      expect(events.last['data']['operation'], 'examine_item');
      expect(events.last['data']['item_id'], 'item-1');
      expect(events.last['data']['trace_id'], 'trace-examine');
    });

    test('logs a safe examination failure and preserves the backend error',
        () async {
      final events = <Map<String, dynamic>>[];
      final repository = SupabaseItemRepository(
        client: null,
        examineItemRpcCaller: (_, __) async =>
            throw StateError('backend secret: examination failed'),
        logEvent: (event, category, {data}) {
          events
              .add({'event': event, 'category': category, 'data': data ?? {}});
        },
      );

      await expectLater(
        () => repository.examineItem(unexaminedItem, traceId: 'trace-failed'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Examining the Item failed.',
          ),
        ),
      );

      expect(events.map((event) => event['event']), [
        'db.query_started',
        'db.query_failed',
      ]);
      expect(events.last['data']['operation'], 'examine_item');
      expect(events.last['data']['trace_id'], 'trace-failed');
      expect(events.last['data']['error_type'], 'StateError');
      expect(
          events.last['data']['error_message'], 'invalid_repository_response');
      expect(events.last['data'].values.join(),
          isNot(contains('backend secret: examination failed')));
    });
  });

  group('SupabaseItemRepository legacy discovery acquisition', () {
    test('sends only discovery identity and provenance to the legacy RPC',
        () async {
      String? rpcName;
      Map<String, dynamic>? rpcParams;
      final repository = SupabaseItemRepository(
        client: null,
        acquireDiscoveryItemRpcCaller: (functionName, params) async {
          rpcName = functionName;
          rpcParams = params;
          return _acquiredItemResponse();
        },
      );

      final item = await repository.acquireDiscoveryItem(_draft());

      expect(item.id, 'item-1');
      expect(rpcName, 'acquire_v3_legacy_discovery_item');
      expect(rpcParams, {
        'p_definition_id': 'species-101',
        'p_acquired_in_cell_id': 'cell-42',
        'p_map_cell_entry_id': 'entry-42',
      });
      for (final forbiddenParam in [
        'p_display_name',
        'p_category',
        'p_scientific_name',
        'p_rarity',
        'p_taxonomic_class',
        'p_habitats_json',
        'p_continents_json',
        'p_identification_state',
        'p_identified_at',
        'p_identified_display_name',
      ]) {
        expect(rpcParams, isNot(contains(forbiddenParam)));
      }
    });

    test('rejects a malformed non-object RPC response', () async {
      final repository = SupabaseItemRepository(
        client: null,
        acquireDiscoveryItemRpcCaller: (_, __) async => [
          _acquiredItemResponse(),
        ],
      );

      await expectLater(
        () => repository.acquireDiscoveryItem(_draft()),
        throwsStateError,
      );
    });

    test('rejects an unsafe or malformed safe Item projection', () async {
      final invalidResponses = [
        _acquiredItemResponse(cellId: 'other-cell'),
        _acquiredItemResponse(displayName: ''),
        _acquiredItemResponse(category: ''),
        <String, dynamic>{
          ..._acquiredItemResponse(),
          'definition_id': 'forged-definition',
        },
      ];

      for (final response in invalidResponses) {
        final repository = SupabaseItemRepository(
          client: null,
          acquireDiscoveryItemRpcCaller: (_, __) async => response,
        );

        await expectLater(
          () => repository.acquireDiscoveryItem(_draft()),
          throwsStateError,
        );
      }
    });

    test('keeps the injectable acquisition query seam usable', () async {
      DiscoveryItemDraft? receivedDraft;
      final draft = _draft();
      final repository = SupabaseItemRepository(
        client: null,
        acquireDiscoveryItemQuery: (draft) async {
          receivedDraft = draft;
          return _acquiredItemResponse();
        },
      );

      final item = await repository.acquireDiscoveryItem(draft);

      expect(receivedDraft, same(draft));
      expect(item.definitionId, isNull);
    });

    test('logs acquisition failures without raw backend messages', () async {
      final events = <Map<String, dynamic>>[];
      final repository = SupabaseItemRepository(
        client: null,
        acquireDiscoveryItemQuery: (_) async =>
            throw StateError('backend secret: acquisition failed'),
        logEvent: (event, category, {data}) {
          events
              .add({'event': event, 'category': category, 'data': data ?? {}});
        },
      );

      await expectLater(
        () => repository.acquireDiscoveryItem(_draft()),
        throwsStateError,
      );

      expect(events.map((event) => event['event']), [
        'db.query_started',
        'db.query_failed',
      ]);
      expect(events.last['data']['error_type'], 'StateError');
      expect(
        events.last['data']['error_message'],
        'invalid_repository_response',
      );
      expect(
        events.last['data'].values.join(),
        isNot(contains('backend secret: acquisition failed')),
      );
    });
  });
}
