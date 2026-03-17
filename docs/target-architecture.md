# Target Architecture

> The definitive design doc for EarthNova. Not aspirational — this is what we're building. Supersedes `architecture.md` (current state), `engine-architecture.md` (engine phases), `ideal-architecture.md` (server-authoritative), and `current-architecture.md`. Those docs remain as historical reference. This doc is the source of truth.

---

## 5 Pillars

Every line of code serves exactly one of these. If it doesn't, it's dead weight.

| # | Pillar | What | Core Modules |
|---|--------|------|-------------|
| 1 | **🗺️ Explore** | Move through the real world, reveal fog-of-war | `core/game_loop/`, `features/map/`, `features/exploration/` |
| 2 | **🔬 Discover** | Encounter species, roll items, build collection | `core/species/`, `features/discovery/` |
| 3 | **🎒 Collect** | Sanctuary, achievements, restoration, caretaking | `features/collection/` |
| 4 | **☁️ Persist** | Auth, local DB, sync, daily seed | `features/auth/`, `features/sync/`, `core/persistence/`, `core/database/` |
| 5 | **📡 Observe** | Structured events, session timelines, fleet health, performance budgets | `core/engine/` (GameEvent stream), `app_events` table |

### Observability Is Not Optional

Observability is not a logging add-on. It's the event stream that IS the game. Every state change — cell entered, species discovered, fog updated, error caught — is a `GameEvent`. The same stream drives:
- **Gameplay** — UI subscribes to events and renders them
- **Persistence** — event consumers write to SQLite + write queue
- **Analytics** — events flush to `app_events` table in Supabase
- **Debugging** — session timelines reconstructable from events
- **Performance** — timing events track frame budgets and latency

One stream. Multiple consumers. No separate logging system for structured data.

---

## Hardware Budgets

These are constraints, not guidelines. The architecture must satisfy them.

### Memory Budget (target: <80 MB total app)

| Resource | Budget | Strategy |
|----------|--------|----------|
| Species catalog | 0 MB in RAM | Pre-compiled SQLite. Query on demand. Never parse JSON at runtime. |
| Species working set | 5 MB (~2K objects) | LRU cache for loot table candidates. Evict least-recently-used. |
| Item instances | 10 MB | Paginate collection views. Load 50 at a time. |
| Cell cache | 500 cells | Ring buffer. Evict farthest cells when full. |
| Fog render cache | Viewport only | Raster image, fixed resolution. No per-cell objects. |
| Map tile cache | 50 tiles | MapLibre default. Cap via config. |
| Event buffer | 2 MB | 500-line ring buffer (DebugLogBuffer) + batched flush (30s). |

### Frame Budget (target: 60fps, 16.6ms per frame)

| Stage | Budget | Enforced By |
|-------|--------|-------------|
| Flutter framework (layout, paint) | 4 ms | Framework |
| Map tile compositing (MapLibre) | 4 ms | MapLibre |
| Fog + cell overlay rendering | 4 ms | Raster overlay (constant cost) |
| Headroom (GC, jank, unexpected) | 4.6 ms | Architecture |

**Rule:** No synchronous computation >8ms on the main thread. If it takes longer, it runs in the engine (background) or gets chunked.

### Battery Budget

| Mode | GPS Rate | Trigger |
|------|----------|---------|
| Walking (active play) | 1 Hz | Default when app is foregrounded |
| Stationary (no movement 30s) | 0.1 Hz | Displacement filter detects no movement |
| Background | OFF | iOS/Android lifecycle. No background GPS. |
| Web | N/A | Step-based only. No GPS. |

### Storage Budget

| Table | Growth Rate | Retention |
|-------|-------------|-----------|
| item_instances | ~3 rows/day | Permanent |
| cell_progress | ~10 rows/day | Permanent |
| app_events | ~200 rows/session | 30 days (performance events: 7 days) |
| species_definitions | Static | Pre-compiled, read-only |
| write_queue | Transient | Deleted after server confirms |

---

