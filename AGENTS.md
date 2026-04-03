# Agent Guidance — EarthNova (working title)

> iNaturalist × Stardew Valley × Pokémon Go. Explore the real world via GPS, reveal fog-of-war, discover 33k real IUCN species, build a sanctuary. Working title: EarthNova.

## Quick Reference

| Key | Value |
|-----|-------|
| Working Title | EarthNova |
| Framework | Flutter 3.41.3 (Dart) |
| State | Riverpod 3.2.1 — `Notifier` pattern (NOT `StateNotifier`) |
| Map | `maplibre` by josxha v0.1.2 (NOT `maplibre_gl`) |
| Persistence | Drift 2.14.0 (SQLite) — local cache + write queue. Supabase = source of truth |
| Geo types | `geobase` — `Geographic(lat:, lon:)` (NOT `LatLng`) |
| Cell system | Voronoi (`LazyVoronoiCellService`, no fallbacks) |
| Species data | 32,752 real IUCN records in Drift-managed `LocalSpeciesTable` (seeded from `assets/species_data.json`) |
| Tests | 445 passing, `flutter_test` only (no mockito/mocktail) |
| Analysis | info-level issues only (0 errors, 0 warnings) |
| Backend | Supabase (conditional) — `SupabaseAuthService` + `SupabasePersistence` when credentials supplied, `MockAuthService` fallback |
| Production | https://geo-app-production-47b0.up.railway.app — Railway, deploys from `main` |

**Run commands:**
```bash
# Flutter via mise
eval "$(~/.local/bin/mise activate bash)"

# Tests (H3 FFI needs LD_LIBRARY_PATH)
LD_LIBRARY_PATH=. flutter test

# Analysis
flutter analyze
```

---

## Architecture Overview

> **Target architecture:** See `docs/target-architecture.md` for the definitive design doc (5 pillars, hardware budgets, migration phases).

```
lib/
├── main.dart        # ProviderScope → EarthNovaApp → TabShell
├── engine/          # Pure Dart game loop + event stream (GameEngine, EngineRunner)
├── domain/          # Game rules: cells, fog, species, items, seed, world
├── data/            # Drift schema, repos, sync, location services
├── models/          # Immutable value objects
├── providers/       # 20 Riverpod providers
├── screens/         # 8 screens (map, pack, sanctuary, settings, auth, etc.)
├── widgets/         # Map rendering, fog overlay, UI components
└── shared/          # Constants, theme, design tokens
```

**See also:** `lib/AGENTS.md`, `lib/data/AGENTS.md`, `lib/data/sync/AGENTS.md`, `lib/domain/fog/AGENTS.md`, `lib/domain/seed/AGENTS.md`, `lib/models/AGENTS.md`, `test/AGENTS.md` for subsystem-specific guidance.

### Codebase Stats

| Metric | Value |
|--------|-------|
| Dart source files | ~130 (lib/) + ~34 (test/) |
| Total lines | ~23,400 |
| Largest file | `database.g.dart` (generated) |
| Providers | 20 Riverpod providers |
| Screens | 8 |

---

## Core Design Decisions

These are **locked in** — do not revisit without explicit instruction.

1. **Computed fog state** — FogState is derived on-demand from player position + visit history, like Civilization fog-of-war. Only `visitedCellIds` are persisted. Never store per-cell fog state.

2. **Deterministic species encounters** — Species for a cell are seeded by `SHA-256(dailySeed + "_" + cellId)`. Same cell + same day = same species. Different day = different species. The daily seed rotates at midnight GMT via server RPC (`ensure_daily_seed()`). Offline fallback: static seed (`offline_no_rotation`) — species don't rotate but encounters still work. Stale seed (>24h server seed) pauses discoveries until refreshed.

3. **Voronoi cells** — The cell system uses Voronoi tessellation exclusively (`LazyVoronoiCellService`). H3CellService has been deleted. `CellService` remains an abstract interface.

4. **IUCN rarity = loot weights** — 6 IUCN statuses map to 3^x weights: Least Concern (243), Near Threatened (81), Vulnerable (27), Endangered (9), Critically Endangered (3), Extinct (1).

5. **Server-authoritative** — Supabase is the source of truth. SQLite is a local cache and offline write queue. Client can roll encounters offline using cached daily seed (24h grace); server re-derives and validates on reconnect. Rejected actions roll back locally.

6. **Riverpod v3 Notifier** — All mutable state uses `NotifierProvider<T, S>` (not `StateNotifier`, not `ChangeNotifier`). Immutable state classes with `copyWith()`.

7. **7 habitats** — Forest, Plains, Freshwater, Saltwater, Swamp, Mountain, Desert.

8. **2 seasons** — Summer (May–Oct), Winter (Nov–Apr). 80% of species are year-round, 10% summer-only, 10% winter-only.

