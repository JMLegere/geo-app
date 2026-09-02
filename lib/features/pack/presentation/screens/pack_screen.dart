import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/app/readiness/app_readiness.dart';
import 'package:earth_nova/core/domain/entities/game_region.dart';
import 'package:earth_nova/core/domain/entities/habitat.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/domain/entities/iucn_status.dart';
import 'package:earth_nova/core/domain/entities/taxonomic_group.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/trace_context.dart';
import 'package:earth_nova/features/identification/presentation/providers/items_provider.dart';
import 'package:earth_nova/features/identification/presentation/screens/identification_service_screen.dart';
import 'package:earth_nova/features/pack/domain/entities/pack_filter_state.dart';
import 'package:earth_nova/features/pack/presentation/widgets/species_card.dart';
import 'package:earth_nova/shared/design.dart';
import 'package:earth_nova/shared/observability/widgets/observable_interaction.dart';
import 'package:earth_nova/shared/observability/widgets/observable_screen.dart';
import 'package:earth_nova/shared/product/player_actions.dart';

/// Direction of a cross-tab edge swipe on [PackScreen].
enum EdgeSwipeDirection { left, right }

enum _PackSortMode {
  recent('Recent'),
  rarity('Rarity'),
  name('A→Z');

  const _PackSortMode(this.label);

  final String label;
}

/// Responsive, searchable collection of acquired Items.
class PackScreen extends ConsumerStatefulWidget {
  const PackScreen({super.key, this.pageController, this.onEdgeSwipe});

  static int get subPageCount => ItemCategory.values.length;

  /// An injected controller remains owned by the caller.
  final PageController? pageController;
  final void Function(EdgeSwipeDirection)? onEdgeSwipe;

  @override
  ConsumerState<PackScreen> createState() => _PackScreenState();
}

class _PackScreenState extends ConsumerState<PackScreen> {
  int _categoryIndex = 0;
  _PackSortMode _sort = _PackSortMode.recent;
  PackFilterState _filters = const PackFilterState();
  bool _panelExpanded = false;
  String _searchQuery = '';
  final Set<String> _examinationsInFlight = {};

  late final bool _ownsController;
  late final PageController _pageController;

  ItemCategory get _category => ItemCategory.values[_categoryIndex];