## System Diagram

```
┌──────────────────────────────────────────────────────────┐
│                     Main Thread (UI)                      │
│                                                           │
│  ┌──────────────┐  ┌───────────────────────────────────┐ │
│  │ RubberBand    │  │  Screens                          │ │
│  │ (60fps vsync) │  │  MapScreen · Sanctuary · Pack     │ │
│  │               │  │  Auth · Settings · Sync           │ │
│  │  GPS → interp │  │                                   │ │
│  │  → camera     │  │  Receives GameEvent stream        │ │
│  │  → marker     │  │  Sends EngineInput messages       │ │
│  └──────┬────────┘  └─────────────────┬─────────────────┘ │
│         │ position (10Hz)             │ user inputs       │
│  ┌──────▼─────────────────────────────▼─────────────────┐ │
│  │              Message Bus (streams)                    │ │
│  │   Stream<EngineInput> ↓        Stream<GameEvent> ↑   │ │
│  └──────────────────┬─────────────────┬─────────────────┘ │
│                     │                 │                    │
├─────────────────────┼─────────────────┼────────────────────┤
│                     │  ENGINE BOUNDARY │                    │
├─────────────────────┼─────────────────┼────────────────────┤
│                     │                 │                    │
│  ┌──────────────────▼─────────────────┴─────────────────┐ │
│  │                    GameEngine                         │ │
│  │   Pure Dart. No Flutter. No Riverpod.                │ │
│  │                                                      │ │
│  │   Owns:                                              │ │
│  │   • Cell resolver (LazyVoronoi, concrete, no iface)  │ │
│  │   • Fog resolver (computed from position + visits)    │ │
│  │   • Encounter roller (SHA-256 deterministic)          │ │
│  │   • Species repository (SQLite queries)               │ │
│  │   • Observability (GameEvent emission)                │ │
│  │                                                      │ │
│  │   Emits: Stream<GameEvent>  (fat structured events)  │ │
│  │   Reads: Stream<EngineInput> (positions, taps, auth) │ │
│  └──────────────────────────────────────────────────────┘ │
│                     │                                      │
│  ┌──────────────────▼──────────────────────────────────┐  │
│  │            Event Consumers (provider layer)          │  │
│  │  PersistenceConsumer — SQLite + write queue          │  │
│  │  EnrichmentManager — AI classification pipeline     │  │
│  │  Provider projections — fog, inventory, player       │  │
│  │  EventSink — app_events table (30s batch flush)     │  │
│  └─────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

---

## Directory Structure

14 features, organized by role. Each is a distinct concept you can name in one word.

**The test:** Can you name it and a user would understand? If yes, it's a feature. If not, it's infrastructure and belongs in `core/` or `shared/`.

### Feature Roles

| Role | Features | What they do |
|------|----------|-------------|
| **Inputs** | `location/`, `world/`, `calendar/`, `weather/`, `steps/` | Real-world data that feeds the game loop |
| **Domain** | `items/` | Core game state — item definitions, instances, inventory, lifecycle |
| **Experiences** | `map/`, `discovery/`, `pack/`, `sanctuary/`, `achievements/`, `caretaking/` | What the player sees and interacts with |
| **Infrastructure** | `auth/`, `sync/`, `onboarding/` | Identity, persistence, first-run |

```
lib/
├── main.dart                      # ProviderScope → App → Shell (TabShell lives here)
│
├── core/                          # Pure Dart. No Flutter. No UI.
│   ├── models/                    # ~24 immutable value objects (unchanged)
│   ├── database/                  # Drift ORM (unchanged)
│   ├── persistence/               # 7 repositories (unchanged)
│   │
│   ├── engine/                    # ★ Game engine — one module, event-driven
│   │   ├── game_engine.dart       #   Wraps GameCoordinator, stream I/O
│   │   ├── game_coordinator.dart  #   Core game logic (fog, cells, encounters)
│   │   ├── game_event.dart        #   Fat structured event envelope
│   │   ├── engine_input.dart      #   Sealed: PositionUpdate, CellTapped, etc.
│   │   ├── engine_runner.dart     #   Abstract runner (main thread / isolate)
│   │   └── event_sink.dart        #   Batched flush to app_events
│   │
│   ├── cells/                     # Spatial grid geometry (LazyVoronoi, cache)
│   │   ├── lazy_voronoi.dart      #   THE cell implementation. No interface. No fallbacks.
│   │   ├── cell_cache.dart        #   LRU memoization (500 cell cap)
│   │   └── country_resolver.dart  #   Lat/lon → continent (ray-casting)
│   │
│   ├── fog/                       # Computed fog state (unchanged)
│   │   └── fog_state_resolver.dart
│   │
│   ├── species/                   # Species data + encounter resolution
│   │   ├── species_repository.dart #  SQLite-backed queries (NOT in-memory JSON)
│   │   ├── species_cache.dart     #   LRU cache (2K object cap, 5 MB budget)
│   │   ├── loot_table.dart        #   Weighted selection (queries species_repository)
│   │   ├── stats_service.dart     #   Brawn/wit/speed rolling
│   │   └── continent_resolver.dart
│   │
│   ├── services/                  # Infrastructure services
│   │   ├── daily_seed_service.dart
│   │   ├── debug_log_buffer.dart
│   │   └── observability_buffer.dart
│   │
│   ├── config/                    # Env vars
│   └── state/                     # Riverpod providers (wiring layer)
│
├── features/
│   │
│   │  ── INPUTS (real-world data → game loop) ──
│   │
│   ├── location/                  # 📍 Where — GPS stream, simulation, filtering
│   │
│   ├── world/                     # 🌍 What's here — terrain, cell state, events
│   │   │                          #   SHARED STATE — same for all players.
│   │   │                          #   Every player in the same cell sees the
│   │   │                          #   same habitat, restoration, events.
│   │   ├── services/              #   Biome resolver (ESA → habitat)
│   │   │                          #   Cell property resolver
│   │   │                          #   Restoration service (cell healing formula)
│   │   ├── models/                #   ESA land cover, cell events
│   │   └── providers/             #   Habitat service, restoration, cell properties
│   │
│   ├── calendar/                  # 📅 When — time of day, season, daily schedule
│   │   ├── services/              #   Season filter, time-of-day resolver
│   │   ├── models/                #   TimeState (dawn/day/dusk/night + season)
│   │   └── providers/             #   Calendar provider
│   │
│   ├── weather/                   # 🌧️ Conditions — real weather at player location
│   │   ├── services/              #   Weather API client
│   │   ├── models/                #   WeatherState (rain, snow, clear, fog, etc.)
│   │   └── providers/             #   Weather provider
│   │
│   ├── steps/                     # 👣 Movement — pedometer, step-based exploration
│   │
│   │  ── DOMAIN (game state) ──
│   │
│   ├── items/                     # 📦 Items — creation, lifecycle, inventory
│   │   │                          #   Items exist independently of where they are.
│   │   │                          #   Location: pack, sanctuary, museum, wild, trade.
│   │   │                          #   NOTE: Item VALUE OBJECTS (ItemDefinition,
│   │   │                          #   ItemInstance, Affix) stay in core/models/.
│   │   │                          #   This feature owns behavior, not shape.
│   │   ├── services/              #   Item creation, stat rolling, affix generation
│   │   └── providers/             #   Items provider (single source of truth for all items)
│   │
│   │  ── EXPERIENCES (views over domain state) ──
│   │
│   ├── map/                       # 🗺️ Map — view over world/ (fog raster + cell lines)
│   ├── discovery/                 # 🔬 Encounters — species events + notifications
│   ├── pack/                      # 🎒 Pack — view over items/ where status = active
│   ├── sanctuary/                 # 🏠 Sanctuary — view over items/ where status = placed
│   ├── achievements/              # 🏆 Milestones — tracking + toast notifications
│   ├── caretaking/                # 💚 Streaks — daily visit tracking
│   │
│   │  ── INFRASTRUCTURE ──
│   │
│   ├── auth/                      # 🔐 Identity — login, OTP, settings
│   ├── sync/                      # ☁️ Cloud — persistence, enrichment, queue
│   └── onboarding/                # 🚀 First-run — welcome flow
│
└── shared/                        # Design system + constants (unchanged)
    ├── constants.dart
    ├── design_tokens.dart
    ├── app_theme.dart
    └── widgets/
