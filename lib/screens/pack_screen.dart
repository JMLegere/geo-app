import 'package:flutter/material.dart' hide Durations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/models/item.dart';
import 'package:earth_nova/providers/items_provider.dart';
import 'package:earth_nova/shared/app_theme.dart';
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/widgets/loading_dots.dart';

/// Pack screen — responsive grid of discovered species with filter and sort.
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(itemsProvider.notifier).fetchItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(itemsProvider);
    final filtered = _filteredAndSorted(state.items);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(
          state.isLoading || state.items.isEmpty
              ? 'Pack'
              : 'Pack · ${filtered.length}',
        ),
        backgroundColor: AppTheme.surfaceContainer,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.outline),
        ),
      ),
      body: state.isLoading
          ? const Center(child: LoadingDots())
          : state.error != null
              ? _ErrorState(message: state.error!, onRetry: _fetch)
              : _PackBody(
                  items: filtered,
                  allItems: state.items,
                  filter: _filter,
                  sort: _sort,
                  onFilterChanged: (cat) => setState(() => _filter = cat),
                  onSortChanged: (mode) => setState(() => _sort = mode),
                ),
    );
  }

  void _fetch() => ref.read(itemsProvider.notifier).fetchItems();

  List<Item> _filteredAndSorted(List<Item> items) {
    var result = items.where((i) => i.category == _filter).toList();
    switch (_sort) {
      case _SortMode.recent:
        result.sort((a, b) => b.acquiredAt.compareTo(a.acquiredAt));
      case _SortMode.rarity:
        const order = [
          'criticallyEndangered',
          'endangered',
          'vulnerable',
          'nearThreatened',
          'leastConcern',
        ];
        result.sort((a, b) {
          final ai = order.indexOf(a.rarity ?? '');
          final bi = order.indexOf(b.rarity ?? '');
          return ai.compareTo(bi);
        });
      case _SortMode.name:
        result.sort((a, b) => a.displayName.compareTo(b.displayName));
    }
    return result;
  }
}

enum _SortMode { recent, rarity, name }

// ─── Pack body ────────────────────────────────────────────────────────────────

/// Top-level layout shell for the non-loading, non-error pack state.
/// Always shows the filter bar; conditionally shows sort bar and grid.
class _PackBody extends StatelessWidget {
  const _PackBody({
    required this.items,
    required this.allItems,
    required this.filter,
    required this.sort,
    required this.onFilterChanged,
    required this.onSortChanged,
  });

  /// Filtered + sorted items for the active category.
  final List<Item> items;

  /// All items across all categories (for per-chip counts).
  final List<Item> allItems;

  final ItemCategory filter;
  final _SortMode sort;
  final void Function(ItemCategory) onFilterChanged;
  final void Function(_SortMode) onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FilterBar(
          filter: filter,
          allItems: allItems,
          onFilterChanged: onFilterChanged,
        ),
        if (items.isNotEmpty)
          _SortBar(sort: sort, onSortChanged: onSortChanged),
        Expanded(
          child: allItems.isEmpty
              ? _EmptyState(
                  filter: filter,
                  subtitle: 'Explore the world to discover wildlife!',
                )
              : items.isEmpty
                  ? _EmptyState(
                      filter: filter,
                      subtitle:
                          'No ${filter.name} in your pack yet. Keep exploring!',
                    )
                  : _ItemGrid(items: items),
        ),
      ],
    );
  }
}

