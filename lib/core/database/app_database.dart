import 'dart:async';
import 'dart:convert';

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

  /// Instance-level icon override URL. Null = use species default from enrichment.
  TextColumn get iconUrl => text().nullable()();

  /// Instance-level illustration override URL. Null = use species default from enrichment.
  TextColumn get artUrl => text().nullable()();

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
  TextColumn get size => text().nullable()();
  TextColumn get artUrl => text().nullable()();
  TextColumn get iconUrl => text().nullable()();
  DateTimeColumn get enrichedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {definitionId};
}

/// Unified species table — IUCN base data + AI enrichment.
/// Replaces both species.db (bundled asset) and LocalSpeciesEnrichmentTable.
/// Seeded from assets/species_data.json on first run.
@DataClassName('LocalSpecies')
class LocalSpeciesTable extends Table {
  TextColumn get definitionId => text()();
  TextColumn get scientificName => text()();
  TextColumn get commonName => text()();
  TextColumn get taxonomicClass => text()();
  TextColumn get iucnStatus => text()();
  TextColumn get habitatsJson => text()();
  TextColumn get continentsJson => text()();
  // Enrichment (nullable until AI-classified):
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

/// Permanent geo-derived properties for a Voronoi cell.
/// Resolved once when a cell is first made adjacent. Globally shared.
@DataClassName('LocalCellProperties')
class LocalCellPropertiesTable extends Table {
  TextColumn get cellId => text()(); // Voronoi cell ID (PK)
  TextColumn get habitats =>
      text()(); // JSON array of habitat names e.g. '["forest","freshwater"]'
  TextColumn get climate => text()(); // Climate enum name
  TextColumn get continent => text()(); // Continent enum name
  TextColumn get locationId => text().nullable()(); // FK → location_nodes
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {cellId};
}

/// A node in the administrative location hierarchy (country, state, city, etc.).
/// Globally shared — not per-user.
@DataClassName('LocalLocationNode')
class LocalLocationNodeTable extends Table {
  TextColumn get id => text()(); // UUID (PK)
  IntColumn get osmId =>
      integer().nullable()(); // OSM relation ID (null for synthetic nodes)
  TextColumn get name => text()(); // "Fredericton"
  TextColumn get adminLevel => text()(); // AdminLevel enum name
  TextColumn get parentId => text().nullable()(); // FK → parent node
  TextColumn get colorHex => text().nullable()(); // hex from flag, or null
  TextColumn get geometryJson =>
      text().nullable()(); // GeoJSON polygon, null if not fetched
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
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
  RealColumn get lastLat => real().nullable()();
  RealColumn get lastLon => real().nullable()();
  IntColumn get totalSteps => integer().withDefault(const Constant(0))();
  IntColumn get lastKnownStepCount =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local cache of observability events for offline session reconstruction.
/// Events are also flushed to Supabase `app_events` table remotely.
/// Retention: 10,000 rows max (oldest evicted on overflow).
@DataClassName('LocalAppEvent')
class LocalAppEventsTable extends Table {
  /// UUID v4.
  TextColumn get id => text()();

  /// Session UUID (one per app launch).
  TextColumn get sessionId => text()();

  /// Supabase user ID (nullable — events fire before auth).
  TextColumn get userId => text().nullable()();

  /// Event category: event, log, js, ui.
  TextColumn get category => text()();

  /// Event name (e.g. 'cell_visited', 'session_started').
  TextColumn get event => text()();

  /// JSON-encoded event payload.
  TextColumn get dataJson => text().withDefault(const Constant('{}'))();

  /// When the event occurred (UTC).
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// WRITE SERIALIZER
// ============================================================================

/// Serializes async write operations to prevent concurrent IndexedDB
/// persistence on web. Without this, two overlapping Drift writes
/// produce `ConstraintError: Index key is not unique`.
class _WriteSerializer {
  Future<void>? _inFlight;

