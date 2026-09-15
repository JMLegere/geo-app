import 'package:flutter/material.dart';

/// Theme-aware loading indicator with a static reduced-motion state.
class LoadingDots extends StatelessWidget {
  const LoadingDots({super.key});

  @override
  Widget build(BuildContext context) {
    final child = MediaQuery.disableAnimationsOf(context)
        ? Icon(
            Icons.more_horiz,
            key: const ValueKey('loading-dots-static'),
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          )
        : SizedBox.square(
            dimension: 20,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  key: const ValueKey('loading-dots-track'),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 2.4,
                    ),
                  ),
                ),
                CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          );

    return Semantics(
      label: 'Loading',
      liveRegion: true,
      child: ExcludeSemantics(child: child),
    );
  }
}
