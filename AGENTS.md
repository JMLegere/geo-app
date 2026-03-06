# Agent Guidance — EarthNova (working title)

> iNaturalist × Stardew Valley × Pokémon Go. Explore the real world via GPS, reveal fog-of-war, discover 33k real IUCN species, build a sanctuary, restore habitats. Working title: EarthNova.

## Quick Reference

| Key | Value |
|-----|-------|
| Working Title | EarthNova |
| Framework | Flutter 3.41.3 (Dart) |
| State | Riverpod 3.2.1 — `Notifier` pattern (NOT `StateNotifier`) |
| Map | `maplibre` by josxha v0.1.2 (NOT `maplibre_gl`) |
| Persistence | Drift 2.14.0 (SQLite) — local cache + write queue. Supabase = source of truth |
| Geo types | `geobase` — `Geographic(lat:, lon:)` (NOT `LatLng`) |
| Cell system | Voronoi (with H3 fallback via `h3_flutter_plus`) |
| Species data | 32,752 real IUCN records in `assets/species_data.json` (6 MB) |
| Tests | 1156 passing, `flutter_test` only (no mockito/mocktail) |
| Analysis | 33 info-level issues |
| Backend | Supabase (conditional) — `SupabaseAuthService` + `SupabasePersistence` when credentials supplied, `MockAuthService` fallback |

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

```
lib/
├── main.dart                   # ProviderScope → FogOfWorldApp → TabShell
├── core/                       # Domain logic, models, state, persistence (NO UI)
│   ├── cells/                  # Spatial indexing (CellService interface + impls)
│   ├── config/                 # SupabaseConfig (env vars)
│   ├── database/               # Drift ORM (3 tables)
│   ├── fog/                    # FogStateResolver (computed visibility)
│   ├── models/                 # 12 immutable value objects
│   ├── persistence/            # Repository pattern (3 repos)
│   ├── species/                # Loot table, species loader, continent resolver
│   └── state/                  # Riverpod providers (fog, location, player, inventory, season)
├── features/                   # Feature modules (UI + feature-specific logic)
│   ├── achievements/           # 🏆 Achievement tracking + toast notifications
│   ├── auth/                   # 🔐 Mock auth (swappable to Supabase)
│   ├── biome/                  # 🌿 ESA land cover → habitat mapping
│   ├── caretaking/             # 🌱 Daily visit streaks
│   ├── discovery/              # 🔬 Species encounter events
│   ├── location/               # 📍 GPS, simulation, filtering (services only)
│   ├── map/                    # 🗺️ Map rendering, fog overlay, camera (14 files)
│   ├── navigation/             # 🧭 4-tab shell (Map | Home | Town | Pack)
│   ├── pack/                   # 🎒 Collection viewer with filters (renamed from journal)
│   ├── restoration/            # 🏗️ Cell restoration progress
│   ├── sanctuary/              # 🏠 Species sanctuary grouped by habitat (Home tab)
│   ├── seasonal/               # ❄️ Summer/winter species availability
│   └── sync/                   # ☁️ Offline-first sync to Supabase
├── shared/
│   └── constants.dart          # All game-balance constants (kDetectionRadiusMeters, etc.)
```

**See also:** `lib/core/AGENTS.md`, `lib/features/map/AGENTS.md`, `lib/shared/AGENTS.md`, `lib/features/location/AGENTS.md`, `lib/features/discovery/AGENTS.md`, `lib/features/achievements/AGENTS.md`, `lib/core/cells/AGENTS.md`, `lib/core/species/AGENTS.md`, `test/AGENTS.md` for subsystem-specific guidance.

### Codebase Stats

| Metric | Value |
|--------|-------|
| Dart source files | ~130 (lib/) + 85 (test/) |
| Total lines | ~34,000 |
| Largest file | `app_database.g.dart` (1,989 lines — generated) |
| Largest feature | `map/` (25 files) |

---

## Core Design Decisions

