// ignore_for_file: avoid_print
/// Generates the Fog of World app icon (1024×1024 PNG).
///
/// Design: dark-navy background, teal annular ring (revealed-fog aesthetic),
/// compass crosshair in light-teal, bright-cyan center dot.
/// Recognisable at every launcher size down to 48 × 48 dp.
///
/// Run with:
///   dart run tool/generate_icon.dart
library;

import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  const size = 1024;
  final cx = size ~/ 2;
  final cy = size ~/ 2;

  // ── Canvas ────────────────────────────────────────────────────────────────
  final image = img.Image(width: size, height: size);

  // 1. Dark-navy fill  (#0D1B2A)
  img.fill(image, color: img.ColorRgb8(13, 27, 42));

  // ── Radial glow: concentric circles from dim outer to bright teal ─────────
  // Painting from outside → in so each circle overwrites the previous ring.
  final glowSteps = [
    (size * 46 ~/ 100, img.ColorRgb8(5,  55,  70)),
    (size * 44 ~/ 100, img.ColorRgb8(0,  80,  96)),
    (size * 42 ~/ 100, img.ColorRgb8(0, 100, 116)),
    (size * 40 ~/ 100, img.ColorRgb8(0, 121, 140)),
    (size * 38 ~/ 100, img.ColorRgb8(0, 141, 160)),
    (size * 36 ~/ 100, img.ColorRgb8(0, 151, 167)),  // outer ring edge
    (size * 33 ~/ 100, img.ColorRgb8(0, 131, 143)),  // ring body
  ];

  for (final (radius, color) in glowSteps) {
    img.fillCircle(image, x: cx, y: cy, radius: radius, color: color);
  }

  // ── Inner dark "fog" circle  (#0D1B2A → slightly lighter centre) ─────────
  img.fillCircle(image, x: cx, y: cy,
      radius: size * 28 ~/ 100, color: img.ColorRgb8(13, 27, 42));
  img.fillCircle(image, x: cx, y: cy,
      radius: size * 22 ~/ 100, color: img.ColorRgb8(17, 34, 52));

  // ── Compass crosshair ─────────────────────────────────────────────────────
  // Light-teal (#B2EBF2), ~2.8 % of canvas width, full span
  final armColor = img.ColorRgb8(178, 235, 242);
  final thickness = size * 28 ~/ 1000; // ≈ 28 px

  // Vertical arm (N ↕ S)
  img.drawLine(image,
      x1: cx, y1: 0, x2: cx, y2: size - 1,
      color: armColor, thickness: thickness);

  // Horizontal arm (W ↔ E)
  img.drawLine(image,
      x1: 0, y1: cy, x2: size - 1, y2: cy,
      color: armColor, thickness: thickness);

  // ── Centre dot  (bright-cyan glow + white core) ───────────────────────────
  img.fillCircle(image, x: cx, y: cy,
      radius: size * 38 ~/ 1000, // ≈ 39 px — cyan glow
      color: img.ColorRgb8(0, 229, 255));
  img.fillCircle(image, x: cx, y: cy,
      radius: size * 18 ~/ 1000, // ≈ 18 px — white core
      color: img.ColorRgb8(255, 255, 255));

  // ── Save ──────────────────────────────────────────────────────────────────
  final outDir = Directory('assets/icon');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);

  final bytes = img.encodePng(image);
  File('assets/icon/app_icon.png').writeAsBytesSync(bytes);

  final kb = (bytes.length / 1024).toStringAsFixed(1);
  print('✓ assets/icon/app_icon.png  — $size×$size px, ${kb}KB');
}
