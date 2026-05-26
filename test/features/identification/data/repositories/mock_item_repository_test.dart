import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/identification/data/repositories/mock_item_repository.dart';
import 'package:earth_nova/features/identification/domain/repositories/item_repository.dart';
import 'package:earth_nova/features/identification/domain/entities/discovery_item_draft.dart';

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

    test('acquireDiscoveryItem creates and returns a new unidentified item',
        () async {
      final repo = MockItemRepository();
      final draft = DiscoveryItemDraft(
        userId: 'user-123',
        definitionId: 'species.amberwing_warbler',
        displayName: 'Unidentified fauna specimen',
        category: ItemCategory.fauna,
        rarity: 'rare',
        acquiredInCellId: 'cell-1',
        mapCellEntryId: 'entry-1',
        identificationState: ItemIdentificationState.unidentified,
        identifiedDisplayName: 'Amberwing Warbler',
        identifiedScientificName: 'Setophaga aestiva',
        identifiedTaxonomicClass: 'Aves',
        identifiedHabitats: const ['forest'],
        identifiedContinents: const ['North America'],
      );

      final item = await repo.acquireDiscoveryItem(draft);

      expect(item.definitionId, draft.definitionId);
      expect(item.identificationState, ItemIdentificationState.unidentified);
      expect(item.displayName, 'Unidentified fauna specimen');
      expect(item.scientificName, isNull);
      expect(item.identifiedDisplayName, 'Amberwing Warbler');
      expect(item.identifiedScientificName, 'Setophaga aestiva');
      expect(item.identifiedTaxonomicClass, 'Aves');
      expect(item.identifiedHabitats, ['forest']);
      expect(item.identifiedContinents, ['North America']);
      expect(item.visibleDisplayName, 'Unidentified fauna specimen');
      expect(item.category, draft.category);
      expect(item.rarity, draft.rarity);
      expect(item.acquiredInCellId, draft.acquiredInCellId);
      expect((await repo.fetchItems('user-123')).single.id, item.id);
    });

    test('acquireDiscoveryItem reuses existing owned item in the same cell',
        () async {
      final existing = Item(
        id: 'existing-1',
        definitionId: 'species.red_fox',
        displayName: 'Red Fox',
        category: ItemCategory.fauna,
        acquiredAt: DateTime(2026),
        acquiredInCellId: 'cell-2',
        status: ItemStatus.active,
      );
      final repo = MockItemRepository(items: [existing]);
      final draft = DiscoveryItemDraft(
        userId: 'user-123',
        definitionId: 'species.red_fox',
        displayName: 'Red Fox',
        category: ItemCategory.fauna,
        acquiredInCellId: 'cell-2',
        mapCellEntryId: 'entry-2',
      );

      final item = await repo.acquireDiscoveryItem(draft);

      expect(item.id, existing.id);
      expect(await repo.fetchItems('user-123'), [existing]);
    });

    test('acquireDiscoveryItem throws when configured to throw', () async {
      final repo = MockItemRepository(shouldThrow: true);
      final draft = DiscoveryItemDraft(
        userId: 'user-123',
        definitionId: 'species.red_fox',
        displayName: 'Red Fox',
        category: ItemCategory.fauna,
        acquiredInCellId: 'cell-2',
        mapCellEntryId: 'entry-2',
      );

      await expectLater(
          () => repo.acquireDiscoveryItem(draft), throwsA(isA<Exception>()));
    });

    test('implements ItemRepository interface', () {
      final repo = MockItemRepository();
      expect(repo, isA<ItemRepository>());
    });
  });
}