These are **locked in** — do not revisit without explicit instruction.

1. **Computed fog state** — FogState is derived on-demand from player position + visit history, like Civilization fog-of-war. Only `visitedCellIds` are persisted. Never store per-cell fog state.

2. **Deterministic species encounters** — Species for a cell are seeded by cell ID via SHA-256 hash. Same cell always yields the same species. This is intentional for reproducibility.

3. **Voronoi cells** — The cell system uses Voronoi tessellation (not H3). `CellService` is an abstract interface; H3 exists as a fallback.

4. **IUCN rarity = loot weights** — 6 IUCN statuses map to 10^x weights: Least Concern (100k), Near Threatened (10k), Vulnerable (1k), Endangered (100), Critically Endangered (10), Extinct (1). Path of Exile style.

5. **Server-authoritative** — Supabase is the source of truth. SQLite is a local cache and offline write queue. Client can roll encounters offline using cached daily seed (24h grace); server re-derives and validates on reconnect. Rejected actions roll back locally.

6. **Riverpod v3 Notifier** — All mutable state uses `NotifierProvider<T, S>` (not `StateNotifier`, not `ChangeNotifier`). Immutable state classes with `copyWith()`.

7. **7 habitats** — Forest, Plains, Freshwater, Saltwater, Swamp, Mountain, Desert.

8. **2 seasons** — Summer (May–Oct), Winter (Nov–Apr). 80% of species are year-round, 10% summer-only, 10% winter-only.

9. **Restoration formula** — 3 unique species in a cell = fully restored (level 1.0). Formula: `min(uniqueSpeciesCount, 3) / 3.0`.

10. **Conditional Supabase** — When `SUPABASE_URL` and `SUPABASE_ANON_KEY` are supplied via `--dart-define`, the app uses `SupabaseAuthService` (with anonymous sign-in) and `SupabasePersistence` (write-through to Supabase tables). Without credentials, `MockAuthService` is used and sync is disabled.

---

## Product Architecture (Design Jam Decisions — 2026-03-06)

These are the target architecture decisions from the design jam. They describe WHERE the product is going. **Phase 1 (item model) is COMPLETE** — `ItemDefinition`, `ItemInstance`, `Affix`, and `inventoryProvider` are now live. Remaining work: GameCoordinator (Phase 2), server-authoritative persistence (Phase 3), daily seed (Phase 4), breeding/bundles (Phase 5+).

**This is the canonical mental model. If something contradicts this section, ALWAYS flag it to the user for resolution. Never silently update — the user decides what's true.**

### Wall 1: Everything Is an Item

- **PoE / CryptoKitty model, NOT Stardew stacking.** Every discovered item is a unique instance with randomly-rolled affixes (prefix/suffix). Items never stack. Two Red Foxes have different stats.
- **5 item categories:** Fauna, Flora, Mineral, Fossil, Artifact. All share the `ItemDefinition` → `ItemInstance` pattern.
- **Rarity gates affix depth:** LC = 0-1 affixes, NT = 1-2, VU = 2-3, EN = 3-4, CR = 4-5, EX = 5+.
- **Breeding:** Two instances → offspring with inherited/combined traits. CryptoKitty-style trait inheritance. Server-validated.
- **Collections are bundles:** Stardew community center model. Bundles group items with completion rewards. Museum = permanent donation bundle. NPC requests = consumable bundles. Achievements track milestones ("discover 100 forest fauna").
- **Full spec:** `docs/item-system-design.md`

### Wall 2: GameCoordinator

