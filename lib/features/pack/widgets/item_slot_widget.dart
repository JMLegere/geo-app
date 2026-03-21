import 'package:flutter/material.dart' hide Durations;

import 'package:earth_nova/core/models/animal_class.dart';
import 'package:earth_nova/core/models/animal_type.dart';
import 'package:earth_nova/core/models/item_instance.dart';
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/shared/earth_nova_theme.dart';
import 'package:earth_nova/shared/game_icons.dart';
import 'package:earth_nova/shared/widgets/habitat_gradient.dart';
import 'package:earth_nova/shared/widgets/species_art_image.dart';
import 'package:earth_nova/shared/widgets/prismatic_border.dart';
import 'package:earth_nova/shared/widgets/rarity_badge.dart';
import 'package:earth_nova/core/models/habitat.dart';

/// Compact Pokémon-PC-box-style grid cell for a single [ItemInstance].
///
/// Renders a habitat gradient background, the creature icon (or habitat/
/// fallback), a tiny [RarityBadge] in the top-right corner, and the
/// display name truncated to one line at the bottom.
///
/// First-discovery items ([ItemInstance.isFirstDiscovery]) receive an animated
/// [PrismaticBorder] (rotating rainbow stroke) and a [FirstDiscoveryBadge]
/// star chip in the top-left corner.
///
/// Pass [onTap] to handle selection (opens the species card modal).
///
/// Plain [StatelessWidget] — no Riverpod dependency.
class ItemSlotWidget extends StatelessWidget {
  const ItemSlotWidget({
    required this.item,
    this.onTap,
    super.key,
  });

  /// The inventory item to display.
  final ItemInstance item;

  /// Called when the slot is tapped.
  final VoidCallback? onTap;

  static Habitat? _parseHabitat(String? name) => name == null
      ? null
      : Habitat.values.where((h) => h.name == name).firstOrNull;

  static AnimalClass? _parseAnimalClass(String? name) => name == null
      ? null
      : AnimalClass.values.where((a) => a.name == name).firstOrNull;

  static AnimalType? _parseAnimalType(String? taxonomicClass) =>
      taxonomicClass == null
          ? null
          : AnimalType.fromTaxonomicClass(taxonomicClass);

  /// Returns the best icon to display for this item.
  ///
  /// Priority: animalClass icon → animalType icon → habitat icon → unknown.
  String _resolveEmoji() {
    final cls = _parseAnimalClass(item.animalClassName);
    if (cls != null) return GameIcons.animalClass(cls);
    final type = _parseAnimalType(item.taxonomicClass);
    if (type != null) return GameIcons.animalType(type);
    if (item.habitats.isNotEmpty) return GameIcons.habitat(item.habitats.first);
    return GameIcons.unknown;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final primaryHabitat = _parseHabitat(item.cellHabitatName) ??
        (item.habitats.isNotEmpty ? item.habitats.first : null);

    final baseDecoration = primaryHabitat != null
        ? HabitatGradient.tile(primaryHabitat)
        : BoxDecoration(color: cs.surfaceContainerHigh);

    // Prefer denormalized rarity from instance.
    final rarity = item.rarity;

    // First-discovery items swap the static rarity border for PrismaticBorder,
    // so we omit the Border from their BoxDecoration entirely.
    final BoxDecoration effectiveDecoration;
    if (item.isFirstDiscovery) {
      effectiveDecoration = baseDecoration.copyWith(
        borderRadius: Radii.borderLg,
        boxShadow: Shadows.soft,
        // No border — PrismaticBorder paints the animated edge.
      );
    } else {
      final borderColor = (rarity != null)
          ? EarthNovaTheme.rarityColor(rarity)
              .withValues(alpha: Opacities.borderSubtle)
          : cs.outline.withValues(alpha: Opacities.borderSubtle);
      effectiveDecoration = baseDecoration.copyWith(
        borderRadius: Radii.borderLg,
        border: Border.all(
          color: borderColor,
          width: rarity != null ? 1.5 : 1.0,
        ),
        boxShadow: Shadows.soft,
      );
    }

    final slot = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: effectiveDecoration,
        padding: const EdgeInsets.fromLTRB(
          Spacing.xs,
          Spacing.xs,
          Spacing.xs,
          Spacing.xxs,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Main area: icon + badges ─────────────────────────────────
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Creature / habitat icon centred
                  Center(
                    child: SpeciesArtImage(
                      artUrl: item.iconUrl,
                      fallbackEmoji: _resolveEmoji(),
                      size: 44,
                      borderRadius: Radii.borderMd,
                      animate: true,
                      animationSeed: item.definitionId.hashCode,
                    ),
                  ),
                  // Rarity badge top-right
                  if (rarity != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: RarityBadge(
                        status: rarity,
                        size: RarityBadgeSize.small,
                      ),
                    ),
                  // ★ First discovery badge top-left (opposite rarity badge)
                  if (item.isFirstDiscovery)
                    const Positioned(
                      top: 0,
                      left: 0,
                      child: FirstDiscoveryBadge(),
                    ),
                ],
              ),
            ),

            Spacing.gapXs,

            // ── Display name ─────────────────────────────────────────────
            Text(
              item.displayName.isNotEmpty ? item.displayName : '???',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );

    // Wrap first-discovery slots in the animated prismatic border.
    // Uses shared animation from PrismaticAnimationScope if available.
    if (item.isFirstDiscovery) {
      return PrismaticBorder(
        borderRadius: Radii.lg,
        borderWidth: 2.5,
        animation: PrismaticAnimationScope.of(context),
        child: slot,
      );
    }
    return slot;
  }
}
