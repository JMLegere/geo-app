import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:earth_nova/shared/design.dart';

/// Compact progress HUD overlaid at the top of the map.
class MapStatusBar extends StatelessWidget {
  const MapStatusBar({
    super.key,
    required this.cellsObserved,
    required this.totalSteps,
    required this.streakDays,
    this.pendingVisits = 0,
    this.paddingTop = 44.0,
  });

  final int cellsObserved;
  final int totalSteps;
  final int streakDays;
  final int pendingVisits;

  /// Top padding to clear the system status bar.
  final double paddingTop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: paddingTop,
        left: Spacing.lg,
        right: Spacing.giant + Spacing.lg,
      ),
      child: ShadCard(
        width: double.infinity,
        padding: const EdgeInsets.all(Spacing.sm),
        shadows: const [],
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          children: [
            _StatPill(
              value: _formatCount(cellsObserved),
              label: cellsObserved == 1 ? 'cell' : 'cells',
            ),
            _StatPill(
              value: _formatSteps(totalSteps),
              label: totalSteps == 1 ? 'step' : 'steps',
            ),
            _StatPill(
              value: '$streakDays',
              label: streakDays == 1 ? 'day' : 'days',
            ),
            if (pendingVisits > 0)
              _StatPill(
                value: _formatCount(pendingVisits),
                label: 'syncing',
                semanticsLabel: '$pendingVisits visits syncing',
                liveRegion: true,
              ),
          ],
        ),
      ),
    );
  }

  static String _formatCount(int count) {
    if (count >= 1000) {
      final k = count / 1000.0;
      return '${k.toStringAsFixed(k == k.truncate() ? 0 : 1)}k';
    }
    return '$count';
  }

  static String _formatSteps(int steps) {
    if (steps >= 1000) {
      final k = steps / 1000.0;
      return '${k.toStringAsFixed(1)}k';
    }
    return '$steps';
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.value,
    required this.label,
    this.semanticsLabel,
    this.liveRegion = false,
  });

  final String value;
  final String label;
  final String? semanticsLabel;
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: liveRegion,
      label: semanticsLabel ?? '$value $label',
      child: ExcludeSemantics(
        child: ShadBadge.secondary(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Spacing.xs,
            children: [
              Text(value, style: Theme.of(context).textTheme.labelLarge),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}
