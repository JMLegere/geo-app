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

  /// Denormalized icon URL (from species enrichment). Null = not enriched yet.
  TextColumn get iconUrl => text().nullable()();

  /// Denormalized art URL (from species enrichment). Null = not enriched yet.
  TextColumn get artUrl => text().nullable()();

  // ---------------------------------------------------------------------------
  // Denormalized species enrichment (snapshotted at discovery or lazily enriched)
  // Each field has a companion `_enrichver` column tracking the pipeline version
  // (commit hash) that produced the value. Schema v20.
  // ---------------------------------------------------------------------------

  TextColumn get animalClassName => text().nullable()();
  TextColumn get animalClassNameEnrichver => text().nullable()();
  TextColumn get foodPreferenceName => text().nullable()();
  TextColumn get foodPreferenceNameEnrichver => text().nullable()();
  TextColumn get climateName => text().nullable()();
  TextColumn get climateNameEnrichver => text().nullable()();
  IntColumn get brawn => integer().nullable()();
  TextColumn get brawnEnrichver => text().nullable()();
  IntColumn get wit => integer().nullable()();
  TextColumn get witEnrichver => text().nullable()();
  IntColumn get speed => integer().nullable()();
  TextColumn get speedEnrichver => text().nullable()();
  TextColumn get sizeName => text().nullable()();
  TextColumn get sizeNameEnrichver => text().nullable()();
  TextColumn get iconUrlEnrichver => text().nullable()();
  TextColumn get artUrlEnrichver => text().nullable()();

  // ---------------------------------------------------------------------------
  // Denormalized cell properties (from CellProperties at discovery)
  // ---------------------------------------------------------------------------

  TextColumn get cellHabitatName => text().nullable()();
  TextColumn get cellHabitatNameEnrichver => text().nullable()();
  TextColumn get cellClimateName => text().nullable()();
  TextColumn get cellClimateNameEnrichver => text().nullable()();
  TextColumn get cellContinentName => text().nullable()();
  TextColumn get cellContinentNameEnrichver => text().nullable()();

  // ---------------------------------------------------------------------------
  // Denormalized location hierarchy (lazily enriched from LocationNode chain)
  // ---------------------------------------------------------------------------

  TextColumn get locationDistrict => text().nullable()();
  TextColumn get locationDistrictEnrichver => text().nullable()();
  TextColumn get locationCity => text().nullable()();
  TextColumn get locationCityEnrichver => text().nullable()();
  TextColumn get locationState => text().nullable()();
  TextColumn get locationStateEnrichver => text().nullable()();
  TextColumn get locationCountry => text().nullable()();
  TextColumn get locationCountryEnrichver => text().nullable()();
  TextColumn get locationCountryCode => text().nullable()();
  TextColumn get locationCountryCodeEnrichver => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// LocalSpeciesEnrichmentTable removed in v18 — data migrated to LocalSpeciesTable.
// Old migration steps (v3, v9, v15) use customStatement() to reference the table by name.

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
  TextColumn get iconPrompt => text().nullable()();
  TextColumn get artPrompt => text().nullable()();
  DateTimeColumn get enrichedAt => dateTime().nullable()();

  // Per-field enrichment pipeline version stamps (commit SHA). Schema v20.
  TextColumn get animalClassEnrichver => text().nullable()();
  TextColumn get foodPreferenceEnrichver => text().nullable()();
  TextColumn get climateEnrichver => text().nullable()();
  TextColumn get brawnEnrichver => text().nullable()();
  TextColumn get witEnrichver => text().nullable()();
  TextColumn get speedEnrichver => text().nullable()();
  TextColumn get sizeEnrichver => text().nullable()();
  TextColumn get iconPromptEnrichver => text().nullable()();
  TextColumn get artPromptEnrichver => text().nullable()();
  TextColumn get iconUrlEnrichver => text().nullable()();
  TextColumn get artUrlEnrichver => text().nullable()();

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
  TextColumn get districtId => text().nullable()(); // FK → districts
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {cellId};
}

