import 'package:flutter/material.dart' hide Durations;

import 'package:earth_nova/core/models/affix.dart';
import 'package:earth_nova/core/models/animal_class.dart';
import 'package:earth_nova/core/models/animal_size.dart';
import 'package:earth_nova/core/models/animal_type.dart';
import 'package:earth_nova/core/models/climate.dart';
import 'package:earth_nova/core/models/food_type.dart';
import 'package:earth_nova/core/models/item_instance.dart';
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/shared/earth_nova_theme.dart';
import 'package:earth_nova/shared/constants.dart';
import 'package:earth_nova/shared/game_icons.dart';
import 'package:earth_nova/shared/widgets/prismatic_border.dart';
import 'package:earth_nova/shared/widgets/rarity_badge.dart';

/// Shows a modal bottom sheet with full item instance details.
///
/// Displays species identity (name, scientific name, rarity), properties
/// (type, class, habitat, region, climate, diet), stat bars
/// (brawn/wit/speed from ItemInstance), and instance provenance
/// (wild/bred, date acquired, cell ID).
///
/// Usage:
/// ```dart
/// showItemDetailSheet(context, item: instance);
/// ```
void showItemDetailSheet(
  BuildContext context, {
  required ItemInstance item,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ItemDetailSheet(item: item),
  );
}

/// The bottom sheet widget itself. Exported for testability.
class ItemDetailSheet extends StatelessWidget {
  const ItemDetailSheet({
    super.key,
    required this.item,
  });

