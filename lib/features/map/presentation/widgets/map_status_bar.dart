import 'package:flutter/material.dart';

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
    this.paddingTop = 44.0,
  });

  final int cellsObserved;
  final int totalSteps;
  final int streakDays;

  /// Top padding to clear the system status bar (44px on iOS).
  final double paddingTop;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xB80D1B2A),
        border: Border(
          bottom: BorderSide(
            color: const Color(0x803D5060),
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
              emoji: '🗺',
              value: _formatCount(cellsObserved),
              label: 'cells',
            ),
            _StatPill(
              emoji: '👟',
              value: _formatSteps(totalSteps),
              label: 'steps',
            ),
            _StatPill(
              emoji: '🔥',
              value: '$streakDays',
              label: 'days',
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
    required this.emoji,
    required this.value,
    required this.label,
  });

  final String emoji;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xBF1A2D40),
        border: Border.all(
          color: const Color(0x993D5060),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          '$emoji $value $label',
          style: const TextStyle(
            color: Color(0xFFE0E1DD),
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}
