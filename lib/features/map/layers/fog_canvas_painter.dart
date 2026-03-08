import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'package:earth_nova/core/models/fog_state.dart';
import 'package:earth_nova/features/map/models/cell_render_data.dart';
import 'package:earth_nova/features/map/utils/mercator_projection.dart';

/// CustomPainter that renders the fog-of-war overlay using the
/// "dark overlay with punched holes" Canvas compositing technique.
///
/// ## Compositing technique
///
/// 1. `saveLayer` creates an offscreen buffer.
/// 2. The entire canvas is filled with `fogColor` (opaque dark overlay).
/// 3. Each revealed cell is drawn with `BlendMode.dstOut`, which punches a
///    transparent hole in the fog — revealing the map underneath.
/// 4. `restore` composites the offscreen buffer back onto the scene.
/// 5. Observed cells with a restoration level > 0 receive a semi-transparent
///    green tint drawn as a separate pass on top of the composited scene.
///
/// ## Performance
///
/// `shouldRepaint` uses `version` (an integer counter) rather than deep list
/// equality. Callers must increment `version` whenever `cells` changes.
class FogCanvasPainter extends CustomPainter {
  /// Cells to render. Only cells with fogState != `FogState.undetected` are
  /// drawn; undetected cells stay under the full fog fill.
  final List<CellRenderData> cells;

  /// Version counter for change detection in [shouldRepaint].
  /// Callers must increment this whenever [cells] changes to trigger a repaint.
  final int version;

  /// The fog fill color. Defaults to a dark blue-black at ~85% opacity.
  final Color fogColor;

  /// Blur sigma for soft cell boundary edges. Set to 0 for crisp edges.
  final double blurSigma;

  /// Optional per-cell restoration levels (0.0–1.0).
  ///
  /// When provided, observed cells whose `cellId` key maps to a level > 0
  /// receive a semi-transparent green overlay rendered after the fog composite
  /// pass. Green color is `Color(0xFF4CAF50)` with alpha = `level * 0.3`
  /// (max 30% opacity at full restoration).
  ///
  /// Non-observed cells are never tinted regardless of their level.
  /// Absent keys imply a level of 0.0 (no tint).
  final Map<String, double>? restorationLevels;

  // -- Camera offset compensation fields --
  // Cell screen vertices are projected against `lastCamera*`. Between full
  // re-projections the map camera moves, so we compute the pixel delta between
  // lastCamera and currentCamera, then `canvas.translate()` to keep fog pinned
  // to the map.

  /// The camera position that was used when [cells] screen vertices were last
  /// projected (output of `FogOverlayController.update()`).
  final double lastCameraLat;
  final double lastCameraLon;
  final double lastZoom;

  /// The LIVE camera position (updated every frame during gestures/animations).
  final double currentCameraLat;
  final double currentCameraLon;
  final double currentZoom;

  /// Viewport dimensions — needed for the Mercator offset calculation.
  final ui.Size viewportSize;

