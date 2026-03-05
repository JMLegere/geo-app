import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/features/location/services/gps_filter.dart';
import 'package:fog_of_world/features/location/services/location_simulator.dart';
import 'package:geobase/geobase.dart';

SimulatedLocation _loc(double lat, double lon, {double accuracy = 5.0}) {
  return SimulatedLocation(
    position: Geographic(lat: lat, lon: lon),
    accuracy: accuracy,
    timestamp: DateTime.now(),
  );
}

void main() {
  group('GpsFilter', () {
    test('rejects readings with accuracy > 50m', () {
      final filter = GpsFilter();
      final result = filter.filter(_loc(37.7749, -122.4194, accuracy: 51.0));
      expect(result, isNull);
    });

    test('accepts readings with accuracy == 50m', () {
      final filter = GpsFilter();
      final result = filter.filter(_loc(37.7749, -122.4194, accuracy: 50.0));
      expect(result, isNotNull);
    });

    test('accepts readings with accuracy < 50m', () {
      final filter = GpsFilter();
      final result = filter.filter(_loc(37.7749, -122.4194, accuracy: 10.0));
      expect(result, isNotNull);
    });

    test('rejects readings within 2m of last accepted position', () {
      final filter = GpsFilter();

      filter.filter(_loc(37.7749, -122.4194));

      // ~1m north — well within 2m threshold
      final tinyMove = _loc(37.77490899, -122.4194);
      final result = filter.filter(tinyMove);
      expect(result, isNull);
    });

    test('accepts readings more than 2m from last accepted position', () {
      final filter = GpsFilter();

      filter.filter(_loc(37.7749, -122.4194));

      // ~100m north
      final bigMove = _loc(37.7758, -122.4194);
      final result = filter.filter(bigMove);
      expect(result, isNotNull);
    });

    test('first reading is always accepted when accuracy is good', () {
      final filter = GpsFilter();
      final result = filter.filter(_loc(0.0, 0.0));
      expect(result, isNotNull);
    });

    test('returns the location unchanged when accepted', () {
      final filter = GpsFilter();
      final input = _loc(37.7749, -122.4194, accuracy: 10.0);
      final output = filter.filter(input);
      expect(output, same(input));
    });

    test('respects custom accuracy threshold', () {
      final filter = GpsFilter(accuracyThreshold: 20.0);

      expect(filter.filter(_loc(37.7749, -122.4194, accuracy: 19.0)), isNotNull);
      expect(filter.filter(_loc(37.776, -122.419, accuracy: 21.0)), isNull);
    });

    test('respects custom minDistance threshold', () {
      final filter = GpsFilter(minDistanceMeters: 10.0);

      filter.filter(_loc(37.7749, -122.4194));

      // ~5m north — under 10m threshold
      final smallMove = _loc(37.77494, -122.4194);
      expect(filter.filter(smallMove), isNull);

      // ~100m north — over 10m threshold
      final bigMove = _loc(37.7758, -122.4194);
      expect(filter.filter(bigMove), isNotNull);
    });
  });
}