/// Country in the geographic hierarchy.
/// Pre-populated from Natural Earth dataset.
@DataClassName('LocalCountry')
class LocalCountryTable extends Table {
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

/// State / Province / Region in the geographic hierarchy.
@DataClassName('LocalState')
class LocalStateTable extends Table {
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
@DataClassName('LocalCity')
class LocalCityTable extends Table {
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
@DataClassName('LocalDistrict')
class LocalDistrictTable extends Table {
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
// LocalAppEventsTable removed — observability unified into app_logs (Supabase).
// All structured events now flow through debugPrint → LogFlushService → app_logs.

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
  'local_write_queue_table',
  'local_cell_properties_table',
  'local_app_events_table',
  'local_country_table',
  'local_state_table',
  'local_city_table',
  'local_district_table',
];

@DriftDatabase(tables: [
  LocalCellProgressTable,
  LocalItemInstanceTable,
  LocalPlayerProfileTable,
  LocalSpeciesTable,
  LocalWriteQueueTable,
  LocalCellPropertiesTable,
  LocalCountryTable,
  LocalStateTable,
  LocalCityTable,
  LocalDistrictTable,
])
class AppDatabase extends _$AppDatabase {
  /// Optional loader for species data JSON. Null in tests (manual seeding).
  final Future<String> Function()? _speciesDataLoader;

  AppDatabase([QueryExecutor? executor, this._speciesDataLoader])
      : super(executor ?? createDatabaseConnection());

  final _writer = _WriteSerializer();

