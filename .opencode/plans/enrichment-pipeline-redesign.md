# PRD: Enrichment Pipeline Redesign

> **Status:** Design Complete — Ready for Implementation
> **Author:** Design Jam (2026-03-20)
> **Scope:** Backend-driven enrichment queue, merged species table, client simplification

---

## 1. Problem Statement

The current enrichment pipeline has **client-managed complexity** that should live on the backend:

- **In-memory queue** — `EnrichmentService` manages a drain timer, batch/single modes, deferred enrichment, startup requeue logic, and rate limiting. ~800 lines of queue machinery in the client. Queue is lost on app restart.
- **Startup requeue** — On every app launch, the client scans inventory against the enrichment cache, partitions candidates into startup vs deferred batches, and drains them with a periodic timer. ~200 lines of band-aid code.
- **Art generation bolted on** — Art generation was added inline to `enrich-species`, making the Edge Function slow and mixing concerns (classification vs image generation).
- **Two species data sources** — `species.db` (bundled read-only asset) and `LocalSpeciesEnrichmentTable` (Drift). `SpeciesService` merges them at read time. Two schemas, two codepaths, no JOINs.
- **Client awareness of enrichment internals** — Client checks for missing `size`, missing art URLs, incomplete enrichment. Should not care.

**Result:** ~3,500 lines of enrichment-related client code, 5 Edge Functions, fragile startup sequencing, and no self-healing for missed enrichments.

---

## 2. Target Architecture

### Principle

**One table. One backend worker. Zero client enrichment logic.**

### Data Flow

```
Player discovers fauna
  ↓
item_instances row written to Supabase (existing persistence flow)
  ↓
pg_cron (hourly): process-enrichment-queue
  ↓
  1. Find species in item_instances not yet classified
     → JOIN species table for names/taxonomy
     → LLM classify → UPDATE species row
  2. Find classified species missing art
     → Gemini generate icon + illustration
     → Upload to storage → UPDATE species row
  ↓
Client syncs species table (delta by enriched_at)
  ↓
FaunaDefinition has stats + art. UI renders.
```

### What Lives Where

| Concern | Current | Target |
|---------|---------|--------|
| Species base data | Bundled `species.db` (read-only SQLite) | `LocalSpeciesTable` in Drift (seeded from `species_data.json` on first run) |
| Enrichment data | `LocalSpeciesEnrichmentTable` + `species_enrichment` on Supabase | Columns on the same `species` / `LocalSpeciesTable` row |
| Classification trigger | Client queue → `enrich-species` Edge Function | pg_cron → `process-enrichment-queue` Edge Function |
| Art generation trigger | Inline in `enrich-species` | pg_cron → `process-enrichment-queue` (art pass) |
| Rate limit management | Client-side exponential backoff | Backend worker with sleep + backoff |
| Queue durability | In-memory (lost on restart) | `species` table with null columns IS the queue |
| Startup requeue | Client scans inventory, partitions, deferred drain | Not needed — backend handles it |
| Species data model | `FaunaDefinition` + `SpeciesEnrichment` (separate, merged at read) | `FaunaDefinition` with enrichment fields built-in |

---

## 3. Database Schema

### 3a. Supabase: `species` Table (New)

Replaces `species_enrichment`. Contains all 32,752 IUCN species with enrichment columns.

```sql
CREATE TABLE species (
  definition_id       TEXT PRIMARY KEY,
  scientific_name     TEXT NOT NULL,
  common_name         TEXT NOT NULL,
  taxonomic_class     TEXT NOT NULL,
  iucn_status         TEXT NOT NULL,
  habitats_json       TEXT NOT NULL,
  continents_json     TEXT NOT NULL,
  -- Enrichment (null until AI-classified):
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

-- Partial indices for queue queries
CREATE INDEX idx_species_needs_classification
  ON species (definition_id) WHERE animal_class IS NULL;
CREATE INDEX idx_species_needs_art
  ON species (definition_id) WHERE animal_class IS NOT NULL
  AND (icon_url IS NULL OR art_url IS NULL);

-- RLS: read-only for clients
ALTER TABLE species ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read" ON species FOR SELECT USING (true);
```

### 3b. Client: `LocalSpeciesTable` (Drift, New)

