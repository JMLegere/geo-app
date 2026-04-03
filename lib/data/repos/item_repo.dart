import 'package:drift/drift.dart';
import 'package:earth_nova/data/database.dart';

class ItemRepo {
  final AppDatabase _db;
  ItemRepo(this._db);

  Future<Item?> get(String id) =>
      (_db.select(_db.itemsTable)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<List<Item>> getAll(String userId) =>
      (_db.select(_db.itemsTable)..where((t) => t.userId.equals(userId))).get();

  Future<List<Item>> getByStatus(String userId, String status) =>
      (_db.select(_db.itemsTable)
            ..where((t) => t.userId.equals(userId) & t.status.equals(status)))
          .get();

  Future<void> create(ItemsTableCompanion entry) =>
      _db.into(_db.itemsTable).insertOnConflictUpdate(entry);

  Future<bool> update(String id, ItemsTableCompanion entry) async {
    final count = await (_db.update(_db.itemsTable)
          ..where((t) => t.id.equals(id)))
        .write(entry);
    return count > 0;
  }

  Future<int> delete(String id) =>
      (_db.delete(_db.itemsTable)..where((t) => t.id.equals(id))).go();
}