  final ItemInstance item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.85,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(Radii.xxxl)),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle + close button
                  Padding(
                    padding:
                        EdgeInsets.only(top: Spacing.md, bottom: Spacing.xs),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Spacer for alignment
                        SizedBox(width: 40),
                        // Drag handle indicator
                        Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: cs.onSurface.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        // Close button
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: IconButton(
                            icon: Icon(Icons.close, size: 20),
                            color: cs.onSurface,
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      Spacing.lg,
                      Spacing.sm,
                      Spacing.lg,
                      Spacing.xxl,
                    ),
                    child: _ItemDetailContent(item: item),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Main content
// ---------------------------------------------------------------------------

class _ItemDetailContent extends StatelessWidget {
  const _ItemDetailContent({required this.item});

  final ItemInstance item;

  static AnimalClass? _parseAnimalClass(String? name) => name == null
      ? null
      : AnimalClass.values.where((a) => a.name == name).firstOrNull;

  static AnimalType? _parseAnimalType(String? taxonomicClass) =>
      taxonomicClass == null
          ? null
          : AnimalType.fromTaxonomicClass(taxonomicClass);

  static Climate? _parseClimate(String? name) => name == null
      ? null
      : Climate.values.where((c) => c.name == name).firstOrNull;

  static FoodType? _parseFoodType(String? name) => name == null
      ? null
      : FoodType.values.where((f) => f.name == name).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final displayName =
        item.displayName.isNotEmpty ? item.displayName : 'Unknown Species';
    final scientificName = item.scientificName;
    final rarity = item.rarity;
    final habitats = item.habitats;
    final continents = item.continents;

    // Parse enriched fields from denormalized strings.
    final animalType = _parseAnimalType(item.taxonomicClass);
    final animalClass = _parseAnimalClass(item.animalClassName);
    final climate = _parseClimate(item.climateName);
    final foodPreference = _parseFoodType(item.foodPreferenceName);

    // Find intrinsic affix for weight (per-instance).
    final intrinsic =
        item.affixes.where((a) => a.type == AffixType.intrinsic).firstOrNull;

    // Determine if we have any property rows to show.
    final hasProperties = animalType != null ||
        animalClass != null ||
        habitats.isNotEmpty ||
        continents.isNotEmpty ||
        climate != null ||
        rarity != null ||
        foodPreference != null;

    // Determine if we have stats.
    final hasStats =
        (item.brawn ?? 0) > 0 || (item.wit ?? 0) > 0 || (item.speed ?? 0) > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Header: name + rarity badge ──────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Species name with optional ★ first-discovery pill badge.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                            letterSpacing: -0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.isFirstDiscovery) ...[
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
                      scientificName,
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: cs.onSurfaceVariant,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (rarity != null) ...[
              SizedBox(width: Spacing.md),
              RarityBadge(
                status: rarity,
                size: RarityBadgeSize.medium,
              ),
            ],
          ],
        ),

        SizedBox(height: Spacing.lg),
        Divider(height: 1, color: cs.outlineVariant),
        SizedBox(height: Spacing.lg),

        // ── Properties ───────────────────────────────────────────────────
        if (animalType != null) ...[
          _PropertyRow(
            label: 'Type',
            value:
                '${GameIcons.animalType(animalType)} ${animalType.name[0].toUpperCase()}${animalType.name.substring(1)}',
          ),
          SizedBox(height: Spacing.sm),
        ],
        if (animalClass != null) ...[
          _PropertyRow(
            label: 'Class',
            value:
                '${GameIcons.animalClass(animalClass)} ${animalClass.displayName}',
          ),
          SizedBox(height: Spacing.sm),
        ] else if (animalType != null) ...[
          _PropertyRow(
            label: 'Class',
            value: 'Awaiting enrichment. Check back soon.',
          ),
          SizedBox(height: Spacing.sm),
        ],
        if (habitats.isNotEmpty) ...[
          _PropertyRow(
            label: 'Habitat',
            value: habitats
                .map((h) => '${GameIcons.habitat(h)} ${h.displayName}')
                .join('  '),
          ),
          SizedBox(height: Spacing.sm),
        ],
        if (continents.isNotEmpty) ...[
          _PropertyRow(
            label: 'Region',
            value: continents
                .map((c) => '${GameIcons.continent(c)} ${c.displayName}')
                .join('  '),
          ),
          SizedBox(height: Spacing.sm),
        ],
        if (climate != null) ...[
          _PropertyRow(
            label: 'Climate',
            value: '${GameIcons.climate(climate)} ${climate.displayName}',
          ),
          SizedBox(height: Spacing.sm),
        ] else if (animalType != null) ...[
          _PropertyRow(
            label: 'Climate',
            value: 'Awaiting enrichment. Check back soon.',
          ),
          SizedBox(height: Spacing.sm),
        ],
        if (rarity != null) ...[
          _PropertyRow(
            label: 'Rarity',
            value:
                '${GameIcons.rarity(rarity)} ${EarthNovaTheme.rarityLabel(rarity)}',
          ),
          SizedBox(height: Spacing.sm),
        ],
        if (foodPreference != null) ...[
          _PropertyRow(
            label: 'Diet',
            value:
                '${GameIcons.foodType(foodPreference)} ${foodPreference.displayName}',
          ),
          SizedBox(height: Spacing.sm),
        ] else if (animalType != null) ...[
          _PropertyRow(
            label: 'Diet',
            value: 'Awaiting enrichment. Check back soon.',
          ),
          SizedBox(height: Spacing.sm),
        ],

        // Show divider if we had any property rows
        if (hasProperties) ...[
          SizedBox(height: Spacing.xs),
          Divider(height: 1, color: cs.outlineVariant),
          SizedBox(height: Spacing.lg),
        ],

        // ── Size & Weight ─────────────────────────────────────────────────
        if (item.sizeName != null) ...[
          _PropertyRow(
            label: 'Size',
            value: '${GameIcons.size} ${_formatSize(item.sizeName!)}',
          ),
          if (intrinsic != null &&
              intrinsic.values.containsKey(kWeightAffixKey)) ...[
            SizedBox(height: Spacing.sm),
            _PropertyRow(
              label: 'Weight',
              value:
                  '${GameIcons.weight} ${_formatWeight((intrinsic.values[kWeightAffixKey] as num).round())}',
            ),
          ],
          SizedBox(height: Spacing.lg),
          Divider(height: 1, color: cs.outlineVariant),
          SizedBox(height: Spacing.lg),
        ] else if (intrinsic != null &&
            intrinsic.values.containsKey(kSizeAffixKey)) ...[
          _PropertyRow(
            label: 'Size',
            value:
                '${GameIcons.size} ${_formatSize(intrinsic.values[kSizeAffixKey] as String)}',
          ),
          if (intrinsic.values.containsKey(kWeightAffixKey)) ...[
            SizedBox(height: Spacing.sm),
            _PropertyRow(
              label: 'Weight',
              value:
                  '${GameIcons.weight} ${_formatWeight((intrinsic.values[kWeightAffixKey] as num).round())}',
            ),
          ],
          SizedBox(height: Spacing.lg),
          Divider(height: 1, color: cs.outlineVariant),
          SizedBox(height: Spacing.lg),
        ],

        // ── Stat bars ────────────────────────────────────────────────────
        if (hasStats) ...[
          Text(
            'Stats',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: Spacing.sm),
          _StatBar(
            icon: GameIcons.brawn,
            label: 'Brawn',
            value: item.brawn ?? 0,
            color: const Color(0xFFE57373), // muted red
          ),
          SizedBox(height: Spacing.xs),
          _StatBar(
            icon: GameIcons.wit,
            label: 'Wit',
            value: item.wit ?? 0,
            color: const Color(0xFF64B5F6), // muted blue
          ),
          SizedBox(height: Spacing.xs),
          _StatBar(
            icon: GameIcons.speed,
            label: 'Speed',
            value: item.speed ?? 0,
            color: const Color(0xFF81C784), // muted green
          ),
          SizedBox(height: Spacing.lg),
          Divider(height: 1, color: cs.outlineVariant),
          SizedBox(height: Spacing.lg),
        ],

        // ── Instance provenance ──────────────────────────────────────────
        Text(
          'Instance',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: cs.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: Spacing.sm),
        _PropertyRow(
          label: 'Origin',
          value: item.isWildCaught
              ? '${GameIcons.wildCaught} Wild caught'
              : '${GameIcons.bred} Bred',
        ),
        SizedBox(height: Spacing.xs),
        _PropertyRow(
          label: 'Found',
          value: _formatDate(item.acquiredAt),
        ),
        if (item.acquiredInCellId != null) ...[
          SizedBox(height: Spacing.xs),
          _PropertyRow(
            label: 'Cell',
            value: _truncateCellId(item.acquiredInCellId!),
          ),
        ],
      ],
    );
  }

  static String _formatDate(DateTime dt) {
    final months = [
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

  /// Capitalize an [AnimalSize] enum name or raw string for display.
  static String _formatSize(String sizeEnumName) {
    try {
      final size = AnimalSize.fromString(sizeEnumName);
      return '${size.name[0].toUpperCase()}${size.name.substring(1)}';
    } on ArgumentError {
      return sizeEnumName;
    }
  }

  /// Format weight in grams to human-friendly units.
  ///
  /// - Under 1 kg → "123 g"
  /// - 1 kg to 999 kg → "45.2 kg" (1 decimal)
  /// - 1,000 kg+ → "12.5 t" (metric tonnes, 1 decimal)
  static String _formatWeight(int grams) {
    if (grams < 1000) return '$grams g';
    if (grams < 1000000) {
      final kg = grams / 1000.0;
      // Drop decimal if it's a whole number.
      return kg == kg.roundToDouble()
          ? '${kg.round()} kg'
          : '${kg.toStringAsFixed(1)} kg';
    }
    final tonnes = grams / 1000000.0;
    return tonnes == tonnes.roundToDouble()
        ? '${tonnes.round()} t'
        : '${tonnes.toStringAsFixed(1)} t';
  }

  static String _truncateCellId(String cellId) {
    if (cellId.length <= 16) return cellId;
    return '${cellId.substring(0, 8)}…${cellId.substring(cellId.length - 6)}';
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _PropertyRow extends StatelessWidget {
  const _PropertyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatBar extends StatelessWidget {
  const _StatBar({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final String icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fraction = (value / kStatMax.toDouble()).clamp(0.0, 1.0);

    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 14)),
        SizedBox(width: Spacing.xs),
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: Radii.borderSm,
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: cs.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        SizedBox(width: Spacing.xs),
        SizedBox(
          width: 24,
          child: Text(
            '$value',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
