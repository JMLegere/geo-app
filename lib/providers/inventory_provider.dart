import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/models/item_instance.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class InventoryState {
  final List<ItemInstance> items;

  const InventoryState({this.items = const []});

  InventoryState copyWith({List<ItemInstance>? items}) =>
      InventoryState(items: items ?? this.items);

  /// Whether any item with [definitionId] is already owned.
  bool hasDefinition(String definitionId) =>
      items.any((i) => i.definitionId == definitionId);

  List<ItemInstance> getByStatus(ItemInstanceStatus status) =>
      items.where((i) => i.status == status).toList();
}

// ---------------------------------------------------------------------------
// Provider + Notifier
// ---------------------------------------------------------------------------

final inventoryProvider =
    NotifierProvider<InventoryNotifier, InventoryState>(InventoryNotifier.new);

class InventoryNotifier extends Notifier<InventoryState> {
  @override
  InventoryState build() => const InventoryState();

  /// Bulk-load items from SQLite on startup. Replaces current state.
  void loadItems(List<ItemInstance> items) =>
      state = InventoryState(items: List.unmodifiable(items));

  /// Prepend a newly-discovered item.
  void addItem(ItemInstance item) {
    state = state.copyWith(items: [item, ...state.items]);
  }

  /// Remove an item by ID (release / donate / trade).
  void removeItem(String id) => state =
      state.copyWith(items: state.items.where((i) => i.id != id).toList());

  /// Update the status of a single item in-place.
  void updateStatus(String id, ItemInstanceStatus status) {
    state = state.copyWith(
      items: state.items
          .map((i) => i.id == id ? i.copyWith(status: status) : i)
          .toList(),
    );
  }
}
