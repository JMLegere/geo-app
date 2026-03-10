import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/models/item_category.dart';
import 'package:earth_nova/core/models/item_definition.dart';
import 'package:earth_nova/core/models/item_instance.dart';
import 'package:earth_nova/core/state/inventory_provider.dart';
import 'package:earth_nova/core/state/player_provider.dart';
import 'package:earth_nova/features/discovery/providers/discovery_provider.dart';

// ---------------------------------------------------------------------------
// Pack Tab enum
// ---------------------------------------------------------------------------

/// Tabs in the Pack screen. Order matches the scrollable TabBar.
enum PackTab {
  character,
  fauna,
  flora,
  minerals,
  fossils,
  artifacts,
  food,
  orbs;

  String get displayName => switch (this) {
        PackTab.character => 'Character',
        PackTab.fauna => 'Fauna',
        PackTab.flora => 'Flora',
        PackTab.minerals => 'Minerals',
        PackTab.fossils => 'Fossils',
        PackTab.artifacts => 'Artifacts',
        PackTab.food => 'Food',
        PackTab.orbs => 'Orbs',
      };

  String get icon => switch (this) {
        PackTab.character => '🧑',
        PackTab.fauna => '🐾',
        PackTab.flora => '🌿',
        PackTab.minerals => '💎',
        PackTab.fossils => '🦴',
        PackTab.artifacts => '🏺',
        PackTab.food => '🍎',
        PackTab.orbs => '🔮',
      };

  /// Maps tab to the corresponding ItemCategory (null for character tab).
  ItemCategory? get itemCategory => switch (this) {
        PackTab.character => null,
        PackTab.fauna => ItemCategory.fauna,
        PackTab.flora => ItemCategory.flora,
        PackTab.minerals => ItemCategory.mineral,
        PackTab.fossils => ItemCategory.fossil,
        PackTab.artifacts => ItemCategory.artifact,
        PackTab.food => ItemCategory.food,
        PackTab.orbs => ItemCategory.orb,
      };
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Immutable snapshot of the Pack tab state.
///
/// Pack = inventory. Shows items the player HAS (ItemInstance objects),
/// NOT a species encyclopedia. The old 32k FaunaDefinition list is removed.
class PackState {
  /// All active item instances, grouped by category.
  final Map<ItemCategory, List<ItemInstance>> itemsByCategory;

  /// Currently selected tab.
  final PackTab activeTab;

  /// Player stats for the Character tab.
  final PlayerState playerStats;

  PackState({
    this.itemsByCategory = const {},
    this.activeTab = PackTab.character,
    PlayerState? playerStats,
  }) : playerStats = playerStats ?? PlayerState();

  /// Items for the currently selected category tab.
  List<ItemInstance> get activeItems {
    final category = activeTab.itemCategory;
    if (category == null) return const []; // character tab
    return itemsByCategory[category] ?? const [];
  }

  /// Total item count across all categories.
  int get totalItems {
    int count = 0;
    for (final items in itemsByCategory.values) {
      count += items.length;
    }
    return count;
  }

  /// Count for a specific category.
  int countForCategory(ItemCategory category) =>
      itemsByCategory[category]?.length ?? 0;

  /// Unique species count (fauna only, for progress display).
  int get uniqueFaunaCount {
    final faunaItems = itemsByCategory[ItemCategory.fauna] ?? const [];
    return faunaItems.map((i) => i.definitionId).toSet().length;
  }

  PackState copyWith({
    Map<ItemCategory, List<ItemInstance>>? itemsByCategory,
    PackTab? activeTab,
    PlayerState? playerStats,
  }) {
    return PackState(
      itemsByCategory: itemsByCategory ?? this.itemsByCategory,
      activeTab: activeTab ?? this.activeTab,
      playerStats: playerStats ?? this.playerStats,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class PackNotifier extends Notifier<PackState> {
  @override
  PackState build() {
    // Listen to inventory changes — regroup items by category.
    ref.listen(inventoryProvider, (_, next) {
      _updateFromInventory(next);
    });

    // Listen to player stats changes.
    ref.listen(playerProvider, (_, next) {
      state = state.copyWith(playerStats: next);
    });

    // Initial state from current inventory.
    final inventory = ref.read(inventoryProvider);
    final playerStats = ref.read(playerProvider);

    return PackState(
      itemsByCategory: _groupByCategory(inventory.items),
      playerStats: playerStats,
    );
  }

  void _updateFromInventory(InventoryState inventory) {
    state = state.copyWith(
      itemsByCategory: _groupByCategory(inventory.items),
    );
  }

  /// Set the active tab.
  void setActiveTab(PackTab tab) {
    state = state.copyWith(activeTab: tab);
  }

  /// Resolve a FaunaDefinition from a definitionId.
  ///
  /// Reads [speciesServiceProvider] on-demand for definition lookup.
  FaunaDefinition? resolveFauna(String definitionId) {
    final service = ref.read(speciesServiceProvider);
    try {
      return service.all.firstWhere((s) => s.id == definitionId);
    } catch (_) {
      return null;
    }
  }

  /// Groups items by their category, filtering to active items only.
  ///
  /// Uses the denormalized [ItemInstance.category] field directly. Falls
  /// back to prefix-based inference for pre-denormalization items whose
  /// category is still the default.
  static Map<ItemCategory, List<ItemInstance>> _groupByCategory(
    List<ItemInstance> items,
  ) {
    final map = <ItemCategory, List<ItemInstance>>{};
    for (final item in items) {
      if (item.status != ItemInstanceStatus.active) continue;
      (map[item.category] ??= []).add(item);
    }
    return map;
  }
}

/// Global provider for [PackNotifier].
final packProvider =
    NotifierProvider<PackNotifier, PackState>(PackNotifier.new);
