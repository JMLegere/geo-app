import 'package:flutter/material.dart' hide Durations;

import 'package:fog_of_world/core/models/item_definition.dart';
import 'package:fog_of_world/core/models/item_instance.dart';
import 'package:fog_of_world/shared/design_tokens.dart';
import 'package:fog_of_world/shared/earth_nova_theme.dart';
import 'package:fog_of_world/shared/game_icons.dart';
import 'package:fog_of_world/shared/widgets/habitat_gradient.dart';
import 'package:fog_of_world/shared/widgets/rarity_badge.dart';

/// Compact Pokémon-PC-box-style grid cell for a single [ItemInstance].
///
/// Renders a habitat gradient background, the creature emoji (or habitat/
/// fallback), a tiny [RarityBadge] in the top-right corner, and the
/// display name truncated to one line at the bottom.
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

    final borderColor = (def?.rarity != null)
        ? EarthNovaTheme.rarityColor(def!.rarity!)
            .withValues(alpha: Opacities.borderSubtle)
        : cs.outline.withValues(alpha: Opacities.borderSubtle);

    final decoration = baseDecoration.copyWith(
      borderRadius: Radii.borderLg,
      border: Border.all(
        color: borderColor,
        width: def?.rarity != null ? 1.5 : 1.0,
      ),
      boxShadow: Shadows.soft,
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: decoration,
        padding: const EdgeInsets.fromLTRB(
          Spacing.xs,
          Spacing.xs,
          Spacing.xs,
          Spacing.xxs,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Main area: emoji + rarity badge ─────────────────────────
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
  }

  /// Returns the best emoji to display for this item.
  ///
  /// Priority: animalType emoji → primary habitat emoji → unknown.
  static String _resolveEmoji(FaunaDefinition? def) {
    if (def == null) return GameIcons.unknown;
    if (def.animalType != null) return GameIcons.animalType(def.animalType!);
    if (def.habitats.isNotEmpty) return GameIcons.habitat(def.habitats.first);
    return GameIcons.unknown;
  }
}