- **The map is a renderer, not an orchestrator.** Game logic lives in `GameCoordinator`, a pure Dart service above the UI.
- **Runs forever** — created at ProviderScope level, never stops on tab switch. Map screen reads its state and renders.
- **Owns:** GPS subscription, game loop tick (~10 Hz), fog computation, discovery processing, write queue, daily seed cache, streaks, restoration.
- **Does NOT own:** map rendering, camera, widget state, toast UI, RubberBand interpolation.
- **Emits:** `Stream<GameState>` — Riverpod notifiers project from this. Discovery events → UI subscribes for toasts.
- **Target directory:** `lib/core/game/`

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
| 2 | Not started | GameCoordinator (extract from map_screen) | Tab-independent game loop |
| 3 | Not started | Server-authoritative persistence (write queue) | Online validation, anti-cheat |
| 4 | Not started | Daily seed system | Deterministic encounters, social sharing |
| 5+ | Not started | Breeding, bundles, museum, social | Endgame features |

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

### Minimal feature (biome, location, caretaking, restoration)
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

3 tables: `LocalCellProgressTable`, `LocalItemInstanceTable`, `LocalPlayerProfileTable`.

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

Tests mirror `lib/` exactly: `test/core/cells/cell_cache_test.dart` tests `lib/core/cells/cell_cache.dart`.

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
| IUCN rarity tiers | 6 | LC, NT, VU, EN, CR, EX — with 10^x loot weights |
| Fog levels | 5 | Undetected (1.0), Unexplored (1.0), Concealed (0.95), Hidden (0.5), Observed (0.0) |
| Seasons | 2 | Summer (May–Oct), Winter (Nov–Apr) |
| Continents | 6 | Asia, North America, South America, Africa, Oceania, Europe |
| Detection radius | 1000 m | kDetectionRadiusMeters — cells within this radius are at least "unexplored" |
| Restoration threshold | 3 species | 3 unique species per cell = fully restored |
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
- **No hardcoded constants**: All game-balance values go in `lib/shared/constants.dart`.
- **No `StateNotifier`**: Use Riverpod v3 `Notifier` pattern exclusively.
- **No stored fog state**: Fog is computed from player position + visit history. Never persist per-cell FogState.
- **No platform-specific code in business logic**: GPS/platform code is isolated in `features/location/`.

---

## Known Tech Debt

| Item | Location | Impact |
|------|----------|--------|
| MapLogger has mutable static variables | `lib/features/map/utils/map_logger.dart` | Violates "no global state" constraint |

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

### High-signal log points

- GPS updates: accuracy, timestamp, tile coordinate
- Fog state transitions: cell ID, old → new state, trigger
- Persistence operations: operation type, row count, latency
- Sync events: type, status, retry count
- Tile requests: URL (masked key), HTTP status, response size

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
├── state.md           # All 26 Riverpod providers, dependency graph, mutation patterns
├── data-model.md      # Models, DB schema (3 tables), repositories, game constants
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
AGENTS.md files (11 total):
├── ./AGENTS.md                              # Root — quick ref, design decisions, forbidden patterns
├── lib/core/AGENTS.md                       # Domain models, providers, persistence internals
├── lib/core/cells/AGENTS.md                 # Voronoi/H3 cell system, CellCache
├── lib/core/species/AGENTS.md               # LootTable, IUCN weights, ContinentResolver
├── lib/features/map/AGENTS.md               # Fog overlay, camera, GeoJSON layers
├── lib/features/navigation/AGENTS.md        # TabShell, tab index provider, web MapVisibility
├── lib/features/location/AGENTS.md          # GPS stream, simulation, filtering
├── lib/features/discovery/AGENTS.md         # Encounter flow, dual notifier pattern
├── lib/features/achievements/AGENTS.md      # Achievement evaluation, toast notifications
├── lib/shared/AGENTS.md                     # Constants, shared utilities
└── test/AGENTS.md                           # Test fixtures, mock patterns, integration suites
```

**Update triggers for `AGENTS.md` files:**

| Trigger | Action |
|---------|--------|
| New feature module created | Create `features/<name>/AGENTS.md` (30–80 lines) |
| Provider renamed or rewired | Update the relevant `AGENTS.md` + `docs/state.md` |
| New model or enum added | Update `lib/core/AGENTS.md` + `docs/data-model.md` |
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
