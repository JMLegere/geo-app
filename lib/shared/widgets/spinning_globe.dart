import 'package:flutter/material.dart';

const _globeFrames = ['\u{1F30D}', '\u{1F30E}', '\u{1F30F}'];

/// Animated spinning globe — cycles through 🌍🌎🌏 emoji.
///
/// Supports an optional entrance animation (scale + fade in) via [animate].
/// When [animate] is true, the globe scales from 0→1 with elasticOut
/// and fades in over the first 1200ms.
class SpinningGlobe extends StatefulWidget {
  const SpinningGlobe({
    super.key,
    this.size = 64,
    this.animate = false,
    this.revolveDuration = const Duration(milliseconds: 1800),
  });

  /// Font size for the globe emoji.
  final double size;

  /// Whether to play an entrance animation (scale + fade in).
  final bool animate;

  /// Duration of one full globe revolution (cycles through 3 frames).
  final Duration revolveDuration;

  @override
  State<SpinningGlobe> createState() => _SpinningGlobeState();
}

class _SpinningGlobeState extends State<SpinningGlobe>
    with TickerProviderStateMixin {
  late final AnimationController _revolveCtrl;
  AnimationController? _entranceCtrl;
  Animation<double>? _scale;
  Animation<double>? _opacity;

  @override
  void initState() {
    super.initState();

    _revolveCtrl = AnimationController(
      vsync: this,
      duration: widget.revolveDuration,
    )..repeat();

    if (widget.animate) {
      _entranceCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      );

      _scale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _entranceCtrl!,
          curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
        ),
      );

      _opacity = CurvedAnimation(
        parent: _entranceCtrl!,
        curve: const Interval(0.0, 0.25, curve: Curves.easeIn),
      );

      _entranceCtrl!.forward();
    }
  }

  @override
  void dispose() {
    _revolveCtrl.dispose();
    _entranceCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget globe = AnimatedBuilder(
      animation: _revolveCtrl,
      builder: (_, __) {
        final frame = (_revolveCtrl.value * _globeFrames.length)
            .floor()
            .clamp(0, _globeFrames.length - 1);
        return Text(
          _globeFrames[frame],
          style: TextStyle(fontSize: widget.size),
        );
      },
    );

    if (widget.animate && _entranceCtrl != null) {
      globe = FadeTransition(
        opacity: _opacity!,
        child: ScaleTransition(
          scale: _scale!,
          child: globe,
        ),
      );
    }

    return globe;
  }
}
