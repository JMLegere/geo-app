import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/data/database.dart';
import 'package:earth_nova/data/repos/item_repo.dart';

ItemsTableCompanion _makeItem({
  required String id,
  String userId = 'user1',
  String definitionId = 'fauna_vulpes_vulpes',
  String status = 'active',
  String displayName = 'Red Fox',
}) {
  return ItemsTableCompanion.insert(
    id: id,
    userId: userId,
    definitionId: definitionId,
    acquiredAt: DateTime(2026, 1, 1),
    status: Value(status),
    displayName: Value(displayName),
  );
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late ItemRepo repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = ItemRepo(db);
  });

  tearDown(() => db.close());

  group('ItemRepo', () {
    test('create inserts new item', () async {
      await repo.create(_makeItem(id: 'item-1'));
      final result = await repo.get('item-1');
      expect(result, isNotNull);
      expect(result!.id, 'item-1');
    });

    test('get retrieves item by ID', () async {
      await repo.create(_makeItem(id: 'item-abc', displayName: 'Wolf'));
      final result = await repo.get('item-abc');
      expect(result!.displayName, 'Wolf');
    });

    test('get returns null for non-existent ID', () async {
      final result = await repo.get('nonexistent-id');
      expect(result, isNull);
    });

    test('getAll returns all items for userId', () async {
      await repo.create(_makeItem(id: 'item-1', userId: 'user1'));
      await repo.create(_makeItem(id: 'item-2', userId: 'user1'));
      await repo.create(_makeItem(id: 'item-3', userId: 'user2'));
      final results = await repo.getAll('user1');
      expect(results.length, 2);
      expect(results.map((i) => i.id), containsAll(['item-1', 'item-2']));
    });

    test('getAll returns empty list for unknown userId', () async {
      await repo.create(_makeItem(id: 'item-1', userId: 'user1'));
      final results = await repo.getAll('unknown-user');
      expect(results, isEmpty);
    });

    test('getByStatus filters by active status', () async {
      await repo
          .create(_makeItem(id: 'item-1', userId: 'user1', status: 'active'));
      await repo
          .create(_makeItem(id: 'item-2', userId: 'user1', status: 'donated'));
      await repo
          .create(_makeItem(id: 'item-3', userId: 'user1', status: 'placed'));
      final active = await repo.getByStatus('user1', 'active');
      expect(active.length, 1);
      expect(active.first.id, 'item-1');
    });

    test('getByStatus filters by donated status', () async {
      await repo
          .create(_makeItem(id: 'item-1', userId: 'user1', status: 'active'));
      await repo
          .create(_makeItem(id: 'item-2', userId: 'user1', status: 'donated'));
      final donated = await repo.getByStatus('user1', 'donated');
      expect(donated.length, 1);
      expect(donated.first.id, 'item-2');
    });

    test('update modifies existing item', () async {
      await repo.create(_makeItem(id: 'item-1'));
      final updated = await repo.update(
        'item-1',
        const ItemsTableCompanion(status: Value('placed')),
      );
      expect(updated, isTrue);
      final result = await repo.get('item-1');
      expect(result!.status, 'placed');
    });

    test('update returns false for non-existent item', () async {
      final updated = await repo.update(
        'ghost-item',
        const ItemsTableCompanion(status: Value('placed')),
      );
      expect(updated, isFalse);
    });

    test('delete removes item', () async {
      await repo.create(_makeItem(id: 'item-1'));
      final count = await repo.delete('item-1');
      expect(count, 1);
      final result = await repo.get('item-1');
      expect(result, isNull);
    });

    test('create with duplicate ID updates via conflict resolution', () async {
      await repo.create(_makeItem(id: 'item-1', displayName: 'Red Fox'));
      await repo.create(_makeItem(id: 'item-1', displayName: 'Arctic Fox'));
      final result = await repo.get('item-1');
      expect(result!.displayName, 'Arctic Fox');
    });

    test('items persist across operations without accidental deletion',
        () async {
      await repo.create(_makeItem(id: 'item-1', userId: 'user1'));
      await repo.create(_makeItem(id: 'item-2', userId: 'user1'));
      await repo.create(_makeItem(id: 'item-3', userId: 'user1'));
      // Update one item
      await repo.update(
          'item-2', const ItemsTableCompanion(status: Value('donated')));
      // Delete another
      await repo.delete('item-3');
      final all = await repo.getAll('user1');
      expect(all.length, 2);
      expect(all.map((i) => i.id), containsAll(['item-1', 'item-2']));
    });

    test('getAll with 50 items returns all 50', () async {
      for (var i = 0; i < 50; i++) {
        await repo.create(_makeItem(id: 'item-$i', userId: 'bulkuser'));
      }
      final results = await repo.getAll('bulkuser');
      expect(results.length, 50);
    });

    test('getByStatus after status update returns item in new category',
        () async {
      await repo
          .create(_makeItem(id: 'item-1', userId: 'user1', status: 'active'));
      await repo.update(
          'item-1', const ItemsTableCompanion(status: Value('placed')));
      final active = await repo.getByStatus('user1', 'active');
      final placed = await repo.getByStatus('user1', 'placed');
      expect(active, isEmpty);
      expect(placed.length, 1);
    });
  });
}
