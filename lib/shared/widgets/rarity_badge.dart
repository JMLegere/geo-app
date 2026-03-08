import 'package:flutter/material.dart';

import 'package:earth_nova/core/models/iucn_status.dart';
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/shared/earth_nova_theme.dart';

/// Compact IUCN rarity badge — coloured pill with 2-letter status code.
///
/// Replaces the 3 duplicate `_RarityBadge` implementations across
/// `species_card.dart`, `sanctuary_species_tile.dart`, and
/// `discovery_notification.dart`.
///
/// Colours come from [EarthNovaTheme.rarityColor] (theme-independent).
///
/// ## Usage
/// ```dart
/// RarityBadge(status: species.iucnStatus)
/// RarityBadge(status: species.iucnStatus, size: RarityBadgeSize.large)
/// ```
class RarityBadge extends StatelessWidget {
  const RarityBadge({
    required this.status,
    this.size = RarityBadgeSize.small,
    super.key,
  });

  /// The IUCN conservation status to display.
  final IucnStatus status;

  /// Badge size variant.
  final RarityBadgeSize size;

  @override
  Widget build(BuildContext context) {
    final bgColor = EarthNovaTheme.rarityColor(status);
    final textColor = EarthNovaTheme.onRarityColor(status);
    final label = EarthNovaTheme.rarityLabel(status);

    final (padding, fontSize, radius, fontWeight, letterSpacing) = switch (size) {
      RarityBadgeSize.small => (
          Spacing.paddingBadgeCompact,
          9.0,
          Radii.sm,
          FontWeight.w800,
          0.3,
        ),
      RarityBadgeSize.medium => (
          Spacing.paddingBadge,
          10.0,
          Radii.md,
          FontWeight.w800,
          0.5,
        ),
    };

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: textColor,
          letterSpacing: letterSpacing,
        ),
      ),
    );
  }
}

/// Size variants for [RarityBadge].
enum RarityBadgeSize {
  /// 9px text, compact padding — grid cards, compact tiles.
  small,

  /// 10px text, standard padding — notification toasts, detail sheets.
  medium,
}