  @override
  void initState() {
    super.initState();
    _ownsController = widget.pageController == null;
    _pageController = widget.pageController ?? PageController();
    _pageController.addListener(_onPageScrolled);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final items = ref.read(itemsProvider);
      if (!items.hasLoaded && !items.isLoading) {
        ref.read(itemsProvider.notifier).fetchItems();
      }
    });
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScrolled);
    if (_ownsController) _pageController.dispose();
    super.dispose();
  }

  void _logInteraction(
    String actionType,
    String widgetName, {
    PlayerActionId? playerActionId,
    String? telemetryOnlyReason,
    Map<String, dynamic>? data,
  }) {
    ObservableInteraction.log(
      logger: ({required event, required category, data}) {
        ref.read(appObservabilityProvider).log(event, category, data: data);
      },
      screenName: 'pack_screen',
      widgetName: widgetName,
      actionType: actionType,
      payload: data,
      playerActionId: playerActionId,
      telemetryOnlyReason: telemetryOnlyReason,
    );
  }

  void _onPageScrolled() {
    if (!_pageController.hasClients) return;
    final page = _pageController.page;
    if (page == null) return;
    final newIndex = page.round();
    if (newIndex == _categoryIndex) return;

    _logInteraction(
      'category_page_changed',
      'pack_page_view',
      telemetryOnlyReason:
          'Pack category paging refines the open Pack view and is not a separate player action.',
      data: {
        'category': ItemCategory.values[newIndex].name,
        'category_index': newIndex,
      },
    );
    HapticFeedback.selectionClick();
    setState(() {
      _categoryIndex = newIndex;
      _filters = const PackFilterState();
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(itemsProvider);
    final obs = ref.watch(appObservabilityProvider);

    return ObservableScreen(
      screenName: 'pack_screen',
      observability: obs,
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Pack')),
        body: state.isLoading
            ? Center(
                child: Semantics(
                  label: 'Loading Pack',
                  liveRegion: true,
                  child: ExcludeSemantics(child: LoadingDots()),
                ),
              )
            : state.error != null
            ? _PackErrorState(message: state.error!, onRetry: _fetch)
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
                onEdgeSwipe: widget.onEdgeSwipe,
                onItemTapped: _onItemTapped,
                onOpenIdentificationService: _openIdentificationService,
              ),
      ),
    );
  }

  void _fetch() {
    _logInteraction(
      'retry_fetch_items',
      'pack_error_retry',
      telemetryOnlyReason:
          'Pack retry is transport recovery inside the open Pack view.',
    );
    ref.read(itemsProvider.notifier).fetchItems();
  }

  void _onCategoryChanged(int index) {
    _logInteraction(
      'select_category',
      'category_chip',
      telemetryOnlyReason:
          'Pack category selection refines the open Pack view and is not a separate player action.',
      data: {
        'category': ItemCategory.values[index].name,
        'category_index': index,
      },
    );
    HapticFeedback.selectionClick();
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
  }

  void _onSortChanged(_PackSortMode mode) {
    _logInteraction(
      'sort_changed',
      'sort_chip',
      telemetryOnlyReason:
          'Pack sorting refines the open Pack view and is not a separate player action.',
      data: {'sort': mode.name},
    );
    setState(() => _sort = mode);
  }

  void _onToggleType(TaxonomicGroup group) {
    _logInteraction(
      'filter_type_toggled',
      'type_filter_chip',
      telemetryOnlyReason:
          'Pack filtering refines the open Pack view and is not a separate player action.',
      data: {
        'type': group.name,
        'active_after': !_filters.activeTypes.contains(group),
      },
    );
    setState(() => _filters = _filters.toggleType(group));
  }

  void _onToggleHabitat(Habitat habitat) {
    _logInteraction(
      'filter_habitat_toggled',
      'habitat_filter_chip',
      telemetryOnlyReason:
          'Pack filtering refines the open Pack view and is not a separate player action.',
      data: {
        'habitat': habitat.name,
        'active_after': !_filters.activeHabitats.contains(habitat),
      },
    );
    setState(() => _filters = _filters.toggleHabitat(habitat));
  }

  void _onToggleRegion(GameRegion region) {
    _logInteraction(
      'filter_region_toggled',
      'region_filter_chip',
      telemetryOnlyReason:
          'Pack filtering refines the open Pack view and is not a separate player action.',
      data: {
        'region': region.name,
        'active_after': !_filters.activeRegions.contains(region),
      },
    );
    setState(() => _filters = _filters.toggleRegion(region));
  }

  void _onToggleRarity(IucnStatus status) {
    _logInteraction(
      'filter_rarity_toggled',
      'rarity_filter_chip',
      telemetryOnlyReason:
          'Pack filtering refines the open Pack view and is not a separate player action.',
      data: {
        'rarity': status.name,
        'active_after': !_filters.activeRarities.contains(status),
      },
    );
    setState(() => _filters = _filters.toggleRarity(status));
  }

  void _onClearFilters() {
    _logInteraction(
      'clear_filters',
      'clear_filters_button',
      telemetryOnlyReason:
          'Pack filtering refines the open Pack view and is not a separate player action.',
      data: {'active_filter_count': _filters.activeFilterCount},
    );
    setState(() => _filters = const PackFilterState());
  }

  void _onTogglePanel() {
    _logInteraction(
      'toggle_filter_panel',
      'compact_filter_bar',
      telemetryOnlyReason:
          'Pack filter panel toggling refines the open Pack view and is not a separate player action.',
      data: {'expanded_after': !_panelExpanded},
    );
    setState(() => _panelExpanded = !_panelExpanded);
  }

  void _onSearchChanged(String query) {
    _logInteraction(
      'search_changed',
      'search_field',
      telemetryOnlyReason:
          'Pack search refines the open Pack view and is not a separate player action.',
      data: {
        'query_length': query.length,
        'had_previous_query': _searchQuery.isNotEmpty,
      },
    );
    setState(() => _searchQuery = query);
  }

  Future<Item?> _onItemTapped(Item item, {TraceContext? parent}) async {
    if (!item.isExamined) {
      if (!_examinationsInFlight.add(item.id)) return null;
      try {
        final examined = await ref
            .read(itemsProvider.notifier)
            .examinePackItem(item.id, parent: parent);
        return examined?.id == item.id ? examined : null;
      } finally {
        _examinationsInFlight.remove(item.id);
      }
    }
    return item;
  }

  void _openIdentificationService(Item item) {
    _logInteraction(
      'open_identification_service',
      'species_card',
      playerActionId: PlayerActions.openIdentificationService,
      data: {'item_id': item.id, 'category': item.category.name},
    );
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => IdentificationServiceScreen(item: item),
      ),
    );
  }
}

