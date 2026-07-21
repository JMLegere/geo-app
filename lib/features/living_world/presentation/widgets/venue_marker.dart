import 'package:flutter/material.dart';

import 'package:earth_nova/features/living_world/domain/entities/town_projection.dart';
import 'package:earth_nova/shared/design.dart';

enum VenueMarkerDisplayMode { glyphOnly, compactLabel }

class VenueMarker extends StatelessWidget {
  const VenueMarker({
    required this.venue,
    this.displayMode = VenueMarkerDisplayMode.compactLabel,
    super.key,
  });

  final TownVenue venue;
  final VenueMarkerDisplayMode displayMode;

  @override
  Widget build(BuildContext context) {
    final label = venue.villagers.isEmpty
        ? '${venue.venue.displayName}, Venue'
        : '${venue.venue.displayName}, Venue with '
            '${venue.villagers.map((v) => v.villager.displayName).join(', ')}';

    return Semantics(
      label: label,
      child: displayMode == VenueMarkerDisplayMode.glyphOnly
          ? _VenuePin(initials: _initialsFor(venue))
          : _CompactVenueCue(
              initials: _initialsFor(venue),
              label: _compactLabelFor(venue),
            ),
    );
  }
}

String _compactLabelFor(TownVenue venue) {
  final kind = _humanizeKind(venue.venue.kind);
  if (kind.length <= 18) return kind;
  return venue.venue.displayName;
}

String _humanizeKind(String kind) {
  final words = kind
      .replaceAll('_', '-')
      .split('-')
      .where((word) => word.trim().isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) return 'Venue';
  return words
      .map((word) =>
          '${word.characters.first.toUpperCase()}${word.substring(1)}')
      .join(' ');
}

String _initialsFor(TownVenue venue) {
  final words = venue.venue.displayName
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) return 'V';
  if (words.length == 1) {
    return words.single.characters.take(2).toString().toUpperCase();
  }
  return words
      .take(2)
      .map((word) => word.characters.first)
      .join()
      .toUpperCase();
}

class _CompactVenueCue extends StatelessWidget {
  const _CompactVenueCue({
    required this.initials,
    required this.label,
  });

  final String initials;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _VenuePin(initials: initials),
        const SizedBox(width: Spacing.xs),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(
              color: AppTheme.tertiary.withValues(alpha: 0.72),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.surface.withValues(alpha: 0.24),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.sm,
              vertical: Spacing.xs,
            ),
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

class _VenuePin extends StatelessWidget {
  const _VenuePin({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: AppTheme.tertiary, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: AppTheme.surface.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: Text(
            initials,
            style: const TextStyle(
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
