# Current Architecture

> How the system works today. For where it should go, see [ideal-architecture.md](ideal-architecture.md).

---

## System Overview

Flutter 3.41.3 web/mobile app. Offline-first with optional Supabase backend. GPS-driven game loop reveals fog-of-war map, discovers species from 32k IUCN dataset, tracks collection and streaks.

```
┌──────────────────────────────────────────────────────────┐
│                    Flutter App (Dart)                      │
│                                                           │
│  GPS (1 Hz) → RubberBand (60 fps) → Game Logic (~10 Hz)  │
│       ↓              ↓                     ↓              │
│  GeoLocator    MapLibre Camera     FogResolver + Discovery│
│                                          ↓                │
│                              Riverpod Notifiers (in-memory)│
│                                          ↓                │
│                              Drift SQLite (offline source) │
│                                          ↓ (write-through)│
│                              Supabase (optional cloud)     │
└──────────────────────────────────────────────────────────┘
```

**~130 Dart source files, ~34k lines.** 14 features, 7 core modules, 1154 tests.

---

## State Management

### Pattern: Riverpod v3 Notifier

All mutable state uses `NotifierProvider<T, S>`. 28 providers total (9 core, 12 feature, 7 map).

**State lifecycle:**
1. `build()` returns initial state (empty map, default enum, etc.)
2. Methods mutate via `state = newState` (immutable replacement)
3. `ref.watch()` in `build()` for reactive deps, `ref.read()` in methods for one-shot

**Key characteristic: state lives in memory only.** Notifiers don't auto-persist. Persistence is a manual step — the caller decides when to write to SQLite. This means:
- App restart = state lost (unless explicitly saved/loaded)
- No replay capability — if a state update is missed, it's gone
- Fog state is computed on-demand (never persisted — this is intentional and correct)
- Player stats, collection, cell progress ARE persisted but loaded manually at startup

### State ↔ Persistence Gap

```
User action → Notifier.method() → state = newState → UI rebuilds
                                        ↓
                         (sometimes) Repository.write() → SQLite
                                        ↓
                         (sometimes) SupabasePersistence.upsert() → Cloud
```

The "sometimes" is the problem. There's no guaranteed persistence pipeline. Each feature decides independently when/whether to persist. Example:
- `fogProvider` — NEVER persists (correct — fog is computed)
- `playerProvider` — persists via `ProfileRepository` (manual calls from caretaking)
- `inventoryProvider` — persists via `ItemInstanceRepository` (on each discovery)
- `achievementProvider` — does NOT persist (state lost on restart)

---

## Data Flow

### GPS → Screen Pipeline (the "game loop")

```
GPS/Simulator → LocationUpdate (1 Hz)
  → RubberBandController interpolates (60 fps)
    → Display position updates:
        1. PlayerMarkerLayer (ValueNotifier → widget rebuild)
        2. CameraController (MapLibre moveCamera)
        3. Game logic (throttled to ~10 Hz):
           → FogResolver: compute fog states for visible cells
           → FogOverlayController: build 3 GeoJSON layers (base, mid, border)
           → MapLibre: updateGeoJsonSource × 3
```

**Everything hangs off GPS.** No GPS = no game logic = no fog updates = no discoveries. The map screen is the orchestrator — it owns the GPS subscription, rubber-band controller, game loop throttle, and all rendering coordination.

### Discovery Pipeline

```
FogResolver.onVisitedCellAdded (sync stream, fired when player enters new cell)
  → DiscoveryService.processCell()
    → SpeciesService.getSpeciesForCell(cellId, habitats, continent)
    → Deterministic roll: SHA-256(cellId) → seed → LootTable.roll()
    → 3 species per cell (fixed, same every time)
  → DiscoveryEvent emitted on stream
  → map_screen subscribes → discoveryProvider.showDiscovery()
  → DiscoveryNotificationOverlay → toast
```

**Discovery is tightly coupled to map_screen.** The subscription lives in `_MapScreenState.initState()`. If map isn't mounted, discoveries don't process.

### Auth Flow

```
App start → SupabaseBootstrap.initialize() (3s timeout)
  → AuthNotifier.build() → check Supabase session
    → Has session? → authenticated (with UserProfile)
    → No session? → auto anonymous sign-in → authenticated (isAnonymous: true)
    → No Supabase? → MockAuthService → authenticated (mock user)
  → upgradePromptProvider watches auth + collection
    → Anonymous + ≥5 species → show save-progress banner
    → User taps → UpgradeBottomSheet (email / Google / Apple)
    → upgradeWithEmail() or linkOAuthIdentity() on AuthService
```

---

## Persistence Architecture

### Three Layers

