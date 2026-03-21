import 'package:earth_nova/core/database/app_database.dart';
import 'package:earth_nova/core/models/item_category.dart';
import 'package:earth_nova/core/models/item_instance.dart';
import 'package:earth_nova/core/models/iucn_status.dart';

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
      displayName: instance.displayName,
      scientificName: instance.scientificName,
      categoryName: instance.category.name,
      rarityName: instance.rarity?.name,
      habitatsJson: instance.habitatsToJson(),
      continentsJson: instance.continentsToJson(),
      taxonomicClass: instance.taxonomicClass,
      affixes: instance.affixesToJson(),
      badgesJson: instance.badgesToJson(),
      parentAId: instance.parentAId,
      parentBId: instance.parentBId,
      acquiredAt: instance.acquiredAt,
      acquiredInCellId: instance.acquiredInCellId,
      dailySeed: instance.dailySeed,
      status: instance.status.name,
      iconUrl: instance.iconUrl,
      artUrl: instance.artUrl,
      // Species enrichment denorm
      animalClassName: instance.animalClassName,
      animalClassNameEnrichver: instance.animalClassNameEnrichver,
      foodPreferenceName: instance.foodPreferenceName,
      foodPreferenceNameEnrichver: instance.foodPreferenceNameEnrichver,
      climateName: instance.climateName,
      climateNameEnrichver: instance.climateNameEnrichver,
      brawn: instance.brawn,
      brawnEnrichver: instance.brawnEnrichver,
      wit: instance.wit,
      witEnrichver: instance.witEnrichver,
      speed: instance.speed,
      speedEnrichver: instance.speedEnrichver,
      sizeName: instance.sizeName,
      sizeNameEnrichver: instance.sizeNameEnrichver,
      iconUrlEnrichver: instance.iconUrlEnrichver,
      artUrlEnrichver: instance.artUrlEnrichver,
      // Cell properties denorm
      cellHabitatName: instance.cellHabitatName,
      cellHabitatNameEnrichver: instance.cellHabitatNameEnrichver,
      cellClimateName: instance.cellClimateName,
      cellClimateNameEnrichver: instance.cellClimateNameEnrichver,
      cellContinentName: instance.cellContinentName,
      cellContinentNameEnrichver: instance.cellContinentNameEnrichver,
      // Location hierarchy denorm
      locationDistrict: instance.locationDistrict,
      locationDistrictEnrichver: instance.locationDistrictEnrichver,
      locationCity: instance.locationCity,
      locationCityEnrichver: instance.locationCityEnrichver,
      locationState: instance.locationState,
      locationStateEnrichver: instance.locationStateEnrichver,
      locationCountry: instance.locationCountry,
      locationCountryEnrichver: instance.locationCountryEnrichver,
      locationCountryCode: instance.locationCountryCode,
      locationCountryCodeEnrichver: instance.locationCountryCodeEnrichver,
    );
  }

  /// Convert Drift row → domain model.
  ItemInstance _fromLocal(LocalItemInstance local) {
    return ItemInstance(
      id: local.id,
      definitionId: local.definitionId,
      displayName: local.displayName,
      scientificName: local.scientificName,
      category: ItemCategory.values.firstWhere(
        (c) => c.name == local.categoryName,
        orElse: () => ItemCategory.fauna,
      ),
      rarity: local.rarityName != null
          ? IucnStatus.values.firstWhere(
              (r) => r.name == local.rarityName,
              orElse: () => IucnStatus.leastConcern,
            )
          : null,
      habitats: ItemInstance.habitatsFromJson(local.habitatsJson),
      continents: ItemInstance.continentsFromJson(local.continentsJson),
      taxonomicClass: local.taxonomicClass,
      affixes: ItemInstance.affixesFromJson(local.affixes),
      badges: ItemInstance.badgesFromJson(local.badgesJson),
      parentAId: local.parentAId,
      parentBId: local.parentBId,
      acquiredAt: local.acquiredAt,
      acquiredInCellId: local.acquiredInCellId,
      dailySeed: local.dailySeed,
      status: ItemInstanceStatus.fromString(local.status),
      iconUrl: local.iconUrl,
      artUrl: local.artUrl,
      // Species enrichment denorm
      animalClassName: local.animalClassName,
      animalClassNameEnrichver: local.animalClassNameEnrichver,
      foodPreferenceName: local.foodPreferenceName,
      foodPreferenceNameEnrichver: local.foodPreferenceNameEnrichver,
      climateName: local.climateName,
      climateNameEnrichver: local.climateNameEnrichver,
      brawn: local.brawn,
      brawnEnrichver: local.brawnEnrichver,
      wit: local.wit,
      witEnrichver: local.witEnrichver,
      speed: local.speed,
      speedEnrichver: local.speedEnrichver,
      sizeName: local.sizeName,
      sizeNameEnrichver: local.sizeNameEnrichver,
      iconUrlEnrichver: local.iconUrlEnrichver,
      artUrlEnrichver: local.artUrlEnrichver,
      // Cell properties denorm
      cellHabitatName: local.cellHabitatName,
      cellHabitatNameEnrichver: local.cellHabitatNameEnrichver,
      cellClimateName: local.cellClimateName,
      cellClimateNameEnrichver: local.cellClimateNameEnrichver,
      cellContinentName: local.cellContinentName,
      cellContinentNameEnrichver: local.cellContinentNameEnrichver,
      // Location hierarchy denorm
      locationDistrict: local.locationDistrict,
      locationDistrictEnrichver: local.locationDistrictEnrichver,
      locationCity: local.locationCity,
      locationCityEnrichver: local.locationCityEnrichver,
      locationState: local.locationState,
      locationStateEnrichver: local.locationStateEnrichver,
      locationCountry: local.locationCountry,
      locationCountryEnrichver: local.locationCountryEnrichver,
      locationCountryCode: local.locationCountryCode,
      locationCountryCodeEnrichver: local.locationCountryCodeEnrichver,
    );
  }

  /// Add a new item instance for a user.
  Future<void> addItem(ItemInstance instance, String userId) async {
    await _db.insertItemInstance(_toLocal(instance, userId));
  }

  /// Upsert an item instance — insert or replace on conflict.
  ///
  /// Preferred over [addItem] in the Supabase hydration path, where the server
  /// is authoritative and may carry badge/status updates for items that already
  /// exist locally.
  Future<void> upsertItem(ItemInstance instance, String userId) async {
    await _db.upsertItemInstance(_toLocal(instance, userId));
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
