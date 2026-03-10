import 'package:flutter/material.dart' hide Durations;

import 'package:earth_nova/core/models/affix.dart';
import 'package:earth_nova/core/models/animal_size.dart';
import 'package:earth_nova/core/models/item_definition.dart';
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
/// (type, class, habitat, region, climate, diet, season), stat bars
/// (brawn/wit/speed from intrinsic affix), and instance provenance
/// (wild/bred, date acquired, cell ID).
///
/// Usage:
/// ```dart
/// showItemDetailSheet(context, item: instance, definition: def);
/// ```
void showItemDetailSheet(
  BuildContext context, {
  required ItemInstance item,
  FaunaDefinition? definition,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ItemDetailSheet(item: item, definition: definition),
  );
}

/// The bottom sheet widget itself. Exported for testability.
class ItemDetailSheet extends StatelessWidget {
  const ItemDetailSheet({
    super.key,
    required this.item,
    this.definition,
  });

  final ItemInstance item;
  final FaunaDefinition? definition;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xxxl)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Padding(
                padding: EdgeInsets.only(top: Spacing.md, bottom: Spacing.xs),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
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
                child: _ItemDetailContent(item: item, definition: definition),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Main content
// ---------------------------------------------------------------------------

class _ItemDetailContent extends StatelessWidget {
  const _ItemDetailContent({required this.item, required this.definition});

  final ItemInstance item;
  final FaunaDefinition? definition;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final def = definition;

    // Prefer denormalized fields from ItemInstance, fall back to definition.
    final displayName = item.displayName.isNotEmpty
        ? item.displayName
        : (def?.displayName ?? 'Unknown Species');
    final scientificName = item.scientificName ?? def?.scientificName;
    final rarity = item.rarity ?? def?.rarity;
    final habitats =
        item.habitats.isNotEmpty ? item.habitats : (def?.habitats ?? const []);
    final continents = item.continents.isNotEmpty
        ? item.continents
        : (def?.continents ?? const []);

    // Find intrinsic affix for stat bars
    final intrinsic =
        item.affixes.where((a) => a.type == AffixType.intrinsic).firstOrNull;

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
        // Enriched-only fields (animalType, animalClass, climate,
        // foodPreference, seasonRestriction) still require definition.
        // Denormalized fields (habitat, region, rarity) use instance values.
        if (def != null) ...[
          if (def.animalType != null)
            _PropertyRow(
              label: 'Type',
              value:
                  '${GameIcons.animalType(def.animalType!)} ${def.animalType!.name[0].toUpperCase()}${def.animalType!.name.substring(1)}',
            ),
          SizedBox(height: Spacing.sm),
          _PropertyRow(
            label: 'Class',
            value: def.animalClass != null
                ? '${GameIcons.animalClass(def.animalClass!)} ${def.animalClass!.displayName}'
                : 'Awaiting enrichment. Check back soon.',
          ),
        ],
        if (habitats.isNotEmpty) ...[
          SizedBox(height: Spacing.sm),
          _PropertyRow(
            label: 'Habitat',
            value: habitats
                .map((h) => '${GameIcons.habitat(h)} ${h.displayName}')
                .join('  '),
          ),
        ],
        if (continents.isNotEmpty) ...[
          SizedBox(height: Spacing.sm),
          _PropertyRow(
            label: 'Region',
            value: continents
                .map((c) => '${GameIcons.continent(c)} ${c.displayName}')
                .join('  '),
          ),
        ],
        if (def != null) ...[
          SizedBox(height: Spacing.sm),
          _PropertyRow(
            label: 'Climate',
            value: def.climate != null
                ? '${GameIcons.climate(def.climate!)} ${def.climate!.displayName}'
                : 'Awaiting enrichment. Check back soon.',
          ),
        ],
        if (rarity != null) ...[
          SizedBox(height: Spacing.sm),
          _PropertyRow(
            label: 'Rarity',
            value:
                '${GameIcons.rarity(rarity)} ${EarthNovaTheme.rarityLabel(rarity)}',
          ),
        ],
        if (def != null) ...[
          SizedBox(height: Spacing.sm),
          _PropertyRow(
            label: 'Diet',
            value: def.foodPreference != null
                ? '${GameIcons.foodType(def.foodPreference!)} ${def.foodPreference!.displayName}'
                : 'Awaiting enrichment. Check back soon.',
          ),
          if (def.seasonRestriction != null) ...[
            SizedBox(height: Spacing.sm),
            _PropertyRow(
              label: 'Season',
              value:
                  '${GameIcons.season(def.seasonRestriction!)} ${def.seasonRestriction!.displayName}',
            ),
          ],
        ],
        // Show divider if we had any property rows
        if (def != null ||
            habitats.isNotEmpty ||
            continents.isNotEmpty ||
            rarity != null) ...[
          SizedBox(height: Spacing.lg),
          Divider(height: 1, color: cs.outlineVariant),
          SizedBox(height: Spacing.lg),
        ],

        // ── Size & Weight ─────────────────────────────────────────────────
        if (intrinsic != null &&
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
        if (intrinsic != null) ...[
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
            value: (intrinsic.values['brawn'] as num?)?.round() ?? 0,
            color: const Color(0xFFE57373), // muted red
          ),
          SizedBox(height: Spacing.xs),
          _StatBar(
            icon: GameIcons.wit,
            label: 'Wit',
            value: (intrinsic.values['wit'] as num?)?.round() ?? 0,
            color: const Color(0xFF64B5F6), // muted blue
          ),
          SizedBox(height: Spacing.xs),
          _StatBar(
            icon: GameIcons.speed,
            label: 'Speed',
            value: (intrinsic.values['speed'] as num?)?.round() ?? 0,
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

  /// Capitalize an [AnimalSize] enum name for display (e.g. "medium" → "Medium").
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