Replaces both `species.db` asset and `LocalSpeciesEnrichmentTable`. Seeded from `species_data.json` on first install.

```dart
class LocalSpeciesTable extends Table {
  TextColumn get definitionId => text()();
  TextColumn get scientificName => text()();
  TextColumn get commonName => text()();
  TextColumn get taxonomicClass => text()();
  TextColumn get iucnStatus => text()();
  TextColumn get habitatsJson => text()();
  TextColumn get continentsJson => text()();
  // Enrichment (nullable until classified):
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
```

**Schema version:** 17 (up from 16).

**Migration v16→v17:**
1. Create `LocalSpeciesTable`
2. Migrate data from `LocalSpeciesEnrichmentTable` into `LocalSpeciesTable` (enrichment columns only — base data seeded separately)
3. Drop `LocalSpeciesEnrichmentTable`

**First-run seeding:** If `LocalSpeciesTable` has 0 rows after migration, bulk-insert from `assets/species_data.json` (32,752 rows in a single Drift batch transaction). Expected time: 2-5 seconds.

**Enrichment merge during seeding:** After inserting base data, UPDATE any rows that had enrichment data in the old `LocalSpeciesEnrichmentTable` (migrated in step 2 above).

---

## 4. Backend: `process-enrichment-queue` Edge Function

Single Edge Function replacing 5 existing functions. Invoked hourly by pg_cron.

### Logic

```
1. Classification pass (LLM — free providers):
   SELECT s.definition_id, s.scientific_name, s.common_name, s.taxonomic_class
   FROM species s
   WHERE s.animal_class IS NULL
     AND EXISTS (SELECT 1 FROM item_instances i WHERE i.definition_id = s.definition_id)
   ORDER BY s.definition_id
   LIMIT 10;

   For each row:
     → Call LLM (Groq/OpenCode Zen with provider rotation)
     → Validate response (animal_class, food_preference, climate, brawn+wit+speed=90, size)
     → UPDATE species SET animal_class=..., food_preference=..., ..., enriched_at=now()
     → Sleep 1s between calls

2. Art pass (Gemini — 250/day free):
   SELECT s.definition_id, s.scientific_name, s.common_name,
          s.brawn, s.wit, s.speed, s.climate
   FROM species s
   WHERE s.animal_class IS NOT NULL
     AND (s.icon_url IS NULL OR s.art_url IS NULL)
     AND EXISTS (SELECT 1 FROM item_instances i WHERE i.definition_id = s.definition_id)
   ORDER BY s.enriched_at ASC
   LIMIT 5;

   For each row:
     If icon_url IS NULL:
       → Build chibi icon prompt
       → Call Gemini (gemini-2.5-flash-image)
       → Upload to species-art storage bucket
       → UPDATE species SET icon_url = public_url
     If art_url IS NULL:
       → Build watercolor illustration prompt (use brawn/wit/speed for pose, climate for lighting)
       → Call Gemini
       → Upload to storage
       → UPDATE species SET art_url = public_url
     Sleep 7s between Gemini calls (stays under 10 RPM)
     On 429: exponential backoff (2s, 4s, 8s), max 3 retries, then stop — next cron tick resumes

3. Return summary:
   { classified: N, icons: N, illustrations: N, errors: [...] }
```

### Rate Limiting Strategy

- **LLM classification:** Free providers (Groq, OpenCode Zen) have generous limits. 1s delay between calls is sufficient. Provider rotation on failure.
- **Gemini art:** 10 RPM, 250 RPD free tier. 7s between calls (safe margin). On 429, exponential backoff then stop. Next hourly tick resumes. At 5 species per hour (10 Gemini calls), daily throughput is ~120 images. The 438 existing species (876 images) fill in ~7 days. New species are classified within the hour, art within a day.

### pg_cron Schedule

