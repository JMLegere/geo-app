import 'package:flutter/rendering.dart';

import 'package:fog_of_world/core/models/fog_state.dart';
import 'package:fog_of_world/features/map/models/cell_render_data.dart';

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

  const FogCanvasPainter({
    required this.cells,
    required this.version,
    this.fogColor = const Color(0xD9161620),
    this.blurSigma = 0.0,
    this.restorationLevels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. saveLayer — begin offscreen compositing buffer.
    //    All subsequent draws are isolated until restore() is called.
    canvas.saveLayer(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint(),
    );

    // 2. Fill the entire canvas with fog color (the dark overlay).
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
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
      if (cell.fogState == FogState.undetected) continue;

      // revealStrength: 0.0 for fully undetected, 1.0 for fully observed.
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
    }
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
      old.restorationLevels != restorationLevels;
}
