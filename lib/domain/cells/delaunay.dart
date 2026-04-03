import 'dart:math';

/// Result of a Delaunay triangulation.
///
/// Contains the list of triangles (as index triples into the input point list)
/// and the circumcenter of each triangle.
class DelaunayResult {
  /// Each triangle is a triple of indices into the original point list.
  final List<(int, int, int)> triangles;

  /// Circumcenter of each triangle, in the same order as [triangles].
  final List<(double, double)> circumcenters;

  /// Creates a Delaunay triangulation result.
  const DelaunayResult({
    required this.triangles,
    required this.circumcenters,
  });
}

/// Bowyer-Watson incremental Delaunay triangulation.
///
/// Pure geometry — no Flutter or geobase dependencies. Operates on 2D points
/// represented as `(double, double)` records (x, y).
///
/// Usage:
/// ```dart
/// final points = [(0.0, 0.0), (1.0, 0.0), (0.5, 1.0)];
/// final result = delaunayTriangulate(points);
/// ```
DelaunayResult delaunayTriangulate(List<(double, double)> points) {
  if (points.length < 3) {
    return const DelaunayResult(triangles: [], circumcenters: []);
  }

  // De-duplicate points (Bowyer-Watson breaks on exact duplicates).
  final uniquePoints = <(double, double)>[];
  final seen = <(double, double)>{};
  final indexMap = <int, int>{}; // original index → unique index
  for (int i = 0; i < points.length; i++) {
    if (seen.add(points[i])) {
      indexMap[i] = uniquePoints.length;
      uniquePoints.add(points[i]);
    } else {
      // Map duplicate to the first occurrence's unique index.
      final firstOriginal =
          points.indexWhere((p) => p.$1 == points[i].$1 && p.$2 == points[i].$2);
      indexMap[i] = indexMap[firstOriginal]!;
    }
  }

  if (uniquePoints.length < 3) {
    return const DelaunayResult(triangles: [], circumcenters: []);
  }

  final result = _bowyerWatson(uniquePoints);

  // Remap unique indices back to original indices.
  // Build reverse map: unique index → first original index.
  final reverseMap = <int, int>{};
  for (final entry in indexMap.entries) {
    reverseMap.putIfAbsent(entry.value, () => entry.key);
  }

  final remappedTriangles = result.triangles.map((t) {
    return (reverseMap[t.$1]!, reverseMap[t.$2]!, reverseMap[t.$3]!);
  }).toList();

  return DelaunayResult(
    triangles: remappedTriangles,
    circumcenters: result.circumcenters,
  );
}

/// Core Bowyer-Watson algorithm on a list of unique 2D points.
DelaunayResult _bowyerWatson(List<(double, double)> points) {
  // 1. Create a super-triangle that encloses all points.
  final (st0, st1, st2) = _superTriangle(points);
  final n = points.length;

  // Working point list: original points + 3 super-triangle vertices.
  final allPoints = [...points, st0, st1, st2];
  final superA = n;
  final superB = n + 1;
  final superC = n + 2;

  // Active triangles stored as index triples.
  var triangles = <(int, int, int)>[(superA, superB, superC)];

  // 2. Insert each point incrementally.
  for (int i = 0; i < n; i++) {
    final p = allPoints[i];

    // Find all triangles whose circumcircle contains the new point.
    final badTriangles = <(int, int, int)>[];
    for (final tri in triangles) {
      if (_inCircumcircle(
          p, allPoints[tri.$1], allPoints[tri.$2], allPoints[tri.$3])) {
        badTriangles.add(tri);
      }
    }

    // Find the boundary polygon of the "bad" region.
    final polygon = <(int, int)>[];
    for (final tri in badTriangles) {
      final edges = [
        (tri.$1, tri.$2),
        (tri.$2, tri.$3),
        (tri.$3, tri.$1),
      ];
      for (final edge in edges) {
        // An edge is on the boundary if it is NOT shared by another bad triangle.
        final shared = badTriangles.any((other) =>
            !identical(other, tri) && _triangleContainsEdge(other, edge));
        if (!shared) {
          polygon.add(edge);
        }
      }
    }

    // Remove bad triangles.
    triangles =
        triangles.where((t) => !badTriangles.contains(t)).toList();

    // Re-triangulate the hole with the new point.
    for (final edge in polygon) {
      triangles.add((i, edge.$1, edge.$2));
    }
  }

  // 3. Remove triangles that share a vertex with the super-triangle.
  triangles = triangles
      .where((t) =>
          t.$1 < n && t.$2 < n && t.$3 < n)
      .toList();

  // 4. Compute circumcenters.
  final circumcenters = triangles.map((t) {
    return _circumcenter(allPoints[t.$1], allPoints[t.$2], allPoints[t.$3]);
  }).toList();

  return DelaunayResult(triangles: triangles, circumcenters: circumcenters);
}

