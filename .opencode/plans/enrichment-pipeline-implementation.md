# Enrichment Pipeline Redesign — Implementation Plan

> **PRD:** `.opencode/plans/enrichment-pipeline-redesign.md`
> **Scope:** 5 PRs, each independently mergeable (compiles + tests pass)

---

## PR Overview

| PR | Title | Lines Added | Lines Deleted | Schema | Risk |
|----|-------|-------------|---------------|--------|------|
| 1 | Server Infrastructure | ~480 | 0 | Supabase migration 019 | Low — additive |
| 2 | FaunaDefinition + LocalSpeciesTable | ~450 | 0 | Drift v16→v17 | Low — additive |
| 3 | Swap Species Source | ~120 | ~230 | — | Medium |
| 4 | Delete Enrichment System | ~50 | ~2,800 | Drift v17→v18 | High |
| 5 | Server + Docs Cleanup | ~20 | ~1,700 | Supabase migration 020 | Low |
| **Total** | | **~1,120** | **~4,730** | | **Net: −3,610 lines** |

**Key insight:** `LocalSpeciesEnrichmentTable` stays in the Drift schema until PR 4 because the enrichment system is still alive in PRs 2–3. Both tables coexist during the transition. Client never calls old enrichment endpoints after PR 4.

---

## PR 1: Server Infrastructure — Supabase `species` Table + Worker

**Goal:** Create the `species` table on Supabase, seed it with 32,752 IUCN rows, deploy `process-enrichment-queue` Edge Function, register pg_cron. Pure backend — zero client changes.

**Branch:** `feat/species-table-backend`
**Depends on:** none

### Files Created

- **`supabase/migrations/019_species_table.sql`** — Creates `species` table (17 columns), partial indices for queue queries, RLS read-only policy. Migrates existing enrichment data from `species_enrichment` (UPSERT: enrichment columns only, base data columns default to `''`/`'[]'` until seed script fills them). Does NOT drop `species_enrichment` — client still reads it until PR 4.

  ```sql
  CREATE TABLE IF NOT EXISTS species (
    definition_id       TEXT PRIMARY KEY,
    scientific_name     TEXT NOT NULL DEFAULT '',
    common_name         TEXT NOT NULL DEFAULT '',
    taxonomic_class     TEXT NOT NULL DEFAULT '',
    iucn_status         TEXT NOT NULL DEFAULT '',
    habitats_json       TEXT NOT NULL DEFAULT '[]',
    continents_json     TEXT NOT NULL DEFAULT '[]',
    animal_class        TEXT,
    food_preference     TEXT,
    climate             TEXT,
    brawn               INTEGER,
    wit                 INTEGER,
    speed               INTEGER,
    size                TEXT,
    icon_url            TEXT,
    art_url             TEXT,
    enriched_at         TIMESTAMPTZ
  );

  INSERT INTO species (definition_id, animal_class, food_preference, climate, brawn, wit, speed, size, icon_url, art_url, enriched_at)
  SELECT definition_id, animal_class, food_preference, climate, brawn, wit, speed, size, icon_url, art_url, enriched_at
  FROM species_enrichment
  ON CONFLICT (definition_id) DO UPDATE SET
    animal_class = EXCLUDED.animal_class, food_preference = EXCLUDED.food_preference,
    climate = EXCLUDED.climate, brawn = EXCLUDED.brawn, wit = EXCLUDED.wit,
    speed = EXCLUDED.speed, size = EXCLUDED.size, icon_url = EXCLUDED.icon_url,
    art_url = EXCLUDED.art_url, enriched_at = EXCLUDED.enriched_at;

  CREATE INDEX IF NOT EXISTS idx_species_needs_classification
    ON species (definition_id) WHERE animal_class IS NULL;
  CREATE INDEX IF NOT EXISTS idx_species_needs_art
    ON species (definition_id) WHERE animal_class IS NOT NULL
    AND (icon_url IS NULL OR art_url IS NULL);

  ALTER TABLE species ENABLE ROW LEVEL SECURITY;
  CREATE POLICY "Public read" ON species FOR SELECT USING (true);
  ```

