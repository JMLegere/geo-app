import 'package:earth_nova/core/database/app_database.dart';
import 'package:earth_nova/core/models/location_node.dart';

class LocationNodeRepository {
  LocationNodeRepository(this._db);
  final AppDatabase _db;

  Future<LocationNode?> get(String id) async {
    final row = await _db.getLocationNode(id);
    return row == null ? null : LocationNode.fromDrift(row);
  }

  Future<LocationNode?> getByOsmId(int osmId) async {
    final row = await _db.getLocationNodeByOsmId(osmId);
    return row == null ? null : LocationNode.fromDrift(row);
  }

  Future<void> upsert(LocationNode node) async {
    await _db.upsertLocationNode(node.toDriftRow());
  }

  Future<List<LocationNode>> getChildren(String parentId) async {
    final rows = await _db.getLocationNodeChildren(parentId);
    return rows.map(LocationNode.fromDrift).toList();
  }

  Future<List<LocationNode>> getAll() async {
    final rows = await _db.getAllLocationNodes();
    return rows.map(LocationNode.fromDrift).toList();
  }
}
