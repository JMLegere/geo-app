import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/observability/observable_notifier.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/entities/player_marker_state.dart';
import 'package:earth_nova/features/map/domain/entities/spline_config.dart';
import 'package:earth_nova/features/map/presentation/providers/location_provider.dart';

final playerMarkerObservabilityProvider = Provider<ObservabilityService>((ref) {
  throw UnimplementedError('Must be overridden with overrideWithValue');
});

final playerMarkerProvider =
    NotifierProvider<PlayerMarkerNotifier, PlayerMarkerState>(
        PlayerMarkerNotifier.new);

class PlayerMarkerNotifier extends ObservableNotifier<PlayerMarkerState> {
  Timer? _ticker;
  double _gpsLat = 0.0;
  double _gpsLng = 0.0;
  bool _hasGps = false;
  DateTime? _ringEnteredAt;

  static const _tickInterval = Duration(milliseconds: 16);

  @override
  ObservabilityService get obs => ref.watch(playerMarkerObservabilityProvider);

  @override
  String get category => 'map';

  @override
  PlayerMarkerState build() {
    ref.listen<LocationProviderState>(locationProvider, (_, next) {
      if (next is LocationProviderActive) {
        _gpsLat = next.location.lat;
        _gpsLng = next.location.lng;
        _hasGps = true;
      }
    });

    ref.onDispose(() => _ticker?.cancel());

    _ticker = Timer.periodic(_tickInterval, (_) => _tick());

    return const PlayerMarkerState(
      lat: 0.0,
      lng: 0.0,
      isRing: false,
      gapDistance: 0.0,
    );
  }

  void _tick() {
    if (!_hasGps) return;

    final current = state;
    final gapMeters = _haversineMeters(
      current.lat,
      current.lng,
      _gpsLat,
      _gpsLng,
    );

    final factor = SplineConfig.lerpFactor(gapMeters);
    final newLat = _lerp(current.lat, _gpsLat, factor);
    final newLng = _lerp(current.lng, _gpsLng, factor);

    final wasRing = current.isRing;
    final isRingNow = gapMeters >= SplineConfig.ringThresholdMeters;

    if (!wasRing && isRingNow) {
      _ringEnteredAt = DateTime.now();
      transition(
        PlayerMarkerState(
          lat: newLat,
          lng: newLng,
          isRing: true,
          gapDistance: gapMeters,
        ),
        'map.gps_accuracy_degraded',
        data: {
          'accuracy_meters': gapMeters,
          'gap_meters': gapMeters,
        },
      );
    } else if (wasRing && !isRingNow) {
      final timeInRingMs = _ringEnteredAt != null
          ? DateTime.now().difference(_ringEnteredAt!).inMilliseconds
          : 0;
      _ringEnteredAt = null;
      transition(
        PlayerMarkerState(
          lat: newLat,
          lng: newLng,
          isRing: false,
          gapDistance: gapMeters,
        ),
        'map.gps_accuracy_restored',
        data: {'time_in_ring_ms': timeInRingMs},
      );
    } else {
      // silentTransition: 60 fps interpolation tick — logging every frame
      // (~3600 events/min/user) would flood Supabase. Ring transitions above
      // are logged; smooth movement is intentionally silent.
      silentTransition(PlayerMarkerState(
        lat: newLat,
        lng: newLng,
        isRing: isRingNow,
        gapDistance: gapMeters,
      ));
    }
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
