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
import 'package:earth_nova/shared/widgets/rarity_badge.dart';
import 'package:earth_nova/shared/widgets/prismatic_border.dart';
import 'package:earth_nova/features/pack/widgets/species_card_art_zone.dart';
import 'package:earth_nova/features/pack/widgets/species_card_stats.dart';

/// Fixed 2:3 aspect ratio species card rendering purely from [ItemInstance].
///
/// Sections (top to bottom):
/// 1. **Name plate** — displayName + rarity badge + ★ badge
/// 2. **Art zone** (Expanded) — watercolor illustration on habitat surface
/// 3. **Stat rings** — animated RGB brawn/wit/speed gauges
/// 4. **Type line** — 🦁 MAM · 🐺 CRN  ⚖️ 62kg
/// 5. **Identity row** — 🌲 FOR  🌎 NA  🍖 CRT  ☀️ TMP
/// 6. **Location** — Downtown Fredericton 🇨🇦
/// 7. **Provenance** — Wild · Mar 21, 2026
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

  // ── Weight formatting ────────────────────────────────────────────────────

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

  // ── Date formatting ──────────────────────────────────────────────────────

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

  // ── Art zone ─────────────────────────────────────────────────────────────

  Widget _buildArtZone(BuildContext context) {
    final habitat = _parseHabitat(item.cellHabitatName) ??
        (item.habitats.isNotEmpty ? item.habitats.first : null);

    if (habitat == null) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: Radii.borderMd,
        ),
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

  // ── Type line ─────────────────────────────────────────────────────────────

  Widget _buildTypeLine(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final parts = <String>[];

    final animalType = _parseAnimalType(item.taxonomicClass);
    final animalClass = _parseAnimalClass(item.animalClassName);

    if (animalType != null) {
      parts.add(
          '${GameIcons.animalTypeIcon(animalType)} ${GameIcons.animalTypeAbbrev(animalType)}');
    }
    if (animalClass != null) {
      parts.add(
          '${GameIcons.animalClass(animalClass)} ${GameIcons.animalClassAbbrev(animalClass)}');
    }

    final weight = _weightGrams;
    if (weight != null) {
      parts.add('${GameIcons.weight} ${formatWeight(weight)}');
    }

    if (parts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: Spacing.xxs),
      child: Text(
        parts.join('  '),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }

  // ── Identity row ──────────────────────────────────────────────────────────

  Widget _buildIdentityRow(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final parts = <String>[];

    final habitat = _parseHabitat(item.cellHabitatName) ??
        (item.habitats.isNotEmpty ? item.habitats.first : null);
    if (habitat != null) {
      parts.add(
          '${GameIcons.habitat(habitat)} ${GameIcons.habitatAbbrev(habitat)}');
    }

    final continent = _parseContinent(item.cellContinentName) ??
        (item.continents.isNotEmpty ? item.continents.first : null);
    if (continent != null) {
      parts.add(
          '${GameIcons.continent(continent)} ${GameIcons.continentAbbrev(continent)}');
    }

    final food = _parseFoodType(item.foodPreferenceName);
    if (food != null) {
      parts
          .add('${GameIcons.foodType(food)} ${GameIcons.foodTypeAbbrev(food)}');
    }

    final climate = _parseClimate(item.climateName);
    if (climate != null) {
      parts.add(
          '${GameIcons.climate(climate)} ${GameIcons.climateAbbrev(climate)}');
    }

    if (parts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: Spacing.xxs),
      child: Text(
        parts.join('  '),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }

  // ── Footer row ───────────────────────────────────────────────────────────

  Widget _buildFooterRow(BuildContext context, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: Spacing.xxs),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: Theme.of(context)
              .colorScheme
              .onSurfaceVariant
              .withValues(alpha: 0.7),
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name plate
        _NamePlate(
          displayName: item.displayName,
          scientificName: item.scientificName,
          rarity: item.rarity,
          isFirstDiscovery: item.isFirstDiscovery,
        ),

        SizedBox(height: Spacing.md),

        // Art zone (~50% of card)
        Expanded(child: _buildArtZone(context)),

        SizedBox(height: Spacing.sm),

        // Stat rings
        if (_hasStats)
          Padding(
            padding: EdgeInsets.only(bottom: Spacing.sm),
            child: SpeciesCardStats(
              brawn: item.brawn ?? 0,
              wit: item.wit ?? 0,
              speed: item.speed ?? 0,
              animate: animate,
            ),
          ),

        // Type line: 🦁 MAM · 🐺 CRN  ⚖️ 62kg
        _buildTypeLine(context),

        // Identity row: 🌲 FOR  🌎 NA  🍖 CRT  ☀️ TMP
        _buildIdentityRow(context),

        // Location: Downtown Fredericton 🇨🇦
        if (_locationLabel.isNotEmpty) _buildFooterRow(context, _locationLabel),

        // Provenance: Wild · Mar 21, 2026
        _buildFooterRow(
          context,
          '${item.isWildCaught ? "Wild" : "Bred"} · ${_formatDate(item.acquiredAt)}',
        ),
      ],
    );
  }
}

// ── Name plate ────────────────────────────────────────────────────────────────

class _NamePlate extends StatelessWidget {
  const _NamePlate({
    required this.displayName,
    required this.scientificName,
    required this.rarity,
    required this.isFirstDiscovery,
  });

  final String displayName;
  final String? scientificName;
  final IucnStatus? rarity;
  final bool isFirstDiscovery;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Display name + ★ badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isFirstDiscovery) ...[
                    SizedBox(width: Spacing.xs),
                    const FirstDiscoveryBadge(
                      size: FirstDiscoveryBadgeSize.pill,
                    ),
                  ],
                ],
              ),
              if (scientificName != null) ...[
                SizedBox(height: Spacing.xxs),
                Text(
                  scientificName!,
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.05,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (rarity != null) ...[
          SizedBox(width: Spacing.md),
          RarityBadge(
            status: rarity!,
            size: RarityBadgeSize.medium,
          ),
        ],
      ],
    );
  }
}