| Layer | Technology | Role |
|-------|-----------|------|
| In-memory | Riverpod notifiers | UI state, computed values, ephemeral |
| Local DB | Drift (SQLite) | Source of truth, offline-first |
| Cloud | Supabase | Write-through backup (optional, manual) |

### SQLite Schema (3 tables)

- `LocalPlayerProfileTable` — display name, streaks, distance, season
- `LocalCellProgressTable` — per-cell fog state, visits, restoration, distance
- `LocalItemInstanceTable` — item instances with affixes, status, parentage (schema v2)

### Repository Pattern

3 repositories wrap `AppDatabase`: `ProfileRepository`, `CellProgressRepository`, `ItemInstanceRepository`. All return `Future<T>`. No reactive streams from DB — pull only.

### Supabase Integration

```
SupabasePersistence (nullable — null when no credentials)
  .upsertProfile()
  .upsertCellProgress()
  .upsertItemInstance()
```

Write-through: every local write optionally also writes to Supabase. No queue, no retry, no conflict resolution. If Supabase write fails, local data is fine but cloud is stale.

**Sync screen** provides manual "Sync Now" button. No background sync, no real-time subscriptions.

---

## Feature Coupling

### The Map Problem

`features/map/` is 25 files and acts as the game's orchestration hub:
- Owns GPS subscription lifecycle
- Runs the game loop (fog computation, discovery triggers)
- Manages 3 GeoJSON fog layers + player marker
- Coordinates camera modes (follow vs free)
- Handles discovery event subscriptions
- Processes cell visits → caretaking → achievements

**This is the single biggest architectural risk.** Every new game mechanic (daily seed, cell activities, weather spawns, NPC discovery) will need to plug into map_screen, making it grow indefinitely.

### Feature Boundary Health

| Feature | Coupling | Notes |
|---------|----------|-------|
| map | **High** — orchestrates 6+ other features | God feature, needs decomposition |
| achievements | Medium — reads 4 providers, pull-based | Clean pattern but no persistence |
| pack/sanctuary | Medium — watches species + collection | Healthy reactive pattern |
| auth | Low — leaf feature, only reads supabase bootstrap | Clean |
| location/biome/seasonal | **None** — pure services | Ideal leaf pattern |
| sync | Low — reads auth, writes to Supabase | Clean but limited (no queue) |

---

## Species Data Pipeline

**Input:** `assets/species_data.json` — 32,752 IUCN records, ~6 MB.

**Loading:** `SpeciesDataLoader` reads entire file at startup, parses into `List<FaunaDefinition>`. All species live in memory for the app's lifetime.

**Querying:** `SpeciesService` filters in-memory list by habitat, continent, season. No index, no pagination — linear scan.

**Loot table:** `LootTable` uses IUCN status → 10^x weight mapping. SHA-256(cellId) seeds the RNG for deterministic per-cell species.

**Habitat resolution:** `BiomeService` maps ESA WorldCover codes → 7 habitats. Currently uses `DefaultHabitatLookup` (returns Plains for everything) until GeoTIFF integration.

---

## Cell System

**Primary:** Voronoi tessellation via `LazyVoronoiCellService`. Generates cells on-demand per tile, cached in `CellCache` (LRU, max 10 tiles).

**Fallback:** H3 hexagons via `h3_flutter_plus` (FFI). Exists but not default.

**Cell lifecycle:**
1. Map viewport determines visible tiles
2. `CellService.getCellsForTile()` → generates/caches Voronoi cells
3. `FogResolver` computes fog state per cell (position + history)
4. `FogOverlayController` builds GeoJSON polygons with opacity per fog level
5. MapLibre renders 3 layers (base fog, mid fog, cell borders)

---

## Testing

1154 tests, `flutter_test` only. No mockito — all mocks are hand-written (`Mock<Interface>` pattern). Tests mirror `lib/` directory structure. 5 integration suites test full persistence round-trips with in-memory Drift databases.

---

## Known Architectural Tensions

| Tension | Impact | Severity |
|---------|--------|----------|
| Map is a god feature | Every new mechanic increases map complexity | 🔴 High |
| State ↔ persistence gap | Achievements, some player state lost on restart | 🟡 Medium |
| No domain events | Can't replay, audit, or sync reliably | 🟡 Medium |
| 6 MB species data in memory | Startup cost, memory pressure on low-end devices | 🟡 Medium |
| No offline sync queue | Supabase writes are fire-and-forget | 🟡 Medium |
| Habitat lookup is a stub | All cells return Plains habitat until GeoTIFF integration | 🟡 Medium |
| Discovery coupled to map mount | Species encounters only process when map screen is active | 🟠 Low-Med |
| No DI beyond Riverpod | Service creation scattered across providers | 🟢 Low |
