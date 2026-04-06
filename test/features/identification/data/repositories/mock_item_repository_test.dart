import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/identification/data/repositories/mock_item_repository.dart';
import 'package:earth_nova/features/identification/domain/repositories/item_repository.dart';

void main() {
  group('MockItemRepository', () {
    test('fetchItems returns configured items', () async {
      final items = [
        Item(
          id: '1',
          definitionId: 'def1',
          displayName: 'Red Fox',
          category: ItemCategory.fauna,
          acquiredAt: DateTime(2026),
          status: ItemStatus.active,
        ),
        Item(
          id: '2',
          definitionId: 'def2',
          displayName: 'Oak Tree',
          category: ItemCategory.flora,
          acquiredAt: DateTime(2026),
          status: ItemStatus.active,
        ),
      ];

      final repo = MockItemRepository(items: items);
      final result = await repo.fetchItems('user-123');
      expect(result, items);
      expect(result.length, 2);
    });

    test('fetchItems returns empty list when no items', () async {
      final repo = MockItemRepository();
      final result = await repo.fetchItems('user-123');
      expect(result, isEmpty);
    });

    test('fetchItems throws when configured to throw', () async {
      final repo = MockItemRepository(shouldThrow: true);
      expect(
        () => repo.fetchItems('user-123'),
        throwsA(isA<Exception>()),
      );
    });

    test('implements ItemRepository interface', () {
      final repo = MockItemRepository();
      expect(repo, isA<ItemRepository>());
    });
  });
}
