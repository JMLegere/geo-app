import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/observability/observable_notifier.dart';
import 'package:earth_nova/core/observability/observable_use_case_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/entities/location_state.dart';
import 'package:earth_nova/features/map/domain/repositories/location_repository.dart';
import 'package:earth_nova/features/map/domain/use_cases/get_location_stream.dart';

sealed class LocationProviderState {
  const LocationProviderState();
}

class LocationProviderLoading extends LocationProviderState {
  const LocationProviderLoading();
}

class LocationProviderActive extends LocationProviderState {
  const LocationProviderActive(this.location);
  final LocationState location;
}

class LocationProviderPermissionDenied extends LocationProviderState {
  const LocationProviderPermissionDenied();
}

class LocationProviderPaused extends LocationProviderState {
  const LocationProviderPaused();
}

class LocationProviderError extends LocationProviderState {
  const LocationProviderError(this.message);
  final String message;
}

enum DebugLocationMoveDirection {
  north,
  south,
  west,
  east,
}

const _kDebugLocationDefaultLat = 45.9636;
const _kDebugLocationDefaultLng = -66.6431;
const _kDebugLocationMoveMeters = 35.0;
const _kMetersPerDegreeLatitude = 111320.0;

final locationObservabilityProvider = Provider<ObservabilityService>((ref) {
  throw UnimplementedError('Must be overridden with overrideWithValue');
});

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  throw UnimplementedError('Must be overridden with overrideWithValue');
});

final getLocationStreamProvider = Provider<GetLocationStream>(
  (ref) {
    ref.watch(observableUseCaseProvider);
    return GetLocationStream(ref.watch(locationRepositoryProvider),
        ref.watch(locationObservabilityProvider));
  },
);

final locationProvider =
    NotifierProvider<LocationNotifier, LocationProviderState>(
        LocationNotifier.new);

class LocationNotifier extends ObservableNotifier<LocationProviderState> {
  late final LocationRepository _repository;
  StreamSubscription<LocationState>? _subscription;
  bool _disposed = false;
  DateTime? _pausedAt;
  bool _debugLocationEnabled = false;
  LocationState? _debugLocation;

  @override
  ObservabilityService get obs => ref.watch(locationObservabilityProvider);

  @override
  String get category => 'map';

  @override
  LocationProviderState build() {
    _repository = ref.watch(locationRepositoryProvider);
    ref.onDispose(() {
      _disposed = true;
      _subscription?.cancel();
    });
    _start();
    return const LocationProviderLoading();
  }

  void moveDebugLocation(DebugLocationMoveDirection direction) {
    final nextLocation = _movedDebugLocation(direction);
    _debugLocationEnabled = true;
    _debugLocation = nextLocation;
    _pausedAt = null;
    _subscription?.cancel();
    _subscription = null;

    transition(
      LocationProviderActive(nextLocation),
      'map.debug_location_updated',
      data: {
        'flow': 'map.bootstrap',
        'phase': TelemetryFlowPhase.dependencyReady.wireName,
        'dependency': 'debug_location',
        'source': 'debug_controls',
        'direction': direction.name,
        'lat': nextLocation.lat,
        'lng': nextLocation.lng,
        'geo_location_enabled': false,
      },
    );
  }

  void resumeGps() {
    if (!_debugLocationEnabled) return;
    _debugLocationEnabled = false;
    _debugLocation = null;
    _subscription?.cancel();
    _subscription = null;

    transition(
      const LocationProviderLoading(),
      'map.debug_location_disabled',
      data: {
        'flow': 'map.bootstrap',
        'phase': TelemetryFlowPhase.dependencyRequested.wireName,
        'dependency': 'gps',
        'source': 'debug_controls',
        'geo_location_enabled': true,
      },
    );
    unawaited(_start());
  }

