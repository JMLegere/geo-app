# Agent Guidance — Fog of World

> iNaturalist × Stardew Valley × Pokémon Go. Explore the real world via GPS, reveal fog-of-war, discover 33k real IUCN species, build a sanctuary, restore habitats.

## Quick Reference

| Key | Value |
|-----|-------|
| Framework | Flutter 3.41.3 (Dart) |
| State | Riverpod 3.2.1 — `Notifier` pattern (NOT `StateNotifier`) |
| Map | `maplibre` by josxha v0.1.2 (NOT `maplibre_gl`) |
| Persistence | Drift 2.14.0 (SQLite) — offline-first |
| Geo types | `geobase` — `Geographic(lat:, lon:)` (NOT `LatLng`) |
| Cell system | Voronoi (with H3 fallback via `h3_flutter_plus`) |
| Species data | 32,752 real IUCN records in `assets/species_data.json` (6 MB) |
| Tests | 910 passing, `flutter_test` only (no mockito/mocktail) |
| Analysis | 0 issues |
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
├── main.dart                   # ProviderScope → FogOfWorldApp (ConsumerWidget)
├── core/                       # Domain logic, models, state, persistence (NO UI)
│   ├── cells/                  # Spatial indexing (CellService interface + impls)
│   ├── config/                 # SupabaseConfig (env vars)
│   ├── database/               # Drift ORM (4 tables)
│   ├── fog/                    # FogStateResolver (computed visibility)
│   ├── models/                 # 8 immutable value objects
│   ├── persistence/            # Repository pattern (4 repos)
│   ├── species/                # Loot table, species loader, continent resolver
│   └── state/                  # Riverpod providers (fog, location, player, collection, season)
├── features/                   # Feature modules (UI + feature-specific logic)
│   ├── achievements/           # 🏆 Achievement tracking + toast notifications
│   ├── auth/                   # 🔐 Mock auth (swappable to Supabase)
│   ├── biome/                  # 🌿 ESA land cover → habitat mapping
│   ├── caretaking/             # 🌱 Daily visit streaks
│   ├── discovery/              # 🔬 Species encounter events
│   ├── journal/                # 📖 Collection viewer with filters
│   ├── location/               # 📍 GPS, simulation, filtering (services only)
│   ├── map/                    # 🗺️ Map rendering, fog overlay, camera (14 files)
│   ├── restoration/            # 🏗️ Cell restoration progress
│   ├── sanctuary/              # 🏠 Species sanctuary grouped by habitat
│   ├── seasonal/               # ❄️ Summer/winter species availability
│   ├── spikes/                 # 🧪 Experimental prototypes (not production)
│   └── sync/                   # ☁️ Offline-first sync to Supabase
├── shared/
│   └── constants.dart          # All game-balance constants (kDetectionRadiusMeters, etc.)
```

**See also:** `lib/core/AGENTS.md` and `lib/features/map/AGENTS.md` for subsystem-specific guidance.

### Codebase Stats

| Metric | Value |
|--------|-------|
| Dart source files | 105 (lib/) + 84 (test/) |
| Total lines | ~30,000 |
| Largest file | `app_database.g.dart` (2,460 lines — generated) |
| Largest feature | `map/` (14 files) |

---

## Core Design Decisions

These are **locked in** — do not revisit without explicit instruction.

1. **Computed fog state** — FogState is derived on-demand from player position + visit history, like Civilization fog-of-war. Only `visitedCellIds` are persisted. Never store per-cell fog state.

2. **Deterministic species encounters** — Species for a cell are seeded by cell ID via SHA-256 hash. Same cell always yields the same species. This is intentional for reproducibility.

3. **Voronoi cells** — The cell system uses Voronoi tessellation (not H3). `CellService` is an abstract interface; H3 exists as a fallback.

4. **IUCN rarity = loot weights** — 6 IUCN statuses map to 10^x weights: Least Concern (100k), Near Threatened (10k), Vulnerable (1k), Endangered (100), Critically Endangered (10), Extinct (1). Path of Exile style.

5. **Offline-first** — SQLite (Drift) is the source of truth. Supabase write-through syncs data when credentials are configured. No sync queue — writes go directly to Supabase via `SupabasePersistence`.

6. **Riverpod v3 Notifier** — All mutable state uses `NotifierProvider<T, S>` (not `StateNotifier`, not `ChangeNotifier`). Immutable state classes with `copyWith()`.

7. **7 habitats** — Forest, Plains, Freshwater, Saltwater, Swamp, Mountain, Desert.

8. **2 seasons** — Summer (May–Oct), Winter (Nov–Apr). 80% of species are year-round, 10% summer-only, 10% winter-only.

9. **Restoration formula** — 3 unique species in a cell = fully restored (level 1.0). Formula: `min(uniqueSpeciesCount, 3) / 3.0`.

10. **Conditional Supabase** — When `SUPABASE_URL` and `SUPABASE_ANON_KEY` are supplied via `--dart-define`, the app uses `SupabaseAuthService` (with anonymous sign-in) and `SupabasePersistence` (write-through to Supabase tables). Without credentials, `MockAuthService` is used and sync is disabled.

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
| `ref.listen()` | React to other provider changes | journal → collectionProvider, sanctuary → playerProvider |
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
| `ref.listen()` in `build()` | React to changes without resetting state | Journal filters persist when collection changes |
| `ref.read(...notifier)` in method | Bidirectional sync between providers | Caretaking syncs streak with PlayerProvider |
| Stream subscription + `ref.onDispose()` | External event source | LocationNotifier subscribes to GPS stream |

---

## Persistence

### Drift (SQLite) ORM

3 tables: `LocalCellProgressTable`, `LocalCollectedSpeciesTable`, `LocalPlayerProfileTable`.

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
- `CollectionRepository` — collected species per user per cell
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
- `test/integration/` — 4 offline workflow suites (full persistence round-trips)

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
| Fog levels | 5 | Undetected (1.0), Unexplored (0.75), Hidden (0.5), Concealed (0.25), Observed (0.0) |
| Seasons | 2 | Summer (May–Oct), Winter (Nov–Apr) |
| Continents | 6 | Asia, North America, South America, Africa, Oceania, Europe |
| Detection radius | 50 km | kDetectionRadiusMeters — cells within this radius are at least "unexplored" |
| Restoration threshold | 3 species | 3 unique species per cell = fully restored |
| Encounter slots per cell | 3 | Max species rolled per cell visit |
| Max cells per tile | 100 | Mesh generation performance |
| Tile prefetch radius | 1 | Network bandwidth, memory cache |
| GPS update frequency | 1 Hz | Battery drain, state churn |
| GPS accuracy threshold | 50 m | Switch to simulation if exceeded |

---

## Forbidden Patterns

- **No type-safety bypasses**: Never use `dynamic`, `as any`, `@ts-ignore` equivalents, or unchecked `as` casts without type guards. Use sealed classes and pattern matching.
- **No global state**: Never use `static` variables or singletons. Use Riverpod providers. *(Known violation: `AchievementService` is a `static const` singleton in `achievement_provider.dart`.)*
- **No monolithic bootstrap**: App uses `ProviderScope` → `ConsumerWidget`. Never create a single class that initializes all systems.
- **No direct SQLite queries**: Always use repository abstractions. Never call `database.rawQuery()`.
- **No blocking main thread**: All I/O (GPS, network, SQLite) must be async.
- **No hardcoded constants**: All game-balance values go in `lib/shared/constants.dart`.
- **No `StateNotifier`**: Use Riverpod v3 `Notifier` pattern exclusively.
- **No stored fog state**: Fog is computed from player position + visit history. Never persist per-cell FogState.
- **No platform-specific code in business logic**: GPS/platform code is isolated in `features/location/`.

---

## Known Tech Debt

| Issue | Location | Severity |
|-------|----------|----------|
| Singleton `AchievementService` | `achievement_provider.dart:83` | Medium — should be a Provider |
| Services instantiated in widget | `map_screen.dart:55-58` | High — should use Riverpod providers |
| Hardcoded coordinates | `map_screen.dart:66-67, 75-81` | Medium — should move to constants.dart |
| `ref.read()` in `build()` | journal, sanctuary, achievement providers | Medium — should use `ref.watch()` |
| Stream subscriptions in widget fields | `map_screen.dart:60-61` | Medium — should use StreamProvider |
| Manual service lifecycle in initState | `map_screen.dart:70-118` | High — should use `ref.onDispose()` |
| Bidirectional notifier coupling | `caretaking_provider.dart:37,51` | Low — works but tight coupling |
| TODO: real GPS plugin | `location_service.dart:53` | Low — using simulation for now |
| Spike code with StatefulWidget | `fog_spike_screen.dart` | Low — experimental, not production |

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

## Future Work (Not Started)

- Camera/AI species identification
- Multiplayer, social features, leaderboards, trading
- Real-time Supabase sync (currently manual only)
- Push notifications
- Particle effects at fog edges (v2 visual polish)
- Real tile provider (MBTiles or Mapbox API)
- Analytics / engagement tracking
