import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/models/item_category.dart';
import 'package:earth_nova/models/item_instance.dart';
import 'package:earth_nova/providers/inventory_provider.dart';
import 'package:earth_nova/shared/widgets/rarity_badge.dart';
import 'package:earth_nova/shared/widgets/species_art_image.dart';
import 'package:earth_nova/widgets/item_detail_sheet.dart';

enum _SortMode { recent, rarity, name }

class PackScreen extends ConsumerStatefulWidget {
  const PackScreen({super.key});

  @override
  ConsumerState<PackScreen> createState() => _PackScreenState();
}

class _PackScreenState extends ConsumerState<PackScreen> {
  ItemCategory? _selectedCategory;
  _SortMode _sortMode = _SortMode.recent;

  static const _kIucnOrder = [
    'extinct',
    'criticallyEndangered',
    'endangered',
    'vulnerable',
    'nearThreatened',
    'leastConcern',
  ];

  List<ItemInstance> _filtered(List<ItemInstance> items) {
    var result = _selectedCategory == null
        ? items
        : items.where((i) => i.category == _selectedCategory).toList();

    result = List.of(result);
    switch (_sortMode) {
      case _SortMode.recent:
        result.sort((a, b) => b.acquiredAt.compareTo(a.acquiredAt));
      case _SortMode.rarity:
        result.sort((a, b) {
          final ai =
              a.rarity == null ? 999 : _kIucnOrder.indexOf(a.rarity!.name);
          final bi =
              b.rarity == null ? 999 : _kIucnOrder.indexOf(b.rarity!.name);
          return ai.compareTo(bi);
        });
      case _SortMode.name:
        result.sort((a, b) => a.displayName.compareTo(b.displayName));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final inventory = ref.watch(inventoryProvider);
    final allItems = inventory.items;
    final displayItems = _filtered(allItems);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: Row(
          children: [
            const Text('Pack'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${allItems.length}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<_SortMode>(
            icon: const Icon(Icons.sort, color: Colors.white70),
            color: const Color(0xFF21262D),
            onSelected: (m) => setState(() => _sortMode = m),
            itemBuilder: (_) => [
              _sortItem(_SortMode.recent, 'Recent', Icons.schedule),
              _sortItem(_SortMode.rarity, 'Rarity', Icons.star),
              _sortItem(_SortMode.name, 'Name', Icons.sort_by_alpha),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          _FilterRow(
            selected: _selectedCategory,
            onSelect: (cat) => setState(() => _selectedCategory = cat),
          ),

          // Grid
          Expanded(
            child: displayItems.isEmpty
                ? const _EmptyState(
                    icon: Icons.backpack_outlined,
                    message: 'No discoveries yet — explore to find species!',
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: displayItems.length,
                    itemBuilder: (ctx, i) => _ItemCard(
                      item: displayItems[i],
                      onTap: () => showItemDetailSheet(ctx, displayItems[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<_SortMode> _sortItem(
      _SortMode mode, String label, IconData icon) {
    return PopupMenuItem(
      value: mode,
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _FilterRow extends StatelessWidget {
  final ItemCategory? selected;
  final ValueChanged<ItemCategory?> onSelect;

  const _FilterRow({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final cats = [null, ...ItemCategory.values];
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final cat = cats[i];
          final label = cat?.displayName ?? 'All';
          final isSelected = selected == cat;
          return GestureDetector(
            onTap: () => onSelect(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF0D1117) : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ItemCard extends StatelessWidget {
  final ItemInstance item;
  final VoidCallback onTap;

  const _ItemCard({required this.item, required this.onTap});

  String _emoji(ItemInstance item) => switch (item.category.name) {
        'fauna' => '🦊',
        'flora' => '🌿',
        'mineral' => '💎',
        'fossil' => '🦴',
        'artifact' => '🏺',
        'food' => '🍎',
        'orb' => '🔮',
        _ => '❓',
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Art
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: SpeciesArtImage(
                artUrl: item.artUrl,
                fallbackEmoji: _emoji(item),
                size: double.infinity,
                borderRadius: BorderRadius.zero,
              ),
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (item.scientificName != null)
                      Text(
                        item.scientificName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    const Spacer(),
                    if (item.rarity != null)
                      RarityBadge(
                          status: item.rarity!, size: RarityBadgeSize.small),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      );
}
