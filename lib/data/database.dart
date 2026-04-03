import 'dart:async';

import 'package:drift/drift.dart';

import 'connection.dart';

part 'database.g.dart';

// ============================================================================
// TABLE DEFINITIONS — 6 tables, schema v1
// ============================================================================

/// Player profile + stats.
@DataClassName('Player')
class PlayersTable extends Table {
  TextColumn get id => text()(); // Supabase user ID
  TextColumn get displayName => text().withDefault(const Constant(''))();
  RealColumn get totalDistanceKm => real().withDefault(const Constant(0.0))();
  IntColumn get cellsExplored => integer().withDefault(const Constant(0))();
  IntColumn get speciesDiscovered => integer().withDefault(const Constant(0))();
  IntColumn get currentStreak => integer().withDefault(const Constant(0))();
  IntColumn get longestStreak => integer().withDefault(const Constant(0))();
  BoolColumn get hasCompletedOnboarding =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Species definitions — 32,752 IUCN records.
/// Seeded from pre-compiled species.db (native) or JSON (web) at first launch.
@DataClassName('Species')
class SpeciesTable extends Table {
  TextColumn get definitionId => text()(); // e.g. "fauna_vulpes_vulpes"
  TextColumn get scientificName => text()();
  TextColumn get commonName => text()();
  TextColumn get taxonomicClass => text()();
  TextColumn get iucnStatus => text()(); // LC, NT, VU, EN, CR, EX
  TextColumn get habitatsJson => text()(); // JSON array
  TextColumn get continentsJson => text()(); // JSON array
  // AI enrichment (nullable, populated server-side)
  TextColumn get animalClass => text().nullable()();
  TextColumn get foodPreference => text().nullable()();
  TextColumn get climate => text().nullable()();
  IntColumn get brawn => integer().nullable()();
  IntColumn get wit => integer().nullable()();
  IntColumn get speed => integer().nullable()();
  TextColumn get size => text().nullable()();
  TextColumn get iconUrl => text().nullable()();
  TextColumn get artUrl => text().nullable()();
  DateTimeColumn get enrichedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {definitionId};
}

/// Unique discovered items with rolled affixes (PoE model).
@DataClassName('Item')
class ItemsTable extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get userId => text()();
  TextColumn get definitionId => text()(); // FK → species
  TextColumn get affixesJson => text().withDefault(const Constant('[]'))();
  DateTimeColumn get acquiredAt => dateTime()();
  TextColumn get acquiredInCellId => text().nullable()();
  TextColumn get dailySeed => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  TextColumn get badgesJson => text().withDefault(const Constant('[]'))();
  TextColumn get parentAId => text().nullable()();
  TextColumn get parentBId => text().nullable()();
  // Snapshot from species at discovery time
  TextColumn get displayName => text().withDefault(const Constant(''))();
  TextColumn get scientificName => text().nullable()();
  TextColumn get categoryName => text().withDefault(const Constant('fauna'))();
  TextColumn get rarityName => text().nullable()();
  TextColumn get habitatsJson => text().withDefault(const Constant('[]'))();
  TextColumn get continentsJson => text().withDefault(const Constant('[]'))();
  TextColumn get taxonomicClass => text().nullable()();
  // Enrichment snapshot (from species at last sync)
  TextColumn get animalClassName => text().nullable()();
  TextColumn get foodPreferenceName => text().nullable()();
  TextColumn get climateName => text().nullable()();
  IntColumn get brawn => integer().nullable()();
  IntColumn get wit => integer().nullable()();
  IntColumn get speed => integer().nullable()();
  TextColumn get sizeName => text().nullable()();
  TextColumn get iconUrl => text().nullable()();
  TextColumn get artUrl => text().nullable()();
  // Cell context at discovery
  TextColumn get cellHabitatName => text().nullable()();
  TextColumn get cellClimateName => text().nullable()();
  TextColumn get cellContinentName => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-player cell visit history. Fog is computed, not stored.
@DataClassName('CellVisit')
class CellVisitsTable extends Table {
  TextColumn get userId => text()();
  TextColumn get cellId => text()();
  IntColumn get visitCount => integer().withDefault(const Constant(0))();
  RealColumn get distanceWalked => real().withDefault(const Constant(0.0))();
  DateTimeColumn get lastVisited => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {userId, cellId};
}

/// Permanent geo-derived properties for a Voronoi cell.
/// Globally shared — same cell = same properties for all players.
@DataClassName('CellProperty')
class CellPropertiesTable extends Table {
  TextColumn get cellId => text()();
  TextColumn get habitatsJson => text()(); // JSON array
  TextColumn get climate => text()();
  TextColumn get continent => text()();
  TextColumn get locationId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {cellId};
}

/// Offline write queue. Entries deleted after server confirms.
@DataClassName('WriteQueueEntry')
class WriteQueueTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text()(); // 'item', 'cellVisit', 'player'
  TextColumn get entityId => text()();
  TextColumn get operation => text()(); // 'upsert', 'delete'
  TextColumn get payload => text()(); // JSON snapshot
  TextColumn get userId => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  // Note: autoIncrement() implies primary key — do NOT override primaryKey.
}

