import 'package:flutter/material.dart' hide Durations;
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/models/item_definition.dart';
import 'package:earth_nova/features/sanctuary/widgets/sanctuary_species_tile.dart';
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/shared/game_icons.dart';
import 'package:earth_nova/shared/habitat_colors.dart';

/// One collapsible section in the Sanctuary screen for a single habitat.
///
/// Shows:
/// - Header row: habitat icon + name (bold 16px) + species count (muted 13px)
/// - 2-column grid of [SanctuarySpeciesTile] for each collected species
/// - Empty state message when [species] is empty
class HabitatSection extends StatelessWidget {
  final Habitat habitat;

  /// Collected species belonging to this habitat. May be empty.
  final List<FaunaDefinition> species;

  const HabitatSection({
    super.key,
    required this.habitat,
    required this.species,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            children: [
              // Habitat icon in tinted pill
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color:
                      HabitatColors.primaryFor(habitat).withValues(alpha: 0.12),
                  borderRadius: Radii.borderLg,
                ),
                child: Center(
                  child: Text(
                    GameIcons.habitat(habitat),
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              SizedBox(width: Spacing.md),

              // Name
              Text(
                habitat.displayName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
              Spacing.gapHSm,

              // Count chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: Radii.borderMd,
                ),
                child: Text(
                  '${species.length} species',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Body: grid or empty state
        if (species.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              'Explore ${habitat.displayName.toLowerCase()} areas to discover species',
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.outline,
                height: 1.4,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.4,
              ),
              itemCount: species.length,
              itemBuilder: (_, index) =>
                  SanctuarySpeciesTile(species: species[index]),
            ),
          ),
      ],
    );
  }
}
