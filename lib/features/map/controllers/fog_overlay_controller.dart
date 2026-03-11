import 'dart:math';
import 'dart:ui';

import 'package:earth_nova/core/cells/cell_service.dart';
import 'package:earth_nova/core/fog/fog_state_resolver.dart';
import 'package:earth_nova/core/models/cell_properties.dart';
import 'package:earth_nova/core/models/fog_state.dart';
import 'package:earth_nova/core/models/location_node.dart';
import 'package:earth_nova/features/map/models/cell_render_data.dart';
import 'package:earth_nova/features/map/utils/cell_property_geojson_builder.dart';
import 'package:earth_nova/features/map/utils/fog_geojson_builder.dart';
import 'package:earth_nova/features/map/utils/mercator_projection.dart';
import 'package:earth_nova/features/map/utils/territory_border_geojson_builder.dart';

/// Computes fog GeoJSON for MapLibre native fill layers.
///
/// On each [update] call, visible cells are discovered via grid sampling,
/// their fog states resolved, and GeoJSON strings built for 3 layers:
/// - [baseFogGeoJson]: opaque world polygon with holes for revealed cells
/// - [midFogGeoJson]: semi-transparent polygons for hidden/concealed cells
/// - [restorationGeoJson]: green tint for restored observed cells
///
/// ## Usage
///
/// Call `update` whenever the camera moves or fog state changes. The
/// `renderVersion` increments on every call so callers can detect changes.
///
/// ```dart
/// controller.update(cameraLat: lat, cameraLon: lon, zoom: zoom, viewportSize: size);
/// await mapController.updateGeoJsonSource(id: 'fog-base-src', data: controller.baseFogGeoJson);
/// ```
class FogOverlayController {
  /// Cell geometry provider.
  final CellService cellService;

  /// Fog state computer.
  final FogStateResolver fogResolver;

  /// Sampling step in logical pixels. Lower = more samples, more CPU.
  final double sampleStepPx;

  int _renderVersion = 0;

  /// Persistent set of all cell IDs ever discovered via viewport sampling.
  ///
  /// Once a cell is found, it stays in this set permanently. This eliminates
  /// the flickering caused by viewport sampling aliasing — at certain zoom
  /// levels, cells near the edge of the viewport can fall between sample
  /// points on one frame and be hit on the next, causing them to pop in/out
  /// of the GeoJSON. MapLibre clips off-screen polygons natively, so
  /// including out-of-viewport cells has negligible rendering cost.
  final Set<String> _discoveredCellIds = {};

  // -- Legacy fields kept for backward compatibility during transition --
  // TODO(cleanup): Remove once FogCanvasOverlay is fully deleted.
  List<CellRenderData> _renderData = const [];
  double lastCameraLat = 0;
  double lastCameraLon = 0;
  double lastZoom = 0;

  /// GeoJSON string for the base fog layer (world polygon with holes).
  String _baseFogGeoJson = FogGeoJsonBuilder.fullWorldFog;

  /// GeoJSON string for the mid fog layer (hidden/concealed cells).
  String _midFogGeoJson = FogGeoJsonBuilder.emptyFeatureCollection;

  /// GeoJSON string for the cell border outlines (unexplored + concealed).
  String _cellBorderGeoJson = FogGeoJsonBuilder.emptyFeatureCollection;

  /// GeoJSON string for the restoration overlay layer.
  final String _restorationGeoJson = FogGeoJsonBuilder.emptyFeatureCollection;

  /// GeoJSON string for cell property icon Point features.
  String _cellIconsGeoJson = CellPropertyGeoJsonBuilder.emptyFeatureCollection;

  /// Cell properties cache — set externally from GameCoordinator.
  Map<String, CellProperties> _cellPropertiesCache = const {};

  /// Location nodes cache — set externally when enrichment data is loaded.
  Map<String, LocationNode> _locationNodesCache = const {};

  /// GeoJSON string for territory border fill (gradient polygons).
  String _borderFillGeoJson =
      TerritoryBorderGeoJsonBuilder.emptyFeatureCollection;

