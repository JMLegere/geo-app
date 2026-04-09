import 'package:flutter/material.dart' hide Durations;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/domain/entities/game_region.dart';
import 'package:earth_nova/core/domain/entities/habitat.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/domain/entities/iucn_status.dart';
import 'package:earth_nova/core/domain/entities/taxonomic_group.dart';
import 'package:earth_nova/features/identification/domain/entities/pack_filter_state.dart';
import 'package:earth_nova/features/identification/presentation/providers/items_provider.dart';
import 'package:earth_nova/features/identification/presentation/widgets/species_card.dart';
import 'package:earth_nova/shared/extensions/iconography.dart';
import 'package:earth_nova/shared/extensions/iucn_status_theme.dart';
import 'package:earth_nova/shared/theme/app_theme.dart';
import 'package:earth_nova/shared/theme/design_tokens.dart';
import 'package:earth_nova/shared/widgets/loading_dots.dart';

/// Pack screen — responsive grid of discovered species with collapsible
/// filter panel and compact filter bar.
class PackScreen extends ConsumerStatefulWidget {
  const PackScreen({super.key});

  @override
  ConsumerState<PackScreen> createState() => _PackScreenState();
}

class _PackScreenState extends ConsumerState<PackScreen> {
  int _categoryIndex = 0;
  PackSortMode _sort = PackSortMode.recent;
  PackFilterState _filters = const PackFilterState();
  bool _panelExpanded = false;
  String _searchQuery = '';
  late final PageController _pageController = PageController();

