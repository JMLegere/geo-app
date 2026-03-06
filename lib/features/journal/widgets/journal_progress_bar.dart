import 'package:flutter/material.dart' hide Durations;
import 'package:fog_of_world/shared/design_tokens.dart';
import 'package:fog_of_world/shared/earth_nova_theme.dart';

/// Compact progress indicator showing how many species the player has collected.
///
/// Displays "X / Y collected" label above a [LinearProgressIndicator].
/// Used at the top of JournalScreen below the AppBar.
class JournalProgressBar extends StatelessWidget {
  final int collected;
  final int total;

  const JournalProgressBar({
    super.key,
    required this.collected,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? collected / total : 0.0;

    return Container(
      padding: Spacing.paddingCard,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$collected / $total collected',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -0.1,
                ),
              ),
              Text(
                total > 0
                    ? '${(fraction * 100).round()}%'
                    : '0%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Spacing.gapSm,
          ClipRRect(
            borderRadius: Radii.borderXs,
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: Theme.of(context).colorScheme.outlineVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                context.earthNova.successColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
