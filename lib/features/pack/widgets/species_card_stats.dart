import 'dart:math' as math;

import 'package:flutter/material.dart' hide Durations;

import 'package:earth_nova/shared/design_tokens.dart';

/// Three stat ring gauges (brawn/wit/speed) displayed horizontally.
///
/// Each ring is a small donut arc filled proportionally to stat/90.
/// Colors: Red (brawn), Blue (wit), Green (speed).
/// Numbers displayed to the right of each ring.
class SpeciesCardStats extends StatelessWidget {
  const SpeciesCardStats({
    required this.brawn,
    required this.wit,
    required this.speed,
    this.animate = true,
    super.key,
  });

  final int brawn;
  final int wit;
  final int speed;
  final bool animate;

  static const int _maxStat = 90;
  static const _brawnColor = Color(0xFFE53935);
  static const _witColor = Color(0xFF1E88E5);
  static const _speedColor = Color(0xFF43A047);

  @override
  Widget build(BuildContext context) {
    if (brawn == 0 && wit == 0 && speed == 0) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _StatRing(
          value: brawn,
          color: _brawnColor,
          label: '💪',
          animate: animate,
          delayMs: 0,
          maxStat: _maxStat,
        ),
        _StatRing(
          value: wit,
          color: _witColor,
          label: '🧠',
          animate: animate,
          delayMs: 80,
          maxStat: _maxStat,
        ),
        _StatRing(
          value: speed,
          color: _speedColor,
          label: '⚡',
          animate: animate,
          delayMs: 160,
          maxStat: _maxStat,
        ),
      ],
    );
  }
}

class _StatRing extends StatefulWidget {
  const _StatRing({
    required this.value,
    required this.color,
    required this.label,
    required this.animate,
    required this.delayMs,
    required this.maxStat,
  });

  final int value;
  final Color color;
  final String label;
  final bool animate;
  final int delayMs;
  final int maxStat;

  @override
  State<_StatRing> createState() => _StatRingState();
}

class _StatRingState extends State<_StatRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    if (widget.animate) {
      Future.delayed(Duration(milliseconds: 200 + widget.delayMs), () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const ringSize = 36.0;
    const strokeWidth = 4.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            return SizedBox(
              width: ringSize,
              height: ringSize,
              child: CustomPaint(
                painter: _RingPainter(
                  fraction: (widget.value / widget.maxStat).clamp(0.0, 1.0) *
                      _animation.value,
                  color: widget.color,
                  backgroundColor: cs.surfaceContainerHighest,
                  strokeWidth: strokeWidth,
                ),
              ),
            );
          },
        ),
        SizedBox(width: Spacing.xs),
        Text(
          '${widget.value}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: widget.color,
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.fraction,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  final double fraction;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = backgroundColor,
    );

    // Foreground arc
    if (fraction > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // start at top
        fraction * 2 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color;
}
