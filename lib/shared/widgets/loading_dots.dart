import 'package:flutter/material.dart';

import 'package:earth_nova/shared/design.dart';
import 'package:earth_nova/shared/theme/design_tokens.dart' as tokens;

/// Animated loading indicator for map/bootstrap surfaces.
class LoadingDots extends StatefulWidget {
  const LoadingDots({super.key});

  @override
  State<LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(
        milliseconds: tokens.Durations.loadingCycle.inMilliseconds * 3,
      ),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: ExcludeSemantics(
        child: SizedBox(
          width: 30,
          height: 30,
          child: RotationTransition(
            turns: _controller,
            child: const EarthIcon(
              glyph: EarthGlyph.world,
              tone: EarthIconTone.tertiary,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}