  /// GeoJSON string for territory border lines (admin boundary edges).
  String _borderLinesGeoJson =
      TerritoryBorderGeoJsonBuilder.emptyFeatureCollection;

  /// Current daily seed for event resolution.
  String _dailySeed = '';

  /// Monotonically incremented on every `update` call.
  int get renderVersion => _renderVersion;

  /// Legacy render data — kept during transition.
  List<CellRenderData> get renderData => _renderData;

  /// GeoJSON for the opaque base fog (world polygon with holes).
  String get baseFogGeoJson => _baseFogGeoJson;

  /// GeoJSON for the semi-transparent mid fog (hidden/concealed cells).
  String get midFogGeoJson => _midFogGeoJson;

  /// GeoJSON for cell border outlines (unexplored + concealed).
  String get cellBorderGeoJson => _cellBorderGeoJson;

  /// GeoJSON for the green restoration overlay.
  String get restorationGeoJson => _restorationGeoJson;

  /// GeoJSON for cell property icon Points (habitat, climate, event icons).
  String get cellIconsGeoJson => _cellIconsGeoJson;

  /// GeoJSON for territory border gradient fill (Stellaris-style).
  String get borderFillGeoJson => _borderFillGeoJson;

  /// GeoJSON for territory border lines (admin boundary edges).
  String get borderLinesGeoJson => _borderLinesGeoJson;

  /// Updates the cell properties cache snapshot from GameCoordinator.
  set cellPropertiesCache(Map<String, CellProperties> cache) =>
      _cellPropertiesCache = cache;

  /// Updates the location nodes cache from the database.
  set locationNodesCache(Map<String, LocationNode> cache) =>
      _locationNodesCache = cache;

  /// Updates the daily seed used for event resolution.
  set dailySeed(String seed) => _dailySeed = seed;

  FogOverlayController({
    required this.cellService,
    required this.fogResolver,
    this.sampleStepPx = 25.0,
  });

  /// Recomputes visible cells and builds GeoJSON for all fog layers.
  ///
  /// Call on every camera move or when fog state changes. The viewport
  /// sampling discovers cells, resolves their fog states, then builds
  /// GeoJSON strings that MapLibre renders as native fill layers.
  void update({
    required double cameraLat,
    required double cameraLon,
    required double zoom,
    required Size viewportSize,
  }) {
    final visibleCellIds = _findVisibleCells(
      cameraLat: cameraLat,
      cameraLon: cameraLon,
      zoom: zoom,
      viewportSize: viewportSize,
    );

    // Accumulate — never remove cells from the discovered set.
    // This prevents flickering caused by viewport sampling aliasing.
    _discoveredCellIds.addAll(visibleCellIds);

    _buildGeoJson(_discoveredCellIds);
    _renderVersion++;

    lastCameraLat = cameraLat;
    lastCameraLon = cameraLon;
    lastZoom = zoom;
  }

