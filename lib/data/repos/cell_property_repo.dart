import 'package:earth_nova/data/database.dart';

class CellPropertyRepo {
  final AppDatabase _db;
  CellPropertyRepo(this._db);

  Future<CellProperty?> get(String cellId) => _db.getCellProperties(cellId);

  Future<void> upsert(CellPropertiesTableCompanion entry) =>
      _db.upsertCellProperties(entry);

  Future<List<CellProperty>> getAll() => _db.getAllCellProperties();
}
