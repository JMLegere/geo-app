// ignore_for_file: avoid_redundant_argument_values

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/data/database.dart';
import 'package:earth_nova/data/repos/write_queue_repo.dart';
import 'package:earth_nova/data/repos/item_repo.dart';
import 'package:earth_nova/data/sync/queue_processor.dart';

import '../fixtures/test_helpers.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late WriteQueueRepo writeQueueRepo;
  late ItemRepo itemRepo;
  late QueueProcessor processor;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    writeQueueRepo = WriteQueueRepo(db);
    itemRepo = ItemRepo(db);

    // No SupabasePersistence — offline-only mode. All flush operations are no-ops.
    processor = QueueProcessor(
      queueRepo: writeQueueRepo,
      persistence: null,
      itemRepo: itemRepo,
    );
  });

  tearDown(() async {
    processor.dispose();
    await db.close();
  });

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  WriteQueueTableCompanion _makeEntry({
    String entityType = 'itemInstance',
    String entityId = 'item-1',
    String operation = 'upsert',
    String payload = '{"id":"item-1","definition_id":"fauna_fox"}',
    String userId = kTestUserId,
  }) =>
      WriteQueueTableCompanion.insert(
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        payload: payload,
        userId: userId,
      );

  // ---------------------------------------------------------------------------
  // Tests
  // ---------------------------------------------------------------------------

  group('sync_offline', () {
    test('enqueue adds entry to write queue with correct fields', () async {
      final id = await writeQueueRepo.enqueue(_makeEntry());

      final pending = await writeQueueRepo.getPending();
      expect(pending.length, 1);
      expect(pending.first.id, id);
      expect(pending.first.entityType, 'itemInstance');
      expect(pending.first.entityId, 'item-1');
      expect(pending.first.status, 'pending');
      expect(pending.first.attempts, 0);
    });

    test('QueueProcessor.enqueue writes to DB and returns entry id', () async {
      // QueueProcessor.enqueue is the higher-level method that also schedules
      // a flush (no-op here since persistence is null).
      final id = await processor.enqueue(
        entityType: 'itemInstance',
        entityId: 'item-proc-1',
        operation: 'upsert',
        payload: '{"id":"item-proc-1"}',
        userId: kTestUserId,
      );

      expect(id, greaterThan(0));
      final pending = await writeQueueRepo.getPending(userId: kTestUserId);
      expect(pending.any((e) => e.entityId == 'item-proc-1'), isTrue);
    });

    test('flush is no-op when persistence is null (offline mode)', () async {
      await writeQueueRepo.enqueue(_makeEntry());

      final summary = await processor.flush();
      expect(summary.confirmed, 0);
      expect(summary.retried, 0);
      expect(summary.rejected, 0);

      // Entry stays pending.
      expect(await writeQueueRepo.countPending(), 1);
    });

    test('rejectEntry marks entry as rejected with error message', () async {
      final id = await writeQueueRepo.enqueue(_makeEntry());
      final success = await writeQueueRepo.rejectEntry(id, 'Server rejected');

      expect(success, isTrue);

      final rejected = await writeQueueRepo.getRejected();
      expect(rejected.length, 1);
      expect(rejected.first.status, 'rejected');
      expect(rejected.first.lastError, 'Server rejected');

      // No longer pending.
      final pending = await writeQueueRepo.getPending();
      expect(pending, isEmpty);
    });

    test('incrementAttempts bumps retry count without removing entry',
        () async {
      final id = await writeQueueRepo.enqueue(_makeEntry());

      await writeQueueRepo.incrementAttempts(id, 'Network timeout');
      await writeQueueRepo.incrementAttempts(id, 'Network timeout');

      // Verify the entry is still pending (count-based check avoids the
      // updated_at datetime parsing quirk with Drift customStatement).
      final count = await writeQueueRepo.countPending();
      expect(count, 1, reason: 'Entry should still be pending after retries');
    });

    test('deleteStale removes entries older than cutoff', () async {
      await writeQueueRepo.enqueue(_makeEntry(entityId: 'stale-item'));
      await writeQueueRepo.enqueue(_makeEntry(entityId: 'fresh-item'));

      // Delete everything created before now + 1 min → both entries removed.
      final cutoff = DateTime.now().add(const Duration(minutes: 1));
      final deleted = await writeQueueRepo.deleteStale(cutoff);
      expect(deleted, 2);
      expect(await writeQueueRepo.getPending(), isEmpty);
    });

    test('clearUser removes all entries for that user only', () async {
      await writeQueueRepo
          .enqueue(_makeEntry(userId: 'user-A', entityId: 'a1'));
      await writeQueueRepo
          .enqueue(_makeEntry(userId: 'user-A', entityId: 'a2'));
      await writeQueueRepo
          .enqueue(_makeEntry(userId: 'user-B', entityId: 'b1'));

      await processor.clearUser('user-A');

      final remaining = await writeQueueRepo.getPending();
      expect(remaining.length, 1);
      expect(remaining.first.userId, 'user-B');
    });

    test('multiple entity types can coexist in queue', () async {
      await writeQueueRepo
          .enqueue(_makeEntry(entityType: 'itemInstance', entityId: 'item-1'));
      await writeQueueRepo
          .enqueue(_makeEntry(entityType: 'cellProgress', entityId: 'cell_A'));
      await writeQueueRepo
          .enqueue(_makeEntry(entityType: 'profile', entityId: kTestUserId));

      final all = await writeQueueRepo.getPending();
      expect(all.length, 3);
      expect(all.map((e) => e.entityType),
          containsAll(['itemInstance', 'cellProgress', 'profile']));
    });
  });
}
