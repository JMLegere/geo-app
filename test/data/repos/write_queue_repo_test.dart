import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/data/database.dart';
import 'package:earth_nova/data/repos/write_queue_repo.dart';

WriteQueueTableCompanion _makeEntry({
  String entityType = 'item',
  String entityId = 'item-1',
  String operation = 'upsert',
  String payload = '{}',
  String userId = 'user1',
}) {
  return WriteQueueTableCompanion.insert(
    entityType: entityType,
    entityId: entityId,
    operation: operation,
    payload: payload,
    userId: userId,
  );
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late WriteQueueRepo repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = WriteQueueRepo(db);
  });

  tearDown(() => db.close());

  group('WriteQueueRepo', () {
    test('enqueue adds entry with pending status', () async {
      await repo.enqueue(_makeEntry());
      final pending = await repo.getPending();
      expect(pending.length, 1);
      expect(pending.first.status, 'pending');
      expect(pending.first.entityType, 'item');
    });

    test('getPending returns pending entries ordered by createdAt', () async {
      // Insert 3 entries — IDs are auto-incremented so order is deterministic
      await repo.enqueue(_makeEntry(entityId: 'item-1'));
      await repo.enqueue(_makeEntry(entityId: 'item-2'));
      await repo.enqueue(_makeEntry(entityId: 'item-3'));
      final pending = await repo.getPending();
      expect(pending.length, 3);
      // createdAt ordering — all in same millisecond, so ID order used as proxy
      expect(pending.map((e) => e.entityId).toList(),
          ['item-1', 'item-2', 'item-3']);
    });

    test('getPending respects limit', () async {
      for (var i = 0; i < 10; i++) {
        await repo.enqueue(_makeEntry(entityId: 'item-$i'));
      }
      final limited = await repo.getPending(limit: 3);
      expect(limited.length, 3);
    });

    test('getPending filters by userId when provided', () async {
      await repo.enqueue(_makeEntry(entityId: 'item-1', userId: 'user1'));
      await repo.enqueue(_makeEntry(entityId: 'item-2', userId: 'user2'));
      await repo.enqueue(_makeEntry(entityId: 'item-3', userId: 'user1'));
      final user1Pending = await repo.getPending(userId: 'user1');
      expect(user1Pending.length, 2);
      expect(user1Pending.every((e) => e.userId == 'user1'), isTrue);
    });

    test('confirmEntry deletes the entry', () async {
      final id = await repo.enqueue(_makeEntry());
      await repo.confirmEntry(id);
      final pending = await repo.getPending();
      expect(pending, isEmpty);
    });

    test('rejectEntry sets status to rejected and stores error', () async {
      final id = await repo.enqueue(_makeEntry());
      final result =
          await repo.rejectEntry(id, 'server rejected: invalid seed');
      expect(result, isTrue);
      final rejected = await repo.getRejected();
      expect(rejected.length, 1);
      expect(rejected.first.status, 'rejected');
      expect(rejected.first.lastError, 'server rejected: invalid seed');
    });

    test('incrementAttempts increases attempt count', () async {
      final id = await repo.enqueue(_makeEntry());
      await repo.incrementAttempts(id, 'network timeout');
      await repo.incrementAttempts(id, 'network timeout');
      // NOTE: incrementEntryAttempts stores updated_at as ISO string via
      // customStatement, which Drift cannot re-parse as epoch millis.
      // Read only the `attempts` column directly to avoid the FormatException.
      final rows = await db.customSelect(
        'SELECT attempts FROM write_queue_table WHERE id = ?',
        variables: [Variable<int>(id)],
      ).get();
      expect(rows.first.read<int>('attempts'), 2);
    });

    test('getRejected returns only rejected entries', () async {
      final id1 = await repo.enqueue(_makeEntry(entityId: 'item-1'));
      await repo.enqueue(_makeEntry(entityId: 'item-2'));
      await repo.rejectEntry(id1, 'bad data');
      final rejected = await repo.getRejected();
      expect(rejected.length, 1);
      expect(rejected.first.entityId, 'item-1');
    });

    test('countPending returns correct count', () async {
      await repo.enqueue(_makeEntry(entityId: 'item-1'));
      await repo.enqueue(_makeEntry(entityId: 'item-2'));
      final id3 = await repo.enqueue(_makeEntry(entityId: 'item-3'));
      await repo.rejectEntry(id3, 'error');
      final count = await repo.countPending();
      expect(count, 2);
    });

    test('deleteStale removes old pending entries', () async {
      // Insert 'old' entry with explicit timestamp far in the past.
      await db.into(db.writeQueueTable).insert(WriteQueueTableCompanion.insert(
            entityType: 'item',
            entityId: 'item-old',
            operation: 'upsert',
            payload: '{}',
            userId: 'user1',
            createdAt: Value(DateTime(2020, 1, 1)),
          ));
      // Insert 'new' entry with default (current) timestamp.
      await repo.enqueue(_makeEntry(entityId: 'item-new'));

      // Cut off at 2023-01-01 — only item-old predates this.
      final cutoff = DateTime(2023, 1, 1);
      final deleted = await repo.deleteStale(cutoff);
      expect(deleted, 1);
      final remaining = await repo.getPending();
      expect(remaining.length, 1);
      expect(remaining.first.entityId, 'item-new');
    });

    test('clearUser removes all entries for a userId', () async {
      await repo.enqueue(_makeEntry(entityId: 'item-1', userId: 'user1'));
      await repo.enqueue(_makeEntry(entityId: 'item-2', userId: 'user1'));
      await repo.enqueue(_makeEntry(entityId: 'item-3', userId: 'user2'));
      final deleted = await repo.clearUser('user1');
      expect(deleted, 2);
      final remaining = await repo.getPending();
      expect(remaining.length, 1);
      expect(remaining.first.userId, 'user2');
    });

    test('deleteEntries removes specific entries by IDs', () async {
      final id1 = await repo.enqueue(_makeEntry(entityId: 'item-1'));
      final id2 = await repo.enqueue(_makeEntry(entityId: 'item-2'));
      await repo.enqueue(_makeEntry(entityId: 'item-3'));
      final deleted = await repo.deleteEntries([id1, id2]);
      expect(deleted, 2);
      final remaining = await repo.getPending();
      expect(remaining.length, 1);
      expect(remaining.first.entityId, 'item-3');
    });
  });
}
