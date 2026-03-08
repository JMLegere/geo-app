import 'package:drift/drift.dart' show driftRuntimeOptions, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/database/app_database.dart';
import 'package:earth_nova/core/models/write_queue_entry.dart';
import 'package:earth_nova/core/persistence/write_queue_repository.dart';

import 'test_helpers.dart';

// ---------------------------------------------------------------------------
// Factories
// ---------------------------------------------------------------------------

/// Enqueue a write queue entry with sensible defaults.
Future<int> enqueueEntry(
  WriteQueueRepository repo, {
  WriteQueueEntityType entityType = WriteQueueEntityType.itemInstance,
  String entityId = 'entity-1',
  WriteQueueOperation operation = WriteQueueOperation.upsert,
  String payload = '{"id":"entity-1"}',
  String userId = 'user-1',
}) {
  return repo.enqueue(
    entityType: entityType,
    entityId: entityId,
    operation: operation,
    payload: payload,
    userId: userId,
  );
}

/// Insert an entry directly into the DB with a custom [createdAt] timestamp.
/// Used for testing [deleteStale] which needs entries with specific timestamps.
Future<int> insertEntryWithTimestamp(
  AppDatabase db, {
  required DateTime createdAt,
  String entityType = 'itemInstance',
  String entityId = 'entity-old',
  String operation = 'upsert',
  String payload = '{}',
  String userId = 'user-1',
  String status = 'pending',
}) {
  return db.insertWriteQueueEntry(
    LocalWriteQueueTableCompanion.insert(
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
      userId: userId,
      status: Value(status),
      attempts: Value(0),
      lastError: const Value(null),
      createdAt: Value(createdAt),
      updatedAt: Value(createdAt),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('WriteQueueRepository', () {
    late AppDatabase db;
    late WriteQueueRepository repo;

    setUp(() {
      db = createTestDatabase();
      repo = WriteQueueRepository(db);
    });

    tearDown(() => db.close());

    // ── enqueue ────────────────────────────────────────────────────────────

    test('enqueue creates entry with correct fields', () async {
      final id = await enqueueEntry(
        repo,
        entityType: WriteQueueEntityType.cellProgress,
        entityId: 'cell-42',
        operation: WriteQueueOperation.upsert,
        payload: '{"cell_id":"cell-42"}',
        userId: 'user-abc',
      );

      expect(id, greaterThan(0));

      final entries = await repo.getPending();
      expect(entries.length, equals(1));

      final entry = entries.first;
      expect(entry.id, equals(id));
      expect(entry.entityType, equals(WriteQueueEntityType.cellProgress));
      expect(entry.entityId, equals('cell-42'));
      expect(entry.operation, equals(WriteQueueOperation.upsert));
      expect(entry.payload, equals('{"cell_id":"cell-42"}'));
      expect(entry.userId, equals('user-abc'));
      expect(entry.status, equals(WriteQueueStatus.pending));
      expect(entry.attempts, equals(0));
      expect(entry.lastError, isNull);
    });

    test('enqueue assigns distinct auto-incremented IDs', () async {
      final id1 = await enqueueEntry(repo, entityId: 'e-1');
      final id2 = await enqueueEntry(repo, entityId: 'e-2');
      final id3 = await enqueueEntry(repo, entityId: 'e-3');

      expect({id1, id2, id3}.length, equals(3));
    });

    // ── getPending ─────────────────────────────────────────────────────────

    test('getPending returns empty list for empty queue', () async {
      final entries = await repo.getPending();
      expect(entries, isEmpty);
    });

    test('getPending returns entries ordered by createdAt ascending', () async {
      // Insert entries with known timestamps so ordering is predictable.
      final now = DateTime(2026, 3, 7, 12, 0, 0);
      await insertEntryWithTimestamp(db,
          createdAt: now.add(const Duration(seconds: 10)), entityId: 'e-c');
      await insertEntryWithTimestamp(db,
          createdAt: now, entityId: 'e-a');
      await insertEntryWithTimestamp(db,
          createdAt: now.add(const Duration(seconds: 5)), entityId: 'e-b');

      final entries = await repo.getPending();
      expect(entries.length, equals(3));
      expect(entries[0].entityId, equals('e-a'));
      expect(entries[1].entityId, equals('e-b'));
      expect(entries[2].entityId, equals('e-c'));
    });

    test('getPending with limit respects the limit', () async {
      for (var i = 0; i < 5; i++) {
        await enqueueEntry(repo, entityId: 'entity-$i');
      }

      final limited = await repo.getPending(limit: 2);
      expect(limited.length, equals(2));
    });

    test('getPending does not return rejected entries', () async {
      final id = await enqueueEntry(repo, entityId: 'to-reject');
      await repo.markRejected(id, 'server_rejected');

      final pending = await repo.getPending();
      expect(pending, isEmpty);
    });

    // ── getRejected ────────────────────────────────────────────────────────

    test('getRejected returns only rejected entries', () async {
      final pendingId = await enqueueEntry(repo, entityId: 'keep-pending');
      final rejectId = await enqueueEntry(repo, entityId: 'to-reject');

      await repo.markRejected(rejectId, 'validation failed');

      final rejected = await repo.getRejected();
      expect(rejected.length, equals(1));
      expect(rejected.first.entityId, equals('to-reject'));
      expect(rejected.first.status, equals(WriteQueueStatus.rejected));

      // Pending entry is unaffected.
      final pending = await repo.getPending();
      expect(pending.length, equals(1));
      expect(pending.first.id, equals(pendingId));
    });

    test('getRejected returns empty list when no rejections', () async {
      await enqueueEntry(repo, entityId: 'normal');
      final rejected = await repo.getRejected();
      expect(rejected, isEmpty);
    });

    // ── countPending ───────────────────────────────────────────────────────

    test('countPending returns correct count', () async {
      expect(await repo.countPending(), equals(0));

      await enqueueEntry(repo, entityId: 'e-1');
      expect(await repo.countPending(), equals(1));

      await enqueueEntry(repo, entityId: 'e-2');
      await enqueueEntry(repo, entityId: 'e-3');
      expect(await repo.countPending(), equals(3));
    });

    test('countPending excludes rejected entries', () async {
      final id1 = await enqueueEntry(repo, entityId: 'e-1');
      await enqueueEntry(repo, entityId: 'e-2');
      await repo.markRejected(id1, 'error');

      expect(await repo.countPending(), equals(1));
    });

    // ── deleteEntry ───────────────────────────────────────────────────────

    test('deleteEntry removes the entry from the queue', () async {
      final id = await enqueueEntry(repo, entityId: 'to-confirm');
      expect(await repo.countPending(), equals(1));

      await repo.deleteEntry(id);

      expect(await repo.countPending(), equals(0));
      final pending = await repo.getPending();
      expect(pending, isEmpty);
    });

    test('deleteEntry only removes the targeted entry', () async {
      final id1 = await enqueueEntry(repo, entityId: 'e-1');
      await enqueueEntry(repo, entityId: 'e-2');
      await enqueueEntry(repo, entityId: 'e-3');

      await repo.deleteEntry(id1);

      expect(await repo.countPending(), equals(2));
      final pending = await repo.getPending();
      expect(pending.map((e) => e.entityId).toList(),
          containsAll(['e-2', 'e-3']));
    });

    test('deleteEntry on non-existent id is a no-op', () async {
      await enqueueEntry(repo, entityId: 'normal');
      await repo.deleteEntry(99999); // Non-existent ID.
      expect(await repo.countPending(), equals(1));
    });

    // ── markRejected ───────────────────────────────────────────────────────

    test('markRejected updates status to rejected with error', () async {
      final id = await enqueueEntry(repo, entityId: 'will-reject');
      await repo.markRejected(id, 'server validation failed');

      final rejected = await repo.getRejected();
      expect(rejected.length, equals(1));
      expect(rejected.first.status, equals(WriteQueueStatus.rejected));
      expect(rejected.first.lastError, equals('server validation failed'));
    });

    test('markRejected removes entry from pending queue', () async {
      final id = await enqueueEntry(repo, entityId: 'will-reject');
      await repo.markRejected(id, 'bad data');

      expect(await repo.countPending(), equals(0));
    });

    test('markRejected preserves other fields', () async {
      final id = await enqueueEntry(
        repo,
        entityType: WriteQueueEntityType.profile,
        entityId: 'profile-1',
        payload: '{"display_name":"Alice"}',
        userId: 'user-alice',
      );
      await repo.markRejected(id, 'duplicate');

      final rejected = await repo.getRejected();
      expect(rejected.first.entityType, equals(WriteQueueEntityType.profile));
      expect(rejected.first.entityId, equals('profile-1'));
      expect(rejected.first.userId, equals('user-alice'));
    });

    // ── incrementAttempts ──────────────────────────────────────────────────

    test('incrementAttempts bumps attempt count and records error', () async {
      final id = await enqueueEntry(repo, entityId: 'retry-me');

      await repo.incrementAttempts(id, 'network timeout');

      final entries = await repo.getPending();
      expect(entries.first.attempts, equals(1));
      expect(entries.first.lastError, equals('network timeout'));
    });

    test('incrementAttempts accumulates across multiple calls', () async {
      final id = await enqueueEntry(repo, entityId: 'retry-me');

      await repo.incrementAttempts(id, 'error 1');
      await repo.incrementAttempts(id, 'error 2');
      await repo.incrementAttempts(id, 'error 3');

      final entries = await repo.getPending();
      expect(entries.first.attempts, equals(3));
      expect(entries.first.lastError, equals('error 3'));
    });

    test('incrementAttempts on non-existent id is a no-op', () async {
      await enqueueEntry(repo, entityId: 'normal');
      await repo.incrementAttempts(99999, 'irrelevant error');
      // The real entry is unaffected.
      final entries = await repo.getPending();
      expect(entries.first.attempts, equals(0));
    });

    // ── deleteStale ────────────────────────────────────────────────────────

    test('deleteStale removes entries older than cutoff', () async {
      final oldTime = DateTime(2020, 1, 1);
      final newTime = DateTime(2026, 3, 7);
      final cutoff = DateTime(2023, 1, 1);

      await insertEntryWithTimestamp(db,
          createdAt: oldTime, entityId: 'old-entry');
      await insertEntryWithTimestamp(db,
          createdAt: newTime, entityId: 'new-entry');

      final deleted = await repo.deleteStale(cutoff);
      expect(deleted, equals(1));

      final remaining = await repo.getPending();
      expect(remaining.length, equals(1));
      expect(remaining.first.entityId, equals('new-entry'));
    });

    test('deleteStale returns 0 when no stale entries', () async {
      await insertEntryWithTimestamp(db,
          createdAt: DateTime(2026, 3, 7), entityId: 'fresh');

      final deleted = await repo.deleteStale(DateTime(2020, 1, 1));
      expect(deleted, equals(0));
    });

    test('deleteStale removes multiple stale entries', () async {
      final past = DateTime(2020, 6, 1);
      final cutoff = DateTime(2024, 1, 1);

      await insertEntryWithTimestamp(db,
          createdAt: past, entityId: 'old-1');
      await insertEntryWithTimestamp(db,
          createdAt: past.add(const Duration(days: 1)), entityId: 'old-2');
      await insertEntryWithTimestamp(db,
          createdAt: DateTime(2026, 1, 1), entityId: 'new-1');

      final deleted = await repo.deleteStale(cutoff);
      expect(deleted, equals(2));
      expect(await repo.countPending(), equals(1));
    });

    test('deleteStale removes both pending and rejected stale entries',
        () async {
      final past = DateTime(2020, 1, 1);
      final cutoff = DateTime(2023, 1, 1);

      await insertEntryWithTimestamp(db,
          createdAt: past, entityId: 'old-pending');
      // Mark one as rejected by updating directly.
      await insertEntryWithTimestamp(db,
          createdAt: past,
          entityId: 'old-rejected',
          status: 'rejected');

      final deleted = await repo.deleteStale(cutoff);
      expect(deleted, equals(2));
    });

    // ── clearUser ──────────────────────────────────────────────────────────

    test('clearUser removes all entries for the specified user', () async {
      await enqueueEntry(repo, entityId: 'u1-e1', userId: 'user-1');
      await enqueueEntry(repo, entityId: 'u1-e2', userId: 'user-1');
      await enqueueEntry(repo, entityId: 'u2-e1', userId: 'user-2');

      final removed = await repo.clearUser('user-1');
      expect(removed, equals(2));

      final remaining = await repo.getPending();
      expect(remaining.length, equals(1));
      expect(remaining.first.userId, equals('user-2'));
    });

    test('clearUser returns 0 when user has no entries', () async {
      await enqueueEntry(repo, entityId: 'e-1', userId: 'user-1');
      final removed = await repo.clearUser('nonexistent-user');
      expect(removed, equals(0));
    });

    test('clearUser does not affect other users', () async {
      await enqueueEntry(repo, entityId: 'u1-e1', userId: 'user-1');
      await enqueueEntry(repo, entityId: 'u2-e1', userId: 'user-2');
      await enqueueEntry(repo, entityId: 'u3-e1', userId: 'user-3');

      await repo.clearUser('user-2');

      expect(await repo.countPending(), equals(2));
      final remaining = await repo.getPending();
      final userIds = remaining.map((e) => e.userId).toSet();
      expect(userIds, equals({'user-1', 'user-3'}));
    });

    test('clearUser removes entries regardless of status', () async {
      await enqueueEntry(repo, entityId: 'pending', userId: 'u1');
      final id2 = await enqueueEntry(repo, entityId: 'to-reject', userId: 'u1');
      await repo.markRejected(id2, 'error');

      final removed = await repo.clearUser('u1');
      expect(removed, equals(2));
    });
  });
}