- **`supabase/functions/process-enrichment-queue/index.ts`** — Hourly worker (~350 lines). Structure:
  - Reuse LLM provider constants and `callLLMWithRotation()` from existing `enrich-species/index.ts` (same providers, same prompt, same validation)
  - Classification pass: `SELECT * FROM species WHERE animal_class IS NULL AND EXISTS (SELECT 1 FROM item_instances WHERE definition_id = species.definition_id) ORDER BY definition_id LIMIT 10` → LLM classify → `UPDATE species SET animal_class=..., enriched_at=now()` → sleep 1000ms
  - Art pass: `SELECT * FROM species WHERE animal_class IS NOT NULL AND (icon_url IS NULL OR art_url IS NULL) AND EXISTS (SELECT 1 FROM item_instances WHERE definition_id = species.definition_id) ORDER BY enriched_at ASC LIMIT 5` → Gemini `gemini-2.5-flash-image` → upload to `species-art` storage → `UPDATE species SET icon_url/art_url` → sleep 7000ms
  - On 429: exponential backoff (2s, 4s, 8s), max 3 retries, then stop
  - Returns `{ classified: N, icons: N, illustrations: N, errors: [...] }`
  - `verify_jwt = false` (called by pg_cron, not users)

- **`tool/seed_species_table.dart`** — Dart CLI script. Reads `assets/species_data.json`, connects to Supabase via `SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY` env vars, UPSERTs all 32,752 rows to `species` table in batches of 500. UPSERT only updates base data columns (`ON CONFLICT(definition_id) DO UPDATE SET scientific_name=..., common_name=..., ...`) — preserves enrichment columns already migrated from `species_enrichment`.

### Files Changed

- **`supabase/config.toml`** — Add `[functions.process-enrichment-queue]` with `verify_jwt = false`. Keep all existing function entries.

- **`.github/workflows/deploy-supabase.yml`** — Add `supabase functions deploy process-enrichment-queue --project-ref $PROJECT_REF` to the Edge Functions deploy step. Add migration 019 application block (same pattern as existing 018 block). Keep existing function deploys (removed in PR 5).

### Manual Steps After Deploy (not automated)

```sql
-- Set database settings for pg_cron HTTP call
ALTER DATABASE postgres SET app.settings.supabase_url = 'https://bfaczcsrpfcbijoaeckb.supabase.co';
ALTER DATABASE postgres SET app.settings.service_role_key = '<SERVICE_ROLE_KEY>';

-- Register hourly cron job
SELECT cron.schedule(
  'process-enrichment-queue',
  '0 * * * *',
  $$
  SELECT net.http_post(
    url := current_setting('app.settings.supabase_url') || '/functions/v1/process-enrichment-queue',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'),
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);
```

Run seed script:
```bash
SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... dart run tool/seed_species_table.dart
```

### Verification
- [ ] Migration 019 applies without error
- [ ] `SELECT COUNT(*) FROM species` returns 32,752
- [ ] `SELECT COUNT(*) FROM species WHERE animal_class IS NOT NULL` matches old `species_enrichment` count
- [ ] Manually invoke `process-enrichment-queue` — returns valid JSON
- [ ] `SELECT * FROM cron.job WHERE jobname = 'process-enrichment-queue'` returns a row
- [ ] Deploy workflow CI passes

---

## PR 2: FaunaDefinition Fields + LocalSpeciesTable (Additive)

**Goal:** Add enrichment fields to `FaunaDefinition`. Add `LocalSpeciesTable` to Drift (schema v17). Implement `DriftSpeciesRepository`. Write tests. All additive — existing enrichment system untouched.

**Branch:** `feat/local-species-table`
**Depends on:** none (parallel with PR 1)

### Files Changed

