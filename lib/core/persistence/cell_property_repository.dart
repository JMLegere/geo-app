import 'package:earth_nova/core/database/app_database.dart';
import 'package:earth_nova/core/models/cell_properties.dart';

class CellPropertyRepository {
  CellPropertyRepository(this._db);
  final AppDatabase _db;

  Future<CellProperties?> get(String cellId) async {
    final row = await _db.getCellProperties(cellId);
    return row == null ? null : CellProperties.fromDrift(row);
  }

  Future<void> upsert(CellProperties properties) async {
    await _db.upsertCellProperties(properties.toDriftRow());
  }

  Future<void> updateLocationId(String cellId, String locationId) async {
    await _db.updateCellPropertiesLocationId(cellId, locationId);
  }

  Future<List<CellProperties>> getAll() async {
    final rows = await _db.getAllCellProperties();
    return rows.map(CellProperties.fromDrift).toList();
  }
}
