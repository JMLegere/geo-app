import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fog_of_world/core/state/player_provider.dart';

/// Top status bar showing key exploration stats (Apple Maps style).
///
/// Reads [playerProvider] for live stats:
/// - 🔍 Cells observed
/// - 🔥 Current exploration streak in days
///
/// Uses a translucent frosted-glass background (BackdropFilter + ClipRect)
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
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    // Frosted-glass tint — dark for exploration mode, white for light mode.
    final tintColor = isDark
        ? cs.surfaceContainer.withValues(alpha: 0.82)
        : cs.surfaceContainer.withValues(alpha: 0.88);

    final borderColor = isDark
        ? cs.outline.withValues(alpha: 0.25)
        : cs.outline.withValues(alpha: 0.3);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.fromLTRB(16, topPadding + 8, 16, 10),
          decoration: BoxDecoration(
            color: tintColor,
            border: Border(
              bottom: BorderSide(color: borderColor, width: 0.5),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatPill(emoji: '🔍', value: '${player.cellsObserved} cells'),
              _StatPill(emoji: '🔥', value: '${player.currentStreak} days'),
            ],
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outline.withValues(alpha: 0.2),
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
