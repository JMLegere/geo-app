/// Integration test: inventory hydration from SQLite.
///
/// Verifies the hydration pipeline that runs on app startup:
///   SQLite → ItemInstanceRepository → InventoryNotifier.loadItems()
///
/// The real wiring lives in `gameCoordinatorProvider`, which calls
/// `itemRepo.getItemsByUser(userId)` then seeds `inventoryProvider` and
/// `discoveryService.markCollected()` before starting the game loop.
///
/// These tests exercise the same data path end-to-end (in-memory DB →
/// repository → notifier) without needing the full GameCoordinator, which
/// would require mocking LocationService, DiscoveryService, and GPS streams.
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fog_of_world/core/database/app_database.dart';
import 'package:fog_of_world/core/models/item_instance.dart';
import 'package:fog_of_world/core/persistence/item_instance_repository.dart';
import 'package:fog_of_world/core/state/app_database_provider.dart';
import 'package:fog_of_world/core/state/inventory_provider.dart';
import 'package:fog_of_world/core/state/item_instance_repository_provider.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AppDatabase makeInMemoryDb() => AppDatabase(NativeDatabase.memory());

/// Insert a [LocalItemInstance] row into the database.
///
/// Returns the domain [ItemInstance] that the repository would produce
/// for this row, so tests can assert equality without building a second
/// conversion path.
Future<ItemInstance> seedItem(
  AppDatabase db, {
  required String id,
  required String userId,
  required String definitionId,
  String cellId = 'cell-1',
  String affixes = '[]',
  String status = 'active',
}) async {
  final row = LocalItemInstance(
    id: id,
    userId: userId,
    definitionId: definitionId,
    affixes: affixes,
    acquiredAt: DateTime(2026, 3, 1),
    acquiredInCellId: cellId,
    status: status,
  );
  await db.insertItemInstance(row);

  return ItemInstance(
    id: id,
    definitionId: definitionId,
    affixes: ItemInstance.affixesFromJson(affixes),
    acquiredAt: row.acquiredAt,
    acquiredInCellId: cellId,
    status: ItemInstanceStatus.fromString(status),
  );
}

