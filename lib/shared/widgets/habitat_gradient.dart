import 'package:flutter/material.dart';

import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/shared/habitat_colors.dart';

/// Builds a habitat-keyed gradient [BoxDecoration] for species cards.
///
/// Replaces the duplicated gradient logic in `species_card.dart` and
/// `sanctuary_species_tile.dart`. Uses [HabitatColors] as the single source
/// of truth (not the local `_habitatColor` helpers that had inconsistent
/// Material design colours).
///
/// ## Usage
/// ```dart
/// Container(
///   decoration: HabitatGradient.card(species.habitats.first),
///   child: ...,
/// )
///
/// // Compact variant with lower opacity
/// Container(
///   decoration: HabitatGradient.tile(species.habitats.first),
///   child: ...,
/// )
/// ```
abstract final class HabitatGradient {
  /// Full species card gradient — higher opacity for larger cards.
  ///
  /// Start: habitat accent at 35% opacity → End: 12% opacity.
  static BoxDecoration card(Habitat habitat) {
    final color = HabitatColors.accentFor(habitat);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withValues(alpha: Opacities.habitatGradientCardStart),
          color.withValues(alpha: Opacities.habitatGradientCardEnd),
        ],
      ),
    );
  }

  /// Compact tile gradient — lower opacity for smaller tiles.
  ///
  /// Start: habitat accent at 20% opacity → End: 5% opacity.
  static BoxDecoration tile(Habitat habitat) {
    final color = HabitatColors.accentFor(habitat);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withValues(alpha: Opacities.habitatGradientStart),
          color.withValues(alpha: Opacities.habitatGradientEnd),
        ],
      ),
    );
  }

  /// Returns the habitat icon for placeholder art.
  static String icon(Habitat habitat) => switch (habitat) {
        Habitat.forest => '🌲',
        Habitat.plains => '🌾',
        Habitat.freshwater => '💧',
        Habitat.saltwater => '🌊',
        Habitat.swamp => '🌿',
        Habitat.mountain => '⛰️',
        Habitat.desert => '🏜️',
      };
}