- **`lib/core/models/item_definition.dart`** — Add to `FaunaDefinition` class:
  ```dart
  final int? brawn;
  final int? wit;
  final int? speed;
  final String? size;       // AnimalSize enum name (not parsed here — stays as String?)
  final DateTime? enrichedAt;
  ```
  Add to constructor (all optional). Update `fromJson()`:
  ```dart
  brawn: json['brawn'] as int?,
  wit: json['wit'] as int?,
  speed: json['speed'] as int?,
  size: json['size'] as String?,
  enrichedAt: json['enriched_at'] != null ? DateTime.tryParse(json['enriched_at'] as String) : null,
  ```
  Update `toJson()` to include them conditionally. Add `FaunaDefinition.fromDrift(LocalSpecies row)` factory:
  ```dart
  factory FaunaDefinition.fromDrift(LocalSpecies row) {
    final habitats = (jsonDecode(row.habitatsJson) as List).cast<String>();
    final continents = (jsonDecode(row.continentsJson) as List).cast<String>();
    return FaunaDefinition(
      id: row.definitionId,
      displayName: row.commonName,
      scientificName: row.scientificName,
      taxonomicClass: row.taxonomicClass,
      rarity: IucnStatus.fromIucnString(row.iucnStatus),
      habitats: habitats.map((h) => Habitat.fromString(h.toLowerCase())).toList(),
      continents: continents.map((c) => Continent.fromDataString(c)).toList(),
      animalClass: row.animalClass != null ? AnimalClass.fromString(row.animalClass!) : null,
      foodPreference: row.foodPreference != null ? FoodType.fromString(row.foodPreference!) : null,
      climate: row.climate != null ? Climate.fromString(row.climate!) : null,
      iconUrl: row.iconUrl,
      artUrl: row.artUrl,
      brawn: row.brawn,
      wit: row.wit,
      speed: row.speed,
      size: row.size,
      enrichedAt: row.enrichedAt,
    );
  }
  ```

- **`lib/core/database/app_database.dart`** — Add `LocalSpeciesTable` class (17 columns, `@DataClassName('LocalSpecies')`). Add to `@DriftDatabase(tables: [...])` — keep `LocalSpeciesEnrichmentTable`. Increment `schemaVersion` to `17`. Add migration `if (from < 17) { await m.createTable(localSpeciesTable); }`. Add `_seedSpeciesTableIfNeeded()` method (called from `beforeOpen` callback):
  ```dart
  Future<void> _seedSpeciesTableIfNeeded(Future<String> Function() loader) async {
    final count = await localSpeciesTable.count().getSingle();
    if (count > 0) return;
    final jsonStr = await loader();
    final data = jsonDecode(jsonStr) as List;
    await batch((b) {
      for (final item in data) {
        final m = item as Map<String, dynamic>;
        final sciName = m['scientificName'] as String;
        final defId = 'fauna_${sciName.toLowerCase().replaceAll(' ', '_')}';
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
          onConflict: DoUpdate((_) => LocalSpeciesTableCompanion(
            scientificName: Value(sciName),
            commonName: Value(m['commonName'] as String),
            // Enrichment columns: Value.absent() — NOT overwritten
          )),
        );
      }
    });
  }
  ```
  Add constructor param `Future<String> Function()? speciesDataLoader`. Add to `beforeOpen`:
  ```dart
  beforeOpen: (details) async {
    if (speciesDataLoader != null) {
      await _seedSpeciesTableIfNeeded(speciesDataLoader!);
    }
  },
  ```
  Add query methods: `getSpeciesByDefinitionId(String id)`, `updateSpeciesEnrichment(String definitionId, {...nullable enrichment fields...})`.

- **`lib/core/state/app_database_provider.dart`** (or wherever `AppDatabase` is created) — Pass `speciesDataLoader: () => rootBundle.loadString('assets/species_data.json')` to `AppDatabase` constructor.

### Files Created

- **`lib/core/species/drift_species_repository.dart`** — `class DriftSpeciesRepository implements SpeciesRepository`. Constructor: `final AppDatabase _db`. Implements:
  - `getCandidates({habitats, continent})` → query `localSpeciesTable` with LIKE filters on `habitatsJson` and `continentsJson` columns (same logic as `NativeSpeciesRepository` but using Drift `customSelect()`). Returns `List<FaunaDefinition>` via `FaunaDefinition.fromDrift()`.
  - `getByScientificName(String name)` → query by `scientificName = name`.
  - `count()` → `localSpeciesTable.count().getSingle()`.
  - `getAll()` → `select(localSpeciesTable).get()`.
  - `dispose()` → no-op.

  For `getCandidates`, use `customSelect()` with raw SQL since Drift's type-safe API doesn't easily express LIKE on JSON array strings:
  ```dart
  Future<List<FaunaDefinition>> getCandidates({required Set<Habitat> habitats, required Continent continent}) async {
    if (habitats.isEmpty) return const [];
    final habitatClauses = List.filled(habitats.length, 'habitats_json LIKE ?').join(' OR ');
    final sql = 'SELECT * FROM local_species_table WHERE ($habitatClauses) AND continents_json LIKE ?';
    final params = [
      ...habitats.map((h) => '%"${h.displayName}"%'),
      '%"${continent.displayName}"%',
    ];
    final rows = await customSelect(sql, variables: params.map((p) => Variable.withString(p)).toList()).get();
    // Parse rows into FaunaDefinition via fromDrift mapping
    ...
  }
  ```