```

### What Moved

| Current Location | Target Location | Rationale |
|------------------|-----------------|-----------|
| `features/biome/` | `features/world/` | Biome is one aspect of "what's here" — terrain type |
| `features/restoration/` | `features/world/` | Restoration is cell state — another aspect of "what's here" |
| `features/seasonal/` | `features/calendar/` | Seasons are one aspect of "when" — grows into time-of-day, daily schedule |
| `features/enrichment/` (1 file) | `features/sync/` | Not a concept. The enrichment service already lives in sync/. |
| `features/navigation/` | `main.dart` | Not a concept. TabShell is app infrastructure. |
| `core/cells/cell_property_resolver.dart` | `features/world/` | Cell property resolution is world state, not grid geometry |
| `core/cells/event_resolver.dart` | `features/world/` | Cell events (migration, nesting) are world state |
| `core/game/` + `core/engine/` | `core/engine/` | One game loop module |

### Items as Independent Entities

Items exist independently of where they are. An item has a **location**, not a status. The location is a real place in the game.

#### Item Locations

| Location | Where the item is | Held? | Viewed by |
|----------|-------------------|-------|-----------|
| `pack` | On the player, in their field pack | Yes | `pack/` |
| `sanctuary` | Placed in the player's sanctuary | Yes | `sanctuary/` |
| `museum` | Donated to the museum (permanent) | No — gone | `museum/` |
| `wild` | Released back into the world | No — gone | — |
| `trade` | In transit to another player | No — pending | — |

**Held** = the player still possesses the item and can move it. Museum, wild, and trade are one-way — the item leaves the player's possession.

Moving an item is changing its location. No transfer logic, no container management:
- `pack → sanctuary` — player places item in sanctuary
- `sanctuary → pack` — player retrieves item from sanctuary
- `pack → museum` — permanent donation (irreversible)
- `pack → wild` — release (irreversible)
- `pack → trade` — offer to another player (irreversible once accepted)

**`items/` owns all item state** — definitions, instances, creation, stats, location, lifecycle. Single source of truth for every item regardless of where it currently is.

**`pack/` and `sanctuary/` are pure views.** They query items by location and render them. They own zero item state.

**`world/` is shared state.** Same cell = same terrain, restoration, events for all players. No userId.

**`items/` is per-player state.** Each player's items are their own. userId on every row.

| State | Scope | Owner | Tables |
|-------|-------|-------|--------|
| World | All players | `world/` | `cell_properties`, `location_nodes`, `species_definitions` |
| Items | Per-player | `items/` | `item_instances`, `player_profile` |
| Events | Per-session | `core/engine/` | `app_events` |

### What's Deleted

| Item | Lines | Reason |
|------|-------|--------|
| `H3CellService` | ~200 | Never used. H3 fallback that never fell back. |
| `VoronoiCellService` | ~200 | Replaced by LazyVoronoi. Dead code. |
| Legacy Voronoi constants (lines 94–114) | 21 | Zero references outside constants.dart. |

**`CellService` interface stays.** LazyVoronoi is the only implementation, but the interface is used by GameCoordinator, FogStateResolver, CellCache, and every test mock. Testability is worth the abstraction.

---

## Species Data: Pre-Compiled SQLite

**Decision: Ship a compiled `.db` file, not a JSON file parsed at runtime.**

### Build Pipeline

```
assets/species_data.json  (source of truth, git-tracked, human-readable)
        │
        ▼
