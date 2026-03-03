import 'dart:async';
import 'dart:math';

import 'package:geobase/geobase.dart';

class SimulatedLocation {
  final Geographic position;
  final double accuracy;
  final DateTime timestamp;

  SimulatedLocation({
    required this.position,
    this.accuracy = 5.0,
    required this.timestamp,
  });
}

class LocationSimulator {
  final Geographic startPosition;
  final double walkSpeedMps;
  final Duration updateInterval;
  final int seed;

  LocationSimulator({
    Geographic? startPosition,
    this.walkSpeedMps = 1.4,
    this.updateInterval = const Duration(seconds: 1),
    this.seed = 42,
  }) : startPosition =
           startPosition ?? const Geographic(lat: 37.7749, lon: -122.4194);

  final StreamController<SimulatedLocation> _controller =
      StreamController<SimulatedLocation>.broadcast();
  Timer? _timer;
  Geographic? _currentPosition;
  double _heading = 0.0;
  late Random _random;

  Stream<SimulatedLocation> get locationStream => _controller.stream;

  void start() {
    _random = Random(seed);
    _currentPosition = startPosition;
    _heading = _random.nextDouble() * 2 * pi;

    _timer?.cancel();
    _timer = Timer.periodic(updateInterval, (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }

  void teleportTo(Geographic position) {
    _currentPosition = position;
  }

  void _tick() {
    final current = _currentPosition;
    if (current == null) return;

    final headingDrift = (_random.nextDouble() - 0.5) * 2 * (15 * pi / 180);
    _heading = (_heading + headingDrift) % (2 * pi);

    final distanceMeters = walkSpeedMps * (updateInterval.inMilliseconds / 1000.0);
    final next = _moveBy(current, _heading, distanceMeters);
    _currentPosition = next;

    _controller.add(
      SimulatedLocation(position: next, timestamp: DateTime.now()),
    );
  }

  Geographic _moveBy(Geographic from, double headingRad, double distanceM) {
    const earthRadius = 6371000.0;
    final latRad = from.lat * pi / 180;
    final lonRad = from.lon * pi / 180;
    final angular = distanceM / earthRadius;

    final newLatRad = asin(
      sin(latRad) * cos(angular) + cos(latRad) * sin(angular) * cos(headingRad),
    );
    final newLonRad =
        lonRad +
        atan2(
          sin(headingRad) * sin(angular) * cos(latRad),
          cos(angular) - sin(latRad) * sin(newLatRad),
        );

    return Geographic(lat: newLatRad * 180 / pi, lon: newLonRad * 180 / pi);
  }
}
