import 'dart:math' as math;

import 'package:flutter/material.dart' hide Durations;
import 'package:fog_of_world/shared/design_tokens.dart';
import 'package:fog_of_world/shared/earth_nova_theme.dart';

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
            painter: _HealthRingPainter(
              percentage: clampedPct,
              trackColor: Theme.of(context).colorScheme.outlineVariant,
              arcStartColor: Theme.of(context).colorScheme.outlineVariant,
              arcEndColor: context.earthNova.successColor,
            ),
            child: Center(
              child: Text(
                pctLabel,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
        ),
        Spacing.gapSm,
        Text(
          message,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isThriving
                ? context.earthNova.successColor
                : Theme.of(context).colorScheme.onSurfaceVariant,
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
  final Color trackColor;
  final Color arcStartColor;
  final Color arcEndColor;

  _HealthRingPainter({
    required this.percentage,
    required this.trackColor,
    required this.arcStartColor,
    required this.arcEndColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 16) / 2; // 8px stroke → 8px inset each side
    const strokeWidth = 8.0;

    // Background track.
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;

    canvas.drawCircle(center, radius, trackPaint);

    if (percentage <= 0) return;

    // Progress arc — sweep from -90° (top) clockwise.
    final sweepAngle = 2 * math.pi * percentage;

    // Interpolated color: arcStartColor → arcEndColor.
    final arcColor = Color.lerp(arcStartColor, arcEndColor, percentage)!;

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
  bool shouldRepaint(_HealthRingPainter old) =>
      old.percentage != percentage ||
      old.trackColor != trackColor ||
      old.arcStartColor != arcStartColor ||
      old.arcEndColor != arcEndColor;
}
