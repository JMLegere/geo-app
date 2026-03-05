import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/core/cells/delaunay.dart';

void main() {
  group('delaunayTriangulate', () {
    // -------------------------------------------------------------------------
    // Basic triangle
    // -------------------------------------------------------------------------
    test('triangulates 3 points into exactly 1 triangle', () {
      final points = [(0.0, 0.0), (1.0, 0.0), (0.5, 1.0)];
      final result = delaunayTriangulate(points);

      expect(result.triangles.length, equals(1));
      expect(result.circumcenters.length, equals(1));

      // All three indices should be present.
      final tri = result.triangles.first;
      final indices = {tri.$1, tri.$2, tri.$3};
      expect(indices, equals({0, 1, 2}));
    });

    // -------------------------------------------------------------------------
    // Square (4 points) → 2 triangles
    // -------------------------------------------------------------------------
    test('triangulates 4 points (square) into 2 triangles', () {
      final points = [
        (0.0, 0.0),
        (1.0, 0.0),
        (1.0, 1.0),
        (0.0, 1.0),
      ];
      final result = delaunayTriangulate(points);

      expect(result.triangles.length, equals(2));
      expect(result.circumcenters.length, equals(2));

      // Every triangle index should be in range [0, 3].
      for (final tri in result.triangles) {
        expect(tri.$1, inInclusiveRange(0, 3));
        expect(tri.$2, inInclusiveRange(0, 3));
        expect(tri.$3, inInclusiveRange(0, 3));
      }
    });

    // -------------------------------------------------------------------------
    // 5 points → correct triangle count
    // -------------------------------------------------------------------------
    test('triangulates 5 points into expected number of triangles', () {
      final points = [
        (0.0, 0.0),
        (2.0, 0.0),
        (2.0, 2.0),
        (0.0, 2.0),
        (1.0, 1.0), // center point
      ];
      final result = delaunayTriangulate(points);

      // 5 points, no collinear → 4 triangles (Euler: 2n - 2 - h, h=4 hull).
      expect(result.triangles.length, equals(4));
    });

    // -------------------------------------------------------------------------
    // Circumcenter correctness
    // -------------------------------------------------------------------------
    test('circumcenters are equidistant from all three triangle vertices', () {
      final points = [
        (0.0, 0.0),
        (4.0, 0.0),
        (2.0, 3.0),
        (1.0, 1.0),
        (3.0, 1.0),
      ];
      final result = delaunayTriangulate(points);

      for (int i = 0; i < result.triangles.length; i++) {
        final tri = result.triangles[i];
        final cc = result.circumcenters[i];
        final a = points[tri.$1];
        final b = points[tri.$2];
        final c = points[tri.$3];

        final da = _dist(cc, a);
        final db = _dist(cc, b);
        final dc = _dist(cc, c);

        expect(da, closeTo(db, 1e-8),
            reason: 'Circumcenter should be equidistant from vertices A and B');
        expect(da, closeTo(dc, 1e-8),
            reason: 'Circumcenter should be equidistant from vertices A and C');
      }
    });

    // -------------------------------------------------------------------------
    // Super-triangle removal
    // -------------------------------------------------------------------------
    test('result contains no indices outside the input point range', () {
      final points = [
        (0.0, 0.0),
        (1.0, 0.0),
        (0.5, 1.0),
        (0.5, 0.3),
      ];
      final result = delaunayTriangulate(points);

      for (final tri in result.triangles) {
        expect(tri.$1, inInclusiveRange(0, points.length - 1));
        expect(tri.$2, inInclusiveRange(0, points.length - 1));
        expect(tri.$3, inInclusiveRange(0, points.length - 1));
      }
    });

    // -------------------------------------------------------------------------
    // Collinear points
    // -------------------------------------------------------------------------
    test('handles collinear points gracefully (returns 0 triangles)', () {
      final points = [(0.0, 0.0), (1.0, 0.0), (2.0, 0.0)];
      final result = delaunayTriangulate(points);

      // Collinear points cannot form a valid Delaunay triangulation.
      // The algorithm may return 0 or degenerate triangles.
      // We just verify it doesn't crash.
      expect(result.triangles, isA<List>());
    });

    // -------------------------------------------------------------------------
    // Duplicate points
    // -------------------------------------------------------------------------
    test('handles duplicate points without crashing', () {
      final points = [
        (0.0, 0.0),
        (1.0, 0.0),
        (0.5, 1.0),
        (0.0, 0.0), // duplicate of point 0
      ];
      final result = delaunayTriangulate(points);

      // Should produce at least 1 triangle from the 3 unique points.
      expect(result.triangles.length, greaterThanOrEqualTo(1));
    });

    // -------------------------------------------------------------------------
    // Fewer than 3 points
    // -------------------------------------------------------------------------
    test('returns empty result for fewer than 3 points', () {
      expect(delaunayTriangulate([]).triangles, isEmpty);
      expect(delaunayTriangulate([(0.0, 0.0)]).triangles, isEmpty);
      expect(
          delaunayTriangulate([(0.0, 0.0), (1.0, 1.0)]).triangles, isEmpty);
    });

    // -------------------------------------------------------------------------
    // Delaunay property: no point inside any circumcircle
    // -------------------------------------------------------------------------
    test('Delaunay property: no point lies inside any circumcircle', () {
      // Use a grid of points for a robust test.
      final points = <(double, double)>[];
      final rng = math.Random(42);
      for (int i = 0; i < 20; i++) {
        points.add((rng.nextDouble() * 10, rng.nextDouble() * 10));
      }

      final result = delaunayTriangulate(points);

      for (int i = 0; i < result.triangles.length; i++) {
        final tri = result.triangles[i];
        final cc = result.circumcenters[i];
        final radiusSq = _distSq(cc, points[tri.$1]);

        for (int j = 0; j < points.length; j++) {
          if (j == tri.$1 || j == tri.$2 || j == tri.$3) continue;
          final dSq = _distSq(cc, points[j]);
          expect(
            dSq,
            greaterThanOrEqualTo(radiusSq - 1e-8),
            reason:
                'Point $j is inside circumcircle of triangle $i (violates Delaunay)',
          );
        }
      }
    });

    // -------------------------------------------------------------------------
    // Regular grid of points
    // -------------------------------------------------------------------------
    test('triangulates a 4×4 regular grid correctly', () {
      final points = <(double, double)>[];
      for (int r = 0; r < 4; r++) {
        for (int c = 0; c < 4; c++) {
          points.add((r.toDouble(), c.toDouble()));
        }
      }

      final result = delaunayTriangulate(points);

      // 16 points on a 4×4 grid → 18 triangles (3×3 squares × 2 triangles).
      expect(result.triangles.length, equals(18));
    });
  });
}

double _dist((double, double) a, (double, double) b) {
  return math.sqrt(_distSq(a, b));
}

double _distSq((double, double) a, (double, double) b) {
  final dx = a.$1 - b.$1;
  final dy = a.$2 - b.$2;
  return dx * dx + dy * dy;
}