- **`test/core/database/local_species_table_test.dart`** — Tests: table creation, seeding from JSON fixture (use subset of `kSpeciesFixtureJson` from `test/fixtures/`), query by habitat/continent, `updateSpeciesEnrichment()` round-trip, idempotent seeding (0 rows → seed → N rows → seed again → still N rows).

- **`test/core/species/drift_species_repository_test.dart`** — Tests: `getCandidates()` returns species matching habitat+continent, `getByScientificName()` finds match or returns null, `count()` returns seeded count, `getAll()` returns all rows. Use `NativeDatabase.memory()`.

### Post-Edit Steps

```bash
dart run build_runner build --delete-conflicting-outputs
# Commit the regenerated app_database.g.dart
```

### Verification
- [ ] `flutter analyze` passes
- [ ] `LD_LIBRARY_PATH=. flutter test` passes (all existing + new tests)
- [ ] `app_database.g.dart` regenerated and committed
- [ ] `FaunaDefinition(brawn: 30, wit: 40, speed: 20)` constructs without error
- [ ] `FaunaDefinition.fromDrift(row)` round-trips correctly
- [ ] Species seeding bench: logs `[AppDatabase] seeded 32,752 species in Xs`

---

## PR 3: Swap Species Source + Delta-Sync

**Goal:** Wire `DriftSpeciesRepository` as the live species source. Switch `speciesRepositoryProvider` from async `FutureProvider` to sync `Provider`. Add species delta-sync from Supabase `species` table during hydration. Delete `species.db`, `species_repository_native.dart`, `species_repository_stub.dart`, `compile_species_db.dart`.

**Branch:** `feat/swap-species-source`
**Depends on:** PR 2

### Files Changed

- **`lib/core/species/species_repository.dart`** — Remove conditional import block. Remove `static fromAssets()` factory. Add `static fromDatabase(AppDatabase db) => DriftSpeciesRepository(db)`. Import `drift_species_repository.dart`. Import `app_database.dart`.

- **`lib/core/state/species_repository_provider.dart`** — Replace `FutureProvider<SpeciesRepository>` with `Provider<SpeciesRepository>`:
  ```dart
  final speciesRepositoryProvider = Provider<SpeciesRepository>((ref) {
    final db = ref.watch(appDatabaseProvider);
    return SpeciesRepository.fromDatabase(db);
  });

  final speciesCacheProvider = Provider<SpeciesCache>((ref) {
    final repo = ref.watch(speciesRepositoryProvider);
    return SpeciesCache(repo);  // Always backed — no .empty() fallback needed
  });
  ```
  Remove: `ObservabilityBuffer` timing, `.when()` pattern, `SpeciesCache.empty()` fallback.

- **`lib/features/sync/services/supabase_persistence.dart`** — Add `fetchSpeciesUpdates(DateTime since)`:
  ```dart
  Future<List<Map<String, dynamic>>> fetchSpeciesUpdates({required DateTime since}) async {
    try {
      final response = await _client
          .from('species')
          .select()
          .not('enriched_at', 'is', null)
          .gt('enriched_at', since.toIso8601String());
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('[SupabasePersistence] fetchSpeciesUpdates failed: $e');
      rethrow;
    }
  }
  ```
  Keep existing `fetchEnrichments()` (still called until PR 4).

