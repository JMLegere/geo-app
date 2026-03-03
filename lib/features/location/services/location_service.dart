import 'dart:async';

import 'gps_filter.dart';
import 'location_simulator.dart';

enum LocationMode { simulation, realGps }

class LocationService {
  final LocationMode mode;
  final LocationSimulator? simulator;
  final GpsFilter filter;

  LocationService({
    this.mode = LocationMode.simulation,
    LocationSimulator? simulator,
    GpsFilter? filter,
  }) : simulator = simulator ?? (mode == LocationMode.simulation ? LocationSimulator() : null),
       filter = filter ?? GpsFilter();

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
    }
  }
}