List<Item> _applyFilterAndSort(
  List<Item> items,
  ItemCategory category,
  PackFilterState filters,
  _PackSortMode sort,
  String searchQuery,
) {
  var result = items.where((item) => item.category == category).toList();
  result = result.where(filters.matches).toList();
  if (searchQuery.isNotEmpty) {
    final query = searchQuery.toLowerCase();
    result = result
        .where(
          (item) =>
              item.visibleDisplayName.toLowerCase().contains(query) ||
              (item.visibleScientificName?.toLowerCase().contains(query) ??
                  false),
        )
        .toList();
  }

  switch (sort) {
    case _PackSortMode.recent:
      result.sort((a, b) => b.acquiredAt.compareTo(a.acquiredAt));
    case _PackSortMode.rarity:
      const order = [
        'criticallyEndangered',
        'endangered',
        'vulnerable',
        'nearThreatened',
        'leastConcern',
      ];
      result.sort(
        (a, b) => order
            .indexOf(a.rarity ?? '')
            .compareTo(order.indexOf(b.rarity ?? '')),
      );
    case _PackSortMode.name:
      result.sort(
        (a, b) => a.visibleDisplayName.compareTo(b.visibleDisplayName),
      );
  }
  return result;
}

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
    required this.onEdgeSwipe,
    required this.onItemTapped,
    required this.onOpenIdentificationService,
  });

  final List<Item> allItems;
  final ItemCategory category;
  final _PackSortMode sort;
  final PackFilterState filters;
  final bool panelExpanded;
  final String searchQuery;
  final PageController pageController;
  final void Function(int) onCategoryChanged;
  final void Function(_PackSortMode) onSortChanged;
  final void Function(TaxonomicGroup) onToggleType;
  final void Function(Habitat) onToggleHabitat;
  final void Function(GameRegion) onToggleRegion;
  final void Function(IucnStatus) onToggleRarity;
  final VoidCallback onClearFilters;
  final VoidCallback onTogglePanel;
  final void Function(String) onSearchChanged;
  final void Function(EdgeSwipeDirection)? onEdgeSwipe;
  final Future<Item?> Function(Item, {TraceContext? parent}) onItemTapped;
  final void Function(Item) onOpenIdentificationService;

  @override
  Widget build(BuildContext context) {
    final filtered = _applyFilterAndSort(
      allItems,
      category,
      filters,
      sort,
      searchQuery,
    );

    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          _CategoryRow(
            category: category,
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
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              heightFactor: panelExpanded ? 1 : 0,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * 0.4,
                ),
                child: SingleChildScrollView(
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
            ),
          ),
          _SearchBar(query: searchQuery, onChanged: onSearchChanged),
          Expanded(
            child: NotificationListener<OverscrollNotification>(
              onNotification: (notification) {
                final callback = onEdgeSwipe;
                if (callback == null) return false;
                if (notification.overscroll < 0) {
                  callback(EdgeSwipeDirection.left);
                } else if (notification.overscroll > 0) {
                  callback(EdgeSwipeDirection.right);
                }
                return false;
              },
              child: PageView.builder(
                controller: pageController,
                itemCount: ItemCategory.values.length,
                itemBuilder: (_, index) {
                  final pageCategory = ItemCategory.values[index];
                  final items = _applyFilterAndSort(
                    allItems,
                    pageCategory,
                    filters,
                    sort,
                    searchQuery,
                  );
                  if (items.isEmpty) {
                    return _PackEmptyState(
                      category: pageCategory,
                      isInitialEmpty: allItems.isEmpty,
                      isFiltered:
                          filters.hasActiveFilters || searchQuery.isNotEmpty,
                    );
                  }
                  return _ItemGrid(
                    items: items,
                    onItemTap: onItemTapped,
                    onOpenIdentificationService: onOpenIdentificationService,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category, required this.onCategoryChanged});

  final ItemCategory category;
  final void Function(int) onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('pack-category-row'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (index, value) in ItemCategory.values.indexed)
            ChoiceChip(
              key: ValueKey('pack-category-${value.name}'),
              label: Text(value.label),
              selected: value == category,
              onSelected: (_) => onCategoryChanged(index),
            ),
        ],
      ),
    );
  }
}

