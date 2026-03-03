import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// [CustomPainter] that renders a dark fog overlay using the GLSL fragment
/// shader defined in `shaders/fog.frag`.
///
/// The shader draws a full-viewport dark overlay with a smooth circular
/// "clear" region centred on [playerScreenPosition].
class FogShaderPainter extends CustomPainter {
  /// The compiled fragment shader (from [ui.FragmentProgram.fragmentShader]).
  final ui.FragmentShader shader;

  /// Player position in screen-pixel coordinates.
  final Offset playerScreenPosition;

  /// Radius (in screen pixels) of the clear region around the player.
  final double revealRadius;

  /// Fog opacity multiplier: 0.0 = fully transparent, 1.0 = fully opaque.
  final double fogDensity;

  /// Current viewport size — used to detect size changes that require repaint.
  final Size viewportSize;

  /// Creates a [FogShaderPainter].
  FogShaderPainter({
    required this.shader,
    required this.playerScreenPosition,
    required this.viewportSize,
    this.revealRadius = 150.0,
    this.fogDensity = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Set uniforms in the order declared in fog.frag:
    // 0: uViewportWidth, 1: uViewportHeight,
    // 2: uPlayerScreenX, 3: uPlayerScreenY,
    // 4: uRevealRadius, 5: uFogDensity
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, playerScreenPosition.dx)
      ..setFloat(3, playerScreenPosition.dy)
      ..setFloat(4, revealRadius)
      ..setFloat(5, fogDensity);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(FogShaderPainter oldDelegate) =>
      oldDelegate.playerScreenPosition != playerScreenPosition ||
      oldDelegate.revealRadius != revealRadius ||
      oldDelegate.fogDensity != fogDensity ||
      oldDelegate.viewportSize != viewportSize;
}

// ---------------------------------------------------------------------------
// FogOverlayWidget
// ---------------------------------------------------------------------------

/// A full-size fog overlay that loads the GLSL shader from assets and renders
/// it via [FogShaderPainter].
///
/// Wrapped in [IgnorePointer] so that map gestures pass through unimpeded.
///
/// Usage:
/// ```dart
/// Stack(children: [
///   MapLibreMap(...),
///   FogOverlayWidget(
///     playerScreenPosition: Offset(200, 400),
///     revealRadius: 150,
///     fogDensity: 1.0,
///   ),
/// ])
/// ```
class FogOverlayWidget extends StatefulWidget {
  /// Player position in screen-pixel coordinates.
  final Offset playerScreenPosition;

  /// Radius (pixels) of the clear region around the player.
  final double revealRadius;

  /// Fog opacity multiplier: 0.0 = transparent, 1.0 = fully opaque.
  final double fogDensity;

  /// Creates a [FogOverlayWidget].
  const FogOverlayWidget({
    super.key,
    required this.playerScreenPosition,
    this.revealRadius = 150.0,
    this.fogDensity = 1.0,
  });

  @override
  State<FogOverlayWidget> createState() => _FogOverlayWidgetState();
}

class _FogOverlayWidgetState extends State<FogOverlayWidget> {
  ui.FragmentProgram? _program;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      final program =
          await ui.FragmentProgram.fromAsset('shaders/fog.frag');
      if (mounted) {
        setState(() => _program = program);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      // Show a debug banner in development; in production this would be hidden.
      return IgnorePointer(
        child: ColoredBox(
          color: Colors.red.withAlpha(77),
          child: Center(
            child: Text(
              'Shader load error: $_error',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      );
    }

    final program = _program;
    if (program == null) {
      // Still loading — render nothing so the map is visible.
      return const IgnorePointer(child: SizedBox.expand());
    }

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return CustomPaint(
            size: size,
            painter: FogShaderPainter(
              shader: program.fragmentShader(),
              playerScreenPosition: widget.playerScreenPosition,
              viewportSize: size,
              revealRadius: widget.revealRadius,
              fogDensity: widget.fogDensity,
            ),
          );
        },
      ),
    );
  }
}