tool/compile_species_db.dart  (build script, runs pre-build)
        │
        ▼
assets/species.db  (pre-compiled SQLite, shipped in APK bundle)
        │
        ▼
SpeciesRepository  (queries SQLite directly, no parsing)
```

### Schema

```sql
CREATE TABLE species_definitions (
  scientific_name TEXT PRIMARY KEY,
  common_name     TEXT NOT NULL,
  taxonomic_class TEXT NOT NULL,
  iucn_status     TEXT NOT NULL,
  habitats_json   TEXT NOT NULL,   -- JSON array: ["Forest","Mountain"]
  continents_json TEXT NOT NULL    -- JSON array: ["Asia"]
);

CREATE INDEX idx_species_habitat ON species_definitions (iucn_status);
```

### Runtime API

```dart
class SpeciesRepository {
  final Database _db;

  /// Query candidates for loot table.
  /// Returns only species matching current habitat + continent + season.
  Future<List<FaunaDefinition>> getCandidates({
    required Set<Habitat> habitats,
    required Continent continent,
    required Season season,
  });

  /// Lookup a single species by scientific name.
  Future<FaunaDefinition?> getByScientificName(String name);

  /// Count total species (for stats display).
  Future<int> count();
}
```

### What This Replaces

| Current | Target |
|---------|--------|
| `SpeciesDataLoader` — parses 6 MB JSON at startup | `SpeciesRepository` — queries pre-compiled SQLite |
| `speciesDataProvider` — FutureProvider holding `List<FaunaDefinition>` | `speciesRepositoryProvider` — Provider holding `SpeciesRepository` |
| `SpeciesService` — filters in-memory list | `LootTable` — queries `SpeciesRepository` for candidates |
| 33K Dart objects in RAM (~40–60 MB) | 0 objects in RAM. LRU cache holds ≤2K working set. |

---

## Fog Rendering: Raster Overlay + Vector Boundaries

**Decision: Fog is a raster image. Cell boundaries are vector lines. Two independent layers.**

### Fog Layer (raster)

- Full-viewport bitmap overlay on the map
- Each pixel's alpha = fog opacity at that world position
- Revealing fog = setting pixels to transparent
- Updated only when fog state changes (not every frame, not on camera pan)
- One draw call. Cost is O(viewport), not O(explored cells).
- Scales infinitely — 10,000 explored cells costs the same as 10.

### Cell Boundary Layer (vector)

- GeoJSON line features for Voronoi cell edges
- Only rendered for cells within viewport + small buffer (~50–100 cells)
- Thin lines, no fill polygons
- Updated on camera pan (debounced 200ms)

### What This Replaces

| Current | Target |
|---------|--------|
| GeoJSON fill polygon per cell (fog + boundary combined) | Raster overlay (fog) + GeoJSON lines (boundaries) |
| Cost grows with explored cells | Cost fixed to viewport size |
| Rebuild on every camera move | Fog: rebuild on state change only. Lines: debounced 200ms. |
| `FogOverlayController` builds GeoJSON | `FogRasterRenderer` renders to bitmap |

---

## Observability Architecture

### The Event Stream

Every game state change is a `GameEvent` with a fat envelope:

```dart
class GameEvent {
  final String sessionId;     // UUID v4, per app launch
  final String? userId;       // Supabase auth user ID
  final String deviceId;      // SHA-256 fingerprint (12 chars)
  final DateTime timestamp;   // UTC
  final String category;      // state | user | system | performance
  final String event;         // cell_entered, species_discovered, etc.
  final Map<String, dynamic> data;  // all context, no joins needed
}
```

### Event Catalog

See `engine-architecture.md` § Event Catalog for the full list. Key events:

| Category | Events |
|----------|--------|
| **State** | cell_entered, cell_exited, species_discovered, fog_changed, cell_restored, seed_rotated, enrichment_complete |
| **User** | session_started, session_ended, tab_switched, cell_tapped |
| **System** | hydration_complete, auth_restored, auth_expired, network_error, crash |
| **Performance** | fog_computed, geojson_built, api_call, sqlite_op |

### Event Flow

```
GameEngine emits GameEvent
  │
  ├─→ UI (MapScreen, toasts, overlays) — gameplay rendering
  ├─→ PersistenceConsumer — SQLite writes + write queue
  ├─→ EventSink — batch flush to app_events (30s / on background)
  └─→ Provider projections — fog, inventory, player state for widgets