class _CompactBar extends StatelessWidget {
  const _CompactBar({
    required this.sort,
    required this.filters,
    required this.count,
    required this.panelExpanded,
    required this.onTogglePanel,
  });

  final _PackSortMode sort;
  final PackFilterState filters;
  final int count;
  final bool panelExpanded;
  final VoidCallback onTogglePanel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      // eac-clickable-owner-logs: onTogglePanel reaches PackScreen._onTogglePanel, which logs its telemetry-only filter-panel action.
      child: InkWell(
        key: const Key('compact-bar'),
        onTap: onTogglePanel,
        child: Semantics(
          button: true,
          expanded: panelExpanded,
          label: 'Filters. ${sort.label}. $count Items',
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  AppBadge(label: sort.label, variant: AppBadgeVariant.outline),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      filters.hasActiveFilters
                          ? '${filters.activeFilterCount} active filters'
                          : 'All discoveries',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '$count',
                    key: const Key('compact-bar-count'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(width: 4),
                  const Text('Items'),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: panelExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.expand_more),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
  final _PackSortMode sort;
  final PackFilterState filters;
  final void Function(_PackSortMode) onSortChanged;
  final void Function(TaxonomicGroup) onToggleType;
  final void Function(Habitat) onToggleHabitat;
  final void Function(GameRegion) onToggleRegion;
  final void Function(IucnStatus) onToggleRarity;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: AppCard(
        title: 'Filters',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FilterSection(
              label: 'SORT',
              children: [
                for (final mode in _PackSortMode.values)
                  ChoiceChip(
                    key: ValueKey('sort-${mode.name}'),
                    label: Text(mode.label),
                    selected: mode == sort,
                    onSelected: (_) => onSortChanged(mode),
                  ),
              ],
            ),
            if (category == ItemCategory.fauna)
              _FilterSection(
                label: 'TYPE',
                children: [
                  for (final group in TaxonomicGroup.values.where(
                    (group) => group != TaxonomicGroup.other,
                  ))
                    FilterChip(
                      key: ValueKey('filter-type-${group.name}'),
                      label: Text(group.label),
                      selected: filters.activeTypes.contains(group),
                      onSelected: (_) => onToggleType(group),
                    ),
                ],
              ),
            if (category == ItemCategory.fauna ||
                category == ItemCategory.flora)
              _FilterSection(
                label: 'HABITAT',
                children: [
                  for (final habitat in Habitat.values)
                    FilterChip(
                      key: ValueKey('filter-habitat-${habitat.name}'),
                      label: Text(habitat.label),
                      selected: filters.activeHabitats.contains(habitat),
                      onSelected: (_) => onToggleHabitat(habitat),
                    ),
                ],
              ),
            if (category == ItemCategory.fauna ||
                category == ItemCategory.flora)
              _FilterSection(
                label: 'REGION',
                children: [
                  for (final region in GameRegion.values.where(
                    (region) => region != GameRegion.unknown,
                  ))
                    FilterChip(
                      key: ValueKey('filter-region-${region.name}'),
                      label: Text(region.label),
                      selected: filters.activeRegions.contains(region),
                      onSelected: (_) => onToggleRegion(region),
                    ),
                ],
              ),
            _FilterSection(
              label: 'CONSERVATION',
              children: [
                for (final status in IucnStatus.values.where(
                  (status) => status != IucnStatus.extinct,
                ))
                  FilterChip(
                    key: ValueKey('filter-conservation-${status.name}'),
                    label: Text(status.code),
                    tooltip: status.displayName,
                    selected: filters.activeRarities.contains(status),
                    onSelected: (_) => onToggleRarity(status),
                  ),
              ],
            ),
            if (filters.hasActiveFilters)
              AppButton(
                key: const Key('clear-filters'),
                label: 'Clear all filters',
                variant: AppButtonVariant.ghost,
                onPressed: onClearFilters,
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }
}

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
  void didUpdateWidget(_SearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query && widget.query != _controller.text) {
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: TextField(
        key: const Key('pack-search'),
        controller: _controller,
        onChanged: widget.onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          labelText: 'Search Pack',
          hintText: 'Name or scientific name',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: widget.query.isEmpty
              ? null
              // eac-clickable-owner-logs: _clear forwards through PackScreen._onSearchChanged, which logs its telemetry-only search action.
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: _clear,
                  icon: const Icon(Icons.close),
                ),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _ItemGrid extends StatelessWidget {
  const _ItemGrid({
    required this.items,
    required this.onItemTap,
    required this.onOpenIdentificationService,
  });

  final List<Item> items;
  final Future<Item?> Function(Item, {TraceContext? parent}) onItemTap;
  final void Function(Item) onOpenIdentificationService;

  static int _columns(double width) {
    if (width < 600) return 3;
    if (width < 900) return 4;
    return 6;
  }

  static double _aspectRatio(int columns) {
    if (columns == 3) return 0.78;
    if (columns == 4) return 0.82;
    return 0.85;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columns(constraints.maxWidth);
        return GridView.builder(
          key: const Key('pack-grid'),
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: _aspectRatio(columns),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: items.length,
          itemBuilder: (_, index) => _ItemSlot(
            item: items[index],
            onItemTap: onItemTap,
            onOpenIdentificationService: onOpenIdentificationService,
          ),
        );
      },
    );
  }
}

class _ItemSlot extends ConsumerStatefulWidget {
  const _ItemSlot({
    required this.item,
    required this.onItemTap,
    required this.onOpenIdentificationService,
  });

  final Item item;
  final Future<Item?> Function(Item, {TraceContext? parent}) onItemTap;
  final void Function(Item) onOpenIdentificationService;

  @override
  ConsumerState<_ItemSlot> createState() => _ItemSlotState();
}

class _ItemSlotState extends ConsumerState<_ItemSlot> {
  bool _busy = false;

  Future<void> _openItem() async {
    if (_busy) return;
    final item = widget.item;
    final examining = !item.isExamined;
    final interaction = ObservableInteractionTrace.start(
      observability: ref.read(appObservabilityProvider),
      interaction: examining
          ? PlayerActions.examinePackItem
          : PlayerActions.inspectPackFind,
      surface: 'pack.item',
      screenName: 'pack_screen',
      widgetName: 'pack_item',
      actionType: examining ? 'examine_pack_item' : 'open_species_card',
      readinessState: ref.read(appReadinessProvider).phase.name,
      payload: {'item_id': item.id, 'category': item.category.name},
    );

    if (examining) {
      setState(() => _busy = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) interaction.complete(transition: 'examination_started');
      });
    }

    Item? openedItem;
    try {
      openedItem = await widget.onItemTap(item, parent: interaction.context);
    } finally {
      if (mounted && examining) setState(() => _busy = false);
    }
    if (!mounted || openedItem == null || openedItem.id != item.id) return;

    showSpeciesCard(
      context,
      openedItem,
      onOpenIdentificationService: widget.onOpenIdentificationService,
    );
    if (!examining) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) interaction.complete(transition: 'species_card_visible');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final status = item.isExamined ? IucnStatus.fromString(item.rarity) : null;
    final silhouetteLabel = 'Unexamined ${item.category.name} Item';

