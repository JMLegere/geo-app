# Implementation Plan

> Concrete, ordered steps to migrate from current state to `target-architecture.md`. Each step has a verification gate: tests pass + analysis clean before moving on.

---

## Current State

| Metric | Value |
|--------|-------|
| Features | 16 directories |
| Dart source files | ~205 (lib/) + 124 (test/) |
| Tests | 1,693 |
| `game_coordinator_provider.dart` | 1,832 lines, 63 imports |
| Analysis issues | 83 (info-level) |
| Dead code | ~420 lines (H3, legacy Voronoi) |

## Target State

| Metric | Value |
|--------|-------|
| Features | 14 directories (5 inputs, 1 domain, 5 experiences, 3 infrastructure) |
| Provider file | ~300 lines (decomposed into consumers) |
| Species in RAM | 0 MB (pre-compiled SQLite) |
| Fog rendering | Profiled, single winner, decoupled from cell boundaries |
| Observability | Full event coverage, session timelines, fleet health |
| Dead code | 0 |

---

## Invariant: Every Step is Green

After every numbered step:
1. `LD_LIBRARY_PATH=. flutter test` — all 1,693+ tests pass
2. `flutter analyze` — no new errors
3. Commit with descriptive message

No step should leave the codebase broken. If a step can't be completed atomically, break it smaller.

---

## Phase 0: Decompose `game_coordinator_provider.dart`

**Why first:** Every subsequent phase touches this file. It has 63 imports, 1,832 lines, and mixes 6 concerns: engine creation, hydration, persistence, enrichment, auth wiring, and profile sync. Decomposing it makes all future changes safer and more parallel.

**Current logical sections** (identified from the file):

| Section | Lines (approx) | Responsibility |
|---------|----------------|----------------|
| Provider setup + engine creation | 87–170 | Create GameEngine, wire resolvers, read providers |
| Callback chaining (6 callbacks) | 226–400 | Chain engine event emission with Riverpod mutations |
| GPS/location wiring | 400–430 | Map LocationService stream → core stream type |
| Hydration (SQLite + Supabase) | 430–770 | Load items, cells, profile, enrichments from DB |
| Auth state handling | 770–900 | React to auth changes, re-hydrate on identity change |
| Profile persistence (ref.listen) | 830–940 | Write-through profile to SQLite + write queue |
| `_persistItemDiscovery()` | 947–1010 | SQLite + write queue for new items |
| `_persistCellProperties()` | 1012–1065 | SQLite + write queue for cell properties |
| `_persistCellVisit()` | 1066–1145 | SQLite + write queue for cell visits |
| `_persistProfileState()` | 1145–1240 | SQLite + write queue for profile |
| `hydrateFromSupabase()` | 1241–1470 | Remote fetch + local cache update |
| Affix backfill | 1471–1690 | Roll/persist intrinsic affixes for enriched species |
| Enrichment requeue | 1691–1832 | Deferred enrichment drain timer |

### Steps

**0.1 — Extract persistence functions into `PersistenceConsumer`**

Create `lib/core/state/persistence_consumer.dart`.

Move these functions out of the provider closure:
- `_persistItemDiscovery()` (lines 947–1010)
- `_persistCellProperties()` (lines 1012–1065)
- `_persistCellVisit()` (lines 1066–1145)
- `_persistProfileState()` (lines 1145–1240)

Make `PersistenceConsumer` a plain class that takes repositories + write queue repo + supabase persistence as constructor params. The provider calls `consumer.persistItemDiscovery(...)` instead of the local function.

**Verify:** Tests pass. Provider is ~240 lines shorter. Persistence functions are independently testable.

**0.2 — Extract hydration logic into `HydrationService`**

Create `lib/core/state/hydration_service.dart`.

Move:
- `rehydrateData()` (lines 477–630)
- `hydrateFromSupabase()` (lines 1241–1470)
- `hydrateAndStart()` orchestration (lines 633–766) — becomes `HydrationService.run()` that takes callbacks for `inventoryProvider.loadItems()`, `playerProvider.setState()`, etc.

**Verify:** Tests pass. Hydration is testable without a full ProviderContainer.

**0.3 — Extract enrichment wiring into `EnrichmentConsumer`**

Create `lib/core/state/enrichment_consumer.dart`.

Move:
- `enrichmentHook()` (lines 180–208)
- `_rollAndPersistIntrinsicAffix()` (lines 1471–1580)
- `_backfillIntrinsicAffixes()` (lines 1581–1630)
- `_backfillAllMissingAffixes()` (lines 1628–1690)
- `_requeueUnenrichedSpecies()` (lines 1691–1832)

**Verify:** Tests pass. Enrichment logic is independently testable.

**0.4 — Slim the provider**