  ItemCategory get _category => ItemCategory.values[_categoryIndex];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_onPageScrolled);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(itemsProvider.notifier).fetchItems();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageScrolled() {
    if (!_pageController.hasClients) return;
    final page = _pageController.page;
    if (page == null) return;
    final newIndex = page.round();
    if (newIndex != _categoryIndex) {
      HapticFeedback.selectionClick();
      setState(() {
        _categoryIndex = newIndex;
        _filters = const PackFilterState();
        _searchQuery = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(itemsProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Pack'),
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
                  allItems: state.items,
                  category: _category,
                  sort: _sort,
                  filters: _filters,
                  panelExpanded: _panelExpanded,
                  searchQuery: _searchQuery,
                  pageController: _pageController,
                  onCategoryChanged: _onCategoryChanged,
                  onSortChanged: _onSortChanged,
                  onToggleType: _onToggleType,
                  onToggleHabitat: _onToggleHabitat,
                  onToggleRegion: _onToggleRegion,
                  onToggleRarity: _onToggleRarity,
                  onClearFilters: _onClearFilters,
                  onTogglePanel: _onTogglePanel,
                  onSearchChanged: _onSearchChanged,
                ),
    );
  }

  void _fetch() => ref.read(itemsProvider.notifier).fetchItems();

  void _onCategoryChanged(int index) {
    HapticFeedback.selectionClick();
    _pageController.animateToPage(
      index,
      duration: Durations.normal,
      curve: AppCurves.standard,
    );
  }

  void _onSortChanged(PackSortMode mode) => setState(() => _sort = mode);

  void _onToggleType(TaxonomicGroup group) =>
      setState(() => _filters = _filters.toggleType(group));

  void _onToggleHabitat(Habitat habitat) =>
      setState(() => _filters = _filters.toggleHabitat(habitat));

  void _onToggleRegion(GameRegion region) =>
      setState(() => _filters = _filters.toggleRegion(region));

  void _onToggleRarity(IucnStatus rarity) =>
      setState(() => _filters = _filters.toggleRarity(rarity));
  void _onClearFilters() => setState(() => _filters = const PackFilterState());
  void _onTogglePanel() => setState(() => _panelExpanded = !_panelExpanded);

  void _onSearchChanged(String query) => setState(() => _searchQuery = query);
}

// ─── Shared filter + sort helper ──────────────────────────────────────────────

List<Item> _applyFilterAndSort(
  List<Item> items,
  ItemCategory category,
  PackFilterState filters,
  PackSortMode sort,
  String searchQuery,
) {
  var result = items.where((i) => i.category == category).toList();
  result = result.where(filters.matches).toList();
  if (searchQuery.isNotEmpty) {
    final q = searchQuery.toLowerCase();
    result = result
        .where((i) =>
            i.displayName.toLowerCase().contains(q) ||
            (i.scientificName?.toLowerCase().contains(q) ?? false))
        .toList();
  }
  switch (sort) {
    case PackSortMode.recent:
      result.sort((a, b) => b.acquiredAt.compareTo(a.acquiredAt));
    case PackSortMode.rarity:
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
    case PackSortMode.name:
      result.sort((a, b) => a.displayName.compareTo(b.displayName));
  }
  return result;
}

// ─── Pack body ────────────────────────────────────────────────────────────────

class _PackBody extends StatelessWidget {
  const _PackBody({
    required this.allItems,
    required this.category,
    required this.sort,
    required this.filters,
    required this.panelExpanded,
    required this.searchQuery,
    required this.pageController,
    required this.onCategoryChanged,
    required this.onSortChanged,
    required this.onToggleType,
    required this.onToggleHabitat,
    required this.onToggleRegion,
    required this.onToggleRarity,
    required this.onClearFilters,
    required this.onTogglePanel,
    required this.onSearchChanged,
  });

  final List<Item> allItems;
  final ItemCategory category;
  final PackSortMode sort;
  final PackFilterState filters;
  final bool panelExpanded;
  final String searchQuery;
  final PageController pageController;
  final void Function(int) onCategoryChanged;
  final void Function(PackSortMode) onSortChanged;
  final void Function(TaxonomicGroup) onToggleType;
  final void Function(Habitat) onToggleHabitat;
  final void Function(GameRegion) onToggleRegion;
  final void Function(IucnStatus) onToggleRarity;
  final VoidCallback onClearFilters;
  final VoidCallback onTogglePanel;
  final void Function(String) onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final filtered =
        _applyFilterAndSort(allItems, category, filters, sort, searchQuery);

    return Column(
      children: [
        _CategoryRow(
          category: category,
          allItems: allItems,
          onCategoryChanged: onCategoryChanged,
        ),
        _CompactBar(
          sort: sort,
          filters: filters,
          count: filtered.length,
          panelExpanded: panelExpanded,
          onTogglePanel: onTogglePanel,
        ),
        ClipRect(
          child: AnimatedAlign(
            duration: Durations.normal,
            curve: AppCurves.standard,
            alignment: Alignment.topCenter,
            heightFactor: panelExpanded ? 1.0 : 0.0,
            child: _FilterPanel(
              category: category,
              sort: sort,
              filters: filters,
              onSortChanged: onSortChanged,
              onToggleType: onToggleType,
              onToggleHabitat: onToggleHabitat,
              onToggleRegion: onToggleRegion,
              onToggleRarity: onToggleRarity,
              onClearFilters: onClearFilters,
            ),
          ),
        ),
        _SearchBar(
          query: searchQuery,
          onChanged: onSearchChanged,
        ),
        Expanded(
          child: PageView.builder(
            controller: pageController,
            itemCount: ItemCategory.values.length,
            itemBuilder: (_, index) {
              final cat = ItemCategory.values[index];
              final items = _applyFilterAndSort(
                  allItems, cat, filters, sort, searchQuery);
              if (items.isEmpty) {
                return _EmptyState(
                  category: cat,
                  hasFilters:
                      filters.hasActiveFilters || searchQuery.isNotEmpty,
                );
              }
              return _ItemGrid(items: items);
            },
          ),
        ),
      ],
    );
  }
}