    return Semantics(
      label: item.isExamined ? item.visibleDisplayName : silhouetteLabel,
      button: true,
      enabled: !_busy,
      excludeSemantics: true,
      // eac-clickable-owner-logs: _openItem starts the appropriate PlayerActions ObservableInteractionTrace before opening the species card.
      child: InkWell(
        key: ValueKey('pack-item-${item.id}'),
        onTap: _busy ? null : _openItem,
        child: AppCard(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: _busy
                      ? Semantics(
                          label: 'Examining Item',
                          liveRegion: true,
                          child: ExcludeSemantics(
                            child: SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      : item.isExamined
                      ? _SpeciesIcon(item: item)
                      : const Icon(Icons.help_outline, size: 40),
                ),
              ),
              if (status != null) ...[
                AppBadge(label: status.code, variant: AppBadgeVariant.outline),
                const SizedBox(height: 6),
              ],
              Text(
                item.isExamined ? item.visibleDisplayName : silhouetteLabel,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeciesIcon extends StatelessWidget {
  const _SpeciesIcon({required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) {
    final fallback = _CategoryMediaFallback(item: item);
    final url = item.iconUrl;
    if (url == null || url.isEmpty) return fallback;

    return Image.network(
      url,
      key: ValueKey('pack-media-${item.id}'),
      width: 48,
      height: 48,
      fit: BoxFit.contain,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : fallback,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

class _CategoryMediaFallback extends StatelessWidget {
  const _CategoryMediaFallback({required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: ValueKey('pack-media-fallback-${item.id}'),
      image: true,
      label: '${item.category.label} media unavailable',
      child: ExcludeSemantics(
        child: Icon(_categoryIcon(item.category), size: 36),
      ),
    );
  }
}

IconData _categoryIcon(ItemCategory category) => switch (category) {
  ItemCategory.fauna => Icons.pets_outlined,
  ItemCategory.flora => Icons.local_florist_outlined,
  ItemCategory.mineral => Icons.diamond_outlined,
  ItemCategory.fossil => Icons.history_edu_outlined,
  ItemCategory.artifact => Icons.museum_outlined,
  ItemCategory.food => Icons.restaurant_outlined,
  ItemCategory.orb => Icons.circle_outlined,
};

class _PackEmptyState extends StatelessWidget {
  const _PackEmptyState({
    required this.category,
    required this.isInitialEmpty,
    required this.isFiltered,
  });

  final ItemCategory category;
  final bool isInitialEmpty;
  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    final (title, message) = isFiltered
        ? (
            'No discoveries match your filters',
            'Adjust the search or remove filters to see more Items.',
          )
        : isInitialEmpty
        ? ('Your Pack is empty', 'Explore the map to add your first discovery.')
        : (
            'No ${category.label.toLowerCase()} discovered yet',
            'Explore the map to discover more ${category.label.toLowerCase()}.',
          );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AppEmptyState(title: title, message: message),
        ),
      ),
    );
  }
}

class _PackErrorState extends StatelessWidget {
  const _PackErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AppErrorState(
            title: "Couldn't load your collection",
            message: message,
            retryLabel: 'Try Again',
            onRetry: onRetry,
          ),
        ),
      ),
    );
  }
}
