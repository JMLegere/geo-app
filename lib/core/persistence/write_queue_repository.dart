import 'package:drift/drift.dart';
import 'package:earth_nova/core/database/app_database.dart';
import 'package:earth_nova/core/models/write_queue_entry.dart';

/// Repository for the local write queue (offline-first sync outbox).
///
/// Each game state change (item discovery, cell visit, profile update)
/// creates a queue entry. The [QueueProcessor] flushes pending entries
/// to Supabase. Confirmed entries are deleted; rejected entries trigger
/// local rollback.
class WriteQueueRepository {
  final AppDatabase _db;

  WriteQueueRepository(this._db);

  // ── Domain ↔ Drift conversion ────────────────────────────────────────────

  WriteQueueEntry _fromLocal(LocalWriteQueueEntry local) {
    return WriteQueueEntry(
      id: local.id,
      entityType: WriteQueueEntityType.fromString(local.entityType),
      entityId: local.entityId,
      operation: WriteQueueOperation.fromString(local.operation),
      payload: local.payload,
      userId: local.userId,
      status: WriteQueueStatus.fromString(local.status),
      attempts: local.attempts,
      lastError: local.lastError,
      createdAt: local.createdAt,
      updatedAt: local.updatedAt,
    );
  }

  // ── Enqueue ──────────────────────────────────────────────────────────────

  /// Add a new entry to the write queue.
  ///
  /// Returns the auto-generated local ID.
  Future<int> enqueue({
    required WriteQueueEntityType entityType,
    required String entityId,
    required WriteQueueOperation operation,
    required String payload,
    required String userId,
  }) async {
    final now = DateTime.now();
    return _db.insertWriteQueueEntry(
      LocalWriteQueueTableCompanion.insert(
        entityType: entityType.name,
        entityId: entityId,
        operation: operation.name,
        payload: payload,
        userId: userId,
        status: Value('pending'),
        attempts: Value(0),
        lastError: const Value(null),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  // ── Read ─────────────────────────────────────────────────────────────────

  /// Get all pending entries, oldest first, up to [limit].
  ///
  /// When [userId] is provided, only entries belonging to that user are
  /// returned — prevents flushing another user's queue after account switch.
  Future<List<WriteQueueEntry>> getPending({int? limit, String? userId}) async {
    final rows = await _db.getPendingQueueEntries(
      limit: limit,
      userId: userId,
    );
    return rows.map(_fromLocal).toList();
  }

  /// Get all rejected entries.
  ///
  /// When [userId] is provided, only entries belonging to that user are
  /// returned.
  Future<List<WriteQueueEntry>> getRejected({String? userId}) async {
    final rows = await _db.getQueueEntriesByStatus(
      'rejected',
      userId: userId,
    );
    return rows.map(_fromLocal).toList();
  }

  /// Count pending entries.
  ///
  /// When [userId] is provided, only counts entries belonging to that user.
  Future<int> countPending({String? userId}) =>
      _db.countPendingQueueEntries(userId: userId);

  // ── Update ───────────────────────────────────────────────────────────────

  /// Delete a processed entry from the queue (after server confirmation or
  /// after processing a rejection rollback).
  Future<void> deleteEntry(int id) async {
    await _db.deleteQueueEntry(id);
  }

  /// Delete multiple entries by ID (batch cleanup of superseded entries).
  Future<int> deleteEntries(List<int> ids) async {
    if (ids.isEmpty) return 0;
    return _db.deleteQueueEntries(ids);
  }

  /// Mark an entry as rejected (server validation failed).
  Future<void> markRejected(int id, String error) async {
    final entry = await _db.getQueueEntryById(id);
    if (entry == null) return;

    final updated = entry.copyWith(
      status: 'rejected',
      lastError: Value(error),
      updatedAt: DateTime.now(),
    );
    await _db.updateQueueEntry(updated);
  }

  /// Increment the attempt count and record the error.
  Future<void> incrementAttempts(int id, String error) async {
    final entry = await _db.getQueueEntryById(id);
    if (entry == null) return;

    final updated = entry.copyWith(
      attempts: entry.attempts + 1,
      lastError: Value(error),
      updatedAt: DateTime.now(),
    );
    await _db.updateQueueEntry(updated);
  }

  // ── Cleanup ──────────────────────────────────────────────────────────────

  /// Delete entries older than [cutoff].
  Future<int> deleteStale(DateTime cutoff) =>
      _db.deleteStaleQueueEntries(cutoff);

  /// Delete all queue entries for a user.
  Future<int> clearUser(String userId) => _db.clearUserQueueEntries(userId);
}
