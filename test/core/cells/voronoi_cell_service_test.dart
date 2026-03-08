import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/cells/cell_service.dart';
import 'package:earth_nova/core/cells/voronoi_cell_service.dart';

/// Tests the [CellService] contract via the [VoronoiCellService] implementation.
///
/// All tests are pure-Dart and do NOT require LD_LIBRARY_PATH (no native libs).
void main() {
  // Bounding box centred on San Francisco (Dolores Park area).
  //   lat span: 37.74 → 37.78 ≈ 4.5 km
  //   lon span: -122.45 → -122.41 ≈ 3.6 km
  // 20×20 grid → 400 cells, each ~200 m across.
  late CellService service;

  // A point well inside the bounding box.
  const double lat = 37.7599;
  const double lon = -122.4268;

  setUp(() {
    service = VoronoiCellService(
      minLat: 37.74,
      maxLat: 37.78,
      minLon: -122.45,
      maxLon: -122.41,
      gridRows: 20,
      gridCols: 20,
      seed: 42,
    );
  });

  group('VoronoiCellService — CellService contract', () {
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
    // 2. getCellId distinguishes distant locations
    // -------------------------------------------------------------------------
    test('getCellId returns different IDs for locations ~556m apart', () {
      // ~0.005 degrees latitude ≈ 556 m — spans ~2.5 cell rows.
      const double offsetLat = 0.005;
      final id1 = service.getCellId(lat, lon);
      final id2 = service.getCellId(lat + offsetLat, lon);
      expect(id1, isNot(equals(id2)));
    });

    // -------------------------------------------------------------------------
    // 3. getCellCenter round-trip
    // -------------------------------------------------------------------------
    test('getCellCenter round-trip: center → getCellId → same cell', () {
      final cellId = service.getCellId(lat, lon);
      final center = service.getCellCenter(cellId);
      final roundTripId = service.getCellId(center.lat, center.lon);
      expect(roundTripId, equals(cellId));
    });

    // -------------------------------------------------------------------------
    // 4. getCellBoundary returns ≥3 vertices, all reasonably close to center
    // -------------------------------------------------------------------------
    test('getCellBoundary returns ≥3 vertices, all within 1 km of center', () {
      final cellId = service.getCellId(lat, lon);
      final boundary = service.getCellBoundary(cellId);
      expect(
        boundary.length,
        greaterThanOrEqualTo(3),
        reason: 'Voronoi cell boundary must have at least 3 vertices',
      );

      final center = service.getCellCenter(cellId);
      for (final vertex in boundary) {
        final dist =
            haversineMeters(center.lat, center.lon, vertex.lat, vertex.lon);
        expect(
          dist,
          lessThan(1000),
          reason: 'Boundary vertex should be within 1 km of cell center',
        );
      }
    });

    // -------------------------------------------------------------------------
    // 5. getNeighborIds — ≥1 neighbor, cell itself excluded
    // -------------------------------------------------------------------------
    test('getNeighborIds returns ≥1 neighbor and does not include the cell itself',
        () {
      final cellId = service.getCellId(lat, lon);
      final neighbors = service.getNeighborIds(cellId);
      expect(
        neighbors.length,
        greaterThanOrEqualTo(1),
        reason: 'Interior cell must have at least one neighbor',
      );
      expect(
        neighbors,
        isNot(contains(cellId)),
        reason: 'A cell must not be its own neighbor',
      );
    });

    // -------------------------------------------------------------------------
    // 6. getCellsInRing(k=0) returns exactly [cellId]
    // -------------------------------------------------------------------------
    test('getCellsInRing(k=0) returns exactly [cellId]', () {
      final cellId = service.getCellId(lat, lon);
      final ring = service.getCellsInRing(cellId, 0);
      expect(ring.length, equals(1));
      expect(ring.first, equals(cellId));
    });

    // -------------------------------------------------------------------------
    // 7. getCellsInRing(k=1) includes cell + all its neighbors
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
    // 8. getCellsInRing(k=2) is strictly larger than k=1
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
    // 9. getCellsAroundLocation matches getCellId + getCellsInRing
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
    // 10. systemName contains "Voronoi"
    // -------------------------------------------------------------------------
    test('systemName contains "Voronoi"', () {
      expect(service.systemName, contains('Voronoi'));
    });

    // -------------------------------------------------------------------------
    // 11. systemName reflects grid dimensions
    // -------------------------------------------------------------------------
    test('systemName reflects grid dimensions', () {
      expect(service.systemName, equals('Voronoi (20x20)'));
    });

    // -------------------------------------------------------------------------
    // 12. cellEdgeLengthMeters is a positive, plausible estimate
    // -------------------------------------------------------------------------
    test('cellEdgeLengthMeters is between 50 m and 1000 m', () {
      expect(service.cellEdgeLengthMeters, greaterThan(50));
      expect(service.cellEdgeLengthMeters, lessThan(1000));
    });

    // -------------------------------------------------------------------------
    // 13. All cells within bounding box return valid numeric IDs
    // -------------------------------------------------------------------------
    test('all sampled points within bounding box return valid numeric IDs', () {
      final voronoi = service as VoronoiCellService;
      final testPoints = [
        (37.74 + 0.005, -122.45 + 0.005), // near SW corner
        (37.78 - 0.005, -122.41 - 0.005), // near NE corner
        (lat, lon), // test anchor
        (37.760, -122.430), // another interior point
      ];
      for (final (testLat, testLon) in testPoints) {
        final id = voronoi.getCellId(testLat, testLon);
        final idx = int.tryParse(id);
        expect(idx, isNotNull, reason: 'ID "$id" is not a valid integer string');
        expect(idx!, greaterThanOrEqualTo(0));
        expect(idx, lessThan(voronoi.cellCount));
      }
    });

    // -------------------------------------------------------------------------
    // 14. Points outside bounding box snap to nearest seed without crash
    // -------------------------------------------------------------------------
    test('points outside bounding box snap to nearest seed (no exception)', () {
      // Significantly outside the bounding box.
      expect(() => service.getCellId(40.0, -74.0), returnsNormally);
      expect(() => service.getCellId(0.0, 0.0), returnsNormally);
      final id = service.getCellId(40.0, -74.0);
      expect(id, isNotEmpty);
    });

    // -------------------------------------------------------------------------
    // 15. getCellBoundary fallback — edge-case cell with very few sample points
    // -------------------------------------------------------------------------
    test('getCellBoundary always returns ≥3 vertices for any valid cell ID', () {
      final voronoi = service as VoronoiCellService;
      // Spot-check first 10 and last 10 cells.
      for (int i = 0; i < math.min(10, voronoi.cellCount); i++) {
        final boundary = voronoi.getCellBoundary(i.toString());
        expect(boundary.length, greaterThanOrEqualTo(3),
            reason: 'Cell $i boundary has fewer than 3 vertices');
      }
      for (int i = math.max(0, voronoi.cellCount - 10);
          i < voronoi.cellCount;
          i++) {
        final boundary = voronoi.getCellBoundary(i.toString());
        expect(boundary.length, greaterThanOrEqualTo(3),
            reason: 'Cell $i boundary has fewer than 3 vertices');
      }
    });

    // -------------------------------------------------------------------------
    // 16. Neighbor map is symmetric (if A neighbors B, B neighbors A)
    // -------------------------------------------------------------------------
    test('neighbor relationship is symmetric', () {
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
  });
}

/// Haversine distance in meters between two lat/lon points.
double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
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