// ============================================================================
// DATABASE
// ============================================================================

@DriftDatabase(tables: [
  PlayersTable,
  SpeciesTable,
  ItemsTable,
  CellVisitsTable,
  CellPropertiesTable,
  WriteQueueTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(createDatabaseConnection());

  /// For testing with in-memory database.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          // Species seeding is handled by the provider layer after DB creation.
          // Native: ATTACH species.db → INSERT SELECT
          // Web: Parse species_data.json → batch insert
        },
      );

  // ---- Write queue convenience methods ----

  Future<int> enqueueEntry(WriteQueueTableCompanion entry) =>
      into(writeQueueTable).insert(entry);

  Future<List<WriteQueueEntry>> getPendingEntries({
    int limit = 50,
    String? userId,
  }) {
    final query = select(writeQueueTable)
      ..where((t) => t.status.equals('pending'));
    if (userId != null) {
      query.where((t) => t.userId.equals(userId));
    }
    query
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
      ..limit(limit);
    return query.get();
  }

  Future<List<WriteQueueEntry>> getRejectedEntries() =>
      (select(writeQueueTable)..where((t) => t.status.equals('rejected')))
          .get();

  Future<int> countPendingEntries({String? userId}) {
    final countExp = writeQueueTable.id.count();
    final query = selectOnly(writeQueueTable)
      ..addColumns([countExp])
      ..where(writeQueueTable.status.equals('pending'));
    if (userId != null) {
      query.where(writeQueueTable.userId.equals(userId));
    }
    return query.map((row) => row.read(countExp)!).getSingle();
  }

  Future<void> confirmEntry(int entryId) =>
      (delete(writeQueueTable)..where((t) => t.id.equals(entryId))).go();

  Future<bool> rejectEntry(int entryId, String error) async {
    final count = await (update(writeQueueTable)
          ..where((t) => t.id.equals(entryId)))
        .write(WriteQueueTableCompanion(
      status: const Value('rejected'),
      lastError: Value(error),
      updatedAt: Value(DateTime.now()),
    ));
    return count > 0;
  }

  Future<void> incrementEntryAttempts(int entryId, String error) =>
      customStatement(
        'UPDATE write_queue_table SET attempts = attempts + 1, '
        'last_error = ?, updated_at = ? WHERE id = ?',
        [error, DateTime.now().toIso8601String(), entryId],
      );

  Future<int> deleteStaleEntries(DateTime cutoff) => (delete(writeQueueTable)
        ..where((t) =>
            t.status.equals('pending') &
            t.createdAt.isSmallerThanValue(cutoff)))
      .go();

  // ---- Cell property convenience methods ----

  Future<CellProperty?> getCellProperties(String cellId) =>
      (select(cellPropertiesTable)..where((t) => t.cellId.equals(cellId)))
          .getSingleOrNull();

  Future<void> upsertCellProperties(CellPropertiesTableCompanion entry) =>
      into(cellPropertiesTable).insertOnConflictUpdate(entry);

  Future<List<CellProperty>> getAllCellProperties() =>
      select(cellPropertiesTable).get();
}
