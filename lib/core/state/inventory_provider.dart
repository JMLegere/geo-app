import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fog_of_world/core/models/item_instance.dart';

/// Immutable state for the player's item inventory.
///
/// Holds the in-memory list of all [ItemInstance]s owned by the current
/// player. Each instance is unique (PoE/CryptoKitty model — no stacking).
class InventoryState {
  final List<ItemInstance> items;

  InventoryState({List<ItemInstance>? items}) : items = items ?? [];

  /// Total number of item instances.
  int get totalItems => items.length;

  /// Unique definition IDs across all items.
  Set<String> get uniqueDefinitionIds =>
      items.map((i) => i.definitionId).toSet();

  /// Total number of unique definitions discovered.
  int get uniqueDefinitionsCount => uniqueDefinitionIds.length;

  /// Get all items matching a specific definition ID.
  List<ItemInstance> itemsForDefinition(String definitionId) =>
      items.where((i) => i.definitionId == definitionId).toList();

  /// Whether the player has at least one instance of a definition.
  bool hasDefinition(String definitionId) =>
      items.any((i) => i.definitionId == definitionId);

  InventoryState copyWith({List<ItemInstance>? items}) {
    return InventoryState(items: items ?? this.items);
  }
}

/// Manages the player's item inventory.
///
/// Replaces CollectionNotifier. Instead of tracking species IDs as strings,
/// tracks full [ItemInstance] objects with affixes, provenance, and status.
class InventoryNotifier extends Notifier<InventoryState> {
  @override
  InventoryState build() {
    return InventoryState();
  }

  /// Add a newly discovered item instance.
  void addItem(ItemInstance instance) {
    state = state.copyWith(
      items: [...state.items, instance],
    );
  }

  /// Remove an item instance by ID (e.g. when donated or released).
  void removeItem(String instanceId) {
    state = state.copyWith(
      items: state.items.where((i) => i.id != instanceId).toList(),
    );
  }

  /// Update an item's status (e.g. active → donated).
  void updateItemStatus(String instanceId, ItemInstanceStatus newStatus) {
    state = state.copyWith(
      items: state.items.map((i) {
        if (i.id == instanceId) {
          return i.copyWith(status: newStatus);
        }
        return i;
      }).toList(),
    );
  }

  /// Replace an item instance in-memory (e.g. after server awards a badge).
  void updateItem(ItemInstance updated) {
    state = state.copyWith(
      items: state.items.map((i) {
        if (i.id == updated.id) return updated;
        return i;
      }).toList(),
    );
  }

  /// Load inventory from persistence (called on app startup).
  void loadItems(List<ItemInstance> items) {
    state = InventoryState(items: items);
  }

  /// Check if a specific definition has been collected.
  bool hasDefinition(String definitionId) {
    return state.hasDefinition(definitionId);
  }
}

final inventoryProvider = NotifierProvider<InventoryNotifier, InventoryState>(
    () => InventoryNotifier());
