import 'package:flutter/material.dart';
import 'package:fog_of_world/core/models/habitat.dart';
import 'package:fog_of_world/core/models/species.dart';
import 'package:fog_of_world/shared/design_tokens.dart';
import 'package:fog_of_world/shared/earth_nova_theme.dart';
import 'package:fog_of_world/shared/widgets/rarity_badge.dart';
import 'package:fog_of_world/shared/widgets/habitat_gradient.dart';

/// Grid card representing a single species in the collection journal.
///
/// ## Collected state
/// - Watercolor-inspired gradient background keyed to the species' primary habitat.
/// - Common name (bold), IUCN rarity badge, and a "✓ Collected" label.
///
/// ## Uncollected state
/// - Muted gray background with a "?" silhouette.
/// - "???" placeholder name, no rarity badge, "Not discovered" label.
///
/// Tap calls [onTap] so the parent can show the SpeciesDetailSheet.
class SpeciesCard extends StatelessWidget {
  final SpeciesRecord species;
  final bool isCollected;
  final VoidCallback onTap;

  const SpeciesCard({
    super.key,
    required this.species,
    required this.isCollected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: Radii.borderXxl,
          boxShadow: Shadows.medium,
        ),
        clipBehavior: Clip.antiAlias,
        child: isCollected
            ? _CollectedCard(species: species)
            : _UncollectedCard(species: species),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Collected
// ---------------------------------------------------------------------------

class _CollectedCard extends StatelessWidget {
  final SpeciesRecord species;

  const _CollectedCard({required this.species});

  @override
  Widget build(BuildContext context) {
    final primaryHabitat =
        species.habitats.isNotEmpty ? species.habitats.first : Habitat.forest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Artwork placeholder — watercolor gradient fill
        Expanded(
          child: Container(
            decoration: HabitatGradient.card(primaryHabitat),
            child: Stack(
              children: [
                // Habitat emoji hint
                Center(
                  child: Text(
                    HabitatGradient.emoji(primaryHabitat),
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
                // Rarity badge — top right
                Positioned(
                  top: 6,
                  right: 6,
                  child: RarityBadge(status: species.iucnStatus),
                ),
              ],
            ),
          ),
        ),

        // Info panel
        Padding(
          padding: EdgeInsets.fromLTRB(Spacing.sm, 6, Spacing.sm, Spacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                species.commonName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -0.1,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Spacing.gapXs,
              Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 12,
                    color: context.earthNova.successColor,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '✓ Collected',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.earthNova.successColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Uncollected
// ---------------------------------------------------------------------------

class _UncollectedCard extends StatelessWidget {
  final SpeciesRecord species;

  const _UncollectedCard({required this.species});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Silhouette placeholder
        Expanded(
          child: Container(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: Center(
              child: Container(
                width: ComponentSizes.silhouetteBox,
                height: ComponentSizes.silhouetteBox,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: Radii.borderXl,
                ),
                child: Center(
                  child: Text(
                    '?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Info panel
        Padding(
          padding: EdgeInsets.fromLTRB(Spacing.sm, 6, Spacing.sm, Spacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '???',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 1,
                ),
              ),
              Spacing.gapXs,
              Text(
                'Not discovered',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


