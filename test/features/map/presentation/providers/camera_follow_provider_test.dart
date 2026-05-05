import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/entities/camera_follow_config.dart';
import 'package:earth_nova/features/map/domain/entities/location_state.dart';
import 'package:earth_nova/features/map/domain/entities/spline_config.dart';
import 'package:earth_nova/features/map/domain/repositories/location_repository.dart';
import 'package:earth_nova/features/map/presentation/providers/camera_follow_provider.dart';
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
      mapObservabilityProvider.overrideWithValue(obs),
      locationObservabilityProvider.overrideWithValue(obs),
      locationRepositoryProvider.overrideWithValue(repo),
    ],
  );
}

void main() {
  group('CameraFollowConfig', () {
    test('camera follow is configured faster than gameplay marker spline', () {
      final cameraFactor = CameraFollowConfig.lerpFactor(20.0);
      final gameplayFactor = SplineConfig.lerpFactor(20.0);

      expect(cameraFactor, greaterThan(gameplayFactor));
    });

    test('camera lerp factor remains bounded', () {
      expect(CameraFollowConfig.minLerpFactor, greaterThan(0.0));
      expect(CameraFollowConfig.minLerpFactor,
          lessThan(CameraFollowConfig.maxLerpFactor));
      expect(CameraFollowConfig.maxLerpFactor, lessThanOrEqualTo(1.0));
    });
  });

  group('CameraFollowNotifier', () {
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

    test('starts without a camera fix before GPS is active', () {
      final state = container.read(cameraFollowProvider);

      expect(state.hasFix, isFalse);
    });

    test('snaps only the first GPS fix to avoid a globe pan', () async {
      container.read(cameraFollowProvider);

      repo.emitPosition(LocationState(
        lat: 45.9636,
        lng: -66.6431,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final state = container.read(cameraFollowProvider);
      expect(state.hasFix, isTrue);
      expect(state.lat, closeTo(45.9636, 0.000001));
      expect(state.lng, closeTo(-66.6431, 0.000001));
      expect(obs.eventNames, contains('map.camera_follow_started'));
    });

    test('lerps subsequent GPS updates instead of snapping', () async {
      container.read(cameraFollowProvider);

      repo.emitPosition(LocationState(
        lat: 45.9636,
        lng: -66.6431,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      repo.emitPosition(LocationState(
        lat: 45.9646,
        lng: -66.6421,
        accuracy: 5.0,
        timestamp: DateTime(2026, 1, 1, 0, 0, 1),
        isConfident: true,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(cameraFollowProvider);
      expect(state.lat, greaterThan(45.9636));
      expect(state.lng, greaterThan(-66.6431));
      expect(state.lat, lessThan(45.9646));
      expect(state.lng, lessThan(-66.6421));
    });

    test('camera gets closer to raw GPS over time', () async {
      container.read(cameraFollowProvider);

      repo.emitPosition(LocationState(
        lat: 45.9636,
        lng: -66.6431,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      repo.emitPosition(LocationState(
        lat: 45.9660,
        lng: -66.6400,
        accuracy: 5.0,
        timestamp: DateTime(2026, 1, 1, 0, 0, 1),
        isConfident: true,
      ));

      await Future<void>.delayed(const Duration(milliseconds: 40));
      final earlyGap = container.read(cameraFollowProvider).gapDistance;

      await Future<void>.delayed(const Duration(milliseconds: 160));
      final laterGap = container.read(cameraFollowProvider).gapDistance;

      expect(laterGap, lessThan(earlyGap));
    });
  });
}
