import 'package:drift/drift.dart';

import 'connection.dart';

part 'app_database.g.dart';

// ============================================================================
// TABLE DEFINITIONS
// ============================================================================

/// Local representation of cell progress (fog state, distance walked, etc.)
/// Mirrors Supabase `cell_progress` table
@DataClassName('LocalCellProgress')
class LocalCellProgressTable extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get cellId => text()();
  TextColumn get fogState => text()(); // Stored as string: 'undetected', 'unexplored', etc.
  RealColumn get distanceWalked => real().withDefault(const Constant(0.0))();
  IntColumn get visitCount => integer().withDefault(const Constant(0))();
  RealColumn get restorationLevel => real().withDefault(const Constant(0.0))();
  DateTimeColumn get lastVisited => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
  
  @override
  List<Set<Column>> get uniqueKeys => [
    {userId, cellId}, // Unique constraint: one progress record per user per cell
  ];
}

/// Local cache of item instances (unique discovered items).
/// Replaces the old LocalCollectedSpeciesTable. Each row is a unique
/// ItemInstance with randomly-rolled affixes.
/// Mirrors Supabase `item_instances` table.
@DataClassName('LocalItemInstance')
class LocalItemInstanceTable extends Table {
  /// UUID v4 — globally unique item ID.
  TextColumn get id => text()();

  /// Owner's user ID.
  TextColumn get userId => text()();

  /// References ItemDefinition.id (e.g. "fauna_vulpes_vulpes").
  TextColumn get definitionId => text()();

  /// JSON-encoded list of Affix objects.
  TextColumn get affixes => text().withDefault(const Constant('[]'))();

  /// Null for wild-caught. Set for bred offspring.
  TextColumn get parentAId => text().nullable()();

  /// Null for wild-caught. Set for bred offspring.
  TextColumn get parentBId => text().nullable()();

  /// When the player acquired this item.
  DateTimeColumn get acquiredAt => dateTime()();

  /// Cell where this item was found. Null for bred items.
  TextColumn get acquiredInCellId => text().nullable()();

  /// Daily seed used for this roll (server re-derivation).
  TextColumn get dailySeed => text().nullable()();