/// Returns a super-triangle that encloses all [points] with generous margin.
(
  (double, double),
  (double, double),
  (double, double),
) _superTriangle(List<(double, double)> points) {
  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = double.negativeInfinity;
  var maxY = double.negativeInfinity;

  for (final p in points) {
    if (p.$1 < minX) minX = p.$1;
    if (p.$2 < minY) minY = p.$2;
    if (p.$1 > maxX) maxX = p.$1;
    if (p.$2 > maxY) maxY = p.$2;
  }

  final dx = maxX - minX;
  final dy = maxY - minY;
  final dmax = max(dx, dy);
  final midX = (minX + maxX) / 2;
  final midY = (minY + maxY) / 2;

  return (
    (midX - 20 * dmax, midY - dmax),
    (midX, midY + 20 * dmax),
    (midX + 20 * dmax, midY - dmax),
  );
}

/// Tests whether point [p] lies inside the circumcircle of triangle (a, b, c).
///
/// Computes the circumcircle center and radius, then checks if [p] is closer
/// than the radius. This approach is winding-order independent.
bool _inCircumcircle(
  (double, double) p,
  (double, double) a,
  (double, double) b,
  (double, double) c,
) {
  final center = _circumcenter(a, b, c);
  final radiusSq = _distSq(center, a);
  final distSq = _distSq(center, p);
  // Small epsilon to handle floating-point edge cases.
  return distSq < radiusSq - 1e-10;
}

/// Squared distance between two 2D points.
double _distSq((double, double) a, (double, double) b) {
  final dx = a.$1 - b.$1;
  final dy = a.$2 - b.$2;
  return dx * dx + dy * dy;
}

/// Computes the circumcenter of triangle (a, b, c).
(double, double) _circumcenter(
  (double, double) a,
  (double, double) b,
  (double, double) c,
) {
  final ax = a.$1;
  final ay = a.$2;
  final bx = b.$1;
  final by = b.$2;
  final cx = c.$1;
  final cy = c.$2;

  final d = 2 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by));

  if (d.abs() < 1e-12) {
    // Degenerate (collinear) — return centroid as fallback.
    return ((ax + bx + cx) / 3, (ay + by + cy) / 3);
  }

  final ux = ((ax * ax + ay * ay) * (by - cy) +
          (bx * bx + by * by) * (cy - ay) +
          (cx * cx + cy * cy) * (ay - by)) /
      d;
  final uy = ((ax * ax + ay * ay) * (cx - bx) +
          (bx * bx + by * by) * (ax - cx) +
          (cx * cx + cy * cy) * (bx - ax)) /
      d;

  return (ux, uy);
}

/// Checks whether a triangle contains an edge (in either direction).
bool _triangleContainsEdge((int, int, int) tri, (int, int) edge) {
  final edges = [
    (tri.$1, tri.$2),
    (tri.$2, tri.$3),
    (tri.$3, tri.$1),
  ];
  return edges.any((e) =>
      (e.$1 == edge.$1 && e.$2 == edge.$2) ||
      (e.$1 == edge.$2 && e.$2 == edge.$1));
}
