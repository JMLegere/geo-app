import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/cells/cell_cache.dart';
import 'package:earth_nova/core/cells/lazy_voronoi_cell_service.dart';
import 'package:earth_nova/core/fog/fog_state_resolver.dart';
import 'package:earth_nova/core/models/fog_state.dart';
import 'package:earth_nova/features/map/controllers/fog_overlay_controller.dart';
import 'package:earth_nova/features/map/utils/mercator_projection.dart';

/// Full-pipeline diagnostic: CellService → FogResolver → FogOverlayController
///
/// Simulates exactly what the MapScreen does on a location update,
/// then inspects the render data to find cells with ≤3 screen vertices.
void main() {
  group('Full rendering pipeline diagnostic', () {
    late CellCache cellService;
    late FogStateResolver fogResolver;
    late FogOverlayController fogOverlay;

    setUp(() {
      cellService = CellCache(LazyVoronoiCellService(
        gridStep: 0.002,
        jitterFactor: 0.75,
        globalSeed: 42,
        neighborRadius: 3,
      ));
      fogResolver = FogStateResolver(cellService);
      fogOverlay = FogOverlayController(
        cellService: cellService,
        fogResolver: fogResolver,
        sampleStepPx: 25.0,
      );
    });

    test('after location update, rendered cells have ≥5 screen vertices', () {
      const playerLat = 37.7749;
      const playerLon = -122.4194;
      const zoom = 15.0;
      const viewportSize = Size(1920, 1080);

      // 1. Simulate player location update (what MapScreen._onLocationUpdate does)
      fogResolver.onLocationUpdate(playerLat, playerLon);

      // 2. Compute fog overlay (what MapScreen._onLocationUpdate does next)
      fogOverlay.update(
        cameraLat: playerLat,
        cameraLon: playerLon,
        zoom: zoom,
        viewportSize: viewportSize,
      );

      final renderData = fogOverlay.renderData;
      print('Total rendered cells: ${renderData.length}');

      // Categorize by vertex count
      final vertexCounts = <int, int>{};
      for (final cell in renderData) {
        final count = cell.screenVertices.length;
        vertexCounts[count] = (vertexCounts[count] ?? 0) + 1;
      }
      print('Vertex count distribution: $vertexCounts');

      // Categorize by fog state
      final fogCounts = <FogState, int>{};
      for (final cell in renderData) {
        fogCounts[cell.fogState] = (fogCounts[cell.fogState] ?? 0) + 1;
      }
      print('Fog state distribution: $fogCounts');

      // Print first 5 cells with their vertex details
      for (final cell in renderData.take(5)) {
        print('Cell ${cell.cellId}: ${cell.fogState}, '
            '${cell.screenVertices.length} vertices');

        // Also check the raw boundary
        final boundary = cellService.getCellBoundary(cell.cellId);
        print('  Raw boundary: ${boundary.length} geo vertices');
      }

      // The key check: no cells should be triangles
      final triangleCells =
          renderData.where((c) => c.screenVertices.length <= 3).toList();
      print('\nTriangle cells (≤3 vertices): ${triangleCells.length}');
      for (final cell in triangleCells.take(5)) {
        final boundary = cellService.getCellBoundary(cell.cellId);
        print('  ${cell.cellId}: ${cell.screenVertices.length} screen verts, '
            '${boundary.length} geo verts');
        print('  Screen positions: ${cell.screenVertices}');
        print('  Geo positions: ${boundary.map((g) => "(${g.lat.toStringAsFixed(6)}, ${g.lon.toStringAsFixed(6)})").join(", ")}');
      }

      expect(
        triangleCells.length,
        equals(0),
        reason: '${triangleCells.length} cells have ≤3 vertices (triangle shape). '
            'Expected 0 triangles in proper Voronoi tessellation.',
      );
    });

    test('MercatorProjection preserves polygon vertex count', () {
      const cameraLat = 37.7749;
      const cameraLon = -122.4194;
      const zoom = 15.0;
      const viewportSize = Size(1920, 1080);

      final service = LazyVoronoiCellService(
        gridStep: 0.002,
        jitterFactor: 0.75,
        globalSeed: 42,
        neighborRadius: 3,
      );

      // Get boundary for cell near SF
      final cellId = service.getCellId(cameraLat, cameraLon);
      final boundary = service.getCellBoundary(cellId);
      print('Geo boundary: ${boundary.length} vertices');

      // Project to screen
      final screenVerts = boundary
          .map((geo) => MercatorProjection.geoToScreen(
                lat: geo.lat,
                lon: geo.lon,
                cameraLat: cameraLat,
                cameraLon: cameraLon,
                zoom: zoom,
                viewportSize: viewportSize,
              ))
          .toList();
      print('Screen vertices: ${screenVerts.length}');

      // Check that vertices are distinct (not collapsed)
      for (int i = 0; i < screenVerts.length; i++) {
        for (int j = i + 1; j < screenVerts.length; j++) {
          final dist = (screenVerts[i] - screenVerts[j]).distance;
          expect(
            dist,
            greaterThan(1.0),
            reason: 'Vertices $i and $j collapsed to same screen position '
                '(dist=$dist px)',
          );
        }
      }

      // Vertex count should be preserved
      expect(screenVerts.length, equals(boundary.length));
    });
  });
}
