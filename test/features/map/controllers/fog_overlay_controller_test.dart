import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:geobase/geobase.dart';
import 'package:fog_of_world/core/cells/cell_service.dart';
import 'package:fog_of_world/core/fog/fog_state_resolver.dart';
import 'package:fog_of_world/core/models/fog_state.dart';
import 'package:fog_of_world/features/map/controllers/fog_overlay_controller.dart';

// ---------------------------------------------------------------------------
// MockCellService — simple 10×10 degree grid.
//
// Cell ID: "cell_{latBucket}_{lonBucket}" where bucket = floor(lat/10) etc.
// Each cell covers a 10°×10° area for easy testing.
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('FogOverlayController', () {
    // -------------------------------------------------------------------------
    // Initial state
    // -------------------------------------------------------------------------

    test('renderVersion starts at 0', () {
      final controller = _makeController();
      expect(controller.renderVersion, equals(0));
    });

    test('renderData is empty before first update', () {
      final controller = _makeController();
      expect(controller.renderData, isEmpty);
    });

    // -------------------------------------------------------------------------
    // update — version increment
    // -------------------------------------------------------------------------

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

    // -------------------------------------------------------------------------
    // update — undetected cells excluded
    // -------------------------------------------------------------------------

    test('undetected cells are excluded from renderData', () {
      final cellService = MockCellService();
      // No location update → all cells are undetected.
      final fogResolver = FogStateResolver(cellService);
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

      // With no visited cells, all resolved states are undetected.
      for (final cell in controller.renderData) {
        expect(cell.fogState, isNot(equals(FogState.undetected)));
      }
    });

    // -------------------------------------------------------------------------
    // update — visible cells produced after location update
    // -------------------------------------------------------------------------

    test('update produces CellRenderData for visible non-undetected cells', () {
      final cellService = MockCellService();
      final fogResolver = FogStateResolver(cellService);

      // Visit the camera location — that cell and neighbors become non-undetected.
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

      // At minimum the current cell (observed) should appear.
      expect(controller.renderData, isNotEmpty);

      for (final cell in controller.renderData) {
        expect(cell.fogState, isNot(equals(FogState.undetected)));
      }
    });

    test('current cell appears as observed in renderData', () {
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

      final currentCellId = fogResolver.currentCellId!;
      final observedCell = controller.renderData
          .where((c) => c.cellId == currentCellId)
          .firstOrNull;

      expect(observedCell, isNotNull);
      expect(observedCell!.fogState, equals(FogState.observed));
    });

    // -------------------------------------------------------------------------
    // update — screen vertices validity
    // -------------------------------------------------------------------------

    test('screen vertices are valid Offsets (finite, not NaN)', () {
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

      for (final cell in controller.renderData) {
        for (final vertex in cell.screenVertices) {
          expect(vertex.dx.isFinite, isTrue,
              reason: 'vertex.dx is finite for cell ${cell.cellId}');
          expect(vertex.dy.isFinite, isTrue,
              reason: 'vertex.dy is finite for cell ${cell.cellId}');
          expect(vertex.dx.isNaN, isFalse,
              reason: 'vertex.dx is not NaN for cell ${cell.cellId}');
          expect(vertex.dy.isNaN, isFalse,
              reason: 'vertex.dy is not NaN for cell ${cell.cellId}');
        }
      }
    });

    test('observed cell has at least 3 screen vertices', () {
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

      final currentCellId = fogResolver.currentCellId!;
      final observedCell = controller.renderData
          .where((c) => c.cellId == currentCellId)
          .firstOrNull;

      // Current cell must be in render data with a valid polygon.
      expect(observedCell, isNotNull);
      expect(observedCell!.screenVertices.length, greaterThanOrEqualTo(3));

      // All vertices must be finite and non-NaN (belt-and-suspenders with the
      // dedicated finite-values test, but explicit per the spec requirement).
      for (final v in observedCell.screenVertices) {
        expect(v.dx.isFinite && !v.dx.isNaN, isTrue,
            reason: 'vertex.dx must be finite');
        expect(v.dy.isFinite && !v.dy.isNaN, isTrue,
            reason: 'vertex.dy must be finite');
      }
    });

    // -------------------------------------------------------------------------
    // update — neighbor expansion
    // -------------------------------------------------------------------------

    test('renderData includes neighbor cells (unexplored) after location update', () {
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

      // Neighbors of the current cell should be concealed.
      final concealedCells = controller.renderData
          .where((c) => c.fogState == FogState.concealed)
          .toList();

      expect(concealedCells, isNotEmpty);
    });

    // -------------------------------------------------------------------------
    // Repeated updates
    // -------------------------------------------------------------------------

    test('repeated updates with same camera produce stable renderData length', () {
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
      final firstCount = controller.renderData.length;

      controller.update(
        cameraLat: _cameraLat,
        cameraLon: _cameraLon,
        zoom: _zoom,
        viewportSize: _viewport,
      );
      final secondCount = controller.renderData.length;

      expect(secondCount, equals(firstCount));
    });

    test('renderVersion increments even when renderData is empty', () {
      // No location updates → all cells undetected → empty renderData.
      final controller = _makeController();

      controller.update(
        cameraLat: _cameraLat,
        cameraLon: _cameraLon,
        zoom: _zoom,
        viewportSize: _viewport,
      );

      expect(controller.renderVersion, equals(1));
      expect(controller.renderData, isEmpty);
    });

    // -------------------------------------------------------------------------
    // Different zoom levels
    // -------------------------------------------------------------------------

    test('lower zoom produces more cells in renderData (wider viewport coverage)', () {
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

      expect(
        lowZoomController.renderData.length,
        greaterThanOrEqualTo(highZoomController.renderData.length),
      );
    });
  });
}