9. **Conditional Supabase** — When `SUPABASE_URL` and `SUPABASE_ANON_KEY` are supplied via `--dart-define`, the app uses `SupabaseAuthService` (with anonymous sign-in) and `SupabasePersistence` (write-through to Supabase tables). Without credentials, `MockAuthService` is used and sync is disabled.

10. **Backend-driven enrichment** — Unified enrichment pipeline runs server-side via `process-enrichment-queue` Edge Function (1-minute pg_cron). Processes species AND items per tick. Species: classify → icon prompt → art prompt → icon image → art image (2-stage LLM → image pipeline with per-field version stamps). Items: denormalizes species fields, icon/art URLs, cell properties, and location hierarchy onto instances. Priority: count fields needing work (null or stale enrichver), process closest-to-done first. No client-side enrichment.

11. **GBA rendering principle** — Never do work that doesn't change a pixel visible this frame. Lazy tabs, viewport-only fog, eager-resolve/lazy-render for districts, visibility-gated animations. The GBA ran Pokemon at 60fps on 16MHz/256KB by never computing invisible work. We have 10,000x the hardware — the problem is always wasted work, not the platform. See `docs/target-architecture.md` > Rendering Principles.

---

## Product Architecture (Design Jam Decisions — 2026-03-06, updated 2026-03-06 Jam 2)

These are the target architecture decisions from two design jams. They describe WHERE the product is going. **Phases 1–4 are COMPLETE** — item model, GameCoordinator, server-authoritative persistence, and daily seed are all live. Remaining work: breeding/bundles (Phase 5+).

**This is the canonical mental model. If something contradicts this section, ALWAYS flag it to the user for resolution. Never silently update — the user decides what's true.**

### Wall 1: Everything Is an Item

- **PoE / CryptoKitty model, NOT Stardew stacking.** Every discovered item is a unique instance with randomly-rolled affixes (prefix/suffix). Items never stack. Two Red Foxes have different stats.
- **7 item categories:** Fauna, Flora, Mineral, Fossil, Artifact, Food, Orb. All share the `ItemDefinition` → `ItemInstance` pattern.
- **Rarity gates affix depth:** LC = 0-1 affixes, NT = 1-2, VU = 2-3, EN = 3-4, CR = 4-5, EX = 5+.
- **Breeding:** Two instances → offspring with inherited/combined traits. CryptoKitty-style trait inheritance. Server-validated.
- **Collections are bundles:** Stardew community center model. Bundles group items with completion rewards. Museum = permanent donation bundle. NPC requests = consumable bundles. Achievements track milestones ("discover 100 forest fauna").
- **Full spec:** `docs/item-system-design.md`, `docs/design-jam-2-item-expansion.md`

### Wall 1b: Fauna Taxonomy (3-Tier)

- **5 Animal Types:** Mammal, Bird, Fish, Reptile, Bug. Deterministic from IUCN `taxonomicClass` (Mammalia→Mammal, Aves→Bird, etc.).
- **35 Animal Classes:** Game-designed sub-classifications. Canonical list:
  - **Bird (7):** Bird of Prey, Game Bird, Nightbird, Parrot, Songbird, Waterfowl, Woodpecker
  - **Bug (9):** Bee, Beetle, Butterfly, Cicada, Dragonfly, Land Mollusk, Locust, Scorpion, Spider
  - **Fish (6):** Cartilaginous Fish, Cephalopod, Clams/Urchins & Crustaceans, Jawless Fish, Lobe-finned Fish, Ray-finned Fish
  - **Mammal (8):** Bat, Carnivore, Hare, Herbivore, Primate, Rodent, Sea Mammal, Shrew
  - **Reptile (5):** Amphibian, Crocodile, Lizard, Snake, Turtle
- **Hierarchy:** Fauna → Type → Class → Species. E.g., Fauna → Mammal → Carnivore → Red Fox.
- **Animal Class is AI-determined** on first global discovery. Canonical forever.

### Wall 1c: Food & Orb Economy

- **Food (7 subtypes):** food-critter, food-fish, food-fruit, food-grub, food-nectar, food-seed, food-veg. Found during exploration. Fed to sanctuary animals.
- **Food preference per species:** AI-determined on first discovery. Maps species to one of 7 food types based on real diet.
- **Orbs = primary game currency.** 3 dimensions, ~46 types:
  - **Habitat orbs (7):** orb-forest, orb-plains, orb-freshwater, orb-saltwater, orb-swamp, orb-mountain, orb-desert
  - **Class orbs (~35):** orb-carnivore, orb-songbird, orb-rodent, orb-crocodile, etc. (one per animal class)
  - **Climate orbs (4):** orb-tropic, orb-temperate, orb-boreal, orb-frigid
- **Feeding produces 3 orbs:** Feed animal → 1 habitat orb + 1 class orb + 1 climate orb.
- **Orb spend:** TBD. Candidates: breeding, lures, cosmetics, NPC shops.
- **Orbs are NOT loot drops** — only produced via sanctuary feeding.

