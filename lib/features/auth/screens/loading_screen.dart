import 'package:flutter/material.dart';

import 'package:earth_nova/shared/design_tokens.dart';

const _globeFrames = ['\u{1F30D}', '\u{1F30E}', '\u{1F30F}'];

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  late final AnimationController _revolveCtrl;

  late final Animation<double> _globeScale;
  late final Animation<double> _globeOpacity;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _subtitleOpacity;

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _revolveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _globeScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    _globeOpacity = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.25, curve: AppCurves.fadeIn),
    );

    _titleOpacity = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.3, 0.7, curve: AppCurves.fadeIn),
    );

    _subtitleOpacity = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.55, 1.0, curve: AppCurves.fadeIn),
    );

    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _revolveCtrl.dispose();
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
              opacity: _globeOpacity,
              child: ScaleTransition(
                scale: _globeScale,
                child: AnimatedBuilder(
                  animation: _revolveCtrl,
                  builder: (_, __) {
                    final frame = (_revolveCtrl.value * _globeFrames.length)
                        .floor()
                        .clamp(0, _globeFrames.length - 1);
                    return Text(
                      _globeFrames[frame],
                      style: const TextStyle(fontSize: 64),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: Spacing.xxl),
            FadeTransition(
              opacity: _titleOpacity,
              child: Text(
                'EarthNova',
                style: tt.displaySmall?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            FadeTransition(
              opacity: _subtitleOpacity,
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
