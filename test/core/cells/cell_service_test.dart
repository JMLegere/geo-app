import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/cells/cell_service.dart';
import 'package:earth_nova/core/cells/lazy_voronoi_cell_service.dart';

/// Tests the [CellService] interface contract via the LazyVoronoiCellService
/// implementation.
void main() {
  late CellService service;

  // San Francisco (Dolores Park area)
  const double lat = 37.7599;
  const double lon = -122.4268;

  setUp(() {
    service = LazyVoronoiCellService();
  });

  group('CellService contract — LazyVoronoi implementation', () {
    // Test 1: getCellId is deterministic
    test('getCellId is deterministic (same lat/lon → same ID, 100 iterations)',
        () {
      final firstId = service.getCellId(lat, lon);
      for (int i = 0; i < 100; i++) {
        expect(service.getCellId(lat, lon), equals(firstId),
            reason: 'Iteration $i returned a different cell ID');
      }
    });

    // Test 2: getCellId returns different IDs for locations >500m apart
    test('getCellId returns different IDs for locations >500m apart', () {
      // ~0.005 degrees latitude ≈ 556m
      const double offsetLat = 0.005;
      final id1 = service.getCellId(lat, lon);
      final id2 = service.getCellId(lat + offsetLat, lon);
      expect(id1, isNot(equals(id2)));
    });

    // Test 3: getCellCenter round-trip
    test('getCellCenter round-trip: center → getCellId → same cell', () {
      final cellId = service.getCellId(lat, lon);
      final center = service.getCellCenter(cellId);
      final roundTripId = service.getCellId(center.lat, center.lon);
      expect(roundTripId, equals(cellId));
    });

    // Test 4: getCellBoundary returns ≥4 vertices, all close to center
    test('getCellBoundary returns ≥4 vertices, all within 500m of center', () {
      final cellId = service.getCellId(lat, lon);
      final boundary = service.getCellBoundary(cellId);
      expect(boundary.length, greaterThanOrEqualTo(4),
          reason: 'Voronoi polygon should have at least 4 boundary vertices');

      final center = service.getCellCenter(cellId);
      for (final vertex in boundary) {
        final dist =
            haversineMeters(center.lat, center.lon, vertex.lat, vertex.lon);
        expect(dist, lessThan(500),
            reason: 'Boundary vertex should be within 500m of cell center');
      }
    });

    // Test 5: getNeighborIds returns ≥3 neighbors (Voronoi cells have variable counts)
    test('getNeighborIds returns ≥3 IDs (not including the cell itself)', () {
      final cellId = service.getCellId(lat, lon);
      final neighbors = service.getNeighborIds(cellId);
      expect(neighbors.length, greaterThanOrEqualTo(3));
      expect(neighbors, isNot(contains(cellId)),
          reason: 'Center cell must not be in neighbor list');
    });

    // Test 6: getCellsInRing(k=0) returns 1 cell
    test('getCellsInRing(k=0) returns exactly 1 cell (the center)', () {
      final cellId = service.getCellId(lat, lon);
      final ring = service.getCellsInRing(cellId, 0);
      expect(ring.length, equals(1));
      expect(ring.first, equals(cellId));
    });

    // Test 7: getCellsInRing(k=1) returns center + neighbors
    test('getCellsInRing(k=1) returns center + ≥3 neighbors', () {
      final cellId = service.getCellId(lat, lon);
      final ring = service.getCellsInRing(cellId, 1);
      expect(ring.length, greaterThanOrEqualTo(4));
      expect(ring, contains(cellId));
    });

    // Test 8: getCellsInRing(k=2) returns more cells than k=1
    test('getCellsInRing(k=2) returns more cells than k=1', () {
      final cellId = service.getCellId(lat, lon);
      final ring1 = service.getCellsInRing(cellId, 1);
      final ring2 = service.getCellsInRing(cellId, 2);
      expect(ring2.length, greaterThan(ring1.length));
    });

    // Test 9: getCellsAroundLocation equivalent to getCellId + getCellsInRing
    test('getCellsAroundLocation is equivalent to getCellId + getCellsInRing',
        () {
      const int k = 2;
      final cellId = service.getCellId(lat, lon);
      final viaRing = service.getCellsInRing(cellId, k);
      final viaConvenience = service.getCellsAroundLocation(lat, lon, k);

      expect(viaConvenience.toSet(), equals(viaRing.toSet()));
    });

    // Test 10: cellEdgeLengthMeters in plausible range for walking-scale cells
    test('cellEdgeLengthMeters is in walking-scale range (50–500m)', () {
      expect(service.cellEdgeLengthMeters, greaterThan(50));
      expect(service.cellEdgeLengthMeters, lessThan(500));
    });

    // Test 11: systemName
    test('systemName identifies the implementation', () {
      expect(service.systemName, isNotEmpty);
    });
  });
}

/// Haversine distance in meters between two lat/lon points.
double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  const double r = 6371000; // Earth radius in meters
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
