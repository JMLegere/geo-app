import 'package:flutter/material.dart' hide Durations;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/models/item_category.dart';
import 'package:earth_nova/features/pack/providers/pack_provider.dart';
import 'package:earth_nova/features/pack/widgets/item_detail_sheet.dart';
import 'package:earth_nova/features/pack/widgets/item_slot_widget.dart';
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/shared/game_icons.dart';
import 'package:earth_nova/shared/widgets/empty_state_widget.dart';

/// 4-column Pokémon-PC-box grid of all fauna [ItemInstance]s the player owns.
///
/// Reads from [packProvider]. Tapping a slot opens [ItemDetailSheet].
/// Shows [EmptyStateWidget] when the player has no fauna yet.
class FaunaGridTab extends ConsumerWidget {
  const FaunaGridTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(packProvider);
    final items = state.itemsByCategory[ItemCategory.fauna] ?? const [];

    if (items.isEmpty) {
      return EmptyStateWidget(
        icon: GameIcons.category(ItemCategory.fauna),
        title: 'No fauna collected yet',
        subtitle: 'Explore the world to discover wildlife!',
      );
    }

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
          item: item,
          definition: definition,
          onTap: () => showItemDetailSheet(
            context,
            item: item,
            definition: definition,
          ),
        );
      },
    );
  }
}