  const FogCanvasPainter({
    required this.cells,
    required this.version,
    this.fogColor = const Color(0xFF161620),
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
  void paint(Canvas canvas, Size size) {
    // Compute pixel offset to compensate for camera movement since last
    // full cell projection. For a pure pan, all screen positions shift by a
    // constant vector: geoToScreen(oldCamera, cameraAt=newCamera) − center.
    // One MercatorProjection call — microseconds.
    final correction = _cameraCorrection(size);

    // 1. saveLayer — begin offscreen compositing buffer.
    //    Expand the rect by the correction so translated content isn't clipped.
    final layerRect = Rect.fromLTWH(0, 0, size.width, size.height)
        .inflate(correction.distance + 1);
    canvas.saveLayer(layerRect, Paint());

    // Apply the translation so all cell polygons track the live camera.
    canvas.translate(correction.dx, correction.dy);

    // 2. Fill with fog color. The rect must cover the viewport AFTER the
    //    inverse translate (i.e., the original viewport bounds).
    canvas.drawRect(
      Rect.fromLTWH(-correction.dx, -correction.dy, size.width, size.height),
      Paint()..color = fogColor,
    );

    // 3. Punch transparent holes for revealed cells via dstOut blend mode.
    //    dstOut erases the destination (fog layer) wherever the source is drawn,
    //    making those pixels transparent and allowing the map to show through.
    final holePaint = Paint()..blendMode = BlendMode.dstOut;

    if (blurSigma > 0) {
      holePaint.maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);
    }

    for (final cell in cells) {
      // Undetected and unexplored cells remain fully black (no hole punched).
      if (cell.fogState == FogState.undetected ||
          cell.fogState == FogState.unexplored) {
        continue;
      }

      // revealStrength: 0.0 for fully fogged, 1.0 for fully observed.
      final revealStrength = 1.0 - cell.fogState.density;
      holePaint.color = Color.fromARGB(
        (revealStrength * 255).round(),
        255,
        255,
        255,
      );

      if (cell.screenVertices.length >= 3) {
        final path = Path()..addPolygon(cell.screenVertices, true);
        canvas.drawPath(path, holePaint);
      }
    }

    // 4. Restore — composite the offscreen buffer onto the scene.
    canvas.restore();

    // 5. Green restoration tint — separate pass after fog composite.
    //    Draws a semi-transparent green overlay on observed+restored cells.
    //    Only cells in FogState.observed are eligible: the fog is fully
    //    transparent there, so the tint appears on top of the visible map.
    final levels = restorationLevels;
    if (levels != null && levels.isNotEmpty) {
      // Apply same camera correction so green tint tracks the cells.
      canvas.save();
      canvas.translate(correction.dx, correction.dy);

      final greenPaint = Paint()..blendMode = BlendMode.srcOver;

      for (final cell in cells) {
        if (cell.fogState != FogState.observed) continue;

        final level = levels[cell.cellId];
        if (level == null || level <= 0.0) continue;
        if (cell.screenVertices.length < 3) continue;

        // Alpha scales linearly with restoration: max 30% opacity at level 1.0.
        final alpha = (level * 0.3 * 255).round();
        greenPaint.color = Color.fromARGB(alpha, 0x4C, 0xAF, 0x50);

        final path = Path()..addPolygon(cell.screenVertices, true);
        canvas.drawPath(path, greenPaint);
      }
      canvas.restore();
    }
  }

  /// Computes the pixel offset between the projection camera and the current
  /// live camera. For a pure pan (no zoom change), this is a constant vector
  /// that shifts all screen coordinates equally.
  Offset _cameraCorrection(Size size) {
    // If no projection has been done yet (lastZoom == 0), or if zoom changed
    // (which distorts non-linearly), skip the correction — a full re-projection
    // will run on the next throttle tick anyway.
    if (lastZoom == 0 || lastZoom != currentZoom) return Offset.zero;
    if (lastCameraLat == currentCameraLat &&
        lastCameraLon == currentCameraLon) {
      return Offset.zero;
    }

    // Where the old camera center appears on screen given the new camera.
    final oldCameraOnScreen = MercatorProjection.geoToScreen(
      lat: lastCameraLat,
      lon: lastCameraLon,
      cameraLat: currentCameraLat,
      cameraLon: currentCameraLon,
      zoom: currentZoom,
      viewportSize: viewportSize,
    );

    // The old camera used to be at viewport center; now it's at
    // oldCameraOnScreen. The difference is the correction to apply.
    final center = Offset(viewportSize.width / 2, viewportSize.height / 2);
    return oldCameraOnScreen - center;
  }

  /// Returns true if the painter needs to repaint.
  ///
  /// Uses [version] comparison for O(1) change detection instead of deep
  /// equality on [cells]. Callers must increment [version] on cell updates.
  /// [restorationLevels] uses reference equality — a new map object triggers
  /// a repaint, which aligns with the immutable Riverpod state pattern.
  @override
  bool shouldRepaint(covariant FogCanvasPainter old) =>
      old.version != version ||
      old.fogColor != fogColor ||
      old.blurSigma != blurSigma ||
      old.restorationLevels != restorationLevels ||
      old.currentCameraLat != currentCameraLat ||
      old.currentCameraLon != currentCameraLon ||
      old.currentZoom != currentZoom;
}
