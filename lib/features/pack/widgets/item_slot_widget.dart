import 'package:flutter/material.dart' hide Durations;

import 'package:earth_nova/core/models/item_definition.dart';
import 'package:earth_nova/core/models/item_instance.dart';
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/shared/earth_nova_theme.dart';
import 'package:earth_nova/shared/game_icons.dart';
import 'package:earth_nova/shared/widgets/habitat_gradient.dart';
import 'package:earth_nova/shared/widgets/prismatic_border.dart';
import 'package:earth_nova/shared/widgets/rarity_badge.dart';

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

    // Prefer denormalized habitats from instance, fall back to definition.
    final habitats =
        item.habitats.isNotEmpty ? item.habitats : (def?.habitats ?? const []);
    final primaryHabitat = habitats.isNotEmpty ? habitats.first : null;

    final baseDecoration = primaryHabitat != null
        ? HabitatGradient.tile(primaryHabitat)
        : BoxDecoration(color: cs.surfaceContainerHigh);

    // Prefer denormalized rarity from instance, fall back to definition.
    final rarity = item.rarity ?? def?.rarity;

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
                    child: Text(
                      _resolveEmoji(def),
                      style: const TextStyle(fontSize: 22),
                      textAlign: TextAlign.center,
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
              item.displayName.isNotEmpty
                  ? item.displayName
                  : (def?.displayName ?? '???'),
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

  /// Returns the best icon to display for this item.
  ///
  /// Priority: animalClass icon → animalType icon → habitat icon → unknown.
  static String _resolveEmoji(FaunaDefinition? def) {
    if (def == null) return GameIcons.unknown;
    return GameIcons.fauna(def);
  }
}
