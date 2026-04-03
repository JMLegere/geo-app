import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:geobase/geobase.dart';
import 'package:earth_nova/core/cells/cell_service.dart';
import 'package:earth_nova/core/fog/fog_state_resolver.dart';
import 'package:earth_nova/features/map/controllers/fog_overlay_controller.dart';
import 'package:earth_nova/features/map/utils/fog_geojson_builder.dart';
import 'package:earth_nova/shared/constants.dart';

// ---------------------------------------------------------------------------
// MockCellService — simple 1°×1° degree grid.
//
// Cell ID: "cell_{latBucket}_{lonBucket}" where bucket = floor(lat) etc.
// Each cell covers a 1°×1° area for easy testing.
// ---------------------------------------------------------------------------
class MockCellService implements CellService {
  @override
  String getCellId(double lat, double lon) {
    final latBucket = lat.floor();
    final lonBucket = lon.floor();
    return 'cell_${latBucket}_$lonBucket';
  }

  @override
  Geographic getCellCenter(String cellId) {
    final parts = cellId.split('_');
    final lat = double.parse(parts[1]) + 0.5;
    final lon = double.parse(parts[2]) + 0.5;
    return Geographic(lat: lat, lon: lon);
  }

  @override
  List<Geographic> getCellBoundary(String cellId) {
    final parts = cellId.split('_');
    final lat = double.parse(parts[1]);
    final lon = double.parse(parts[2]);
    // Return a unit-degree square polygon.
    return [
      Geographic(lat: lat, lon: lon),
      Geographic(lat: lat, lon: lon + 1),
      Geographic(lat: lat + 1, lon: lon + 1),
      Geographic(lat: lat + 1, lon: lon),
    ];
  }

  @override
  List<String> getNeighborIds(String cellId) {
    final parts = cellId.split('_');
    final lat = int.parse(parts[1]);
    final lon = int.parse(parts[2]);
    final neighbors = <String>[];
    for (var dlat = -1; dlat <= 1; dlat++) {
      for (var dlon = -1; dlon <= 1; dlon++) {
        if (dlat == 0 && dlon == 0) continue;
        neighbors.add('cell_${lat + dlat}_${lon + dlon}');
      }
    }
    return neighbors;
  }

  @override
  List<String> getCellsInRing(String cellId, int k) {
    final parts = cellId.split('_');
    final lat = int.parse(parts[1]);
    final lon = int.parse(parts[2]);
    final cells = <String>[];
    for (var dlat = -k; dlat <= k; dlat++) {
      for (var dlon = -k; dlon <= k; dlon++) {
        cells.add('cell_${lat + dlat}_${lon + dlon}');
      }
    }
    return cells;
  }

  @override
  List<String> getCellsAroundLocation(double lat, double lon, int k) {
    return getCellsInRing(getCellId(lat, lon), k);
  }

  @override
  double get cellEdgeLengthMeters => 111000.0; // ~1° at equator

