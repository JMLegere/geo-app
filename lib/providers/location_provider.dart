import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geobase/geobase.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum LocationPermissionStatus { unknown, granted, denied, deniedForever }

class LocationState {
  final Geographic? position;
  final double accuracy;
  final LocationPermissionStatus permission;
  final bool isTracking;
  final String? errorMessage;

  const LocationState({
    this.position,
    this.accuracy = 0.0,
    this.permission = LocationPermissionStatus.unknown,
    this.isTracking = false,
    this.errorMessage,
  });

  LocationState copyWith({
    Geographic? position,
    double? accuracy,
    LocationPermissionStatus? permission,
    bool? isTracking,
    String? errorMessage,
    bool clearError = false,
  }) =>
      LocationState(
        position: position ?? this.position,
        accuracy: accuracy ?? this.accuracy,
        permission: permission ?? this.permission,
        isTracking: isTracking ?? this.isTracking,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );
}

// ---------------------------------------------------------------------------
// GPS stream provider (for engine wiring)
// ---------------------------------------------------------------------------

/// Raw GPS stream exposed for [engineProvider] to subscribe the engine.
///
/// [LocationNotifier] adds to this controller when it receives GPS updates.
final _gpsStreamController =
    StreamController<({Geographic position, double accuracy})>.broadcast();

/// Exposes the GPS stream for [engine_provider.dart] to pass to GameEngine.
final gpsStreamProvider =
    Provider<Stream<({Geographic position, double accuracy})>>(
  (ref) => _gpsStreamController.stream,
);

// ---------------------------------------------------------------------------
// Provider + Notifier
// ---------------------------------------------------------------------------

final locationProvider =
    NotifierProvider<LocationNotifier, LocationState>(LocationNotifier.new);

class LocationNotifier extends Notifier<LocationState> {
  @override
  LocationState build() => const LocationState();

  /// Called by the location service (or simulation) on every GPS fix.
  void updateLocation(Geographic position, double accuracy) {
    state = state.copyWith(
        position: position, accuracy: accuracy, clearError: true);
    // Broadcast to GPS stream for engine subscription.
    if (!_gpsStreamController.isClosed) {
      _gpsStreamController.add((position: position, accuracy: accuracy));
    }
  }

  void setPermission(LocationPermissionStatus status) =>
      state = state.copyWith(permission: status);

  void setTracking(bool active) => state = state.copyWith(isTracking: active);

  void setError(String message) =>
      state = state.copyWith(errorMessage: message);

  void clearError() => state = state.copyWith(clearError: true);
}
