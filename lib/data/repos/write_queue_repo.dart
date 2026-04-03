import 'package:earth_nova/data/database.dart';

class WriteQueueRepo {
  final AppDatabase _db;
  WriteQueueRepo(this._db);

  Future<int> enqueue(WriteQueueTableCompanion entry) =>
      _db.enqueueEntry(entry);

  Future<List<WriteQueueEntry>> getPending({int limit = 50, String? userId}) =>
      _db.getPendingEntries(limit: limit, userId: userId);

  Future<List<WriteQueueEntry>> getRejected() => _db.getRejectedEntries();

  Future<int> countPending({String? userId}) =>
      _db.countPendingEntries(userId: userId);

  Future<void> confirmEntry(int id) => _db.confirmEntry(id);

  Future<bool> rejectEntry(int id, String error) => _db.rejectEntry(id, error);

  Future<void> incrementAttempts(int id, String error) =>
      _db.incrementEntryAttempts(id, error);

  Future<int> deleteStale(DateTime cutoff) => _db.deleteStaleEntries(cutoff);

  Future<int> clearUser(String userId) =>
      (_db.delete(_db.writeQueueTable)..where((t) => t.userId.equals(userId)))
          .go();

  Future<int> deleteEntries(List<int> ids) =>
      (_db.delete(_db.writeQueueTable)..where((t) => t.id.isIn(ids))).go();
}
