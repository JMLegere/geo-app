import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Renders emoji strings to PNG [Uint8List] images for use with
/// MapLibre's `addImage()` API.
///
/// MapLibre GL only supports BMP characters (U+0000–U+FFFF) in its
/// native `text-field` property, silently dropping most emoji. This
/// renderer bypasses that limitation by painting emoji via Flutter's
/// [TextPainter] onto a [Canvas], then exporting as PNG bytes.
///
/// Usage:
/// ```dart
/// final bytes = await MapIconRenderer.renderEmoji('🌲', size: 64);
/// await controller.addImage('habitat-forest', bytes);
/// ```
abstract final class MapIconRenderer {
  /// Renders [emoji] text to a PNG [Uint8List] at the given pixel [size].
  ///
  /// The emoji is centered within a square canvas of [size]×[size] pixels.
  /// Returns raw PNG bytes suitable for `MapController.addImage()`.
  static Future<Uint8List> renderEmoji(String emoji, {double size = 64}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final painter = TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(fontSize: size * 0.8),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Center the emoji within the square canvas.
    final dx = (size - painter.width) / 2;
    final dy = (size - painter.height) / 2;
    painter.paint(canvas, Offset(dx, dy));

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    if (byteData == null) {
      throw StateError('Failed to render emoji "$emoji" to PNG');
    }

    return byteData.buffer.asUint8List();
  }

  /// Pre-defined icon IDs used by [CellPropertyGeoJsonBuilder] and
  /// registered in map_screen's `_initCellPropertyLayers()`.
  ///
  /// Format: `"habitat-{name}"`, `"climate-{name}"`, `"event-{name}"`,
  /// `"event-unknown"`.
  static String habitatIconId(String habitatName) => 'habitat-$habitatName';
  static String climateIconId(String climateName) => 'climate-$climateName';
  static String eventIconId(String eventTypeName) => 'event-$eventTypeName';
  static const String eventUnknownId = 'event-unknown';
}
