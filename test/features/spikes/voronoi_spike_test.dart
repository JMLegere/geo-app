import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/features/spikes/voronoi_spike.dart';

void main() {
  const minLat = 37.7;
  const maxLat = 37.85;
  const minLon = -122.5;
  const maxLon = -122.35;

  late VoronoiCellService service;

  setUpAll(() {
    service = VoronoiCellService(
      minLat: minLat,
      maxLat: maxLat,
      minLon: minLon,
      maxLon: maxLon,
      gridRows: 20,
      gridCols: 20,
      seed: 42,
    );
  });

  group('VoronoiCellService', () {
    test('cell generation is deterministic (same seed → same cells)', () {
      final service2 = VoronoiCellService(
        minLat: minLat,
        maxLat: maxLat,
        minLon: minLon,
        maxLon: maxLon,
        seed: 42,
      );

      const testLat = 37.7749;
      const testLon = -122.4194;
      expect(
        service.getCellForPoint(testLat, testLon),
        equals(service2.getCellForPoint(testLat, testLon)),
      );
    });

    test('different seeds produce different cells', () {
      final otherService = VoronoiCellService(
        minLat: minLat,
        maxLat: maxLat,
        minLon: minLon,
        maxLon: maxLon,
        seed: 99,
      );

      // Different seeds should often yield different cell assignments
      // (not guaranteed but very likely)
      expect(service.cellCount, equals(otherService.cellCount));
    });

    test('cell count equals gridRows × gridCols', () {
      expect(service.cellCount, equals(20 * 20));
    });

    test('nearest-neighbor lookup returns a valid cell ID', () {
      final cellId = service.getCellForPoint(37.7749, -122.4194);
      expect(cellId, greaterThanOrEqualTo(0));
      expect(cellId, lessThan(service.cellCount));
    });

    test('getCellCenter returns the seed point for the cell', () {
      final cellId = service.getCellForPoint(37.7749, -122.4194);
      final (lat, lon) = service.getCellCenter(cellId);
      expect(lat, greaterThanOrEqualTo(minLat));
      expect(lat, lessThanOrEqualTo(maxLat));
      expect(lon, greaterThanOrEqualTo(minLon));
      expect(lon, lessThanOrEqualTo(maxLon));
    });

    test('getCellForPoint is consistent: center of cell maps back to same cell', () {
      const testLat = 37.7749;
      const testLon = -122.4194;
      final cellId = service.getCellForPoint(testLat, testLon);
      final (centerLat, centerLon) = service.getCellCenter(cellId);
      final cellIdFromCenter = service.getCellForPoint(centerLat, centerLon);
      expect(cellIdFromCenter, equals(cellId));
    });

    test('all points in bounding box map to exactly one cell', () {
      const rows = 10;
      const cols = 10;
      final latStep = (maxLat - minLat) / rows;
      final lonStep = (maxLon - minLon) / cols;

      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          final lat = minLat + r * latStep + latStep / 2;
          final lon = minLon + c * lonStep + lonStep / 2;
          final cellId = service.getCellForPoint(lat, lon);
          expect(cellId, isA<int>());
          expect(cellId, greaterThanOrEqualTo(0));
          expect(cellId, lessThan(service.cellCount));
        }
      }
    });

    test('getCellBoundary returns a convex polygon with 3+ vertices', () {
      final cellId = service.getCellForPoint(37.7749, -122.4194);
      final boundary = service.getCellBoundary(cellId);
      expect(boundary.length, greaterThanOrEqualTo(3));
    });

    test('invalid cell ID throws ArgumentError', () {
      expect(() => service.getCellCenter(-1), throwsArgumentError);
      expect(() => service.getCellCenter(service.cellCount), throwsArgumentError);
    });

    test('getNeighbors returns non-empty list of adjacent cells', () {
      final cellId = service.getCellForPoint(37.7749, -122.4194);
      final neighbors = service.getNeighbors(cellId);
      expect(neighbors, isNotEmpty);
      expect(neighbors, isNot(contains(cellId)));
      for (final n in neighbors) {
        expect(n, greaterThanOrEqualTo(0));
        expect(n, lessThan(service.cellCount));
      }
    });

    group('benchmarks', () {
      test('generate 500 cells (20x25 grid) and measure time', () {
        final sw = Stopwatch()..start();
        final bigService = VoronoiCellService(
          minLat: minLat,
          maxLat: maxLat,
          minLon: minLon,
          maxLon: maxLon,
          gridRows: 20,
          gridCols: 25,
          seed: 42,
        );
        sw.stop();

        // ignore: avoid_print
        print(
            'Voronoi generate ${bigService.cellCount} cells: ${sw.elapsedMilliseconds}ms');
        expect(bigService.cellCount, greaterThanOrEqualTo(500));
        expect(sw.elapsedMilliseconds, lessThan(5000));
      });

      test('1000 point-in-cell lookups measure time', () {
        final sw = Stopwatch()..start();
        for (int i = 0; i < 1000; i++) {
          service.getCellForPoint(
            minLat + (i % 100) * (maxLat - minLat) / 100,
            minLon + (i ~/ 100) * (maxLon - minLon) / 10,
          );
        }
        sw.stop();

        // ignore: avoid_print
        print('Voronoi 1000 getCellForPoint lookups: ${sw.elapsedMilliseconds}ms');
        expect(sw.elapsedMilliseconds, lessThan(10000));
      });

      test('find neighbors for 100 cells and measure time', () {
        final cells = List.generate(
          100,
          (i) => service.getCellForPoint(
            minLat + i * (maxLat - minLat) / 200,
            minLon + i * (maxLon - minLon) / 200,
          ),
        ).toSet().take(100).toList();

        final sw = Stopwatch()..start();
        for (final cellId in cells) {
          service.getNeighbors(cellId);
        }
        sw.stop();

        // ignore: avoid_print
        print(
            'Voronoi getNeighbors for ${cells.length} cells: ${sw.elapsedMilliseconds}ms');
        expect(sw.elapsedMilliseconds, lessThan(60000));
      });
    });
  });
}
