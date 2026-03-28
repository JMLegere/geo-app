import 'package:flutter/material.dart' hide Durations;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/models/item_category.dart';
import 'package:earth_nova/features/pack/providers/pack_provider.dart';
import 'package:earth_nova/features/pack/widgets/item_slot_widget.dart';
import 'package:earth_nova/features/pack/widgets/species_card_modal.dart';
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/shared/game_icons.dart';
import 'package:earth_nova/shared/widgets/empty_state_widget.dart';
import 'package:earth_nova/shared/widgets/prismatic_border.dart';

/// 6-column grid of all fauna ItemInstances the player owns.
///
/// Reads from [packProvider]. Tapping a slot opens the species card modal.
/// Shows [EmptyStateWidget] when the player has no fauna yet.
///
/// Wraps the grid in a [PrismaticAnimationScope] so all first-discovery
/// items share a single [AnimationController] instead of one each.
class FaunaGridTab extends ConsumerWidget {
  const FaunaGridTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(packProvider
        .select((p) => p.itemsByCategory[ItemCategory.fauna] ?? const []));

    if (items.isEmpty) {
      return EmptyStateWidget(
        icon: GameIcons.category(ItemCategory.fauna),
        title: 'No fauna collected yet',
        subtitle: 'Explore the world to discover wildlife!',
      );
    }

    // ignore: avoid_print
    print('[ART] grid build: ${items.length} items');

    return PrismaticAnimationScope(
      child: GridView.builder(
        padding: EdgeInsets.all(Spacing.sm),
        cacheExtent:
            100, // Reduced from default 250 — limits off-screen pre-builds on iOS
        addAutomaticKeepAlives: false, // Reduce memory pressure on iOS
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          childAspectRatio: 0.85,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];

          return ItemSlotWidget(
            key: ValueKey(item.id),
            item: item,
            onTap: () => showSpeciesCardModal(context, item: item),
          );
        },
      ),
    );
  }
}
