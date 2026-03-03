import 'dart:async';

import 'package:flutter/foundation.dart';

import 'gps_filter.dart';
import 'keyboard_location_service.dart';
import 'location_simulator.dart';

enum LocationMode { simulation, realGps, keyboard }

class LocationService {
  final LocationMode mode;
  final LocationSimulator? simulator;
  final KeyboardLocationService? keyboardService;
  final GpsFilter filter;

  LocationService({
    LocationMode? mode,
    LocationSimulator? simulator,
    KeyboardLocationService? keyboardService,
    GpsFilter? filter,
  }) : mode = mode ?? (kIsWeb ? LocationMode.keyboard : LocationMode.simulation),
       simulator = simulator ?? (_resolvedMode(mode) == LocationMode.simulation ? LocationSimulator() : null),
       keyboardService = keyboardService ?? (_resolvedMode(mode) == LocationMode.keyboard ? KeyboardLocationService() : null),
       filter = filter ?? GpsFilter();

  static LocationMode _resolvedMode(LocationMode? mode) =>
      mode ?? (kIsWeb ? LocationMode.keyboard : LocationMode.simulation);

  StreamSubscription<SimulatedLocation>? _subscription;
  late final StreamController<SimulatedLocation> _outputController =
      StreamController<SimulatedLocation>.broadcast(
        onCancel: () {},
      );

  bool _isTracking = false;

  Stream<SimulatedLocation> get filteredLocationStream => _outputController.stream;

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
        // TODO: Task 10 - integrate real GPS plugin
        break;
    }
  }

  void stop() {
    if (!_isTracking) return;
    _isTracking = false;

    _subscription?.cancel();
    _subscription = null;

    if (mode == LocationMode.simulation) {
      simulator?.stop();
    } else if (mode == LocationMode.keyboard) {
      keyboardService?.stop();
    }
  }
}
