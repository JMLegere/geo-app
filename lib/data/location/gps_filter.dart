import 'dart:math';

import 'package:geobase/geobase.dart';

import 'location_simulator.dart';

double _haversineMeters(Geographic a, Geographic b) {
  const R = 6371000.0;
  final dLat = (b.lat - a.lat) * pi / 180;
  final dLon = (b.lon - a.lon) * pi / 180;
  final sinDLat = sin(dLat / 2);
  final sinDLon = sin(dLon / 2);
  final a2 = sinDLat * sinDLat +
      cos(a.lat * pi / 180) * cos(b.lat * pi / 180) * sinDLon * sinDLon;
  return R * 2 * atan2(sqrt(a2), sqrt(1 - a2));
}

class GpsFilter {
  final double accuracyThreshold;
  final double minDistanceMeters;

  GpsFilter({
    this.accuracyThreshold = 50.0,
    this.minDistanceMeters = 2.0,
  });

  Geographic? _lastAccepted;

  SimulatedLocation? filter(SimulatedLocation raw) {
    if (raw.accuracy > accuracyThreshold) return null;

    final last = _lastAccepted;
    if (last != null &&
        _haversineMeters(last, raw.position) < minDistanceMeters) {
      return null;
    }

    _lastAccepted = raw.position;
    return raw;
  }
}
