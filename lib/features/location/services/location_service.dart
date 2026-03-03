import 'dart:async';

import 'package:flutter/foundation.dart';

import 'gps_filter.dart';
import 'keyboard_location_service.dart';
import 'location_simulator.dart';
import 'real_gps_service.dart';

enum LocationMode { simulation, realGps, keyboard }

class LocationService {
  final LocationMode mode;
  final LocationSimulator? simulator;
  final KeyboardLocationService? keyboardService;
  final RealGpsService? gpsService;
  final GpsFilter filter;

  LocationService({
    LocationMode? mode,
    LocationSimulator? simulator,
    KeyboardLocationService? keyboardService,
    RealGpsService? gpsService,
    GpsFilter? filter,
  })  : mode = mode ?? _defaultMode(),
        simulator = simulator ??
            (_resolvedMode(mode) == LocationMode.simulation
                ? LocationSimulator()
                : null),
        keyboardService = keyboardService ??
            (_resolvedMode(mode) == LocationMode.keyboard
                ? KeyboardLocationService()
                : null),
        gpsService = gpsService ??
            (_resolvedMode(mode) == LocationMode.realGps
                ? RealGpsService()
                : null),
        filter = filter ?? GpsFilter();

  static LocationMode _defaultMode() =>
      kIsWeb ? LocationMode.keyboard : LocationMode.realGps;

  static LocationMode _resolvedMode(LocationMode? mode) =>
      mode ?? _defaultMode();

  StreamSubscription<SimulatedLocation>? _subscription;
  late final StreamController<SimulatedLocation> _outputController =
      StreamController<SimulatedLocation>.broadcast(
    onCancel: () {},
  );

  bool _isTracking = false;

  Stream<SimulatedLocation> get filteredLocationStream =>
      _outputController.stream;

  bool get isTracking => _isTracking;

  void dispose() {
    stop();
    _outputController.close();
  }

  void start() {
    if (_isTracking) return;
    _isTracking = true;

    switch (mode) {
      case LocationMode.simulation:
        final sim = simulator;
        if (sim != null) {
          sim.start();
          _subscription = sim.locationStream
              .map((loc) => filter.filter(loc))
              .where((loc) => loc != null)
              .cast<SimulatedLocation>()
              .listen(_outputController.add);
        }
      case LocationMode.keyboard:
        final kb = keyboardService;
        if (kb != null) {
          kb.start();
          _subscription = kb.locationStream
              .map((loc) => filter.filter(loc))
              .where((loc) => loc != null)
              .cast<SimulatedLocation>()
              .listen(_outputController.add);
        }
      case LocationMode.realGps:
        final gps = gpsService;
        if (gps != null) {
          _subscription = gps.locationStream
              .map((loc) => filter.filter(loc))
              .where((loc) => loc != null)
              .cast<SimulatedLocation>()
              .listen(_outputController.add);
          // Fire-and-forget: GPS starts emitting after permission is granted.
          gps.start();
        }
    }
  }

  void stop() {
    if (!_isTracking) return;
    _isTracking = false;

    _subscription?.cancel();
    _subscription = null;

    switch (mode) {
      case LocationMode.simulation:
        simulator?.stop();
      case LocationMode.keyboard:
        keyboardService?.stop();
      case LocationMode.realGps:
        gpsService?.stop();
    }
  }

  /// Checks GPS permission status without starting the service.
  ///
  /// Returns null for non-GPS modes (simulation, keyboard).
  /// Returns a [GpsPermissionStatus] for real GPS mode.
  Future<GpsPermissionStatus?> checkPermission() async {
    if (mode != LocationMode.realGps) return null;
    return gpsService?.ensurePermission();
  }
}