  Future<T> run<T>(Future<T> Function() action) async {
    while (_inFlight != null) {
      try {
        await _inFlight;
      } catch (_) {
        // Previous write failed — proceed anyway.
      }
    }
    final completer = Completer<void>();
    _inFlight = completer.future;
    try {
      final result = await action();
      // Yield to let IndexedDB persistence complete before next write.
      await Future.delayed(Duration.zero);
      return result;
    } finally {
      _inFlight = null;
      completer.complete();
    }
  }
}

// ============================================================================
// DATABASE CLASS
// ============================================================================

/// SQL table names for all application tables.
///
/// Used by connection files to verify schema integrity after opening the
/// database. Kept here (next to the @DriftDatabase annotation) so it stays
/// in sync when tables are added or removed.
const kExpectedTableNames = [
  'local_cell_progress_table',
  'local_item_instance_table',
  'local_player_profile_table',
  'local_species_enrichment_table',
  'local_write_queue_table',
  'local_cell_properties_table',
  'local_location_node_table',
  'local_app_events_table',
];

@DriftDatabase(tables: [
  LocalCellProgressTable,
  LocalItemInstanceTable,
  LocalPlayerProfileTable,
  LocalSpeciesEnrichmentTable,
  LocalSpeciesTable,
  LocalWriteQueueTable,
  LocalCellPropertiesTable,
  LocalLocationNodeTable,
  LocalAppEventsTable,
])
class AppDatabase extends _$AppDatabase {
  /// Optional loader for species data JSON. Null in tests (manual seeding).
  final Future<String> Function()? _speciesDataLoader;

  AppDatabase([QueryExecutor? executor, this._speciesDataLoader])
      : super(executor ?? createDatabaseConnection());

  final _writer = _WriteSerializer();

