import 'package:earth_nova/core/database/app_database.dart';
import 'package:earth_nova/core/models/item_instance.dart';

/// Repository for ItemInstance CRUD operations.
///
/// Wraps [AppDatabase] and handles conversion between domain [ItemInstance]
/// objects and the Drift [LocalItemInstance] data class.
class ItemInstanceRepository {
  final AppDatabase _db;

  ItemInstanceRepository(this._db);

  /// Convert domain model → Drift row.
  LocalItemInstance _toLocal(ItemInstance instance, String userId) {
    return LocalItemInstance(
      id: instance.id,
      userId: userId,
      definitionId: instance.definitionId,
      affixes: instance.affixesToJson(),
      badgesJson: instance.badgesToJson(),
      parentAId: instance.parentAId,
      parentBId: instance.parentBId,
      acquiredAt: instance.acquiredAt,
      acquiredInCellId: instance.acquiredInCellId,
      dailySeed: instance.dailySeed,
      status: instance.status.name,
    );
  }

  /// Convert Drift row → domain model.
  ItemInstance _fromLocal(LocalItemInstance local) {
    return ItemInstance(
      id: local.id,
      definitionId: local.definitionId,
      affixes: ItemInstance.affixesFromJson(local.affixes),
      badges: ItemInstance.badgesFromJson(local.badgesJson),
      parentAId: local.parentAId,
      parentBId: local.parentBId,
      acquiredAt: local.acquiredAt,
      acquiredInCellId: local.acquiredInCellId,
      dailySeed: local.dailySeed,
      status: ItemInstanceStatus.fromString(local.status),
    );
  }

  /// Add a new item instance for a user.
  Future<void> addItem(ItemInstance instance, String userId) async {
    await _db.insertItemInstance(_toLocal(instance, userId));
  }

  /// Get all item instances for a user.
  Future<List<ItemInstance>> getItemsByUser(String userId) async {
    final rows = await _db.getItemInstancesByUser(userId);
    return rows.map(_fromLocal).toList();
  }

  /// Get item instances acquired in a specific cell.
  Future<List<ItemInstance>> getItemsByCell(
    String userId,
    String cellId,
  ) async {
    final rows = await _db.getItemInstancesByCell(userId, cellId);
    return rows.map(_fromLocal).toList();
  }

  /// Get a single item instance by ID.
  Future<ItemInstance?> getItem(String id) async {
    final row = await _db.getItemInstance(id);
    return row == null ? null : _fromLocal(row);
  }

  /// Update an item instance (e.g. status change to donated/placed/released).
  Future<bool> updateItem(ItemInstance instance, String userId) async {
    return _db.updateItemInstance(_toLocal(instance, userId));
  }

  /// Delete an item instance by ID.
  Future<int> deleteItem(String id) async {
    return _db.deleteItemInstance(id);
  }

  /// Get the total number of items for a user.
  Future<int> getItemCount(String userId) async {
    final items = await _db.getItemInstancesByUser(userId);
    return items.length;
  }

  /// Get unique definition IDs collected by a user.
  Future<Set<String>> getUniqueDefinitionIds(String userId) async {
    final items = await _db.getItemInstancesByUser(userId);
    return items.map((i) => i.definitionId).toSet();
  }

  /// Delete all items for a user.
  Future<int> clearUserItems(String userId) async {
    return _db.clearUserItemInstances(userId);
  }
}