- **`lib/core/state/persistence_consumer.dart`** — In `hydrateFromSupabase()`, add species delta-sync step after enrichment hydration (step 5):
  ```dart
  // 5. Species enrichment delta-sync → LocalSpeciesTable
  try {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncStr = prefs.getString('lastEnrichmentSync');
    final lastSync = lastSyncStr != null ? DateTime.tryParse(lastSyncStr) ?? DateTime(2020) : DateTime(2020);
    final speciesUpdates = await persistence.fetchSpeciesUpdates(since: lastSync);
    if (speciesUpdates.isNotEmpty) {
      for (final row in speciesUpdates) {
        await db.updateSpeciesEnrichment(
          definitionId: row['definition_id'] as String,
          animalClass: row['animal_class'] as String?,
          foodPreference: row['food_preference'] as String?,
          climate: row['climate'] as String?,
          brawn: row['brawn'] as int?,
          wit: row['wit'] as int?,
          speed: row['speed'] as int?,
          size: row['size'] as String?,
          iconUrl: row['icon_url'] as String?,
          artUrl: row['art_url'] as String?,
          enrichedAt: row['enriched_at'] != null ? DateTime.parse(row['enriched_at'] as String) : null,
        );
      }
      await prefs.setString('lastEnrichmentSync', DateTime.now().toIso8601String());
    }
  } catch (e) {
    debugPrint('[GameCoordinator] species delta-sync failed: $e');
  }
  ```
  Add `required AppDatabase db` parameter to `hydrateFromSupabase()`. Import `shared_preferences`.

- **`lib/core/state/game_coordinator_provider.dart`** — Pass `db: ref.read(appDatabaseProvider)` to `hydrateFromSupabase()` call. Remove the `.isEmpty` guard on `speciesCache.warmUp()` (cache is always backed now).

- **`lib/features/discovery/providers/discovery_provider.dart`** — In `speciesServiceProvider`: Remove `ref.watch(enrichmentMapProvider)`. Pass `enrichments: const {}` as bridge (merge logic is a no-op with empty map — fully cleaned in PR 4).

- **`pubspec.yaml`** — Check if `sqlite3` / `sqlite3_flutter_libs` are exclusively used by `species_repository_native.dart`. If so, remove them. (Note: `h3_flutter_plus` may use its own SQLite — check before removing.)

### Files Deleted
- `lib/core/species/species_repository_native.dart` (149 lines)
- `lib/core/species/species_repository_stub.dart` (29 lines)
- `assets/species.db` (5.6 MB)
- `tool/compile_species_db.dart` (~50 lines)

### Implementation Notes

Any test that overrides `speciesRepositoryProvider` must change from:
```dart
// Old (FutureProvider)
speciesRepositoryProvider.overrideWith((ref) async => MockSpeciesRepository())
// New (Provider)
speciesRepositoryProvider.overrideWith((ref) => MockSpeciesRepository())
```

### Verification
- [ ] `flutter analyze` passes
- [ ] `LD_LIBRARY_PATH=. flutter test` passes
- [ ] `assets/species.db` absent from project
- [ ] Species encounters still work (same species for same seed+cellId)
- [ ] Species delta-sync runs during hydration when Supabase configured
- [ ] `speciesRepositoryProvider` type is `Provider<SpeciesRepository>` (not `FutureProvider`)

---

## PR 4: Delete Enrichment System

**Goal:** Remove all client-side enrichment code (~2,800 lines). Migrate enrichment data from `LocalSpeciesEnrichmentTable` → `LocalSpeciesTable` in Drift migration v17→v18, then drop old table. This is the big one.

**Branch:** `feat/delete-enrichment-system`
**Depends on:** PR 3

### Files Deleted
- `lib/core/models/species_enrichment.dart` (164 lines)
- `lib/core/persistence/enrichment_repository.dart` (~80 lines)
- `lib/features/sync/services/enrichment_service.dart` (~525 lines)
- `lib/features/sync/providers/enrichment_provider.dart` (42 lines)
- `test/core/models/species_enrichment_test.dart`
- `test/core/persistence/enrichment_repository_test.dart`
- `test/features/sync/services/enrichment_service_test.dart`
- `test/features/enrichment/enrichment_service_test.dart`
- `test/core/state/enrichment_requeue_test.dart`
- `test/integration/enrichment_merge_test.dart`

### Files Renamed
- `lib/core/state/enrichment_consumer.dart` → `lib/core/state/affix_backfill.dart`
  - Keep: `needsIntrinsicBackfill()`, `rollAndPersistIntrinsicAffix()`, `backfillIntrinsicAffixes()`, `backfillAllMissingAffixes()`
  - Delete: `requeueUnenrichedSpecies()`, `partitionEnrichmentCandidates()`, `_requeueUnenrichedSpecies()`
  - Remove imports: `enrichment_provider.dart`, `enrichment_service.dart`

