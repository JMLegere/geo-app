import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/models/item_instance.dart';
import 'package:earth_nova/core/models/item_category.dart';
import 'package:earth_nova/features/items/providers/items_provider.dart';

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
      displayName: 'Test Species',
      category: ItemCategory.fauna,
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
  group('ItemsNotifier — initial state', () {
    test('starts with empty items list', () {
      final container = _makeContainer();
      final state = container.read(itemsProvider);

      expect(state.items, isEmpty);
      expect(state.totalItems, equals(0));
      expect(state.uniqueDefinitionIds, isEmpty);
      expect(state.uniqueDefinitionsCount, equals(0));
    });
  });

  group('ItemsNotifier — addItem', () {
    test('addItem increases totalItems', () {
      final container = _makeContainer();
      container.read(itemsProvider.notifier).addItem(_makeItem());

      expect(container.read(itemsProvider).totalItems, equals(1));
    });

    test('addItem adds item to items list', () {
      final container = _makeContainer();
      final item = _makeItem();
      container.read(itemsProvider.notifier).addItem(item);

      expect(container.read(itemsProvider).items, contains(item));
    });

    test(
        'adding two items with same definitionId counts as 1 unique definition',
        () {
      final container = _makeContainer();
      container.read(itemsProvider.notifier).addItem(
            _makeItem(id: 'item-1', definitionId: 'fauna_fox'),
          );
      container.read(itemsProvider.notifier).addItem(
            _makeItem(id: 'item-2', definitionId: 'fauna_fox'),
          );

      final state = container.read(itemsProvider);
      expect(state.totalItems, equals(2));
      expect(state.uniqueDefinitionsCount, equals(1));
    });

    test('adding items with different definitionIds counts each as unique', () {
      final container = _makeContainer();
      container.read(itemsProvider.notifier).addItem(
            _makeItem(id: 'item-1', definitionId: 'fauna_fox'),
          );
      container.read(itemsProvider.notifier).addItem(
            _makeItem(id: 'item-2', definitionId: 'fauna_bear'),
          );

      final state = container.read(itemsProvider);
      expect(state.totalItems, equals(2));
      expect(state.uniqueDefinitionsCount, equals(2));
    });
  });

  group('ItemsNotifier — removeItem', () {
    test('removeItem decreases totalItems', () {
      final container = _makeContainer();
      final item = _makeItem();
      container.read(itemsProvider.notifier).addItem(item);
      container.read(itemsProvider.notifier).removeItem(item.id);

      expect(container.read(itemsProvider).totalItems, equals(0));
    });

    test('removeItem removes correct item by id', () {
      final container = _makeContainer();
      final item1 = _makeItem(id: 'item-1', definitionId: 'fauna_fox');
      final item2 = _makeItem(id: 'item-2', definitionId: 'fauna_bear');
      container.read(itemsProvider.notifier).addItem(item1);
      container.read(itemsProvider.notifier).addItem(item2);
      container.read(itemsProvider.notifier).removeItem('item-1');

      final state = container.read(itemsProvider);
      expect(state.items.length, equals(1));
      expect(state.items.first.id, equals('item-2'));
    });

    test('removeItem with unknown id is a no-op', () {
      final container = _makeContainer();
      container.read(itemsProvider.notifier).addItem(_makeItem());
      container.read(itemsProvider.notifier).removeItem('ghost-id');

      expect(container.read(itemsProvider).totalItems, equals(1));
    });
  });

  group('ItemsNotifier — updateItemStatus', () {
    test('updateItemStatus changes status of matching item', () {
      final container = _makeContainer();
      final item = _makeItem();
      container.read(itemsProvider.notifier).addItem(item);
      container
          .read(itemsProvider.notifier)
          .updateItemStatus(item.id, ItemInstanceStatus.donated);

      final updated = container.read(itemsProvider).items.first;
      expect(updated.status, equals(ItemInstanceStatus.donated));
    });

    test('updateItemStatus does not affect other items', () {
      final container = _makeContainer();
      final item1 = _makeItem(id: 'item-1');
      final item2 = _makeItem(id: 'item-2', definitionId: 'fauna_bear');
      container.read(itemsProvider.notifier).addItem(item1);
      container.read(itemsProvider.notifier).addItem(item2);
      container
          .read(itemsProvider.notifier)
          .updateItemStatus('item-1', ItemInstanceStatus.released);

      final state = container.read(itemsProvider);
      final i1 = state.items.firstWhere((i) => i.id == 'item-1');
      final i2 = state.items.firstWhere((i) => i.id == 'item-2');
      expect(i1.status, equals(ItemInstanceStatus.released));
      expect(i2.status, equals(ItemInstanceStatus.active));
    });
  });

  group('ItemsNotifier — loadItems', () {
    test('loadItems replaces all existing items', () {
      final container = _makeContainer();
      container.read(itemsProvider.notifier).addItem(_makeItem(id: 'old'));

      final newItems = [
        _makeItem(id: 'new-1', definitionId: 'fauna_fox'),
        _makeItem(id: 'new-2', definitionId: 'fauna_bear'),
      ];
      container.read(itemsProvider.notifier).loadItems(newItems);

      final state = container.read(itemsProvider);
      expect(state.totalItems, equals(2));
      expect(state.items.map((i) => i.id), containsAll(['new-1', 'new-2']));
      expect(state.items.map((i) => i.id), isNot(contains('old')));
    });

    test('loadItems with empty list clears inventory', () {
      final container = _makeContainer();
      container.read(itemsProvider.notifier).addItem(_makeItem());
      container.read(itemsProvider.notifier).loadItems([]);

      expect(container.read(itemsProvider).totalItems, equals(0));
    });
  });

  group('ItemsState — computed properties', () {
    test('hasDefinition returns true when definition exists', () {
      final container = _makeContainer();
      container.read(itemsProvider.notifier).addItem(
            _makeItem(definitionId: 'fauna_fox'),
          );

      expect(
        container.read(itemsProvider).hasDefinition('fauna_fox'),
        isTrue,
      );
    });

    test('hasDefinition returns false when definition absent', () {
      final container = _makeContainer();
      container.read(itemsProvider.notifier).addItem(
            _makeItem(definitionId: 'fauna_fox'),
          );

      expect(
        container.read(itemsProvider).hasDefinition('fauna_bear'),
        isFalse,
      );
    });

    test('uniqueDefinitionIds contains all distinct definition IDs', () {
      final container = _makeContainer();
      container.read(itemsProvider.notifier).addItem(
            _makeItem(id: 'i1', definitionId: 'fauna_fox'),
          );
      container.read(itemsProvider.notifier).addItem(
            _makeItem(id: 'i2', definitionId: 'fauna_fox'),
          );
      container.read(itemsProvider.notifier).addItem(
            _makeItem(id: 'i3', definitionId: 'fauna_bear'),
          );

      final ids = container.read(itemsProvider).uniqueDefinitionIds;
      expect(ids, containsAll(['fauna_fox', 'fauna_bear']));
      expect(ids.length, equals(2));
    });

    test('itemsForDefinition returns all instances of a definition', () {
      final container = _makeContainer();
      container.read(itemsProvider.notifier).addItem(
            _makeItem(id: 'i1', definitionId: 'fauna_fox'),
          );
      container.read(itemsProvider.notifier).addItem(
            _makeItem(id: 'i2', definitionId: 'fauna_fox'),
          );
      container.read(itemsProvider.notifier).addItem(
            _makeItem(id: 'i3', definitionId: 'fauna_bear'),
          );

      final foxItems =
          container.read(itemsProvider).itemsForDefinition('fauna_fox');
      expect(foxItems.length, equals(2));
      expect(foxItems.map((i) => i.id), containsAll(['i1', 'i2']));
    });
  });

  group('ItemsNotifier — hasDefinition method', () {
    test('notifier.hasDefinition delegates to state', () {
      final container = _makeContainer();
      container.read(itemsProvider.notifier).addItem(
            _makeItem(definitionId: 'fauna_fox'),
          );

      expect(
        container.read(itemsProvider.notifier).hasDefinition('fauna_fox'),
        isTrue,
      );
      expect(
        container.read(itemsProvider.notifier).hasDefinition('fauna_bear'),
        isFalse,
      );
    });
  });
}
