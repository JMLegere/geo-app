import 'package:flutter/material.dart';
import 'package:fog_of_world/core/models/habitat.dart';
import 'package:fog_of_world/core/models/iucn_status.dart';
import 'package:fog_of_world/core/models/species.dart';

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
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
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
    final habitatColor = _habitatColor(primaryHabitat);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Artwork placeholder — watercolor gradient fill
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  habitatColor.withValues(alpha: 0.35),
                  habitatColor.withValues(alpha: 0.12),
                ],
              ),
            ),
            child: Stack(
              children: [
                // Habitat emoji hint
                Center(
                  child: Text(
                    _habitatEmoji(primaryHabitat),
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
                // Rarity badge — top right
                Positioned(
                  top: 6,
                  right: 6,
                  child: _RarityBadge(status: species.iucnStatus),
                ),
              ],
            ),
          ),
        ),

        // Info panel
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                species.commonName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                  letterSpacing: -0.1,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 12,
                    color: Color(0xFF16A34A),
                  ),
                  const SizedBox(width: 3),
                  const Text(
                    '✓ Collected',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF16A34A),
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
            color: const Color(0xFFF3F4F6),
            child: Center(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    '?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Info panel
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '???',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9CA3AF),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Not discovered',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFD1D5DB),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Rarity badge
// ---------------------------------------------------------------------------

class _RarityBadge extends StatelessWidget {
  final IucnStatus status;

  const _RarityBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _rarityColor(status);
    final label = _rarityLabel(status);
    final isLight = status == IucnStatus.nearThreatened;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: isLight ? const Color(0xFF1A1A2E) : Colors.white,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Color / label helpers
// ---------------------------------------------------------------------------

/// Habitat placeholder art colors per task spec.
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
      Habitat.freshwater => '💧',
      Habitat.saltwater => '🌊',
      Habitat.swamp => '🌿',
      Habitat.mountain => '⛰️',
      Habitat.desert => '🏜️',
    };

/// IUCN rarity badge colors per task spec:
/// LC=green, NT=yellow, VU=orange, EN=red, CR=darkRed, EX=black.
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
