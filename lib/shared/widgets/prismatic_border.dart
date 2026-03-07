import 'dart:math' show pi;

import 'package:flutter/material.dart' hide Durations;

import 'package:fog_of_world/shared/design_tokens.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PrismaticBorder + FirstDiscoveryBadge
//
// Balatro-style animated rainbow border for first-discovery item instances.
//
// PrismaticBorder wraps any child and paints a slow-rotating HSV gradient
// stroke around it — think holographic trading card foil. The SweepGradient
// start angle advances every frame, making the full spectrum appear to rotate
// smoothly around the card edge.
//
// FirstDiscoveryBadge is the ★ badge for first-discovery items:
//   • compact  — tiny star chip for grid cards (top-left corner)
//   • pill     — inline "★ First" pill for detail sheet headers
// ═══════════════════════════════════════════════════════════════════════════════

// ── PrismaticBorder ──────────────────────────────────────────────────────────

/// Wraps [child] with a continuously-animating rainbow gradient border.
///
/// The border is a [SweepGradient] whose start angle advances each frame,
/// making the HSV spectrum appear to rotate slowly around the card edge.
/// The animation loops forever via [AnimationController.repeat].
///
/// A [RepaintBoundary] is placed around the child so the border's per-frame
/// repaint does not invalidate the child's rendering layer.
///
/// ## Usage
/// ```dart
/// PrismaticBorder(
///   borderRadius: Radii.lg,
///   borderWidth: 2.5,
///   child: MyCard(),
/// )
/// ```
class PrismaticBorder extends StatefulWidget {
  const PrismaticBorder({
    required this.child,
    this.borderRadius = Radii.lg,
    this.borderWidth = 2.5,
    super.key,
  });

  /// The widget to frame with the prismatic border.
  final Widget child;

  /// Corner radius — should match the child's own [BorderRadius].
  /// Defaults to [Radii.lg] (10 px), matching [ItemSlotWidget].
  final double borderRadius;

  /// Thickness of the rainbow stroke in logical pixels.
  final double borderWidth;

  @override
  State<PrismaticBorder> createState() => _PrismaticBorderState();
}

class _PrismaticBorderState extends State<PrismaticBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Durations.prismaticCycle,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder caches `child` so the subtree is not rebuilt each frame.
    // Only the CustomPaint foreground layer repaints.
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => CustomPaint(
        foregroundPainter: _PrismaticBorderPainter(
          animationValue: _controller.value,
          borderRadius: widget.borderRadius,
          borderWidth: widget.borderWidth,
        ),
        child: child,
      ),
      // RepaintBoundary isolates the child's layer from the per-frame repaint.
      child: RepaintBoundary(child: widget.child),
    );
  }
}

// ── Painter ──────────────────────────────────────────────────────────────────

class _PrismaticBorderPainter extends CustomPainter {
  const _PrismaticBorderPainter({
    required this.animationValue,
    required this.borderRadius,
    required this.borderWidth,
  });

  final double animationValue;
  final double borderRadius;
  final double borderWidth;

  // 13 stops → 12 segments + wrap: gives a smooth, seamless spectrum.
  static const int _hueStops = 13;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // Inset by half stroke width so the stroke stays within widget bounds.
    final halfStroke = borderWidth / 2;
    final paintRect = Rect.fromLTWH(
      halfStroke,
      halfStroke,
      size.width - borderWidth,
      size.height - borderWidth,
    );
    if (paintRect.width <= 0 || paintRect.height <= 0) return;

    // Build the rainbow color stops.
    // animationValue (0→1) drives the hue offset for the rotation effect.
    final hueOffset = animationValue * 360.0;
    final colors = List<Color>.generate(_hueStops, (i) {
      final hue = ((i / (_hueStops - 1)) * 360.0 + hueOffset) % 360.0;
      return HSVColor.fromAHSV(1.0, hue, 0.92, 1.0).toColor();
    });

    // Rotate the sweep's start angle: one full revolution per cycle.
    // Starting at –π/2 (top) means red begins at the top of the card.
    final sweepOffset = animationValue * 2 * pi;
    final gradient = SweepGradient(
      center: Alignment.center,
      startAngle: -pi / 2 + sweepOffset,
      endAngle: -pi / 2 + sweepOffset + 2 * pi,
      colors: colors,
    );

    // The shader rect must span the full widget so the gradient center and
    // angles map correctly onto the stroke path around the perimeter.
    final shaderRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(
      paintRect,
      Radius.circular(borderRadius),
    );

    // ── Glow pass ─────────────────────────────────────────────────────────
    // A wider, softly-blurred stroke gives the holographic shimmer effect.
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = gradient.createShader(shaderRect)
        ..strokeWidth = borderWidth * 2.5
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0),
    );

    // ── Crisp border ──────────────────────────────────────────────────────
    // The sharp stroke on top defines the card edge cleanly.
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = gradient.createShader(shaderRect)
        ..strokeWidth = borderWidth
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_PrismaticBorderPainter old) =>
      old.animationValue != animationValue ||
      old.borderRadius != borderRadius ||
      old.borderWidth != borderWidth;
}

// ── FirstDiscoveryBadge ──────────────────────────────────────────────────────

/// Size variants for [FirstDiscoveryBadge].
enum FirstDiscoveryBadgeSize {
  /// Tiny star chip — grid cards, top-left corner opposite the rarity badge.
  compact,

  /// Inline pill — detail sheet, next to the species name in the header.
  pill,
}

/// Gold ★ badge marking first-discovery item instances.
///
/// [FirstDiscoveryBadgeSize.compact] matches [RarityBadge.small] dimensions
/// and is intended to be positioned at the top-left corner of a grid card.
///
/// [FirstDiscoveryBadgeSize.pill] is an inline pill reading "★  First" for
/// use beside the species name in [ItemDetailSheet].
///
/// ## Usage
/// ```dart
/// // Grid card (positioned top-left)
/// const FirstDiscoveryBadge()
///
/// // Detail sheet (inline with species name)
/// const FirstDiscoveryBadge(size: FirstDiscoveryBadgeSize.pill)
/// ```
class FirstDiscoveryBadge extends StatelessWidget {
  const FirstDiscoveryBadge({
    this.size = FirstDiscoveryBadgeSize.compact,
    super.key,
  });

  final FirstDiscoveryBadgeSize size;

  // Material Amber 700 — vivid gold that reads well on both dark and light.
  static const Color _gold = Color(0xFFFFB300);

  // ~15 % alpha background (matches Opacities.badgeBackground pattern).
  static const Color _goldBg = Color(0x26FFB300);

  @override
  Widget build(BuildContext context) {
    final (label, padding, fontSize, radius) = switch (size) {
      FirstDiscoveryBadgeSize.compact => (
          '★',
          Spacing.paddingBadgeCompact, // (6, 2) — matches RarityBadge.small
          9.0,
          Radii.sm,
        ),
      FirstDiscoveryBadgeSize.pill => (
          '★  First',
          Spacing.paddingBadge, // (8, 2) — matches RarityBadge.medium
          10.0,
          Radii.md,
        ),
    };

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _goldBg,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: _gold,
          letterSpacing: 0.3,
          height: 1.0,
        ),
      ),
    );
  }
}