  @override
  int get schemaVersion => 24;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // ── Legacy migrations (v1–v17) ──────────────────────────────────
        // These only apply to databases upgrading from pre-v18 schemas.
        // Fresh databases (created by createAll at v18+) already have the
        // correct schema and must NOT run these — they reference tables
        // and columns that never existed on fresh installs (e.g.
        // local_species_enrichment_table, dropped in v18).
        //
        // No production users exist on schemas < 18 (pre-release), so
        // these are kept only for development DB upgrades. Once all dev
        // databases are at v18+, this entire block can be deleted.
        if (from < 18) {
          // Check if this is a genuine upgrade from an old schema
          // (enrichment table exists) vs a fresh DB where Drift calls
          // onUpgrade(from:1) because no prior version was stored.
          final isLegacyDb = (await customSelect(
                "SELECT name FROM sqlite_master WHERE type='table' AND name='local_species_enrichment_table'",
              ).get())
                  .isNotEmpty ||
              from >= 2; // from >= 2 means a real prior schema existed

          if (isLegacyDb) {
            if (from < 2) {
              await m.createTable(localItemInstanceTable);
              await customStatement(
                  'DROP TABLE IF EXISTS local_collected_species_table');
            }
            if (from < 3) {
              await customStatement('''
                CREATE TABLE IF NOT EXISTS local_species_enrichment_table (
                  definition_id TEXT NOT NULL PRIMARY KEY,
                  animal_class TEXT NOT NULL,
                  food_preference TEXT NOT NULL,
                  climate TEXT NOT NULL,
                  brawn INTEGER NOT NULL,
                  wit INTEGER NOT NULL,
                  speed INTEGER NOT NULL,
                  art_url TEXT,
                  enriched_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
                )
              ''');
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
              await m.addColumn(
                  localItemInstanceTable, localItemInstanceTable.displayName);
              await m.addColumn(localItemInstanceTable,
                  localItemInstanceTable.scientificName);
              await m.addColumn(
                  localItemInstanceTable, localItemInstanceTable.categoryName);
              await m.addColumn(
                  localItemInstanceTable, localItemInstanceTable.rarityName);
              await m.addColumn(
                  localItemInstanceTable, localItemInstanceTable.habitatsJson);
              await m.addColumn(localItemInstanceTable,
                  localItemInstanceTable.continentsJson);
              await m.addColumn(localItemInstanceTable,
                  localItemInstanceTable.taxonomicClass);
            }
            if (from < 8) {
              await m.addColumn(
                  localPlayerProfileTable, localPlayerProfileTable.lastLat);
              await m.addColumn(
                  localPlayerProfileTable, localPlayerProfileTable.lastLon);
            }
            if (from < 9) {
              final hasEnrich = (await customSelect(
                "SELECT name FROM sqlite_master WHERE type='table' AND name='local_species_enrichment_table'",
              ).get())
                  .isNotEmpty;
              if (hasEnrich) {
                await customStatement(
                    'ALTER TABLE local_species_enrichment_table ADD COLUMN size TEXT');
              }
            }
            if (from < 10) {
              await m.addColumn(
                  localPlayerProfileTable, localPlayerProfileTable.totalSteps);
              await m.addColumn(localPlayerProfileTable,
                  localPlayerProfileTable.lastKnownStepCount);
            }
            if (from < 11) {
              await m.createTable(localCellPropertiesTable);
              // LocalLocationNodeTable was created here — dropped in v24.
              await customStatement('''
                CREATE TABLE IF NOT EXISTS local_location_node_table (
                  id TEXT NOT NULL PRIMARY KEY,
                  osm_id INTEGER,
                  name TEXT NOT NULL,
                  admin_level TEXT NOT NULL,
                  parent_id TEXT,
                  color_hex TEXT,
                  created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
                )
              ''');
            }
            // v12, v13: legacy LocalLocationNodeTable migrations — table dropped in v24.
            if (from < 14) {
              // localAppEventsTable was here — dropped in v21.
              // Create it only if upgrading from <14, so v21 drop succeeds.
              await customStatement('''
                CREATE TABLE IF NOT EXISTS local_app_events_table (
                  id TEXT NOT NULL PRIMARY KEY,
                  session_id TEXT NOT NULL,
                  user_id TEXT,
                  category TEXT NOT NULL,
                  event TEXT NOT NULL,
                  data_json TEXT NOT NULL DEFAULT '{}',
                  created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
                )
              ''');
            }
            if (from < 15) {
              final hasEnrich15 = (await customSelect(
                "SELECT name FROM sqlite_master WHERE type='table' AND name='local_species_enrichment_table'",
              ).get())
                  .isNotEmpty;
              if (hasEnrich15) {
                await customStatement(
                    'ALTER TABLE local_species_enrichment_table ADD COLUMN icon_url TEXT');
              }
            }
            if (from < 16) {
              // Guard: columns may already exist on fresh DB or web re-open.
              final cols16 = await customSelect(
                "PRAGMA table_info(local_item_instance_table)",
              ).get();
              final colNames16 =
                  cols16.map((r) => r.read<String>('name')).toSet();
              if (!colNames16.contains('icon_url')) {
                await m.addColumn(
                    localItemInstanceTable, localItemInstanceTable.iconUrl);
              }
              if (!colNames16.contains('art_url')) {
                await m.addColumn(
                    localItemInstanceTable, localItemInstanceTable.artUrl);
              }
            }
            if (from < 17) {
              await m.createTable(localSpeciesTable);
            }
            // v18: migrate enrichment data to LocalSpeciesTable, drop old table
            final tables = await customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='local_species_enrichment_table'",
            ).get();
            if (tables.isNotEmpty) {
              await customStatement('''
                UPDATE local_species_table SET
                  animal_class   = (SELECT animal_class   FROM local_species_enrichment_table WHERE definition_id = local_species_table.definition_id),
                  food_preference = (SELECT food_preference FROM local_species_enrichment_table WHERE definition_id = local_species_table.definition_id),
                  climate        = (SELECT climate        FROM local_species_enrichment_table WHERE definition_id = local_species_table.definition_id),
                  brawn          = (SELECT brawn          FROM local_species_enrichment_table WHERE definition_id = local_species_table.definition_id),
                  wit            = (SELECT wit            FROM local_species_enrichment_table WHERE definition_id = local_species_table.definition_id),
                  speed          = (SELECT speed          FROM local_species_enrichment_table WHERE definition_id = local_species_table.definition_id),
                  size           = (SELECT size           FROM local_species_enrichment_table WHERE definition_id = local_species_table.definition_id),
                  icon_url       = (SELECT icon_url       FROM local_species_enrichment_table WHERE definition_id = local_species_table.definition_id),
                  art_url        = (SELECT art_url        FROM local_species_enrichment_table WHERE definition_id = local_species_table.definition_id),
                  enriched_at    = (SELECT enriched_at    FROM local_species_enrichment_table WHERE definition_id = local_species_table.definition_id)
                WHERE definition_id IN (SELECT definition_id FROM local_species_enrichment_table)
              ''');
              await customStatement(
                  'DROP TABLE IF EXISTS local_species_enrichment_table');
            }
          }
        }
        if (from < 19) {
          // Add icon_prompt and art_prompt columns for 2-stage art pipeline.
          // Guard: columns may already exist if table was created fresh at v19+.
          final cols = await customSelect(
            "PRAGMA table_info(local_species_table)",
          ).get();
          final colNames = cols.map((r) => r.read<String>('name')).toSet();
          if (!colNames.contains('icon_prompt')) {
            await customStatement(
                'ALTER TABLE local_species_table ADD COLUMN icon_prompt TEXT');
          }
          if (!colNames.contains('art_prompt')) {
            await customStatement(
                'ALTER TABLE local_species_table ADD COLUMN art_prompt TEXT');
          }
        }
        if (from < 20) {
          // v20: Denormalized enrichment fields + per-field version stamps.
          // Guard against columns already existing (fresh DB created at v20+).
          Future<Set<String>> columnNames(String table) async {
            final cols = await customSelect(
              "PRAGMA table_info($table)",
            ).get();
            return cols.map((r) => r.read<String>('name')).toSet();
          }

          Future<void> addIfMissing(
              String table, String col, String type) async {
            final cols = await columnNames(table);
            if (!cols.contains(col)) {
              await customStatement('ALTER TABLE $table ADD COLUMN $col $type');
            }
          }

          // -- LocalItemInstanceTable: 32+ new columns --
          const itemTable = 'local_item_instance_table';
          // Species enrichment denorm (icon_url/art_url added in v16 but
          // without column-existence guards — include here as safety net).
          for (final col in [
            'icon_url', 'art_url',
            'animal_class_name', 'animal_class_name_enrichver',
            'food_preference_name', 'food_preference_name_enrichver',
            'climate_name', 'climate_name_enrichver',
            'size_name', 'size_name_enrichver',
            'brawn_enrichver', 'wit_enrichver', 'speed_enrichver',
            'icon_url_enrichver', 'art_url_enrichver',
            // Cell properties denorm
            'cell_habitat_name', 'cell_habitat_name_enrichver',
            'cell_climate_name', 'cell_climate_name_enrichver',
            'cell_continent_name', 'cell_continent_name_enrichver',
            // Location hierarchy denorm
            'location_district', 'location_district_enrichver',
            'location_city', 'location_city_enrichver',
            'location_state', 'location_state_enrichver',
            'location_country', 'location_country_enrichver',
            'location_country_code', 'location_country_code_enrichver',
          ]) {
            await addIfMissing(itemTable, col, 'TEXT');
          }
          for (final col in ['brawn', 'wit', 'speed']) {
            await addIfMissing(itemTable, col, 'INTEGER');
          }

          // -- LocalSpeciesTable: 11 new version columns --
          const speciesTable = 'local_species_table';
          for (final col in [
            'animal_class_enrichver',
            'food_preference_enrichver',
            'climate_enrichver',
            'brawn_enrichver',
            'wit_enrichver',
            'speed_enrichver',
            'size_enrichver',
            'icon_prompt_enrichver',
            'art_prompt_enrichver',
            'icon_url_enrichver',
            'art_url_enrichver',
          ]) {
            await addIfMissing(speciesTable, col, 'TEXT');
          }
        }
        if (from < 21) {
          // v21: Drop LocalAppEventsTable — observability unified into
          // app_logs (Supabase). Structured events now flow through
          // debugPrint → LogFlushService → app_logs.
          await customStatement('DROP TABLE IF EXISTS local_app_events_table');
        }
        if (from < 22) {
          // v22: Add adjacentLocationIds and cellIds to LocalLocationNodeTable
          // for detection zone caching.
          final cols = await customSelect(
            "PRAGMA table_info(local_location_node_table)",
          ).get();
          final colNames = cols.map((r) => r.read<String>('name')).toSet();
          if (!colNames.contains('adjacent_location_ids')) {
            await customStatement(
                'ALTER TABLE local_location_node_table ADD COLUMN adjacent_location_ids TEXT');
          }
          if (!colNames.contains('cell_ids')) {
            await customStatement(
                'ALTER TABLE local_location_node_table ADD COLUMN cell_ids TEXT');
          }
        }
        if (from < 23) {
          // v23: Add hierarchy tables (countries, states, cities, districts)
          // and district_id column to cell_properties.
          await m.createTable(localCountryTable);
          await m.createTable(localStateTable);
          await m.createTable(localCityTable);
          await m.createTable(localDistrictTable);

          // Add district_id to cell_properties (may already exist on fresh DB).
          final cols23 = await customSelect(
            "PRAGMA table_info(local_cell_properties_table)",
          ).get();
          final colNames23 = cols23.map((r) => r.read<String>('name')).toSet();
          if (!colNames23.contains('district_id')) {
            await customStatement(
              'ALTER TABLE local_cell_properties_table ADD COLUMN district_id TEXT',
            );
          }
        }
        if (from < 24) {
          // v24: Drop legacy LocalLocationNodeTable (replaced by 4-table hierarchy).
          await customStatement(
              'DROP TABLE IF EXISTS local_location_node_table');
        }
      },
      beforeOpen: (details) async {
        if (_speciesDataLoader != null) {
          final count = await localSpeciesTable.count().getSingle();
          if (count == 0) {
            final sw = Stopwatch()..start();
            try {
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
            } catch (e) {
              // ignore: avoid_print
              print(
                  '[AppDatabase] species seeding failed (will retry next open): $e');
              // Don't rethrow — let the DB open without species data.
              // Supabase species sync will populate later.
            }
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

  /// Update enrichment columns on a LocalSpeciesTable row.
  /// Used by species delta-sync from Supabase.
  /// Update enrichment columns on a LocalSpeciesTable row.
  ///
  /// All fields are written unconditionally (including null) so that
  /// server-side clears (e.g. art URL wipe) propagate to the local cache.
  /// Previously used `Value.absent()` for nulls, which meant "don't touch" —
  /// stale local values were never cleared.
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
    String? iconPrompt,
    String? artPrompt,
    DateTime? enrichedAt,
    String? animalClassEnrichver,
    String? foodPreferenceEnrichver,
    String? climateEnrichver,
    String? brawnEnrichver,
    String? witEnrichver,
    String? speedEnrichver,
    String? sizeEnrichver,
    String? iconPromptEnrichver,
    String? artPromptEnrichver,
    String? iconUrlEnrichver,
    String? artUrlEnrichver,
  }) {
    return (update(localSpeciesTable)
          ..where((t) => t.definitionId.equals(definitionId)))
        .write(LocalSpeciesTableCompanion(
      animalClass: Value(animalClass),
      foodPreference: Value(foodPreference),
      climate: Value(climate),
      brawn: Value(brawn),
      wit: Value(wit),
      speed: Value(speed),
      size: Value(size),
      iconUrl: Value(iconUrl),
      artUrl: Value(artUrl),
      iconPrompt: Value(iconPrompt),
      artPrompt: Value(artPrompt),
      enrichedAt: Value(enrichedAt),
      animalClassEnrichver: Value(animalClassEnrichver),
      foodPreferenceEnrichver: Value(foodPreferenceEnrichver),
      climateEnrichver: Value(climateEnrichver),
      brawnEnrichver: Value(brawnEnrichver),
      witEnrichver: Value(witEnrichver),
      speedEnrichver: Value(speedEnrichver),
      sizeEnrichver: Value(sizeEnrichver),
      iconPromptEnrichver: Value(iconPromptEnrichver),
      artPromptEnrichver: Value(artPromptEnrichver),
      iconUrlEnrichver: Value(iconUrlEnrichver),
      artUrlEnrichver: Value(artUrlEnrichver),
    ));
  }

  /// Delete multiple write queue entries by ID (batch cleanup of superseded
  /// entries during flush coalescing).
  Future<int> deleteQueueEntries(List<int> ids) =>
      (delete(localWriteQueueTable)..where((t) => t.id.isIn(ids))).go();

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
  // HIERARCHY TABLE QUERIES
  // ========================================================================

  Future<List<LocalCountry>> getAllCountries() =>
      select(localCountryTable).get();

  Future<List<LocalState>> getStatesForCountry(String countryId) =>
      (select(localStateTable)..where((t) => t.countryId.equals(countryId)))
          .get();

  Future<List<LocalCity>> getCitiesForState(String stateId) =>
      (select(localCityTable)..where((t) => t.stateId.equals(stateId))).get();

  Future<List<LocalDistrict>> getDistrictsForCity(String cityId) =>
      (select(localDistrictTable)..where((t) => t.cityId.equals(cityId))).get();

  Future<LocalCountry?> getCountry(String id) =>
      (select(localCountryTable)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<LocalState?> getState(String id) =>
      (select(localStateTable)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<LocalCity?> getCity(String id) =>
      (select(localCityTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<LocalDistrict?> getDistrict(String id) =>
      (select(localDistrictTable)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<void> upsertCountry(LocalCountryTableCompanion entry) =>
      into(localCountryTable).insertOnConflictUpdate(entry);

  Future<void> upsertState(LocalStateTableCompanion entry) =>
      into(localStateTable).insertOnConflictUpdate(entry);

  Future<void> upsertCity(LocalCityTableCompanion entry) =>
      into(localCityTable).insertOnConflictUpdate(entry);

  Future<void> upsertDistrict(LocalDistrictTableCompanion entry) =>
      into(localDistrictTable).insertOnConflictUpdate(entry);

  // App Events table removed in v21 — observability unified into app_logs.
}
