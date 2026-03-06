import 'package:flutter/material.dart' hide Durations;
import 'package:fog_of_world/core/models/iucn_status.dart';
import 'package:fog_of_world/core/models/species.dart';
import 'package:fog_of_world/shared/design_tokens.dart';
import 'package:fog_of_world/shared/earth_nova_theme.dart';
import 'package:fog_of_world/shared/widgets/rarity_badge.dart';

/// Shows a modal bottom sheet with full or partial species details.
///
/// ## Collected species
/// Full details: common name, scientific name (italic), taxonomic class,
/// habitat list, continent list, IUCN status badge.
///
/// ## Uncollected species
/// Minimal view: "Unknown Species" title, habitat hint, exploration prompt.
///
/// ## Usage
/// ```dart
/// showSpeciesDetailSheet(context, species: record, isCollected: true);
/// ```
void showSpeciesDetailSheet(
  BuildContext context, {
  required SpeciesRecord species,
  required bool isCollected,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => SpeciesDetailSheet(
      species: species,
      isCollected: isCollected,
    ),
  );
}

/// The bottom sheet widget itself. Exported for testing.
class SpeciesDetailSheet extends StatelessWidget {
  final SpeciesRecord species;
  final bool isCollected;

  const SpeciesDetailSheet({
    super.key,
    required this.species,
    required this.isCollected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xxxl)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: isCollected
                  ? _CollectedContent(species: species)
                  : _UncollectedContent(species: species),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Collected content
// ---------------------------------------------------------------------------

class _CollectedContent extends StatelessWidget {
  final SpeciesRecord species;

  const _CollectedContent({required this.species});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header: name + rarity badge
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    species.commonName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    species.scientificName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF6B7280),
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _RarityBadge(status: species.iucnStatus),
          ],
        ),

        const SizedBox(height: 16),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        const SizedBox(height: 16),

        // Taxonomic class
        _DetailRow(
          label: 'Class',
          value: species.taxonomicClass,
        ),

        const SizedBox(height: 10),

        // Habitats
        _DetailRow(
          label: 'Habitats',
          value: species.habitats.map((h) => h.displayName).join(', '),
        ),

        const SizedBox(height: 10),

        // Continents
        _DetailRow(
          label: 'Continents',
          value: species.continents.map((c) => c.displayName).join(', '),
        ),

        const SizedBox(height: 10),

        // IUCN Status
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(
              width: 80,
              child: Text(
                'Status',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
            _StatusPill(status: species.iucnStatus),
          ],
        ),

        const SizedBox(height: 16),

        // Collected indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFBBF7D0),
              width: 1,
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: Color(0xFF16A34A),
              ),
              SizedBox(width: 6),
              Text(
                'Added to your collection',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF16A34A),
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
// Uncollected content
// ---------------------------------------------------------------------------

class _UncollectedContent extends StatelessWidget {
  final SpeciesRecord species;

  const _UncollectedContent({required this.species});

  @override
  Widget build(BuildContext context) {
    // Reveal habitat hint without exposing identity
    final habitatHint = species.habitats.isNotEmpty
        ? 'Found in ${species.habitats.first.displayName.toLowerCase()} areas'
        : 'Found in unknown areas';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mystery icon
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Center(
            child: Text('?', style: TextStyle(fontSize: 28, color: Color(0xFF9CA3AF))),
          ),
        ),

        const SizedBox(height: 12),

        const Text(
          'Unknown Species',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
            letterSpacing: -0.3,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          habitatHint,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
          ),
        ),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
              width: 1,
            ),
          ),
          child: const Row(
            children: [
              Icon(Icons.explore_outlined, size: 18, color: Color(0xFF6B7280)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Explore more to discover this species',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    height: 1.4,
                  ),
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
// Shared sub-widgets
// ---------------------------------------------------------------------------

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ),
      ],
    );
  }
}

class _RarityBadge extends StatelessWidget {
  final IucnStatus status;

  const _RarityBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _rarityColor(status);
    final label = _rarityLabel(status);
    final fullLabel = status.displayName;
    final isLight = status == IucnStatus.nearThreatened;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isLight ? const Color(0xFF1A1A2E) : Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            fullLabel,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: (isLight ? const Color(0xFF1A1A2E) : Colors.white)
                  .withValues(alpha: 0.8),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IucnStatus status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _rarityColor(status);
    final isLight = status == IucnStatus.nearThreatened;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isLight ? const Color(0xFF92700A) : color,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Color / label helpers (duplicated from species_card for self-contained file)
// ---------------------------------------------------------------------------

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
