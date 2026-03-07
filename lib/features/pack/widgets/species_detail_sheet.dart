import 'package:flutter/material.dart' hide Durations;
import 'package:fog_of_world/core/models/iucn_status.dart';
import 'package:fog_of_world/core/models/item_definition.dart';
import 'package:fog_of_world/shared/design_tokens.dart';
import 'package:fog_of_world/shared/earth_nova_theme.dart';

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
  required FaunaDefinition species,
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
  final FaunaDefinition species;
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
  final FaunaDefinition species;

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
                    species.displayName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    species.scientificName,
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _RarityBadge(status: species.rarity!),
          ],
        ),

        const SizedBox(height: 16),
        Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
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
            SizedBox(
              width: 80,
              child: Text(
                'Status',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            _StatusPill(status: species.rarity!),
          ],
        ),

        const SizedBox(height: 16),

        // Collected indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: context.earthNova.successColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: context.earthNova.successColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: context.earthNova.successColor,
              ),
              const SizedBox(width: 6),
              Text(
                'Added to your collection',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.earthNova.successColor,
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
  final FaunaDefinition species;

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
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text('?', style: TextStyle(fontSize: 28, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        ),

        const SizedBox(height: 12),

        Text(
          'Unknown Species',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
            letterSpacing: -0.3,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          habitatHint,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.explore_outlined, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Explore more to discover this species',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
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
              color: isLight ? Theme.of(context).colorScheme.onSurface : Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            fullLabel,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: (isLight ? Theme.of(context).colorScheme.onSurface : Colors.white)
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
          color: isLight ? Theme.of(context).colorScheme.onSurface : color,
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
