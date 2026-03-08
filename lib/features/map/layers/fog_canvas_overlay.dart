import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'package:earth_nova/features/map/layers/fog_canvas_painter.dart';
import 'package:earth_nova/features/map/models/cell_render_data.dart';

/// Widget that renders the fog-of-war overlay using [FogCanvasPainter].
///
/// Wrapped in [RepaintBoundary] to isolate repaints from the parent widget tree,
/// and [IgnorePointer] to pass touch events through to the map below.
///
/// ## Usage
///
/// Increment [renderVersion] whenever [cells] changes to trigger a repaint.
/// The [FogCanvasPainter] uses the version for O(1) change detection.
///
/// Pass both the projection camera (`lastCamera*`) and the live camera
/// (`currentCamera*`) so the painter can apply a pixel offset correction
/// between full re-projections — keeping the fog pinned to the map.
///
/// ```dart
/// FogCanvasOverlay(
///   cells: controller.renderData,
///   renderVersion: controller.renderVersion,
///   lastCameraLat: controller.lastCameraLat,
///   lastCameraLon: controller.lastCameraLon,
///   lastZoom: controller.lastZoom,
///   currentCameraLat: _currentCameraLat,
///   currentCameraLon: _currentCameraLon,
///   currentZoom: _currentZoom,
///   viewportSize: MediaQuery.of(context).size,
/// )
/// ```
class FogCanvasOverlay extends StatelessWidget {
  /// The cell render data to paint. Updated by `FogOverlayController`.
  final List<CellRenderData> cells;

  /// Incremented by callers when `cells` changes, triggering a repaint.
  final int renderVersion;

  /// The fog fill color. Defaults to a dark blue-black at ~85% opacity.
  final Color fogColor;

  /// Blur sigma for soft cell boundaries. Defaults to 3.0.
  final double blurSigma;

  /// Optional per-cell restoration levels (0.0–1.0).
  ///
  /// Passed through to [FogCanvasPainter]. Observed cells whose key maps to a
  /// level > 0 receive a green tint overlay at up to 30% opacity.
  final Map<String, double>? restorationLevels;

  /// Camera position used during the last full cell projection.
  final double lastCameraLat;
  final double lastCameraLon;
  final double lastZoom;

  /// Live camera position — updated every frame during gestures/animations.
  final double currentCameraLat;
  final double currentCameraLon;
  final double currentZoom;

  /// Viewport dimensions for Mercator offset calculation.
  final ui.Size viewportSize;

  const FogCanvasOverlay({
    super.key,
    required this.cells,
    required this.renderVersion,
    this.fogColor = const Color(0xD9161620),
    this.blurSigma = 0.0,
    this.restorationLevels,
    this.lastCameraLat = 0,
    this.lastCameraLon = 0,
    this.lastZoom = 0,
    this.currentCameraLat = 0,
    this.currentCameraLon = 0,
    this.currentZoom = 0,
    this.viewportSize = ui.Size.zero,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: FogCanvasPainter(
            cells: cells,
            version: renderVersion,
            fogColor: fogColor,
            blurSigma: blurSigma,
            restorationLevels: restorationLevels,
            lastCameraLat: lastCameraLat,
            lastCameraLon: lastCameraLon,
            lastZoom: lastZoom,
            currentCameraLat: currentCameraLat,
            currentCameraLon: currentCameraLon,
            currentZoom: currentZoom,
            viewportSize: viewportSize,
          ),
          // Fill available space — sized by parent (typically Stack).
          size: Size.infinite,
        ),
      ),
    );
  }
}