What remains in `game_coordinator_provider.dart`:
- Read providers, create GameEngine
- Wire resolvers and services
- Chain callbacks (delegating to PersistenceConsumer/EnrichmentConsumer)
- Auth state listener (delegating to HydrationService)
- Profile ref.listen (delegating to PersistenceConsumer)
- Lifecycle/dispose

**Target: ~400 lines.** Down from 1,832.

**Verify:** All tests pass. `flutter analyze` clean. Commit.

---

## Phase A: Dead Code + Feature Reorganization

**Why next:** Stabilize the directory structure before doing any functional changes. Every import path is settled after this phase. Phases B/C/D don't have to deal with moves.

### A.1 — Delete dead code

| File | Action |
|------|--------|
| `lib/core/cells/h3_cell_service.dart` | Delete |
| `lib/core/cells/voronoi_cell_service.dart` | Delete |
| `test/core/cells/voronoi_cell_service_test.dart` (if exists) | Delete |
| `test/core/cells/h3_cell_service_test.dart` (if exists) | Delete |
| Legacy Voronoi constants in `constants.dart` (lines 94–114) | Delete |
| Remove H3/Voronoi references in `cell_service_provider.dart` | Clean up dead switch branches |

**Verify:** Tests pass. Analyze clean. Commit: `🔥 remove: delete unused H3 and legacy Voronoi cell services`

### A.2 — Fold `enrichment/` → `sync/`

Move `features/enrichment/providers/enrichment_provider.dart` → `features/sync/providers/enrichment_provider.dart`. Update all imports (2 files import it: `game_coordinator_provider.dart` and `discovery_provider.dart`).

Delete empty `features/enrichment/` directory.

**Verify:** Tests pass. Commit: `♻️ refactor: fold enrichment provider into sync feature`

### A.3 — Fold `navigation/` → `shared/`

Move `features/navigation/screens/tab_shell.dart` → `shared/widgets/tab_shell.dart` (or `lib/tab_shell.dart`). Move `features/navigation/providers/tab_index_provider.dart` → `core/state/tab_index_provider.dart`.

Update imports in `main.dart` and anywhere else that references navigation/.

Delete empty `features/navigation/` directory.

**Verify:** Tests pass. Commit: `♻️ refactor: move TabShell to shared, tab_index to core/state`

### A.4 — Create `features/world/`

Create directory. Move into it:
- `features/biome/` → `features/world/services/` + `features/world/models/` + `features/world/providers/`
- `core/cells/cell_property_resolver.dart` → `features/world/services/`
- `core/cells/event_resolver.dart` → `features/world/services/`

Update all imports. Tests that import these files need path updates.

**Verify:** Tests pass. Commit: `♻️ refactor: create world feature from biome, cell properties`

### A.5 — Create `features/calendar/`

Create directory. Move into it:
- `features/seasonal/` → `features/calendar/services/` + `features/calendar/providers/`

