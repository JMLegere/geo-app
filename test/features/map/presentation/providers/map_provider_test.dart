import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/core/domain/entities/user_profile.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/core/observability/observable_use_case_provider.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_visit.dart';
import 'package:earth_nova/features/map/domain/entities/cell_knowledge_projection.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/features/map/domain/repositories/cell_knowledge_repository.dart';

import 'package:earth_nova/features/map/domain/entities/location_state.dart';
import 'package:earth_nova/features/map/domain/repositories/cell_repository.dart';
import 'package:earth_nova/features/map/domain/repositories/location_repository.dart';
import 'package:earth_nova/features/map/presentation/providers/location_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/map_provider.dart';

class TestObservabilityService extends ObservabilityService {
  TestObservabilityService() : super(sessionId: 'test-session');

  final List<({String event, String category, Map<String, dynamic>? data})>
      events = [];

  @override
  void log(String event, String category, {Map<String, dynamic>? data}) {
    events.add((event: event, category: category, data: data));
    super.log(event, category, data: data);
  }

  List<String> get eventNames => events.map((e) => e.event).toList();
}

class ControllableMockLocationRepository implements LocationRepository {
  final _controller = StreamController<LocationState>.broadcast();
  bool _permissionGranted = true;
  LocationState? _currentPosition;
  bool _throwOnGetCurrent = false;

  @override
  Stream<LocationState> get positionStream => _controller.stream;

  @override
  Future<LocationState> getCurrentPosition({String? traceId}) async {
    if (_throwOnGetCurrent) throw Exception('Location unavailable');
    if (_currentPosition != null) return _currentPosition!;
    return LocationState(
      lat: 0.0,
      lng: 0.0,
      accuracy: 10.0,
      timestamp: DateTime(2026),
      isConfident: true,
    );
  }

  @override
  Future<bool> requestPermission({String? traceId}) async => _permissionGranted;

  void emitPosition(LocationState position) {
    _currentPosition = position;
    _controller.add(position);
  }

  void setPermissionGranted(bool granted) => _permissionGranted = granted;
  void setThrowOnGetCurrent(bool value) => _throwOnGetCurrent = value;

  void dispose() => _controller.close();
}

class ControllableMockCellRepository implements CellRepository {
  List<Cell> cells = [];
  Set<String> visitedIds = {};
  bool shouldThrow = false;
  int fetchCallCount = 0;
  String? lastVisitedUserId;
  bool delayNextFetch = false;
  final pendingFetches = <Completer<List<Cell>>>[];

  @override
  Future<List<Cell>> fetchCellsInRadius(
      double lat, double lng, double radiusMeters,
      {String? traceId}) async {
    fetchCallCount++;
    if (shouldThrow) throw Exception('Cell fetch error');
    if (delayNextFetch) {
      delayNextFetch = false;
      final completer = Completer<List<Cell>>();
      pendingFetches.add(completer);
      return completer.future;
    }
    return cells;
  }

  @override
  Future<CellVisit> recordVisit(
      String userId, String cellId, String clientEventId,
      {String? traceId}) async {
    return CellVisit(
      id: 'visit-1',
      userId: userId,
      cellId: cellId,
      visitedAt: DateTime.utc(2026, 7, 20),
    );
  }

  @override
  Future<Set<String>> getVisitedCellIds(String userId,
      {String? traceId}) async {
    lastVisitedUserId = userId;
    if (shouldThrow) throw Exception('Visited cells error');
    return visitedIds;
  }

  @override
  Future<bool> isFirstVisit(String userId, String cellId,
          {String? traceId}) async =>
      true;
}

class ControllableMockCellKnowledgeRepository
    implements CellKnowledgeRepository {
  Map<String, CellKnowledgeProjection> projections = {};
  List<String>? lastRequestedCellIds;

  @override
  Future<Map<String, CellKnowledgeProjection>> fetchForCells(
    Iterable<String> cellIds, {
    String? traceId,
  }) async {
    lastRequestedCellIds = cellIds.toList();
    return projections;
  }
}

