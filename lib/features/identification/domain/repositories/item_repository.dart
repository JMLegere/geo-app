import 'package:earth_nova/core/domain/entities/item.dart';

abstract class ItemRepository {
  Future<List<Item>> fetchItems(String userId);
}
