import 'package:flutter/material.dart';
import 'package:fog_of_world/core/models/habitat.dart';
import 'package:fog_of_world/core/models/species.dart';
import 'package:fog_of_world/features/sanctuary/widgets/sanctuary_species_tile.dart';

/// One collapsible section in the Sanctuary screen for a single habitat.
///
/// Shows:
/// - Header row: habitat emoji + name (bold 16px) + species count (muted 13px)
/// - 2-column grid of [SanctuarySpeciesTile] for each collected species
/// - Empty state message when [species] is empty
class HabitatSection extends StatelessWidget {
  final Habitat habitat;

  /// Collected species belonging to this habitat. May be empty.
  final List<SpeciesRecord> species;

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
              // Habitat emoji in tinted pill
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _habitatColor(habitat).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    _habitatEmoji(habitat),
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Name
              Text(
                habitat.displayName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A2E1B),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 8),

              // Count chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${species.length} species',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
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
              style: const TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Color(0xFF9CA3AF),
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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Color _habitatColor(Habitat habitat) => switch (habitat) {
      Habitat.forest => const Color(0xFF4CAF50),
      Habitat.plains => const Color(0xFFFFC107),
      Habitat.freshwater => const Color(0xFF03A9F4),
      Habitat.saltwater => const Color(0xFF0277BD),
      Habitat.swamp => const Color(0xFF795548),
      Habitat.mountain => const Color(0xFF9E9E9E),
      Habitat.desert => const Color(0xFFFF9800),
    };

String _habitatEmoji(Habitat habitat) => switch (habitat) {
      Habitat.forest => '🌲',
      Habitat.plains => '🌾',
      Habitat.freshwater => '🐟',
      Habitat.saltwater => '🌊',
      Habitat.swamp => '🌿',
      Habitat.mountain => '⛰️',
      Habitat.desert => '🏜️',
    };