ProviderContainer makeContainer({
  required TestObservabilityService obs,
  required ControllableMockLocationRepository locationRepo,
  required ControllableMockCellRepository cellRepo,
  required ControllableMockCellKnowledgeRepository cellKnowledgeRepo,
  AuthState authState = const AuthState.unauthenticated(),
}) {
  return ProviderContainer(
    overrides: [
      authProvider.overrideWith(() => _FakeAuthNotifier(authState)),
      mapObservabilityProvider.overrideWithValue(obs),
      observableUseCaseProvider.overrideWithValue(obs),
      locationObservabilityProvider.overrideWithValue(obs),
      locationRepositoryProvider.overrideWithValue(locationRepo),
      cellRepositoryProvider.overrideWithValue(cellRepo),
      cellKnowledgeRepositoryProvider.overrideWithValue(cellKnowledgeRepo),
    ],
  );
}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._state);

  final AuthState _state;

  @override
  AuthState build() => _state;
}

class _FakeLocationNotifier extends LocationNotifier {
  _FakeLocationNotifier(this._state);

  final LocationProviderState _state;

  @override
  LocationProviderState build() => _state;
}

void main() {
  group('MapNotifier', () {
    late ProviderContainer container;
    late TestObservabilityService obs;
    late ControllableMockLocationRepository locationRepo;
    late ControllableMockCellRepository cellRepo;
    late ControllableMockCellKnowledgeRepository cellKnowledgeRepo;

    setUp(() {
      obs = TestObservabilityService();
      locationRepo = ControllableMockLocationRepository();
      cellRepo = ControllableMockCellRepository();
      cellKnowledgeRepo = ControllableMockCellKnowledgeRepository();
      container = makeContainer(
        obs: obs,
        locationRepo: locationRepo,
        cellRepo: cellRepo,
        cellKnowledgeRepo: cellKnowledgeRepo,
        authState: AuthState.authenticated(
          UserProfile(
            id: 'user-123',
            phone: '5551234567',
            createdAt: DateTime(2026),
          ),
        ),
      );
    });

    tearDown(() async {
      await Future<void>.delayed(Duration.zero);
      container.dispose();
      locationRepo.dispose();
    });

    test('initial state is loading', () {
      final state = container.read(mapProvider);
      expect(state, isA<MapStateLoading>());
    });

    test('hydrate restores a ready Map without fetching', () {
      final ready = MapStateReady(
        cells: const [],
        visitedCellIds: const {},
        location: LocationState(
          lat: 1,
          lng: 2,
          accuracy: 3,
          timestamp: DateTime.utc(2026),
          isConfident: true,
        ),
      );

      container.read(mapProvider.notifier).hydrate(ready);

      expect(container.read(mapProvider), same(ready));
      expect(cellRepo.fetchCallCount, 0);
      expect(obs.eventNames, contains('map.hydrated'));
    });

    test('mapObservabilityProvider throws when not overridden', () {
      final c = ProviderContainer();
      expect(() => c.read(mapObservabilityProvider), throwsA(anything));
      c.dispose();
    });

    test('cellRepositoryProvider throws when not overridden', () {
      final c = ProviderContainer(
        overrides: [
          mapObservabilityProvider.overrideWithValue(obs),
        ],
      );
      expect(() => c.read(cellRepositoryProvider), throwsA(anything));
      c.dispose();
    });

    test('transitions to ready when location becomes active', () async {
      container.read(mapProvider);
      await Future<void>.delayed(Duration.zero);

      final position = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      locationRepo.emitPosition(position);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(mapProvider);
      expect(state, isA<MapStateReady>());
    });

    test('ready state contains location from GPS', () async {
      container.read(mapProvider);
      await Future<void>.delayed(Duration.zero);

      final position = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      locationRepo.emitPosition(position);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(mapProvider) as MapStateReady;
      expect(state.location.lat, 37.7749);
      expect(state.location.lng, -122.4194);
    });

    test('ready state contains cells fetched from repository', () async {
      final cell = Cell(
        id: 'cell-1',
        habitats: [],
        polygons: [
          [[]]
        ],
        districtId: 'd1',
        cityId: 'c1',
        stateId: 's1',
        countryId: 'co1',
      );
      cellRepo.cells = [cell];

      container.read(mapProvider);
      await Future<void>.delayed(Duration.zero);

      final position = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      locationRepo.emitPosition(position);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(mapProvider) as MapStateReady;
      expect(state.cells, hasLength(1));
      expect(state.cells.first.id, 'cell-1');
    });

    test('ready state contains visited cell IDs', () async {
      cellRepo.visitedIds = {'cell-1', 'cell-2'};

      container.read(mapProvider);
      await Future<void>.delayed(Duration.zero);

      final position = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      locationRepo.emitPosition(position);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(mapProvider) as MapStateReady;
      expect(state.visitedCellIds, containsAll(['cell-1', 'cell-2']));
    });

    test('loads player cell knowledge projections for fetched cells', () async {
      final cell = Cell(
        id: 'cell-1',
        habitats: const [],
        polygons: const [],
        districtId: 'district',
        cityId: 'city',
        stateId: 'state',
        countryId: 'country',
      );
      cellRepo.cells = [cell];
      cellKnowledgeRepo.projections = const {
        'cell-1': CellKnowledgeProjection(
          cellId: 'cell-1',
          state: CellKnowledgeState.informed,
          category: 'fauna',
        ),
      };

      container.read(mapProvider);
      await Future<void>.delayed(Duration.zero);
      locationRepo.emitPosition(LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      ));
      await Future<void>.delayed(Duration.zero);

      final state = container.read(mapProvider) as MapStateReady;
      expect(cellKnowledgeRepo.lastRequestedCellIds, ['cell-1']);
      expect(
        state.knowledgeByCellId['cell-1']!.state,
        CellKnowledgeState.informed,
      );
      expect(state.knowledgeByCellId['cell-1']!.category, 'fauna');
    });

    test('transitions to error when cell fetch fails', () async {
      cellRepo.shouldThrow = true;

      container.read(mapProvider);
      await Future<void>.delayed(Duration.zero);

      final position = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      locationRepo.emitPosition(position);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(mapProvider);
      expect(state, isA<MapStateError>());
    });

    test('error state contains message', () async {
      cellRepo.shouldThrow = true;

      container.read(mapProvider);
      await Future<void>.delayed(Duration.zero);

      final position = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      locationRepo.emitPosition(position);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(mapProvider) as MapStateError;
      expect(state.message, isNotEmpty);
    });

    test('transitions to error when GPS provider errors', () async {
      locationRepo.setThrowOnGetCurrent(true);

      final c = makeContainer(
        obs: obs,
        locationRepo: locationRepo,
        cellRepo: cellRepo,
        cellKnowledgeRepo: cellKnowledgeRepo,
        authState: AuthState.authenticated(
          UserProfile(
            id: 'user-123',
            phone: '5551234567',
            createdAt: DateTime(2026),
          ),
        ),
      );
      addTearDown(c.dispose);

      c.read(mapProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = c.read(mapProvider) as MapStateError;
      expect(state.message, contains('Location unavailable'));
    });

    test('transitions to error when location permission is denied', () async {
      locationRepo.setPermissionGranted(false);

      final c = makeContainer(
        obs: obs,
        locationRepo: locationRepo,
        cellRepo: cellRepo,
        cellKnowledgeRepo: cellKnowledgeRepo,
      );
      addTearDown(c.dispose);

      c.read(mapProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = c.read(mapProvider) as MapStateError;
      expect(state.message, 'Location permission denied');
    });

    test('fetches visited cells for the authenticated user', () async {
      container.read(mapProvider);
      await Future<void>.delayed(Duration.zero);

      final position = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      locationRepo.emitPosition(position);
      await Future<void>.delayed(Duration.zero);

      expect(cellRepo.lastVisitedUserId, 'user-123');
    });

    test('logs map.cells_fetch_started when fetch begins', () async {
      container.read(mapProvider);
      await Future<void>.delayed(Duration.zero);

      final position = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      locationRepo.emitPosition(position);
      await Future<void>.delayed(Duration.zero);

      expect(obs.eventNames, contains('map.cells_fetch_started'));
    });

    test('map.cells_fetch_started includes lat, lng, radius_meters', () async {
      // Set initial position BEFORE reading mapProvider so the initial fetch uses it
      final initialPosition = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      locationRepo.emitPosition(initialPosition);

      container.read(mapProvider);
      await Future<void>.delayed(Duration.zero);

      final startedEvent =
          obs.events.firstWhere((e) => e.event == 'map.cells_fetch_started');
      expect(startedEvent.data?['lat'], 37.7749);
      expect(startedEvent.data?['lng'], -122.4194);
      expect(startedEvent.data?['radius_meters'], isA<double>());
    });

    test('initial active location waits for the App Readiness refresh', () async {
      final initial = LocationState(
        lat: 45.9636,
        lng: -66.6431,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      final c = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => _FakeAuthNotifier(
                AuthState.authenticated(
                  UserProfile(
                    id: 'user-123',
                    phone: '5551234567',
                    createdAt: DateTime(2026),
                  ),
                ),
              )),
          mapObservabilityProvider.overrideWithValue(obs),
          observableUseCaseProvider.overrideWithValue(obs),
          locationProvider.overrideWith(
            () => _FakeLocationNotifier(LocationProviderActive(initial)),
          ),
          cellRepositoryProvider.overrideWithValue(cellRepo),
          cellKnowledgeRepositoryProvider.overrideWithValue(cellKnowledgeRepo),
        ],
      );
      addTearDown(c.dispose);

      c.read(mapProvider);
      await Future<void>.delayed(Duration.zero);

      expect(cellRepo.fetchCallCount, 0);
      expect(c.read(mapProvider), isA<MapStateLoading>());

      expect(await c.read(mapProvider.notifier).refresh(), isTrue);
      expect(cellRepo.fetchCallCount, 1);
      expect(c.read(mapProvider), isA<MapStateReady>());
    });

    test('logs map.cells_fetch_complete with cell stats when ready', () async {
      final cell = Cell(
        id: 'cell-1',
        habitats: [],
        polygons: [
          [
            [
              (lat: 0.0, lng: 0.0),
              (lat: 1.0, lng: 0.0),
              (lat: 1.0, lng: 1.0),
            ]
          ]
        ],
        districtId: 'd1',
        cityId: 'c1',
        stateId: 's1',
        countryId: 'co1',
        geometrySourceVersion: 'organic-voronoi-beta-v1',
        geometryGenerationMode: 'db-deterministic-jittered-centroid-voronoi',
        centroidDatasetVersion: 'earthnova-organic-centroids-beta-v1',
        geometryContract: 'true-voronoi-clipped-to-lattice-coverage',
      );
      cellRepo.cells = [cell];
      cellRepo.visitedIds = {'cell-1'};

      container.read(mapProvider);
      await Future<void>.delayed(Duration.zero);

      final position = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      locationRepo.emitPosition(position);
      await Future<void>.delayed(Duration.zero);

      expect(obs.eventNames, contains('map.cells_fetch_complete'));
      final completeEvent =
          obs.events.firstWhere((e) => e.event == 'map.cells_fetch_complete');
      expect(completeEvent.data?['total_cells'], 1);
      expect(completeEvent.data?['cells_with_polygon'], 1);
      expect(completeEvent.data?['cells_without_polygon'], 0);
      expect(completeEvent.data?['visited_count'], 1);
      expect(completeEvent.data?['geometry_source_versions'],
          ['organic-voronoi-beta-v1']);
      expect(completeEvent.data?['geometry_generation_modes'],
          ['db-deterministic-jittered-centroid-voronoi']);
      expect(completeEvent.data?['geometry_contracts'],
          ['true-voronoi-clipped-to-lattice-coverage']);
      expect(completeEvent.data?['geometry_rectangular_cell_count'], 0);
      expect(completeEvent.data?['geometry_four_point_exterior_count'], 0);
      expect(completeEvent.data?['geometry_axis_aligned_edge_ratio'],
          lessThan(1.0));
      expect(completeEvent.data?['geometry_shape_warnings'], isEmpty);
    });

    test('logs map.cells_fetch_error on failure', () async {
      cellRepo.shouldThrow = true;

      container.read(mapProvider);
      await Future<void>.delayed(Duration.zero);

      final position = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      locationRepo.emitPosition(position);
      await Future<void>.delayed(Duration.zero);

      expect(obs.eventNames, contains('map.cells_fetch_error'));
      final errorEvent =
          obs.events.firstWhere((e) => e.event == 'map.cells_fetch_error');
      expect(errorEvent.data?['error'], isNotEmpty);
    });

    test('retains stale context when a refresh fetch fails', () async {
      final oldCell = Cell(
        id: 'old-cell',
        habitats: [],
        polygons: const [],
        districtId: 'd1',
        cityId: 'c1',
        stateId: 's1',
        countryId: 'co1',
      );
      cellRepo.cells = [oldCell];

      container.read(mapProvider);
      await Future<void>.delayed(Duration.zero);

      final pos1 = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      locationRepo.emitPosition(pos1);
      await Future<void>.delayed(Duration.zero);

      cellRepo.shouldThrow = true;
      final refreshed = await container.read(mapProvider.notifier).refresh();

      expect(refreshed, isFalse);

      final state = container.read(mapProvider) as MapStateReady;
      expect(state.cells.single.id, 'old-cell');
      expect(
          obs.eventNames, contains('map.cells_fetch_stale_context_retained'));
      final retainedEvent = obs.events.firstWhere(
        (event) => event.event == 'map.cells_fetch_stale_context_retained',
      );
      expect(retainedEvent.data?['retained_cell_count'], 1);
      expect(retainedEvent.data?['dependency'], 'cells');
      expect(retainedEvent.data?['error'], contains('Cell fetch error'));
    });

    test('logs map.zoom_changed when zoom is updated', () {
      container.read(mapProvider.notifier).setZoom(14);

      expect(obs.eventNames, contains('map.zoom_changed'));
    });

    test('re-fetches cells when position changes significantly', () async {
      container.read(mapProvider);
      await Future<void>.delayed(Duration.zero);

      final pos1 = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      locationRepo.emitPosition(pos1);
      await Future<void>.delayed(Duration.zero);

      final fetchCountAfterFirst = cellRepo.fetchCallCount;

      final pos2 = LocationState(
        lat: 37.8000,
        lng: -122.4500,
        accuracy: 5.0,
        timestamp: DateTime(2026, 1, 1, 0, 1),
        isConfident: true,
      );
      locationRepo.emitPosition(pos2);
      await Future<void>.delayed(Duration.zero);

      expect(cellRepo.fetchCallCount, greaterThan(fetchCountAfterFirst));
    });

    test('keeps previous cells visible while a significant move refetches',
        () async {
      final oldCell = Cell(
        id: 'old-cell',
        habitats: [],
        polygons: const [],
        districtId: 'd1',
        cityId: 'c1',
        stateId: 's1',
        countryId: 'co1',
      );
      final newCell = Cell(
        id: 'new-cell',
        habitats: [],
        polygons: const [],
        districtId: 'd1',
        cityId: 'c1',
        stateId: 's1',
        countryId: 'co1',
      );
      cellRepo.cells = [oldCell];

      container.read(mapProvider);
      await Future<void>.delayed(Duration.zero);

      final pos1 = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      locationRepo.emitPosition(pos1);
      await Future<void>.delayed(Duration.zero);
      expect((container.read(mapProvider) as MapStateReady).cells.single.id,
          'old-cell');

      cellRepo.cells = [newCell];
      cellRepo.delayNextFetch = true;
      final pos2 = LocationState(
        lat: 37.8000,
        lng: -122.4500,
        accuracy: 5.0,
        timestamp: DateTime(2026, 1, 1, 0, 1),
        isConfident: true,
      );
      locationRepo.emitPosition(pos2);
      await Future<void>.delayed(Duration.zero);

      final refreshing = container.read(mapProvider) as MapStateRefreshing;
      expect(refreshing.previous.cells.single.id, 'old-cell');
      expect(refreshing.refreshLocation, pos2);

      cellRepo.pendingFetches.single.complete([newCell]);
      await Future<void>.delayed(Duration.zero);
      expect((container.read(mapProvider) as MapStateReady).cells.single.id,
          'new-cell');
    });

    test('does not re-fetch when position changes minimally', () async {
      container.read(mapProvider);
      await Future<void>.delayed(Duration.zero);

      final pos1 = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      locationRepo.emitPosition(pos1);
      await Future<void>.delayed(Duration.zero);

      final fetchCountAfterFirst = cellRepo.fetchCallCount;

      final pos2 = LocationState(
        lat: 37.7749001,
        lng: -122.4194001,
        accuracy: 5.0,
        timestamp: DateTime(2026, 1, 1, 0, 0, 1),
        isConfident: true,
      );
      locationRepo.emitPosition(pos2);
      await Future<void>.delayed(Duration.zero);

      expect(cellRepo.fetchCallCount, equals(fetchCountAfterFirst));
    });

    test('uses category map', () async {
      container.read(mapProvider);
      await Future<void>.delayed(Duration.zero);

      final position = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      locationRepo.emitPosition(position);
      await Future<void>.delayed(Duration.zero);

      final mapEvents =
          obs.events.where((e) => e.event.startsWith('map.')).toList();
      expect(mapEvents, isNotEmpty);
      for (final event in mapEvents) {
        expect(event.category, 'map');
      }
    });
  });
}
