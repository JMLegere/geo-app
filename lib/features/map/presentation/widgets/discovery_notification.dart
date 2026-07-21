import 'package:flutter/material.dart';

import 'package:earth_nova/shared/design.dart';

/// Brief notification shown just below the status bar when the player
/// enters a new cell for the first time.
///
/// Floats over the map. Caller is responsible for showing/hiding it
/// (e.g. via AnimatedOpacity or conditional inclusion in the Stack).
class DiscoveryNotification extends StatelessWidget {
  const DiscoveryNotification({
    super.key,
    required this.cellName,
  });

  final String cellName;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.92),
        border: Border.all(
          color: AppTheme.tertiary.withValues(alpha: 0.35),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EarthIcon(
              glyph: EarthGlyph.map,
              tone: EarthIconTone.tertiary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const EarthMetaText('New cell', tone: EarthMetaTone.accent),
                  const SizedBox(height: 2),
                  Text(
                    cellName.isEmpty ? 'Unknown Cell' : cellName,
                    style: const TextStyle(
                      color: AppTheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
