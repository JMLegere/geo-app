import 'package:flutter/material.dart';

/// Theme-aware loading indicator with a static reduced-motion state.
class LoadingDots extends StatelessWidget {
  const LoadingDots({super.key});

  @override
  Widget build(BuildContext context) {
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Semantics(
      label: 'Loading',
      liveRegion: true,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(
            value: reducedMotion ? 0.75 : null,
            strokeWidth: 2.4,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
