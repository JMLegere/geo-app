import 'package:flutter/material.dart' hide Durations;

import 'package:earth_nova/core/models/item_instance.dart';
import 'package:earth_nova/core/models/item_definition.dart';
import 'package:earth_nova/core/models/affix.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/models/iucn_status.dart';
import 'package:earth_nova/core/models/food_type.dart';
import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/shared/game_icons.dart';
import 'package:earth_nova/shared/widgets/rarity_badge.dart';
import 'package:earth_nova/shared/widgets/prismatic_border.dart';
import 'package:earth_nova/features/pack/widgets/species_card_art_zone.dart';
import 'package:earth_nova/features/pack/widgets/species_card_stats.dart';

/// Fixed 2:3 aspect ratio species card combining all identity + art + stats.
///
/// Sections (top to bottom):
/// 1. **Name plate** — displayName + scientificName + rarity badge + ★ badge
/// 2. **Art zone** (~55% height) — watercolor illustration on habitat surface
/// 3. **Stats** — animated RGB brawn/wit/speed bars
/// 4. **Identity strip** — habitat · continent · weight · diet
/// 5. **Scrollable section** — type/class, climate/season, provenance, cell
class SpeciesCard extends StatelessWidget {
  const SpeciesCard({
    required this.item,
    this.definition,
    this.animate = true,
    super.key,
  });

  final ItemInstance item;
  final FaunaDefinition? definition;
  final bool animate;

  // ── Derived values ────────────────────────────────────────────────────────

  String get _displayName => item.displayName.isNotEmpty
      ? item.displayName
      : (definition?.displayName ?? '???');

  String? get _scientificName =>
      item.scientificName ?? definition?.scientificName;

  IucnStatus? get _rarity => item.rarity ?? definition?.rarity;

  List<Habitat> get _habitats =>
      item.habitats.isNotEmpty ? item.habitats : (definition?.habitats ?? []);

  List<Continent> get _continents => item.continents.isNotEmpty
      ? item.continents
      : (definition?.continents ?? []);

  Habitat? get _primaryHabitat => _habitats.isNotEmpty ? _habitats.first : null;

  String? get _artUrl => item.artUrl ?? definition?.artUrl;

  // Stats from definition → instance intrinsic affix → 0
  int get _brawn => (definition?.brawn) ?? (intrinsic?['brawn'] as int?) ?? 0;

  int get _wit => (definition?.wit) ?? (intrinsic?['wit'] as int?) ?? 0;

  int get _speed => (definition?.speed) ?? (intrinsic?['speed'] as int?) ?? 0;

  Map<String, dynamic>? get intrinsic => item.affixes
      .where((a) => a.type == AffixType.intrinsic)
      .firstOrNull
      ?.values;

  int? get _weightGrams => intrinsic?['weightGrams'] as int?;

  FoodType? get _foodPreference => definition?.foodPreference;

  String get _fallbackEmoji {
    final cls = definition?.animalClass;
    if (cls != null) return GameIcons.animalClass(cls);
    if (definition != null) return GameIcons.fauna(definition!);
    return GameIcons.category(item.category);
  }

  // ── Weight formatting ───────────────────────────────────────────────────

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

  // ── Date formatting ───────────────────────────────────────────────────

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
      'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  // ── Cell ID truncation ─────────────────────────────────────────────────

  static String _truncateCellId(String id) {
    if (id.length <= 16) return id;
    return '${id.substring(0, 8)}…${id.substring(id.length - 6)}';
  }

  // ── Art zone ──────────────────────────────────────────────────────────