// ─── Category row ─────────────────────────────────────────────────────────────

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.allItems,
    required this.onCategoryChanged,
  });

  final ItemCategory category;
  final List<Item> allItems;
  final void Function(int) onCategoryChanged;

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
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.xs,
          vertical: Spacing.xs,
        ),
        child: Row(
          children: List.generate(ItemCategory.values.length * 2 - 1, (i) {
            if (i.isOdd) return const SizedBox(width: Spacing.xxs);
            final index = i ~/ 2;
            final cat = ItemCategory.values[index];
            return Expanded(
              child: _CategoryChip(
                category: cat,
                selected: cat == category,
                onTap: () => onCategoryChanged(index),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final ItemCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.md),
      splashColor: Colors.transparent,
      highlightColor: AppTheme.primary.withValues(alpha: 0.08),
      child: AnimatedContainer(
        duration: Durations.quick,
        curve: AppCurves.standard,
        padding: const EdgeInsets.all(Spacing.xxs),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(Radii.md),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.45),
                blurRadius: 10,
                offset: const Offset(0, 3),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 3,
                offset: const Offset(0, 1.5),
              ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              category.emoji,
              style: const TextStyle(fontSize: 18, height: 1.0),
            ),
            const SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                category.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? Colors.white : AppTheme.onSurfaceVariant,
                  height: 1.1,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Compact filter bar ───────────────────────────────────────────────────────

class _CompactBar extends StatelessWidget {
  const _CompactBar({
    required this.sort,
    required this.filters,
    required this.count,
    required this.panelExpanded,
    required this.onTogglePanel,
  });

  final PackSortMode sort;
  final PackFilterState filters;
  final int count;
  final bool panelExpanded;
  final VoidCallback onTogglePanel;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('compact-bar'),
      onTap: onTogglePanel,
      child: Container(
        height: ComponentSizes.compactBarHeight,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceContainer,
          border: Border(
            bottom: BorderSide(
              color: AppTheme.outline,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(
              sort.icon,
              style: const TextStyle(
                fontSize: ComponentSizes.compactBarEmoji,
              ),
            ),
            const SizedBox(width: Spacing.xxs),
            Text(
              sort.label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.secondary,
              ),
            ),
            if (filters.hasActiveFilters) ...[
              const SizedBox(width: Spacing.xs),
              Text(
                '·',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.onSurfaceVariant.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(width: Spacing.xs),
              Expanded(child: _MiniFilterChips(filters: filters)),
            ] else ...[
              const SizedBox(width: Spacing.xs),
              Text(
                '·',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.onSurfaceVariant.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(width: Spacing.xs),
              Text(
                'All',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
              const Spacer(),
            ],
            Text(
              key: const Key('compact-bar-count'),
              '$count',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface,
              ),
            ),
            Text(
              ' sp',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: AppTheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: Spacing.xs),
            AnimatedRotation(
              turns: panelExpanded ? 0.5 : 0.0,
              duration: Durations.normal,
              curve: AppCurves.standard,
              child: const Icon(
                Icons.keyboard_arrow_down,
                size: 20,
                color: AppTheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniFilterChips extends StatelessWidget {
  const _MiniFilterChips({required this.filters});
  final PackFilterState filters;

  @override
  Widget build(BuildContext context) {
    final chips = <String>[
      ...filters.activeTypes.map((t) => t.icon),
      ...filters.activeHabitats.map((h) => h.icon),
      ...filters.activeRegions.map((r) => r.icon),
    ];

    final showCount = chips.length > 3 ? 3 : chips.length;
    final overflow = chips.length - showCount;

    return Row(
      children: [
        for (var i = 0; i < showCount; i++) ...[
          if (i > 0) const SizedBox(width: Spacing.xxs),
          Container(
            width: ComponentSizes.miniChipSize,
            height: ComponentSizes.miniChipSize,
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerHighest.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(Radii.xs),
            ),
            child: Center(
              child: Text(
                chips[i],
                style: const TextStyle(
                  fontSize: ComponentSizes.compactBarEmoji,
                ),
              ),
            ),
          ),
        ],
        if (overflow > 0) ...[
          const SizedBox(width: Spacing.xxs),
          Container(
            width: ComponentSizes.miniChipSize,
            height: ComponentSizes.miniChipSize,
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerHighest.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(Radii.xs),
            ),
            child: Center(
              child: Text(
                '+$overflow',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
        const Spacer(),
      ],
    );
  }
}

// ─── Filter panel (expandable) ────────────────────────────────────────────────

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.category,
    required this.sort,
    required this.filters,
    required this.onSortChanged,
    required this.onToggleType,
    required this.onToggleHabitat,
    required this.onToggleRegion,
    required this.onToggleRarity,
    required this.onClearFilters,
  });

  final ItemCategory category;
  final PackSortMode sort;
  final PackFilterState filters;
  final void Function(PackSortMode) onSortChanged;
  final void Function(TaxonomicGroup) onToggleType;
  final void Function(Habitat) onToggleHabitat;
  final void Function(GameRegion) onToggleRegion;
  final void Function(IucnStatus) onToggleRarity;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceContainer,
        border: Border(
          bottom: BorderSide(color: AppTheme.outline, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FilterRow(
            label: 'SORT',
            child: Row(
              children: PackSortMode.values.map((mode) {
                return Padding(
                  padding: const EdgeInsets.only(right: Spacing.xs),
                  child: _SortToggle(
                    mode: mode,
                    selected: mode == sort,
                    onTap: () => onSortChanged(mode),
                  ),
                );
              }).toList(),
            ),
          ),
          if (category == ItemCategory.fauna) ...[
            _divider(),
            _FilterRow(
              label: 'TYPE',
              child: Wrap(
                spacing: Spacing.xs,
                runSpacing: Spacing.xs,
                children: TaxonomicGroup.values
                    .where((g) => g != TaxonomicGroup.other)
                    .map((group) {
                  return _IconFilterToggle(
                    key: ValueKey('filter-type-${group.name}'),
                    icon: group.icon,
                    selected: filters.activeTypes.contains(group),
                    onTap: () => onToggleType(group),
                  );
                }).toList(),
              ),
            ),
          ],
          if (category == ItemCategory.fauna ||
              category == ItemCategory.flora) ...[
            _divider(),
            _FilterRow(
              label: 'HABITAT',
              child: Wrap(
                spacing: Spacing.xs,
                runSpacing: Spacing.xs,
                children: Habitat.values.map((habitat) {
                  return _IconFilterToggle(
                    icon: habitat.icon,
                    selected: filters.activeHabitats.contains(habitat),
                    onTap: () => onToggleHabitat(habitat),
                  );
                }).toList(),
              ),
            ),
          ],
          if (category == ItemCategory.fauna ||
              category == ItemCategory.flora) ...[
            _divider(),
            _FilterRow(
              label: 'REGION',
              child: Wrap(
                spacing: Spacing.xs,
                runSpacing: Spacing.xs,
                children: GameRegion.values
                    .where((r) => r != GameRegion.unknown)
                    .map((region) {
                  return _IconFilterToggle(
                    icon: region.icon,
                    selected: filters.activeRegions.contains(region),
                    onTap: () => onToggleRegion(region),
                  );
                }).toList(),
              ),
            ),
          ],
          _divider(),
          _FilterRow(
            label: 'RARITY',
            child: Wrap(
              spacing: Spacing.xs,
              runSpacing: Spacing.xs,
              children: IucnStatus.values
                  .where((s) => s != IucnStatus.extinct)
                  .map((status) {
                return _RarityFilterToggle(
                  status: status,
                  selected: filters.activeRarities.contains(status),
                  onTap: () => onToggleRarity(status),
                );
              }).toList(),
            ),
          ),
          if (filters.hasActiveFilters) ...[
            _divider(),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.xs,
              ),
              child: GestureDetector(
                onTap: onClearFilters,
                child: Text(
                  'Clear all filters',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.error.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: Spacing.xs),
        ],
      ),
    );
  }

  static Widget _divider() => Container(
        height: 0.5,
        margin: const EdgeInsets.symmetric(horizontal: Spacing.md),
        color: AppTheme.outline.withValues(alpha: 0.4),
      );
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.onSurfaceVariant.withValues(alpha: 0.7),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          child,
        ],
      ),
    );
  }
}

// ─── Toggle components ────────────────────────────────────────────────────────

class _IconFilterToggle extends StatelessWidget {
  const _IconFilterToggle({
    super.key,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.lg),
      splashColor: Colors.transparent,
      highlightColor: AppTheme.primary.withValues(alpha: 0.08),
      child: AnimatedContainer(
        duration: Durations.quick,
        curve: AppCurves.standard,
        width: ComponentSizes.filterToggleSize,
        height: ComponentSizes.filterToggleSize,
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.15)
              : AppTheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.60)
                : AppTheme.outline,
            width: selected ? 1.5 : 1.0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.20),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: Durations.quick,
            style: TextStyle(
              fontSize: ComponentSizes.filterPanelEmoji,
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.75),
            ),
            child: Text(icon),
          ),
        ),
      ),
    );
  }
}