// ─── Filter bar ───────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.allItems,
    required this.onFilterChanged,
  });

  final ItemCategory filter;
  final List<Item> allItems;
  final void Function(ItemCategory) onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceContainer,
        border: Border(
          bottom: BorderSide(color: AppTheme.outline, width: 0.5),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.xs,
        ),
        itemCount: ItemCategory.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: Spacing.xs),
        itemBuilder: (context, index) {
          final cat = ItemCategory.values[index];
          final count = allItems.where((i) => i.category == cat).length;
          return _CategoryChip(
            category: cat,
            selected: cat == filter,
            count: count,
            onTap: () => onFilterChanged(cat),
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  final ItemCategory category;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  static String _label(ItemCategory cat) => switch (cat) {
        ItemCategory.fauna => 'Fauna',
        ItemCategory.flora => 'Flora',
        ItemCategory.mineral => 'Mineral',
        ItemCategory.fossil => 'Fossil',
        ItemCategory.artifact => 'Artifact',
        ItemCategory.food => 'Food',
        ItemCategory.orb => 'Orb',
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Durations.quick,
        curve: AppCurves.standard,
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.xxs,
        ),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.outline,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              category.emoji,
              style: const TextStyle(fontSize: 14, height: 1),
            ),
            const SizedBox(width: Spacing.xs),
            Text(
              _label(category),
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? Colors.white : AppTheme.onSurfaceVariant,
                height: 1,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: Spacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.25)
                      : AppTheme.outline.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppTheme.onSurfaceVariant,
                    height: 1,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Sort bar ─────────────────────────────────────────────────────────────────

class _SortBar extends StatelessWidget {
  const _SortBar({required this.sort, required this.onSortChanged});

  final _SortMode sort;
  final void Function(_SortMode) onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.xs,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.outline, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _SortPill(
            label: 'Recent',
            selected: sort == _SortMode.recent,
            onTap: () => onSortChanged(_SortMode.recent),
          ),
          const SizedBox(width: Spacing.xs),
          _SortPill(
            label: 'Rarity',
            selected: sort == _SortMode.rarity,
            onTap: () => onSortChanged(_SortMode.rarity),
          ),
          const SizedBox(width: Spacing.xs),
          _SortPill(
            label: 'Name',
            selected: sort == _SortMode.name,
            onTap: () => onSortChanged(_SortMode.name),
          ),
        ],
      ),
    );
  }
}

class _SortPill extends StatelessWidget {
  const _SortPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Durations.quick,
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.xs,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.sm),
          border: Border.all(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.6)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppTheme.primary : AppTheme.onSurfaceVariant,
            height: 1,
          ),
        ),
      ),
    );
  }
}

// ─── Item grid ────────────────────────────────────────────────────────────────

class _ItemGrid extends StatelessWidget {
  const _ItemGrid({required this.items});
  final List<Item> items;

  /// Responsive column count.
  /// Mobile  < 600px  → 3 cols (~114px cards on 375px)
  /// Tablet  < 900px  → 4 cols
  /// Desktop ≥ 900px  → 6 cols
  static int _columns(double width) {
    if (width < 600) return 3;
    if (width < 900) return 4;
    return 6;
  }

  /// Taller aspect ratio at fewer columns keeps names readable.
  static double _aspectRatio(int cols) {
    if (cols <= 3) return 0.78;
    if (cols == 4) return 0.82;
    return 0.85;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = _columns(constraints.maxWidth);
        return GridView.builder(
          padding: const EdgeInsets.all(Spacing.sm),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            childAspectRatio: _aspectRatio(cols),
            crossAxisSpacing: Spacing.sm,
            mainAxisSpacing: Spacing.sm,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => _ItemSlot(item: items[i]),
        );
      },
    );
  }
}

// ─── Item slot ────────────────────────────────────────────────────────────────

class _ItemSlot extends StatelessWidget {
  const _ItemSlot({required this.item});
  final Item item;

