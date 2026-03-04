import 'dart:math';
import 'dart:ui';

import 'package:fog_of_world/core/cells/cell_service.dart';
import 'package:fog_of_world/core/fog/fog_state_resolver.dart';
import 'package:fog_of_world/core/models/fog_state.dart';
import 'package:fog_of_world/features/map/models/cell_render_data.dart';
import 'package:fog_of_world/features/map/utils/fog_geojson_builder.dart';
import 'package:fog_of_world/features/map/utils/mercator_projection.dart';

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

  /// GeoJSON string for the unexplored cell border outlines.
  String _unexploredBorderGeoJson = FogGeoJsonBuilder.emptyFeatureCollection;

  /// GeoJSON string for the restoration overlay layer.
  final String _restorationGeoJson = FogGeoJsonBuilder.emptyFeatureCollection;

  /// Monotonically incremented on every `update` call.
  int get renderVersion => _renderVersion;

  /// Legacy render data — kept during transition.
  List<CellRenderData> get renderData => _renderData;

  /// GeoJSON for the opaque base fog (world polygon with holes).
  String get baseFogGeoJson => _baseFogGeoJson;

  /// GeoJSON for the semi-transparent mid fog (hidden/concealed cells).
  String get midFogGeoJson => _midFogGeoJson;

  /// GeoJSON for unexplored cell border outlines.
  String get unexploredBorderGeoJson => _unexploredBorderGeoJson;

  /// GeoJSON for the green restoration overlay.
  String get restorationGeoJson => _restorationGeoJson;

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

    _buildGeoJson(visibleCellIds);
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

    final accumulated = <String>{};

    for (var i = 0; i < visibleCellIds.length; i += chunkSize) {
      if (_asyncUpdateGeneration != myGeneration) return accumulated.length;

      final end = min(i + chunkSize, visibleCellIds.length);
      final chunk = visibleCellIds.sublist(i, end);
      accumulated.addAll(chunk);

      // Build GeoJSON from all accumulated cells so far.
      _buildGeoJson(accumulated);
      _renderVersion++;
      onBatchReady?.call();

      if (end < visibleCellIds.length) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    lastCameraLat = cameraLat;
    lastCameraLon = cameraLon;
    lastZoom = zoom;

    return accumulated.length;
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

    _unexploredBorderGeoJson = FogGeoJsonBuilder.buildUnexploredBorders(
      cellStates: cellStates,
      getBoundary: cellService.getCellBoundary,
    );

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
