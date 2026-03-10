import 'package:flutter/material.dart' hide Durations;
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/shared/game_icons.dart';

/// Small pill badge showing the player's daily visit streak.
///
/// - When [streak] > 0: flame icon + "Day N" with warm orange pill background.
/// - When [streak] == 0: "Start your streak!" in muted italic gray, no flame.
class StreakBadge extends StatelessWidget {
  /// Player's current daily visit streak.
  final int streak;

  const StreakBadge({super.key, required this.streak});

  @override
  Widget build(BuildContext context) {
    if (streak == 0) {
      return Text(
        'Start your streak!',
        style: TextStyle(
          fontSize: 13,
          fontStyle: FontStyle.italic,
          color: Theme.of(context).colorScheme.outline,
          letterSpacing: 0.1,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md, vertical: Spacing.sm),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9800).withValues(alpha: 0.15),
        borderRadius: Radii.borderPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(GameIcons.streak, style: const TextStyle(fontSize: 14)),
          SizedBox(width: Spacing.xs),
          Text(
            'Day $streak',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
