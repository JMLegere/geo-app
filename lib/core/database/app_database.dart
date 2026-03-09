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
  TextColumn get fogState =>
      text()(); // Stored as string: 'undetected', 'unexplored', etc.
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
        {
          userId,
          cellId
        }, // Unique constraint: one progress record per user per cell
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

  /// JSON-encoded list of badge strings (e.g. '["first_discovery","beta"]').
  TextColumn get badgesJson => text().withDefault(const Constant('[]'))();

  // ---------------------------------------------------------------------------
  // Denormalized identity fields (snapshotted from definition at discovery)
  // Added in schema v7.
  // ---------------------------------------------------------------------------

  /// Human-readable display name (e.g. "Red Fox"). Snapshotted at discovery.
  TextColumn get displayName => text().withDefault(const Constant(''))();

  /// Scientific name. Null for non-biological items.
  TextColumn get scientificName => text().nullable()();

  /// Item category (e.g. "fauna", "flora"). Snapshotted at discovery.
  TextColumn get categoryName => text().withDefault(const Constant('fauna'))();

  /// IUCN rarity tier name (e.g. "leastConcern"). Null if no rarity.
  TextColumn get rarityName => text().nullable()();

  /// JSON-encoded list of habitat name strings (e.g. '["forest","plains"]').
  TextColumn get habitatsJson => text().withDefault(const Constant('[]'))();

  /// JSON-encoded list of continent name strings (e.g. '["asia","europe"]').
  TextColumn get continentsJson => text().withDefault(const Constant('[]'))();

  /// Taxonomic class string (e.g. "Mammalia"). Fauna only — null otherwise.
  TextColumn get taxonomicClass => text().nullable()();

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

/// Local write queue for offline-first sync to Supabase.
/// Each row is a pending write operation (item discovery, cell visit, profile
/// update) that will be flushed to the server by [QueueProcessor].
@DataClassName('LocalWriteQueueEntry')
class LocalWriteQueueTable extends Table {
  /// Auto-incremented local ID. Entries are deleted after server confirmation.
  IntColumn get id => integer().autoIncrement()();

  /// Entity type: 'itemInstance', 'cellProgress', 'profile'.
  TextColumn get entityType => text()();

  /// Primary key of the entity being synced.
  TextColumn get entityId => text()();

  /// Operation: 'upsert' or 'delete'.
  TextColumn get operation => text()();

  /// JSON-encoded snapshot of the entity at time of queuing.
  TextColumn get payload => text()();

  /// Owner's user ID.
  TextColumn get userId => text()();

  /// Processing status: 'pending' or 'rejected'.
  TextColumn get status => text().withDefault(const Constant('pending'))();

  /// Number of sync attempts so far.
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// Last error message from a failed sync attempt.
  TextColumn get lastError => text().nullable()();

