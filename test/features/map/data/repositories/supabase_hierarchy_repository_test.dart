import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:earth_nova/features/map/data/repositories/supabase_hierarchy_repository.dart';
import 'package:earth_nova/features/map/domain/repositories/hierarchy_repository.dart';
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

    SupabaseHierarchyRepository repo({required HierarchyRpcCaller rpcCaller}) {
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
      expect(
        events.first.data,
        containsPair('operation', 'get_hierarchy_scope_summary'),
      );
      expect(events.first.data, containsPair('scope_level', 'city'));
      expect(events.first.data, containsPair('scope_id', 'city-1'));
      expect(events.last.data, containsPair('row_count', 1));
      expect(events.last.data, contains('duration_ms'));
    });

    test(
      'transports cached district geometry and preserves an unknown total',
      () async {
        final requestedDistrictIds = <String>[];
        final repository = SupabaseHierarchyRepository(
          client: SupabaseClient('https://example.supabase.co', 'anon-key'),
          rpcCaller: (_, __) async => [
            {
              'id': 'district_ca_town_plat',
              'name': 'Town Plat',
              'level': 'district',
              'cells_visited': 55,
              'cells_total': 0,
              'progress_percent': 0,
              'rank': 1,
            },
          ],
          districtMetadataQuery: (districtId) async {
            requestedDistrictIds.add(districtId);
            return {
              'geometry_json': jsonEncode({
                'type': 'MultiPolygon',
                'coordinates': [
                  [
                    [
                      [-66.65, 45.96],
                      [-66.64, 45.96],
                      [-66.64, 45.97],
                      [-66.65, 45.97],
                      [-66.65, 45.96],
                    ],
                    [
                      [-66.648, 45.963],
                      [-66.645, 45.963],
                      [-66.645, 45.966],
                      [-66.648, 45.966],
                      [-66.648, 45.963],
                    ],
                  ],
                  [
                    [
                      [-66.63, 45.96],
                      [-66.62, 45.96],
                      [-66.62, 45.97],
                      [-66.63, 45.97],
                      [-66.63, 45.96],
                    ],
                  ],
                ],
              }),
              'cells_total': null,
            };
          },
        );

        final summary = await repository.getScopeSummary(
          userId: 'user-1',
          level: MapLevel.district,
          scopeId: 'district_ca_town_plat',
        );

        expect(requestedDistrictIds, ['district_ca_town_plat']);
        expect(summary.cellsTotalKnown, isFalse);
        expect(summary.districtBoundary, isNotNull);
        expect(summary.districtBoundary!.polygons, hasLength(2));
        expect(summary.districtBoundary!.polygons.first, hasLength(2));
        expect(summary.districtBoundary!.polygons.first.last, hasLength(5));
      },
    );

    test('keeps malformed cached district geometry unavailable', () async {
      final repository = SupabaseHierarchyRepository(
        client: SupabaseClient('https://example.supabase.co', 'anon-key'),
        rpcCaller: (_, __) async => [
          {
            'id': 'district-1',
            'name': 'District',
            'level': 'district',
            'cells_visited': 1,
            'cells_total': 1,
            'progress_percent': 100,
            'rank': 1,
          },
        ],
        districtMetadataQuery: (_) async => {
          'geometry_json': '{"type":"Polygon","coordinates":[[]]}',
          'cells_total': 1,
        },
      );

      final summary = await repository.getScopeSummary(
        userId: 'user-1',
        level: MapLevel.district,
        scopeId: 'district-1',
      );

      expect(summary.districtBoundary, isNull);
      expect(summary.cellsTotalKnown, isTrue);
    });

    test('emits safe telemetry and failure for raw RPC errors', () async {
      const malicious =
          'SQL: select private_data; response={"token":"never-log-this"}';
      final repository = repo(
        rpcCaller: (_, __) async => throw Exception(malicious),
      );

      await expectLater(
        () => repository.getChildSummaries(
          userId: 'user-1',
          level: MapLevel.country,
          scopeId: 'country-1',
        ),
        throwsA(
          isA<HierarchyRepositoryFailure>()
              .having(
                (failure) => failure.kind,
                'kind',
                HierarchyRepositoryFailureKind.unavailable,
              )
              .having(
                (failure) => failure.toString(),
                'safe failure',
                isNot(contains(malicious)),
              ),
        ),
      );

      expect(events.map((event) => event.event), [
        'db.rpc_started',
        'db.rpc_failed',
      ]);
      expect(
        events.last.data,
        containsPair('operation', 'get_hierarchy_child_summaries_with_rank'),
      );
      expect(events.last.data, containsPair('duration_ms', isA<int>()));
      expect(
        events.last.data,
        containsPair('error_type', 'HierarchyRepositoryFailure'),
      );
      expect(events.last.data, containsPair('error_message', 'unavailable'));
      expect(events.toString(), isNot(contains(malicious)));
    });
  });
}