  @override
  String get systemName => 'MockGrid';
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Small viewport for predictable sampling counts.
const _viewport = Size(400, 800);
const _zoom = 13.0;

/// San Francisco area — approximately 37–38°N, -123 to -122°E.
const _cameraLat = 37.7;
const _cameraLon = -122.4;

FogOverlayController _makeController({
  MockCellService? cellService,
  FogStateResolver? fogResolver,
}) {
  final cs = cellService ?? MockCellService();
  final fr = fogResolver ?? FogStateResolver(cs);
  return FogOverlayController(
    cellService: cs,
    fogResolver: fr,
    sampleStepPx: 80.0,
  );
}

/// Parses a GeoJSON string and returns the decoded map.
Map<String, dynamic> _parseGeoJson(String geoJson) {
  return jsonDecode(geoJson) as Map<String, dynamic>;
}

/// Returns the list of features from a GeoJSON FeatureCollection string.
List<dynamic> _getFeatures(String geoJson) {
  final parsed = _parseGeoJson(geoJson);
  return parsed['features'] as List<dynamic>;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('FogOverlayController', () {
    // -----------------------------------------------------------------------
    // Initial state
    // -----------------------------------------------------------------------

    test('renderVersion starts at 0', () {
      final controller = _makeController();
      expect(controller.renderVersion, equals(0));
    });

    test('baseFogGeoJson is full world fog before first update', () {
      final controller = _makeController();
      expect(controller.baseFogGeoJson, equals(FogGeoJsonBuilder.fullWorldFog));
    });

    test('midFogGeoJson is empty before first update', () {
      final controller = _makeController();
      expect(
        controller.midFogGeoJson,
        equals(FogGeoJsonBuilder.emptyFeatureCollection),
      );
    });

    // -----------------------------------------------------------------------
    // update — version increment
    // -----------------------------------------------------------------------

    test('renderVersion increments on each update call', () {
      final controller = _makeController();

      controller.update(
        cameraLat: _cameraLat,
        cameraLon: _cameraLon,
        zoom: _zoom,
        viewportSize: _viewport,
      );
      expect(controller.renderVersion, equals(1));

      controller.update(
        cameraLat: _cameraLat,
        cameraLon: _cameraLon,
        zoom: _zoom,
        viewportSize: _viewport,
      );
      expect(controller.renderVersion, equals(2));

      controller.update(
        cameraLat: _cameraLat,
        cameraLon: _cameraLon,
        zoom: _zoom,
        viewportSize: _viewport,
      );
      expect(controller.renderVersion, equals(3));
    });

    test('renderVersion increments even when no cells are visited', () {
      // No location updates → all cells undetected → no holes in base fog.
      final controller = _makeController();

      controller.update(
        cameraLat: _cameraLat,
        cameraLon: _cameraLon,
        zoom: _zoom,
        viewportSize: _viewport,
      );

      expect(controller.renderVersion, equals(1));
    });

    // -----------------------------------------------------------------------
    // update — base fog GeoJSON (world polygon with holes)
    // -----------------------------------------------------------------------

    test('baseFogGeoJson has no holes when no cells are visited', () {
      final cellService = MockCellService();
      final fogResolver = FogStateResolver(cellService);
      // No location update → all cells undetected.
      final controller = FogOverlayController(
        cellService: cellService,
        fogResolver: fogResolver,
        sampleStepPx: 80.0,
      );

      controller.update(
        cameraLat: _cameraLat,
        cameraLon: _cameraLon,
        zoom: _zoom,
        viewportSize: _viewport,
      );

      // The base fog should be the full world polygon (no holes).
      final features = _getFeatures(controller.baseFogGeoJson);
      expect(features.length, equals(1));

      final geometry = features[0]['geometry'] as Map<String, dynamic>;
      expect(geometry['type'], equals('Polygon'));

      final coordinates = geometry['coordinates'] as List<dynamic>;
      // Only the exterior ring — no hole rings.
      expect(coordinates.length, equals(1),
          reason: 'No holes should be present when no cells are visited');
    });

    test('baseFogGeoJson has holes after visiting a location', () {
      final cellService = MockCellService();
      final fogResolver = FogStateResolver(cellService);
      // Visit the camera location → current cell becomes observed,
      // neighbors become concealed/hidden.
      fogResolver.onLocationUpdate(_cameraLat, _cameraLon);

      final controller = FogOverlayController(
        cellService: cellService,
        fogResolver: fogResolver,
        sampleStepPx: 80.0,
      );

      // Populate discovered cells via detection zone (viewport sampling removed).
      final currentCellId = cellService.getCellId(_cameraLat, _cameraLon);
      final zoneCells = {
        currentCellId,
        ...cellService.getNeighborIds(currentCellId),
      };
      controller.addDetectionZoneCells(zoneCells, const {});

      controller.update(
        cameraLat: _cameraLat,
        cameraLon: _cameraLon,
        zoom: _zoom,
        viewportSize: _viewport,
      );

      final features = _getFeatures(controller.baseFogGeoJson);
      expect(features.length, equals(1));

      final geometry = features[0]['geometry'] as Map<String, dynamic>;
      final coordinates = geometry['coordinates'] as List<dynamic>;
      // Should have more than just the exterior ring (holes for revealed cells).
      expect(coordinates.length, greaterThan(1),
          reason:
              'Holes should be punched for observed/hidden/concealed cells');
    });

    test('baseFogGeoJson hole coordinates are valid closed rings', () {
      final cellService = MockCellService();
      final fogResolver = FogStateResolver(cellService);
      fogResolver.onLocationUpdate(_cameraLat, _cameraLon);

      final controller = FogOverlayController(
        cellService: cellService,
        fogResolver: fogResolver,
        sampleStepPx: 80.0,
      );

      // Populate discovered cells via detection zone (viewport sampling removed).
      final currentCellId = cellService.getCellId(_cameraLat, _cameraLon);
      final zoneCells = {
        currentCellId,
        ...cellService.getNeighborIds(currentCellId),
      };
      controller.addDetectionZoneCells(zoneCells, const {});

      controller.update(
        cameraLat: _cameraLat,
        cameraLon: _cameraLon,
        zoom: _zoom,
        viewportSize: _viewport,
      );

      final features = _getFeatures(controller.baseFogGeoJson);
      final geometry = features[0]['geometry'] as Map<String, dynamic>;
      final coordinates = geometry['coordinates'] as List<dynamic>;

      // Skip the first ring (world exterior). Check all hole rings.
      for (var i = 1; i < coordinates.length; i++) {
        final ring = coordinates[i] as List<dynamic>;
        // GeoJSON rings must have at least 4 points (3 vertices + closing).
        expect(ring.length, greaterThanOrEqualTo(4),
            reason: 'Ring $i must have at least 4 points');

        // Ring must be closed (first == last).
        final first = ring.first as List<dynamic>;
        final last = ring.last as List<dynamic>;
        expect(first[0], equals(last[0]),
            reason: 'Ring $i longitude must close');
        expect(first[1], equals(last[1]),
            reason: 'Ring $i latitude must close');
      }
    });

    // -----------------------------------------------------------------------
    // update — mid fog GeoJSON (hidden/concealed cells)
    // -----------------------------------------------------------------------

    test('midFogGeoJson is empty when no cells are visited', () {
      final controller = _makeController();

      controller.update(
        cameraLat: _cameraLat,
        cameraLon: _cameraLon,
        zoom: _zoom,
        viewportSize: _viewport,
      );

      final features = _getFeatures(controller.midFogGeoJson);
      expect(features, isEmpty);
    });

    test('midFogGeoJson contains hidden/concealed cells after visiting', () {
      final cellService = MockCellService();
      final fogResolver = FogStateResolver(cellService);
      fogResolver.onLocationUpdate(_cameraLat, _cameraLon);

      final controller = FogOverlayController(
        cellService: cellService,
        fogResolver: fogResolver,
        sampleStepPx: 80.0,
      );

      // Populate discovered cells via detection zone (viewport sampling removed).
      final currentCellId = cellService.getCellId(_cameraLat, _cameraLon);
      final zoneCells = {
        currentCellId,
        ...cellService.getNeighborIds(currentCellId),
      };
      controller.addDetectionZoneCells(zoneCells, const {});

      // Use zoom=7 so the ±1° neighbor cells (1°×1° mock grid) fall within the
      // viewport bounding box (~±4.4° lat × ±2.2° lon at this zoom level).
      // At zoom 13 (the default _zoom), the viewport is only ~0.14° tall —
      // neighbors at ±1° would be filtered out by the viewport optimization.
      controller.update(
        cameraLat: _cameraLat,
        cameraLon: _cameraLon,
        zoom: 7.0,
        viewportSize: _viewport,
      );

      final features = _getFeatures(controller.midFogGeoJson);
      expect(features, isNotEmpty,
          reason: 'Neighbor cells should be hidden or concealed');

      // Each feature should have a density property.
      for (final feature in features) {
        final props = feature['properties'] as Map<String, dynamic>;
        final density = props['density'] as num;
        expect(density, isNotNull);
        // Density should be 0.95 (concealed) or 0.5 (hidden).
        expect(density, anyOf(equals(0.95), equals(0.5)));
      }
    });

    test('midFogGeoJson does not include observed cells', () {
      final cellService = MockCellService();
      final fogResolver = FogStateResolver(cellService);
      fogResolver.onLocationUpdate(_cameraLat, _cameraLon);

      final controller = FogOverlayController(
        cellService: cellService,
        fogResolver: fogResolver,
        sampleStepPx: 80.0,
      );

      controller.update(
        cameraLat: _cameraLat,
        cameraLon: _cameraLon,
        zoom: _zoom,
        viewportSize: _viewport,
      );

      final features = _getFeatures(controller.midFogGeoJson);
      for (final feature in features) {
        final props = feature['properties'] as Map<String, dynamic>;
        final density = props['density'] as num;
        // Observed density is 0.0 — should not be present.
        expect(density, isNot(equals(0.0)),
            reason: 'Observed cells should not appear in mid fog');
      }
    });

    // -----------------------------------------------------------------------
    // Repeated updates — stability
    // -----------------------------------------------------------------------

    test('repeated updates with same camera produce stable GeoJSON', () {
      final cellService = MockCellService();
      final fogResolver = FogStateResolver(cellService);
      fogResolver.onLocationUpdate(_cameraLat, _cameraLon);

      final controller = FogOverlayController(
        cellService: cellService,
        fogResolver: fogResolver,
        sampleStepPx: 80.0,
      );

      controller.update(
        cameraLat: _cameraLat,
        cameraLon: _cameraLon,
        zoom: _zoom,
        viewportSize: _viewport,
      );
      final firstBase = controller.baseFogGeoJson;
      final firstMid = controller.midFogGeoJson;

      controller.update(
        cameraLat: _cameraLat,
        cameraLon: _cameraLon,
        zoom: _zoom,
        viewportSize: _viewport,
      );
      final secondBase = controller.baseFogGeoJson;
      final secondMid = controller.midFogGeoJson;

      expect(secondBase, equals(firstBase));
      expect(secondMid, equals(firstMid));
    });

    // -----------------------------------------------------------------------
    // Different zoom levels
    // -----------------------------------------------------------------------

    test('lower zoom discovers more cells (wider viewport coverage)', () {
      final cellService = MockCellService();
      final fogResolver = FogStateResolver(cellService);

      // Visit many cells in all directions.
      for (var dlat = -5; dlat <= 5; dlat++) {
        for (var dlon = -5; dlon <= 5; dlon++) {
          fogResolver.onLocationUpdate(
            _cameraLat + dlat,
            _cameraLon + dlon,
          );
        }
      }

      final highZoomController = FogOverlayController(
        cellService: cellService,
        fogResolver: fogResolver,
        sampleStepPx: 80.0,
      );

      final lowZoomController = FogOverlayController(
        cellService: cellService,
        fogResolver: fogResolver,
        sampleStepPx: 80.0,
      );

      highZoomController.update(
        cameraLat: _cameraLat,
        cameraLon: _cameraLon,
        zoom: 16.0, // High zoom → small area
        viewportSize: _viewport,
      );

      lowZoomController.update(
        cameraLat: _cameraLat,
        cameraLon: _cameraLon,
        zoom: 10.0, // Low zoom → large area
        viewportSize: _viewport,
      );

      // Lower zoom should produce more holes in the base fog.
      final highZoomHoles = (_getFeatures(highZoomController.baseFogGeoJson)[0]
              ['geometry']['coordinates'] as List<dynamic>)
          .length;
      final lowZoomHoles = (_getFeatures(lowZoomController.baseFogGeoJson)[0]
              ['geometry']['coordinates'] as List<dynamic>)
          .length;

      expect(lowZoomHoles, greaterThanOrEqualTo(highZoomHoles));
    });

    // -----------------------------------------------------------------------
    // GeoJSON validity
    // -----------------------------------------------------------------------

    test('baseFogGeoJson is valid JSON after update', () {
      final controller = _makeController();

      controller.update(
        cameraLat: _cameraLat,
        cameraLon: _cameraLon,
        zoom: _zoom,
        viewportSize: _viewport,
      );

      // Should not throw.
      final parsed = _parseGeoJson(controller.baseFogGeoJson);
      expect(parsed['type'], equals('FeatureCollection'));
    });

    test('midFogGeoJson is valid JSON after update', () {
      final controller = _makeController();

      controller.update(
        cameraLat: _cameraLat,
        cameraLon: _cameraLon,
        zoom: _zoom,
        viewportSize: _viewport,
      );

      final parsed = _parseGeoJson(controller.midFogGeoJson);
      expect(parsed['type'], equals('FeatureCollection'));
    });
  });

  // -----------------------------------------------------------------------
  // addDetectionZoneCells pruning
  // -----------------------------------------------------------------------

  group('addDetectionZoneCells pruning', () {
    test('unvisited out-of-range cells are pruned when zone shifts', () {
      // Zone A: cells at lat=0 row, Zone B: cells at lat=10 row — no overlap.
      final cellService = MockCellService();
      final fogResolver = FogStateResolver(cellService);
      final controller = FogOverlayController(
        cellService: cellService,
        fogResolver: fogResolver,
        sampleStepPx: 80.0,
      );

      final zoneA = {'cell_0_0', 'cell_0_1', 'cell_0_2'};
      final zoneB = {'cell_10_10', 'cell_10_11', 'cell_10_12'};

      controller.addDetectionZoneCells(zoneA, const {});
      expect(controller.visibleCellCount, equals(3));

      controller.addDetectionZoneCells(zoneB, const {});
      // zoneA cells are unvisited and outside zoneB → should be pruned.
      expect(
        controller.visibleCellCount,
        equals(3),
        reason:
            'Only zone B cells should remain; zone A unvisited cells pruned',
      );
    });

    test('visited cells survive pruning even when outside the new zone', () {
      final cellService = MockCellService();
      final fogResolver = FogStateResolver(cellService);
      final controller = FogOverlayController(
        cellService: cellService,
        fogResolver: fogResolver,
        sampleStepPx: 80.0,
      );

      // Mark two zone-A cells as visited (center of cell_0_0 and cell_0_1).
      fogResolver.onLocationUpdate(0.5, 0.5); // visits cell_0_0
      fogResolver.onLocationUpdate(0.5, 1.5); // visits cell_0_1

      final zoneA = {'cell_0_0', 'cell_0_1', 'cell_0_2'};
      controller.addDetectionZoneCells(zoneA, const {});
      expect(controller.visibleCellCount, equals(3));

      // Zone B has no overlap with zone A.
      final zoneB = {'cell_10_10', 'cell_10_11', 'cell_10_12'};
      controller.addDetectionZoneCells(zoneB, const {});

      // cell_0_0 and cell_0_1 are visited → preserved.
      // cell_0_2 is unvisited and outside zoneB → pruned.
      // zoneB cells → 3 kept.
      expect(
        controller.visibleCellCount,
        equals(5),
        reason: '3 zone B cells + 2 visited zone A cells should survive',
      );
    });

    test('cells in both old and new zone are preserved', () {
      final cellService = MockCellService();
      final fogResolver = FogStateResolver(cellService);
      final controller = FogOverlayController(
        cellService: cellService,
        fogResolver: fogResolver,
        sampleStepPx: 80.0,
      );

      // Zone A: shared cell + a-only cell.
      final zoneA = {'cell_5_5', 'cell_5_6'};
      controller.addDetectionZoneCells(zoneA, const {});

      // Zone B: shared cell + b-only cell.
      final zoneB = {'cell_5_5', 'cell_5_7'};
      controller.addDetectionZoneCells(zoneB, const {});

      // cell_5_6 is not in zoneB and not visited → pruned.
      // cell_5_5 is in zoneB → kept.
      // cell_5_7 is in zoneB → kept.
      expect(
        controller.visibleCellCount,
        equals(2),
        reason: 'Only cells in new zone should remain when a-only is unvisited',
      );
    });
  });

  // -----------------------------------------------------------------------
  // viewport filtering
  // -----------------------------------------------------------------------

  group('viewport filtering', () {
    test('viewport filter reduces processed cell count for wide discovery zone',
        () {
      final cellService = MockCellService();
      final fogResolver = FogStateResolver(cellService);
      final controller = FogOverlayController(
        cellService: cellService,
        fogResolver: fogResolver,
        sampleStepPx: 80.0,
      );

      // Add cells spread across a wide area — most will be off-viewport at
      // high zoom. Camera at (37.5, -122.5) zoom=15 covers only ~0.01°.
      final wideCells = <String>{};
      for (var lat = 0; lat < 80; lat += 5) {
        for (var lon = -180; lon < 0; lon += 5) {
          wideCells.add('cell_${lat}_$lon');
        }
      }
      controller.addDetectionZoneCells(wideCells, const {});
      expect(controller.visibleCellCount, equals(wideCells.length));

      controller.update(
        cameraLat: 37.5,
        cameraLon: -122.5,
        zoom: 15.0,
        viewportSize: const Size(400, 800),
      );

      // Viewport cells should be a strict subset of all discovered cells.
      expect(
        controller.lastViewportCellCount,
        lessThan(controller.visibleCellCount),
        reason: 'High zoom should filter most cells off-viewport',
      );
    });

    test('off-viewport unvisited cells not included in borders GeoJSON', () {
      final cellService = MockCellService();
      final fogResolver = FogStateResolver(cellService);
      final controller = FogOverlayController(
        cellService: cellService,
        fogResolver: fogResolver,
        sampleStepPx: 80.0,
      );

      // Camera exactly at cell_37_-123's center (37.5, -122.5).
      // cell_37_-123: center (37.5, -122.5)  — in viewport at zoom 12.
      // cell_80_80:   center (80.5, 80.5)    — far off-viewport.
      const cameraLat = 37.5;
      const cameraLon = -122.5;
      const inViewport = 'cell_37_-123';
      const offViewport = 'cell_80_80';

      controller.addDetectionZoneCells({inViewport, offViewport}, const {});

      controller.update(
        cameraLat: cameraLat,
        cameraLon: cameraLon,
        zoom: 12.0,
        viewportSize: const Size(400, 800),
      );

      // Both cells are unknown → border at opacity 0.1.
      // Only in-viewport cell should appear (off-viewport filtered out).
      final features = _getFeatures(controller.cellBorderGeoJson);
      expect(
        features.length,
        equals(1),
        reason: 'Only viewport cell should appear in borders',
      );
    });
  });

  // -----------------------------------------------------------------------
  // _buildGeoJson property layer optimization
  // -----------------------------------------------------------------------

  group('_buildGeoJson property layer optimization', () {
    test('fog-only update does not dirty icons when visited count changes', () {
      final cellService = MockCellService();
      final fogResolver = FogStateResolver(cellService);
      final controller = FogOverlayController(
        cellService: cellService,
        fogResolver: fogResolver,
        sampleStepPx: 80.0,
      );

      // Populate detection zone cells.
      final currentCellId = cellService.getCellId(_cameraLat, _cameraLon);
      final zoneCells = {
        currentCellId,
        ...cellService.getNeighborIds(currentCellId),
      };
      controller.addDetectionZoneCells(zoneCells, const {});

      // Initial update — full build including properties.
      controller.update(
        cameraLat: _cameraLat,
        cameraLon: _cameraLon,
        zoom: _zoom,
        viewportSize: _viewport,
      );
      // Consume dirty flags to reset them.
      controller.consumeFogDirty();
      controller.consumeIconsDirty();
      controller.consumeHabitatDirty();

      // Simulate a fog-only change: player visits a cell (visited count changes)
      // but no new cells are discovered (cell count unchanged).
      fogResolver.onLocationUpdate(_cameraLat, _cameraLon);

      controller.update(
        cameraLat: _cameraLat,
        cameraLon: _cameraLon,
        zoom: _zoom,
        viewportSize: _viewport,
      );

      // Fog was rebuilt (visited count changed).
      expect(controller.consumeFogDirty(), isTrue,
          reason: 'Fog should be rebuilt when visited count changes');

      // Icons and habitat were NOT rebuilt (cell count unchanged = fog-only change).
      expect(controller.consumeIconsDirty(), isFalse,
          reason: 'Icons should not be rebuilt on fog-only changes');
      expect(controller.consumeHabitatDirty(), isFalse,
          reason: 'Habitat should not be rebuilt on fog-only changes');
    });

    test('cell count change rebuilds property layers', () {
      final cellService = MockCellService();
      final fogResolver = FogStateResolver(cellService);
      final controller = FogOverlayController(
        cellService: cellService,
        fogResolver: fogResolver,
        sampleStepPx: 80.0,
      );

      // Initial detection zone.
      final currentCellId = cellService.getCellId(_cameraLat, _cameraLon);
      final zoneCells = {
        currentCellId,
        ...cellService.getNeighborIds(currentCellId),
      };
      controller.addDetectionZoneCells(zoneCells, const {});

      // Initial update — full build.
      controller.update(
        cameraLat: _cameraLat,
        cameraLon: _cameraLon,
        zoom: _zoom,
        viewportSize: _viewport,
      );
      controller.consumeFogDirty();
      controller.consumeIconsDirty();
      controller.consumeHabitatDirty();

      // Add more cells (cell count changes).
      final newCellId = cellService.getCellId(_cameraLat + 2, _cameraLon + 2);
      final newZoneCells = {
        newCellId,
        ...cellService.getNeighborIds(newCellId)
      };
      controller.addDetectionZoneCells(newZoneCells, const {});

      controller.update(
        cameraLat: _cameraLat,
        cameraLon: _cameraLon,
        zoom: _zoom,
        viewportSize: _viewport,
      );

      // Both fog and property layers should be rebuilt.
      expect(controller.consumeFogDirty(), isTrue,
          reason: 'Fog should be rebuilt when cell count changes');
      expect(controller.consumeIconsDirty(), isTrue,
          reason: 'Icons should be rebuilt when cell count changes');
      expect(controller.consumeHabitatDirty(), isTrue,
          reason: 'Habitat should be rebuilt when cell count changes');
    });
  });

  // -------------------------------------------------------------------------
  // P3: Stationary fog skip — threshold constant and no-rebuild invariant
  // -------------------------------------------------------------------------

  group('P3 stationary fog skip', () {
    test('kFogMovementThreshold is approximately 1m in degrees (~0.00001°)',
        () {
      // 1 degree latitude ≈ 111 km → 0.00001° ≈ 1.11 m.
      // The threshold should be small enough to detect 1m movement but
      // large enough to ignore floating-point noise from GPS.
      expect(
        kFogMovementThreshold,
        greaterThanOrEqualTo(0.000005),
        reason: 'Too tight — sub-meter GPS noise would prevent fog updates',
      );
      expect(
        kFogMovementThreshold,
        lessThanOrEqualTo(0.0001),
        reason: 'Too loose — 10m movement would be ignored',
      );
    });

    test(
        'consumeFogDirty() stays false when update() called twice with identical params and no state changes',
        () {
      final controller = _makeController();

      // Prime the controller — first call always runs (no prior coords).
      controller.update(
        cameraLat: _cameraLat,
        cameraLon: _cameraLon,
        zoom: _zoom,
        viewportSize: _viewport,
      );
      controller.consumeFogDirty(); // drain

      // Second call — same coords, no state changes.
      controller.update(
        cameraLat: _cameraLat,
        cameraLon: _cameraLon,
        zoom: _zoom,
        viewportSize: _viewport,
      );

      expect(
        controller.consumeFogDirty(),
        isFalse,
        reason: 'Fog should NOT be marked dirty when nothing changed — '
            'stationary skip relies on this invariant',
      );
    });

    test(
        'consumeFogDirty() is true after update() when player moves beyond kFogMovementThreshold',
        () {
      final cellService = MockCellService();
      final fogResolver = FogStateResolver(cellService);
      final ctrl = FogOverlayController(
        cellService: cellService,
        fogResolver: fogResolver,
        sampleStepPx: 80.0,
      );

      // Seed detection zone to make a cell explorable.
      final cellId = cellService.getCellId(_cameraLat, _cameraLon);
      ctrl.addDetectionZoneCells({cellId}, {});

      // Prime at initial position.
      ctrl.update(
        cameraLat: _cameraLat,
        cameraLon: _cameraLon,
        zoom: _zoom,
        viewportSize: _viewport,
      );
      ctrl.consumeFogDirty(); // drain

      // Visit the cell (state change) then move > threshold.
      fogResolver.onLocationUpdate(_cameraLat, _cameraLon);
      final movedLat = _cameraLat + kFogMovementThreshold * 2;
      ctrl.update(
        cameraLat: movedLat,
        cameraLon: _cameraLon,
        zoom: _zoom,
        viewportSize: _viewport,
      );

      expect(
        ctrl.consumeFogDirty(),
        isTrue,
        reason: 'Fog should be rebuilt when player moved AND fog state changed',
      );
    });
  });
}
