import 'package:flutter/material.dart';

import 'package:earth_nova/features/living_world/domain/entities/npc_venue.dart';
import 'package:earth_nova/shared/theme/app_theme.dart';

enum NpcVenueMarkerDisplayMode { glyphOnly, compactLabel }

class NpcVenueMarker extends StatelessWidget {
  const NpcVenueMarker({
    required this.venue,
    this.displayMode = NpcVenueMarkerDisplayMode.compactLabel,
    super.key,
  });

  final NpcVenue venue;
  final NpcVenueMarkerDisplayMode displayMode;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${venue.venueName}, ${venue.npcName}, ${venue.npcRole}',
      child: displayMode == NpcVenueMarkerDisplayMode.glyphOnly
          ? const _NpcVenuePin()
          : _CompactNpcVenueCue(label: _compactLabelFor(venue.kind)),
    );
  }
}

String _compactLabelFor(NpcVenueKind kind) {
  return switch (kind) {
    NpcVenueKind.wildlifeRehabilitationCenter => 'Wildlife Rehab',
  };
}

class _CompactNpcVenueCue extends StatelessWidget {
  const _CompactNpcVenueCue({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const _NpcVenuePin(),
        const SizedBox(width: 6),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppTheme.tertiary.withValues(alpha: 0.72),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.onSurface,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.1,
                height: 1.0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NpcVenuePin extends StatelessWidget {
  const _NpcVenuePin();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.tertiary, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: Text(
            'WR',
            style: TextStyle(
              color: AppTheme.tertiary,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}
