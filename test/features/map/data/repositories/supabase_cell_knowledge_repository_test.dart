import 'package:earth_nova/features/map/data/repositories/supabase_cell_knowledge_repository.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupabaseCellKnowledgeRepository', () {
    test('fetches server-derived player states with only requested cell ids',
        () async {
      final calls = <({String functionName, Map<String, Object?> params})>[];
      final events = <Map<String, dynamic>>[];
      final repository = SupabaseCellKnowledgeRepository(
        client: null,
        rpcQuery: (functionName, params) async {
          calls.add((functionName: functionName, params: params));
          return const [
            {
              'cell_id': 'cell-1',
              'state': 'informed',
              'category': 'fauna',
              'contents': {'exact': 'must-not-leak'},
            },
            {
              'cell_id': 'cell-2',
              'state': 'explored',
              'category': 'flora',
            },
          ];
        },
        logEvent: (event, category, {data}) {
          events.add({
            'event': event,
            'category': category,
            'data': data ?? const <String, dynamic>{},
          });
        },
      );

      final projections = await repository.fetchForCells(
        ['cell-1', '', 'cell-2', 'cell-1'],
        traceId: 'trace-1',
      );

      expect(calls, hasLength(1));
      expect(calls.single.functionName, 'fetch_v3_player_cell_states');
      expect(calls.single.params, {
        'p_cell_ids': ['cell-1', 'cell-2'],
      });
      expect(calls.single.params.containsKey('user_id'), isFalse);
      expect(projections.keys, containsAll(['cell-1', 'cell-2']));
      expect(projections['cell-1']!.state, CellKnowledgeState.informed);
      expect(projections['cell-1']!.category, 'fauna');
      expect(projections['cell-2']!.state, CellKnowledgeState.explored);
      expect(projections['cell-2']!.category, isNull);
      expect(events.map((event) => event['event']), [
        'db.query_started',
        'db.query_completed',
      ]);
      expect(
        events.every(
          (event) => event['category'] == 'cell_knowledge.repository',
        ),
        isTrue,
      );
      final started = events.first['data'] as Map<String, dynamic>;
      expect(started['trace_id'], 'trace-1');
      expect(started['operation'], 'fetch_player_cell_states');
      final completed = events.last['data'] as Map<String, dynamic>;
      expect(completed['trace_id'], 'trace-1');
      expect(completed['operation'], 'fetch_player_cell_states');
      expect(completed['row_count'], 2);
      expect(completed['request_count'], 1);
      expect(completed['duration_ms'], isA<int>());
    });

    test('batches all distinct cell ids within the RPC cap', () async {
      final calls = <List<String>>[];
      final events = <Map<String, dynamic>>[];
      final cellIds = List.generate(257, (index) => 'cell-$index');
      final repository = SupabaseCellKnowledgeRepository(
        client: null,
        rpcQuery: (_, params) async {
          final requestIds = params['p_cell_ids']! as List<String>;
          calls.add(requestIds);
          return [
            for (final cellId in requestIds)
              {'cell_id': cellId, 'state': 'informed'},
          ];
        },
        logEvent: (event, category, {data}) {
          events.add({
            'event': event,
            'category': category,
            'data': data ?? const <String, dynamic>{},
          });
        },
      );

      final projections = await repository.fetchForCells([
        ...cellIds.take(256),
        'cell-0',
        '',
        cellIds.last,
      ]);

      expect(calls, hasLength(2));
      expect(calls[0], cellIds.take(256).toList());
      expect(calls[1], [cellIds.last]);
      expect(calls.every((ids) => ids.length <= 256), isTrue);
      expect(projections.keys, orderedEquals(cellIds));
      expect(projections, hasLength(257));
      expect(events.map((event) => event['event']), [
        'db.query_started',
        'db.query_completed',
      ]);
      final completed = events.last['data'] as Map<String, dynamic>;
      expect(completed['row_count'], 257);
      expect(completed['request_count'], 2);
    });

    test('redacts failed RPC diagnostics and throws a safe error', () async {
      const secret = 'raw-payload-must-not-leak';
      final events = <Map<String, dynamic>>[];
      final repository = SupabaseCellKnowledgeRepository(
        client: null,
        rpcQuery: (_, __) async => throw FormatException(secret),
        logEvent: (event, category, {data}) {
          events.add({
            'event': event,
            'category': category,
            'data': data ?? const <String, dynamic>{},
          });
        },
      );

      await expectLater(
        repository.fetchForCells(['cell-1'], traceId: 'trace-2'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Fetching Cell knowledge failed.',
          ),
        ),
      );

      expect(events.map((event) => event['event']), [
        'db.query_started',
        'db.query_failed',
      ]);
      final failed = events.last['data'] as Map<String, dynamic>;
      expect(events.last['category'], 'cell_knowledge.repository');
      expect(failed['trace_id'], 'trace-2');
      expect(failed['operation'], 'fetch_player_cell_states');
      expect(failed['duration_ms'], isA<int>());
      expect(failed['error_type'], 'FormatException');
      expect(failed['error_message'], 'repository_operation_failed');
      expect(events.toString(), isNot(contains(secret)));
    });
    test('returns Shrouded projections for malformed state rows', () async {
      final repository = SupabaseCellKnowledgeRepository(
        client: null,
        rpcQuery: (_, __) async => const [
          {'cell_id': 'cell-1', 'state': 'unrecognized'},
          {'cell_id': 'cell-2', 'state': 'informed'},
        ],
      );

      final projections = await repository.fetchForCells(['cell-1', 'cell-2']);

      expect(projections['cell-1']!.state, CellKnowledgeState.shrouded);
      expect(projections['cell-1']!.category, isNull);
      expect(projections['cell-2']!.state, CellKnowledgeState.shrouded);
      expect(projections['cell-2']!.category, isNull);
    });
  });
}