  Future<void> _start() async {
    if (_disposed || _debugLocationEnabled) return;
    transition(const LocationProviderLoading(), 'map.gps_started', data: {
      'flow': 'map.bootstrap',
      'phase': TelemetryFlowPhase.dependencyRequested.wireName,
      'dependency': 'gps',
    });

    final granted = await _repository.requestPermission();
    if (_disposed || _debugLocationEnabled) return;
    if (!granted) {
      transition(
        const LocationProviderPermissionDenied(),
        'map.gps_permission_denied',
        data: {
          'flow': 'map.bootstrap',
          'phase': TelemetryFlowPhase.dependencyFailed.wireName,
          'dependency': 'gps_permission',
        },
      );
      return;
    }

    try {
      final initial = await _repository.getCurrentPosition();
      if (_disposed || _debugLocationEnabled) return;
      transition(LocationProviderActive(initial), 'map.gps_position_updated',
          data: {
            'flow': 'map.bootstrap',
            'phase': TelemetryFlowPhase.dependencyReady.wireName,
            'dependency': 'gps',
          });
    } catch (e) {
      if (_disposed || _debugLocationEnabled) return;
      transition(LocationProviderError(e.toString()), 'map.gps_error', data: {
        'flow': 'map.bootstrap',
        'phase': TelemetryFlowPhase.dependencyFailed.wireName,
        'dependency': 'gps',
        'error': e.toString(),
      });
      return;
    }

    _subscribe();
  }

  void _subscribe() {
    if (_debugLocationEnabled) return;
    _subscription?.cancel();
    _subscription = _repository.positionStream.listen(
      (position) {
        if (_debugLocationEnabled) return;
        final wasPaused = state is LocationProviderPaused;
        if (wasPaused) {
          final timeInPausedMs = _pausedAt != null
              ? DateTime.now().difference(_pausedAt!).inMilliseconds
              : 0;
          _pausedAt = null;
          transition(
            LocationProviderActive(position),
            'map.gps_resumed',
            data: {
              'flow': 'map.bootstrap',
              'phase': TelemetryFlowPhase.dependencyReady.wireName,
              'dependency': 'gps',
              'time_in_paused_ms': timeInPausedMs,
            },
          );
        } else {
          transition(
              LocationProviderActive(position), 'map.gps_position_updated',
              data: {
                'flow': 'map.bootstrap',
                'phase': TelemetryFlowPhase.dependencyReady.wireName,
                'dependency': 'gps',
              });
        }
      },
      onError: (Object e, StackTrace st) {
        if (_disposed || _debugLocationEnabled) return;
        obs.logError(e, st, event: 'map.gps_stream_error');
        _pausedAt = DateTime.now();
        transition(const LocationProviderPaused(), 'map.gps_paused', data: {
          'flow': 'map.bootstrap',
          'phase': TelemetryFlowPhase.dependencyFailed.wireName,
          'dependency': 'gps',
          'reason': 'stream_error',
          'error': e.toString(),
        });
        // Do NOT cancel the subscription — keep listening so recovery is
        // automatic when GPS returns. The stream may emit new positions after
        // a transient error without needing a resubscribe.
      },
      cancelOnError: false,
    );
  }

  LocationState _movedDebugLocation(DebugLocationMoveDirection direction) {
    final base = _debugLocation ?? _currentLocationOrDebugDefault();
    final latDelta = _kDebugLocationMoveMeters / _kMetersPerDegreeLatitude;
    final metersPerDegreeLng = _kMetersPerDegreeLatitude *
        math.max(0.01, math.cos(base.lat * math.pi / 180).abs());
    final lngDelta = _kDebugLocationMoveMeters / metersPerDegreeLng;

    final nextLat = switch (direction) {
      DebugLocationMoveDirection.north => base.lat + latDelta,
      DebugLocationMoveDirection.south => base.lat - latDelta,
      DebugLocationMoveDirection.west ||
      DebugLocationMoveDirection.east =>
        base.lat,
    };
    final nextLng = switch (direction) {
      DebugLocationMoveDirection.east => base.lng + lngDelta,
      DebugLocationMoveDirection.west => base.lng - lngDelta,
      DebugLocationMoveDirection.north ||
      DebugLocationMoveDirection.south =>
        base.lng,
    };

    return LocationState(
      lat: nextLat.clamp(-85.0, 85.0).toDouble(),
      lng: nextLng.clamp(-180.0, 180.0).toDouble(),
      accuracy: 1.0,
      timestamp: DateTime.now(),
      isConfident: true,
    );
  }

  LocationState _currentLocationOrDebugDefault() {
    final currentLocation = switch (state) {
      LocationProviderActive(location: final location) => location,
      _ => null,
    };
    if (currentLocation != null &&
        (currentLocation.lat != 0.0 || currentLocation.lng != 0.0)) {
      return currentLocation;
    }

    return LocationState(
      lat: _kDebugLocationDefaultLat,
      lng: _kDebugLocationDefaultLng,
      accuracy: 1.0,
      timestamp: DateTime.now(),
      isConfident: true,
    );
  }
}