### Files Changed

**Critical ordering within this PR: delete files first, then fix compilation errors systematically.**

- **`lib/core/database/app_database.dart`** — Increment `schemaVersion` to `18`. Remove `LocalSpeciesEnrichmentTable` from `@DriftDatabase(tables: [...])`. Remove all enrichment methods (`getEnrichment`, `getAllEnrichments`, `upsertEnrichment`, `getEnrichmentsSince`). Add migration `if (from < 18)`:
  ```dart
  if (from < 18) {
    // Copy enrichment data from old LocalSpeciesEnrichmentTable into LocalSpeciesTable.
    // SQLite doesn't support UPDATE...FROM, use correlated subqueries.
    await customStatement('''
      UPDATE local_species_table SET
        animal_class   = (SELECT animal_class   FROM local_species_enrichment_table WHERE definition_id = local_species_table.definition_id),
        food_preference = (SELECT food_preference FROM local_species_enrichment_table WHERE definition_id = local_species_table.definition_id),
        climate        = (SELECT climate        FROM local_species_enrichment_table WHERE definition_id = local_species_table.definition_id),
        brawn          = (SELECT brawn          FROM local_species_enrichment_table WHERE definition_id = local_species_table.definition_id),
        wit            = (SELECT wit            FROM local_species_enrichment_table WHERE definition_id = local_species_table.definition_id),
        speed          = (SELECT speed          FROM local_species_enrichment_table WHERE definition_id = local_species_table.definition_id),
        size           = (SELECT size           FROM local_species_enrichment_table WHERE definition_id = local_species_table.definition_id),
        icon_url       = (SELECT art_url        FROM local_species_enrichment_table WHERE definition_id = local_species_table.definition_id),
        art_url        = (SELECT art_url        FROM local_species_enrichment_table WHERE definition_id = local_species_table.definition_id),
        enriched_at    = (SELECT enriched_at    FROM local_species_enrichment_table WHERE definition_id = local_species_table.definition_id)
      WHERE definition_id IN (SELECT definition_id FROM local_species_enrichment_table)
    ''');
    await customStatement('DROP TABLE IF EXISTS local_species_enrichment_table');
  }
  ```
  Run `dart run build_runner build --delete-conflicting-outputs` after.

- **`lib/core/species/species_cache.dart`** — Add `_byId` map (`Map<String, FaunaDefinition> _byId = {}`). In `warmUp()`, populate: `for (final def in candidates) { _byId[def.id] = def; }`. Add `FaunaDefinition? getByIdSync(String id) => _byId[id]`. Add `_byId.clear()` to `clear()`.

- **`lib/core/species/species_service.dart`** — Remove `import 'species_enrichment.dart'`. Remove `_enrichments` field. Remove `enrichments` param from `SpeciesService.fromCache()`. Simplify `_getPool()`: return `_cache!.getCandidatesSync(habitats: habitats, continent: continent)` directly (no map/merge).

- **`lib/core/state/game_coordinator_provider.dart`** — Remove (~200 lines total):
  - Imports: `species_enrichment.dart`, `enrichment_provider.dart`, `enrichment_consumer.dart` → update to `affix_backfill.dart`
  - `ref.watch(enrichmentRepositoryProvider)` (line ~86)
  - `enrichmentCache` declaration + `deferredEnrichmentQueue` + `deferredDrainTimer`
  - `enrichmentHook()` function body
  - `ref.read(enrichmentServiceProvider).onEnrichedHook = enrichmentHook` wiring
  - In `onItemDiscovered`: entire `if (event.item is FaunaDefinition)` block that calls `enrichmentServiceProvider.requestEnrichment()` + cache update
  - In `rehydrateData()` / `hydrateAndStart()`: `enrichmentRepo.getAllEnrichments()` from `Future.wait`, enrichment cache population loop — adjust results array indexing
  - `requeueUnenrichedSpecies()` call in background sync `.then()`
  - `ref.invalidate(enrichmentServiceProvider)` + `onEnrichedHook` re-wiring in `handleAuthState()`
  - Deferred drain timer cancel in dispose

  Rewire `enrichedStatsLookup` on `GameCoordinator`:
  ```dart
  final speciesCache = ref.read(speciesCacheProvider);
  coordinator.enrichedStatsLookup = (definitionId) {
    final def = speciesCache.getByIdSync(definitionId);
    if (def == null || def.brawn == null) return null;
    return (
      speed: def.speed!,
      brawn: def.brawn!,
      wit: def.wit!,
      size: def.size != null ? AnimalSize.fromString(def.size!) : null,
    );
  };
  ```

  Rewire `backfillAllMissingAffixes()` — build stats map from species cache:
  ```dart
  final enrichedStats = <String, ({int speed, int brawn, int wit, AnimalSize? size})>{};
  for (final item in ref.read(itemsProvider).items) {
    if (item.category != ItemCategory.fauna) continue;
    if (enrichedStats.containsKey(item.definitionId)) continue;
    final def = speciesCache.getByIdSync(item.definitionId);
    if (def != null && def.brawn != null) {
      enrichedStats[item.definitionId] = (
        speed: def.speed!, brawn: def.brawn!, wit: def.wit!,
        size: def.size != null ? AnimalSize.fromString(def.size!) : null,
      );
    }
  }
  backfillAllMissingAffixes(enrichmentCache: enrichedStats, ...);
  ```

