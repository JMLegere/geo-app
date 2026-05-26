import 'package:flutter/material.dart';

import 'package:earth_nova/features/living_world/domain/entities/npc_venue.dart';
import 'package:earth_nova/shared/theme/app_theme.dart';

/// Compact bottom sheet showing NPC venue info, opened from cell detail or Town.
class NpcVenueDetailSheet extends StatelessWidget {
  const NpcVenueDetailSheet({super.key, required this.venue});

  final NpcVenue venue;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: Color(0xFF333333), width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF555555),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.tertiary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          'WR',
                          style: TextStyle(
                            color: AppTheme.tertiary,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            venue.venueName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${venue.npcName}  •  ${venue.npcRole}',
                            style: TextStyle(
                              color: AppTheme.onSurfaceVariant
                                  .withValues(alpha: 0.75),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _VenueInfoRow(
                  icon: Icons.pets,
                  label: 'Service',
                  value: venue.featureName,
                ),
                const SizedBox(height: 10),
                _VenueInfoRow(
                  icon: Icons.info_outline,
                  label: 'Status',
                  value: 'Coming soon',
                  valueColor: const Color(0xFFFFC857),
                ),
                const SizedBox(height: 16),
                Text(
                  '${venue.npcName} is preparing local release programs for animals that are ready to return to the wild.',
                  style: TextStyle(
                    color: AppTheme.onSurfaceVariant.withValues(alpha: 0.72),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VenueInfoRow extends StatelessWidget {
  const _VenueInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF888888), size: 18),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF888888),
            fontSize: 13,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
