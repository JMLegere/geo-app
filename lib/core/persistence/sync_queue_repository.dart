import 'dart:convert';
import 'package:fog_of_world/core/database/app_database.dart';

/// Repository for managing the sync queue
class SyncQueueRepository {
  final AppDatabase _db;

  SyncQueueRepository(this._db);

  /// Enqueue an insert action
  Future<int> enqueueInsert({
    required String tableName,
    required Map<String, dynamic> data,
  }) async {
    return _enqueueAction('insert', tableName, data);
  }

  /// Enqueue an update action
  Future<int> enqueueUpdate({
    required String tableName,
    required Map<String, dynamic> data,
  }) async {
    return _enqueueAction('update', tableName, data);
  }

  /// Enqueue a delete action
  Future<int> enqueueDelete({
    required String tableName,
    required Map<String, dynamic> data,
  }) async {
    return _enqueueAction('delete', tableName, data);
  }

  /// Internal method to enqueue an action
  Future<int> _enqueueAction(
    String action,
    String tableName,
    Map<String, dynamic> data,
  ) async {
    final companion = SyncQueueTableCompanion.insert(
      action: action,
      targetTable: tableName,
      data: jsonEncode(data),
    );
    return _db.enqueueSyncEvent(companion);
  }

  /// Get all pending sync events
  Future<List<SyncQueueEntry>> getPending() async {
    return _db.getPendingSyncEvents();
  }

  /// Get pending sync events for a specific table
  Future<List<SyncQueueEntry>> getPendingByTable(String tableName) async {
    return _db.getPendingSyncEventsByTable(tableName);
  }

  /// Dequeue a sync event (remove after successful sync)
  Future<int> dequeue(int eventId) async {
    return _db.dequeueSyncEvent(eventId);
  }

  /// Dequeue multiple sync events
  Future<int> dequeueBatch(List<int> eventIds) async {
    int deleted = 0;
    for (final id in eventIds) {
      deleted += await _db.dequeueSyncEvent(id);
    }
    return deleted;
  }

  /// Clear all sync events
  Future<int> clear() async {
    return _db.clearSyncQueue();
  }

  /// Get sync queue size
  Future<int> getSize() async {
    return _db.getSyncQueueSize();
  }

  /// Check if queue is empty
  Future<bool> isEmpty() async {
    final size = await getSize();
    return size == 0;
  }

  /// Get oldest pending event
  Future<SyncQueueEntry?> getOldest() async {
    final pending = await getPending();
    if (pending.isEmpty) return null;
    pending.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return pending.first;
  }

  /// Get events by action type
  Future<List<SyncQueueEntry>> getByAction(String action) async {
    final pending = await getPending();
    return pending.where((e) => e.action == action).toList();
  }

  /// Parse sync event data
  static Map<String, dynamic> parseData(SyncQueueEntry event) {
    return jsonDecode(event.data) as Map<String, dynamic>;
  }

  /// Get summary of pending changes
  Future<Map<String, int>> getSummary() async {
    final pending = await getPending();
    final summary = <String, int>{};
    for (final event in pending) {
      final key = '${event.action}_${event.targetTable}';
      summary[key] = (summary[key] ?? 0) + 1;
    }
    return summary;
  }
}
