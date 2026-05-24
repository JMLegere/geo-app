import 'package:flutter/material.dart';

import 'package:earth_nova/shared/design.dart';
import 'package:earth_nova/shared/theme/app_theme.dart';

/// Frosted glass status bar overlaid at the top of the map.
///
/// Shows three stat pills: cells observed, total steps, streak days.
/// Sits on top of the map (not above it). Uses backdrop blur for frosted glass.
/// [paddingTop] defaults to 44 to clear the iOS system status bar.
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

  /// Top padding to clear the system status bar (44px on iOS).
  final double paddingTop;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.72),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.outline.withValues(alpha: 0.52),
            width: 0.5,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: paddingTop,
          bottom: 10,
          left: 16,
          right: 16,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StatPill(
              glyph: EarthGlyph.cells,
              value: _formatCount(cellsObserved),
              label: 'cells',
            ),
            _StatPill(
              glyph: EarthGlyph.steps,
              value: _formatSteps(totalSteps),
              label: 'steps',
            ),
            _StatPill(
              glyph: EarthGlyph.streak,
              value: '$streakDays',
              label: 'days',
            ),
            if (pendingVisits > 0)
              _StatPill(
                glyph: EarthGlyph.sync,
                value: _formatCount(pendingVisits),
                label: 'syncing',
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
    required this.glyph,
    required this.value,
    required this.label,
  });

  final EarthGlyph glyph;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.86),
        border: Border.all(
          color: AppTheme.outline.withValues(alpha: 0.60),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            EarthIcon(
              glyph: glyph,
              tone: glyph == EarthGlyph.streak
                  ? EarthIconTone.warning
                  : EarthIconTone.tertiary,
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(
                color: AppTheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(width: 4),
            EarthMetaText(label),
          ],
        ),
      ),
    );
  }
}
