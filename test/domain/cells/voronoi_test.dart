import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/domain/cells/voronoi.dart';

// Shared instance tuned for fast tests (small neighborhood radius).
LazyVoronoiCellService _makeSvc({double gridStep = 0.002, int radius = 3}) =>
    LazyVoronoiCellService(
      gridStep: gridStep,
      jitterFactor: 0.75,
      globalSeed: 42,
      neighborRadius: radius,
    );

void main() {
  group('LazyVoronoiCellService', () {
    late LazyVoronoiCellService svc;

    setUp(() {
      svc = _makeSvc();
    });

    // ── getCellId ─────────────────────────────────────────────────────────────

    test('getCellId returns consistent ID for same coordinates', () {
      final a = svc.getCellId(1.001, 1.001);
      final b = svc.getCellId(1.001, 1.001);
      expect(a, equals(b));
    });

    test('getCellId returns different IDs for coordinates far apart', () {
      final a = svc.getCellId(0.0, 0.0);
      final b = svc.getCellId(10.0, 10.0);
      expect(a, isNot(equals(b)));
    });

    test('getCellId produces IDs with v_ prefix', () {
      final id = svc.getCellId(45.0, -75.0);
      expect(id, startsWith('v_'));
    });

    // ── getCellCenter ─────────────────────────────────────────────────────────

    test('getCellCenter returns the jittered seed center of the cell', () {
      const lat = 1.0;
      const lon = 1.0;
      final cellId = svc.getCellId(lat, lon);
      final center = svc.getCellCenter(cellId);

      // Center should be close to the input location (within ~gridStep distance).
      const gridStep = 0.002;
      expect((center.lat - lat).abs(), lessThan(gridStep * 2));
      expect((center.lon - lon).abs(), lessThan(gridStep * 2));
    });

    test('getCellCenter is deterministic for the same cellId', () {
      final cellId = svc.getCellId(1.0, 1.0);
      final c1 = svc.getCellCenter(cellId);
      final c2 = svc.getCellCenter(cellId);
      expect(c1.lat, c2.lat);
      expect(c1.lon, c2.lon);
    });

    // ── getCellBoundary ───────────────────────────────────────────────────────

    test('getCellBoundary returns polygon vertices (non-empty)', () {
      final cellId = svc.getCellId(1.0, 1.0);
      final boundary = svc.getCellBoundary(cellId);
      expect(boundary, isNotEmpty);
    });

    test('getCellBoundary vertices are near the cell center', () {
      final cellId = svc.getCellId(1.0, 1.0);
      final center = svc.getCellCenter(cellId);
      final boundary = svc.getCellBoundary(cellId);

      // All boundary vertices should be within ~5 grid steps of center.
      for (final vertex in boundary) {
        final dist = sqrt(
          pow(vertex.lat - center.lat, 2) + pow(vertex.lon - center.lon, 2),
        );
        expect(dist, lessThan(0.02)); // 10× gridStep
      }
    });

    // ── getNeighborIds ────────────────────────────────────────────────────────

    test('getNeighborIds returns adjacent cell IDs (non-empty)', () {
      final cellId = svc.getCellId(1.0, 1.0);
      final neighbors = svc.getNeighborIds(cellId);
      expect(neighbors, isNotEmpty);
    });

    test('getNeighborIds result does not include the cell itself', () {
      final cellId = svc.getCellId(1.0, 1.0);
      final neighbors = svc.getNeighborIds(cellId);
      expect(neighbors, isNot(contains(cellId)));
    });

    test(
        'neighborOf(A) includes A as neighbor of neighborOf(A) (bidirectional)',
        () {
      final aId = svc.getCellId(1.0, 1.0);
      final aNeighbors = svc.getNeighborIds(aId);
      expect(aNeighbors, isNotEmpty);

      final bId = aNeighbors.first;
      final bNeighbors = svc.getNeighborIds(bId);
      // Voronoi neighbors are symmetric.
      expect(bNeighbors, contains(aId));
    });

    // ── getCellsInRing ────────────────────────────────────────────────────────

    test('getCellsInRing(k:0) returns only the cell itself', () {
      final cellId = svc.getCellId(1.0, 1.0);
      final ring0 = svc.getCellsInRing(cellId, 0);
      expect(ring0, [cellId]);
    });

    test('getCellsInRing(k:1) includes the cell and its immediate neighbors',
        () {
      final cellId = svc.getCellId(1.0, 1.0);
      final ring1 = svc.getCellsInRing(cellId, 1);
      final neighbors = svc.getNeighborIds(cellId);

      expect(ring1, contains(cellId));
      for (final n in neighbors) {
        expect(ring1, contains(n));
      }
    });

    test('getCellsInRing(k:2) has more cells than k:1', () {
      final cellId = svc.getCellId(1.0, 1.0);
      final ring1 = svc.getCellsInRing(cellId, 1);
      final ring2 = svc.getCellsInRing(cellId, 2);
      expect(ring2.length, greaterThan(ring1.length));
    });

    // ── cellEdgeLengthMeters ──────────────────────────────────────────────────

    test('cellEdgeLengthMeters is approximately 180m for default gridStep', () {
      // Formula in source: gridStep * (metersPerDegLat + metersPerDegLon) / 2
      // ≈ 0.002 * (111000 + 78485) / 2 ≈ 0.002 * 94742 ≈ 189 m.
      final length = svc.cellEdgeLengthMeters;
      expect(length, greaterThan(150));
      expect(length, lessThan(250));
    });

    // ── systemName ────────────────────────────────────────────────────────────

    test('systemName contains "Voronoi"', () {
      expect(svc.systemName.toLowerCase(), contains('voronoi'));
    });
  });
}
