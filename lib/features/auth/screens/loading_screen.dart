import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:earth_nova/shared/design_tokens.dart';

/// Animated splash screen shown while game data loads. No Riverpod.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  late final AnimationController _globeCtrl;
  late final AnimationController _orbitalCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _globeFade;
  late final Animation<double> _titleFade;
  late final Animation<double> _subtitleFade;
  late final Animation<double> _entranceScale;
  late final Animation<double> _globeRotation;
  late final Animation<double> _orbitalAngle;
  late final Animation<double> _glowPulse;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _globeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 32),
    )..repeat();
    _orbitalCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    // Staggered entrance: globe → title → subtitle
    _globeFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.55, curve: AppCurves.fadeIn),
    );
    _titleFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.18, 0.72, curve: AppCurves.fadeIn),
    );
    _subtitleFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.42, 1.0, curve: AppCurves.fadeIn),
    );
    _entranceScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: AppCurves.standard),
    );
    _globeRotation =
        Tween<double>(begin: 0, end: math.pi * 2).animate(_globeCtrl);
    _orbitalAngle =
        Tween<double>(begin: 0, end: math.pi * 2).animate(_orbitalCtrl);
    _glowPulse = Tween<double>(begin: 0.48, end: 0.88).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: AppCurves.standard),
    );
    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _globeCtrl.dispose();
    _orbitalCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _globeFade,
              child: ScaleTransition(
                scale: _entranceScale,
                child: AnimatedBuilder(
                  animation: Listenable.merge(
                    [_globeCtrl, _orbitalCtrl, _pulseCtrl],
                  ),
                  builder: (_, __) => SizedBox(
                    width: 180,
                    height: 180,
                    child: CustomPaint(
                      painter: _GlobePainter(
                        rotation: _globeRotation.value,
                        glowPulse: _glowPulse.value,
                        orbitalAngle: _orbitalAngle.value,
                        primaryColor: cs.primary,
                        tertiaryColor: cs.tertiary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Spacing.xxxl),
            FadeTransition(
              opacity: _titleFade,
              child: Text(
                'EarthNova',
                style: tt.headlineLarge?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            FadeTransition(
              opacity: _subtitleFade,
              child: Text(
                'Loading your world\u2026',
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Painted globe: glow → ocean → landmasses (rotating) →
// atmosphere rim → specular highlight → orbital comet ring.
class _GlobePainter extends CustomPainter {
  _GlobePainter({
    required this.rotation,
    required this.glowPulse,
    required this.orbitalAngle,
    required this.primaryColor,
    required this.tertiaryColor,
  });

  final double rotation;
  final double glowPulse;
  final double orbitalAngle;
  final Color primaryColor;
  final Color tertiaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.375;
    _paintGlow(canvas, c, r);
    _paintOcean(canvas, c, r);
    _paintLandmasses(canvas, c, r);
    _paintAtmosphere(canvas, c, r);
    _paintSpecular(canvas, c, r);
    _paintOrbital(canvas, c, r);
  }

  void _paintGlow(Canvas canvas, Offset c, double r) {
    final gr = r * 1.52;
    canvas.drawCircle(
        c,
        gr,
        Paint()
          ..shader = RadialGradient(colors: [
            primaryColor.withValues(alpha: glowPulse * 0.22),
            primaryColor.withValues(alpha: glowPulse * 0.06),
            primaryColor.withValues(alpha: 0),
          ], stops: const [
            0.0,
            0.50,
            1.0
          ]).createShader(Rect.fromCircle(center: c, radius: gr)));
  }

  void _paintOcean(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r, Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.38, -0.42),
        colors: [Color(0xFF31AECF), Color(0xFF0F6B8C), Color(0xFF064668), Color(0xFF041A28)],
        stops: [0.0, 0.30, 0.62, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r)));
  }
  void _paintLandmasses(Canvas canvas, Offset c, double r) {
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rotation);
    final land = Paint()..color = const Color(0xFF1A7A4D).withValues(alpha: 0.82);
    canvas.drawPath(Path()..moveTo(r * 0.06, -r * 0.12)
        ..cubicTo(r * 0.38, -r * 0.38, r * 0.48, r * 0.08, r * 0.18, r * 0.56)
        ..cubicTo(-r * 0.04, r * 0.62, -r * 0.10, r * 0.08, r * 0.06, -r * 0.12), land);
    canvas.drawPath(Path()..moveTo(-r * 0.52, -r * 0.18)
        ..cubicTo(-r * 0.28, -r * 0.52, -r * 0.12, -r * 0.22, -r * 0.18, r * 0.52)
        ..cubicTo(-r * 0.44, r * 0.58, -r * 0.72, r * 0.18, -r * 0.52, -r * 0.18), land);
    canvas.drawPath(Path()..moveTo(r * 0.12, -r * 0.52)
        ..cubicTo(r * 0.62, -r * 0.58, r * 0.78, -r * 0.08, r * 0.52, r * 0.02)
        ..cubicTo(r * 0.22, r * 0.08, r * 0.06, -r * 0.28, r * 0.12, -r * 0.52), land);
    canvas.restore();
  }
  void _paintAtmosphere(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r, Paint()
      ..shader = RadialGradient(colors: [
        tertiaryColor.withValues(alpha: 0),
        tertiaryColor.withValues(alpha: 0),
        tertiaryColor.withValues(alpha: 0.12),
        tertiaryColor.withValues(alpha: 0.30),
      ], stops: const [0.0, 0.75, 0.90, 1.0])
          .createShader(Rect.fromCircle(center: c, radius: r)));
  }
  void _paintSpecular(Canvas canvas, Offset c, double r) {
    final sc = Offset(c.dx - r * 0.28, c.dy - r * 0.30);
    canvas.drawCircle(sc, r * 0.30, Paint()
      ..shader = RadialGradient(colors: [
        Colors.white.withValues(alpha: 0.20),
        Colors.white.withValues(alpha: 0),
      ]).createShader(Rect.fromCircle(center: sc, radius: r * 0.30)));
  }
  void _paintOrbital(Canvas canvas, Offset c, double r) {
    final orR = r * 1.24;
    const tail = math.pi * 0.52;
    const segs = 7;
    canvas.drawCircle(c, orR, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = primaryColor.withValues(alpha: 0.10));
    for (var i = 0; i < segs; i++) {
      final t = i / segs;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: orR),
        orbitalAngle - tail + t * tail,
        tail / segs + 0.005,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = i == segs - 1 ? StrokeCap.round : StrokeCap.butt
          ..color = primaryColor.withValues(alpha: t * 0.82),
      );
    }
    final h = Offset(
      c.dx + orR * math.cos(orbitalAngle),
      c.dy + orR * math.sin(orbitalAngle),
    );
    canvas.drawCircle(
        h, 5.0, Paint()..color = primaryColor.withValues(alpha: 0.18));
    canvas.drawCircle(
        h, 2.8, Paint()..color = primaryColor.withValues(alpha: 0.95));
  }

  @override
  bool shouldRepaint(_GlobePainter o) =>
      rotation != o.rotation ||
      glowPulse != o.glowPulse ||
      orbitalAngle != o.orbitalAngle ||
      primaryColor != o.primaryColor ||
      tertiaryColor != o.tertiaryColor;
}
