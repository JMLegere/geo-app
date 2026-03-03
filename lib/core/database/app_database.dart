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

/// Local representation of collected species
/// Mirrors Supabase `collected_species` table
@DataClassName('LocalCollectedSpecies')
class LocalCollectedSpeciesTable extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get speciesId => text()();
  TextColumn get cellId => text()();
  DateTimeColumn get collectedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
  
  @override
  List<Set<Column>> get uniqueKeys => [
    {userId, speciesId, cellId}, // Unique: one collection per user per species per cell
  ];
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
  LocalCollectedSpeciesTable,
  LocalPlayerProfileTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? createDatabaseConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Future migrations will be added here
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
  // COLLECTED SPECIES QUERIES
  // ========================================================================

  /// Get all collected species for a user
  Future<List<LocalCollectedSpecies>> getCollectedSpeciesByUser(String userId) {
    return (select(localCollectedSpeciesTable)
          ..where((tbl) => tbl.userId.equals(userId)))
        .get();
  }

  /// Get collected species for a specific cell
  Future<List<LocalCollectedSpecies>> getCollectedSpeciesByCell(
    String userId,
    String cellId,
  ) {
    return (select(localCollectedSpeciesTable)
          ..where((tbl) =>
              tbl.userId.equals(userId) & tbl.cellId.equals(cellId)))
        .get();
  }

  /// Check if a species is collected in a cell
  Future<bool> isSpeciesCollected(
    String userId,
    String speciesId,
    String cellId,
  ) async {
    final result = await (select(localCollectedSpeciesTable)
          ..where((tbl) =>
              tbl.userId.equals(userId) &
              tbl.speciesId.equals(speciesId) &
              tbl.cellId.equals(cellId)))
        .getSingleOrNull();
    return result != null;
  }

  /// Insert collected species
  Future<void> insertCollectedSpecies(LocalCollectedSpecies species) async {
    await into(localCollectedSpeciesTable).insert(species);
  }

  /// Delete collected species
  Future<int> deleteCollectedSpecies(
    String userId,
    String speciesId,
    String cellId,
  ) {
    return (delete(localCollectedSpeciesTable)
          ..where((tbl) =>
              tbl.userId.equals(userId) &
              tbl.speciesId.equals(speciesId) &
              tbl.cellId.equals(cellId)))
        .go();
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