Rename `SeasonService` → keep name (it's fine). The feature grows later with time-of-day.

Update all imports.

**Verify:** Tests pass. Commit: `♻️ refactor: create calendar feature from seasonal`

### A.6 — Create `features/items/`

Create directory. Extract into it:
- `core/state/inventory_provider.dart` → `features/items/providers/items_provider.dart`
- Rename `InventoryNotifier` → `ItemsNotifier`, `InventoryState` → `ItemsState`, `inventoryProvider` → `itemsProvider`
- Item creation logic from `game_coordinator_provider.dart` → `features/items/services/item_factory.dart`
- `core/species/stats_service.dart` → `features/items/services/stats_service.dart` (stat rolling is item creation, not species)

Value objects (`ItemDefinition`, `ItemInstance`, `Affix`, etc.) stay in `core/models/`.

Update all imports. This touches many files — `inventoryProvider` is referenced in ~14 files.

**Verify:** Tests pass. Commit: `♻️ refactor: create items feature, extract inventory and item creation`

### A.7 — Merge `core/game/` → `core/engine/`

Move `core/game/game_coordinator.dart` → `core/engine/game_coordinator.dart`.

Delete empty `core/game/` directory. Update all imports.

**Verify:** Tests pass. Commit: `♻️ refactor: merge core/game into core/engine`

### A.8 — Update documentation

Update all AGENTS.md files that reference moved files/features:
- Root AGENTS.md: feature list, directory structure
- `lib/core/AGENTS.md`: cells/ no longer has property resolver
- `lib/core/cells/AGENTS.md`: remove property resolver and event resolver docs
- `lib/features/map/AGENTS.md`: update imports if any changed
- `test/AGENTS.md`: update any fixture paths
- Delete `lib/features/navigation/AGENTS.md`
- Delete `lib/features/biome/AGENTS.md` (if exists)
- Create `lib/features/world/AGENTS.md`
- Create `lib/features/calendar/AGENTS.md`
- Create `lib/features/items/AGENTS.md`
- Update `docs/state.md`: provider renames
- Update `docs/architecture.md`: feature list

**Verify:** Docs consistent. Commit: `📝 docs: update AGENTS.md and docs for new feature structure`

---

## Phase B: Species SQLite

**Dependency:** Phase A complete (imports stable).

### B.1 — Build script

Create `tool/compile_species_db.dart`:
- Reads `assets/species_data.json`
- Creates SQLite database at `assets/species.db`
- Creates `species_definitions` table with: `scientific_name` (PK), `common_name`, `taxonomic_class`, `iucn_status`, `habitats_json`, `continents_json`
- Inserts all 32,752 records
- Creates index on `iucn_status`

Run manually: `dart run tool/compile_species_db.dart`

**Verify:** `assets/species.db` created, correct row count. Commit: `🔧 chore: add species database build script`

### B.2 — SpeciesRepository

Create `lib/core/species/species_repository.dart`:
- Opens `assets/species.db` as read-only
- `getCandidates({habitats, continent, season})` → `Future<List<FaunaDefinition>>`
- `getByScientificName(String)` → `Future<FaunaDefinition?>`
- `count()` → `Future<int>`
- Platform-aware: native opens file, web loads via rootBundle into WASM SQLite

Create `lib/core/species/species_cache.dart`:
- LRU cache wrapping SpeciesRepository
- Max 2,000 FaunaDefinition objects
- Cache key: query parameters hash

**Verify:** Unit tests for repository and cache. Commit: `✨ feat(species): add SQLite-backed SpeciesRepository with LRU cache`

### B.3 — Rewire LootTable

Current: `LootTable` takes `List<FaunaDefinition>` synchronously, builds weighted table, rolls.

New: `LootTable.fromCandidates()` still takes a list synchronously. The async work happens BEFORE the roll — `SpeciesRepository.getCandidates()` fetches the candidate list, then LootTable is constructed from it.

```dart
// Before (sync, all 33K in memory)
final table = LootTable<FaunaDefinition>();
for (final species in allSpecies) { table.add(species, species.weight); }

// After (async fetch, sync roll)
final candidates = await speciesRepo.getCandidates(habitats: h, continent: c, season: s);
final table = LootTable<FaunaDefinition>();
for (final species in candidates) { table.add(species, species.weight); }
```

The LootTable API doesn't change. The call site becomes async at the point of fetching candidates.

Update `SpeciesService.getSpeciesForCell()` to use `SpeciesRepository` instead of in-memory list.

**Verify:** Species encounter tests pass with SQLite backend. Commit: `♻️ refactor(species): wire LootTable to SpeciesRepository`

### B.4 — Delete old species loading

- Delete `SpeciesDataLoader` class
- Delete `speciesDataProvider` (FutureProvider that held all species in memory)
- Create `speciesRepositoryProvider` (Provider that holds SpeciesRepository)
- Update `speciesServiceProvider` to use repository instead of data provider
- Update test fixtures: tests that used `kSpeciesFixtureJson` may need a test SQLite DB or continue using in-memory list for unit tests

**Verify:** All tests pass. No `SpeciesDataLoader` references remain. Commit: `🔥 remove: delete in-memory species loading, fully SQLite-backed`

### B.5 — CI integration

Add to `.github/workflows/ci.yml`:
```yaml
- name: Compile species database
  run: dart run tool/compile_species_db.dart
```

Add `assets/species.db` to `.gitignore` (generated artifact, not committed).

**Verify:** CI builds species.db before tests. Commit: `🔧 chore: add species DB compilation to CI pipeline`

---

## Phase C: Fog Rendering

**Dependency:** Phase 0 complete (provider decomposed). Independent of B.

### C.1 — Profile existing renderers

Add timing instrumentation to:
- `FogCanvasPainter.paint()` — measure per-frame cost
- `FogGeoJsonBuilder` — measure per-update cost

Test scenarios:
- 50 explored cells (new player)
- 500 explored cells (week of play)
- 2,000 explored cells (month of play)

Record P50 and P95 frame times for each.

**Verify:** Profiling data collected. Document results in a comment on the PR.

### C.2 — Pick winner, delete loser

Based on profiling:
- If either meets the 4ms budget at 2,000 cells → keep it, delete the other
- If neither meets budget → keep the better one as fallback, build ImageSource overlay in C.3

**Verify:** One fog renderer remains. Tests pass. Commit: `🚀 perf(fog): pick [winner], delete [loser]`

### C.3 — Separate fog fill from cell boundaries (if not already)

Ensure fog opacity (fill) and cell edges (lines) are independent layers:
- Fog layer: opacity overlay (whichever renderer won)
- Cell boundary layer: GeoJSON LineString features for visible cells only
- Fog updates on state change, not camera pan
- Cell boundaries update on camera pan (debounced 200ms)

**Verify:** Visual correctness on web. Frame times within budget. Commit: `♻️ refactor(map): decouple fog fill from cell boundaries`

---

## Phase D: Observability Completion

**Dependency:** Phase 0 complete (provider decomposed). Independent of C.
**Note:** Sequence D after B (both touch the game loop), or accept merge conflicts.

### D.1 — Complete event emission

Audit all `GameCoordinator` callbacks. Ensure every state change emits a `GameEvent`:
- `onCellVisited` ✅ (already emits `cell_visited`)
- `onItemDiscovered` ✅ (already emits `species_discovered`)
- `onGpsErrorChanged` ✅ (already emits `gps_error_changed`)
- `onCellPropertiesResolved` ✅ (already emits `cell_properties_resolved`)
- `onExplorationDisabledChanged` ✅ (already emits)
- Missing: `session_started`, `hydration_complete`, `auth_restored`, `seed_rotated`

Add missing system events from HydrationService and auth handler (extracted in Phase 0).

**Verify:** Event catalog in `engine-architecture.md` matches implementation. Commit: `✨ feat(observability): complete event emission coverage`

### D.2 — EventSink batch flush

Create `lib/core/engine/event_sink.dart` (or complete existing stub):
- Accumulates GameEvents in memory (ring buffer, 10K cap)
- Flushes to Supabase `app_events` table every 30 seconds
- Flushes on `AppBackgrounded` engine input
- Accepts `EventFlusher` callback (not Supabase directly — keeps core/ clean)
- Silent failure — never throws

Wire in `gameCoordinatorProvider`: inject `EventSink` into `GameEngine`.

**Verify:** Events appear in `app_events` table. Commit: `✨ feat(observability): add EventSink with 30s batch flush`

### D.3 — Local event table

Add Drift migration (v13 → v14): `LocalAppEventsTable`
- `id` (text PK, UUID)
- `sessionId` (text)
- `userId` (text nullable)
- `category` (text)
- `event` (text)
- `dataJson` (text)
- `createdAt` (datetime)

EventSink writes to local SQLite AND flushes to Supabase. Local table has 10K row cap (delete oldest on overflow).

**Verify:** Migration runs. Events written locally. Commit: `✨ feat(observability): add local app_events SQLite table`

### D.4 — Performance timing

Add `Stopwatch` instrumentation to:
- Hydration (`hydration_complete` with `duration_ms`)
- Species roll (`species_roll` with `duration_ms`, `candidate_count`)
- Fog computation (when relevant — only state transitions)
- SQLite operations (via repository wrapper or interceptor)

Emit as `performance` category events.

**Verify:** Performance events visible in `app_events`. Commit: `✨ feat(observability): add performance timing events`

---

## Phase Order + Dependencies

```
Phase 0 (decompose provider)          ~6 hrs
    ↓
Phase A (reorganize features)          ~12 hrs
    ↓
    ├── Phase B (species SQLite)       ~12 hrs
    ├── Phase C (fog rendering)        ~6-10 hrs
    └── Phase D (observability)        ~8 hrs
```

**Phase 0 → A** is sequential (A moves files that 0 just decomposed).
**B, C, D** are independent of each other after A. But B and D both touch the game loop — do B first, then D, to avoid merge conflicts. C is fully independent.

**Recommended serial order:** 0 → A → B → C → D

**Total estimate:** ~44–48 hours of focused work.

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Provider decomposition breaks callback chaining | Medium | High — game loop stops | Each extraction is one commit. Revert if tests fail. |
| Import path changes in Phase A cascade unexpectedly | High | Medium — many files to update | IDE refactoring tools. One move per commit. |
| `inventoryProvider` rename (A.6) breaks 14+ files | High | Medium — many files touched | Use IDE rename refactoring. Run tests after each file. |
| Species SQLite on web doesn't work with WASM | Medium | Low — web is dev/test only | Keep JSON loader as web fallback if needed. |
| LootTable async migration (B.3) is more complex than scoped | Medium | Medium — touches discovery pipeline | Pre-fetch candidates in SpeciesService, LootTable stays sync. |
| Fog profiling shows both renderers are fine | Low | Positive — skip C.3 | Pick simpler one, delete the other, move on. |
| Phase D event volume overwhelms buffer | Low | Low — cap at 10K | Only emit state TRANSITIONS, not recomputations. |

---

## Definition of Done

Each phase is done when:
1. All tests pass (`LD_LIBRARY_PATH=. flutter test`)
2. Analysis clean (`flutter analyze` — no new errors beyond existing 83 info-level)
3. All commits pushed
4. AGENTS.md files updated for any moved/renamed/created modules
5. `docs/target-architecture.md` Phase section marked with completion status
