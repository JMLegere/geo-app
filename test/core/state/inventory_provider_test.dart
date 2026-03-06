import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/core/models/item_instance.dart';
import 'package:fog_of_world/core/state/inventory_provider.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ItemInstance _makeItem({
  String id = 'item-1',
  String definitionId = 'fauna_vulpes_vulpes',
  String cellId = 'cell-42',
}) =>
    ItemInstance(
      id: id,
      definitionId: definitionId,
      acquiredAt: DateTime(2026, 3, 1),
      acquiredInCellId: cellId,
    );

ProviderContainer _makeContainer() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('InventoryNotifier — initial state', () {
    test('starts with empty items list', () {
      final container = _makeContainer();
      final state = container.read(inventoryProvider);

      expect(state.items, isEmpty);
      expect(state.totalItems, equals(0));
      expect(state.uniqueDefinitionIds, isEmpty);
      expect(state.uniqueDefinitionsCount, equals(0));
    });
  });

  group('InventoryNotifier — addItem', () {
    test('addItem increases totalItems', () {
      final container = _makeContainer();
      container.read(inventoryProvider.notifier).addItem(_makeItem());

      expect(container.read(inventoryProvider).totalItems, equals(1));
    });

    test('addItem adds item to items list', () {
      final container = _makeContainer();
      final item = _makeItem();
      container.read(inventoryProvider.notifier).addItem(item);

      expect(container.read(inventoryProvider).items, contains(item));
    });

    test('adding two items with same definitionId counts as 1 unique definition', () {
      final container = _makeContainer();
      container.read(inventoryProvider.notifier).addItem(
            _makeItem(id: 'item-1', definitionId: 'fauna_fox'),
          );
      container.read(inventoryProvider.notifier).addItem(
            _makeItem(id: 'item-2', definitionId: 'fauna_fox'),
          );

      final state = container.read(inventoryProvider);
      expect(state.totalItems, equals(2));
      expect(state.uniqueDefinitionsCount, equals(1));
    });

    test('adding items with different definitionIds counts each as unique', () {
      final container = _makeContainer();
      container.read(inventoryProvider.notifier).addItem(
            _makeItem(id: 'item-1', definitionId: 'fauna_fox'),
          );
      container.read(inventoryProvider.notifier).addItem(
            _makeItem(id: 'item-2', definitionId: 'fauna_bear'),
          );

      final state = container.read(inventoryProvider);
      expect(state.totalItems, equals(2));
      expect(state.uniqueDefinitionsCount, equals(2));
    });
  });

  group('InventoryNotifier — removeItem', () {
    test('removeItem decreases totalItems', () {
      final container = _makeContainer();
      final item = _makeItem();
      container.read(inventoryProvider.notifier).addItem(item);
      container.read(inventoryProvider.notifier).removeItem(item.id);

      expect(container.read(inventoryProvider).totalItems, equals(0));
    });

    test('removeItem removes correct item by id', () {
      final container = _makeContainer();
      final item1 = _makeItem(id: 'item-1', definitionId: 'fauna_fox');
      final item2 = _makeItem(id: 'item-2', definitionId: 'fauna_bear');
      container.read(inventoryProvider.notifier).addItem(item1);
      container.read(inventoryProvider.notifier).addItem(item2);
      container.read(inventoryProvider.notifier).removeItem('item-1');

      final state = container.read(inventoryProvider);
      expect(state.items.length, equals(1));
      expect(state.items.first.id, equals('item-2'));
    });

    test('removeItem with unknown id is a no-op', () {
      final container = _makeContainer();
      container.read(inventoryProvider.notifier).addItem(_makeItem());
      container.read(inventoryProvider.notifier).removeItem('ghost-id');

      expect(container.read(inventoryProvider).totalItems, equals(1));
    });
  });

  group('InventoryNotifier — updateItemStatus', () {
    test('updateItemStatus changes status of matching item', () {
      final container = _makeContainer();
      final item = _makeItem();
      container.read(inventoryProvider.notifier).addItem(item);
      container
          .read(inventoryProvider.notifier)
          .updateItemStatus(item.id, ItemInstanceStatus.donated);

      final updated = container.read(inventoryProvider).items.first;
      expect(updated.status, equals(ItemInstanceStatus.donated));
    });

    test('updateItemStatus does not affect other items', () {
      final container = _makeContainer();
      final item1 = _makeItem(id: 'item-1');
      final item2 = _makeItem(id: 'item-2', definitionId: 'fauna_bear');
      container.read(inventoryProvider.notifier).addItem(item1);
      container.read(inventoryProvider.notifier).addItem(item2);
      container
          .read(inventoryProvider.notifier)
          .updateItemStatus('item-1', ItemInstanceStatus.released);

      final state = container.read(inventoryProvider);
      final i1 = state.items.firstWhere((i) => i.id == 'item-1');
      final i2 = state.items.firstWhere((i) => i.id == 'item-2');
      expect(i1.status, equals(ItemInstanceStatus.released));
      expect(i2.status, equals(ItemInstanceStatus.active));
    });
  });

  group('InventoryNotifier — loadItems', () {
    test('loadItems replaces all existing items', () {
      final container = _makeContainer();
      container.read(inventoryProvider.notifier).addItem(_makeItem(id: 'old'));

      final newItems = [
        _makeItem(id: 'new-1', definitionId: 'fauna_fox'),
        _makeItem(id: 'new-2', definitionId: 'fauna_bear'),
      ];
      container.read(inventoryProvider.notifier).loadItems(newItems);

      final state = container.read(inventoryProvider);
      expect(state.totalItems, equals(2));
      expect(state.items.map((i) => i.id), containsAll(['new-1', 'new-2']));
      expect(state.items.map((i) => i.id), isNot(contains('old')));
    });

    test('loadItems with empty list clears inventory', () {
      final container = _makeContainer();
      container.read(inventoryProvider.notifier).addItem(_makeItem());
      container.read(inventoryProvider.notifier).loadItems([]);

      expect(container.read(inventoryProvider).totalItems, equals(0));
    });
  });

  group('InventoryState — computed properties', () {
    test('hasDefinition returns true when definition exists', () {
      final container = _makeContainer();
      container.read(inventoryProvider.notifier).addItem(
            _makeItem(definitionId: 'fauna_fox'),
          );

      expect(
        container.read(inventoryProvider).hasDefinition('fauna_fox'),
        isTrue,
      );
    });

    test('hasDefinition returns false when definition absent', () {
      final container = _makeContainer();
      container.read(inventoryProvider.notifier).addItem(
            _makeItem(definitionId: 'fauna_fox'),
          );

      expect(
        container.read(inventoryProvider).hasDefinition('fauna_bear'),
        isFalse,
      );
    });

    test('uniqueDefinitionIds contains all distinct definition IDs', () {
      final container = _makeContainer();
      container.read(inventoryProvider.notifier).addItem(
            _makeItem(id: 'i1', definitionId: 'fauna_fox'),
          );
      container.read(inventoryProvider.notifier).addItem(
            _makeItem(id: 'i2', definitionId: 'fauna_fox'),
          );
      container.read(inventoryProvider.notifier).addItem(
            _makeItem(id: 'i3', definitionId: 'fauna_bear'),
          );

      final ids = container.read(inventoryProvider).uniqueDefinitionIds;
      expect(ids, containsAll(['fauna_fox', 'fauna_bear']));
      expect(ids.length, equals(2));
    });

    test('itemsForDefinition returns all instances of a definition', () {
      final container = _makeContainer();
      container.read(inventoryProvider.notifier).addItem(
            _makeItem(id: 'i1', definitionId: 'fauna_fox'),
          );
      container.read(inventoryProvider.notifier).addItem(
            _makeItem(id: 'i2', definitionId: 'fauna_fox'),
          );
      container.read(inventoryProvider.notifier).addItem(
            _makeItem(id: 'i3', definitionId: 'fauna_bear'),
          );

      final foxItems =
          container.read(inventoryProvider).itemsForDefinition('fauna_fox');
      expect(foxItems.length, equals(2));
      expect(foxItems.map((i) => i.id), containsAll(['i1', 'i2']));
    });
  });

  group('InventoryNotifier — hasDefinition method', () {
    test('notifier.hasDefinition delegates to state', () {
      final container = _makeContainer();
      container.read(inventoryProvider.notifier).addItem(
            _makeItem(definitionId: 'fauna_fox'),
          );

      expect(
        container.read(inventoryProvider.notifier).hasDefinition('fauna_fox'),
        isTrue,
      );
      expect(
        container.read(inventoryProvider.notifier).hasDefinition('fauna_bear'),
        isFalse,
      );
    });
  });
}
