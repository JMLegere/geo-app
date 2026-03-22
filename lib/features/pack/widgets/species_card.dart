import 'package:flutter/material.dart' hide Durations;

import 'package:earth_nova/core/models/item_instance.dart';
import 'package:earth_nova/core/models/affix.dart';
import 'package:earth_nova/core/models/animal_class.dart';
import 'package:earth_nova/core/models/animal_type.dart';
import 'package:earth_nova/core/models/climate.dart';
import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/food_type.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/models/iucn_status.dart';
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/shared/game_icons.dart';
import 'package:earth_nova/shared/habitat_colors.dart';
import 'package:earth_nova/shared/widgets/prismatic_border.dart';
import 'package:earth_nova/shared/widgets/rarity_badge.dart';
import 'package:earth_nova/features/pack/widgets/species_card_art_zone.dart';
import 'package:earth_nova/features/pack/widgets/species_card_stats.dart';

/// Trading card layout inspired by MtG/Pokémon TCG.
///
/// Visual zones (top → bottom):
///   Title bar  → Art frame  → Type bar  → Info box  → Footer
///
/// Renders purely from [ItemInstance]. No scroll. Fixed 2:3 aspect.
class SpeciesCard extends StatelessWidget {
  const SpeciesCard({
    required this.item,
    this.animate = true,
    super.key,
  });

  final ItemInstance item;
  final bool animate;

  // ── Enum parsers ──────────────────────────────────────────────────────────

  static Habitat? _parseHabitat(String? name) => name == null
      ? null
      : Habitat.values.where((h) => h.name == name).firstOrNull;

  static Continent? _parseContinent(String? name) => name == null
      ? null
      : Continent.values.where((c) => c.name == name).firstOrNull;

  static Climate? _parseClimate(String? name) => name == null
      ? null
      : Climate.values.where((c) => c.name == name).firstOrNull;

  static FoodType? _parseFoodType(String? name) => name == null
      ? null
      : FoodType.values.where((f) => f.name == name).firstOrNull;

  static AnimalClass? _parseAnimalClass(String? name) => name == null
      ? null
      : AnimalClass.values.where((a) => a.name == name).firstOrNull;

  static AnimalType? _parseAnimalType(String? taxonomicClass) =>
      taxonomicClass == null
          ? null
          : AnimalType.fromTaxonomicClass(taxonomicClass);

  // ── Derived values ────────────────────────────────────────────────────────

  Habitat? get _primaryHabitat =>
      _parseHabitat(item.cellHabitatName) ??
      (item.habitats.isNotEmpty ? item.habitats.first : null);

  HabitatPalette? get _palette =>
      _primaryHabitat != null ? HabitatColors.of(_primaryHabitat!) : null;

  int? get _weightGrams {
    final intrinsic =
        item.affixes.where((a) => a.type == AffixType.intrinsic).firstOrNull;
    return intrinsic?.values['weightGrams'] as int?;
  }

  bool get _hasStats =>
      (item.brawn ?? 0) > 0 || (item.wit ?? 0) > 0 || (item.speed ?? 0) > 0;

  String get _fallbackEmoji {
    final cls = _parseAnimalClass(item.animalClassName);
    if (cls != null) return GameIcons.animalClass(cls);
    final type = _parseAnimalType(item.taxonomicClass);
    if (type != null) return GameIcons.animalType(type);
    return GameIcons.category(item.category);
  }

