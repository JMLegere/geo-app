import 'dart:ui';

import 'package:fog_of_world/core/cells/cell_service.dart';
import 'package:fog_of_world/core/fog/fog_state_resolver.dart';
import 'package:fog_of_world/core/models/fog_state.dart';
import 'package:fog_of_world/features/map/models/cell_render_data.dart';
import 'package:fog_of_world/features/map/utils/mercator_projection.dart';

/// Computes the list of `CellRenderData` for the current viewport.
///
/// On each `update` call, visible cells are discovered via grid sampling,
/// their fog states resolved, and their boundary polygons projected to screen
/// coordinates. The result is stored in `renderData` for `FogCanvasOverlay`.
///
/// ## Usage
///
/// Call `update` whenever the camera moves or fog state changes. The
/// `renderVersion` increments on every call so the overlay widget can use it
/// for O(1) repaint detection.
///
/// ```dart
/// controller.update(
///   cameraLat: lat, cameraLon: lon,
///   zoom: zoom, viewportSize: size,
/// );
/// overlay = FogCanvasOverlay(
///   cells: controller.renderData,
///   renderVersion: controller.renderVersion,
/// );
/// ```
class FogOverlayController {
  /// Cell geometry provider.
  final CellService cellService;

  /// Fog state computer.
  final FogStateResolver fogResolver;

  /// Sampling step in logical pixels. Lower = more samples, more CPU.
  final double sampleStepPx;

  int _renderVersion = 0;
  List<CellRenderData> _renderData = const [];

  /// Monotonically incremented on every `update` call.
  /// Use as a change token for `FogCanvasPainter.version`.
  int get renderVersion => _renderVersion;

  /// The most recent computed render data.
  /// Empty until `update` is first called.
  List<CellRenderData> get renderData => _renderData;

  FogOverlayController({
    required this.cellService,
    required this.fogResolver,
    this.sampleStepPx = 80.0,
  });

  /// Recomputes visible cells and their screen-projected polygons.
  ///
  /// Call on every camera move or when fog state changes. Designed for
  /// ~10–30 fps render loops with a 400×800 viewport (~50 sample points).
  ///
  /// 1. Discovers cells by grid-sampling the viewport + 20% padding.
  /// 2. Expands by one ring of neighbors to cover edge gaps.
  /// 3. Resolves fog state; skips [FogState.undetected] cells.
  /// 4. Projects cell boundary vertices to screen coordinates.
  /// 5. Increments [renderVersion].
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

    final newData = <CellRenderData>[];

    for (final cellId in visibleCellIds) {
      final fogState = fogResolver.resolve(cellId);
      // Undetected cells stay fully covered by the fog fill; skip them.
      if (fogState == FogState.undetected) continue;

      final boundary = cellService.getCellBoundary(cellId);
      final screenVertices = boundary
          .map(
            (geo) => MercatorProjection.geoToScreen(
              lat: geo.lat,
              lon: geo.lon,
              cameraLat: cameraLat,
              cameraLon: cameraLon,
              zoom: zoom,
              viewportSize: viewportSize,
            ),
          )
          .toList();

      newData.add(CellRenderData(
        cellId: cellId,
        fogState: fogState,
        screenVertices: screenVertices,
      ));
    }

    _renderData = newData;
    _renderVersion++;
  }

  /// Discovers cell IDs visible in the current viewport via grid sampling.
  ///
  /// Samples the viewport at [sampleStepPx] intervals (plus 20% padding for
  /// smooth scrolling), converts each screen point to geographic coordinates,
  /// and calls [CellService.getCellId]. After collecting sampled IDs, expands
  /// by one ring of neighbors to ensure full coverage at viewport edges.
  Set<String> _findVisibleCells({
    required double cameraLat,
    required double cameraLon,
    required double zoom,
    required Size viewportSize,
  }) {
    // Add 20% padding to viewport to prefetch cells just outside the screen.
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

    // Expand by one ring of neighbors to cover cells that straddle viewport
    // boundaries and would otherwise produce holes at the edges.
    final expanded = <String>{...sampled};
    for (final cellId in sampled) {
      expanded.addAll(cellService.getNeighborIds(cellId));
    }

    return expanded;
  }
}
