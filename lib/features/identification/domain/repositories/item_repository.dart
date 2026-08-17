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

  /// Authoritatively reveals Base Item content for one owned Item instance.
  ///
  /// Concrete default preserves existing lightweight test doubles until they
  /// opt into examination.
  Future<Item> examineItem(Item item, {String? traceId}) =>
      throw UnimplementedError('Item examination is unavailable.');
}
