import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/location/services/location_simulator.dart';
import 'package:geobase/geobase.dart';

double _haversineMeters(Geographic a, Geographic b) {
  const R = 6371000.0;
  final dLat = (b.lat - a.lat) * pi / 180;
  final dLon = (b.lon - a.lon) * pi / 180;
  final sinDLat = sin(dLat / 2);
  final sinDLon = sin(dLon / 2);
  final a2 =
      sinDLat * sinDLat +
      cos(a.lat * pi / 180) * cos(b.lat * pi / 180) * sinDLon * sinDLon;
  return R * 2 * atan2(sqrt(a2), sqrt(1 - a2));
}

void main() {
  group('LocationSimulator', () {
    test('produces location updates at configured interval', () async {
      final sim = LocationSimulator(
        updateInterval: const Duration(milliseconds: 50),
        seed: 1,
      );
      sim.start();

      final locations = await sim.locationStream
          .take(3)
          .toList()
          .timeout(const Duration(seconds: 2));

      sim.stop();

      expect(locations.length, 3);
      for (final loc in locations) {
        expect(loc.accuracy, 5.0);
        expect(loc.timestamp, isA<DateTime>());
      }
    });

    test('same seed produces same path', () async {
      final sim1 = LocationSimulator(
        updateInterval: const Duration(milliseconds: 30),
        seed: 99,
      );
      final sim2 = LocationSimulator(
        updateInterval: const Duration(milliseconds: 30),
        seed: 99,
      );

      sim1.start();
      final path1 = await sim1.locationStream.take(5).toList().timeout(const Duration(seconds: 2));
      sim1.stop();

      sim2.start();
      final path2 = await sim2.locationStream.take(5).toList().timeout(const Duration(seconds: 2));
      sim2.stop();

      expect(path1.length, path2.length);
      for (var i = 0; i < path1.length; i++) {
        expect(path1[i].position.lat, closeTo(path2[i].position.lat, 1e-10));
        expect(path1[i].position.lon, closeTo(path2[i].position.lon, 1e-10));
      }
    });

    test('walk speed matches configured speed within tolerance', () async {
      const speed = 2.0;
      const interval = Duration(milliseconds: 100);
      final sim = LocationSimulator(
        walkSpeedMps: speed,
        updateInterval: interval,
        seed: 7,
      );

      sim.start();
      final locs = await sim.locationStream
          .take(4)
          .toList()
          .timeout(const Duration(seconds: 2));
      sim.stop();

      final expectedDistance = speed * (interval.inMilliseconds / 1000.0);

      for (var i = 0; i < locs.length - 1; i++) {
        final dist = _haversineMeters(locs[i].position, locs[i + 1].position);
        expect(dist, closeTo(expectedDistance, expectedDistance * 0.01));
      }
    });

    test('teleportTo immediately changes position', () async {
      final sim = LocationSimulator(
        updateInterval: const Duration(milliseconds: 50),
        seed: 3,
      );
      sim.start();

      await sim.locationStream.first.timeout(const Duration(seconds: 1));

      const tokyo = Geographic(lat: 35.6762, lon: 139.6503);
      sim.teleportTo(tokyo);

      final next = await sim.locationStream.first.timeout(const Duration(seconds: 1));
      sim.stop();

      expect(next.position.lat, closeTo(35.6762, 0.01));
      expect(next.position.lon, closeTo(139.6503, 0.01));
    });

    test('stop() stops the stream', () async {
      final sim = LocationSimulator(
        updateInterval: const Duration(milliseconds: 50),
        seed: 5,
      );

      sim.start();
      await sim.locationStream.first.timeout(const Duration(seconds: 1));
      sim.stop();

      final count = await sim.locationStream
          .take(3)
          .timeout(const Duration(milliseconds: 300), onTimeout: (sink) => sink.close())
          .length;

      expect(count, 0);
    });
  });
}
