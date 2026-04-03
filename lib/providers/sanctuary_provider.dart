import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/models/item_instance.dart';
import 'package:earth_nova/providers/inventory_provider.dart';

/// Derived view — items with [ItemInstanceStatus.placed].
///
/// Computed from [inventoryProvider] on every inventory change.
/// No separate state needed — sanctuary = filter over inventory.
final sanctuaryProvider = Provider<List<ItemInstance>>((ref) {
  final inventory = ref.watch(inventoryProvider);
  return inventory.getByStatus(ItemInstanceStatus.placed);
});
