import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/models/item_instance.dart';
import 'package:earth_nova/models/item_category.dart';
import 'package:earth_nova/providers/inventory_provider.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ItemInstance _makeItem({
  String id = 'item_1',
  String definitionId = 'def_1',
  String displayName = 'Red Fox',
  ItemInstanceStatus status = ItemInstanceStatus.active,
}) =>
    ItemInstance(
      id: id,
      definitionId: definitionId,
      displayName: displayName,
      category: ItemCategory.fauna,
      acquiredAt: DateTime(2026, 1, 1),
      status: status,
    );

void main() {
  group('InventoryNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('initial state is empty', () {
      final state = container.read(inventoryProvider);
      expect(state.items, isEmpty);
    });

    test('loadItems replaces state with provided items', () {
      final items = [
        _makeItem(id: 'a'),
        _makeItem(id: 'b', displayName: 'Snow Leopard'),
      ];
      container.read(inventoryProvider.notifier).loadItems(items);

      final state = container.read(inventoryProvider);
      expect(state.items.length, 2);
      expect(state.items.map((i) => i.id), containsAll(['a', 'b']));
    });

    test('addItem prepends to items list', () {
      container.read(inventoryProvider.notifier)
        ..loadItems([_makeItem(id: 'existing')])
        ..addItem(_makeItem(id: 'new'));

      final items = container.read(inventoryProvider).items;
      expect(items.first.id, 'new');
      expect(items.length, 2);
    });

    test('removeItem removes item by id', () {
      container.read(inventoryProvider.notifier).loadItems([
        _makeItem(id: 'keep'),
        _makeItem(id: 'remove_me'),
      ]);
      container.read(inventoryProvider.notifier).removeItem('remove_me');

      final items = container.read(inventoryProvider).items;
      expect(items.length, 1);
      expect(items.first.id, 'keep');
    });

    test('updateStatus changes item status in-place', () {
      container
          .read(inventoryProvider.notifier)
          .loadItems([_makeItem(id: 'x', status: ItemInstanceStatus.active)]);
      container
          .read(inventoryProvider.notifier)
          .updateStatus('x', ItemInstanceStatus.placed);

      final item = container
          .read(inventoryProvider)
          .items
          .firstWhere((i) => i.id == 'x');
      expect(item.status, ItemInstanceStatus.placed);
    });

    test('getByStatus filters items by status', () {
      container.read(inventoryProvider.notifier).loadItems([
        _makeItem(id: 'a', status: ItemInstanceStatus.active),
        _makeItem(id: 'b', status: ItemInstanceStatus.placed),
        _makeItem(id: 'c', status: ItemInstanceStatus.active),
      ]);

      final active = container
          .read(inventoryProvider)
          .getByStatus(ItemInstanceStatus.active);
      expect(active.length, 2);
      expect(
          active.every((i) => i.status == ItemInstanceStatus.active), isTrue);
    });

    test('addItem with duplicate id creates a second entry (no dedup)', () {
      // InventoryNotifier does NOT deduplicate by id — each addItem is independent.
      container.read(inventoryProvider.notifier)
        ..loadItems([_makeItem(id: 'dup')])
        ..addItem(_makeItem(id: 'dup'));

      final items = container.read(inventoryProvider).items;
      expect(items.where((i) => i.id == 'dup').length, 2);
    });

    test('loadItems with empty list clears state', () {
      container.read(inventoryProvider.notifier).loadItems([_makeItem()]);
      container.read(inventoryProvider.notifier).loadItems([]);

      expect(container.read(inventoryProvider).items, isEmpty);
    });

    test('state is immutable — modifying returned list does not affect state',
        () {
      container
          .read(inventoryProvider.notifier)
          .loadItems([_makeItem(id: 'orig')]);
      final items = container.read(inventoryProvider).items;

      // Attempt to cast and mutate — should throw or have no effect.
      expect(() => items.add(_makeItem(id: 'hacked')), throwsUnsupportedError);

      // State should be unchanged.
      expect(container.read(inventoryProvider).items.length, 1);
    });

    test('hasDefinition returns true when definitionId is present', () {
      container
          .read(inventoryProvider.notifier)
          .loadItems([_makeItem(definitionId: 'fox_def')]);
      expect(
          container.read(inventoryProvider).hasDefinition('fox_def'), isTrue);
      expect(container.read(inventoryProvider).hasDefinition('other_def'),
          isFalse);
    });
  });
}
