import 'package:flutter/material.dart';
import 'package:fog_of_world/core/models/habitat.dart';
import 'package:fog_of_world/core/models/iucn_status.dart';
import 'package:fog_of_world/core/models/species.dart';

/// Compact card displaying a collected species inside a habitat section.
///
/// - Rounded card (12px) with soft shadow.
/// - Gradient background keyed to the species' primary habitat (low opacity).
/// - Common name (bold 13px), scientific name (italic 11px), IUCN badge.
class SanctuarySpeciesTile extends StatelessWidget {
  final SpeciesRecord species;

  const SanctuarySpeciesTile({super.key, required this.species});

  @override
  Widget build(BuildContext context) {
    final primaryHabitat =
        species.habitats.isNotEmpty ? species.habitats.first : Habitat.forest;
    final habitatColor = _habitatColor(primaryHabitat);
    final rarityColor = _rarityColor(species.iucnStatus);
    final rarityLabel = _rarityLabel(species.iucnStatus);
    final isLightBadge = species.iucnStatus == IucnStatus.nearThreatened;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            habitatColor.withValues(alpha: 0.20),
            habitatColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        color: Colors.white,
      ),
      child: Stack(
        children: [
          // Species names
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                species.commonName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A2E1B),
                  letterSpacing: -0.1,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                species.scientificName,
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF6B7280),
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
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: rarityColor,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                rarityLabel,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: isLightBadge
                      ? const Color(0xFF1A1A2E)
                      : Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Color / label helpers (package-private, mirrors species_card.dart palette)
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

Color _rarityColor(IucnStatus status) => switch (status) {
      IucnStatus.leastConcern => const Color(0xFF4CAF50),
      IucnStatus.nearThreatened => const Color(0xFFFFEB3B),
      IucnStatus.vulnerable => const Color(0xFFFF9800),
      IucnStatus.endangered => const Color(0xFFF44336),
      IucnStatus.criticallyEndangered => const Color(0xFFB71C1C),
      IucnStatus.extinct => const Color(0xFF000000),
    };

String _rarityLabel(IucnStatus status) => switch (status) {
      IucnStatus.leastConcern => 'LC',
      IucnStatus.nearThreatened => 'NT',
      IucnStatus.vulnerable => 'VU',
      IucnStatus.endangered => 'EN',
      IucnStatus.criticallyEndangered => 'CR',
      IucnStatus.extinct => 'EX',
    };
