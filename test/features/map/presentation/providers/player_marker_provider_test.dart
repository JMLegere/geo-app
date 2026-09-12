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
  Future<LocationState> getCurrentPosition({String? traceId}) async {
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

LocationState _trustedPosition(double lat, double lng, {DateTime? timestamp}) {
  return LocationState(
    lat: lat,
    lng: lng,
    accuracy: 5.0,
    timestamp: timestamp ?? DateTime(2026),
    isConfident: true,
  );
}

LocationState _untrustedPosition(
  double lat,
  double lng, {
  required double accuracy,
  DateTime? timestamp,
}) {
  return LocationState(
    lat: lat,
    lng: lng,
    accuracy: accuracy,
    timestamp: timestamp ?? DateTime(2026),
    isConfident: false,
  );
}

Future<void> _anchorMarkerAt(
  ControllableMockLocationRepository repo,
  double lat,
  double lng,
) async {
  repo.emitPosition(_trustedPosition(lat, lng));
  await Future<void>.delayed(Duration.zero);
}

void main() {
  group('SplineConfig', () {
    test('ringThresholdMeters is 100m', () {
      expect(SplineConfig.ringThresholdMeters, 100.0);
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

    test('bounded lerp scales speed proportionally to gap size', () {
      final tickInterval = const Duration(milliseconds: 16);
      final factorAt100m = SplineConfig.boundedLerpFactor(
        gapMeters: 100.0,
        tickInterval: tickInterval,
      );
      final factorAt50m = SplineConfig.boundedLerpFactor(
        gapMeters: 50.0,
        tickInterval: tickInterval,
      );

      final tickSeconds = tickInterval.inMilliseconds / 1000.0;
      final speedAt100m = factorAt100m * 100.0 / tickSeconds;
      final speedAt50m = factorAt50m * 50.0 / tickSeconds;

      expect(speedAt100m, closeTo(100.0, 2.0));
      expect(speedAt50m, closeTo(50.0, 2.0));
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

    test(
      'first GPS fix anchors marker instead of chasing from origin',
      () async {
        container.read(playerMarkerProvider);

        repo.emitPosition(_trustedPosition(45.9636, -66.6431));
        await Future<void>.delayed(Duration.zero);

        final state = container.read(playerMarkerProvider);
        expect(state.lat, closeTo(45.9636, 0.0000001));
        expect(state.lng, closeTo(-66.6431, 0.0000001));
        expect(state.isRing, isFalse);
      },
    );

    test('settles under 5cm without further state emissions', () async {
      container.read(playerMarkerProvider);
      await _anchorMarkerAt(repo, 0.0, 0.0);

      repo.emitPosition(_trustedPosition(0.0000006, 0.0));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(playerMarkerProvider).lat, lessThan(0.0000006));

      repo.emitPosition(
        _trustedPosition(
          0.0000003,
          0.0,
          timestamp: DateTime(2026, 1, 1, 0, 0, 1),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final settled = container.read(playerMarkerProvider);
      expect(settled.lat, 0.0000003);
      expect(settled.lng, 0.0);
      expect(settled.gapDistance, 0.0);

      var updates = 0;
      final subscription = container.listen(
        playerMarkerProvider,
        (_, __) => updates++,
      );
      addTearDown(subscription.close);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(updates, 0);
    });

    test('low-confidence GPS still drags marker below ring distance', () async {
      container.read(playerMarkerProvider);

      repo.emitPosition(_trustedPosition(45.9636, -66.6431));
      await Future<void>.delayed(Duration.zero);

      repo.emitPosition(
        _untrustedPosition(
          45.9639,
          -66.6431,
          accuracy: 80.0,
          timestamp: DateTime(2026, 1, 1, 0, 0, 1),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(playerMarkerProvider);
      expect(state.isRing, isFalse);
      expect(state.lat, greaterThan(45.9636));
      expect(state.lat, lessThan(45.9639));
      expect(state.lng, closeTo(-66.6431, 0.00001));
    });

    test('marker position lerps toward GPS position over ticks', () async {
      container.read(playerMarkerProvider);
      await _anchorMarkerAt(repo, 0.0, 0.0);

      repo.emitPosition(_trustedPosition(0.0002, 0.0));
      await Future<void>.delayed(Duration.zero);

      // Trigger multiple ticks
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = container.read(playerMarkerProvider);
      // Marker should have moved toward GPS (not still at 0,0)
      expect(state.lat, greaterThan(0.0));
      // But not yet at GPS position (spline, not snap)
      expect(state.lat, lessThan(0.0002));
    });

    test('marker is closer to GPS after more ticks', () async {
      container.read(playerMarkerProvider);
      await _anchorMarkerAt(repo, 0.0, 0.0);

      repo.emitPosition(_trustedPosition(0.0002, 0.0));
      await Future<void>.delayed(Duration.zero);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final stateEarly = container.read(playerMarkerProvider);
      final gapEarly = stateEarly.gapDistance;

      await Future<void>.delayed(const Duration(milliseconds: 200));
      final stateLater = container.read(playerMarkerProvider);
      final gapLater = stateLater.gapDistance;

      expect(gapLater, lessThan(gapEarly));
    });

    test(
      'isRing becomes true when marker-geolocation gap exceeds 100m',
      () async {
        container.read(playerMarkerProvider);
        await _anchorMarkerAt(repo, 0.0, 0.0);

        // GPS jumps beyond the 100m ring threshold.
        repo.emitPosition(_trustedPosition(0.001, 0.0));
        await Future<void>.delayed(Duration.zero);

        await Future<void>.delayed(const Duration(milliseconds: 50));

        final state = container.read(playerMarkerProvider);
        expect(state.isRing, isTrue);
        expect(
          state.lat,
          greaterThan(0.0),
          reason: 'Marker should still drag toward the geo location in ring.',
        );
      },
    );

    test('isRing becomes false when gap shrinks below threshold', () async {
      container.read(playerMarkerProvider);
      await _anchorMarkerAt(repo, 0.0, 0.0);

      // First: large gap → ring
      repo.emitPosition(_trustedPosition(0.001, 0.0));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Verify ring state
      expect(container.read(playerMarkerProvider).isRing, isTrue);

      // Now GPS moves to same position as marker (gap shrinks)
      final currentMarker = container.read(playerMarkerProvider);
      repo.emitPosition(
        _trustedPosition(
          currentMarker.lat,
          currentMarker.lng,
          timestamp: DateTime(2026, 1, 1, 0, 0, 1),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = container.read(playerMarkerProvider);
      expect(state.isRing, isFalse);
    });

    test('gapDistance reflects distance between marker and GPS', () async {
      container.read(playerMarkerProvider);
      await _anchorMarkerAt(repo, 0.0, 0.0);

      repo.emitPosition(_trustedPosition(0.0002, 0.0));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // After a tick, gap should be reflected in state
      final state = container.read(playerMarkerProvider);
      expect(state.gapDistance, greaterThan(0.0));
    });

    test(
      'logs map.gps_accuracy_degraded when isRing transitions to true',
      () async {
        container.read(playerMarkerProvider);
        await _anchorMarkerAt(repo, 0.0, 0.0);

        repo.emitPosition(_trustedPosition(0.001, 0.0));
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(obs.eventNames, contains('map.gps_accuracy_degraded'));
      },
    );

    test(
      'logs map.gps_accuracy_restored when isRing transitions to false',
      () async {
        container.read(playerMarkerProvider);
        await _anchorMarkerAt(repo, 0.0, 0.0);

        // Trigger ring state
        repo.emitPosition(_trustedPosition(0.001, 0.0));
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Move GPS to marker position to restore
        final currentMarker = container.read(playerMarkerProvider);
        repo.emitPosition(
          _trustedPosition(
            currentMarker.lat,
            currentMarker.lng,
            timestamp: DateTime(2026, 1, 1, 0, 0, 1),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));

        expect(obs.eventNames, contains('map.gps_accuracy_restored'));
      },
    );

    test('uses category map', () async {
      container.read(playerMarkerProvider);
      await _anchorMarkerAt(repo, 0.0, 0.0);

      repo.emitPosition(_trustedPosition(0.001, 0.0));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final markerEvents = obs.events
          .where(
            (e) =>
                e.event == 'map.gps_accuracy_degraded' ||
                e.event == 'map.gps_accuracy_restored',
          )
          .toList();
      for (final event in markerEvents) {
        expect(event.category, 'map');
      }
    });

    test('trusted movement is speed bounded below ring threshold', () async {
      container.read(playerMarkerProvider);
      await _anchorMarkerAt(repo, 0.0, 0.0);

      repo.emitPosition(_trustedPosition(0.0003, 0.0)); // ~33m north
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(playerMarkerProvider);
      expect(state.isRing, isFalse);
      expect(state.lat, greaterThan(0.0));
      expect(
        state.lat,
        lessThan(0.00005),
        reason: 'Marker should move smoothly, not cover most of 33m in 50ms.',
      );
    });
  });
}