```

### Persistence

Two destinations:

| Destination | Table | Retention | Purpose |
|-------------|-------|-----------|---------|
| Local SQLite | `app_events` | Session lifetime | Offline debugging, session reconstruction |
| Supabase | `app_events` | 30 days (perf: 7 days) | Fleet health, analytics, dashboards |

### Dashboard Queries (ready to use)

```sql
-- Session timeline
SELECT event, data, created_at FROM app_events
WHERE session_id = '<id>' ORDER BY created_at;

-- Crash rate per hour
SELECT date_trunc('hour', created_at), count(*)
FROM app_events WHERE event = 'crash'
GROUP BY 1 ORDER BY 1 DESC LIMIT 24;

-- P95 hydration time
SELECT percentile_cont(0.95) WITHIN GROUP (ORDER BY (data->>'duration_ms')::int)
FROM app_events WHERE event = 'hydration_complete';

-- Daily active users
SELECT date_trunc('day', created_at), count(DISTINCT user_id)
FROM app_events WHERE event = 'session_started'
GROUP BY 1 ORDER BY 1 DESC;
```

### Error Firewall

The engine never throws to the UI. All errors become events:
- Network failure → `network_error` event → engine continues, queue writes
- Auth expired → `auth_expired` event → engine pauses, UI shows re-auth
- SQLite failure → `crash` event → engine attempts recovery
- Asset load failure → `crash` event → fall back to cached data

---

## Web Platform

Web is a dev/test platform. Not a product target.

**Build for mobile. Tolerate web. Stop investing in web-specific code.**

- Web uses step-based exploration (no GPS)
- Web uses main-thread engine runner (no isolate)
- Web uses WASM SQLite via Drift (accept the performance hit)
- No web-specific optimizations, no web-specific features
- Existing platform splits (`_web.dart` / `_native.dart`) stay where they exist but don't grow

---

## Game Loop Pipeline

Event-driven. Not timer-driven.

```
GPS (1 Hz, displacement-filtered)
  │
  ▼
