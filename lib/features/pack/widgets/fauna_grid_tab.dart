import 'package:flutter/material.dart' hide Durations;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/models/item_category.dart';
import 'package:earth_nova/features/pack/providers/pack_provider.dart';
import 'package:earth_nova/features/pack/widgets/item_slot_widget.dart';
import 'package:earth_nova/features/pack/widgets/species_card_modal.dart';
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/shared/game_icons.dart';
import 'package:earth_nova/shared/widgets/empty_state_widget.dart';

/// 6-column grid of all fauna ItemInstances the player owns.
///
/// Reads from [packProvider]. Tapping a slot opens the species card modal.
/// Shows [EmptyStateWidget] when the player has no fauna yet.
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

    // Log art URL resolution summary on every grid build.
    int withItemUrl = 0;
    int withDefUrl = 0;
    int withNoUrl = 0;
    int noDef = 0;
    for (final item in items) {
      final def =
          ref.read(packProvider.notifier).resolveFauna(item.definitionId);
      if (item.iconUrl != null) {
        withItemUrl++;
      } else if (def == null) {
        noDef++;
      } else if (def.iconUrl != null) {
        withDefUrl++;
      } else {
        withNoUrl++;
      }
    }
    // ignore: avoid_print
    print(
      '[ART] grid build: ${items.length} items, '
      'itemUrl=$withItemUrl, defUrl=$withDefUrl, '
      'noUrl=$withNoUrl, noDef=$noDef',
    );

    return GridView.builder(
      padding: EdgeInsets.all(Spacing.sm),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        childAspectRatio: 0.85,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final definition =
            ref.read(packProvider.notifier).resolveFauna(item.definitionId);

        return ItemSlotWidget(
          key: ValueKey(item.id),
          item: item,
          definition: definition,
          onTap: () => showSpeciesCardModal(
            context,
            item: item,
            definition: definition,
          ),
        );
      },
    );
  }
}
