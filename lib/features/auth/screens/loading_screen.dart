import 'package:flutter/material.dart';

import 'package:earth_nova/shared/design_tokens.dart';

/// Clean branded splash screen shown while game data loads. No Riverpod.
///
/// Dark background, centred "EarthNova" wordmark with subtle fade-in.
/// No 3D, no CustomPainter — flat and clean.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _titleFade;
  late final Animation<double> _subtitleFade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _titleFade = CurvedAnimation(
      parent: _fadeCtrl,
      curve: const Interval(0.0, 0.6, curve: AppCurves.fadeIn),
    );
    _subtitleFade = CurvedAnimation(
      parent: _fadeCtrl,
      curve: const Interval(0.35, 1.0, curve: AppCurves.fadeIn),
    );
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
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
              opacity: _titleFade,
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
