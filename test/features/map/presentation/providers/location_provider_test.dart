import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/entities/location_state.dart';
import 'package:earth_nova/features/map/domain/repositories/location_repository.dart';
import 'package:earth_nova/features/map/presentation/providers/location_provider.dart';

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
  Future<LocationState> getCurrentPosition() async {
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
  Future<bool> requestPermission() async => _permissionGranted;

  void emitPosition(LocationState position) {
    _currentPosition = position;
    _controller.add(position);
  }

  void emitError(Object error) => _controller.addError(error);

  void setPermissionGranted(bool granted) => _permissionGranted = granted;
  void setThrowOnGetCurrent(bool value) => _throwOnGetCurrent = value;

  void dispose() => _controller.close();
}

void main() {
  group('LocationNotifier', () {
    late ProviderContainer container;
    late TestObservabilityService obs;
    late ControllableMockLocationRepository repo;

    setUp(() {
      obs = TestObservabilityService();
      repo = ControllableMockLocationRepository();
      container = ProviderContainer(
        overrides: [
          locationObservabilityProvider.overrideWithValue(obs),
          locationRepositoryProvider.overrideWithValue(repo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      repo.dispose();
    });

    test('initial state is loading', () {
      final state = container.read(locationProvider);
      expect(state, isA<LocationProviderLoading>());
    });

    test('transitions to active after receiving first position', () async {
      container.read(locationProvider);

      final position = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      repo.emitPosition(position);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(locationProvider);
      expect(state, isA<LocationProviderActive>());
      final active = state as LocationProviderActive;
      expect(active.location.lat, 37.7749);
      expect(active.location.lng, -122.4194);
    });

    test('transitions to permissionDenied when permission is denied', () async {
      repo.setPermissionGranted(false);

      final c = ProviderContainer(
        overrides: [
          locationObservabilityProvider.overrideWithValue(obs),
          locationRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(c.dispose);

      c.read(locationProvider);
      await Future<void>.delayed(Duration.zero);

      final state = c.read(locationProvider);
      expect(state, isA<LocationProviderPermissionDenied>());
    });

    test('transitions to error when getCurrentPosition throws', () async {
      repo.setThrowOnGetCurrent(true);

      final c = ProviderContainer(
        overrides: [
          locationObservabilityProvider.overrideWithValue(obs),
          locationRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(c.dispose);

      c.read(locationProvider);
      await Future<void>.delayed(Duration.zero);

      final state = c.read(locationProvider);
      expect(state, isA<LocationProviderError>());
      final error = state as LocationProviderError;
      expect(error.message, isNotEmpty);
    });

    test('logs map.gps_started event on build', () async {
      container.read(locationProvider);
      await Future<void>.delayed(Duration.zero);

      expect(obs.eventNames, contains('map.gps_started'));
    });

    test('logs map.gps_position_updated on each position', () async {
      container.read(locationProvider);

      final position = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      repo.emitPosition(position);
      await Future<void>.delayed(Duration.zero);

      expect(obs.eventNames, contains('map.gps_position_updated'));
    });

    test('logs map.gps_permission_denied when permission denied', () async {
      repo.setPermissionGranted(false);

      final c = ProviderContainer(
        overrides: [
          locationObservabilityProvider.overrideWithValue(obs),
          locationRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(c.dispose);

      c.read(locationProvider);
      await Future<void>.delayed(Duration.zero);

      expect(obs.eventNames, contains('map.gps_permission_denied'));
    });

    test('logs map.gps_error when error occurs', () async {
      repo.setThrowOnGetCurrent(true);

      final c = ProviderContainer(
        overrides: [
          locationObservabilityProvider.overrideWithValue(obs),
          locationRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(c.dispose);

      c.read(locationProvider);
      await Future<void>.delayed(Duration.zero);

      expect(obs.eventNames, contains('map.gps_error'));
    });

    test('uses category map', () async {
      container.read(locationProvider);
      await Future<void>.delayed(Duration.zero);

      for (final event in obs.events) {
        expect(event.category, 'map');
      }
    });

    test('updates state on multiple position emissions', () async {
      container.read(locationProvider);

      final pos1 = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      final pos2 = LocationState(
        lat: 37.7750,
        lng: -122.4195,
        accuracy: 3.0,
        timestamp: DateTime(2026, 1, 1, 0, 0, 1),
        isConfident: true,
      );

      repo.emitPosition(pos1);
      await Future<void>.delayed(Duration.zero);
      repo.emitPosition(pos2);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(locationProvider);
      expect(state, isA<LocationProviderActive>());
      final active = state as LocationProviderActive;
      expect(active.location.lat, 37.7750);
    });

    test('stream error transitions to paused (not permanent error)', () async {
      container.read(locationProvider);

      final position = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      repo.emitPosition(position);
      await Future<void>.delayed(Duration.zero);

      // Confirm active before error
      expect(container.read(locationProvider), isA<LocationProviderActive>());

      // Emit a stream error (e.g. geolocator timeout)
      repo.emitError(Exception('GPS timeout'));
      await Future<void>.delayed(Duration.zero);

      // Must NOT transition to LocationProviderError — shows paused banner instead
      final state = container.read(locationProvider);
      expect(
        state,
        isA<LocationProviderPaused>(),
        reason: 'A transient stream error must show a paused banner, '
            'not strand the user on a permanent error screen.',
      );
    });

    test('stream error recovery resumes active state automatically', () async {
      container.read(locationProvider);

      final position = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      repo.emitPosition(position);
      await Future<void>.delayed(Duration.zero);

      // Trigger paused state via stream error
      repo.emitError(Exception('GPS timeout'));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(locationProvider), isA<LocationProviderPaused>());

      // GPS recovers — emit a new position
      final recoveredPosition = LocationState(
        lat: 37.7750,
        lng: -122.4195,
        accuracy: 5.0,
        timestamp: DateTime(2026, 1, 1, 0, 0, 5),
        isConfident: true,
      );
      repo.emitPosition(recoveredPosition);
      await Future<void>.delayed(Duration.zero);

      // Must resume active without manual refresh
      final state = container.read(locationProvider);
      expect(
        state,
        isA<LocationProviderActive>(),
        reason: 'Discovery must resume automatically when GPS returns.',
      );
      final active = state as LocationProviderActive;
      expect(active.location.lat, 37.7750);
    });

    test('stream error logs map.gps_paused event', () async {
      container.read(locationProvider);

      final position = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      repo.emitPosition(position);
      await Future<void>.delayed(Duration.zero);

      repo.emitError(Exception('GPS timeout'));
      await Future<void>.delayed(Duration.zero);

      expect(obs.eventNames, contains('map.gps_paused'));
    });

    test('GPS recovery logs map.gps_resumed event', () async {
      container.read(locationProvider);

      final position = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      repo.emitPosition(position);
      await Future<void>.delayed(Duration.zero);

      repo.emitError(Exception('GPS timeout'));
      await Future<void>.delayed(Duration.zero);

      final recoveredPosition = LocationState(
        lat: 37.7750,
        lng: -122.4195,
        accuracy: 5.0,
        timestamp: DateTime(2026, 1, 1, 0, 0, 5),
        isConfident: true,
      );
      repo.emitPosition(recoveredPosition);
      await Future<void>.delayed(Duration.zero);

      expect(obs.eventNames, contains('map.gps_resumed'));
    });

    test('stream error is logged as map.gps_stream_error', () async {
      container.read(locationProvider);

      final position = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      repo.emitPosition(position);
      await Future<void>.delayed(Duration.zero);

      repo.emitError(Exception('GPS timeout'));
      await Future<void>.delayed(Duration.zero);

      expect(obs.eventNames, contains('map.gps_stream_error'));
    });

    test('stream error does not log map.gps_error (no permanent error state)',
        () async {
      container.read(locationProvider);

      final position = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      repo.emitPosition(position);
      await Future<void>.delayed(Duration.zero);

      repo.emitError(Exception('transient error'));
      await Future<void>.delayed(Duration.zero);

      // map.gps_error is only for getCurrentPosition failures, not stream errors
      expect(obs.eventNames, isNot(contains('map.gps_error')));
    });
  });
}
