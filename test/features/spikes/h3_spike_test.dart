import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/features/spikes/h3_spike.dart';

double _haversineMeters(
    double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  final phi1 = lat1 * math.pi / 180;
  final phi2 = lat2 * math.pi / 180;
  final dphi = (lat2 - lat1) * math.pi / 180;
  final dlambda = (lon2 - lon1) * math.pi / 180;
  final a = math.pow(math.sin(dphi / 2), 2) +
      math.cos(phi1) * math.cos(phi2) * math.pow(math.sin(dlambda / 2), 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return r * c;
}

void main() {
  const sfLat = 37.7749;
  const sfLon = -122.4194;

  late H3CellService service;

  setUpAll(() {
    service = H3CellService(resolution: 9);
  });

  group('H3CellService', () {
    test('cell generation is deterministic', () {
      final id1 = service.getCellId(sfLat, sfLon);
      final id2 = service.getCellId(sfLat, sfLon);
      expect(id1, equals(id2));
    });

    test('cell ID is non-empty hex string', () {
      final id = service.getCellId(sfLat, sfLon);
      expect(id, isNotEmpty);
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(id), isTrue);
    });

    test('resolution of returned cell matches requested resolution', () {
      final id = service.getCellId(sfLat, sfLon);
      expect(service.getResolution(id), equals(9));
    });

    test('k=1 gridDisk returns exactly 7 cells (center + 6 neighbors)', () {
      final id = service.getCellId(sfLat, sfLon);
      final ring = service.getNeighbors(id, k: 1);
      expect(ring.length, equals(7));
    });

    test('returned cell ID is included in its own k=1 ring', () {
      final id = service.getCellId(sfLat, sfLon);
      final ring = service.getNeighbors(id, k: 1);
      expect(ring, contains(id));
    });

    test('point-in-cell round-trip: center is near original point', () {
      final id = service.getCellId(sfLat, sfLon);
      final (centerLat, centerLon) = service.getCellCenter(id);
      // Resolution 9 cells have ~174m edge; center should be within ~200m
      expect((centerLat - sfLat).abs(), lessThan(0.003));
      expect((centerLon - sfLon).abs(), lessThan(0.003));
    });

    test('cell boundary returns 6 vertices (hexagon)', () {
      final id = service.getCellId(sfLat, sfLon);
      final boundary = service.getCellBoundary(id);
      // Standard H3 hexagons have 6 vertices; pentagons have 5
      expect(boundary.length, inInclusiveRange(5, 6));
    });

    test('neighbor centers are ~300-350m from origin center (resolution 9)', () {
      final originId = service.getCellId(sfLat, sfLon);
      final ring = service.getNeighbors(originId, k: 1);
      final neighborIds = ring.where((id) => id != originId).toList();

      final (originCenterLat, originCenterLon) = service.getCellCenter(originId);

      for (final neighborId in neighborIds) {
        final (nLat, nLon) = service.getCellCenter(neighborId);
        final dist = _haversineMeters(
            originCenterLat, originCenterLon, nLat, nLon);
        // H3 res 9: edge ~174m → center-to-center distance ~300-350m
        expect(dist, greaterThan(250));
        expect(dist, lessThan(450));
      }
    });

    test('different lat/lon points produce different cell IDs', () {
      final id1 = service.getCellId(sfLat, sfLon);
      final id2 = service.getCellId(sfLat + 0.01, sfLon + 0.01);
      expect(id1, isNot(equals(id2)));
    });

    group('benchmarks', () {
      test('generate 500 cells around a point and measure time', () {
        final sw = Stopwatch()..start();
        final cells = service.getCellsInRadius(sfLat, sfLon, 6);
        sw.stop();

        // k-ring size = 3k²+3k+1; k=13 → 547 cells
        final sw2 = Stopwatch()..start();
        final bigRing = service.getCellsInRadius(sfLat, sfLon, 13);
        sw2.stop();

        // ignore: avoid_print
        print('H3 k=6 ring (${cells.length} cells): ${sw.elapsedMicroseconds}µs');
        // ignore: avoid_print
        print(
            'H3 k=13 ring (${bigRing.length} cells): ${sw2.elapsedMicroseconds}µs');

        expect(bigRing.length, greaterThanOrEqualTo(500));
        expect(sw2.elapsedMilliseconds, lessThan(2000));
      });

      test('1000 point-in-cell lookups measure time', () {
        final sw = Stopwatch()..start();
        for (int i = 0; i < 1000; i++) {
          service.getCellId(sfLat + i * 0.0001, sfLon + i * 0.0001);
        }
        sw.stop();

        // ignore: avoid_print
        print('H3 1000 getCellId lookups: ${sw.elapsedMilliseconds}ms');
        expect(sw.elapsedMilliseconds, lessThan(5000));
      });

      test('find all neighbors for 100 cells and measure time', () {
        final originId = service.getCellId(sfLat, sfLon);
        final cells = service.getNeighbors(originId, k: 5).take(100).toList();

        final sw = Stopwatch()..start();
        for (final cellId in cells) {
          service.getNeighbors(cellId, k: 1);
        }
        sw.stop();

        // ignore: avoid_print
        print(
            'H3 getNeighbors k=1 for ${cells.length} cells: ${sw.elapsedMilliseconds}ms');
        expect(sw.elapsedMilliseconds, lessThan(5000));
      });
    });
  });
}