### Wall 1d: Climate Zones

- **4 climate zones:** Tropic (0°–23.5°), Temperate (23.5°–55°), Boreal (55°–66.5°), Frigid (66.5°–90°).
- **Derived from real latitude:** `abs(playerLat)` → climate zone. No API needed.
- **Climate drives spawning:** Tropical species only near equator. Boreal species only at high latitudes. Real geography = gameplay.
- **Climate on species:** AI-enriched on first discovery, or inferrable from real-world range.

### Wall 1e: Lazy AI Enrichment

- **Trigger:** First global discovery of any item. Background AI job fires automatically.
- **Phase 1c IMPLEMENTED:** Classification pipeline (animalClass, foodPreference, climate) via Gemini Flash. Art and stats enrichment deferred to later phase.
- **Fauna enrichment:** animalClass, foodPreference, stats (brawn+wit+speed=90), watercolor art.
- **All categories enriched:** Flora, Mineral, Fossil, Artifact also get category-specific AI enrichment + watercolor art. Food and Orbs are predefined — no enrichment needed.
- **AI is canonical for facts.** Stats, classification, food preference — AI sets, locked forever. No crowdsourcing for factual attributes.
- **Art is crowd-canonical.** AI watercolor is the default. First 50 owners can upload art. Art locks when 51% of instances select same art at daily reset. **Moderation: free AI screening only — automatically reject inappropriate uploads. No community reports.**
- **Architecture:** `process-enrichment-queue` Edge Function (hourly pg_cron) → Gemini Flash API (classification + art) → writes to `species` Supabase table → client reads enrichment fields from `LocalSpeciesTable` (Drift). No client-side enrichment service.
- **Non-blocking:** Enrichment runs in background. Gameplay continues with just IUCN data. Enrichment adds richness over time.
- **Full spec:** `docs/design-jam-2-item-expansion.md`

### Wall 1f: Species Identity

