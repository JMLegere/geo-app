import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geobase/geobase.dart';

import '../../features/location/services/location_service.dart';

class LocationState {
  final Geographic? currentPosition;
  final double? accuracy;
  final bool isTracking;

  LocationState({
    this.currentPosition,
    this.accuracy,
    this.isTracking = false,
  });

  LocationState copyWith({
    Geographic? currentPosition,
    double? accuracy,
    bool? isTracking,
  }) {
    return LocationState(
      currentPosition: currentPosition ?? this.currentPosition,
      accuracy: accuracy ?? this.accuracy,
      isTracking: isTracking ?? this.isTracking,
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

  void connectToService(LocationService service) {
    _serviceSubscription?.cancel();
    _serviceSubscription = service.filteredLocationStream.listen((loc) {
      updateLocation(loc.position, loc.accuracy);
    });
  }
}

final locationProvider =
    NotifierProvider<LocationNotifier, LocationState>(() => LocationNotifier());
