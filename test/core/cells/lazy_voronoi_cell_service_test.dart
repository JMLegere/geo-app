import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/cells/cell_service.dart';
import 'package:earth_nova/core/cells/lazy_voronoi_cell_service.dart';

/// Tests the [CellService] contract via the [LazyVoronoiCellService]
/// implementation.
///
/// All tests are pure-Dart and do NOT require LD_LIBRARY_PATH (no native libs).
void main() {
  late CellService service;

  // San Francisco (Dolores Park area) — same anchor as other cell tests.
  const double lat = 37.7599;
  const double lon = -122.4268;

  setUp(() {
    service = LazyVoronoiCellService(
      gridStep: 0.0125,
      jitterFactor: 0.6,
      globalSeed: 42,
      neighborRadius: 3,
    );
  });

  group('LazyVoronoiCellService — CellService contract', () {
    // -------------------------------------------------------------------------
    // 1. getCellId determinism
    // -------------------------------------------------------------------------
    test('getCellId is deterministic (same lat/lon → same ID, 100 iterations)',
        () {
      final firstId = service.getCellId(lat, lon);
      for (int i = 0; i < 100; i++) {
        expect(
          service.getCellId(lat, lon),
          equals(firstId),
          reason: 'Iteration $i returned a different cell ID',
        );
      }
    });

    // -------------------------------------------------------------------------
    // 2. getCellId: nearby points in same cell return same ID
    // -------------------------------------------------------------------------
    test('getCellId returns same ID for nearby points within same cell', () {
      final id1 = service.getCellId(lat, lon);
      // Offset by ~10m — well within a single cell.
      final id2 = service.getCellId(lat + 0.0001, lon + 0.0001);
      expect(id1, equals(id2));
    });

    // -------------------------------------------------------------------------
    // 3. getCellId: distant points return different IDs
    // -------------------------------------------------------------------------
    test('getCellId returns different IDs for points in different grid cells',
        () {
      final id1 = service.getCellId(lat, lon);
      // Offset by ~2 grid steps — guaranteed different cell.
      final id2 = service.getCellId(lat + 0.03, lon + 0.03);
      expect(id1, isNot(equals(id2)));
    });

    // -------------------------------------------------------------------------
    // 4. getCellId: cell ID format is "v_{row}_{col}"
    // -------------------------------------------------------------------------
    test('getCellId returns IDs in "v_{row}_{col}" format', () {
      final id = service.getCellId(lat, lon);
      expect(id, matches(RegExp(r'^v_-?\d+_-?\d+$')));
    });

    // -------------------------------------------------------------------------
    // 5. getCellCenter: returns a point within the grid cell
    // -------------------------------------------------------------------------
    test('getCellCenter returns a point near the grid cell center', () {
      final cellId = service.getCellId(lat, lon);
      final center = service.getCellCenter(cellId);

      // Center should be within ~1 grid step of the query point.
      final dist = _haversineMeters(lat, lon, center.lat, center.lon);
      expect(dist, lessThan(2000),
          reason: 'Cell center should be within 2 km of query point');
    });

    // -------------------------------------------------------------------------
    // 6. getCellCenter round-trip
    // -------------------------------------------------------------------------
    test('getCellCenter round-trip: center → getCellId → same cell', () {
      final cellId = service.getCellId(lat, lon);
      final center = service.getCellCenter(cellId);
      final roundTripId = service.getCellId(center.lat, center.lon);
      expect(roundTripId, equals(cellId));
    });

    // -------------------------------------------------------------------------
    // 7. getCellBoundary: returns ≥3 vertices
    // -------------------------------------------------------------------------
    test('getCellBoundary returns ≥3 vertices forming a closed polygon', () {
      final cellId = service.getCellId(lat, lon);
      final boundary = service.getCellBoundary(cellId);
      expect(
        boundary.length,
        greaterThanOrEqualTo(3),
        reason: 'Voronoi cell boundary must have at least 3 vertices',
      );
    });

    // -------------------------------------------------------------------------
    // 8. getCellBoundary: polygon contains the cell center
    // -------------------------------------------------------------------------
    test('getCellBoundary polygon contains the cell center', () {
      final cellId = service.getCellId(lat, lon);
      final center = service.getCellCenter(cellId);
      final boundary = service.getCellBoundary(cellId);

      if (boundary.length >= 3) {
        final inside = _pointInPolygon(
          center.lat,
          center.lon,
          boundary.map((g) => (g.lat, g.lon)).toList(),
        );
        expect(inside, isTrue,
            reason: 'Cell center should be inside its own boundary polygon');
      }
    });

    // -------------------------------------------------------------------------
    // 9. getCellBoundary: vertices are within reasonable distance of center
    // -------------------------------------------------------------------------
    test('getCellBoundary vertices are all within 3 km of cell center', () {
      final cellId = service.getCellId(lat, lon);
      final center = service.getCellCenter(cellId);
      final boundary = service.getCellBoundary(cellId);

      for (final vertex in boundary) {
        final dist =
            _haversineMeters(center.lat, center.lon, vertex.lat, vertex.lon);
        expect(dist, lessThan(3000),
            reason: 'Boundary vertex should be within 3 km of cell center');
      }
    });

    // -------------------------------------------------------------------------
    // 10. getCellBoundary: adjacent cells share boundary edges (gap-free)
    // -------------------------------------------------------------------------
    test('adjacent cells share at least one boundary vertex (gap-free)', () {
      final cellId = service.getCellId(lat, lon);
      final neighbors = service.getNeighborIds(cellId);
      final boundary = service.getCellBoundary(cellId);

      // At least one neighbor should share a vertex with this cell.
      var sharedCount = 0;
      for (final neighborId in neighbors) {
        final neighborBoundary = service.getCellBoundary(neighborId);
        for (final v1 in boundary) {
          for (final v2 in neighborBoundary) {
            if ((v1.lat - v2.lat).abs() < 1e-8 &&
                (v1.lon - v2.lon).abs() < 1e-8) {
              sharedCount++;
            }
          }
        }
      }
      expect(sharedCount, greaterThan(0),
          reason: 'Adjacent cells should share boundary vertices');
    });

    // -------------------------------------------------------------------------
    // 11. getNeighborIds: returns non-empty list
    // -------------------------------------------------------------------------
    test('getNeighborIds returns non-empty list for any cell', () {
      final cellId = service.getCellId(lat, lon);
      final neighbors = service.getNeighborIds(cellId);
      expect(neighbors.length, greaterThanOrEqualTo(1));
      expect(neighbors, isNot(contains(cellId)),
          reason: 'A cell must not be its own neighbor');
    });

    // -------------------------------------------------------------------------
    // 12. getNeighborIds: symmetric relationship
    // -------------------------------------------------------------------------
    test('neighbor relationship is symmetric (if A neighbors B, B neighbors A)',
        () {
      final cellId = service.getCellId(lat, lon);
      final neighbors = service.getNeighborIds(cellId);
      for (final n in neighbors) {
        final reverseNeighbors = service.getNeighborIds(n);
        expect(
          reverseNeighbors,
          contains(cellId),
          reason: 'If $cellId neighbors $n, then $n must neighbor $cellId',
        );
      }
    });

    // -------------------------------------------------------------------------
    // 13. getCellsInRing(k=0): returns [cellId]
    // -------------------------------------------------------------------------
    test('getCellsInRing(k=0) returns exactly [cellId]', () {
      final cellId = service.getCellId(lat, lon);
      final ring = service.getCellsInRing(cellId, 0);
      expect(ring.length, equals(1));
      expect(ring.first, equals(cellId));
    });

    // -------------------------------------------------------------------------
    // 14. getCellsInRing(k=1): returns cell + neighbors
    // -------------------------------------------------------------------------
    test('getCellsInRing(k=1) includes the cell and all immediate neighbors',
        () {
      final cellId = service.getCellId(lat, lon);
      final neighbors = service.getNeighborIds(cellId);
      final ring = service.getCellsInRing(cellId, 1);

      expect(ring, contains(cellId));
      for (final n in neighbors) {
        expect(ring, contains(n),
            reason: 'k=1 ring must contain neighbor $n');
      }
      expect(ring.length, equals(1 + neighbors.length));
    });

    // -------------------------------------------------------------------------
    // 15. getCellsInRing(k=2): includes ring-2 cells not in ring-1
    // -------------------------------------------------------------------------
    test('getCellsInRing(k=2) is strictly larger than k=1', () {
      final cellId = service.getCellId(lat, lon);
      final ring1 = service.getCellsInRing(cellId, 1);
      final ring2 = service.getCellsInRing(cellId, 2);
      expect(
        ring2.length,
        greaterThan(ring1.length),
        reason: 'k=2 must include more cells than k=1',
      );
    });

    // -------------------------------------------------------------------------
    // 16. getCellsAroundLocation matches getCellId + getCellsInRing
    // -------------------------------------------------------------------------
    test('getCellsAroundLocation is equivalent to getCellId + getCellsInRing',
        () {
      const int k = 2;
      final cellId = service.getCellId(lat, lon);
      final viaRing = service.getCellsInRing(cellId, k);
      final viaConvenience = service.getCellsAroundLocation(lat, lon, k);

      expect(viaConvenience.toSet(), equals(viaRing.toSet()));
    });

    // -------------------------------------------------------------------------
    // 17. cellEdgeLengthMeters: reasonable value
    // -------------------------------------------------------------------------
    test('cellEdgeLengthMeters is between 500 m and 2000 m', () {
      expect(service.cellEdgeLengthMeters, greaterThan(500));
      expect(service.cellEdgeLengthMeters, lessThan(2000));
    });

    // -------------------------------------------------------------------------
    // 18. systemName: descriptive string
    // -------------------------------------------------------------------------
    test('systemName contains "Voronoi"', () {
      expect(service.systemName, contains('Voronoi'));
    });

    // -------------------------------------------------------------------------
    // 19. Determinism: two instances with same params produce identical results
    // -------------------------------------------------------------------------
    test('two instances with same params produce identical results', () {
      final service2 = LazyVoronoiCellService(
        gridStep: 0.0125,
        jitterFactor: 0.6,
        globalSeed: 42,
        neighborRadius: 3,
      );

      final id1 = service.getCellId(lat, lon);
      final id2 = service2.getCellId(lat, lon);
      expect(id1, equals(id2));

      final center1 = service.getCellCenter(id1);
      final center2 = service2.getCellCenter(id2);
      expect(center1.lat, equals(center2.lat));
      expect(center1.lon, equals(center2.lon));

      final boundary1 = service.getCellBoundary(id1);
      final boundary2 = service2.getCellBoundary(id2);
      expect(boundary1.length, equals(boundary2.length));
      for (int i = 0; i < boundary1.length; i++) {
        expect(boundary1[i].lat, closeTo(boundary2[i].lat, 1e-10));
        expect(boundary1[i].lon, closeTo(boundary2[i].lon, 1e-10));
      }

      final neighbors1 = service.getNeighborIds(id1);
      final neighbors2 = service2.getNeighborIds(id2);
      expect(neighbors1, equals(neighbors2));
    });

    // -------------------------------------------------------------------------
    // 20. Different globalSeed produces different cell layouts
    // -------------------------------------------------------------------------
    test('different globalSeed produces different cell layouts', () {
      final service2 = LazyVoronoiCellService(
        gridStep: 0.0125,
        jitterFactor: 0.6,
        globalSeed: 99, // different seed
        neighborRadius: 3,
      );

      // Compare cell centers for the same grid cell (not the same query point,
      // which might map to different grid cells with different jitter).
      // Use a fixed cell ID to compare the seed positions directly.
      const fixedId = 'v_3020_-9794';
      final center1 = service.getCellCenter(fixedId);
      final center2 = service2.getCellCenter(fixedId);

      // With different seeds, the jittered centers should differ.
      final sameLat = (center1.lat - center2.lat).abs() < 1e-10;
      final sameLon = (center1.lon - center2.lon).abs() < 1e-10;
      expect(sameLat && sameLon, isFalse,
          reason: 'Different seeds should produce different cell centers');
    });

    // -------------------------------------------------------------------------
    // 21. Works at various global locations (not just SF)
    // -------------------------------------------------------------------------
    test('works at various global locations without errors', () {
      final locations = [
        (0.0, 0.0), // Null Island
        (51.5074, -0.1278), // London
        (-33.8688, 151.2093), // Sydney
        (35.6762, 139.6503), // Tokyo
        (-22.9068, -43.1729), // Rio de Janeiro
        (90.0, 0.0), // North Pole
        (-90.0, 0.0), // South Pole
      ];

      for (final (testLat, testLon) in locations) {
        expect(
          () {
            final id = service.getCellId(testLat, testLon);
            service.getCellCenter(id);
            service.getCellBoundary(id);
            service.getNeighborIds(id);
          },
          returnsNormally,
          reason: 'Should work at ($testLat, $testLon)',
        );
      }
    });

    // -------------------------------------------------------------------------
    // 22. Cell IDs contain negative coordinates for negative lat/lon
    // -------------------------------------------------------------------------
    test('cell IDs handle negative coordinates correctly', () {
      final id = service.getCellId(-33.8688, 151.2093);
      expect(id, matches(RegExp(r'^v_-?\d+_-?\d+$')));

      // Round-trip: parse and reconstruct.
      final center = service.getCellCenter(id);
      final roundTripId = service.getCellId(center.lat, center.lon);
      expect(roundTripId, equals(id));
    });

    // -------------------------------------------------------------------------
    // 23. Neighbor count is reasonable (typically 5-7 for Voronoi)
    // -------------------------------------------------------------------------
    test('neighbor count is between 3 and 10 for interior cells', () {
      final cellId = service.getCellId(lat, lon);
      final neighbors = service.getNeighborIds(cellId);
      expect(neighbors.length, greaterThanOrEqualTo(3));
      expect(neighbors.length, lessThanOrEqualTo(10));
    });

    // -------------------------------------------------------------------------
    // 24. Invalid cell ID throws ArgumentError
    // -------------------------------------------------------------------------
    test('invalid cell ID throws ArgumentError', () {
      expect(() => service.getCellCenter('invalid'), throwsArgumentError);
      expect(() => service.getCellCenter('42'), throwsArgumentError);
      expect(() => service.getCellCenter('v_abc_def'), throwsArgumentError);
    });
  });
}

/// Haversine distance in meters between two lat/lon points.
double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  const double r = 6371000; // Earth radius in metres
  final double phi1 = lat1 * math.pi / 180;
  final double phi2 = lat2 * math.pi / 180;
  final double dPhi = (lat2 - lat1) * math.pi / 180;
  final double dLambda = (lon2 - lon1) * math.pi / 180;

  final double a = math.pow(math.sin(dPhi / 2), 2).toDouble() +
      math.cos(phi1) *
          math.cos(phi2) *
          math.pow(math.sin(dLambda / 2), 2).toDouble();
  final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return r * c;
}

/// Ray-casting point-in-polygon test.
bool _pointInPolygon(
    double lat, double lon, List<(double, double)> polygon) {
  var inside = false;
  final n = polygon.length;
  for (int i = 0, j = n - 1; i < n; j = i++) {
    final yi = polygon[i].$1;
    final xi = polygon[i].$2;
    final yj = polygon[j].$1;
    final xj = polygon[j].$2;

    if (((yi > lat) != (yj > lat)) &&
        (lon < (xj - xi) * (lat - yi) / (yj - yi) + xi)) {
      inside = !inside;
    }
  }
  return inside;
}
