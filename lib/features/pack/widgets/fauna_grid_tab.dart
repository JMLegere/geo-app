import 'package:flutter/material.dart' hide Durations;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/models/animal_type.dart';
import 'package:earth_nova/core/models/item_category.dart';
import 'package:earth_nova/core/models/item_instance.dart';
import 'package:earth_nova/features/pack/providers/pack_provider.dart';
import 'package:earth_nova/features/pack/widgets/item_slot_widget.dart';
import 'package:earth_nova/features/pack/widgets/species_card_modal.dart';
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/shared/game_icons.dart';
import 'package:earth_nova/shared/widgets/empty_state_widget.dart';
import 'package:earth_nova/shared/widgets/prismatic_border.dart';

/// 6-column grid of all fauna ItemInstances the player owns, organised into
/// AnimalType subtabs: Mammal | Bird | Fish | Reptile | Bug.
///
/// Reads from [packProvider]. Tapping a slot opens the species card modal.
/// Shows [EmptyStateWidget] when the player has no fauna, or per-type when a
/// subtab is empty. The secondary [TabBar] is visually subordinate to the
/// parent [PackScreen] tab bar — smaller font and thinner indicator.
///
/// Wraps each grid in a [PrismaticAnimationScope] so first-discovery items
/// share a single [AnimationController] instead of one each.
class FaunaGridTab extends ConsumerStatefulWidget {
  const FaunaGridTab({super.key});

  @override
  ConsumerState<FaunaGridTab> createState() => _FaunaGridTabState();
}

class _FaunaGridTabState extends ConsumerState<FaunaGridTab>
    with SingleTickerProviderStateMixin {
  // 5 tabs: one per AnimalType.
  static const int _tabCount = 5; // AnimalType.values.length

  late final TabController _subtabController;

  @override
  void initState() {
    super.initState();
    _subtabController = TabController(length: _tabCount, vsync: this);
  }

  @override
  void dispose() {
    _subtabController.dispose();
    super.dispose();
  }

  /// Groups [items] into a map keyed by [AnimalType].
  /// Items whose [taxonomicClass] maps to no known type are excluded.
  Map<AnimalType, List<ItemInstance>> _groupByType(List<ItemInstance> items) {
    final map = {for (final t in AnimalType.values) t: <ItemInstance>[]};
    for (final item in items) {
      final type = AnimalType.fromTaxonomicClass(item.taxonomicClass ?? '');
      if (type != null) map[type]!.add(item);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(packProvider
        .select((p) => p.itemsByCategory[ItemCategory.fauna] ?? const []));

    // Global empty state — player has collected nothing yet.
    if (items.isEmpty) {
      return EmptyStateWidget(
        icon: GameIcons.category(ItemCategory.fauna),
        title: 'No fauna collected yet',
        subtitle: 'Explore the world to discover wildlife!',
      );
    }

    // ignore: avoid_print
    print('[ART] grid build: ${items.length} items');

    final byType = _groupByType(items);
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        // ── Secondary subtab bar ─────────────────────────────────────────────
        // Visually subordinate to the parent PackScreen TabBar:
        //   • smaller font (11 vs 12) and lighter indicator weight (1.5 vs 2.5)
        //   • surfaceContainerLow background keeps it one step below the appbar
        Material(
          color: cs.surfaceContainerLow,
          child: TabBar(
            controller: _subtabController,
            isScrollable: false,
            indicatorColor: cs.primary,
            labelColor: cs.primary,
            unselectedLabelColor: cs.onSurfaceVariant,
            labelStyle: const TextStyle(fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            indicatorWeight: 1.5,
            dividerColor: cs.outlineVariant.withValues(alpha: 0.4),
            padding: EdgeInsets.zero,
            tabs: AnimalType.values
                .map((type) => Tab(icon: Text(type.icon), height: 36))
                .toList(),
          ),
        ),

        // ── Subtab content ───────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _subtabController,
            children: [
              ...AnimalType.values.map((type) {
                final typeItems = byType[type]!;
                if (typeItems.isEmpty) {
                  return EmptyStateWidget(
                    icon: type.icon,
                    title:
                        'No ${type.displayName.toLowerCase()}s collected yet',
                    subtitle: 'Explore to find some!',
                  );
                }
                return _buildGrid(typeItems);
              }),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds the shared 6-column grid wrapped in [PrismaticAnimationScope].
  Widget _buildGrid(List<ItemInstance> items) {
    return PrismaticAnimationScope(
      child: GridView.builder(
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
