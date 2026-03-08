import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/cells/delaunay.dart';
import 'package:earth_nova/core/cells/lazy_voronoi_cell_service.dart';

/// Diagnostic test to reproduce the "sparse disconnected triangles" bug.
///
/// Production uses gridStep=0.002 (vs test's 0.0125). This test checks
/// whether cells near SF have proper polygon boundaries (5-7 vertices)
/// instead of degenerate triangles (3 vertices).
void main() {
  group('Voronoi polygon vertex count diagnostic', () {
    test('production params: cells near SF have ≥5 boundary vertices', () {
      final service = LazyVoronoiCellService(
        gridStep: 0.002, // PRODUCTION value
        jitterFactor: 0.75, // PRODUCTION value
        globalSeed: 42,
        neighborRadius: 3,
      );

      // San Francisco — default map center
      const lat = 37.7749;
      const lon = -122.4194;

      final cellId = service.getCellId(lat, lon);
      final boundary = service.getCellBoundary(cellId);

      print('Cell ID: $cellId');
      print('Boundary vertex count: ${boundary.length}');
      for (final v in boundary) {
        print('  (${v.lat}, ${v.lon})');
      }

      // A proper interior Voronoi cell should have 5-7 vertices,
      // NOT 3 (triangle).
      expect(
        boundary.length,
        greaterThanOrEqualTo(5),
        reason: 'Interior Voronoi cell should have ≥5 vertices, '
            'got ${boundary.length} (triangle = broken Delaunay)',
      );
    });

    test('production params: check 20 cells around SF for vertex counts', () {
      final service = LazyVoronoiCellService(
        gridStep: 0.002,
        jitterFactor: 0.75,
        globalSeed: 42,
        neighborRadius: 3,
      );

      const baseLat = 37.7749;
      const baseLon = -122.4194;

      final vertexCounts = <int>[];

      // Sample a 5×4 grid of cells around SF
      for (int r = 0; r < 5; r++) {
        for (int c = 0; c < 4; c++) {
          final lat = baseLat + r * 0.003;
          final lon = baseLon + c * 0.003;
          final cellId = service.getCellId(lat, lon);
          final boundary = service.getCellBoundary(cellId);
          vertexCounts.add(boundary.length);
        }
      }

      print('Vertex counts for 20 cells: $vertexCounts');
      final triangleCount = vertexCounts.where((c) => c <= 3).length;
      print('Cells with ≤3 vertices (triangles): $triangleCount / ${vertexCounts.length}');

      // No more than 10% of interior cells should be triangular.
      expect(
        triangleCount,
        lessThanOrEqualTo(2),
        reason: '$triangleCount / ${vertexCounts.length} cells are triangles — '
            'Voronoi tessellation is broken',
      );
    });

    test('Delaunay triangle count for 49-point jittered grid', () {
      // Reproduce exactly what LazyVoronoiCellService does internally
      final service = LazyVoronoiCellService(
        gridStep: 0.002,
        jitterFactor: 0.75,
        globalSeed: 42,
        neighborRadius: 3,
      );

      const lat = 37.7749;
      const lon = -122.4194;
      final cellId = service.getCellId(lat, lon);

      // Parse cell ID to get row, col
      final parts = cellId.split('_');
      final row = int.parse(parts[1]);
      final col = int.parse(parts[2]);

      // Generate the same local seeds that _computeLocalVoronoi would
      final seeds = <(double, double)>[];
      int targetIdx = -1;
      for (int dr = -3; dr <= 3; dr++) {
        for (int dc = -3; dc <= 3; dc++) {
          final r = row + dr;
          final c = col + dc;
          if (r == row && c == col) targetIdx = seeds.length;
          final center = service.getCellCenter('v_${r}_$c');
          seeds.add((center.lat, center.lon));
        }
      }

      print('Target index: $targetIdx');
      print('Total seeds: ${seeds.length}');

      final result = delaunayTriangulate(seeds);
      print('Total Delaunay triangles: ${result.triangles.length}');

      // Count triangles incident to target
      int incidentCount = 0;
      for (final tri in result.triangles) {
        if (tri.$1 == targetIdx || tri.$2 == targetIdx || tri.$3 == targetIdx) {
          incidentCount++;
        }
      }

      print('Triangles incident to target: $incidentCount');

      // Interior point of 49-point grid should have 5-7 incident triangles
      expect(
        incidentCount,
        greaterThanOrEqualTo(5),
        reason: 'Center point should have ≥5 incident Delaunay triangles, '
            'got $incidentCount',
      );
    });

    test('identical() works correctly for record tuples', () {
      // Test if identical() is reliable for records — this is the suspected bug
      final list = <(int, int, int)>[(1, 2, 3), (4, 5, 6), (7, 8, 9)];

      for (int i = 0; i < list.length; i++) {
        final a = list[i];
        for (int j = 0; j < list.length; j++) {
          final b = list[j];
          if (i == j) {
            // Same element — identical should be true
            expect(identical(a, b), isTrue,
                reason: 'identical() failed for same list element at index $i');
          } else {
            // Different elements with different values — identical should be false
            expect(identical(a, b), isFalse,
                reason: 'identical() wrongly true for indices $i and $j');
          }
        }
      }
    });
  });
}