```sql
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

### LLM Provider Rotation

Same providers as current `enrich-species`:

| Provider | Model | Key Env |
|----------|-------|---------|
| Groq | llama-3.3-70b-versatile | `GROQ_API_KEY` |
| OpenCode Zen | gpt-5-nano | `OPENCODE_ZEN_API_KEY` |
| OpenCode Zen | big-pickle | `OPENCODE_ZEN_API_KEY` |
| OpenCode Zen | minimax-m2.5-free | `OPENCODE_ZEN_API_KEY` |
| OpenCode Zen | mimo-v2-flash-free | `OPENCODE_ZEN_API_KEY` |
| OpenCode Zen | nemotron-3-super-free | `OPENCODE_ZEN_API_KEY` |

On failure, rotate to next provider. All providers exhausted → log error, skip species, next tick retries.

### Art Prompts

**Icon (96×96 chibi):**
```
Cute chibi-style character icon of a {commonName} ({scientificName}).
Simple, adorable, round proportions, expressive eyes, clean outline.
Transparent background, centered, facing slightly left.
Style: Pokemon PC box sprite, soft colors, no text, no shadows, no ground.
96x96 pixels.
```

**Illustration (512×512 watercolor):**
```
Professional Pokemon TCG-style watercolor illustration of a {commonName} ({scientificName}).
Pose: {pose from stats — brawn=powerful, speed=dynamic, wit=alert}.
Background: Soft atmospheric natural scene, impressionistic.
{climate lighting — tropic=golden, boreal=crisp, frigid=arctic}.
Style: Watercolor with visible brushstrokes, soft edges, translucent layers.
No text, no labels, no borders. 512x512 pixels.
```

---

## 5. Client Changes

### 5a. Model: Merge `SpeciesEnrichment` into `FaunaDefinition`

`FaunaDefinition` already has `animalClass`, `foodPreference`, `climate`, `iconUrl`, `artUrl` as nullable fields. Add:

```dart
class FaunaDefinition extends ItemDefinition {
  // ... existing fields ...
  // Add these enrichment fields:
  final int? brawn;
  final int? wit;
  final int? speed;
  final String? size;
  final DateTime? enrichedAt;
}
```

Update `FaunaDefinition.fromJson()` to parse these from the Drift row.

Delete `SpeciesEnrichment` model entirely.

### 5b. Species Data: Drift-managed `LocalSpeciesTable`

Replace `species.db` (bundled read-only SQLite asset) with `LocalSpeciesTable` in `AppDatabase`.

**`SpeciesRepository` rewrite:**
Currently opens `species.db` via raw SQLite FFI. Rewrite to query `AppDatabase.localSpeciesTable` via Drift. Same interface (`getCandidates`, `getAll`, `count`, `getByScientificName`), different backing store.

Delete:
- `assets/species.db`
- `lib/core/species/species_repository_native.dart`
- `lib/core/species/species_repository_stub.dart`
- `tool/compile_species_db.dart`

Keep:
- `lib/core/species/species_repository.dart` (abstract interface — update to use Drift)
- `assets/species_data.json` (used for first-run seeding)

**`SpeciesCache` stays:**
Same LRU cache pattern. Warms up from Drift-backed `SpeciesRepository` instead of raw SQLite. Interface unchanged. Needed for sync access during ~10Hz game tick.

### 5c. `SpeciesService` Simplification

Remove `_enrichments` map and merge logic in `_getPool()`. `FaunaDefinition` objects come from Drift with enrichment already baked in — no merge needed.

```dart
// Current:
SpeciesService.fromCache({required SpeciesCache cache, Map<String, SpeciesEnrichment> enrichments})

// Target:
SpeciesService.fromCache({required SpeciesCache cache})
// No enrichments parameter. FaunaDefinition has everything.
```

### 5d. Sync: Pull Enrichment Updates

On app start, fetch updated species rows from Supabase and write to local `LocalSpeciesTable`:

```dart
// In persistence_consumer or game_coordinator_provider hydration:
final lastSync = prefs.getDateTime('lastEnrichmentSync') ?? DateTime(2020);
final updated = await supabase
    .from('species')
    .select()
    .not('enriched_at', 'is', null)
    .gt('enriched_at', lastSync.toIso8601String());

