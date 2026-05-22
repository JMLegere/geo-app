import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/identification/domain/entities/discovery_item_draft.dart';
import 'package:earth_nova/features/identification/domain/repositories/item_repository.dart';

class MockItemRepository implements ItemRepository {
  MockItemRepository({List<Item> items = const [], this.shouldThrow = false})
      : _items = List<Item>.from(items);

  final List<Item> _items;
  final bool shouldThrow;

  @override
  Future<List<Item>> fetchItems(String userId, {String? traceId}) async {
    if (shouldThrow) throw Exception('Mock fetch error');
    return List<Item>.unmodifiable(_items);
  }

  @override
  Future<Item> acquireDiscoveryItem(
    DiscoveryItemDraft draft, {
    String? traceId,
  }) async {
    if (shouldThrow) throw Exception('Mock acquire error');
    for (final item in _items) {
      if (item.definitionId == draft.definitionId &&
          item.acquiredInCellId == draft.acquiredInCellId) {
        return item;
      }
    }
    final item = Item(
      id: 'mock-${_items.length + 1}',
      definitionId: draft.definitionId,
      displayName: draft.displayName,
      scientificName: draft.scientificName,
      category: draft.category,
      rarity: draft.rarity,
      acquiredAt: DateTime.now(),
      acquiredInCellId: draft.acquiredInCellId,
      status: ItemStatus.active,
      taxonomicClass: draft.taxonomicClass,
      habitats: draft.habitats,
      continents: draft.continents,
      identificationState: draft.identificationState,
      identifiedAt: draft.identifiedAt,
      identifiedDisplayName: draft.identifiedDisplayName,
      identifiedScientificName: draft.identifiedScientificName,
      identifiedTaxonomicClass: draft.identifiedTaxonomicClass,
      identifiedHabitats: draft.identifiedHabitats,
      identifiedContinents: draft.identifiedContinents,
    );
    _items.insert(0, item);
    return item;
  }

  @override
  Future<Item> identifyUnidentifiedFind(
    Item item, {
    String? traceId,
  }) async {
    if (shouldThrow) throw Exception('Mock identify error');
    final identified = item.identify();
    final index = _items.indexWhere((candidate) => candidate.id == item.id);
    if (index == -1) {
      _items.insert(0, identified);
    } else {
      _items[index] = identified;
    }
    return identified;
  }
}
