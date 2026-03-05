import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geobase/geobase.dart';

/// Describes any location-related error state the user should be informed of.
enum LocationError {
  /// No error — location is working normally.
  none,

  /// User denied location permission (can request again).
  permissionDenied,

  /// User denied location permission permanently (must open Settings).
  permissionDeniedForever,

  /// Device location services are switched off.
  serviceDisabled,

  /// GPS accuracy exceeds the acceptable threshold.
  lowAccuracy,
}

class LocationState {
  final Geographic? currentPosition;
  final double? accuracy;
  final bool isTracking;

  /// Current location error state, if any.
  final LocationError locationError;

  LocationState({
    this.currentPosition,
    this.accuracy,
    this.isTracking = false,
    this.locationError = LocationError.none,
  });

  LocationState copyWith({
    Geographic? currentPosition,
    double? accuracy,
    bool? isTracking,
    LocationError? locationError,
  }) {
    return LocationState(
      currentPosition: currentPosition ?? this.currentPosition,
      accuracy: accuracy ?? this.accuracy,
      isTracking: isTracking ?? this.isTracking,
      locationError: locationError ?? this.locationError,
    );
  }
}

class LocationNotifier extends Notifier<LocationState> {
  StreamSubscription<dynamic>? _serviceSubscription;

  @override
  LocationState build() {
    ref.onDispose(() {
      _serviceSubscription?.cancel();
    });
    return LocationState();
  }

  void updateLocation(Geographic position, double accuracy) {
    state = state.copyWith(
      currentPosition: position,
      accuracy: accuracy,
    );
  }

  void startTracking() {
    state = state.copyWith(isTracking: true);
  }

  void stopTracking() {
    state = state.copyWith(isTracking: false);
    _serviceSubscription?.cancel();
    _serviceSubscription = null;
  }

  /// Sets the current location error. Use [LocationError.none] to clear.
  void setError(LocationError error) {
    state = state.copyWith(locationError: error);
  }

  /// Subscribes to a location stream emitting `({Geographic position, double accuracy})`.
  ///
  /// This accepts a stream instead of a concrete service to keep core/
  /// free of feature-layer dependencies.
  void connectToStream(Stream<({Geographic position, double accuracy})> stream) {
    _serviceSubscription?.cancel();
    _serviceSubscription = stream.listen((loc) {
      updateLocation(loc.position, loc.accuracy);
    });
  }
}

final locationProvider =
    NotifierProvider<LocationNotifier, LocationState>(() => LocationNotifier());
