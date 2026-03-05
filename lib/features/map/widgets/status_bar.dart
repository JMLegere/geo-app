import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fog_of_world/core/state/player_provider.dart';
import 'package:fog_of_world/shared/design_tokens.dart';
import 'package:fog_of_world/shared/widgets/frosted_glass_container.dart';

/// Top status bar showing key exploration stats (Apple Maps style).
///
/// Reads [playerProvider] for live stats:
/// - 🔍 Cells observed
/// - 🔥 Current exploration streak in days
///
/// Uses a translucent frosted-glass background via [FrostedGlassContainer]
/// and respects the device's safe area (status bar height).
///
/// Adapts to the active theme — dark theme produces a naval frosted-glass
/// panel; light theme produces the classic white frosted-glass panel.
///
/// ## Usage
///
/// ```dart
/// Positioned(
///   top: 0, left: 0, right: 0,
///   child: const StatusBar(),
/// )
/// ```
class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final topPadding = MediaQuery.of(context).padding.top;

    return FrostedGlassContainer(
      blur: Blurs.statusBar,
      bottomBorderOnly: true,
      borderRadius: 0,
      padding: EdgeInsets.fromLTRB(Spacing.lg, topPadding + Spacing.sm, Spacing.lg, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatPill(emoji: '🔍', value: '${player.cellsObserved} cells'),
          _StatPill(emoji: '🔥', value: '${player.currentStreak} days'),
        ],
      ),
    );
  }
}

/// A compact stat chip with an emoji label and a formatted value.
class _StatPill extends StatelessWidget {
  final String emoji;
  final String value;

  const _StatPill({required this.emoji, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 5),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh.withValues(alpha: Opacities.chipBackground),
        borderRadius: Radii.borderXxxl,
        border: Border.all(
          color: cs.outline.withValues(alpha: Opacities.borderSubtle),
          width: 0.5,
        ),
      ),
      child: Text(
        '$emoji $value',
        style: tt.labelMedium?.copyWith(
          color: cs.onSurface,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
