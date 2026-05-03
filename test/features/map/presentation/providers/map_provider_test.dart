import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/core/domain/entities/user_profile.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/core/observability/observable_use_case_provider.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
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

  @override
  Future<List<Cell>> fetchCellsInRadius(
      double lat, double lng, double radiusMeters,
      {String? traceId}) async {
    fetchCallCount++;
    if (shouldThrow) throw Exception('Cell fetch error');
    return cells;
  }

  @override
  Future<void> recordVisit(String userId, String cellId,
      {String? traceId}) async {}

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

ProviderContainer makeContainer({
  required TestObservabilityService obs,
  required ControllableMockLocationRepository locationRepo,
  required ControllableMockCellRepository cellRepo,
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
    ],
  );
}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._state);

  final AuthState _state;

  @override
  AuthState build() => _state;
}

void main() {
  group('MapNotifier', () {
    late ProviderContainer container;
    late TestObservabilityService obs;
    late ControllableMockLocationRepository locationRepo;
    late ControllableMockCellRepository cellRepo;

    setUp(() {
      obs = TestObservabilityService();
      locationRepo = ControllableMockLocationRepository();
      cellRepo = ControllableMockCellRepository();
      container = makeContainer(
        obs: obs,
        locationRepo: locationRepo,
        cellRepo: cellRepo,
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
        polygons: [[[]]],
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

    test('logs map.cells_fetch_complete with cell stats when ready', () async {
      final cell = Cell(
        id: 'cell-1',
        habitats: [],
        polygons: [[[
          (lat: 0.0, lng: 0.0),
          (lat: 1.0, lng: 0.0),
          (lat: 1.0, lng: 1.0),
        ]]],
        districtId: 'd1',
        cityId: 'c1',
        stateId: 's1',
        countryId: 'co1',
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
