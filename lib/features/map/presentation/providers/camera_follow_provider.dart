import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/observability/observable_notifier.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/entities/camera_follow_config.dart';
import 'package:earth_nova/features/map/domain/entities/camera_follow_state.dart';
import 'package:earth_nova/features/map/domain/entities/location_state.dart';
import 'package:earth_nova/features/map/presentation/providers/location_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/map_provider.dart';

final cameraFollowProvider =
    NotifierProvider<CameraFollowNotifier, CameraFollowState>(
        CameraFollowNotifier.new);

class CameraFollowNotifier extends ObservableNotifier<CameraFollowState> {
  Timer? _ticker;
  double _gpsLat = 0.0;
  double _gpsLng = 0.0;
  bool _hasGps = false;

  static const _tickInterval = Duration(milliseconds: 16);

  @override
  ObservabilityService get obs => ref.watch(mapObservabilityProvider);

  @override
  String get category => 'map';

  @override
  CameraFollowState build() {
    ref.listen<LocationProviderState>(locationProvider, (_, next) {
      if (next is LocationProviderActive) {
        _setGpsTarget(next.location);
      }
    });

    ref.onDispose(() => _ticker?.cancel());
    _ticker = Timer.periodic(_tickInterval, (_) => _tick());

    final currentLocation = ref.read(locationProvider);
    if (currentLocation is LocationProviderActive) {
      _gpsLat = currentLocation.location.lat;
      _gpsLng = currentLocation.location.lng;
      _hasGps = true;
      return CameraFollowState(
        lat: _gpsLat,
        lng: _gpsLng,
        hasFix: true,
        gapDistance: 0.0,
      );
    }

    return const CameraFollowState.noFix();
  }

  void _setGpsTarget(LocationState location) {
    _gpsLat = location.lat;
    _gpsLng = location.lng;
    _hasGps = true;

    if (!state.hasFix) {
      transition(
        CameraFollowState(
          lat: _gpsLat,
          lng: _gpsLng,
          hasFix: true,
          gapDistance: 0.0,
        ),
        'map.camera_follow_started',
        data: {
          'flow': 'map.bootstrap',
          'phase': TelemetryFlowPhase.dependencyReady.wireName,
          'dependency': 'camera_follow',
        },
      );
    }
  }

  void _tick() {
    if (!_hasGps || !state.hasFix) return;

    final current = state;
    final gapMeters = _haversineMeters(
      current.lat,
      current.lng,
      _gpsLat,
      _gpsLng,
    );

    if (gapMeters <= CameraFollowConfig.settleDistanceMeters) {
      if (current.gapDistance == 0.0 &&
          current.lat == _gpsLat &&
          current.lng == _gpsLng) {
        return;
      }
      // silentTransition: camera follow settle ticks can run every animation
      // frame; only the initial camera-follow start is useful telemetry.
      silentTransition(CameraFollowState(
        lat: _gpsLat,
        lng: _gpsLng,
        hasFix: true,
        gapDistance: 0.0,
      ));
      return;
    }

    final factor = CameraFollowConfig.lerpFactor(gapMeters);
    final newLat = _lerp(current.lat, _gpsLat, factor);
    final newLng = _lerp(current.lng, _gpsLng, factor);

    // silentTransition: camera follow can tick at 60 fps. Logging each frame
    // would flood telemetry while adding no useful state-transition signal.
    silentTransition(CameraFollowState(
      lat: newLat,
      lng: newLng,
      hasFix: true,
      gapDistance: gapMeters,
    ));
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  static double _haversineMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusM = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusM * c;
  }

  static double _toRad(double deg) => deg * math.pi / 180.0;
}