RubberBandController (60fps vsync, main thread)
  │ interpolated position (10Hz throttled)
  ▼
EngineRunner.send(PositionUpdate)
  │
  ▼
GameEngine._processGameLogic()
  ├── Cell resolution (LazyVoronoi, cached)
  ├── Fog computation (from position + visit history)
  ├── Encounter check (only on NEW cell entry)
  │     └── Species roll (SHA-256 deterministic, queries SpeciesRepository)
  ├── Emit GameEvents (cell_entered, fog_changed, species_discovered)
  └── Observability (timing events for each stage)
  │
  ▼
Event Consumers (provider layer)
  ├── PersistenceConsumer → SQLite + write queue
  ├── Provider projections → UI state (fog, inventory, player)
  └── EventSink → app_events (batched)
```

### Adaptive Tick Rate

The game loop doesn't run on a fixed timer. It processes when there's input:

- **Position update** → full pipeline (cell → fog → encounter → events)
- **Cell tap** → cell info lookup → event
- **Auth change** → hydration or pause → event
- **App lifecycle** → flush events, pause/resume GPS

When the player is stationary, nothing processes. Zero CPU, zero battery.

---

## Principles

1. **Features are user journeys.** If a user can't point at it on screen, it's not a feature. It's infrastructure and belongs in `core/`.

2. **The engine is a firewall.** Errors inside become events, not exceptions. Nothing propagates to the UI. Nothing cascades. Nothing kills the widget tree.

3. **Everything is an event.** A discovery, a cell visit, an error, a hydration completion — same shape, same stream. The event stream IS observability, sync, and state.

4. **Hardware budgets are constraints.** 80 MB RAM. 16.6ms frame. 0 MB for species in memory. These aren't targets — they're ceilings.

5. **No prototyping shortcuts.** Pre-compiled SQLite, not parsed JSON. Raster fog, not polygon-per-cell. One cell implementation, not three. The right solution, not the quick one.

6. **The map is a dumb renderer.** It receives events and draws them. No game logic, no state management, no persistence. Just pixels.

7. **Ship the compiled artifact.** Species data, biome data, any large dataset — compile to SQLite at build time. Parse text at build time. Query binary at runtime.

8. **Web is dev/test.** Build for mobile phones. Tolerate web browsers. Don't optimize for web.

---

## Migration Path (Current → Target)

### Phase 0: Decompose `game_coordinator_provider.dart`

This 1,832-line file is the actual architecture. It imports from 30+ modules, hydrates 4 data sources, wires 10+ callbacks, manages auth, triggers enrichment, and handles persistence. Every subsequent phase touches this file. Decompose it first.

| Action | Effort |
|--------|--------|
| Extract hydration logic into `HydrationService` | 2 hr |
| Extract persistence wiring into `PersistenceConsumer` | 2 hr |
| Extract enrichment wiring into `EnrichmentConsumer` | 1 hr |
| Slim provider to: create engine, wire consumers, expose coordinator | 1 hr |

**Result:** Provider file drops from 1,832 lines to ~300. Each consumer is independently testable.

### Phase A: Dead Code + Feature Reorganization

Delete dead code. Reorganize features. Create new concept features. Zero behavior change.

| Action | Effort |
|--------|--------|
| Delete H3CellService, VoronoiCellService, legacy constants | 1 hr |
| Fold `enrichment/` (1 file) → `sync/providers/` | 30 min |
| Move `seasonal/` → `features/calendar/` (new feature) | 1 hr |
| Move `biome/` + `restoration/` + cell property resolver + event resolver → `features/world/` (new feature) | 2 hr |
| Move `navigation/` TabShell → `main.dart` or `shared/` | 1 hr |
| Create `features/items/` (extract item services + providers from core/state/) | 2 hr |
| Merge `core/game/` into `core/engine/` | 1 hr |
| Update all import paths + tests + AGENTS.md files | 3 hr |

**Result:** 16 → 14 features. 2 non-concepts folded (enrichment, navigation). 3 new concept features created (calendar, world, items). Dead code deleted. Import paths stabilized before heavier phases.

### Phase B: Species SQLite

Replace in-memory JSON parsing with pre-compiled SQLite.

| Action | Effort |
|--------|--------|
| Write `tool/compile_species_db.dart` build script | 2 hr |
| Create `species_definitions` table schema | 30 min |
| Create `SpeciesRepository` (query interface) | 2 hr |
| Create `SpeciesCache` (LRU, 2K cap) | 1 hr |
| Rewire `LootTable` to query `SpeciesRepository` | 2 hr |
| Delete `SpeciesDataLoader`, `speciesDataProvider` | 30 min |
| Update tests | 2 hr |

**Result:** 0 MB species in RAM. Startup time drops. 33K species queryable in <1ms.

### Phase C: Fog Rendering

**Current state:** Two fog renderers already exist:
1. `FogCanvasPainter` — Canvas compositing (raster-like, already implemented)
2. `FogGeoJsonBuilder` — 3-layer native GeoJSON via MapLibre

**Decision needed:** Profile both. Pick the one with better frame budget numbers. If neither meets the 4ms fog budget, then build a MapLibre `ImageSource` raster overlay. Don't build a third renderer without evidence the existing two fail.

| Action | Effort |
|--------|--------|
| Profile `FogCanvasPainter` vs `FogGeoJsonBuilder` (measure frame times) | 2 hr |
| Pick winner, delete loser | 1 hr |
| If neither meets budget: build `ImageSource` raster overlay | 4 hr |
| Separate cell boundary lines from fog fill (regardless of approach) | 1 hr |
| Wire fog state changes → regeneration only on state change (not camera pan) | 1 hr |

**Result:** Fog rendering cost fixed to viewport size. Scales to unlimited explored cells.

### Phase D: Observability Completion

Engine event foundation exists (Phases 1–5 of engine-architecture.md, partially done). Complete it.

| Action | Effort |
|--------|--------|
| Event emission from all coordinator callbacks (complete coverage) | 2 hr |
| EventSink batch flush to `app_events` (30s + on background) | 2 hr |
| Performance timing events (fog, GeoJSON, SQLite, API) | 2 hr |
| Local `app_events` SQLite table for offline sessions | 1 hr |
| Dashboard query templates (session timeline, crash rate, DAU) | 1 hr |

**Result:** Full observability. Any session reconstructable. Fleet health queryable.

### Phase Order

```
Phase A (consolidation) — no dependencies, safe, immediate
    ↓
