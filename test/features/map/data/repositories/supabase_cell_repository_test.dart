import 'package:earth_nova/features/map/data/repositories/supabase_cell_repository.dart';
import 'package:earth_nova/features/map/domain/entities/cell_visit.dart';
import 'package:earth_nova/features/map/domain/ports/cell_visit_port.dart';
import 'package:earth_nova/features/map/domain/repositories/cell_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupabaseCellRepository trace logging', () {
    test('logs query started/completed with trace_id and row_count', () async {
      final events = <Map<String, dynamic>>[];

      final repository = SupabaseCellRepository(
        client: null,
        fetchCellsQuery: (_, __, ___) async => [
          {
            'cell_id': 'a',
            'habitats': <String>[],
            'polygon': [
              {'lat': 0.0, 'lng': 0.0},
              {'lat': 1.0, 'lng': 0.0},
              {'lat': 1.0, 'lng': 1.0},
            ],
            'district_id': 'd1',
            'city_id': 'c1',
            'state_id': 's1',
            'country_id': 'co1',
          },
          {
            'cell_id': 'b',
            'habitats': <String>[],
            'polygon': [
              {'lat': 1.0, 'lng': 1.0},
              {'lat': 2.0, 'lng': 1.0},
              {'lat': 2.0, 'lng': 2.0},
            ],
            'district_id': 'd2',
            'city_id': 'c2',
            'state_id': 's2',
            'country_id': 'co1',
          },
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
      expect(events[0]['data']['operation'], 'fetch_cells_in_radius');
      expect(events[1]['event'], 'db.query_completed');
      expect(events[1]['data']['trace_id'], 'trace-123');
      expect(events[1]['data']['row_count'], 2);
      expect(events[1]['data']['operation'], 'fetch_cells_in_radius');
      expect(events[1]['data']['duration_ms'], isA<int>());
    });

    test('decodes nearby cell RPC payload with polygon and hierarchy',
        () async {
      final repository = SupabaseCellRepository(
        client: null,
        fetchCellsQuery: (_, __, ___) async => [
          {
            'cell_id': 'cell_forest_1',
            'habitats': ['forest', 'freshwater'],
            'polygon': [
              {'lat': 45.0, 'lng': -66.0},
              {'lat': 45.001, 'lng': -66.0},
              {'lat': 45.001, 'lng': -66.001},
              {'lat': 45.0, 'lng': -66.001},
            ],
            'district_id': 'district_downtown',
            'city_id': 'city_fredericton',
            'state_id': 'state_nb',
            'country_id': 'country_ca',
          },
        ],
      );

      final cells = await repository.fetchCellsInRadius(45, -66, 2000);

      expect(cells, hasLength(1));
      final cell = cells.single;
      expect(cell.id, 'cell_forest_1');
      expect(cell.habitats.map((h) => h.name),
          containsAll(['forest', 'freshwater']));
      expect(cell.polygons.first.first, hasLength(4));
      expect(cell.polygons.first.first.first.lat, 45.0);
      expect(cell.polygons.first.first.first.lng, -66.0);
      expect(cell.districtId, 'district_downtown');
      expect(cell.cityId, 'city_fredericton');
      expect(cell.stateId, 'state_nb');
      expect(cell.countryId, 'country_ca');
    });

    test('filters out nearby cells with empty polygons', () async {
      final repository = SupabaseCellRepository(
        client: null,
        fetchCellsQuery: (_, __, ___) async => [
          {
            'cell_id': 'empty-cell',
            'habitats': ['forest'],
            'polygon': <Map<String, dynamic>>[],
            'district_id': 'district_downtown',
            'city_id': 'city_fredericton',
            'state_id': 'state_nb',
            'country_id': 'country_ca',
          },
          {
            'cell_id': 'valid-cell',
            'habitats': ['plains'],
            'polygon': [
              {'lat': 45.0, 'lng': -66.0},
              {'lat': 45.001, 'lng': -66.0},
              {'lat': 45.001, 'lng': -66.001},
            ],
            'district_id': 'district_downtown',
            'city_id': 'city_fredericton',
            'state_id': 'state_nb',
            'country_id': 'country_ca',
          },
        ],
      );

      final cells = await repository.fetchCellsInRadius(45, -66, 2000);

      expect(cells.map((cell) => cell.id), ['valid-cell']);
    });

    test('forwards the exact recorded visit through the trace bridge',
        () async {
      final visit = CellVisit(
        id: 'visit-1',
        userId: 'user-1',
        cellId: 'cell-1',
        visitedAt: DateTime.utc(2026, 7, 20, 12, 34, 56),
        clientEventId: 'event-1',
      );
      final visitPort = _StubCellVisitPort(visit);
      final repository = SupabaseCellRepository(
        client: null,
        visitPort: visitPort,
      );

      final result = await repository.recordVisit(
        'user-1',
        'cell-1',
        'event-1',
        traceId: 'trace-1',
      );

      expect(result, visit);
      expect(visitPort.lastTraceId, 'trace-1');
      expect(visitPort.lastClientEventId, 'event-1');
    });

    test('emits safe telemetry and failure for raw port errors', () async {
      const malicious =
          'SQL: select secret_token from private_rows; token=never-log-this';
      final events = <Map<String, dynamic>>[];

      final repository = SupabaseCellRepository(
        client: null,
        rpcQuery: (_, __) async => throw Exception(malicious),
        logEvent: (event, category, {data}) {
          events
              .add({'event': event, 'category': category, 'data': data ?? {}});
        },
      );

      await expectLater(
        () =>
            repository.recordVisit('u1', 'c1', 'event-1', traceId: 'trace-999'),
        throwsA(
          isA<CellRepositoryFailure>()
              .having((failure) => failure.kind, 'kind',
                  CellRepositoryFailureKind.unavailable)
              .having((failure) => failure.toString(), 'safe message',
                  isNot(contains(malicious))),
        ),
      );

      expect(events, hasLength(2));
      expect(events[0]['event'], 'db.query_started');
      expect(events[1]['event'], 'db.query_failed');
      expect(events[1]['data']['trace_id'], 'trace-999');
      expect(events[1]['data']['operation'], 'record_cell_visit');
      expect(events[1]['data']['duration_ms'], isA<int>());
      expect(events[1]['data']['error_type'], 'CellRepositoryFailure');
      expect(events[1]['data']['error_message'], 'unavailable');
      expect(events.toString(), isNot(contains(malicious)));
    });
  });
}

class _StubCellVisitPort implements CellVisitPort {
  _StubCellVisitPort(this.visit);

  final CellVisit visit;
  String? lastTraceId;
  String? lastClientEventId;

  @override
  Future<CellVisit> recordVisit({
    required String userId,
    required String cellId,
    required String clientEventId,
    String? traceId,
  }) async {
    lastTraceId = traceId;
    lastClientEventId = clientEventId;
    return visit;
  }

  @override
  Future<Set<String>> getVisitedCellIds({
    required String userId,
    String? traceId,
  }) async =>
      {};

  @override
  Future<bool> isFirstVisit({
    required String userId,
    required String cellId,
    String? traceId,
  }) async =>
      false;
}
