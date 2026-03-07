import 'package:flutter/material.dart' hide Durations;

import 'package:fog_of_world/core/models/item_definition.dart';
import 'package:fog_of_world/core/models/item_instance.dart';
import 'package:fog_of_world/shared/design_tokens.dart';
import 'package:fog_of_world/shared/earth_nova_theme.dart';
import 'package:fog_of_world/shared/game_icons.dart';
import 'package:fog_of_world/shared/widgets/habitat_gradient.dart';
import 'package:fog_of_world/shared/widgets/prismatic_border.dart';
import 'package:fog_of_world/shared/widgets/rarity_badge.dart';

/// Compact Pokémon-PC-box-style grid cell for a single [ItemInstance].
///
/// Renders a habitat gradient background, the creature emoji (or habitat/
/// fallback), a tiny [RarityBadge] in the top-right corner, and the
/// display name truncated to one line at the bottom.
///
/// First-discovery items ([ItemInstance.isFirstDiscovery]) receive an animated
/// [PrismaticBorder] (rotating rainbow stroke) and a [FirstDiscoveryBadge]
/// star chip in the top-left corner.
///
/// Pass [onTap] to handle selection (opens [ItemDetailSheet]).
/// [definition] may be null if the species isn't resolved yet — the slot
/// shows a neutral placeholder in that case.
///
/// Plain [StatelessWidget] — no Riverpod dependency.
class ItemSlotWidget extends StatelessWidget {
  const ItemSlotWidget({
    required this.item,
    this.definition,
    this.onTap,
    super.key,
  });

  /// The inventory item to display.
  final ItemInstance item;

  /// Resolved species definition — may be null if lookup failed.
  final FaunaDefinition? definition;

  /// Called when the slot is tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final def = definition;
    final cs = Theme.of(context).colorScheme;
    final primaryHabitat =
        (def != null && def.habitats.isNotEmpty) ? def.habitats.first : null;

    final baseDecoration = primaryHabitat != null
        ? HabitatGradient.tile(primaryHabitat)
        : BoxDecoration(color: cs.surfaceContainerHigh);

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
      final borderColor = (def?.rarity != null)
          ? EarthNovaTheme.rarityColor(def!.rarity!)
              .withValues(alpha: Opacities.borderSubtle)
          : cs.outline.withValues(alpha: Opacities.borderSubtle);
      effectiveDecoration = baseDecoration.copyWith(
        borderRadius: Radii.borderLg,
        border: Border.all(
          color: borderColor,
          width: def?.rarity != null ? 1.5 : 1.0,
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
            // ── Main area: emoji + badges ────────────────────────────────
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Creature / habitat emoji centred
                  Center(
                    child: Text(
                      _resolveEmoji(def),
                      style: const TextStyle(fontSize: 22),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Rarity badge top-right
                  if (def?.rarity != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: RarityBadge(
                        status: def!.rarity!,
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
              def?.displayName ?? '???',
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
    if (item.isFirstDiscovery) {
      return PrismaticBorder(
        borderRadius: Radii.lg,
        borderWidth: 2.5,
        child: slot,
      );
    }
    return slot;
  }

  /// Returns the best emoji to display for this item.
  ///
  /// Priority: animalClass emoji → animalType emoji → habitat emoji → unknown.
  static String _resolveEmoji(FaunaDefinition? def) {
    if (def == null) return GameIcons.unknown;
    return GameIcons.fauna(def);
  }
}
