import 'package:flutter/material.dart';

import 'package:earth_nova/features/living_world/domain/entities/npc_venue.dart';
import 'package:earth_nova/shared/theme/app_theme.dart';

class NpcVenueMarker extends StatelessWidget {
  const NpcVenueMarker({required this.venue, super.key});

  final NpcVenue venue;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${venue.venueName}, ${venue.npcName}, ${venue.npcRole}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.tertiary, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _NpcDot(),
                  const SizedBox(width: 6),
                  Text(
                    venue.venueName,
                    style: const TextStyle(
                      color: AppTheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${venue.npcName} • ${venue.npcRole}',
                style: const TextStyle(
                  color: AppTheme.onSurfaceVariant,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NpcDot extends StatelessWidget {
  const _NpcDot();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.tertiary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const SizedBox(width: 8, height: 8),
    );
  }
}