  @override
  int get schemaVersion => 17;

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
        if (from < 8) {
          // Add last known position to player profile for session restore.
          await m.addColumn(
              localPlayerProfileTable, localPlayerProfileTable.lastLat);
          await m.addColumn(
              localPlayerProfileTable, localPlayerProfileTable.lastLon);
        }
        if (from < 9) {
          // Add size column to species enrichment (AnimalSize enum name).
          await m.addColumn(
              localSpeciesEnrichmentTable, localSpeciesEnrichmentTable.size);
        }
        if (from < 10) {
          // Add step tracking columns to player profile.
          await m.addColumn(
              localPlayerProfileTable, localPlayerProfileTable.totalSteps);
          await m.addColumn(localPlayerProfileTable,
              localPlayerProfileTable.lastKnownStepCount);
        }
        if (from < 11) {
          await m.createTable(localCellPropertiesTable);
          await m.createTable(localLocationNodeTable);
        }
        if (from < 12) {
          // Make osmId nullable for synthetic nodes (world, continent).
          // SQLite doesn't support ALTER COLUMN, so we recreate the table.
          await customStatement('''
            CREATE TABLE local_location_node_table_new (
              id TEXT NOT NULL PRIMARY KEY,
              osm_id INTEGER,
              name TEXT NOT NULL,
              admin_level TEXT NOT NULL,
              parent_id TEXT,
              color_hex TEXT,
              created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
            )
          ''');
          await customStatement('''
            INSERT INTO local_location_node_table_new
              (id, osm_id, name, admin_level, parent_id, color_hex, created_at)
            SELECT id, osm_id, name, admin_level, parent_id, color_hex, created_at
            FROM local_location_node_table
          ''');
          await customStatement('DROP TABLE local_location_node_table');
          await customStatement(
              'ALTER TABLE local_location_node_table_new RENAME TO local_location_node_table');
        }
        if (from < 13) {
          // Add geometryJson column for storing GeoJSON polygon boundaries.
          await m.addColumn(
              localLocationNodeTable, localLocationNodeTable.geometryJson);
        }
        if (from < 14) {
          await m.createTable(localAppEventsTable);
        }
        if (from < 15) {
          await m.addColumn(
              localSpeciesEnrichmentTable, localSpeciesEnrichmentTable.iconUrl);
        }
        if (from < 16) {
          await m.addColumn(
              localItemInstanceTable, localItemInstanceTable.iconUrl);
          await m.addColumn(
              localItemInstanceTable, localItemInstanceTable.artUrl);
        }
        if (from < 17) {
          await m.createTable(localSpeciesTable);
        }
      },
      beforeOpen: (details) async {
        if (_speciesDataLoader != null) {
          final count = await localSpeciesTable.count().getSingle();
          if (count == 0) {
            final sw = Stopwatch()..start();
            final jsonStr = await _speciesDataLoader!();
            final data = jsonDecode(jsonStr) as List;
            await batch((b) {
              for (final item in data) {
                final m = item as Map<String, dynamic>;
                final sciName = m['scientificName'] as String;
                final defId =
                    'fauna_${sciName.toLowerCase().replaceAll(' ', '_')}';
                b.insert(
                  localSpeciesTable,
                  LocalSpeciesTableCompanion.insert(
                    definitionId: defId,
                    scientificName: sciName,
                    commonName: m['commonName'] as String,
                    taxonomicClass: m['taxonomicClass'] as String,
                    iucnStatus: m['iucnStatus'] as String,
                    habitatsJson: jsonEncode(m['habitats']),
                    continentsJson: jsonEncode(m['continents']),
                  ),
                );
              }
            });
            sw.stop();
            // ignore: avoid_print
            print(
                '[AppDatabase] seeded ${data.length} species in ${sw.elapsedMilliseconds}ms');
          }
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
  ///
  /// Targets the `(userId, cellId)` composite unique constraint so that
  /// rows hydrated from Supabase (which may have a different PK `id`) still
  /// upsert correctly instead of violating the uniqueness constraint.
  Future<void> upsertCellProgress(LocalCellProgress progress) =>
      _writer.run(() => into(localCellProgressTable).insert(
            progress,
            onConflict: DoUpdate(
              (_) => progress,
              target: [
                localCellProgressTable.userId,
                localCellProgressTable.cellId,
              ],
            ),
          ));

  /// Delete cell progress
  Future<int> deleteCellProgress(String userId, String cellId) =>
      _writer.run(() => (delete(localCellProgressTable)
            ..where(
                (tbl) => tbl.userId.equals(userId) & tbl.cellId.equals(cellId)))
          .go());

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
  Future<void> insertItemInstance(LocalItemInstance instance) =>
      _writer.run(() => into(localItemInstanceTable).insert(instance));

  /// Upsert an item instance — insert or replace on conflict.
  ///
  /// Used by the Supabase hydration path to apply server-side updates
  /// (e.g. new badges, status changes) to items that already exist locally.
  Future<void> upsertItemInstance(LocalItemInstance instance) => _writer
      .run(() => into(localItemInstanceTable).insertOnConflictUpdate(instance));

  /// Update an existing item instance (e.g. status change).
  Future<bool> updateItemInstance(LocalItemInstance instance) =>
      _writer.run(() => update(localItemInstanceTable).replace(instance));

  /// Delete an item instance by ID.
  Future<int> deleteItemInstance(String id) => _writer.run(() =>
      (delete(localItemInstanceTable)..where((tbl) => tbl.id.equals(id))).go());

  /// Delete all item instances for a user.
  Future<int> clearUserItemInstances(String userId) =>
      _writer.run(() => (delete(localItemInstanceTable)
            ..where((tbl) => tbl.userId.equals(userId)))
          .go());

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

  Future<void> upsertEnrichment(LocalSpeciesEnrichment enrichment) =>
      _writer.run(() {
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
          size: Value(enrichment.size),
          artUrl: Value(enrichment.artUrl),
          enrichedAt: Value(enrichment.enrichedAt),
        );
        return into(localSpeciesEnrichmentTable).insert(
          enrichment,
          onConflict: DoUpdate((_) => companion),
        );
      });

  Future<List<LocalSpeciesEnrichment>> getEnrichmentsSince(DateTime since) {
    return (select(localSpeciesEnrichmentTable)
          ..where((tbl) => tbl.enrichedAt.isBiggerOrEqualValue(since)))
        .get();
  }

  /// Update enrichment columns on a LocalSpeciesTable row.
  /// Used by species delta-sync from Supabase.
  Future<void> updateSpeciesEnrichment({
    required String definitionId,
    String? animalClass,
    String? foodPreference,
    String? climate,
    int? brawn,
    int? wit,
    int? speed,
    String? size,
    String? iconUrl,
    String? artUrl,
    DateTime? enrichedAt,
  }) {
    return (update(localSpeciesTable)
          ..where((t) => t.definitionId.equals(definitionId)))
        .write(LocalSpeciesTableCompanion(
      animalClass:
          animalClass != null ? Value(animalClass) : const Value.absent(),
      foodPreference:
          foodPreference != null ? Value(foodPreference) : const Value.absent(),
      climate: climate != null ? Value(climate) : const Value.absent(),
      brawn: brawn != null ? Value(brawn) : const Value.absent(),
      wit: wit != null ? Value(wit) : const Value.absent(),
      speed: speed != null ? Value(speed) : const Value.absent(),
      size: size != null ? Value(size) : const Value.absent(),
      iconUrl: iconUrl != null ? Value(iconUrl) : const Value.absent(),
      artUrl: artUrl != null ? Value(artUrl) : const Value.absent(),
      enrichedAt: enrichedAt != null ? Value(enrichedAt) : const Value.absent(),
    ));
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
  Future<void> upsertPlayerProfile(LocalPlayerProfile profile) =>
      _writer.run(() => into(localPlayerProfileTable).insert(
            profile,
            onConflict: DoUpdate((_) => profile),
          ));

  /// Delete player profile
  Future<int> deletePlayerProfile(String userId) => _writer.run(() =>
      (delete(localPlayerProfileTable)..where((tbl) => tbl.id.equals(userId)))
          .go());

  // ========================================================================
  // WRITE QUEUE QUERIES
  // ========================================================================

  /// Insert a new write queue entry.
  Future<int> insertWriteQueueEntry(LocalWriteQueueTableCompanion entry) =>
      _writer.run(() => into(localWriteQueueTable).insert(entry));

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
  Future<bool> updateQueueEntry(LocalWriteQueueEntry entry) =>
      _writer.run(() => update(localWriteQueueTable).replace(entry));

  /// Delete a queue entry by ID (after server confirmation).
  Future<int> deleteQueueEntry(int id) => _writer.run(() =>
      (delete(localWriteQueueTable)..where((tbl) => tbl.id.equals(id))).go());

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
  ///
  /// Only deletes entries with status 'confirmed' or 'rejected' — never
  /// deletes 'pending' entries, which may still be awaiting their first
  /// successful flush.
  Future<int> deleteStaleQueueEntries(DateTime cutoff) =>
      _writer.run(() => (delete(localWriteQueueTable)
            ..where(
              (tbl) =>
                  tbl.createdAt.isSmallerThanValue(cutoff) &
                  tbl.status.isIn(['confirmed', 'rejected']),
            ))
          .go());

  /// Delete all queue entries for a user.
  Future<int> clearUserQueueEntries(String userId) => _writer.run(() =>
      (delete(localWriteQueueTable)..where((tbl) => tbl.userId.equals(userId)))
          .go());

  // ========================================================================
  // CELL PROPERTIES QUERIES
  // ========================================================================

  Future<LocalCellProperties?> getCellProperties(String cellId) {
    return (select(localCellPropertiesTable)
          ..where((tbl) => tbl.cellId.equals(cellId)))
        .getSingleOrNull();
  }

  Future<List<LocalCellProperties>> getAllCellProperties() {
    return select(localCellPropertiesTable).get();
  }

  Future<void> upsertCellProperties(LocalCellProperties properties) =>
      _writer.run(() => into(localCellPropertiesTable).insert(
            properties,
            onConflict: DoUpdate((_) => properties),
          ));

  Future<void> updateCellPropertiesLocationId(
          String cellId, String locationId) =>
      _writer.run(() => (update(localCellPropertiesTable)
                ..where((tbl) => tbl.cellId.equals(cellId)))
              .write(LocalCellPropertiesTableCompanion(
            locationId: Value(locationId),
          )));

  // ========================================================================
  // LOCATION NODE QUERIES
  // ========================================================================

  Future<LocalLocationNode?> getLocationNode(String id) {
    return (select(localLocationNodeTable)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  Future<LocalLocationNode?> getLocationNodeByOsmId(int osmId) {
    return (select(localLocationNodeTable)
          ..where((tbl) => tbl.osmId.equals(osmId)))
        .getSingleOrNull();
  }

  Future<void> upsertLocationNode(LocalLocationNode node) =>
      _writer.run(() => into(localLocationNodeTable).insert(
            node,
            onConflict: DoUpdate((_) => node),
          ));

  Future<List<LocalLocationNode>> getLocationNodeChildren(String parentId) {
    return (select(localLocationNodeTable)
          ..where((tbl) => tbl.parentId.equals(parentId)))
        .get();
  }

  Future<List<LocalLocationNode>> getAllLocationNodes() {
    return select(localLocationNodeTable).get();
  }

  // =========================================================================
  // App Events (observability)
  // =========================================================================

  /// Insert a batch of events. Used by ObservabilityBuffer for local persistence.
  Future<void> insertAppEvents(
      List<LocalAppEventsTableCompanion> events) async {
    await _writer.run(() async {
      await batch((b) {
        b.insertAll(localAppEventsTable, events);
      });
    });
  }

  /// Read events for a session (for offline debugging/reconstruction).
  Future<List<LocalAppEvent>> getEventsBySession(String sessionId) async {
    return (select(localAppEventsTable)
          ..where((e) => e.sessionId.equals(sessionId))
          ..orderBy([(e) => OrderingTerm.asc(e.createdAt)]))
        .get();
  }

  /// Count total local events.
  Future<int> countAppEvents() async {
    final count = countAll();
    final query = selectOnly(localAppEventsTable)..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count)!;
  }

  /// Delete oldest events when count exceeds cap.
  Future<void> trimAppEvents({int maxRows = 10000}) async {
    await _writer.run(() async {
      final total = await countAppEvents();
      if (total <= maxRows) return;
      final excess = total - maxRows;
      // Delete oldest N rows
      await customStatement(
        'DELETE FROM local_app_events_table WHERE id IN '
        '(SELECT id FROM local_app_events_table ORDER BY created_at ASC LIMIT ?)',
        [excess],
      );
    });
  }
}
