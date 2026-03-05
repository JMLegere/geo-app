import 'package:fog_of_world/core/database/app_database.dart';

class CollectionRepository {
  final AppDatabase _db;

  CollectionRepository(this._db);

  Future<void> addSpecies({
    required String id,
    required String userId,
    required String speciesId,
    required String cellId,
    DateTime? collectedAt,
  }) async {
    final species = LocalCollectedSpecies(
      id: id,
      userId: userId,
      speciesId: speciesId,
      cellId: cellId,
      collectedAt: collectedAt ?? DateTime.now(),
    );
    await _db.insertCollectedSpecies(species);
  }

  Future<int> removeSpecies(
    String userId,
    String speciesId,
    String cellId,
  ) async {
    return _db.deleteCollectedSpecies(userId, speciesId, cellId);
  }

  Future<bool> isCollected(
    String userId,
    String speciesId,
    String cellId,
  ) async {
    return _db.isSpeciesCollected(userId, speciesId, cellId);
  }

  Future<List<LocalCollectedSpecies>> getCollectedByUser(String userId) async {
    return _db.getCollectedSpeciesByUser(userId);
  }

  Future<List<LocalCollectedSpecies>> getCollectedByCell(
    String userId,
    String cellId,
  ) async {
    return _db.getCollectedSpeciesByCell(userId, cellId);
  }

  Future<int> getCollectionCount(String userId) async {
    final collected = await _db.getCollectedSpeciesByUser(userId);
    return collected.length;
  }

  Future<List<String>> getUniqueSpeciesIds(String userId) async {
    final collected = await _db.getCollectedSpeciesByUser(userId);
    final uniqueIds = <String>{};
    for (final item in collected) {
      uniqueIds.add(item.speciesId);
    }
    return uniqueIds.toList();
  }

  Future<List<LocalCollectedSpecies>> getAllCollections() async {
    return _db.select(_db.localCollectedSpeciesTable).get();
  }

  Future<int> clearUserCollections(String userId) async {
    return (_db.delete(_db.localCollectedSpeciesTable)
          ..where((t) => t.userId.equals(userId)))
        .go();
  }
}