  /// Non-blocking version of [update] for initial map load.
  ///
  /// Processes visible cells in batches, yielding to the event loop between
  /// each chunk. The [onBatchReady] callback fires after each batch.
  Future<int> updateAsync({
    required double cameraLat,
    required double cameraLon,
    required double zoom,
    required Size viewportSize,
    void Function()? onBatchReady,
    int chunkSize = 20,
  }) async {
    _asyncUpdateGeneration++;
    final myGeneration = _asyncUpdateGeneration;

    final visibleCellIds = _findVisibleCells(
      cameraLat: cameraLat,
      cameraLon: cameraLon,
      zoom: zoom,
      viewportSize: viewportSize,
    ).toList();

    var addedCount = 0;

    for (var i = 0; i < visibleCellIds.length; i += chunkSize) {
      if (_asyncUpdateGeneration != myGeneration) return addedCount;

      final end = min(i + chunkSize, visibleCellIds.length);
      final chunk = visibleCellIds.sublist(i, end);
      // Accumulate into the persistent set — never remove.
      _discoveredCellIds.addAll(chunk);
      addedCount += chunk.length;

      // Build GeoJSON from all discovered cells so far.
      _buildGeoJson(_discoveredCellIds);
      _renderVersion++;
      onBatchReady?.call();

      if (end < visibleCellIds.length) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    lastCameraLat = cameraLat;
    lastCameraLon = cameraLon;
    lastZoom = zoom;

    return addedCount;
  }

  int _asyncUpdateGeneration = 0;

  /// Builds all 3 GeoJSON strings from the given set of visible cell IDs.
  void _buildGeoJson(Iterable<String> cellIds) {
    final cellStates = <String, FogState>{};
    for (final cellId in cellIds) {
      final state = fogResolver.resolve(cellId);
      if (state == FogState.undetected) continue;
      cellStates[cellId] = state;
    }

    _baseFogGeoJson = FogGeoJsonBuilder.buildBaseFog(
      cellStates: cellStates,
      getBoundary: cellService.getCellBoundary,
    );

    _midFogGeoJson = FogGeoJsonBuilder.buildMidFog(
      cellStates: cellStates,
      getBoundary: cellService.getCellBoundary,
    );

    _cellBorderGeoJson = FogGeoJsonBuilder.buildCellBorders(
      cellStates: cellStates,
      getBoundary: cellService.getCellBoundary,
    );

    // Build cell property icons (habitat, climate, event).
    if (_cellPropertiesCache.isNotEmpty && _dailySeed.isNotEmpty) {
      _cellIconsGeoJson = CellPropertyGeoJsonBuilder.buildCellIcons(
        cellStates: cellStates,
        cellProperties: _cellPropertiesCache,
        currentCellId: fogResolver.currentCellId,
        adjacentCellIds: fogResolver.currentNeighborIds,
        visitedCellIds: fogResolver.visitedCellIds,
        dailySeed: _dailySeed,
        getCellCenter: cellService.getCellCenter,
      );
    } else {
      _cellIconsGeoJson = CellPropertyGeoJsonBuilder.emptyFeatureCollection;
    }

    // Build territory border overlays.
    if (_locationNodesCache.isNotEmpty && _cellPropertiesCache.isNotEmpty) {
      _borderFillGeoJson = TerritoryBorderGeoJsonBuilder.buildBorderFill(
        cellProperties: _cellPropertiesCache,
        locationNodes: _locationNodesCache,
        visibleCellIds: cellStates.keys.toSet(),
        getNeighborIds: cellService.getNeighborIds,
        getBoundary: cellService.getCellBoundary,
      );
      _borderLinesGeoJson = TerritoryBorderGeoJsonBuilder.buildBorderLines(
        cellProperties: _cellPropertiesCache,
        locationNodes: _locationNodesCache,
        visibleCellIds: cellStates.keys.toSet(),
        getNeighborIds: cellService.getNeighborIds,
        getBoundary: cellService.getCellBoundary,
      );
    } else {
      _borderFillGeoJson = TerritoryBorderGeoJsonBuilder.emptyFeatureCollection;
      _borderLinesGeoJson =
          TerritoryBorderGeoJsonBuilder.emptyFeatureCollection;
    }

    // Keep legacy renderData empty — no longer needed for Canvas painting.
    _renderData = const [];
  }

  /// Discovers cell IDs visible in the current viewport via grid sampling.
  Set<String> _findVisibleCells({
    required double cameraLat,
    required double cameraLon,
    required double zoom,
    required Size viewportSize,
  }) {
    final padX = viewportSize.width * 0.2;
    final padY = viewportSize.height * 0.2;

    final sampled = <String>{};

    var y = -padY;
    while (y <= viewportSize.height + padY) {
      var x = -padX;
      while (x <= viewportSize.width + padX) {
        final geo = MercatorProjection.screenToGeo(
          screenPoint: Offset(x, y),
          cameraLat: cameraLat,
          cameraLon: cameraLon,
          zoom: zoom,
          viewportSize: viewportSize,
        );
        final cellId = cellService.getCellId(geo.lat, geo.lon);
        sampled.add(cellId);
        x += sampleStepPx;
      }
      y += sampleStepPx;
    }

    final expanded = <String>{...sampled};
    for (final cellId in sampled) {
      expanded.addAll(cellService.getNeighborIds(cellId));
    }

    return expanded;
  }
}
