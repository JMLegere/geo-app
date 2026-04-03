import 'dart:async';

import 'package:drift/drift.dart';

import 'connection.dart';

part 'database.g.dart';

// ============================================================================
// TABLE DEFINITIONS — 10 tables, schema v2
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

/// Country in the geographic hierarchy.
@DataClassName('HierarchyCountry')
class CountriesTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get centroidLat => real()();
  RealColumn get centroidLon => real()();
  TextColumn get continent => text()();
  TextColumn get boundaryJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// State / Province in the geographic hierarchy.
@DataClassName('HierarchyState')
class StatesTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get centroidLat => real()();
  RealColumn get centroidLon => real()();
  TextColumn get countryId => text()();
  TextColumn get boundaryJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// City / Locality in the geographic hierarchy.
@DataClassName('HierarchyCity')
class CitiesTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get centroidLat => real()();
  RealColumn get centroidLon => real()();
  TextColumn get stateId => text()();
  TextColumn get boundaryJson => text().nullable()();
  IntColumn get cellsTotal => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// District / Neighbourhood in the geographic hierarchy.
@DataClassName('HierarchyDistrict')
class DistrictsTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get centroidLat => real()();
  RealColumn get centroidLon => real()();
  TextColumn get cityId => text()();
  TextColumn get boundaryJson => text().nullable()();
  IntColumn get cellsTotal => integer().nullable()();
  TextColumn get source => text().withDefault(const Constant('whosonfirst'))();
  TextColumn get sourceId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
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
  CountriesTable,
  StatesTable,
  CitiesTable,
  DistrictsTable,
  WriteQueueTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(createDatabaseConnection());

  /// For testing with in-memory database.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          // Species seeding is handled by the provider layer after DB creation.
          // Native: ATTACH species.db → INSERT SELECT
          // Web: Parse species_data.json → batch insert
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.createTable(countriesTable);
            await m.createTable(statesTable);
            await m.createTable(citiesTable);
            await m.createTable(districtsTable);
          }
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

  Future<void> incrementEntryAttempts(int entryId, String error) async {
    final entry = await (select(writeQueueTable)
          ..where((t) => t.id.equals(entryId)))
        .getSingleOrNull();
    if (entry == null) return;
    await (update(writeQueueTable)..where((t) => t.id.equals(entryId))).write(
      WriteQueueTableCompanion(
        attempts: Value(entry.attempts + 1),
        lastError: Value(error),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> deleteStaleEntries(DateTime cutoff) => (delete(writeQueueTable)
        ..where((t) =>
            t.status.equals('pending') &
            t.createdAt.isSmallerThanValue(cutoff)))
      .go();

  // ---- Hierarchy convenience methods ----

  Future<List<HierarchyCountry>> getAllCountries() =>
      select(countriesTable).get();

  Future<HierarchyCountry?> getCountry(String id) =>
      (select(countriesTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsertCountry(CountriesTableCompanion entry) =>
      into(countriesTable).insertOnConflictUpdate(entry);

  Future<List<HierarchyState>> getStatesForCountry(String countryId) =>
      (select(statesTable)..where((t) => t.countryId.equals(countryId))).get();

  Future<HierarchyState?> getState(String id) =>
      (select(statesTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsertState(StatesTableCompanion entry) =>
      into(statesTable).insertOnConflictUpdate(entry);

  Future<List<HierarchyCity>> getCitiesForState(String stateId) =>
      (select(citiesTable)..where((t) => t.stateId.equals(stateId))).get();

  Future<HierarchyCity?> getCity(String id) =>
      (select(citiesTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsertCity(CitiesTableCompanion entry) =>
      into(citiesTable).insertOnConflictUpdate(entry);

  Future<List<HierarchyDistrict>> getDistrictsForCity(String cityId) =>
      (select(districtsTable)..where((t) => t.cityId.equals(cityId))).get();

  Future<HierarchyDistrict?> getDistrict(String id) =>
      (select(districtsTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<HierarchyDistrict>> getAllDistricts() =>
      select(districtsTable).get();

  Future<void> upsertDistrict(DistrictsTableCompanion entry) =>
      into(districtsTable).insertOnConflictUpdate(entry);

  // ---- Cell property convenience methods ----

  Future<CellProperty?> getCellProperties(String cellId) =>
      (select(cellPropertiesTable)..where((t) => t.cellId.equals(cellId)))
          .getSingleOrNull();

  Future<void> upsertCellProperties(CellPropertiesTableCompanion entry) =>
      into(cellPropertiesTable).insertOnConflictUpdate(entry);

  Future<List<CellProperty>> getAllCellProperties() =>
      select(cellPropertiesTable).get();
}
