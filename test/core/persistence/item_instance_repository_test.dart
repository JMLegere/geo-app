/// Tests for ItemInstanceRepository — specifically the upsert path added for
/// the Supabase hydration flow (#130).
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/core/models/affix.dart';
import 'package:earth_nova/core/models/item_category.dart';
import 'package:earth_nova/core/models/item_instance.dart';
import 'package:earth_nova/core/models/iucn_status.dart';
import 'package:earth_nova/core/persistence/item_instance_repository.dart';

import 'test_helpers.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ItemInstance makeItem({
  String id = 'item-1',
  String definitionId = 'fauna_vulpes_vulpes',
  ItemInstanceStatus status = ItemInstanceStatus.active,
  List<Affix> affixes = const [],
}) {
  return ItemInstance(
    id: id,
    definitionId: definitionId,
    displayName: 'Red Fox',
    category: ItemCategory.fauna,
    rarity: IucnStatus.leastConcern,
    status: status,
    affixes: affixes,
    acquiredAt: DateTime(2026, 3, 1),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('ItemInstanceRepository', () {
    late final db = createTestDatabase();
    late final repo = ItemInstanceRepository(db);

    tearDownAll(() async {
      await db.close();
    });

    // ── addItem ───────────────────────────────────────────────────────────────

    test('addItem inserts a new item', () async {
      final item = makeItem(id: 'add-1');
      await repo.addItem(item, 'user-1');

      final found = await repo.getItem('add-1');
      expect(found, isNotNull);
      expect(found!.definitionId, 'fauna_vulpes_vulpes');
    });

    test('addItem throws on duplicate id', () async {
      final item = makeItem(id: 'dup-1');
      await repo.addItem(item, 'user-1');

      expect(
        () => repo.addItem(item, 'user-1'),
        throwsException,
      );
    });

    // ── upsertItem ────────────────────────────────────────────────────────────

    test('upsertItem inserts item when none exists', () async {
      final item = makeItem(id: 'upsert-new-1');
      await repo.upsertItem(item, 'user-1');

      final found = await repo.getItem('upsert-new-1');
      expect(found, isNotNull);
      expect(found!.status, ItemInstanceStatus.active);
    });

    test(
        'upsertItem replaces existing item — server-side status update is '
        'applied locally (#130)', () async {
      // Insert original item.
      final original = makeItem(id: 'upsert-update-1');
      await repo.addItem(original, 'user-1');

      // Upsert with updated status (simulates server returning donated status).
      final updated = makeItem(
        id: 'upsert-update-1',
        status: ItemInstanceStatus.donated,
      );
      await repo.upsertItem(updated, 'user-1');

      final found = await repo.getItem('upsert-update-1');
      expect(found, isNotNull);
      expect(found!.status, ItemInstanceStatus.donated);
    });

    test('upsertItem applies badge updates from server', () async {
      final original = makeItem(id: 'upsert-badge-1');
      await repo.addItem(original, 'user-1');

      // Simulate server awarding first-discovery badge (badges are Set<String>).
      final withBadge = ItemInstance(
        id: 'upsert-badge-1',
        definitionId: original.definitionId,
        displayName: original.displayName,
        category: original.category,
        rarity: original.rarity,
        status: original.status,
        affixes: original.affixes,
        badges: const {'first_discovery'},
        acquiredAt: original.acquiredAt,
      );
      await repo.upsertItem(withBadge, 'user-1');

      final found = await repo.getItem('upsert-badge-1');
      expect(found, isNotNull);
      expect(found!.badges, contains('first_discovery'));
    });
  });
}
