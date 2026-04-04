import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/models/item.dart';
import 'package:earth_nova/services/item_service.dart';

void main() {
  group('MockItemService', () {
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

      final service = MockItemService(items: items);
      final result = await service.fetchItems('user-123');
      expect(result, items);
      expect(result.length, 2);
    });

    test('fetchItems returns empty list when no items', () async {
      final service = MockItemService();
      final result = await service.fetchItems('user-123');
      expect(result, isEmpty);
    });

    test('fetchItems throws when configured to throw', () async {
      final service = MockItemService(shouldThrow: true);
      expect(
        () => service.fetchItems('user-123'),
        throwsA(isA<Exception>()),
      );
    });

    test('implements ItemService interface', () {
      final service = MockItemService();
      expect(service, isA<ItemService>());
    });
  });
}