  /// Returns rarity-specific border opacity and glow strength.
  /// Higher rarity → more vivid border + ambient glow.
  static ({Color color, double borderAlpha, double glowAlpha}) _rarityDecor(
    String? rarity,
  ) {
    return switch (rarity) {
      'criticallyEndangered' => (
          color: const Color(0xFF9C27B0),
          borderAlpha: 0.9,
          glowAlpha: 0.35,
        ),
      'endangered' => (
          color: const Color(0xFFFFD700),
          borderAlpha: 0.85,
          glowAlpha: 0.25,
        ),
      'vulnerable' => (
          color: const Color(0xFF2196F3),
          borderAlpha: 0.65,
          glowAlpha: 0.15,
        ),
      'nearThreatened' => (
          color: const Color(0xFF4CAF50),
          borderAlpha: 0.5,
          glowAlpha: 0.0,
        ),
      'leastConcern' => (
          color: Colors.white,
          borderAlpha: 0.12,
          glowAlpha: 0.0,
        ),
      _ => (
          color: AppTheme.outline,
          borderAlpha: 0.5,
          glowAlpha: 0.0,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final rd = _rarityDecor(item.rarity);
    final hasFrame2 = item.iconUrlFrame2 != null;

    return GestureDetector(
      onTap: () {
        // TODO: open SpeciesCard bottom sheet
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(Radii.xl),
          border: Border.all(
            color: rd.color.withValues(alpha: rd.borderAlpha),
            width: 1.5,
          ),
          boxShadow: rd.glowAlpha > 0
              ? [
                  BoxShadow(
                    color: rd.color.withValues(alpha: rd.glowAlpha),
                    blurRadius: 12,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Icon area ─────────────────────────────────────────────────
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  // Species icon centred in the card body.
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Spacing.xs,
                        Spacing.md,
                        Spacing.xs,
                        Spacing.xxs,
                      ),
                      child: _SpeciesIcon(item: item),
                    ),
                  ),
                  // Rarity badge — top-right corner.
                  if (item.rarity != null)
                    Positioned(
                      top: Spacing.xs,
                      right: Spacing.xs,
                      child: _RarityBadge(rarity: item.rarity!),
                    ),
                  // Animated-species dot — teal pulse, bottom-left.
                  // Signals that this species has 2-frame idle animation data.
                  if (hasFrame2)
                    Positioned(
                      bottom: Spacing.xs,
                      left: Spacing.xs,
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppTheme.tertiary.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.tertiary.withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // ── Name strip ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.xs,
                vertical: Spacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainer.withValues(alpha: 0.85),
                borderRadius: const BorderRadius.vertical(
                  bottom:
                      Radius.circular(Radii.lg), // inset from outer Radii.xl
                ),
              ),
              child: Text(
                item.displayName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurface,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Species icon ─────────────────────────────────────────────────────────────

/// Loads the species chibi icon from the item's iconUrl with an emoji fallback.
class _SpeciesIcon extends StatelessWidget {
  const _SpeciesIcon({required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) {
    if (item.iconUrl != null) {
      return Image.network(
        item.iconUrl!,
        width: 44,
        height: 44,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _CategoryEmoji(category: item.category),
      );
    }
    return _CategoryEmoji(category: item.category);
  }
}

class _CategoryEmoji extends StatelessWidget {
  const _CategoryEmoji({required this.category});
  final ItemCategory category;

  @override
  Widget build(BuildContext context) {
    return Text(category.emoji, style: const TextStyle(fontSize: 36));
  }
}

// ─── Rarity badge ─────────────────────────────────────────────────────────────

/// IUCN status pill — e.g. "CR" on purple, "EN" on gold.
/// Placed top-right on each item slot.
class _RarityBadge extends StatelessWidget {
  const _RarityBadge({required this.rarity});
  final String rarity;

  static ({Color bg, Color fg, String code}) _badgeData(String rarity) =>
      switch (rarity) {
        'criticallyEndangered' => (
            bg: const Color(0xFF9C27B0),
            fg: Colors.white,
            code: 'CR',
          ),
        'endangered' => (
            bg: const Color(0xFFFFD700),
            fg: const Color(0xFF1A1A2E),
            code: 'EN',
          ),
        'vulnerable' => (
            bg: const Color(0xFF2196F3),
            fg: Colors.white,
            code: 'VU',
          ),
        'nearThreatened' => (
            bg: const Color(0xFF4CAF50),
            fg: Colors.white,
            code: 'NT',
          ),
        'leastConcern' => (
            bg: Colors.white,
            fg: const Color(0xFF1A1A2E),
            code: 'LC',
          ),
        _ => (
            bg: AppTheme.outline,
            fg: AppTheme.onSurface,
            code: '?',
          ),
      };

  @override
  Widget build(BuildContext context) {
    final d = _badgeData(rarity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: d.bg,
        borderRadius: BorderRadius.circular(Radii.xs),
        boxShadow: [
          BoxShadow(
            color: d.bg.withValues(alpha: 0.5),
            blurRadius: 4,
          ),
        ],
      ),
      child: Text(
        d.code,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w800,
          color: d.fg,
          letterSpacing: 0.4,
          height: 1.2,
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

/// Shown when [filter] category has no items.
/// [subtitle] varies depending on whether the user has NO items at all,
/// or simply none in this category.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.filter,
    required this.subtitle,
  });

  final ItemCategory filter;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xxxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              filter.emoji,
              style: const TextStyle(fontSize: 56),
            ),
            const SizedBox(height: Spacing.md),
            Text(
              'No ${filter.name} discovered yet',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurface,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Error state ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xxxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.error.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: const Center(
                child: Text('⚠️', style: TextStyle(fontSize: 28)),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            const Text(
              "Couldn't load your collection",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurface,
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: Spacing.xxl),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(140, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.xl),
                ),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