  /// When this entry was created.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// When this entry was last updated.
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  // Note: autoIncrement() implies primary key — do NOT override primaryKey.
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
  TextColumn get currentSeason =>
      text().withDefault(const Constant('summer'))();
  BoolColumn get hasCompletedOnboarding =>
      boolean().withDefault(const Constant(false))();
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
  LocalWriteQueueTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? createDatabaseConnection());

  @override
  int get schemaVersion => 7;

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
        if (from < 4) {
          await m.createTable(localWriteQueueTable);
        }
        if (from < 5) {
          await m.addColumn(
              localItemInstanceTable, localItemInstanceTable.badgesJson);
        }
        if (from < 6) {
          await m.addColumn(localPlayerProfileTable,
              localPlayerProfileTable.hasCompletedOnboarding);
        }
        if (from < 7) {
          // Add denormalized identity fields to item instances.
          // categoryName is new — not present before v7.
          await m.addColumn(
              localItemInstanceTable, localItemInstanceTable.displayName);
          await m.addColumn(
              localItemInstanceTable, localItemInstanceTable.scientificName);
          await m.addColumn(
              localItemInstanceTable, localItemInstanceTable.categoryName);
          await m.addColumn(
              localItemInstanceTable, localItemInstanceTable.rarityName);
          await m.addColumn(
              localItemInstanceTable, localItemInstanceTable.habitatsJson);
          await m.addColumn(
              localItemInstanceTable, localItemInstanceTable.continentsJson);
          await m.addColumn(
              localItemInstanceTable, localItemInstanceTable.taxonomicClass);
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
          ..where(
              (tbl) => tbl.userId.equals(userId) & tbl.cellId.equals(cellId)))
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
          ..where(
              (tbl) => tbl.userId.equals(userId) & tbl.cellId.equals(cellId)))
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
              tbl.userId.equals(userId) & tbl.acquiredInCellId.equals(cellId)))
        .get();
  }

  /// Get a single item instance by ID.
  Future<LocalItemInstance?> getItemInstance(String id) {
    return (select(localItemInstanceTable)..where((tbl) => tbl.id.equals(id)))
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
    return (delete(localItemInstanceTable)..where((tbl) => tbl.id.equals(id)))
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

  // ========================================================================
  // WRITE QUEUE QUERIES
  // ========================================================================

  /// Insert a new write queue entry.
  Future<int> insertWriteQueueEntry(LocalWriteQueueTableCompanion entry) {
    return into(localWriteQueueTable).insert(entry);
  }

  /// Get all pending queue entries, oldest first.
  ///
  /// When [userId] is provided, only entries belonging to that user are
  /// returned — prevents leaking another user's queued writes after an
  /// account switch on the same device.
  Future<List<LocalWriteQueueEntry>> getPendingQueueEntries({
    int? limit,
    String? userId,
  }) {
    final query = select(localWriteQueueTable)
      ..where((tbl) {
        final cond = tbl.status.equals('pending');
        if (userId != null) return cond & tbl.userId.equals(userId);
        return cond;
      })
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]);
    if (limit != null) {
      query.limit(limit);
    }
    return query.get();
  }

  /// Get queue entries by status.
  ///
  /// When [userId] is provided, only entries belonging to that user are
  /// returned.
  Future<List<LocalWriteQueueEntry>> getQueueEntriesByStatus(
    String status, {
    String? userId,
  }) {
    return (select(localWriteQueueTable)
          ..where((tbl) {
            final cond = tbl.status.equals(status);
            if (userId != null) return cond & tbl.userId.equals(userId);
            return cond;
          }))
        .get();
  }

  /// Update a queue entry's status and error info.
  Future<bool> updateQueueEntry(LocalWriteQueueEntry entry) {
    return update(localWriteQueueTable).replace(entry);
  }

  /// Delete a queue entry by ID (after server confirmation).
  Future<int> deleteQueueEntry(int id) {
    return (delete(localWriteQueueTable)..where((tbl) => tbl.id.equals(id)))
        .go();
  }

  /// Get a single queue entry by ID.
  Future<LocalWriteQueueEntry?> getQueueEntryById(int id) {
    return (select(localWriteQueueTable)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  /// Count pending queue entries using efficient SELECT COUNT(*).
  ///
  /// When [userId] is provided, only counts entries belonging to that user.
  Future<int> countPendingQueueEntries({String? userId}) {
    final countExp = localWriteQueueTable.id.count();
    final query = selectOnly(localWriteQueueTable)
      ..addColumns([countExp])
      ..where(localWriteQueueTable.status.equals('pending'));
    if (userId != null) {
      query.where(localWriteQueueTable.userId.equals(userId));
    }
    return query.map((row) => row.read(countExp)!).getSingle();
  }

  /// Delete stale entries older than [cutoff].
  Future<int> deleteStaleQueueEntries(DateTime cutoff) {
    return (delete(localWriteQueueTable)
          ..where((tbl) => tbl.createdAt.isSmallerThanValue(cutoff)))
        .go();
  }

  /// Delete all queue entries for a user.
  Future<int> clearUserQueueEntries(String userId) {
    return (delete(localWriteQueueTable)
          ..where((tbl) => tbl.userId.equals(userId)))
        .go();
  }
}
