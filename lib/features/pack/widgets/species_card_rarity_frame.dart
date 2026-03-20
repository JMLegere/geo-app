import 'dart:math' as math;

import 'package:flutter/material.dart' hide Durations;

import 'package:earth_nova/core/models/iucn_status.dart';
import 'package:earth_nova/shared/widgets/prismatic_border.dart';

/// Wraps a [child] card with a rarity-appropriate border frame.
///
/// | Rarity | Frame Treatment |
/// |--------|----------------|
/// | LC | 2px solid neutral border |
/// | NT | 2.5px green border + subtle inner glow |
/// | VU | 3px double border (outer blue, inner lighter blue) |
/// | EN | 3px gold gradient edge + outer glow |
/// | CR | 3.5px animated holographic shimmer (diagonal sweep, 4s) |
/// | EX | PrismaticBorder (animated rainbow) + floating particles |
class SpeciesCardRarityFrame extends StatelessWidget {
  const SpeciesCardRarityFrame({
    required this.rarity,
    required this.child,
    this.borderRadius = 12.0,
    super.key,
  });

  final IucnStatus? rarity;
  final Widget child;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    if (rarity == null) return child;

    return switch (rarity!) {
      IucnStatus.leastConcern => _buildNeutralBorder(context),
      IucnStatus.nearThreatened => _buildNTBorder(context),
      IucnStatus.vulnerable => _buildVUBorder(context),
      IucnStatus.endangered => _buildENBorder(context),
      IucnStatus.criticallyEndangered =>
        _HolographicFrame(borderRadius: borderRadius, child: child),
      IucnStatus.extinct => PrismaticBorder(
          borderRadius: borderRadius,
          borderWidth: 4,
          child: child,
        ),
    };
  }

  Widget _buildNeutralBorder(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: cs.outline.withValues(alpha: 0.4),
          width: 2,
        ),
      ),
      child: child,
    );
  }

  Widget _buildNTBorder(BuildContext context) {
    const green = Color(0xFF4CAF50);
    const greenGlow = Color(0xFF81C784);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: green, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: greenGlow.withValues(alpha: 0.25),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildVUBorder(BuildContext context) {
    const outer = Color(0xFF1565C0); // blue
    const inner = Color(0xFF64B5F6); // lighter blue
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: outer, width: 3),
        boxShadow: [
          BoxShadow(
            color: outer.withValues(alpha: 0.3),
            blurRadius: 6,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: inner.withValues(alpha: 0.15),
            blurRadius: 3,
            spreadRadius: 1,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius - 2),
          border: Border.all(color: inner.withValues(alpha: 0.6), width: 1),
        ),
        child: child,
      ),
    );
  }

  Widget _buildENBorder(BuildContext context) {
    const gold = Color(0xFFFFD700);
    const goldDark = Color(0xFFB8860B);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            gold,
            goldDark,
            gold,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: gold.withValues(alpha: 0.5),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.all(1.5),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius - 1.5),
          color: const Color(0xFF1A1A2E), // dark card surface
        ),
        child: child,
      ),
    );
  }
}

/// Animated holographic shimmer border for CR rarity.
class _HolographicFrame extends StatefulWidget {
  const _HolographicFrame({
    required this.child,
    this.borderRadius = 12.0,
  });

  final Widget child;
  final double borderRadius;

  @override
  State<_HolographicFrame> createState() => _HolographicFrameState();
}

class _HolographicFrameState extends State<_HolographicFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _HolographicPainter(
            animationValue: _controller.value,
            borderRadius: widget.borderRadius,
            borderWidth: 3.5,
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// Diagonal holographic sweep painter for CR border.
class _HolographicPainter extends CustomPainter {
  const _HolographicPainter({
    required this.animationValue,
    required this.borderRadius,
    required this.borderWidth,
  });

  final double animationValue;
  final double borderRadius;
  final double borderWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final halfStroke = borderWidth / 2;
    final paintRect = Rect.fromLTWH(
      halfStroke,
      halfStroke,
      size.width - borderWidth,
      size.height - borderWidth,
    );
    final rrect = RRect.fromRectAndRadius(
      paintRect,
      Radius.circular(borderRadius),
    );

    // Diagonal gradient sweep — sweep angle driven by animationValue
    // Build holographic colors (silvers, purples, cyans)
    final colors = [
      const Color(0xFFE0E0FF),
      const Color(0xFFB388FF),
      const Color(0xFF80DEEA),
      const Color(0xFFCE93D8),
      const Color(0xFFE0E0FF),
    ];

    final sweepOffset = animationValue * 2 * math.pi;

    // Glow pass
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = SweepGradient(
          center: Alignment.center,
          startAngle: sweepOffset,
          endAngle: sweepOffset + 2 * math.pi,
          colors: colors,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..strokeWidth = borderWidth * 2
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Crisp border
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = SweepGradient(
          center: Alignment.center,
          startAngle: sweepOffset,
          endAngle: sweepOffset + 2 * math.pi,
          colors: colors,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..strokeWidth = borderWidth
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_HolographicPainter old) =>
      old.animationValue != animationValue;
}