/// Build a [ProviderContainer] with an in-memory database wired through
/// the normal provider chain: appDatabaseProvider → itemInstanceRepositoryProvider.
///
/// The container is NOT disposed automatically — caller must add a tearDown.
ProviderContainer makeContainer(AppDatabase db) {
  return ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      itemInstanceRepositoryProvider.overrideWith(
        (ref) => ItemInstanceRepository(ref.watch(appDatabaseProvider)),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Hydration — Repository Round-Trip', () {
    late AppDatabase db;
    late ItemInstanceRepository repo;

    setUp(() {
      db = makeInMemoryDb();
      repo = ItemInstanceRepository(db);
    });
    tearDown(() => db.close());

    test('getItemsByUser returns empty list for fresh database', () async {
      final items = await repo.getItemsByUser('user-1');
      expect(items, isEmpty);
    });

    test('getItemsByUser returns all items seeded for that user', () async {
      await seedItem(db,
          id: 'item-1', userId: 'user-1', definitionId: 'fauna_vulpes_vulpes');
      await seedItem(db,
          id: 'item-2', userId: 'user-1', definitionId: 'fauna_panthera_leo');
      await seedItem(db,
          id: 'item-3',
          userId: 'user-2',
          definitionId: 'fauna_ursus_arctos');

      final user1Items = await repo.getItemsByUser('user-1');
      expect(user1Items.length, equals(2));
      expect(
        user1Items.map((i) => i.definitionId).toSet(),
        equals({'fauna_vulpes_vulpes', 'fauna_panthera_leo'}),
      );

      // user-2's item is not included.
      final user2Items = await repo.getItemsByUser('user-2');
      expect(user2Items.length, equals(1));
    });

    test('domain conversion preserves all fields', () async {
      final expected = await seedItem(db,
          id: 'item-round-trip',
          userId: 'user-1',
          definitionId: 'fauna_vulpes_vulpes',
          cellId: 'cell-42',
          status: 'active');

      final items = await repo.getItemsByUser('user-1');
      expect(items.length, equals(1));

      final actual = items.first;
      expect(actual.id, equals(expected.id));
      expect(actual.definitionId, equals(expected.definitionId));
      expect(actual.acquiredInCellId, equals(expected.acquiredInCellId));
      expect(actual.status, equals(expected.status));
      expect(actual.affixes, equals(expected.affixes));
    });

    test('items with affixes survive round-trip', () async {
      const affixJson =
          '[{"id":"swift","type":"intrinsic","values":{"speed":45}},'
          '{"id":"mighty","type":"prefix","values":{"brawn":30}}]';

      await seedItem(db,
          id: 'item-affix',
          userId: 'user-1',
          definitionId: 'fauna_vulpes_vulpes',
          affixes: affixJson);

      final items = await repo.getItemsByUser('user-1');
      expect(items.first.affixes.length, equals(2));
      expect(items.first.affixes[0].id, equals('swift'));
      expect(items.first.affixes[1].id, equals('mighty'));
      expect(items.first.affixes[0].values['speed'], equals(45));
      expect(items.first.affixes[1].values['brawn'], equals(30));
    });
  });

  group('Hydration — InventoryNotifier.loadItems()', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = makeInMemoryDb();
      container = makeContainer(db);
    });
    tearDown(() {
      container.dispose();
      db.close();
    });

    test('loadItems replaces inventory with database contents', () async {
      // Seed 3 items in the database.
      final item1 = await seedItem(db,
          id: 'h-1', userId: 'user-1', definitionId: 'fauna_vulpes_vulpes');
      final item2 = await seedItem(db,
          id: 'h-2', userId: 'user-1', definitionId: 'fauna_panthera_leo');
      final item3 = await seedItem(db,
          id: 'h-3', userId: 'user-1', definitionId: 'fauna_ursus_arctos');

      // Simulate the hydration path:
      //   itemRepo.getItemsByUser(userId) → inventoryNotifier.loadItems(items)
      final repo = container.read(itemInstanceRepositoryProvider);
      final items = await repo.getItemsByUser('user-1');
      container.read(inventoryProvider.notifier).loadItems(items);

      // Verify inventory state.
      final state = container.read(inventoryProvider);
      expect(state.totalItems, equals(3));
      expect(
        state.uniqueDefinitionIds,
        equals({item1.definitionId, item2.definitionId, item3.definitionId}),
      );
    });

    test('loadItems replaces (not appends to) existing inventory', () async {
      // Pre-populate inventory with a stale item.
      container.read(inventoryProvider.notifier).addItem(ItemInstance(
            id: 'stale-item',
            definitionId: 'fauna_stale_species',
            acquiredAt: DateTime(2026, 1, 1),
          ));
      expect(container.read(inventoryProvider).totalItems, equals(1));

      // Seed different items in DB.
      await seedItem(db,
          id: 'fresh-1',
          userId: 'user-1',
          definitionId: 'fauna_vulpes_vulpes');
      await seedItem(db,
          id: 'fresh-2',
          userId: 'user-1',
          definitionId: 'fauna_panthera_leo');

      // Hydrate — should REPLACE, not append.
      final repo = container.read(itemInstanceRepositoryProvider);
      final items = await repo.getItemsByUser('user-1');
      container.read(inventoryProvider.notifier).loadItems(items);

      final state = container.read(inventoryProvider);
      expect(state.totalItems, equals(2),
          reason: 'loadItems replaces, not appends');
      expect(state.hasDefinition('fauna_stale_species'), isFalse,
          reason: 'stale item should be wiped');
      expect(state.hasDefinition('fauna_vulpes_vulpes'), isTrue);
      expect(state.hasDefinition('fauna_panthera_leo'), isTrue);
    });

    test('hydrating empty DB produces empty inventory', () async {
      final repo = container.read(itemInstanceRepositoryProvider);
      final items = await repo.getItemsByUser('user-1');
      expect(items, isEmpty);

      // loadItems with empty list → resets to empty.
      container.read(inventoryProvider.notifier).loadItems(items);

      final state = container.read(inventoryProvider);
      expect(state.totalItems, equals(0));
    });
  });

  group('Hydration — Discovery Race Safety', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = makeInMemoryDb();
      container = makeContainer(db);
    });
    tearDown(() {
      container.dispose();
      db.close();
    });

    test('discovery added before hydration is preserved when DB is empty',
        () async {
      // Simulate a discovery arriving BEFORE hydration (race window).
      container.read(inventoryProvider.notifier).addItem(ItemInstance(
            id: 'race-item',
            definitionId: 'fauna_race_species',
            acquiredAt: DateTime.now(),
          ));
      expect(container.read(inventoryProvider).totalItems, equals(1));

      // Now hydration runs — DB is empty, so loadItems([]) would wipe it.
      // The real gameCoordinatorProvider guards this with:
      //   if (items.isNotEmpty) { loadItems(items); }
      // Simulating that guard:
      final repo = container.read(itemInstanceRepositoryProvider);
      final items = await repo.getItemsByUser('user-1');
      if (items.isNotEmpty) {
        container.read(inventoryProvider.notifier).loadItems(items);
      }

      // Race item survives because empty DB skips loadItems.
      expect(container.read(inventoryProvider).totalItems, equals(1));
      expect(
          container.read(inventoryProvider).hasDefinition('fauna_race_species'),
          isTrue);
    });

    test(
        'discovery added before hydration is WIPED when DB has items '
        '(documents the race condition that hydrate-before-start prevents)',
        () async {
      // This test documents WHY hydration MUST complete before the game loop
      // starts. If a discovery sneaks in during the async gap, loadItems()
      // replaces the entire inventory — the race-window item is lost.

      // Simulate: discovery fires first.
      container.read(inventoryProvider.notifier).addItem(ItemInstance(
            id: 'race-item',
            definitionId: 'fauna_race_species',
            acquiredAt: DateTime.now(),
          ));

      // Then hydration fires with DB items.
      await seedItem(db,
          id: 'db-item',
          userId: 'user-1',
          definitionId: 'fauna_vulpes_vulpes');
      final repo = container.read(itemInstanceRepositoryProvider);
      final items = await repo.getItemsByUser('user-1');
      container.read(inventoryProvider.notifier).loadItems(items);

      // Race item is gone — loadItems replaces everything.
      final state = container.read(inventoryProvider);
      expect(state.totalItems, equals(1));
      expect(state.hasDefinition('fauna_race_species'), isFalse,
          reason: 'loadItems wipes pre-hydration items');
      expect(state.hasDefinition('fauna_vulpes_vulpes'), isTrue);
    });

    test('addItem after hydration correctly appends', () async {
      // Seed DB.
      await seedItem(db,
          id: 'db-item',
          userId: 'user-1',
          definitionId: 'fauna_vulpes_vulpes');

      // Hydrate.
      final repo = container.read(itemInstanceRepositoryProvider);
      final items = await repo.getItemsByUser('user-1');
      container.read(inventoryProvider.notifier).loadItems(items);
      expect(container.read(inventoryProvider).totalItems, equals(1));

      // New discovery arrives AFTER hydration — safe.
      container.read(inventoryProvider.notifier).addItem(ItemInstance(
            id: 'new-item',
            definitionId: 'fauna_panthera_leo',
            acquiredAt: DateTime.now(),
          ));

      final state = container.read(inventoryProvider);
      expect(state.totalItems, equals(2));
      expect(state.hasDefinition('fauna_vulpes_vulpes'), isTrue);
      expect(state.hasDefinition('fauna_panthera_leo'), isTrue);
    });
  });

  group('Hydration — Persistence of New Discoveries', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = makeInMemoryDb();
      container = makeContainer(db);
    });
    tearDown(() {
      container.dispose();
      db.close();
    });

    test('item persisted to DB survives a simulated app restart', () async {
      final repo = container.read(itemInstanceRepositoryProvider);

      // Hydrate (empty DB).
      final initial = await repo.getItemsByUser('user-1');
      expect(initial, isEmpty);

      // Discover an item during gameplay → persist to SQLite.
      final newItem = ItemInstance(
        id: 'discovered-1',
        definitionId: 'fauna_vulpes_vulpes',
        acquiredAt: DateTime(2026, 3, 1),
        acquiredInCellId: 'cell-7',
      );
      container.read(inventoryProvider.notifier).addItem(newItem);
      await repo.addItem(newItem, 'user-1');

      // Simulate app restart: new container, same DB.
      container.dispose();
      final container2 = makeContainer(db);
      addTearDown(container2.dispose);

      // Re-hydrate from DB.
      final repo2 = container2.read(itemInstanceRepositoryProvider);
      final persisted = await repo2.getItemsByUser('user-1');
      expect(persisted.length, equals(1));

      container2.read(inventoryProvider.notifier).loadItems(persisted);
      final state = container2.read(inventoryProvider);
      expect(state.totalItems, equals(1));
      expect(state.items.first.id, equals('discovered-1'));
      expect(state.items.first.definitionId, equals('fauna_vulpes_vulpes'));
      expect(state.items.first.acquiredInCellId, equals('cell-7'));
    });

    test('multiple discoveries accumulate across hydration cycles', () async {
      final repo = container.read(itemInstanceRepositoryProvider);

      // Session 1: discover 2 items.
      for (final (i, defId) in [
        'fauna_vulpes_vulpes',
        'fauna_panthera_leo',
      ].indexed) {
        final item = ItemInstance(
          id: 'session1-$i',
          definitionId: defId,
          acquiredAt: DateTime(2026, 3, 1),
        );
        container.read(inventoryProvider.notifier).addItem(item);
        await repo.addItem(item, 'user-1');
      }
      expect(container.read(inventoryProvider).totalItems, equals(2));

      // Session 2: re-hydrate, discover 1 more.
      container.dispose();
      final container2 = makeContainer(db);
      addTearDown(container2.dispose);

      final repo2 = container2.read(itemInstanceRepositoryProvider);
      final persisted = await repo2.getItemsByUser('user-1');
      container2.read(inventoryProvider.notifier).loadItems(persisted);
      expect(container2.read(inventoryProvider).totalItems, equals(2));

      final newItem = ItemInstance(
        id: 'session2-0',
        definitionId: 'fauna_ursus_arctos',
        acquiredAt: DateTime(2026, 3, 2),
      );
      container2.read(inventoryProvider.notifier).addItem(newItem);
      await repo2.addItem(newItem, 'user-1');

      expect(container2.read(inventoryProvider).totalItems, equals(3));

      // Verify DB has all 3.
      final allItems = await repo2.getItemsByUser('user-1');
      expect(allItems.length, equals(3));
    });
  });
}
