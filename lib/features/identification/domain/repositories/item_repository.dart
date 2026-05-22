import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/identification/domain/entities/discovery_item_draft.dart';

abstract class ItemRepository {
  Future<List<Item>> fetchItems(String userId, {String? traceId});
  Future<Item> acquireDiscoveryItem(
    DiscoveryItemDraft draft, {
    String? traceId,
  });
  Future<Item> identifyUnidentifiedFind(
    Item item, {
    String? traceId,
  });
}