  Widget _buildArtZone(BuildContext context) {
    if (_primaryHabitat == null) {
      final cs = Theme.of(context).colorScheme;
      return Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: Radii.borderMd,
        ),
        child: Center(
          child: Text(_fallbackEmoji, style: const TextStyle(fontSize: 48)),
        ),
      );
    }

    return SpeciesCardArtZone(
      artUrl: _artUrl,
      primaryHabitat: _primaryHabitat!,
      habitats: _habitats,
      definitionId: definition?.id ?? item.definitionId,
      animalClass: definition?.animalClass,
      animalType: definition?.animalType,
    );
  }

  // ── Identity strip ───────────────────────────────────────────────────

  Widget _buildIdentityStrip(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = <Widget>[];

    // Habitat(s)
    if (_habitats.isNotEmpty) {
      items.add(_IdentityChip(
        label: _habitats
            .map((h) => '${GameIcons.habitat(h)} ${h.displayName}')
            .join('  '),
        color: cs.onSurfaceVariant,
      ));
    }

    // Continent
    if (_continents.isNotEmpty) {
      items.add(_IdentityChip(
        label: _continents
            .map((c) => '${GameIcons.continent(c)} ${c.displayName}')
            .join('  '),
        color: cs.onSurfaceVariant,
      ));
    }

    // Weight
    if (_weightGrams != null) {
      items.add(_IdentityChip(
        label: '${GameIcons.weight} ${formatWeight(_weightGrams!)}',
        color: cs.onSurfaceVariant,
      ));
    }

    // Diet
    if (_foodPreference != null) {
      items.add(_IdentityChip(
        label:
            '${GameIcons.foodType(_foodPreference!)} ${_foodPreference!.displayName}',
        color: cs.onSurfaceVariant,
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.xs,
      children: items,
    );
  }

  // ── Scrollable section ─────────────────────────────────────────────────

  Widget _buildScrollSection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rows = <Widget>[];

    // Animal type + class
    final typeLabel = definition?.animalType?.name;
    final classLabel = definition?.animalClass?.displayName;
    if (typeLabel != null || classLabel != null) {
      rows.add(_MetadataRow(
        label: _fallbackEmoji,
        value: [
          if (typeLabel != null)
            typeLabel[0].toUpperCase() + typeLabel.substring(1),
          if (classLabel != null) classLabel,
        ].join(' · '),
      ));
    }

    // Climate + season
    final climate = definition?.climate;
    final season = definition?.seasonRestriction;
    if (climate != null || season != null) {
      final seasonText = season != null
          ? '${GameIcons.season(season)} ${season.displayName}'
          : '${GameIcons.climate(climate!)} ${climate.displayName}';
      rows.add(_MetadataRow(
        label: '🌡️',
        value: season != null ? '$seasonText  ☀️ Year-round' : seasonText,
      ));
    }

    // Provenance + date
    rows.add(_MetadataRow(
      label: '📍',
      value:
          '${item.isWildCaught ? 'Wild' : 'Bred'} · ${_formatDate(item.acquiredAt)}',
    ));

    // Cell
    if (item.acquiredInCellId != null) {
      rows.add(_MetadataRow(
        label: '📦',
        value: 'Cell ${_truncateCellId(item.acquiredInCellId!)}',
      ));
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: cs.outlineVariant.withValues(alpha: 0.4)),
        SizedBox(height: Spacing.sm),
        ...rows,
      ],
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Collect items into column
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Name plate ─────────────────────────────────────────────────
        _NamePlate(
          displayName: _displayName,
          scientificName: _scientificName,
          rarity: _rarity,
          isFirstDiscovery: item.isFirstDiscovery,
        ),

        SizedBox(height: Spacing.md),

        // ── Art zone ─────────────────────────────────────────────────
        AspectRatio(
          aspectRatio: 1 / 1.1, // slightly taller than square for portrait feel
          child: _buildArtZone(context),
        ),

        SizedBox(height: Spacing.md),

        // ── Stats ────────────────────────────────────────────────────
        if (_hasStats)
          SpeciesCardStats(
            brawn: _brawn,
            wit: _wit,
            speed: _speed,
            animate: animate,
          ),

        if (_hasStats) SizedBox(height: Spacing.md),

        // ── Identity strip ────────────────────────────────────────────
        _buildIdentityStrip(context),

        // ── Scrollable section ──────────────────────────────────────
        _buildScrollSection(context),
      ],
    );
  }

  bool get _hasStats => _brawn > 0 || _wit > 0 || _speed > 0;
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

// ── Identity chip ─────────────────────────────────────────────────────────────

class _IdentityChip extends StatelessWidget {
  const _IdentityChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: Radii.borderSm,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1.2,
        ),
      ),
    );
  }
}

// ── Metadata row ───────────────────────────────────────────────────────────────

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: Spacing.xs),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 13)),
          SizedBox(width: Spacing.xs),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