Phase B (species SQLite) — independent of C and D
Phase C (raster fog) — independent of B and D
Phase D (observability) — independent of B and C
```

B, C, D are independent and can be worked in any order or in parallel.

---

## What Stays Unchanged

These are already correct:

- **`core/models/`** — 24 immutable value objects, sealed classes
- **`core/database/`** — Drift ORM, schema version 13
- **`core/persistence/`** — 7 repositories, clean abstractions
- **`core/fog/`** — Computed fog from position + visits, never persisted
- **Deterministic encounters** — SHA-256(dailySeed + cellId), daily rotation
- **Server-authoritative** — Supabase source of truth, SQLite cache + write queue
- **Riverpod v3 Notifier pattern** — consistent, correct
- **`shared/`** — Design tokens, theme, constants
- **GameEvent model** — envelope with sessionId, userId, deviceId, category, event, data
- **Engine firewall** — errors become events, never exceptions
- **Write queue** — debounced, batched, retry with backoff

---

## Open Issues

Issues identified during architecture review that need resolution before or during implementation.

| # | Issue | Impact | Resolution |
|---|-------|--------|------------|
| 1 | **Species SQLite on web**: WASM SQLite can't open a pre-compiled `.db` asset the same way native can. Web may need a different loading path or first-run import. | Blocks Phase B for web | Acceptable — web is dev/test only. Build for native, tolerate web. |
| 2 | **`world/` naming**: Users don't think "world." Closer to infrastructure. But it IS shared state that's distinct from player state. | Naming clarity | Open — keep `world/` or rename to `terrain/` or `environment/` |
| 3 | **Species SQLite build integration**: When does `compile_species_db.dart` run? CI? Local? Is the `.db` committed or generated? | Phase B implementation detail | Decide during Phase B. Likely: generated in CI, committed as asset. |
| 4 | **LootTable async migration**: Current LootTable takes `List<FaunaDefinition>` synchronously. SQLite queries are async. Every call site that builds a LootTable breaks. | Phase B complexity | LootTable must pre-fetch candidates async, then roll synchronously from the cached set. |
| 5 | **EventSink error recovery**: What happens when Supabase is unreachable for days? Local `app_events` grows unbounded? | Phase D reliability | Add retention cap to local events (e.g., 10K rows). Accept data loss for old events. |
| 6 | **GameEvent volume**: Fog changes at 10Hz when walking. 36K events/hour would flood the buffer. | Phase D design | NOT all fog changes are events. Only fog STATE TRANSITIONS (unexplored → observed) are events, not every recomputation. |

---

## Superseded Documents

| Document | Status | What to Use Instead |
|----------|--------|---------------------|
| `architecture.md` | Historical — describes current state | This doc (target state) |
| `current-architecture.md` | Historical — how it works today | This doc + codebase |
| `engine-architecture.md` | Historical — engine migration phases | This doc § Observability + § Migration. Phase details remain as implementation reference. |
| `ideal-architecture.md` | Historical — server-authoritative decisions | This doc. Design decisions from ideal-architecture.md are incorporated here. |
