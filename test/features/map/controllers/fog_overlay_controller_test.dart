import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:geobase/geobase.dart';
import 'package:fog_of_world/core/cells/cell_service.dart';
import 'package:fog_of_world/core/fog/fog_state_resolver.dart';
import 'package:fog_of_world/features/map/controllers/fog_overlay_controller.dart';
import 'package:fog_of_world/features/map/utils/fog_geojson_builder.dart';

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
          reason: 'Holes should be punched for observed/hidden/concealed cells');
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

      controller.update(
        cameraLat: _cameraLat,
        cameraLon: _cameraLon,
        zoom: _zoom,
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
        // Density should be 0.25 (concealed) or 0.5 (hidden).
        expect(density, anyOf(equals(0.25), equals(0.5)));
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

    test('restorationGeoJson is valid JSON after update', () {
      final controller = _makeController();

      controller.update(
        cameraLat: _cameraLat,
        cameraLon: _cameraLon,
        zoom: _zoom,
        viewportSize: _viewport,
      );

      final parsed = _parseGeoJson(controller.restorationGeoJson);
      expect(parsed['type'], equals('FeatureCollection'));
    });
  });
}
