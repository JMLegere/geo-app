import 'package:flutter/material.dart';

import 'package:earth_nova/features/living_world/domain/entities/town_projection.dart';

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
      excludeSemantics: true,
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
      .map(
        (word) => '${word.characters.first.toUpperCase()}${word.substring(1)}',
      )
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
  const _CompactVenueCue({required this.initials, required this.label});

  final String initials;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _VenuePin(initials: initials),
        const SizedBox(width: 4),
        Material(
          color: colors.surfaceContainerHigh,
          shape: StadiumBorder(side: BorderSide(color: colors.outline)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(label, style: Theme.of(context).textTheme.labelSmall),
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
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest,
      shape: CircleBorder(side: BorderSide(color: colors.outline)),
      child: SizedBox.square(
        dimension: 32,
        child: Center(
          child: Text(initials, style: Theme.of(context).textTheme.labelSmall),
        ),
      ),
    );
  }
}
