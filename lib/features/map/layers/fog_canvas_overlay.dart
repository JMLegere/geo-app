import 'package:flutter/widgets.dart';

import 'package:fog_of_world/features/map/layers/fog_canvas_painter.dart';
import 'package:fog_of_world/features/map/models/cell_render_data.dart';

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
/// ```dart
/// FogCanvasOverlay(
///   cells: controller.renderData,
///   renderVersion: controller.renderVersion,
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

  const FogCanvasOverlay({
    super.key,
    required this.cells,
    required this.renderVersion,
    this.fogColor = const Color(0xD9161620),
    this.blurSigma = 0.0,
    this.restorationLevels,
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
          ),
          // Fill available space — sized by parent (typically Stack).
          size: Size.infinite,
        ),
      ),
    );
  }
}