  String get _locationLabel {
    final parts = <String>[];
    if (item.locationDistrict != null) parts.add(item.locationDistrict!);
    if (item.locationCity != null) parts.add(item.locationCity!);
    if (item.locationCountryCode != null) {
      parts.add(GameIcons.countryFlag(item.locationCountryCode!));
    }
    return parts.join(' ');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String formatWeight(int grams) {
    if (grams < 1000) return '$grams g';
    if (grams < 1000000) {
      final kg = grams / 1000.0;
      return kg == kg.roundToDouble()
          ? '${kg.round()} kg'
          : '${kg.toStringAsFixed(1)} kg';
    }
    final tonnes = grams / 1000000.0;
    return tonnes == tonnes.roundToDouble()
        ? '${tonnes.round()} t'
        : '${tonnes.toStringAsFixed(1)} t';
  }

  static String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final palette = _palette;
    // Subtle habitat tint for the title bar and info box backgrounds.
    final tintColor = palette?.primary.withValues(alpha: 0.15) ??
        cs.surfaceContainerHighest.withValues(alpha: 0.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ─── Title bar ──────────────────────────────────────────────
        _TitleBar(
          displayName: item.displayName,
          rarity: item.rarity,
          isFirstDiscovery: item.isFirstDiscovery,
          backgroundColor: tintColor,
        ),

        const SizedBox(height: 2),

        // ─── Art frame (fills available space) ──────────────────────
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: Radii.borderSm,
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: Radii.borderSm,
              child: _buildArtZone(context),
            ),
          ),
        ),

        const SizedBox(height: 2),

        // ─── Type bar (thin habitat-colored divider) ────────────────
        _TypeBar(
          scientificName: item.scientificName,
          animalClass: _parseAnimalClass(item.animalClassName),
          weight: _weightGrams,
          palette: palette,
        ),

        const SizedBox(height: 2),

        // ─── Info box (contained panel) ─────────────────────────────
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: Spacing.sm,
            vertical: Spacing.xs,
          ),
          decoration: BoxDecoration(
            color: tintColor,
            borderRadius: Radii.borderSm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Stat rings
              if (_hasStats)
                Padding(
                  padding: EdgeInsets.only(bottom: Spacing.xs),
                  child: SpeciesCardStats(
                    brawn: item.brawn ?? 0,
                    wit: item.wit ?? 0,
                    speed: item.speed ?? 0,
                    animate: animate,
                  ),
                ),

              // Identity emojis
              _buildIdentityRow(context),
            ],
          ),
        ),

        const SizedBox(height: 2),

        // ─── Footer ─────────────────────────────────────────────────
        _buildFooter(context),
      ],
    );
  }

  // ── Art zone ─────────────────────────────────────────────────────────────

  Widget _buildArtZone(BuildContext context) {
    final habitat = _primaryHabitat;
    if (habitat == null) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Text(_fallbackEmoji, style: const TextStyle(fontSize: 48)),
        ),
      );
    }
    return SpeciesCardArtZone(
      artUrl: item.artUrl,
      primaryHabitat: habitat,
      habitats: item.habitats,
      definitionId: item.definitionId,
      animalClass: _parseAnimalClass(item.animalClassName),
      animalType: _parseAnimalType(item.taxonomicClass),
    );
  }

  // ── Identity row (emoji only, no abbreviations) ──────────────────────────

  Widget _buildIdentityRow(BuildContext context) {
    final emojis = <String>[];

    // All habitats
    for (final h in item.habitats) {
      emojis.add(GameIcons.habitat(h));
    }
    if (emojis.isEmpty) {
      final h = _parseHabitat(item.cellHabitatName);
      if (h != null) emojis.add(GameIcons.habitat(h));
    }

    // All continents
    for (final c in item.continents) {
      emojis.add(GameIcons.continent(c));
    }
    if (item.continents.isEmpty) {
      final c = _parseContinent(item.cellContinentName);
      if (c != null) emojis.add(GameIcons.continent(c));
    }

    // Food
    final food = _parseFoodType(item.foodPreferenceName);
    if (food != null) emojis.add(GameIcons.foodType(food));

    // Climate
    final climate = _parseClimate(item.climateName);
    if (climate != null) emojis.add(GameIcons.climate(climate));

    if (emojis.isEmpty) return const SizedBox.shrink();

    return Center(
      child: Text(
        emojis.join('  '),
        style: const TextStyle(fontSize: 14, letterSpacing: 2),
      ),
    );
  }

  // ── Footer ───────────────────────────────────────────────────────────────

  Widget _buildFooter(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final footerStyle = TextStyle(
      fontSize: 9,
      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
      letterSpacing: 0.2,
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Spacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Location (left)
          if (_locationLabel.isNotEmpty)
            Flexible(
              child: Text(
                _locationLabel,
                style: footerStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          // Provenance (right)
          Text(
            '${item.isWildCaught ? "Wild" : "Bred"} · ${_formatDate(item.acquiredAt)}',
            style: footerStyle,
          ),
        ],
      ),
    );
  }
}

// ── Title bar ────────────────────────────────────────────────────────────────

class _TitleBar extends StatelessWidget {
  const _TitleBar({
    required this.displayName,
    required this.rarity,
    required this.isFirstDiscovery,
    required this.backgroundColor,
  });

  final String displayName;
  final IucnStatus? rarity;
  final bool isFirstDiscovery;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.xs,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: Radii.borderSm,
      ),
      child: Row(
        children: [
          // Name
          Expanded(
            child: Text(
              displayName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
                letterSpacing: -0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // First discovery star
          if (isFirstDiscovery) ...[
            SizedBox(width: Spacing.xs),
            const FirstDiscoveryBadge(size: FirstDiscoveryBadgeSize.pill),
          ],
          // Rarity badge
          if (rarity != null) ...[
            SizedBox(width: Spacing.xs),
            RarityBadge(status: rarity!, size: RarityBadgeSize.medium),
          ],
        ],
      ),
    );
  }
}

// ── Type bar ─────────────────────────────────────────────────────────────────

class _TypeBar extends StatelessWidget {
  const _TypeBar({
    required this.scientificName,
    required this.animalClass,
    required this.weight,
    required this.palette,
  });

  final String? scientificName;
  final AnimalClass? animalClass;
  final int? weight;
  final HabitatPalette? palette;

  @override
  Widget build(BuildContext context) {
    final bgColor = palette?.primary.withValues(alpha: 0.25) ??
        Theme.of(context).colorScheme.surfaceContainerHighest;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: Radii.borderSm,
      ),
      child: Row(
        children: [
          // Class emoji + scientific name
          if (animalClass != null)
            Text(
              GameIcons.animalClass(animalClass!),
              style: const TextStyle(fontSize: 12),
            ),
          if (animalClass != null) SizedBox(width: Spacing.xs),
          Expanded(
            child: Text(
              scientificName ?? '',
              style: TextStyle(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: Colors.white.withValues(alpha: 0.8),
                letterSpacing: 0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Weight (right-aligned)
          if (weight != null)
            Text(
              '${GameIcons.weight} ${SpeciesCard.formatWeight(weight!)}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
    );
  }
}
