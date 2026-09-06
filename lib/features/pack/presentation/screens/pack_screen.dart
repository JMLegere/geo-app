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
import 'package:earth_nova/shared/presentation/interface_help_provider.dart';
import 'package:earth_nova/shared/observability/widgets/observable_interaction.dart';
import 'package:earth_nova/shared/observability/widgets/observable_screen.dart';
import 'package:earth_nova/shared/product/player_actions.dart';

/// Direction of a cross-tab edge swipe on [PackScreen].
enum EdgeSwipeDirection { left, right }

enum _PackSortMode {
  recent('Recent'),
  rarity('Conservation'),
  name('Name');

  const _PackSortMode(this.label);

  final String label;
}

typedef _PackView = ({
  String query,
  PackFilterState filters,
  _PackSortMode sort,
  bool reverse,
});

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
  bool _allCategories = false;
  bool _reverse = false;
  final _filterRefresh = ValueNotifier<int>(0);
  String _searchQuery = '';
  final Set<String> _examinationsInFlight = {};
  final Map<int, _PackView> _categoryViews = {};
  final _scrollControllers = List.generate(
    ItemCategory.values.length + 1,
    (_) => ScrollController(),
  );

  _PackView _viewFor(int index) => index == _categoryIndex
      ? (query: _searchQuery, filters: _filters, sort: _sort, reverse: _reverse)
      : _categoryViews[index] ??
            (
              query: '',
              filters: const PackFilterState(),
              sort: _PackSortMode.recent,
              reverse: false,
            );

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
    _filterRefresh.dispose();
    for (final controller in _scrollControllers) {
      controller.dispose();
    }
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
      _categoryViews[_categoryIndex] = (
        query: _searchQuery,
        filters: _filters,
        sort: _sort,
        reverse: _reverse,
      );
      _categoryIndex = newIndex;
      final restored = _categoryViews[newIndex];
      _filters = restored?.filters ?? const PackFilterState();
      _searchQuery = restored?.query ?? '';
      _sort = restored?.sort ?? _PackSortMode.recent;
      _reverse = restored?.reverse ?? false;
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
        body: state.isLoading && !state.hasLoaded && state.items.isEmpty
            ? Center(
                child: Semantics(
                  label: 'Loading Pack',
                  liveRegion: true,
                  child: ExcludeSemantics(child: LoadingDots()),
                ),
              )
            : state.error != null && !state.hasLoaded && state.items.isEmpty
            ? _PackErrorState(message: state.error!, onRetry: _fetch)
            : _PackBody(
                allItems: state.items,
                allCategories: _allCategories,
                reverse: _reverse,
                onScopeChanged: _onScopeChanged,
                onReverse: _onReverse,
                onClearSearchAndFilters: _onClearSearchAndFilters,
                refreshing: state.isLoading,
                refreshFailed: state.error != null,
                onRetry: _fetch,
                category: _category,
                sort: _sort,
                filters: _filters,
                panelExpanded: _panelExpanded,
                searchQuery: _searchQuery,
                pageController: _pageController,
                viewFor: _viewFor,
                scrollControllers: _scrollControllers,
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
    ref.read(interfaceHelpProvider.notifier).dismiss();
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
    if (_allCategories) {
      setState(() => _allCategories = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(index);
        }
      });
      return;
    }
    HapticFeedback.selectionClick();
    _pageController.animateToPage(
      index,
      duration: DesignMotion.of(context, DesignMotion.open),
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
    _filterRefresh.value++;
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
    _filterRefresh.value++;
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
    _filterRefresh.value++;
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
    _filterRefresh.value++;
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
    _filterRefresh.value++;
  }

  void _onScopeChanged(bool allCategories) {
    _logInteraction(
      'search_scope_changed',
      'pack_search_scope',
      telemetryOnlyReason: 'Search scope is a local browsing choice.',
      data: {'all_categories': allCategories},
    );
    setState(() => _allCategories = allCategories);
  }

  void _onReverse() {
    _logInteraction(
      'sort_direction_changed',
      'pack_sort_direction',
      telemetryOnlyReason: 'Sort direction is a local browsing choice.',
    );
    setState(() => _reverse = !_reverse);
  }

  void _onClearSearchAndFilters() {
    _onSearchChanged('');
    _onClearFilters();
  }

  Future<void> _onTogglePanel() async {
    if (_panelExpanded) return;
    _logInteraction(
      'open_filters',
      'pack_filters',
      telemetryOnlyReason:
          'Filters refine the open Pack without changing Items.',
    );
    setState(() => _panelExpanded = true);
    await AppFilterSheet.show(
      context,
      (_) => ListenableBuilder(
        listenable: _filterRefresh,
        builder: (_, _) => AppFilterSheet(
          child: _FilterPanel(
            category: _category,
            sort: _sort,
            filters: _filters,
            onSortChanged: _onSortChanged,
            onToggleType: _onToggleType,
            onToggleHabitat: _onToggleHabitat,
            onToggleRegion: _onToggleRegion,
            onToggleRarity: _onToggleRarity,
            onClearFilters: _onClearFilters,
          ),
        ),
      ),
    );
    if (mounted) setState(() => _panelExpanded = false);
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
  String searchQuery, {
  bool allCategories = false,
  bool reverse = false,
}) {
  var result = items
      .where((item) => allCategories || item.category == category)
      .toList();
  result = result.where(filters.matches).toList();
  if (searchQuery.isNotEmpty) {
    final query = searchQuery.trim().toLowerCase();
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
            .indexOf(a.isExamined ? a.rarity ?? '' : '')
            .compareTo(order.indexOf(b.isExamined ? b.rarity ?? '' : '')),
      );
    case _PackSortMode.name:
      result.sort(
        (a, b) => a.visibleDisplayName.compareTo(b.visibleDisplayName),
      );
  }
  return reverse ? result.reversed.toList() : result;
}

