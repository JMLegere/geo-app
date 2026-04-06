import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/identification/domain/repositories/item_repository.dart';

class MockItemRepository implements ItemRepository {
  MockItemRepository({this.items = const [], this.shouldThrow = false});

  final List<Item> items;
  final bool shouldThrow;

  @override
  Future<List<Item>> fetchItems(String userId) async {
    if (shouldThrow) throw Exception('Mock fetch error');
    return items;
  }
}