- **Stats:** AI-canonical. Brawn + Wit + Speed = 90. Based on real-world characteristics (cheetah=fast, elephant=strong, octopus=smart).
- **Size:** AI-canonical. 9 categories: fine, diminutive, tiny, small, medium, large, huge, gargantuan, colossal. Enriched per species.
- **Weight:** Instance-level. Random integer grams within the species' size band, seeded by instance UUID. Deterministic via SHA-256 (`"weight:$instanceSeed"`).
- **Color:** RGB derived from stats. R=brawn/90×255, G=speed/90×255, B=wit/90×255.
- **Instance variance:** All instances get canonical base ±30% SHA-256 variance. No special first-50 handling. Weight varies within size band per instance.
- **Art:** Crowd-canonical. AI default + player uploads. 51% lock at daily reset. Moderation via free AI screening only (no community reports).
- **Badges:** First Discovery (★), Pioneer (#2–50), Artist (winning art), Beta (beta period). Instance-level, stack.
- **Species Card UI:** Frame (rarity+badges) → Art → Badge icons → Stats (RGB bars) → Color identity → Name plate.
- **Replaces:** `docs/species-community-system.md` stats sections. Art/badges/card UI unchanged.

### Wall 2: GameCoordinator

- **The map is a renderer, not an orchestrator.** Game logic lives in `GameCoordinator`, a pure Dart service above the UI.
- **Runs forever** — created at ProviderScope level, never stops on tab switch. Map screen reads its state and renders.
- **Currently owns:** GPS subscription, game loop tick (~10 Hz), fog computation, discovery processing.
- **Will own (Phase 3+):** write queue, daily seed cache, streaks.
- **Does NOT own:** map rendering, camera, widget state, toast UI, RubberBand interpolation.
- **Output:** Individual callbacks (onPlayerLocationUpdate, onGpsErrorChanged, onCellVisited, onItemDiscovered) wired by gameCoordinatorProvider. Discovery events → UI subscribes for toasts.
- **Target directory:** `lib/core/game/`
- **IMPLEMENTED** — `GameEngine` at `lib/engine/game_engine.dart` with `EngineRunner` orchestration and `engineProvider` at `lib/providers/engine_provider.dart`.

### Wall 3: Server-Authoritative with Offline Resilience

- **Supabase is source of truth.** SQLite is local cache + offline write queue. NOT offline-first.
- **Online flow:** Player enters cell → server rolls encounter → writes to DB → client caches result.
- **Offline flow:** Client rolls encounter using cached daily seed → UI shows optimistic result → action queued → flushed on reconnect → server re-derives and validates → match = confirmed, mismatch = rolled back.
- **Daily seed:** Server generates per calendar day (midnight GMT). Client fetches on app open, caches 24h. Deterministic: `hash(seed + cellId + definitionId)` → same result. Stale seed (>24h offline) → discoveries pause.
- **Write queue:** Temporary outbox in SQLite. NOT event sourcing — queue entries deleted after server confirms. Entries: `{ type, payload, timestamp, status: pending|confirmed|rejected }`.
- **Read-only offline:** Browse collection, sanctuary, cached map tiles. Fog animates visually but doesn't persist until server confirms.
- **Full spec:** `docs/ideal-architecture.md`

### Migration Phases

| Phase | Status | Change | Enables |
|-------|--------|--------|---------|
| 1 | **COMPLETE** | Item model (sealed classes, instances, affixes) | Everything downstream |
| 1b | **COMPLETE** | Item expansion (7 categories, taxonomy, food, orbs, climate) | Economy, sanctuary loop |
| 1c | **COMPLETE** | Lazy AI enrichment pipeline (classification only — art deferred) | Species identity (partial) |
| 2 | **COMPLETE** | GameCoordinator (extract from map_screen) | Tab-independent game loop |
| 3 | **COMPLETE** | Server-authoritative persistence (write queue, rollback, Edge Function validation) | Online validation, anti-cheat |
| 4 | **COMPLETE** | Daily seed system (DailySeedService, stale guard, validate-encounter) | Deterministic daily encounters, social sharing |
| 5+ | Not started | Breeding, bundles, museum, social | Endgame features |

**Note:** Lazy AI enrichment (Phase 1c) requires Supabase Edge Functions but doesn't depend on GameCoordinator or write queue.

---

## Feature Template

Features follow a consistent sub-directory pattern, with variation by feature complexity:

### Full feature (auth, achievements, sync)
```
features/X/
├── models/        # Data classes, enums, state objects
├── providers/     # Riverpod NotifierProviders
├── services/      # Pure logic (no Riverpod dependency)
├── screens/       # Full-page widgets (ConsumerWidget or ConsumerStatefulWidget)
└── widgets/       # Reusable UI components
```

### Minimal feature (biome, location, caretaking)
```
features/X/
├── models/        # (optional)
├── providers/     # (optional — biome/location have none)
└── services/      # Pure logic only
```

### Naming conventions
- Provider file: `<feature>_provider.dart`
- Provider variable: `<feature>Provider` (e.g., `achievementProvider`)
- Notification provider: `<feature>NotificationProvider` (for toast/overlay features)
- Service: `<Feature>Service` (pure Dart class, no Riverpod dependency)
- State class: `<Feature>State` (immutable, with `copyWith()`)
- Screen: `<Feature>Screen` (ConsumerWidget or ConsumerStatefulWidget)

### Provider patterns used

| Pattern | When | Example |
|---------|------|---------|
| `NotifierProvider<T, S>` | Mutable state | `achievementProvider`, `authProvider`, `fogProvider` |
| `Provider<T>` | Stateless service / infrastructure | `seasonServiceProvider`, `syncServiceProvider` |
| Dual notifiers | State + notification queue | achievements, discovery |
| `ref.listen()` | React to other provider changes | pack → inventoryProvider, sanctuary → playerProvider |
| `ref.read()` in methods | One-shot mutations from event handlers | caretaking → playerProvider (bidirectional sync) |

### Service injection

Services are **pure Dart classes** with no Riverpod dependency. They receive dependencies via constructor or method parameters:

```dart
// CORRECT: Pure service, testable without Riverpod
class AchievementService {
  List<Achievement> evaluate(AchievementContext ctx) { ... }
}

// INCORRECT: Service coupled to Riverpod
class AchievementService {
  final Ref ref;  // Don't do this
}
```

**Exception:** `SyncService` reads `authProvider` because it needs auth state for cloud sync.

**Exception:** `gameCoordinatorProvider` imports from features/ because it is the central orchestrator wiring layer that bridges core GameCoordinator with feature-layer services (LocationService, DiscoveryService).

---

## State Management

### Riverpod v3 Pattern

All providers use the Notifier pattern (Riverpod 3.x):

```dart
final fogProvider = NotifierProvider<FogNotifier, Map<String, FogState>>(() => FogNotifier());

class FogNotifier extends Notifier<Map<String, FogState>> {
  @override
  Map<String, FogState> build() => {};
  
  void updateCellFogState(String cellId, FogState state) {
    state = {...state, cellId: state};
  }
}
```

**Key rules:**
- `build()` returns the initial state
- `state = newState` triggers listeners (immutable replacement)
- Use `ref.watch()` in `build()` for reactive dependencies
- Use `ref.read()` in methods for one-shot reads
- Guard async gaps with `ref.mounted` check

### State synchronization patterns

| Pattern | Use case | Example |
|---------|----------|---------|
| `ref.listen()` in `build()` | React to changes without resetting state | Pack filters persist when collection changes |
| `ref.read(...notifier)` in method | Bidirectional sync between providers | Caretaking syncs streak with PlayerProvider |
| Stream subscription + `ref.onDispose()` | External event source | LocationNotifier subscribes to GPS stream |

---

## Persistence

### Drift (SQLite) ORM

6 tables: `LocalCellProgressTable`, `LocalItemInstanceTable`, `LocalPlayerProfileTable`, `LocalSpeciesTable`, `LocalWriteQueueTable`, `LocalCellPropertiesTable`. Plus 4 hierarchy tables: `LocalCountryTable`, `LocalStateTable`, `LocalCityTable`, `LocalDistrictTable`. Schema v24.

`LocalItemInstanceTable` has 32 denormalized enrichment columns (15 data + 17 per-field version stamps). `LocalSpeciesTable` has 11 per-field version stamps. Each enrichable field has a companion `_enrichver` column tracking the pipeline commit that produced the value.

**Critical Drift conventions:**
- `copyWith` uses `Value<T>` wrappers — use `Value(x)` for set, `Value.absent()` for skip
- Tables with `autoIncrement()` must NOT override `primaryKey`
- FogState stored as string in DB (e.g., `'undetected'`)
- Use `Companion.insert()` for auto-increment tables
- Database uses `LazyDatabase` for deferred file opening
- Run `flutter pub run build_runner build` after schema changes

### Repository pattern

Each repo wraps `AppDatabase` and provides domain-specific methods:
- `ProfileRepository` — player profile CRUD
- `CellProgressRepository` — per-cell fog state + distance + visits
- `ItemInstanceRepository` — item instances (full CRUD with Drift domain conversion)
### Sync architecture

```
Local write (SQLite) ──→ SupabasePersistence.upsert*() ──→ Supabase table
                         (write-through when configured)
```

When `SUPABASE_URL` is empty, `SupabasePersistence` is null and the app runs in offline-only mode. The `supabasePersistenceProvider` returns null, and the sync screen shows "Supabase not configured".

---

## Test Conventions

### Framework

`flutter_test` only. No mockito, no mocktail — all mocks are hand-written.

### Structure

Tests mirror `lib/` exactly: `test/domain/cells/cell_cache_test.dart` tests `lib/domain/cells/cell_cache.dart`.

Additional directories:
- `test/fixtures/` — shared test data (`kSpeciesFixtureJson`: 50 species)
- `test/integration/` — 5 offline workflow suites (full persistence round-trips)

### Patterns

| Pattern | Usage |
|---------|-------|
| `setUp()` / `tearDown()` | Fresh instance per test |
| `ProviderContainer` + `addTearDown(container.dispose)` | Riverpod provider tests |
| `testWidgets()` + `MaterialApp` wrapper | Widget tests |
| `NativeDatabase.memory()` | In-memory Drift for integration tests |
| `driftRuntimeOptions.dontWarnAboutMultipleDatabases = true` | Required in `setUpAll()` for Drift tests |
| Hand-written `Mock<Interface>` | Implements interface with deterministic behavior |
| `make<ClassName>()` factory functions | Inline builders with sensible defaults |
| `collectEvents()` helpers | Capture stream events during test |

### Naming

- Test: `test('verb + condition + expected outcome', () { ... })`
- Widget: `testWidgets('renders X when Y', (tester) async { ... })`
- Group: `group('ClassName', () { ... })`
- Mock: `Mock<InterfaceName>` (e.g., `MockCellService`)
- Fixture: `k<Feature>FixtureJson`

---

## Scope Ceilings

| Constraint | Value | Rationale |
|-----------|-------|-----------|
| Species | 32,752 (real IUCN dataset) | Full biodiversity catalog |
| Habitats | 7 | Forest, Plains, Freshwater, Saltwater, Swamp, Mountain, Desert |
| IUCN rarity tiers | 6 | LC, NT, VU, EN, CR, EX — with 3^x loot weights |
| Fog levels | 5 | Unknown (1.0), Detected (0.85), Nearby (0.95), Explored (0.5), Present (0.0) |
| Seasons | 2 | Summer (May–Oct), Winter (Nov–Apr) |
| Continents | 6 | Asia, North America, South America, Africa, Oceania, Europe |
| Detection radius | 1000 m | kDetectionRadiusMeters — cells within this radius are at least "unexplored" |
| Encounter slots per cell | 3 | Max species rolled per cell visit |
| Max cells per tile | 100 | Mesh generation performance |
| Tile prefetch radius | 1 | Network bandwidth, memory cache |
| GPS update frequency | 1 Hz | Battery drain, state churn |
| GPS accuracy threshold | 50 m | Switch to simulation if exceeded |

---

## Forbidden Patterns

- **No type-safety bypasses**: Never use `dynamic`, `as any`, `@ts-ignore` equivalents, or unchecked `as` casts without type guards. Use sealed classes and pattern matching.
- **No global state**: Never use `static` variables or singletons. Use Riverpod providers.
- **No monolithic bootstrap**: App uses `ProviderScope` → `ConsumerWidget`. Never create a single class that initializes all systems.
- **No direct SQLite queries**: Always use repository abstractions. Never call `database.rawQuery()`.
- **No blocking main thread**: All I/O (GPS, network, SQLite) must be async.
- **No unbounded synchronous loops over I/O**: Any loop that awaits SQLite/network per iteration (hydration, bulk sync, batch persist) MUST yield to the event loop periodically (`await Future.delayed(Duration.zero)` every ~50 iterations). On iOS WebKit, each IndexedDB-backed SQLite write takes 10-15ms — 700 sequential writes without yielding freezes the UI for 7-10 seconds.
- **No hardcoded constants**: All game-balance values go in `lib/shared/constants.dart`.
- **No `StateNotifier`**: Use Riverpod v3 `Notifier` pattern exclusively.
- **No stored fog state**: Fog is computed from player position + visit history. Never persist per-cell FogState.
- **No platform-specific code in business logic**: GPS/platform code is isolated in `features/location/`.
- **No invisible computation**: Never rebuild widgets, allocate strings, or run animations for tabs/screens the user isn't viewing. Gate all computation on visibility. See "The GBA Rule" in `docs/target-architecture.md`.

---

## Known Tech Debt

| Item | Location | Impact |
|------|----------|--------|
| `widget_test.dart` accepts ErrorBoundary fallback as passing | `test/widget_test.dart` | MapLibre doesn't render on headless CI — real map tests require device/emulator |
| `widget_test.dart` accepts ErrorBoundary fallback as passing | `test/widget_test.dart` | MapLibre doesn't render on headless CI — real map tests require device/emulator |

---

## API Gotchas

| Library | Gotcha |
|---------|--------|
| `geobase` | Uses `Geographic` class, NOT `LatLng`. Constructor: `Geographic(lat: ..., lon: ...)` |
| `maplibre` | `Position(lng, lat)` — **longitude first!** |
| `maplibre` | `MapController.animateCamera(center:, nativeDuration:)` |
| Drift | `copyWith` uses `Value<T>` wrappers — `Value(x)` to set, `Value.absent()` to skip |
| Drift | `autoIncrement()` tables must NOT override `primaryKey` |
| Drift | Run `flutter pub run build_runner build` after schema changes |
| Riverpod 3.x | `Notifier` pattern (not `StateNotifier`). `build()` returns initial state. |
| Riverpod 3.x | Guard async gaps with `if (!ref.mounted) return;` |
| `h3_flutter_plus` | Requires `LD_LIBRARY_PATH=.` at runtime for FFI |
| `FogStateResolver` | `onVisitedCellAdded` stream must be `sync: true` |

---

## Debugging Checklist

When a feature misbehaves:

1. **Capture exact inputs/outputs** — log player location, cell ID, fog state, API responses
2. **Apply 5-why analysis** — find root cause, not symptom
3. **Isolate the system** — disable unrelated features to narrow scope
4. **Check constraints** — verify no scope ceiling violations
5. **Verify reversibility** — ensure any fix can be toggled off

### Infrastructure Investigation Protocol

When diagnosing infrastructure issues (stalled pipelines, deploy failures, schema mismatches):

1. **Verify live state first** — always query the production database/service before comparing against local files. Local files may have diverged from remote. A single `curl` to the REST API can disprove a hypothesis in seconds.
2. **Test your hypothesis before implementing** — run one verification query/command to confirm the suspected root cause before writing any fix code. Never write a migration without first checking if the columns already exist.
3. **Check migration sync status early** — run `supabase migration list --linked` BEFORE assuming local migrations reflect remote schema. Remote may have migrations applied directly that aren't in local files.
4. **Distinguish code bugs from operational issues** — a stalled pipeline could be: schema mismatch (code), API key expiry (ops), rate limiting (ops), deploy failure (ops), cron stopped (ops), or env var change (ops). Check operational causes before assuming code bugs.
5. **Check deploy history** — when did the last successful Edge Function deploy happen? Did a recent deploy change `PIPELINE_VERSION` or other env vars? Use `gh api repos/.../deployments` to check.
6. **Time-box investigation** — 15 min max per hypothesis before pivoting. If you can't confirm a root cause in 15 min, you're likely chasing the wrong lead.

> **Observability architecture** — two parallel systems:
> - **`app_logs`** table: Raw debug text blobs from `DebugLogBuffer` via `LogFlushService` (debounced 5s). Severity-filtered (warning+ and always-pass tags).
> - **`app_events`** table: Structured typed events from `ObservabilityBuffer` (30s batch flush). Categories: event, log, js, ui.
>
> See `docs/target-architecture.md` for the full observability design.

> **Investigation postmortem (2026-03-28):** Enrichment pipeline stalled for 3 days. Initially misdiagnosed as "missing DB columns" by comparing local migration files against Edge Function code. Columns already existed on remote (added via direct migrations). Root cause: `PIPELINE_VERSION` env var matched existing enrichver stamps, so no candidates looked stale. A deploy with a new commit SHA changed the version and unblocked the pipeline. Lesson: always verify live state before diagnosing.

### Supabase App Logs

Debug text logs are in `app_logs`, structured events are in `app_events`. Both are in Supabase (project ref: `bfaczcsrpfcbijoaeckb`). Query via the Supabase CLI:

```bash
npx supabase db query --linked "SELECT * FROM app_logs ORDER BY created_at DESC LIMIT 100"
npx supabase db query --linked "SELECT * FROM app_events ORDER BY created_at DESC LIMIT 100"
```

Edge function logs (process-enrichment-queue, validate-encounter, etc.) are accessible via the Railway production logs:
```bash
railway logs --tail 100
```

### High-signal log points

- GPS updates: accuracy, timestamp, tile coordinate
- Fog state transitions: cell ID, old → new state, trigger
- Persistence operations: operation type, row count, latency
- Sync events: type, status, retry count
- Tile requests: URL (masked key), HTTP status, response size

---

## Repo Hygiene

### Commit Convention

Format: `{emoji} {type}({scope}): {description} (#{issue})`

- Scope is optional. Multiple issues: `(#1, #2, #3)`.
- Squash-only merges — PR title becomes the commit message.

| Emoji | Type | When |
|-------|------|------|
| ✨ | `feat` | New feature |
| 🐛 | `fix` | Bug fix |
| 🎨 | `style` | UI/visual changes, formatting |
| ♻️ | `refactor` | Refactoring, no behavior change |
| ✅ | `test` | Tests only |
| 📝 | `docs` | Documentation |
| 🔧 | `chore` | Tooling, config, build |
| 🚀 | `perf` | Performance |
| 🔥 | `remove` | Delete code/files |

**Examples:**
```
✨ feat(map): add fog-of-war cell visibility (#88)
🐛 fix(sync): gate queue enqueue on SQLite success (#129)
🎨 style(icons): standardize iconography via GameIcons (#84)
♻️ refactor(persistence): extract upsertItem into repository (#130)
✅ test(sync): add write queue stale deletion tests (#128)
```

- **Single docs directory**: All documentation lives in `docs/`. No `doc/`, `documentation/`, or other variants.
- **No stale research artifacts**: One-off research notes, brainstorm dumps, and superseded designs get consolidated into the relevant design doc or deleted. Don't leave scratch files in the repo.
- **Generated files stay generated**: Never hand-edit `*.g.dart`, `*.freezed.dart`, or other build_runner outputs.
- **Assets are intentional**: Everything in `assets/` is loaded at runtime. Don't commit unused data files, test exports, or draft datasets.
- **No orphan directories**: Empty directories or directories with only `.gitkeep` should be removed unless they serve a structural purpose.
- **Clean up after yourself**: When deleting a feature or consolidating files, remove all traces — imports, test files, doc references, AGENTS.md mentions.

---

## Documentation Maintenance Protocol

This project has two documentation systems. **Both must stay current.**

### 1. Cross-Cutting Docs (`docs/`)

Architecture, data flow, and reference docs designed for agent context loading. Start with `docs/INDEX.md` — it tells you what to read for any task type.

```
docs/
├── INDEX.md           # Reading guide — what to read for which task
├── architecture.md    # Layer diagram, dependency rules, feature boundaries
├── game-loop.md       # GPS→render pipeline, fog state machine, tick rates
├── state.md           # All 30 Riverpod providers, dependency graph, mutation patterns
├── data-model.md      # Models, DB schema (4 tables), repositories, game constants
└── tech-stack.md      # Versions, packages, build/run/deploy commands
```

**Update triggers for `docs/` files:**

| File | Update when... |
|------|----------------|
| `architecture.md` | New feature module added, layer boundary changed, dependency rule added |
| `game-loop.md` | Pipeline stage added/removed, tick rate changed, new state machine |
| `state.md` | Provider added/removed/renamed, dependency between providers changed |
| `data-model.md` | Model field added/removed, DB table changed, repository method added, constant changed |
| `tech-stack.md` | Package added/removed/upgraded, build command changed, deploy config changed |
| `INDEX.md` | New docs file added, reading recommendations changed |

### 2. Local Context Docs (`AGENTS.md`)

Per-directory files providing module-specific patterns, gotchas, and anti-patterns. These are **not** duplicates of `docs/` — they cover local concerns only.

```
AGENTS.md files:
├── ./AGENTS.md                          # Root — quick ref, design decisions, forbidden patterns
├── lib/AGENTS.md                        # v2 flat structure overview
├── lib/data/AGENTS.md                   # Drift schema, repos, sync
├── lib/data/sync/AGENTS.md             # Write queue, Supabase persistence
├── lib/domain/fog/AGENTS.md            # Fog state resolution
├── lib/domain/seed/AGENTS.md           # Daily seed service
├── lib/models/AGENTS.md                # Immutable value objects
├── lib/shared/AGENTS.md                # Constants, shared utilities
└── test/AGENTS.md                       # Test fixtures, mock patterns, integration suites
```

**Update triggers for `AGENTS.md` files:**

| Trigger | Action |
|---------|--------|
| New feature module created | Create `features/<name>/AGENTS.md` (30–80 lines) |
| Provider renamed or rewired | Update the relevant `AGENTS.md` + `docs/state.md` |
| New model or enum added | Update `lib/models/AGENTS.md` + `docs/data-model.md` |
| New gotcha or anti-pattern discovered | Add to the nearest `AGENTS.md` |
| File moved between directories | Update both old and new parent `AGENTS.md` |
| Test pattern changed (new mock, new fixture) | Update `test/AGENTS.md` |
| Design decision changed (requires explicit instruction) | Update root `AGENTS.md` Core Design Decisions + `docs/game-design.md` |

### Maintenance Rules

1. **Overwrite stale content, never append.** When a section is outdated, replace it entirely. Do not add "Update:" or "Note:" annotations — just fix the content.
2. **Child AGENTS.md never repeats parent.** If root AGENTS.md covers it, the child should not. Each file owns its local scope only.
3. **Format for AI.** Bullet points, tables, code blocks, type schemas. Zero narrative fluff. Telegraphic style.
4. **Verify after changes.** After updating any doc, spot-check that cross-references between `docs/` files and `AGENTS.md` files remain consistent (e.g., provider count in `state.md` matches root AGENTS.md Quick Reference).
5. **50–150 lines per AGENTS.md.** If a file grows past 150 lines, split into child directories or move cross-cutting content to `docs/`.

---

## Managing AGENTS.md Files

### How it works

There is no automatic inheritance. Each agent reads the AGENTS.md files it finds in directories it's working in. The root file contains project-wide rules; subdirectory files contain directory-specific context plus a pointer line back to their parent. Behavior varies by tool — some tools load all AGENTS.md files in the path, others only the nearest one.

### Structure

```
/AGENTS.md                        ← Project-wide rules, architecture, design decisions
lib/AGENTS.md                     ← v2 flat structure overview
lib/<subdir>/AGENTS.md            ← Stub with local rules + pointer to root AGENTS.md
lib/shared/AGENTS.md              ← Design system, constants, shared widget rules
test/AGENTS.md                    ← Test conventions, mocks, integration suites
.agents/                          ← Agent working memory (gitignored)
```

### Rules for maintaining

1. **Every significant directory gets a file.** Skip `generated/`, `assets/`, `__tests__/`, platform dirs (`android/`, `ios/`, `web/`, `linux/`, `macos/`, `windows/`).
2. **Keep them operational.** Rules agents can follow, not docs for humans.
3. **Preserve existing rules when updating.** Read first, then add.
4. **When adding a new feature directory**, create its `AGENTS.md` immediately (use feature template from root AGENTS.md).
5. **When adding a new convention or constraint**, add to root; only add to subdirectory file if the rule is scoped to that directory.
6. **End every subdirectory file** with: `See /AGENTS.md for project-wide rules.` (or pointer to nearest parent).
7. **Core subdirectory files are stubs** pointing to `lib/core/AGENTS.md` — the parent file has full detail for all core subdirs.
8. **50–150 lines per file.** If a feature file exceeds 150 lines, split by moving cross-cutting content to `docs/`.

### How to regenerate

Run `/init-deep` in the OpenCode session to rescan and update all AGENTS.md files and `.agents/` working memory.

---

## Future Work (Not Started)

- ~~4-tab navigation (Map | Home | Town | Pack) — currently Map only~~ **Done** (TabShell with IndexedStack)
- Museum (7 habitat wings, permanent donations, unlockable progression)
- Town tab (NPC hub, discoverable NPCs on map)
- Pack tab (inventory-first management, species as stacked items)
- Rarity-scaled discovery reveals (LC = toast → EX = full-screen ceremony)
- Tap-to-photograph for rare species (VU+)
- Daily world seed (midnight GMT rotation, deterministic per-day)
- Treasure maps (quest system for directed exploration)
- NPC bundles (Stardew-style themed collections)
- Sub-collections & sets (habitat sets, taxonomic sets, continent sets, rarity sets)
- Sanctuary appeal system (Ark Nova-style placement puzzle)
- Cell activities (forage, lure, survey, habitat care)
- Weather-based spawns (rain = amphibians, night = different species)
- Adjacent cell previews (silhouettes/glows of nearby species)
- Plants/Flora collectibles (trees, flowers, fungi)
- Minerals/Gems collectibles (rocks, crystals)
- Artifacts/Fossils collectibles (ancient items, bones)
- Camera/AI species identification
- Multiplayer, social features, leaderboards, trading
- Real-time Supabase sync (currently manual only)
- Push notifications
- Particle effects at fog edges (v2 visual polish)
- Real tile provider (MBTiles or Mapbox API)
- Analytics / engagement tracking