- **`lib/core/state/persistence_consumer.dart`** — Remove `import 'species_enrichment.dart'`. Remove `enrichmentRepo` parameter from `hydrateFromSupabase()`. Remove step 4 (enrichments → SQLite). Remove `persistence.fetchEnrichments()` from `Future.wait`. Adjust results array indexing.

- **`lib/features/discovery/providers/discovery_provider.dart`** — Remove `import 'enrichment_provider.dart'`. In `speciesServiceProvider`: Call `SpeciesService.fromCache(cache: cache)` — no enrichments param.

- **`lib/features/pack/widgets/fauna_grid_tab.dart`** — Remove `ref.watch(enrichmentMapProvider)` + `.when()` handler + `import 'enrichment_provider.dart'`. Remove `enrichmentMap` from `showSpeciesCardModal()` call.

- **`lib/features/pack/widgets/species_card.dart`** — Remove `final SpeciesEnrichment? enrichment` parameter. Read `definition.brawn`, `definition.wit`, `definition.speed`, `definition.iconUrl`, `definition.artUrl`, `definition.animalClass`, `definition.foodPreference` directly.

- **`lib/features/pack/widgets/species_card_modal.dart`** — Remove `Map<String, SpeciesEnrichment>? enrichmentMap` parameter. Remove enrichment lookup inside.

- **`lib/features/pack/widgets/species_card_stats.dart`** — Read `definition.brawn/wit/speed` instead of `enrichment?.brawn`.

- **`lib/features/pack/widgets/species_card_art_zone.dart`** — Read `definition.artUrl/iconUrl` instead of `enrichment?.artUrl`.

- **`lib/features/discovery/widgets/discovery_notification.dart`** — Read from definition instead of enrichment.

- **`lib/features/sanctuary/widgets/sanctuary_species_tile.dart`** — Read from definition instead of enrichment.

- **`lib/features/sync/services/supabase_persistence.dart`** — Remove `fetchEnrichments()` method.

- **`lib/shared/constants.dart`** — Remove `kStartupEnrichmentCap`, `kDeferredEnrichmentBatchSize`, `kDeferredEnrichmentIntervalSeconds`.

- **`test/core/state/game_coordinator_provider_test.dart`** — Remove test groups: `'enrichment on cell visit'`, `'enrichment service re-wiring after auth cycle'`, enrichment service invalidation tests. Remove `enrichmentServiceProvider`, `enrichmentRepositoryProvider`, `enrichmentMapProvider` overrides from test containers.

- **`test/integration/supabase_hydration_test.dart`** — Remove enrichment hydration assertions. Update result indexing.

- **`test/features/discovery/providers/discovery_provider_test.dart`** — Remove `enrichmentMapProvider` override.

- **`test/core/database/migration_v16_test.dart`** — Rename to `migration_v18_test.dart`. Update migration test to verify: old `local_species_enrichment_table` absence after v18 migration + enrichment data presence on `local_species_table`.

### Post-Edit Steps

```bash
dart run build_runner build --delete-conflicting-outputs
LD_LIBRARY_PATH=. flutter test
flutter analyze
```

