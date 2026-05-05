import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:earth_nova/features/map/data/repositories/supabase_hierarchy_repository.dart';
import 'package:earth_nova/features/map/domain/entities/map_level.dart';

class _LoggedEvent {
  const _LoggedEvent(this.event, this.category, this.data);

  final String event;
  final String category;
  final Map<String, dynamic> data;
}

void main() {
  group('SupabaseHierarchyRepository telemetry', () {
    late List<_LoggedEvent> events;

    setUp(() {
      events = [];
    });

    SupabaseHierarchyRepository repo({
      required HierarchyRpcCaller rpcCaller,
    }) {
      return SupabaseHierarchyRepository(
        client: SupabaseClient('https://example.supabase.co', 'anon-key'),
        rpcCaller: rpcCaller,
        logEvent: (event, category, {data}) {
          events.add(_LoggedEvent(event, category, data ?? const {}));
        },
      );
    }

    test('logs RPC start and completion with operation details', () async {
      final repository = repo(
        rpcCaller: (functionName, params) async => [
          {
            'id': 'city-1',
            'name': 'Fredericton',
            'level': 'city',
            'cells_visited': 3,
            'cells_total': 10,
            'progress_percent': 30,
            'rank': 2,
          },
        ],
      );

      final summary = await repository.getScopeSummary(
        userId: 'user-1',
        level: MapLevel.city,
        scopeId: 'city-1',
      );

      expect(summary.id, 'city-1');
      expect(events.map((event) => event.event), [
        'db.rpc_started',
        'db.rpc_completed',
      ]);
      expect(events.first.category, 'map.hierarchy_repository');
      expect(events.first.data,
          containsPair('operation', 'get_hierarchy_scope_summary'));
      expect(events.first.data, containsPair('scope_level', 'city'));
      expect(events.first.data, containsPair('scope_id', 'city-1'));
      expect(events.last.data, containsPair('row_count', 1));
      expect(events.last.data, contains('duration_ms'));
    });

    test('logs RPC failure with diagnostic error details', () async {
      final repository = repo(
        rpcCaller: (_, __) async => throw StateError('rpc broken'),
      );

      await expectLater(
        () => repository.getChildSummaries(
          userId: 'user-1',
          level: MapLevel.country,
          scopeId: 'country-1',
        ),
        throwsStateError,
      );

      expect(events.map((event) => event.event), [
        'db.rpc_started',
        'db.rpc_failed',
      ]);
      expect(events.last.data,
          containsPair('operation', 'get_hierarchy_child_summaries_with_rank'));
      expect(events.last.data, containsPair('error_type', 'StateError'));
      expect(events.last.data['error_message'], contains('rpc broken'));
    });
  });
}
