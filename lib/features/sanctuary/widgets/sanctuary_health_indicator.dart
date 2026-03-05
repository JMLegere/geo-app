import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Circular progress ring showing overall sanctuary collection completeness.
///
/// - Gradient ring: gray (0%) → green (100%)
/// - Center: percentage text in bold 24px
/// - Below ring: contextual message ("growing" vs "thriving")
class SanctuaryHealthIndicator extends StatelessWidget {
  /// Completion fraction in [0.0, 1.0].
  final double percentage;

  const SanctuaryHealthIndicator({
    super.key,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    final clampedPct = percentage.clamp(0.0, 1.0);
    final isThriving = clampedPct >= 0.75;
    final pctLabel = '${(clampedPct * 100).round()}%';
    final message = isThriving
        ? 'Your sanctuary is thriving'
        : 'Your sanctuary is growing';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: CustomPaint(
            painter: _HealthRingPainter(percentage: clampedPct),
            child: Center(
              child: Text(
                pctLabel,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D3A2E),
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isThriving
                ? const Color(0xFF16A34A)
                : const Color(0xFF6B7280),
            letterSpacing: 0.1,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Custom ring painter
// ---------------------------------------------------------------------------

class _HealthRingPainter extends CustomPainter {
  final double percentage;

  _HealthRingPainter({required this.percentage});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 16) / 2; // 8px stroke → 8px inset each side
    const strokeWidth = 8.0;

    // Background track — light warm gray.
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE5E7EB);

    canvas.drawCircle(center, radius, trackPaint);

    if (percentage <= 0) return;

    // Progress arc — sweep from -90° (top) clockwise.
    final sweepAngle = 2 * math.pi * percentage;

    // Interpolated color: gray → green.
    final arcColor = Color.lerp(
      const Color(0xFFD1D5DB), // light gray
      const Color(0xFF22C55E), // vibrant green
      percentage,
    )!;

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = arcColor;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // start at top
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_HealthRingPainter old) => old.percentage != percentage;
}