class _SortToggle extends StatelessWidget {
  const _SortToggle({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final PackSortMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.pill),
      splashColor: Colors.transparent,
      highlightColor: AppTheme.secondary.withValues(alpha: 0.08),
      child: AnimatedContainer(
        duration: Durations.quick,
        curve: AppCurves.standard,
        height: ComponentSizes.sortToggleHeight,
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.xs,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.secondary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(
            color: selected
                ? AppTheme.secondary.withValues(alpha: 0.55)
                : Colors.transparent,
            width: selected ? 1.5 : 0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedDefaultTextStyle(
              duration: Durations.quick,
              style: TextStyle(
                fontSize: 16,
                color: selected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.50),
              ),
              child: Text(mode.icon),
            ),
            const SizedBox(width: Spacing.xxs),
            Text(
              mode.label,
              style: TextStyle(
                fontSize: ComponentSizes.filterLabelFont,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color:
                    selected ? AppTheme.secondary : AppTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Rarity filter toggle ─────────────────────────────────────────────────────

class _RarityFilterToggle extends StatelessWidget {
  const _RarityFilterToggle({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final IucnStatus status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.lg),
      splashColor: Colors.transparent,
      child: AnimatedContainer(
        duration: Durations.quick,
        curve: AppCurves.standard,
        width: ComponentSizes.rarityToggleWidth,
        height: ComponentSizes.filterToggleSize,
        decoration: BoxDecoration(
          color: selected
              ? status.color.withValues(alpha: 0.15)
              : AppTheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(
            color: selected
                ? status.color.withValues(alpha: 0.60)
                : AppTheme.outline,
            width: selected ? 1.5 : 1.0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: status.color.withValues(alpha: 0.25),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            status.code,
            style: TextStyle(
              fontSize: ComponentSizes.rarityCodeFont,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? status.color : AppTheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Search bar ───────────────────────────────────────────────────────────────

class _SearchBar extends StatefulWidget {
  const _SearchBar({required this.query, required this.onChanged});
  final String query;
  final void Function(String) onChanged;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(_SearchBar old) {
    super.didUpdateWidget(old);
    if (widget.query != old.query && widget.query != _controller.text) {
      _controller.text = widget.query;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
      margin: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.xl),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search,
            size: 18,
            color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: widget.onChanged,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Search species...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (widget.query.isNotEmpty)
            GestureDetector(
              onTap: _clear,
              child: Icon(
                Icons.close,
                size: 16,
                color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Item grid ────────────────────────────────────────────────────────────────

class _ItemGrid extends StatelessWidget {
  const _ItemGrid({required this.items});
  final List<Item> items;

  static int _columns(double width) {
    if (width < 600) return 3;
    if (width < 900) return 4;
    return 6;
  }

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

  @override
  Widget build(BuildContext context) {
    final status = IucnStatus.fromString(item.rarity);
    final hasFrame2 = item.iconUrlFrame2 != null;

    return GestureDetector(
      onTap: () => showSpeciesCard(context, item),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(Radii.xl),
          border: Border.all(
            color: status != null
                ? status.color.withValues(alpha: status.borderAlpha)
                : AppTheme.outline.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: status != null && status.glowAlpha > 0
              ? [
                  BoxShadow(
                    color: status.color.withValues(alpha: status.glowAlpha),
                    blurRadius: 12,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                children: [
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
                  if (status != null)
                    Positioned(
                      top: Spacing.xs,
                      right: Spacing.xs,
                      child: _RarityBadge(status: status),
                    ),
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
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.xs,
                vertical: Spacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainer.withValues(alpha: 0.85),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(Radii.lg),
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
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Text(
            item.category.emoji,
            style: const TextStyle(fontSize: 28),
          );
        },
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

class _RarityBadge extends StatelessWidget {
  const _RarityBadge({required this.status});
  final IucnStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: status.color,
        borderRadius: BorderRadius.circular(Radii.xs),
        boxShadow: [
          BoxShadow(
            color: status.color.withValues(alpha: 0.5),
            blurRadius: 4,
          ),
        ],
      ),
      child: Text(
        status.code,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w800,
          color: status.fgColor,
          letterSpacing: 0.4,
          height: 1.2,
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.category,
    required this.hasFilters,
  });

  final ItemCategory category;
  final bool hasFilters;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xxxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              hasFilters ? AppIcons.search : category.emoji,
              style: const TextStyle(fontSize: 56),
            ),
            const SizedBox(height: Spacing.md),
            Text(
              hasFilters
                  ? 'No discoveries match your filters'
                  : 'No ${category.label.toLowerCase()} discovered yet',
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
              hasFilters
                  ? 'Try removing some filters'
                  : 'Explore the world to discover wildlife!',
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
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 28,
                  color: AppTheme.error,
                ),
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
