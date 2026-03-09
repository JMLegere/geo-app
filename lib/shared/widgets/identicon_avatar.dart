import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

/// GitHub-style identicon avatar generated deterministically from a string seed.
///
/// Renders a 5x5 grid with left-right mirror symmetry, using a SHA-256 hash
/// of [seed] to determine which cells are filled. The foreground color is also
/// derived from the hash, with saturation/lightness tuned for the current theme.
///
/// ```dart
/// IdenticonAvatar(
///   seed: user.id,
///   size: 32,
/// )
/// ```
class IdenticonAvatar extends StatelessWidget {
  const IdenticonAvatar({
    super.key,
    required this.seed,
    this.size = 32,
  });

  /// The string used to generate the identicon pattern and color.
  /// Typically a user ID or phone hash.
  final String seed;

  /// Diameter of the circular avatar in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? colors.surfaceContainerHigh
            : colors.surfaceContainerHighest,
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        size: Size.square(size),
        painter: _IdenticonPainter(
          seed: seed,
          isDark: isDark,
          backgroundColor: isDark
              ? colors.surfaceContainerHigh
              : colors.surfaceContainerHighest,
        ),
      ),
    );
  }
}

/// Paints a 5x5 mirrored pixel grid inside a circle.
///
/// The pattern is symmetric about the vertical axis:
/// columns 0,1,2 are independent; column 3 mirrors column 1; column 4 mirrors
/// column 0. This gives 15 independent bits (5 rows x 3 columns), extracted
/// from bytes 1–15 of the SHA-256 hash. Byte 0 determines hue.
class _IdenticonPainter extends CustomPainter {
  _IdenticonPainter({
    required this.seed,
    required this.isDark,
    required this.backgroundColor,
  });

  final String seed;
  final bool isDark;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final hashBytes = sha256.convert(utf8.encode(seed)).bytes;

    // Derive foreground color from first byte (hue 0–360).
    final hue = (hashBytes[0] / 255.0) * 360.0;
    final fg = HSLColor.fromAHSL(
      1.0,
      hue,
      isDark ? 0.55 : 0.50,
      isDark ? 0.60 : 0.45,
    ).toColor();

    final cellW = size.width / 5;
    final cellH = size.height / 5;

    final paint = Paint()..color = fg;

    // 5 rows x 3 independent columns = 15 bits.
    // We use bytes 1..15 (odd/even) to decide fill.
    for (int row = 0; row < 5; row++) {
      for (int col = 0; col < 3; col++) {
        final byteIndex = 1 + row * 3 + col;
        final filled = hashBytes[byteIndex] % 2 == 0;
        if (!filled) continue;

        // Draw left side.
        canvas.drawRect(
          Rect.fromLTWH(col * cellW, row * cellH, cellW, cellH),
          paint,
        );

        // Mirror to right side (col 0 → 4, col 1 → 3, col 2 stays center).
        if (col < 2) {
          final mirrorCol = 4 - col;
          canvas.drawRect(
            Rect.fromLTWH(mirrorCol * cellW, row * cellH, cellW, cellH),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_IdenticonPainter oldDelegate) =>
      seed != oldDelegate.seed || isDark != oldDelegate.isDark;
}
