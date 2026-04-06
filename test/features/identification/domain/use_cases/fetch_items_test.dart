import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/identification/domain/repositories/item_repository.dart';
import 'package:earth_nova/features/identification/domain/use_cases/fetch_items.dart';

class FakeItemRepository implements ItemRepository {
  FakeItemRepository({this.items = const [], this.shouldThrow = false});

  final List<Item> items;
  final bool shouldThrow;

  @override
  Future<List<Item>> fetchItems(String userId) async {
    if (shouldThrow) throw Exception('Fake fetch error');
    return items;
  }
}

Item _testItem() => Item(
      id: 'item-1',
      definitionId: 'def-1',
      displayName: 'Test Ocelot',
      category: ItemCategory.fauna,
      acquiredAt: DateTime(2026, 1, 1),
      status: ItemStatus.active,
    );

void main() {
  group('FetchItems', () {
    test('delegates to repository and returns items', () async {
      final repo = FakeItemRepository(items: [_testItem()]);
      final useCase = FetchItems(repo);
      final result = await useCase.call('user-1');
      expect(result, hasLength(1));
      expect(result.first.id, 'item-1');
    });

    test('propagates repository exceptions', () async {
      final repo = FakeItemRepository(shouldThrow: true);
      final useCase = FetchItems(repo);
      expect(() => useCase.call('user-1'), throwsException);
    });
  });
}
