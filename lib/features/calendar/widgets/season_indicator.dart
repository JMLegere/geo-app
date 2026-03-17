import 'package:flutter/material.dart';
import 'package:earth_nova/core/models/season.dart';
import 'package:earth_nova/shared/game_icons.dart';

/// A compact pill badge showing the current [Season].
///
/// Renders an icon + label on a tinted background:
/// - Summer → ☀️ "Summer" on amber-50 (#FFF9C4)
/// - Winter → ❄️ "Winter" on blue-100 (#BBDEFB)
///
/// Fixed size: ~80 × 28 px. Intended for placement in `StatusBar` or
/// overlaid on the map screen.
///
/// ## Usage
///
/// ```dart
/// // Static season (e.g. in tests or previews)
/// SeasonIndicator(season: Season.summer)
///
/// // Live season from Riverpod
/// Consumer(
///   builder: (ctx, ref, _) =>
///       SeasonIndicator(season: ref.watch(seasonProvider)),
/// )
/// ```
class SeasonIndicator extends StatelessWidget {
  final Season season;

  const SeasonIndicator({super.key, required this.season});

  @override
  Widget build(BuildContext context) {
    final isSummer = season.isSummer;

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        // Amber-50 for summer, Blue-100 for winter.
        color: isSummer ? const Color(0xFFFFF9C4) : const Color(0xFFBBDEFB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            GameIcons.season(season),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 4),
          Text(
            season.displayName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isSummer
                  ? const Color(0xFF795548) // brown-600 on yellow
                  : const Color(0xFF1565C0), // blue-800 on light blue
            ),
          ),
        ],
      ),
    );
  }
}
