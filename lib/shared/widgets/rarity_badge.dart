import 'package:flutter/material.dart';

import 'package:earth_nova/models/iucn_status.dart';
import 'package:earth_nova/shared/earth_nova_theme.dart';
import 'package:earth_nova/shared/design_tokens.dart';

/// Display size for [RarityBadge].
enum RarityBadgeSize {
  /// Compact — used inside list items, small cards.
  small,

  /// Standard — used in discovery toasts and collection tiles.
  medium,

  /// Large — used in species detail view.
  large,
}

/// A coloured pill badge showing an IUCN rarity status abbreviation.
///
/// Colour is derived from [EarthNovaTheme.rarityColor].
///
/// ## Usage
/// ```dart
/// RarityBadge(status: IucnStatus.endangered, size: RarityBadgeSize.medium)
/// ```
class RarityBadge extends StatelessWidget {
  /// IUCN conservation status.
  final IucnStatus status;

  /// Controls font size and padding.
  final RarityBadgeSize size;

  const RarityBadge({
    super.key,
    required this.status,
    this.size = RarityBadgeSize.medium,
  });

  static String _abbreviation(IucnStatus s) => switch (s) {
        IucnStatus.leastConcern => 'LC',
        IucnStatus.nearThreatened => 'NT',
        IucnStatus.vulnerable => 'VU',
        IucnStatus.endangered => 'EN',
        IucnStatus.criticallyEndangered => 'CR',
        IucnStatus.extinct => 'EX',
      };

  @override
  Widget build(BuildContext context) {
    final color = EarthNovaTheme.rarityColor(status);
    final tt = Theme.of(context).textTheme;

    final (fontSize, padding) = switch (size) {
      RarityBadgeSize.small => (9.0, Spacing.paddingBadgeCompact),
      RarityBadgeSize.medium => (10.0, Spacing.paddingBadge),
      RarityBadgeSize.large => (12.0, Spacing.paddingCard),
    };

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: Opacities.badgeBackground),
        borderRadius: Radii.borderXxxl,
        border: Border.all(
          color: color.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: Text(
        _abbreviation(status),
        style: tt.labelSmall?.copyWith(
          fontSize: fontSize,
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