### Verification
- [ ] `flutter analyze` passes
- [ ] `LD_LIBRARY_PATH=. flutter test` passes
- [ ] `grep -r "SpeciesEnrichment" lib/ test/` returns zero results
- [ ] `grep -r "enrichmentMapProvider\|enrichmentServiceProvider\|enrichmentRepositoryProvider" lib/ test/` returns zero results
- [ ] Species card shows stats (brawn/wit/speed) for enriched species
- [ ] Fresh install: species seeded, delta-sync runs, enrichment shows in UI
- [ ] Upgrade v17→v18: enrichment data migrated, old table dropped

---

## PR 5: Server + Docs Cleanup

**Goal:** Delete old Edge Functions, drop `species_enrichment` table, clean up config, update all docs.

**Branch:** `chore/enrichment-cleanup`
**Depends on:** PR 1 (server infra), PR 4 (client cleaned up)

### Files Deleted
- `supabase/functions/enrich-species/` (entire directory)
- `supabase/functions/enrich-species-batch/` (entire directory)
- `supabase/functions/generate-species-art/` (entire directory)
- `supabase/functions/generate-species-art-batch/` (entire directory)
- `supabase/functions/admin-purge-enrichments/` (entire directory)

### Files Created

- **`supabase/migrations/020_drop_species_enrichment.sql`**:
  ```sql
  DROP TABLE IF EXISTS species_enrichment;
  ```

### Files Changed

- **`supabase/config.toml`** — Remove `[functions.enrich-species]`, `[functions.admin-purge-enrichments]`, `[functions.enrich-species-batch]`, `[functions.generate-species-art]`, `[functions.generate-species-art-batch]`.

- **`.github/workflows/deploy-supabase.yml`** — Remove deploy lines for 5 deleted functions. Keep `process-enrichment-queue`, `validate-encounter`, `enrich-location`, `enrich-locations-batch`.

- **`AGENTS.md`** (root) — Update: schema version 18, provider count (remove 3 enrichment providers), file count/total lines, architecture overview (remove enrichment_consumer from core/state), Known Tech Debt (remove if applicable).

- **`lib/core/AGENTS.md`** — Update: database section (8 tables, `LocalSpeciesTable` replaces `LocalSpeciesEnrichmentTable`), models section (remove `SpeciesEnrichment`), persistence section (remove `EnrichmentRepository`), state section (remove 3 enrichment providers), species section (`SpeciesRepository` now Drift-backed).

- **`lib/core/species/AGENTS.md`** — Update: `SpeciesRepository` is Drift-backed (not `species.db`). Remove enrichment merge reference in `SpeciesService`.

- **`lib/features/discovery/AGENTS.md`** — Remove enrichment integration. Update `speciesServiceProvider` docs.

- **`test/AGENTS.md`** — Remove deleted test file references.

- **`docs/data-model.md`** — Remove `SpeciesEnrichment` model, update DB schema table list (v18, 8 tables), update `FaunaDefinition` field list (add brawn/wit/speed/size/enrichedAt).

- **`docs/state.md`** — Remove 3 enrichment providers. Update provider count and dependency graph.

### Verification

Run after merge:
```bash
grep -r "species_enrichment\|SpeciesEnrichment\|EnrichmentService\|enrichment_consumer\|species\.db\|enrichmentMapProvider\|enrichmentServiceProvider\|enrichmentRepositoryProvider\|enrich-species\|compile_species_db" . \
  --include="*.dart" --include="*.ts" --include="*.sql" --include="*.yml" --include="*.toml" --include="*.md"
# Should return zero results (except this file and PRD)
```

- [ ] `flutter analyze` passes
- [ ] `LD_LIBRARY_PATH=. flutter test` passes
- [ ] `species_enrichment` table dropped from Supabase
- [ ] `process-enrichment-queue` still firing hourly on pg_cron
- [ ] All AGENTS.md + docs/ updated
- [ ] Zero stale references to deleted symbols

---

## Merge Order

```
PR 1 (server infra)    ─── can merge independently
PR 2 (Drift table)     ─── can merge independently
PR 3 (swap source)     ─── after PR 2
PR 4 (delete system)   ─── after PR 3
PR 5 (cleanup)         ─── after PR 1 AND PR 4
```

PRs 1 and 2 can be worked on and merged simultaneously. PRs 3→4→5 are sequential.
