import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/habitat.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_visit.dart';
import 'package:earth_nova/features/map/domain/repositories/cell_repository.dart';
import 'package:earth_nova/features/map/data/repositories/supabase_cell_repository.dart';
import 'package:earth_nova/features/map/domain/use_cases/fetch_nearby_cells.dart';

class TestObservabilityService extends ObservabilityService {
  TestObservabilityService() : super(sessionId: 'test-session');

  final logs = <Map<String, Object?>>[];

  @override
  void log(String event, String category, {Map<String, dynamic>? data}) {
    logs.add({
      'event': event,
      'category': category,
      'data': data ?? const <String, dynamic>{},
    });
  }
}

class FakeCellRepository implements CellRepository {
  FakeCellRepository({this.cells = const [], this.shouldThrow = false});

  final List<Cell> cells;
  final bool shouldThrow;
  final _visits = <String, Set<String>>{};
  var _visitSequence = 0;

  @override
  Future<List<Cell>> fetchCellsInRadius(
      double lat, double lng, double radiusMeters,
      {String? traceId}) async {
    if (shouldThrow) throw Exception('Fake fetch error');
    return cells;
  }

  @override
  Future<CellVisit> recordVisit(
    String userId,
    String cellId,
    String clientEventId, {
    String? traceId,
  }) async {
    _visits.putIfAbsent(userId, () => {}).add(cellId);
    return CellVisit(
      id: 'visit-${++_visitSequence}',
      userId: userId,
      cellId: cellId,
      clientEventId: clientEventId,
      visitedAt: DateTime.utc(2026, 7, 20),
    );
  }

  @override
  Future<Set<String>> getVisitedCellIds(String userId,
      {String? traceId}) async {
    return _visits[userId] ?? {};
  }

  @override
  Future<bool> isFirstVisit(String userId, String cellId,
      {String? traceId}) async {
    return !(_visits[userId]?.contains(cellId) ?? false);
  }
}

Cell _testCell(String id) => Cell(
      id: id,
      habitats: [Habitat.forest],
      polygons: const [
        [
          [(lat: 1.0, lng: 2.0)]
        ]
      ],
      districtId: '',
      cityId: '',
      stateId: '',
      countryId: '',
    );

void main() {
  group('FetchNearbyCells', () {
    test('delegates to repository and returns cells', () async {
      final cells = [_testCell('cell-1'), _testCell('cell-2')];
      final repo = FakeCellRepository(cells: cells);
      final obs = TestObservabilityService();
      final useCase = FetchNearbyCells(repo, obs);

      final result = await useCase.call((
        lat: 1.0,
        lng: 2.0,
        radiusMeters: 2000,
      ));

      expect(result, hasLength(2));
      expect(result.first.id, 'cell-1');
      expect(obs.logs[0]['event'], 'operation.started');
      expect(obs.logs[1]['event'], 'operation.completed');
    });

    test('returns empty list when no cells nearby', () async {
      final repo = FakeCellRepository();
      final useCase = FetchNearbyCells(repo, TestObservabilityService());

      final result = await useCase.call((
        lat: 0.0,
        lng: 0.0,
        radiusMeters: 1000,
      ));

      expect(result, isEmpty);
    });

    test('keeps raw repository errors out of use-case observability', () async {
      const malicious =
          'PostgREST body={"access_token":"never-log-this","query":"select *"}';
      final repositoryEvents = <Map<String, dynamic>>[];
      final repository = SupabaseCellRepository(
        client: null,
        fetchCellsQuery: (_, __, ___) async => throw Exception(malicious),
        logEvent: (event, category, {data}) {
          repositoryEvents.add({
            'event': event,
            'category': category,
            'data': data ?? const <String, dynamic>{},
          });
        },
      );
      final obs = TestObservabilityService();
      final useCase = FetchNearbyCells(repository, obs);

      await expectLater(
        () => useCase.call((
          lat: 0.0,
          lng: 0.0,
          radiusMeters: 1000,
        )),
        throwsA(
          isA<CellRepositoryFailure>()
              .having((failure) => failure.kind, 'kind',
                  CellRepositoryFailureKind.unavailable)
              .having((failure) => failure.toString(), 'safe message',
                  isNot(contains(malicious))),
        ),
      );

      final repositoryFailure = repositoryEvents.singleWhere(
        (event) => event['event'] == 'db.query_failed',
      );
      final useCaseFailure =
          obs.logs.singleWhere((log) => log['event'] == 'operation.failed');
      expect(repositoryFailure['data']['operation'], 'fetch_cells_in_radius');
      expect(repositoryFailure['data']['duration_ms'], isA<int>());
      expect(repositoryFailure['data']['error_type'], 'CellRepositoryFailure');
      expect(repositoryFailure['data']['error_message'], 'unavailable');
      expect(useCaseFailure['data'],
          containsPair('operation', 'fetch_nearby_cells'));
      expect(useCaseFailure['data'], containsPair('duration_ms', isA<int>()));
      expect(useCaseFailure['data'],
          containsPair('error_type', 'CellRepositoryFailure'));
      expect(useCaseFailure['data'],
          containsPair('error_message', 'Cell request failed (unavailable).'));
      expect(repositoryEvents.toString(), isNot(contains(malicious)));
      expect(obs.logs.toString(), isNot(contains(malicious)));
    });
  });
}
