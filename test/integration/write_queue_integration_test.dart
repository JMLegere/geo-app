/// Integration test: write queue full round-trip.
///
/// Exercises the full lifecycle of write queue entries through SQLite:
///   enqueue → getPending → deleteEntry / markRejected / incrementAttempts → deleteStale
///
/// Uses an in-memory Drift database (no file I/O) for isolation and speed.
library;

import 'package:drift/drift.dart' show driftRuntimeOptions, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/core/database/app_database.dart';
import 'package:earth_nova/core/models/write_queue_entry.dart';
import 'package:earth_nova/core/persistence/write_queue_repository.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AppDatabase makeInMemoryDb() => AppDatabase(NativeDatabase.memory());

/// Insert an entry directly into the DB with an explicit [createdAt] timestamp.
/// Used for controlling age in deleteStale tests.
Future<int> insertEntryWithTimestamp(
  AppDatabase db, {
  required DateTime createdAt,
  String entityType = 'itemInstance',
  String entityId = 'entity',
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

  group('Write Queue — Full Round-Trip', () {
    late AppDatabase db;
    late WriteQueueRepository repo;

    setUp(() {
      db = makeInMemoryDb();
      repo = WriteQueueRepository(db);
    });

    tearDown(() => db.close());

    test('enqueue, read, confirm, reject, increment, deleteStale full flow',
        () async {
      // ── Step 1: Enqueue 3 entries ──────────────────────────────────────────

      final itemId = await repo.enqueue(
        entityType: WriteQueueEntityType.itemInstance,
        entityId: 'item-uuid-abc',
        operation: WriteQueueOperation.upsert,
        payload: '{"id":"item-uuid-abc","definition_id":"fauna_vulpes_vulpes",'
            '"affixes":"[]","acquired_at":"2026-03-07T00:00:00.000Z",'
            '"status":"active"}',
        userId: 'user-1',
      );

      final cellId = await repo.enqueue(
        entityType: WriteQueueEntityType.cellProgress,
        entityId: 'cell-xyz',
        operation: WriteQueueOperation.upsert,
        payload: '{"cell_id":"cell-xyz","fog_state":"observed",'
            '"distance_walked":250.0,"visit_count":3,"restoration_level":0.67}',
        userId: 'user-1',
      );

      final profileId = await repo.enqueue(
        entityType: WriteQueueEntityType.profile,
        entityId: 'user-1',
        operation: WriteQueueOperation.upsert,
        payload: '{"display_name":"Alice","current_streak":7,'
            '"longest_streak":12,"total_distance_km":5.4}',
        userId: 'user-1',
      );

      // ── Step 2: Read pending — verify 3 entries in createdAt order ─────────

      final pending = await repo.getPending();
      expect(pending.length, equals(3));

      // All start as pending.
      expect(pending.every((e) => e.status == WriteQueueStatus.pending), isTrue);

      // IDs are distinct and match what enqueue returned.
      final ids = pending.map((e) => e.id).toList();
      expect(ids, containsAll([itemId, cellId, profileId]));

      // Verify entity types are correct.
      final byId = {for (final e in pending) e.id: e};
      expect(byId[itemId]!.entityType,
          equals(WriteQueueEntityType.itemInstance));
      expect(byId[cellId]!.entityType,
          equals(WriteQueueEntityType.cellProgress));
      expect(byId[profileId]!.entityType,
          equals(WriteQueueEntityType.profile));

      // Verify entityId and userId are persisted.
      expect(byId[itemId]!.entityId, equals('item-uuid-abc'));
      expect(byId[cellId]!.entityId, equals('cell-xyz'));
      expect(byId[profileId]!.userId, equals('user-1'));

      // Verify operations.
      expect(byId[itemId]!.operation, equals(WriteQueueOperation.upsert));
      expect(byId[cellId]!.operation, equals(WriteQueueOperation.upsert));

      // ── Step 3: Delete confirmed entry — verify only 2 pending remain ───

      await repo.deleteEntry(itemId);

      final afterConfirm = await repo.getPending();
      expect(afterConfirm.length, equals(2));
      expect(afterConfirm.any((e) => e.id == itemId), isFalse,
          reason: 'confirmed entry should be deleted');
      expect(afterConfirm.any((e) => e.id == cellId), isTrue);
      expect(afterConfirm.any((e) => e.id == profileId), isTrue);

      // countPending matches.
      expect(await repo.countPending(), equals(2));

      // ── Step 4: Mark second (cell) rejected with error ─────────────────────

      await repo.markRejected(cellId, 'server_validation_failed');

      // Pending count drops.
      expect(await repo.countPending(), equals(1));

      // Rejected entries are retrievable.
      final rejected = await repo.getRejected();
      expect(rejected.length, equals(1));
      expect(rejected.first.id, equals(cellId));
      expect(rejected.first.status, equals(WriteQueueStatus.rejected));
      expect(rejected.first.lastError, equals('server_validation_failed'));
      expect(rejected.first.entityType,
          equals(WriteQueueEntityType.cellProgress));

      // Profile entry still pending.
      final stillPending = await repo.getPending();
      expect(stillPending.length, equals(1));
      expect(stillPending.first.id, equals(profileId));

      // ── Step 5: Increment attempts on profile entry ────────────────────────

      await repo.incrementAttempts(profileId, 'network timeout #1');

      // Verify attempt count.
      final afterIncrement1 = await repo.getPending();
      expect(afterIncrement1.first.attempts, equals(1));
      expect(afterIncrement1.first.lastError, equals('network timeout #1'));

      // Increment again.
      await repo.incrementAttempts(profileId, 'network timeout #2');
      final afterIncrement2 = await repo.getPending();
      expect(afterIncrement2.first.attempts, equals(2));
      expect(afterIncrement2.first.lastError, equals('network timeout #2'));

      // Status remains pending (not rejected).
      expect(afterIncrement2.first.status, equals(WriteQueueStatus.pending));
    });

    test('deleteStale cleans up old entries while preserving recent ones',
        () async {
      final past = DateTime(2022, 6, 1);
      final recent = DateTime(2026, 3, 7);
      final cutoff = DateTime(2024, 1, 1);

      // Insert one stale and one fresh entry directly with controlled timestamps.
      await insertEntryWithTimestamp(
        db,
        createdAt: past,
        entityId: 'stale-item',
        entityType: 'cellProgress',
        payload: '{"cell_id":"stale-cell"}',
      );

      await insertEntryWithTimestamp(
        db,
        createdAt: recent,
        entityId: 'fresh-item',
        entityType: 'profile',
        payload: '{"display_name":"Bob"}',
      );

      expect(await repo.countPending(), equals(2));

      // Delete entries older than cutoff.
      final deleted = await repo.deleteStale(cutoff);
      expect(deleted, equals(1));

      // Only the fresh entry remains.
      final remaining = await repo.getPending();
      expect(remaining.length, equals(1));
      expect(remaining.first.entityId, equals('fresh-item'));
      expect(remaining.first.entityType,
          equals(WriteQueueEntityType.profile));
    });

    test('enqueue stores payload as opaque JSON string (round-trip)', () async {
      const payload = '{"nested":{"key":"value"},"list":[1,2,3]}';
      await repo.enqueue(
        entityType: WriteQueueEntityType.itemInstance,
        entityId: 'item-payload-test',
        operation: WriteQueueOperation.upsert,
        payload: payload,
        userId: 'user-1',
      );

      final entries = await repo.getPending();
      expect(entries.first.payload, equals(payload));
    });

    test('delete operation is stored and retrievable', () async {
      await repo.enqueue(
        entityType: WriteQueueEntityType.itemInstance,
        entityId: 'item-to-delete',
        operation: WriteQueueOperation.delete,
        payload: '{}',
        userId: 'user-1',
      );

      final entries = await repo.getPending();
      expect(entries.first.operation, equals(WriteQueueOperation.delete));
    });

    test('getPending limit slices the oldest entries', () async {
      // Insert 5 entries with increasing timestamps.
      final base = DateTime(2026, 3, 7, 10);
      for (var i = 0; i < 5; i++) {
        await insertEntryWithTimestamp(
          db,
          createdAt: base.add(Duration(minutes: i)),
          entityId: 'e-$i',
        );
      }

      final limited = await repo.getPending(limit: 3);
      expect(limited.length, equals(3));
      // Should be the 3 oldest.
      expect(limited.map((e) => e.entityId).toList(),
          equals(['e-0', 'e-1', 'e-2']));
    });

    test('multiple users are isolated via clearUser', () async {
      // User A has 2 entries; User B has 1.
      await repo.enqueue(
        entityType: WriteQueueEntityType.cellProgress,
        entityId: 'cell-a1',
        operation: WriteQueueOperation.upsert,
        payload: '{"cell_id":"cell-a1"}',
        userId: 'user-a',
      );
      await repo.enqueue(
        entityType: WriteQueueEntityType.profile,
        entityId: 'user-a',
        operation: WriteQueueOperation.upsert,
        payload: '{"display_name":"Alice"}',
        userId: 'user-a',
      );
      await repo.enqueue(
        entityType: WriteQueueEntityType.cellProgress,
        entityId: 'cell-b1',
        operation: WriteQueueOperation.upsert,
        payload: '{"cell_id":"cell-b1"}',
        userId: 'user-b',
      );

      expect(await repo.countPending(), equals(3));

      // Clear user-a only.
      final cleared = await repo.clearUser('user-a');
      expect(cleared, equals(2));

      // Only user-b's entry remains.
      final remaining = await repo.getPending();
      expect(remaining.length, equals(1));
      expect(remaining.first.userId, equals('user-b'));
      expect(remaining.first.entityId, equals('cell-b1'));
    });

    test('rejected entries do not appear in getPending', () async {
      final id1 = await repo.enqueue(
        entityType: WriteQueueEntityType.cellProgress,
        entityId: 'cell-1',
        operation: WriteQueueOperation.upsert,
        payload: '{"cell_id":"cell-1"}',
        userId: 'user-1',
      );
      await repo.enqueue(
        entityType: WriteQueueEntityType.cellProgress,
        entityId: 'cell-2',
        operation: WriteQueueOperation.upsert,
        payload: '{"cell_id":"cell-2"}',
        userId: 'user-1',
      );

      await repo.markRejected(id1, 'invalid');

      final pending = await repo.getPending();
      expect(pending.length, equals(1));
      expect(pending.first.entityId, equals('cell-2'));

      final rejected = await repo.getRejected();
      expect(rejected.length, equals(1));
      expect(rejected.first.entityId, equals('cell-1'));
    });

    test('fresh database starts with empty queue', () async {
      expect(await repo.countPending(), equals(0));
      expect(await repo.getPending(), isEmpty);
      expect(await repo.getRejected(), isEmpty);
    });
  });
}
