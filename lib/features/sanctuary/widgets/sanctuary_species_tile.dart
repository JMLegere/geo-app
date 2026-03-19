import 'package:flutter/material.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/models/item_definition.dart';
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/shared/earth_nova_theme.dart';
import 'package:earth_nova/shared/game_icons.dart';
import 'package:earth_nova/shared/widgets/rarity_badge.dart';
import 'package:earth_nova/shared/widgets/habitat_gradient.dart';
import 'package:earth_nova/shared/widgets/species_art_image.dart';

/// Compact card displaying a collected species inside a habitat section.
///
/// - Rounded card (12px) with soft shadow.
/// - Gradient background keyed to the species' primary habitat (low opacity).
/// - Rarity-coloured border (prismatic border takes priority if first discovery).
/// - Common name (bold 13px), scientific name (italic 11px), IUCN badge.
class SanctuarySpeciesTile extends StatelessWidget {
  final FaunaDefinition species;

  const SanctuarySpeciesTile({super.key, required this.species});

  @override
  Widget build(BuildContext context) {
    final primaryHabitat =
        species.habitats.isNotEmpty ? species.habitats.first : Habitat.forest;

    final rarity = species.rarity;
    final borderColor = (rarity != null)
        ? EarthNovaTheme.rarityColor(rarity)
            .withValues(alpha: Opacities.borderSubtle)
        : Theme.of(context)
            .colorScheme
            .outline
            .withValues(alpha: Opacities.borderSubtle);

    return Container(
      padding: EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        gradient: HabitatGradient.tile(primaryHabitat).gradient,
        borderRadius: Radii.borderXl,
        border: Border.all(
          color: borderColor,
          width: rarity != null ? 1.5 : 1.0,
        ),
        boxShadow: Shadows.soft,
      ),
      child: Row(
        children: [
          // Species icon
          SpeciesArtImage(
            artUrl: species.iconUrl,
            fallbackEmoji: GameIcons.fauna(species),
            size: 36,
            borderRadius: Radii.borderMd,
          ),
          SizedBox(width: Spacing.sm),
          // Species names
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  species.displayName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: -0.1,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  species.scientificName,
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 0.1,
                    height: 1.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: Spacing.xs),
          // IUCN rarity badge
          RarityBadge(status: species.rarity!),
        ],
      ),
    );
  }
}