class _PackBody extends StatelessWidget {
  const _PackBody({
    required this.allItems,
    required this.allCategories,
    required this.reverse,
    required this.onScopeChanged,
    required this.onReverse,
    required this.onClearSearchAndFilters,
    required this.refreshing,
    required this.refreshFailed,
    required this.onRetry,
    required this.category,
    required this.sort,
    required this.filters,
    required this.panelExpanded,
    required this.searchQuery,
    required this.pageController,
    required this.viewFor,
    required this.scrollControllers,
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
  final bool allCategories;
  final bool reverse;
  final ValueChanged<bool> onScopeChanged;
  final VoidCallback onReverse;
  final VoidCallback onClearSearchAndFilters;
  final bool refreshing;
  final bool refreshFailed;
  final VoidCallback onRetry;
  final ItemCategory category;
  final _PackSortMode sort;
  final PackFilterState filters;
  final bool panelExpanded;
  final String searchQuery;
  final PageController pageController;
  final _PackView Function(int) viewFor;
  final List<ScrollController> scrollControllers;
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
      allCategories: allCategories,
      reverse: reverse,
    );

    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          if (refreshing)
            const AppNotice(
              title: 'Refreshing Pack',
              message: 'Your loaded Items remain available.',
            ),
          if (refreshFailed)
            Row(
              children: [
                const Expanded(
                  child: AppNotice(
                    title: 'Could not refresh Pack',
                    message: 'Showing your last loaded Items.',
                    tone: AppNoticeTone.warning,
                  ),
                ),
                AppButton(label: 'Retry', onPressed: onRetry),
              ],
            ),
          _CategoryRow(
            category: category,
            onCategoryChanged: onCategoryChanged,
          ),
          AppCard(
            child: Column(
              children: [
                AppSearchField(
                  key: const Key('pack-search'),
                  query: searchQuery,
                  hint: 'Search Pack...',
                  onChanged: onSearchChanged,
                ),
                Wrap(
                  spacing: Spacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AppChoiceMenu<_PackSortMode>(
                      key: const Key('pack-sort'),
                      label: 'Sort',
                      value: sort,
                      choices: [
                        for (final mode in _PackSortMode.values)
                          AppChoice(value: mode, label: mode.label),
                      ],
                      onChanged: onSortChanged,
                    ),
                    AppIconButton(
                      key: const Key('pack-sort-direction'),
                      label: 'Reverse sort direction',
                      icon: reverse
                          ? Icons.arrow_drop_up
                          : Icons.arrow_drop_down,
                      onPressed: onReverse,
                    ),
                    AppChoiceMenu<bool>(
                      key: const Key('pack-search-scope'),
                      label: 'Search scope',
                      value: allCategories,
                      choices: [
                        AppChoice(value: false, label: category.label),
                        const AppChoice(value: true, label: 'All Pack'),
                      ],
                      onChanged: onScopeChanged,
                    ),
                    AppIconButton(
                      key: const Key('compact-bar'),
                      label: 'Filters. ${filters.activeFilterCount} active',
                      icon: Icons.tune,
                      badgeCount: filters.activeFilterCount,
                      onPressed: onTogglePanel,
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${filtered.length}',
                      key: const Key('compact-bar-count'),
                    ),
                    Text(' of ${allItems.length} Items'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: allCategories
                ? (filtered.isEmpty
                      ? _PackEmptyState(
                          category: category,
                          isInitialEmpty: allItems.isEmpty,
                          isFiltered:
                              filters.hasActiveFilters ||
                              searchQuery.isNotEmpty,
                          onClear: onClearSearchAndFilters,
                        )
                      : _ItemGrid(
                          storageKey: const PageStorageKey('pack-grid-all'),
                          controller: scrollControllers.last,
                          items: filtered,
                          onItemTap: onItemTapped,
                          onOpenIdentificationService:
                              onOpenIdentificationService,
                        ))
                : NotificationListener<OverscrollNotification>(
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
                        final view = viewFor(index);
                        final items = _applyFilterAndSort(
                          allItems,
                          pageCategory,
                          view.filters,
                          view.sort,
                          view.query,
                          reverse: view.reverse,
                        );
                        if (items.isEmpty) {
                          return _PackEmptyState(
                            onClear: onClearSearchAndFilters,
                            category: pageCategory,
                            isInitialEmpty: allItems.isEmpty,
                            isFiltered:
                                view.filters.hasActiveFilters ||
                                view.query.isNotEmpty,
                          );
                        }
                        return _ItemGrid(
                          storageKey: PageStorageKey(
                            'pack-grid-${pageCategory.name}',
                          ),
                          controller: scrollControllers[index],
                          items: items,
                          onItemTap: onItemTapped,
                          onOpenIdentificationService:
                              onOpenIdentificationService,
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

class _CategoryRow extends ConsumerWidget {
  const _CategoryRow({required this.category, required this.onCategoryChanged});
  final ItemCategory category;
  final ValueChanged<int> onCategoryChanged;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showLabels = ref.watch(interfaceHelpProvider);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: constraints.maxWidth.clamp(
            8 * DesignMetrics.touchTarget,
            double.infinity,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (index, value) in ItemCategory.values.indexed)
                Expanded(
                  child: AppNavButton(
                    key: ValueKey('pack-category-${value.name}'),
                    label: value.label,
                    icon: Icon(_categoryIcon(value)),
                    compact: true,
                    selected: value == category,
                    showLabel: showLabels,
                    onPressed: () => onCategoryChanged(index),
                  ),
                ),
              Expanded(
                child: AppNavButton(
                  key: const Key('pack-category-help'),
                  label: 'Help',
                  icon: const Icon(Icons.help_outline),
                  compact: true,
                  showLabel: showLabels,
                  selected: showLabels,
                  onPressed: () =>
                      ref.read(interfaceHelpProvider.notifier).toggle(),
                ),
              ),
            ],
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
            if (category == ItemCategory.fauna)
              _FilterSection(
                label: 'TYPE',
                children: [
                  for (final group in TaxonomicGroup.values.where(
                    (group) => group != TaxonomicGroup.other,
                  ))
                    AppToggleChip(
                      key: ValueKey('filter-type-${group.name}'),
                      label: group.label,
                      selected: filters.activeTypes.contains(group),
                      onChanged: (_) => onToggleType(group),
                    ),
                ],
              ),
            if (category == ItemCategory.fauna ||
                category == ItemCategory.flora)
              _FilterSection(
                label: 'HABITAT',
                children: [
                  for (final habitat in Habitat.values)
                    AppToggleChip(
                      key: ValueKey('filter-habitat-${habitat.name}'),
                      label: habitat.label,
                      selected: filters.activeHabitats.contains(habitat),
                      onChanged: (_) => onToggleHabitat(habitat),
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
                    AppToggleChip(
                      key: ValueKey('filter-region-${region.name}'),
                      label: region.label,
                      selected: filters.activeRegions.contains(region),
                      onChanged: (_) => onToggleRegion(region),
                    ),
                ],
              ),
            if (category == ItemCategory.fauna ||
                category == ItemCategory.flora)
              _FilterSection(
                label: 'CONSERVATION',
                children: [
                  for (final status in IucnStatus.values.where(
                    (status) => status != IucnStatus.extinct,
                  ))
                    AppToggleChip(
                      key: ValueKey('filter-conservation-${status.name}'),
                      label: status.code,
                      explanation: status.displayName,
                      selected: filters.activeRarities.contains(status),
                      onChanged: (_) => onToggleRarity(status),
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

class _ItemGrid extends StatelessWidget {
  const _ItemGrid({
    required this.storageKey,
    required this.controller,
    required this.items,
    required this.onItemTap,
    required this.onOpenIdentificationService,
  });

  final PageStorageKey<String> storageKey;
  final ScrollController controller;
  final List<Item> items;
  final Future<Item?> Function(Item, {TraceContext? parent}) onItemTap;
  final void Function(Item) onOpenIdentificationService;

  @override
  Widget build(BuildContext context) => AppCollectionGrid(
    storageKey: storageKey,
    controller: controller,
    itemCount: items.length,
    itemBuilder: (_, index) => _ItemSlot(
      key: ValueKey(items[index].id),
      item: items[index],
      onItemTap: onItemTap,
      onOpenIdentificationService: onOpenIdentificationService,
    ),
  );
}

class _ItemSlot extends ConsumerStatefulWidget {
  const _ItemSlot({
    super.key,
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
    final silhouetteLabel = 'Unknown ${item.category.name} Item';

    return Semantics(
      label: _busy
          ? 'Examining ${item.category.name} Item'
          : item.isExamined
          ? item.visibleDisplayName
          : silhouetteLabel,
      button: true,
      enabled: !_busy,
      excludeSemantics: true,
      // eac-clickable-owner-logs: _openItem starts the appropriate PlayerActions ObservableInteractionTrace before opening the species card.
      child: InkWell(
        key: ValueKey('pack-item-${item.id}'),
        onTap: _busy ? null : _openItem,
        child: AppItemCard(
          unknown: !item.isExamined,
          busy: _busy,
          artwork: item.isExamined
              ? _SpeciesIcon(item: item)
              : const Icon(
                  Icons.help_outline,
                  size: DesignMetrics.navigationIcon,
                ),
          property:
              item.isExamined &&
                  !item.isUnidentified &&
                  item.category == ItemCategory.fauna &&
                  item.taxonomicClass != null
              ? AppCardProperty(
                  label: 'Class',
                  value: item.taxonomicGroup.label,
                )
              : null,
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
    required this.onClear,
  });

  final ItemCategory category;
  final bool isInitialEmpty;
  final bool isFiltered;
  final VoidCallback onClear;

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppEmptyState(title: title, message: message),
              if (isFiltered)
                AppButton(
                  label: 'Clear search and filters',
                  onPressed: onClear,
                ),
            ],
          ),
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