for (final row in updated) {
  await db.localSpeciesTable.updateEnrichmentColumns(row);
}
prefs.setDateTime('lastEnrichmentSync', DateTime.now());
```

This replaces the current `EnrichmentService.syncEnrichments()` and `SupabasePersistence.fetchEnrichments()`.

### 5e. UI: Read from `FaunaDefinition` Directly

All UI components currently receiving `SpeciesEnrichment?` change to read from `FaunaDefinition`:

| Widget | Change |
|--------|--------|
| `species_card.dart` | Remove `enrichment` param. Read `definition.brawn`, `definition.iconUrl`, etc. |
| `species_card_modal.dart` | Remove `enrichmentMap` param. |
| `species_card_stats.dart` | Read `definition.brawn/wit/speed` instead of `enrichment?.brawn`. |
| `species_card_art_zone.dart` | Read `definition.artUrl` instead of `enrichment?.artUrl`. |
| `fauna_grid_tab.dart` | Remove `enrichmentMapProvider` watch. |
| `discovery_notification.dart` | Read from definition. |
| `sanctuary_species_tile.dart` | Read from definition. |

### 5f. `game_coordinator_provider.dart` Changes

Remove:
- `enrichmentCache` (`Map<String, ({int speed, int brawn, int wit, AnimalSize? size})>`)
- `enrichmentHook` callback
- `onEnrichedHook` wiring on `EnrichmentService`
- `_requeueUnenrichedSpecies()` call
- Deferred enrichment queue + timer
- `enrichmentServiceProvider` reads/invalidation
- `enrichmentRepositoryProvider` reads

The `enrichedStatsLookup` callback on `GameCoordinator` still needs stats for weight rolling during discovery. Change it to read from the local `LocalSpeciesTable` (via a repository query or in-memory cache) instead of the enrichment cache.

Add:
- Species enrichment sync during hydration (Phase 5d above)

### 5g. Instance Stat Variance

Base stats (brawn/wit/speed) live on the species. Instance-level variance (±30%) is rolled at creation time using `SHA-256(instanceId)` and applied on top of base stats. This is the existing design (permanent per-instance variance, seeded by instance UUID). No change needed.

---

## 6. Delete List

### Client Files to Delete (~2,000 lines)

| File | Lines | Reason |
|------|-------|--------|
| `lib/core/models/species_enrichment.dart` | ~120 | Merged into `FaunaDefinition` |
| `lib/core/persistence/enrichment_repository.dart` | ~80 | Replaced by `LocalSpeciesTable` queries |
| `lib/features/sync/services/enrichment_service.dart` | ~525 | Backend handles enrichment |
| `lib/features/sync/providers/enrichment_provider.dart` | ~45 | 3 providers deleted |
| `lib/core/state/enrichment_consumer.dart` | ~200 | Requeue/partition/backfill gone |
| `lib/core/species/species_repository_native.dart` | ~149 | Replaced by Drift-backed repository |
| `lib/core/species/species_repository_stub.dart` | ~20 | Web stub no longer needed |
| `tool/compile_species_db.dart` | ~50 | No longer compiling species.db |
| `assets/species.db` | — | Replaced by Drift-managed table |

### Client Tests to Delete (~800 lines)

| File | Lines | Reason |
|------|-------|--------|
| `test/core/models/species_enrichment_test.dart` | ~100 | Model deleted |
| `test/core/persistence/enrichment_repository_test.dart` | ~100 | Repository deleted |
| `test/features/sync/services/enrichment_service_test.dart` | ~400 | Service deleted |
| `test/features/enrichment/enrichment_service_test.dart` | ~50 | Service deleted |
| `test/core/state/enrichment_requeue_test.dart` | ~80 | Requeue deleted |
| `test/integration/enrichment_merge_test.dart` | ~100 | Merge logic deleted |

### Edge Functions to Delete (~1,680 lines)

| Function | Lines | Reason |
|----------|-------|--------|
| `supabase/functions/enrich-species/` | ~551 | Replaced by queue worker |
| `supabase/functions/enrich-species-batch/` | ~586 | Replaced by queue worker |
| `supabase/functions/generate-species-art/` | ~223 | Absorbed into queue worker |
| `supabase/functions/generate-species-art-batch/` | ~270 | Absorbed into queue worker |
| `supabase/functions/admin-purge-enrichments/` | ~50 | Old table gone |

### Constants to Delete

| Constant | File | Reason |
|----------|------|--------|
| `kStartupEnrichmentCap` | `constants.dart` | No client-side enrichment |
| `kDeferredEnrichmentBatchSize` | `constants.dart` | No deferred drain |
| `kDeferredEnrichmentIntervalSeconds` | `constants.dart` | No deferred drain |

### Supabase Table to Drop

- `species_enrichment` — replaced by `species` table

### Supabase Migrations to Supersede

Migrations 002, 007, 012, 018 created/modified `species_enrichment`. New migration 019 replaces them with the `species` table.

---

## 7. New Code

### New Files

| File | Purpose | Est. Lines |
|------|---------|------------|
| `supabase/functions/process-enrichment-queue/index.ts` | Hourly worker: classify + generate art | ~350 |
| `supabase/migrations/019_species_table.sql` | Create `species` table, migrate data, drop old table | ~50 |
| `tool/seed_species_table.dart` | One-time: upload 32,752 rows to Supabase `species` table | ~80 |

### Modified Files

| File | Change | Est. Effort |
|------|--------|-------------|
| `lib/core/models/item_definition.dart` | Add `brawn`, `wit`, `speed`, `size`, `enrichedAt` to `FaunaDefinition` | Small |
| `lib/core/database/app_database.dart` | Add `LocalSpeciesTable`, migration v16→v17 (create + seed + migrate enrichment + drop old table) | Medium |
| `lib/core/species/species_repository.dart` | Rewrite interface for Drift backing | Medium |
| `lib/core/species/species_cache.dart` | Minor — same pattern, new backing | Small |
| `lib/core/species/species_service.dart` | Remove `_enrichments`, `_getPool()` merge | Medium |
| `lib/core/state/game_coordinator_provider.dart` | Remove enrichment wiring, add species sync | Large |
| `lib/core/state/persistence_consumer.dart` | Remove `SpeciesEnrichment` handling, add species sync | Medium |
| `lib/core/state/species_repository_provider.dart` | Simplify — no async asset loading | Small |
| `lib/features/discovery/providers/discovery_provider.dart` | Remove `enrichmentMapProvider` dep | Small |
| `lib/features/sync/services/supabase_persistence.dart` | `fetchEnrichments()` → `fetchSpeciesUpdates()` | Small |
| `lib/features/pack/widgets/species_card.dart` | Read from definition | Small |
| `lib/features/pack/widgets/species_card_modal.dart` | Remove enrichmentMap | Small |
| `lib/features/pack/widgets/species_card_stats.dart` | Read from definition | Small |
| `lib/features/pack/widgets/fauna_grid_tab.dart` | Remove enrichmentMapProvider | Small |
| `.github/workflows/deploy-supabase.yml` | Deploy `process-enrichment-queue`, remove old functions | Small |

### Net Impact

| Metric | Before | After | Delta |
|--------|--------|-------|-------|
| Client enrichment lines | ~2,000 | ~0 | **-2,000** |
| Client test lines (enrichment) | ~800 | ~0 | **-800** |
| Edge Function lines | ~1,680 (5 functions) | ~350 (1 function) | **-1,330** |
| Species data sources (client) | 2 (species.db + enrichment table) | 1 (LocalSpeciesTable) | **-1** |
| Dart models for species | 2 (FaunaDefinition + SpeciesEnrichment) | 1 (FaunaDefinition) | **-1** |
| Client enrichment providers | 3 | 0 | **-3** |
| **Total lines removed** | | | **~4,130** |
| **Total lines added** | | | **~480** |
| **Net reduction** | | | **~3,650** |

---

## 8. Execution Plan

### Phase 1: Server Infrastructure

| Step | Task | Depends On |
|------|------|------------|
| 1.1 | Write migration `019_species_table.sql` | — |
| 1.2 | Write `tool/seed_species_table.dart` (reads `species_data.json`, upserts to Supabase) | 1.1 |
| 1.3 | Apply migration to Supabase (via deploy workflow) | 1.1 |
| 1.4 | Run seed script to populate 32,752 rows | 1.3 |
| 1.5 | Verify: existing 438 enrichment rows migrated with classification + art data | 1.4 |

### Phase 2: Backend Worker

| Step | Task | Depends On |
|------|------|------------|
| 2.1 | Write `process-enrichment-queue/index.ts` Edge Function | 1.5 |
| 2.2 | Deploy Edge Function | 2.1 |
| 2.3 | Set up pg_cron hourly schedule | 2.2 |
| 2.4 | Verify: manually trigger, confirm it classifies + generates art | 2.3 |

### Phase 3: Client Model Changes

| Step | Task | Depends On |
|------|------|------------|
| 3.1 | Add `brawn`, `wit`, `speed`, `size`, `enrichedAt` to `FaunaDefinition` | — |
| 3.2 | Add `LocalSpeciesTable` to Drift, write migration v16→v17 | 3.1 |
| 3.3 | Implement first-run seeding from `species_data.json` in migration | 3.2 |
| 3.4 | Rewrite `SpeciesRepository` to use Drift | 3.2 |
| 3.5 | Update `SpeciesCache` to use new repository | 3.4 |
| 3.6 | Simplify `SpeciesService` — remove enrichment merge | 3.5 |
| 3.7 | Run `dart run build_runner build` to regenerate Drift code | 3.2 |
| 3.8 | Run test suite, fix compilation errors | 3.7 |

### Phase 4: Client Cleanup

| Step | Task | Depends On |
|------|------|------------|
| 4.1 | Delete `SpeciesEnrichment` model | 3.8 |
| 4.2 | Delete `EnrichmentRepository` | 4.1 |
| 4.3 | Delete `EnrichmentService` | 4.2 |
| 4.4 | Delete `enrichment_provider.dart` (3 providers) | 4.3 |
| 4.5 | Delete `enrichment_consumer.dart` | 4.4 |
| 4.6 | Refactor `game_coordinator_provider.dart` — remove enrichment wiring | 4.5 |
| 4.7 | Refactor `persistence_consumer.dart` | 4.6 |
| 4.8 | Add species sync to hydration flow | 4.7 |
| 4.9 | Update UI widgets (species_card, fauna_grid_tab, etc.) | 4.1 |
| 4.10 | Delete old test files | 4.9 |
| 4.11 | Write new tests (LocalSpeciesTable seeding, Drift queries, species sync) | 4.10 |
| 4.12 | Run full test suite | 4.11 |

### Phase 5: Deploy + Cleanup

| Step | Task | Depends On |
|------|------|------------|
| 5.1 | Delete `assets/species.db`, `tool/compile_species_db.dart` | 4.12 |
| 5.2 | Delete old Edge Functions (enrich-species, generate-species-art, etc.) | 4.12 |
| 5.3 | Update `deploy-supabase.yml` | 5.2 |
| 5.4 | Delete old enrichment constants from `constants.dart` | 4.12 |
| 5.5 | Drop `species_enrichment` table from Supabase | 5.3 |
| 5.6 | Update all `AGENTS.md` and `docs/` files | 5.5 |
| 5.7 | Final test suite run + `flutter analyze` | 5.6 |
| 5.8 | PR, merge, verify production | 5.7 |

---

## 9. Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| First-run seeding takes too long (>10s) | Bad first-launch UX | Benchmark on low-end device. If >5s, show progress indicator during onboarding. Drift batch inserts are fast — 32k rows should be 2-3s. |
| pg_cron not available on Supabase free tier | Can't schedule worker | Supabase Pro plan includes pg_cron. If needed, use GitHub Actions cron or external scheduler as fallback. |
| Gemini rate limit fills slowly (7 days for 438 species) | Existing species lack art for a week | Acceptable. Art is cosmetic — emoji fallback works. Could temporarily increase batch size or use paid tier. |
| Drift migration fails mid-seed | Corrupt database on app update | Wrap seeding in a transaction. On failure, user can clear app data and re-install (standard recovery). |
| `species_data.json` grows app size (6.1MB) | Already bundled today | No change — `species_data.json` is already in assets. We're deleting `species.db` (5.6MB), net savings. |
| Breaking change to `FaunaDefinition` | Many tests fail | Expected. Phase 4 handles test updates systematically. |

---

## 10. Success Criteria

- [ ] All 32,752 species in Supabase `species` table with IUCN data
- [ ] 438 previously-enriched species retain their classification + art data
- [ ] pg_cron worker classifies new species within 1 hour of discovery
- [ ] pg_cron worker generates art for classified species (respecting Gemini rate limits)
- [ ] Client has zero enrichment endpoint calls — no `enrich-species` invocations
- [ ] `SpeciesEnrichment` model deleted, `EnrichmentService` deleted
- [ ] `FaunaDefinition` has all enrichment fields, read from one Drift table
- [ ] `species.db` asset deleted, replaced by Drift-managed `LocalSpeciesTable`
- [ ] All existing tests pass (with updates), `flutter analyze` clean
- [ ] Net code reduction: ~3,650 lines
