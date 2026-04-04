import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/models/item.dart';
import 'package:earth_nova/providers/items_provider.dart';
import 'package:earth_nova/shared/app_theme.dart';
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/widgets/loading_dots.dart';

/// Pack screen — grid of discovered species with filter and sort.
class PackScreen extends ConsumerStatefulWidget {
  const PackScreen({super.key});

  @override
  ConsumerState<PackScreen> createState() => _PackScreenState();
}

class _PackScreenState extends ConsumerState<PackScreen> {
  ItemCategory _filter = ItemCategory.fauna;
  _SortMode _sort = _SortMode.recent;

  @override
  void initState() {
    super.initState();
    // Fetch items when screen mounts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(itemsProvider.notifier).fetchItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(itemsProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text('Pack · ${state.items.length}'),
        backgroundColor: AppTheme.surfaceContainer,
      ),
      body: state.isLoading
          ? const Center(child: LoadingDots())
          : state.error != null
              ? _ErrorState(message: state.error!, onRetry: _fetch)
              : state.items.isEmpty
                  ? const _EmptyState()
                  : _Grid(
                      items: _filteredAndSorted(state.items),
                      filter: _filter,
                      sort: _sort,
                      onFilterChanged: (cat) => setState(() => _filter = cat),
                      onSortChanged: (mode) => setState(() => _sort = mode),
                    ),
    );
  }

  void _fetch() => ref.read(itemsProvider.notifier).fetchItems();

  List<Item> _filteredAndSorted(List<Item> items) {
    var filtered = items.where((i) => i.category == _filter).toList();
    switch (_sort) {
      case _SortMode.recent:
        filtered.sort((a, b) => b.acquiredAt.compareTo(a.acquiredAt));
      case _SortMode.rarity:
        final order = [
          'criticallyEndangered',
          'endangered',
          'vulnerable',
          'nearThreatened',
          'leastConcern'
        ];
        filtered.sort((a, b) {
          final ai = order.indexOf(a.rarity ?? '');
          final bi = order.indexOf(b.rarity ?? '');
          return ai.compareTo(bi);
        });
      case _SortMode.name:
        filtered.sort((a, b) => a.displayName.compareTo(b.displayName));
    }
    return filtered;
  }
}

enum _SortMode { recent, rarity, name }

class _Grid extends StatelessWidget {
  const _Grid({
    required this.items,
    required this.filter,
    required this.sort,
    required this.onFilterChanged,
    required this.onSortChanged,
  });

  final List<Item> items;
  final ItemCategory filter;
  final _SortMode sort;
  final void Function(ItemCategory) onFilterChanged;
  final void Function(_SortMode) onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter chips
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
            children: [
              for (final cat in ItemCategory.values)
                Padding(
                  padding: const EdgeInsets.only(right: Spacing.xs),
                  child: FilterChip(
                    label: Text('${cat.emoji} ${cat.name}'),
                    selected: cat == filter,
                    onSelected: (_) => onFilterChanged(cat),
                    selectedColor: AppTheme.primary,
                    labelStyle: TextStyle(
                      color: cat == filter ? Colors.white : AppTheme.onSurface,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppTheme.outline),
        // Sort dropdown
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.sm, vertical: Spacing.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Sort: ',
                  style: TextStyle(
                      color: AppTheme.onSurfaceVariant, fontSize: 13)),
              DropdownButton<_SortMode>(
                value: sort,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(
                      value: _SortMode.recent, child: Text('Recent')),
                  DropdownMenuItem(
                      value: _SortMode.rarity, child: Text('Rarity')),
                  DropdownMenuItem(value: _SortMode.name, child: Text('Name')),
                ],
                onChanged: (v) {
                  if (v != null) onSortChanged(v);
                },
                style: TextStyle(color: AppTheme.onSurface, fontSize: 13),
                dropdownColor: AppTheme.surfaceContainer,
              ),
            ],
          ),
        ),
        // Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(Spacing.sm),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              childAspectRatio: 0.85,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) => _ItemSlot(item: items[index]),
          ),
        ),
      ],
    );
  }
}

class _ItemSlot extends StatelessWidget {
  const _ItemSlot({required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) {
    final rarityColor = _rarityColor(item.rarity);
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.lg),
        border:
            Border.all(color: rarityColor.withValues(alpha: 0.2), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Text(
            item.category.emoji,
            style: const TextStyle(fontSize: 28),
          ),
          const SizedBox(height: Spacing.xxs),
          // Name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.xxs),
            child: Text(
              item.displayName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _rarityColor(String? rarity) {
    switch (rarity) {
      case 'criticallyEndangered':
        return const Color(0xFF9C27B0);
      case 'endangered':
        return const Color(0xFFFFD700);
      case 'vulnerable':
        return const Color(0xFF2196F3);
      case 'nearThreatened':
        return const Color(0xFF4CAF50);
      case 'leastConcern':
        return Colors.white;
      default:
        return AppTheme.outline;
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🦊', style: TextStyle(fontSize: 52)),
          const SizedBox(height: Spacing.md),
          const Text(
            'No fauna collected yet',
            style: TextStyle(fontSize: 16, color: AppTheme.onSurface),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Explore the world to find wildlife!',
            style: TextStyle(fontSize: 14, color: AppTheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: Spacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppTheme.onSurface),
            ),
          ),
          const SizedBox(height: Spacing.lg),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
