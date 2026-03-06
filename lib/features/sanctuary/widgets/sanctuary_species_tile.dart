import 'package:flutter/material.dart';
import 'package:fog_of_world/core/models/habitat.dart';
import 'package:fog_of_world/core/models/item_definition.dart';
import 'package:fog_of_world/shared/design_tokens.dart';
import 'package:fog_of_world/shared/widgets/rarity_badge.dart';
import 'package:fog_of_world/shared/widgets/habitat_gradient.dart';

/// Compact card displaying a collected species inside a habitat section.
///
/// - Rounded card (12px) with soft shadow.
/// - Gradient background keyed to the species' primary habitat (low opacity).
/// - Common name (bold 13px), scientific name (italic 11px), IUCN badge.
class SanctuarySpeciesTile extends StatelessWidget {
  final FaunaDefinition species;

  const SanctuarySpeciesTile({super.key, required this.species});

  @override
  Widget build(BuildContext context) {
    final primaryHabitat =
        species.habitats.isNotEmpty ? species.habitats.first : Habitat.forest;

    return Container(
      padding: EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        gradient: HabitatGradient.tile(primaryHabitat).gradient,
        borderRadius: Radii.borderXl,
        boxShadow: Shadows.soft,
      ),
      child: Stack(
        children: [
          // Species names
          Column(
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

          // IUCN rarity badge — top right corner
          Positioned(
            top: 0,
            right: 0,
            child: RarityBadge(status: species.rarity!),
          ),
        ],
      ),
    );
  }
}


