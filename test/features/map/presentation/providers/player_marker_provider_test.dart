import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/entities/location_state.dart';
import 'package:earth_nova/features/map/domain/entities/spline_config.dart';
import 'package:earth_nova/features/map/domain/repositories/location_repository.dart';
import 'package:earth_nova/features/map/presentation/providers/location_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/player_marker_provider.dart';

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
  final bool _permissionGranted = true;
  LocationState? _currentPosition;

  @override
  Stream<LocationState> get positionStream => _controller.stream;

  @override
  Future<LocationState> getCurrentPosition() async {
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

  void dispose() => _controller.close();
}

ProviderContainer makeContainer({
  required TestObservabilityService obs,
  required ControllableMockLocationRepository repo,
}) {
  return ProviderContainer(
    overrides: [
      playerMarkerObservabilityProvider.overrideWithValue(obs),
      locationObservabilityProvider.overrideWithValue(obs),
      locationRepositoryProvider.overrideWithValue(repo),
    ],
  );
}

void main() {
  group('SplineConfig', () {
    test('ringThresholdMeters is between 30 and 50', () {
      expect(SplineConfig.ringThresholdMeters, greaterThanOrEqualTo(30.0));
      expect(SplineConfig.ringThresholdMeters, lessThanOrEqualTo(50.0));
    });

    test('minLerpFactor is positive and less than maxLerpFactor', () {
      expect(SplineConfig.minLerpFactor, greaterThan(0.0));
      expect(SplineConfig.minLerpFactor, lessThan(SplineConfig.maxLerpFactor));
    });

    test('maxLerpFactor is at most 1.0', () {
      expect(SplineConfig.maxLerpFactor, lessThanOrEqualTo(1.0));
    });

    test('lerpFactor returns minLerpFactor when gap is near zero', () {
      final factor = SplineConfig.lerpFactor(0.0);
      expect(factor, closeTo(SplineConfig.minLerpFactor, 0.01));
    });

    test('lerpFactor returns maxLerpFactor when gap is very large', () {
      final factor = SplineConfig.lerpFactor(10000.0);
      expect(factor, closeTo(SplineConfig.maxLerpFactor, 0.01));
    });

    test('lerpFactor increases with distance', () {
      final near = SplineConfig.lerpFactor(1.0);
      final mid = SplineConfig.lerpFactor(50.0);
      final far = SplineConfig.lerpFactor(200.0);
      expect(near, lessThan(mid));
      expect(mid, lessThan(far));
    });
  });

  group('PlayerMarkerNotifier', () {
    late ProviderContainer container;
    late TestObservabilityService obs;
    late ControllableMockLocationRepository repo;

    setUp(() {
      obs = TestObservabilityService();
      repo = ControllableMockLocationRepository();
      container = makeContainer(obs: obs, repo: repo);
    });

    tearDown(() {
      container.dispose();
      repo.dispose();
    });

    test('initial state has isRing false', () {
      final state = container.read(playerMarkerProvider);
      expect(state.isRing, isFalse);
    });

    test('initial marker position is at origin', () {
      final state = container.read(playerMarkerProvider);
      expect(state.lat, 0.0);
      expect(state.lng, 0.0);
    });

    test('marker position lerps toward GPS position over ticks', () async {
      container.read(playerMarkerProvider);

      final gpsPos = LocationState(
        lat: 10.0,
        lng: 10.0,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      repo.emitPosition(gpsPos);
      await Future<void>.delayed(Duration.zero);

      // Trigger multiple ticks
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = container.read(playerMarkerProvider);
      // Marker should have moved toward GPS (not still at 0,0)
      expect(state.lat, greaterThan(0.0));
      expect(state.lng, greaterThan(0.0));
      // But not yet at GPS position (spline, not snap)
      expect(state.lat, lessThan(10.0));
      expect(state.lng, lessThan(10.0));
    });

    test('marker is closer to GPS after more ticks', () async {
      container.read(playerMarkerProvider);

      final gpsPos = LocationState(
        lat: 1.0,
        lng: 1.0,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      repo.emitPosition(gpsPos);
      await Future<void>.delayed(Duration.zero);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final stateEarly = container.read(playerMarkerProvider);
      final gapEarly = stateEarly.gapDistance;

      await Future<void>.delayed(const Duration(milliseconds: 200));
      final stateLater = container.read(playerMarkerProvider);
      final gapLater = stateLater.gapDistance;

      expect(gapLater, lessThan(gapEarly));
    });

    test('isRing becomes true when gap exceeds ring threshold', () async {
      container.read(playerMarkerProvider);

      // GPS jumps far away (simulating large gap)
      final farPos = LocationState(
        lat: 1.0, // ~111km from origin
        lng: 0.0,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      repo.emitPosition(farPos);
      await Future<void>.delayed(Duration.zero);

      // After GPS update, gap should be huge → isRing = true
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(playerMarkerProvider);
      expect(state.isRing, isTrue);
    });

    test('isRing becomes false when gap shrinks below threshold', () async {
      container.read(playerMarkerProvider);

      // First: large gap → ring
      final farPos = LocationState(
        lat: 1.0,
        lng: 0.0,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      repo.emitPosition(farPos);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Verify ring state
      expect(container.read(playerMarkerProvider).isRing, isTrue);

      // Now GPS moves to same position as marker (gap shrinks)
      final currentMarker = container.read(playerMarkerProvider);

      // Emit GPS at marker position → gap = 0
      final nearPos = LocationState(
        lat: currentMarker.lat,
        lng: currentMarker.lng,
        accuracy: 5.0,
        timestamp: DateTime(2026, 1, 1, 0, 0, 1),
        isConfident: true,
      );
      repo.emitPosition(nearPos);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = container.read(playerMarkerProvider);
      expect(state.isRing, isFalse);
    });

    test('gapDistance reflects distance between marker and GPS', () async {
      container.read(playerMarkerProvider);

      final gpsPos = LocationState(
        lat: 0.001, // ~111m north
        lng: 0.0,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      repo.emitPosition(gpsPos);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // After a tick, gap should be reflected in state
      final state = container.read(playerMarkerProvider);
      expect(state.gapDistance, greaterThan(0.0));
    });

    test('logs map.gps_accuracy_degraded when isRing transitions to true',
        () async {
      container.read(playerMarkerProvider);

      final farPos = LocationState(
        lat: 1.0,
        lng: 0.0,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      repo.emitPosition(farPos);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(obs.eventNames, contains('map.gps_accuracy_degraded'));
    });

    test('logs map.gps_accuracy_restored when isRing transitions to false',
        () async {
      container.read(playerMarkerProvider);

      // Trigger ring state
      final farPos = LocationState(
        lat: 1.0,
        lng: 0.0,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      repo.emitPosition(farPos);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Move GPS to marker position to restore
      final currentMarker = container.read(playerMarkerProvider);
      final nearPos = LocationState(
        lat: currentMarker.lat,
        lng: currentMarker.lng,
        accuracy: 5.0,
        timestamp: DateTime(2026, 1, 1, 0, 0, 1),
        isConfident: true,
      );
      repo.emitPosition(nearPos);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(obs.eventNames, contains('map.gps_accuracy_restored'));
    });

    test('uses category map', () async {
      container.read(playerMarkerProvider);

      final farPos = LocationState(
        lat: 1.0,
        lng: 0.0,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      repo.emitPosition(farPos);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final markerEvents = obs.events
          .where((e) =>
              e.event == 'map.gps_accuracy_degraded' ||
              e.event == 'map.gps_accuracy_restored')
          .toList();
      for (final event in markerEvents) {
        expect(event.category, 'map');
      }
    });

    test('speed is proportional to distance — larger gap moves faster',
        () async {
      // Test with a small gap
      final obsSmall = TestObservabilityService();
      final repoSmall = ControllableMockLocationRepository();
      final containerSmall = makeContainer(obs: obsSmall, repo: repoSmall);
      addTearDown(() {
        containerSmall.dispose();
        repoSmall.dispose();
      });

      containerSmall.read(playerMarkerProvider);
      repoSmall.emitPosition(LocationState(
        lat: 0.0001, // ~11m
        lng: 0.0,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final stateSmall = containerSmall.read(playerMarkerProvider);
      final progressSmall = stateSmall.lat / 0.0001; // fraction covered

      // Test with a large gap
      final obsLarge = TestObservabilityService();
      final repoLarge = ControllableMockLocationRepository();
      final containerLarge = makeContainer(obs: obsLarge, repo: repoLarge);
      addTearDown(() {
        containerLarge.dispose();
        repoLarge.dispose();
      });

      containerLarge.read(playerMarkerProvider);
      repoLarge.emitPosition(LocationState(
        lat: 0.01, // ~1.1km
        lng: 0.0,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final stateLarge = containerLarge.read(playerMarkerProvider);
      final progressLarge = stateLarge.lat / 0.01; // fraction covered

      // Larger gap should cover a larger fraction in the same time
      expect(progressLarge, greaterThan(progressSmall));
    });
  });
}
