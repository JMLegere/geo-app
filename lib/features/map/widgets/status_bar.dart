import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/state/player_provider.dart';
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/shared/game_icons.dart';
import 'package:earth_nova/shared/widgets/frosted_glass_container.dart';

/// Top status bar showing key exploration stats (Apple Maps style).
///
/// Reads [playerProvider] for live stats:
/// - Cells observed
/// - Current exploration streak in days
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

  /// Formats a step count for compact display: "0", "999", "1.2k", "15k".
  @visibleForTesting
  static String formatSteps(int steps) {
    if (steps < 1000) return '$steps';
    final k = steps / 1000;
    // Show one decimal only when < 10k (e.g. 1.2k, 9.9k), else whole (15k).
    return k < 10 ? '${k.toStringAsFixed(1)}k' : '${k.round()}k';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final topPadding = MediaQuery.of(context).padding.top;

    return FrostedGlassContainer(
      blur: Blurs.statusBar,
      bottomBorderOnly: true,
      borderRadius: 0,
      padding: EdgeInsets.fromLTRB(
          Spacing.lg, topPadding + Spacing.sm, Spacing.lg, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatPill(
              icon: GameIcons.cellsExplored,
              value: '${player.cellsObserved} cells'),
          _StatPill(
              icon: GameIcons.steps, value: formatSteps(player.totalSteps)),
          _StatPill(
              icon: GameIcons.streak, value: '${player.currentStreak} days'),
        ],
      ),
    );
  }
}

/// A compact stat chip with an icon label and a formatted value.
class _StatPill extends StatelessWidget {
  final String icon;
  final String value;

  const _StatPill({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 5),
      decoration: BoxDecoration(
        color:
            cs.surfaceContainerHigh.withValues(alpha: Opacities.chipBackground),
        borderRadius: Radii.borderXxxl,
        border: Border.all(
          color: cs.outline.withValues(alpha: Opacities.borderSubtle),
          width: 0.5,
        ),
      ),
      child: Text(
        '$icon $value',
        style: tt.labelMedium?.copyWith(
          color: cs.onSurface,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
