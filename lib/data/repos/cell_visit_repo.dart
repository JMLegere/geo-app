import 'package:drift/drift.dart';
import 'package:earth_nova/data/database.dart';

class CellVisitRepo {
  final AppDatabase _db;
  CellVisitRepo(this._db);

  Future<CellVisit?> get(String userId, String cellId) =>
      (_db.select(_db.cellVisitsTable)
            ..where((t) => t.userId.equals(userId) & t.cellId.equals(cellId)))
          .getSingleOrNull();

  Future<void> upsert(CellVisitsTableCompanion entry) =>
      _db.into(_db.cellVisitsTable).insertOnConflictUpdate(entry);

  Future<List<CellVisit>> getAllVisited(String userId) =>
      (_db.select(_db.cellVisitsTable)..where((t) => t.userId.equals(userId)))
          .get();

  Future<void> incrementVisit(String userId, String cellId) async {
    final existing = await get(userId, cellId);
    if (existing == null) {
      await upsert(CellVisitsTableCompanion.insert(
        userId: userId,
        cellId: cellId,
        visitCount: const Value(1),
        lastVisited: Value(DateTime.now()),
      ));
    } else {
      await (_db.update(_db.cellVisitsTable)
            ..where((t) => t.userId.equals(userId) & t.cellId.equals(cellId)))
          .write(CellVisitsTableCompanion(
        visitCount: Value(existing.visitCount + 1),
        lastVisited: Value(DateTime.now()),
      ));
    }
  }

  Future<void> addDistance(String userId, String cellId, double meters) async {
    final existing = await get(userId, cellId);
    if (existing == null) {
      await upsert(CellVisitsTableCompanion.insert(
        userId: userId,
        cellId: cellId,
        distanceWalked: Value(meters),
      ));
    } else {
      await (_db.update(_db.cellVisitsTable)
            ..where((t) => t.userId.equals(userId) & t.cellId.equals(cellId)))
          .write(CellVisitsTableCompanion(
        distanceWalked: Value(existing.distanceWalked + meters),
      ));
    }
  }
}