  /// Lifecycle status: active, donated, placed, released, traded.
  TextColumn get status => text().withDefault(const Constant('active'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local cache of species enrichment data (AI-enriched classification).
/// Global — one row per definition_id, shared across all users.
@DataClassName('LocalSpeciesEnrichment')
class LocalSpeciesEnrichmentTable extends Table {
  TextColumn get definitionId => text()();
  TextColumn get animalClass => text()();
  TextColumn get foodPreference => text()();
  TextColumn get climate => text()();
  IntColumn get brawn => integer()();
  IntColumn get wit => integer()();
  IntColumn get speed => integer()();
  TextColumn get artUrl => text().nullable()();
  DateTimeColumn get enrichedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {definitionId};
}

/// Local representation of player profile
/// Mirrors Supabase `profiles` table
@DataClassName('LocalPlayerProfile')
class LocalPlayerProfileTable extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  IntColumn get currentStreak => integer().withDefault(const Constant(0))();
  IntColumn get longestStreak => integer().withDefault(const Constant(0))();
  RealColumn get totalDistanceKm => real().withDefault(const Constant(0.0))();
  TextColumn get currentSeason => text().withDefault(const Constant('summer'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// DATABASE CLASS
// ============================================================================

@DriftDatabase(tables: [
  LocalCellProgressTable,
  LocalItemInstanceTable,
  LocalPlayerProfileTable,
  LocalSpeciesEnrichmentTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? createDatabaseConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.createTable(localItemInstanceTable);
          await m.deleteTable('local_collected_species_table');
        }
        if (from < 3) {
          await m.createTable(localSpeciesEnrichmentTable);
        }
      },
    );
  }

  // ========================================================================
  // CELL PROGRESS QUERIES
  // ========================================================================

  /// Get all cell progress records for a user
  Future<List<LocalCellProgress>> getCellProgressByUser(String userId) {
    return (select(localCellProgressTable)
          ..where((tbl) => tbl.userId.equals(userId)))
        .get();
  }

  /// Get a specific cell progress record
  Future<LocalCellProgress?> getCellProgress(String userId, String cellId) {
    return (select(localCellProgressTable)
          ..where((tbl) => tbl.userId.equals(userId) & tbl.cellId.equals(cellId)))
        .getSingleOrNull();
  }

  /// Insert or update cell progress
  Future<void> upsertCellProgress(LocalCellProgress progress) async {
    await into(localCellProgressTable).insert(
      progress,
      onConflict: DoUpdate((_) => progress),
    );
  }

  /// Delete cell progress
  Future<int> deleteCellProgress(String userId, String cellId) {
    return (delete(localCellProgressTable)
          ..where((tbl) => tbl.userId.equals(userId) & tbl.cellId.equals(cellId)))
        .go();
  }

  // ========================================================================
  // ITEM INSTANCE QUERIES
  // ========================================================================

  /// Get all item instances for a user.
  Future<List<LocalItemInstance>> getItemInstancesByUser(String userId) {
    return (select(localItemInstanceTable)
          ..where((tbl) => tbl.userId.equals(userId)))
        .get();
  }

  /// Get item instances for a specific cell.
  Future<List<LocalItemInstance>> getItemInstancesByCell(
    String userId,
    String cellId,
  ) {
    return (select(localItemInstanceTable)
          ..where((tbl) =>
              tbl.userId.equals(userId) &
              tbl.acquiredInCellId.equals(cellId)))
        .get();
  }

  /// Get a single item instance by ID.
  Future<LocalItemInstance?> getItemInstance(String id) {
    return (select(localItemInstanceTable)
          ..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  /// Insert a new item instance.
  Future<void> insertItemInstance(LocalItemInstance instance) async {
    await into(localItemInstanceTable).insert(instance);
  }

  /// Update an existing item instance (e.g. status change).
  Future<bool> updateItemInstance(LocalItemInstance instance) {
    return update(localItemInstanceTable).replace(instance);
  }

  /// Delete an item instance by ID.
  Future<int> deleteItemInstance(String id) {
    return (delete(localItemInstanceTable)
          ..where((tbl) => tbl.id.equals(id)))
        .go();
  }

  /// Delete all item instances for a user.
  Future<int> clearUserItemInstances(String userId) {
    return (delete(localItemInstanceTable)
          ..where((tbl) => tbl.userId.equals(userId)))
        .go();
  }

  // ========================================================================
  // SPECIES ENRICHMENT QUERIES
  // ========================================================================

  Future<LocalSpeciesEnrichment?> getEnrichment(String definitionId) {
    return (select(localSpeciesEnrichmentTable)
          ..where((tbl) => tbl.definitionId.equals(definitionId)))
        .getSingleOrNull();
  }

  Future<List<LocalSpeciesEnrichment>> getAllEnrichments() {
    return select(localSpeciesEnrichmentTable).get();
  }

  Future<void> upsertEnrichment(LocalSpeciesEnrichment enrichment) async {
    // Use a companion for the DoUpdate clause so nullable columns (e.g. artUrl)
    // are explicitly set to NULL rather than skipped when the value is null.
    final companion = LocalSpeciesEnrichmentTableCompanion(
      definitionId: Value(enrichment.definitionId),
      animalClass: Value(enrichment.animalClass),
      foodPreference: Value(enrichment.foodPreference),
      climate: Value(enrichment.climate),
      brawn: Value(enrichment.brawn),
      wit: Value(enrichment.wit),
      speed: Value(enrichment.speed),
      artUrl: Value(enrichment.artUrl),
      enrichedAt: Value(enrichment.enrichedAt),
    );
    await into(localSpeciesEnrichmentTable).insert(
      enrichment,
      onConflict: DoUpdate((_) => companion),
    );
  }

  Future<List<LocalSpeciesEnrichment>> getEnrichmentsSince(DateTime since) {
    return (select(localSpeciesEnrichmentTable)
          ..where((tbl) => tbl.enrichedAt.isBiggerOrEqualValue(since)))
        .get();
  }

  // ========================================================================
  // PLAYER PROFILE QUERIES
  // ========================================================================

  /// Get player profile by ID
  Future<LocalPlayerProfile?> getPlayerProfile(String userId) {
    return (select(localPlayerProfileTable)
          ..where((tbl) => tbl.id.equals(userId)))
        .getSingleOrNull();
  }

  /// Insert or update player profile
  Future<void> upsertPlayerProfile(LocalPlayerProfile profile) async {
    await into(localPlayerProfileTable).insert(
      profile,
      onConflict: DoUpdate((_) => profile),
    );
  }

  /// Delete player profile
  Future<int> deletePlayerProfile(String userId) {
    return (delete(localPlayerProfileTable)
          ..where((tbl) => tbl.id.equals(userId)))
        .go();
  }

}
