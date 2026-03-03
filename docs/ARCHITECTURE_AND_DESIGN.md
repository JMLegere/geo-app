# Fog of World — Architecture & Design

> **iNaturalist × Stardew Valley × Pokémon Go**  
> Explore the real world via GPS, reveal fog-of-war, discover 33k real IUCN species, build a sanctuary, restore habitats.

This document serves as both a technical architecture reference and a game design document for developers joining the Fog of World project. It explains what the game is, how it works, and how the code is structured.

---

## Table of Contents

**Part 1 — Game Design**
- [Elevator Pitch & Core Loop](#elevator-pitch--core-loop)
- [Fog-of-War System](#fog-of-war-system)
- [Species Encounter System](#species-encounter-system)
- [Habitats & Biomes](#habitats--biomes)
- [Continents & Geographic Distribution](#continents--geographic-distribution)
- [Seasonal System](#seasonal-system)
- [Restoration Mechanic](#restoration-mechanic)
- [Sanctuary](#sanctuary)
- [Achievement System](#achievement-system)
- [Caretaking & Daily Streaks](#caretaking--daily-streaks)
- [Game Balance Constants](#game-balance-constants)

**Part 2 — Technical Architecture**
- [High-Level Module Diagram](#high-level-module-diagram)
- [State Management](#state-management)
- [Data Flow Pipeline](#data-flow-pipeline)
- [Persistence Layer](#persistence-layer)
- [Cell System](#cell-system)
- [Map Rendering Pipeline](#map-rendering-pipeline)
- [Service Injection Pattern](#service-injection-pattern)
- [Auth System](#auth-system)
- [Key Architectural Decisions](#key-architectural-decisions)

**Part 3 — Data Model**
- [Database Schema](#database-schema)
- [Domain Models](#domain-models)
- [Species Data Format](#species-data-format)

---

# Part 1 — Game Design

## Elevator Pitch & Core Loop

**Fog of World** is a real-world exploration game that turns your neighborhood into a living biodiversity catalog. Walk around with your phone, reveal the fog-of-war on a map, and discover real species from the IUCN Red List. Collect species to restore habitats, build a sanctuary, and track your exploration progress.

### Core Loop

```
Walk → Reveal fog → Discover species → Collect → Restore habitats → Repeat
```

1. **Walk**: GPS tracks your real-world movement
2. **Reveal**: Cells you visit transition from fogged to observed
3. **Discover**: Each cell contains 3 deterministic species encounters
4. **Collect**: Add species to your collection
5. **Restore**: 3 unique species per cell = fully restored habitat
6. **Repeat**: Explore new areas, complete achievements, build your sanctuary

### Design Philosophy

- **Offline-first**: Everything works without network. Supabase sync is optional.
- **Deterministic encounters**: Same cell always yields the same species (seeded by cell ID).
- **Real biodiversity**: 32,752 real IUCN species records, not fictional creatures.
- **Computed fog state**: Fog is derived from player position + visit history, like Civilization fog-of-war.
- **No grinding**: 3 species per cell = fully restored. No infinite collection treadmill.

---

## Fog-of-War System

The fog-of-war is the core mechanic. The map starts fully fogged. As you move, cells reveal themselves based on your proximity and visit history.

### The 5 Fog States

| State | Density | Condition | Description |
|-------|---------|-----------|-------------|
| **Undetected** | 1.0 (opaque) | >50 km from player, never visited | Completely hidden |
| **Unexplored** | 0.75 | Within 50 km OR adjacent to visited cell | Detected but not entered |
| **Hidden** | 0.5 | Previously visited, not in current view | You've been here before |
| **Concealed** | 0.25 | Adjacent to current cell | Nearby, partially visible |
| **Observed** | 0.0 (transparent) | Player is currently in this cell | Fully revealed |

### How Fog Works

Fog state is **computed on-demand**, not stored. The only persisted data is the set of cell IDs you've physically entered. When you move:

1. `FogStateResolver.onLocationUpdate(lat, lon)` is called
2. Your current cell becomes **Observed**
3. Immediate neighbors become **Concealed**
4. Previously visited cells become **Hidden**
5. Cells within 50 km become **Unexplored**
6. Everything else stays **Undetected**

This is **dynamic** — leaving a cell transitions it from Observed → Hidden immediately. This is intentional, not a bug. It mimics Civilization/StarCraft fog-of-war.

### Detection Radius

The 50 km detection radius (`kDetectionRadiusMeters`) means you can see a large area around you even without visiting every cell. This prevents the map from feeling claustrophobic and rewards exploration.

### Exploration Frontier

When you visit a new cell, its unvisited neighbors are added to the "exploration frontier" — a set of cells that are Unexplored. This creates a natural expansion pattern as you explore.

### Code Reference

- **Fog computation**: `lib/core/fog/fog_state_resolver.dart`
- **Fog states**: `lib/core/models/fog_state.dart`
- **Detection radius constant**: `lib/shared/constants.dart` (`kDetectionRadiusMeters`)

```dart
// Example: Resolving fog state for a cell
final fogState = fogResolver.resolve(cellId);
// Returns: FogState.observed, .concealed, .hidden, .unexplored, or .undetected
```

---

## Species Encounter System

Each cell contains **3 deterministic species encounters**. Same cell always yields the same species.

### How Encounters Work

1. **Cell ID as seed**: When you enter a cell, its ID is hashed (SHA-256) to generate a deterministic seed
2. **Filter by habitat + continent**: Species pool is filtered to match the cell's habitat and your current continent
3. **Weighted random selection**: Species are rolled from a loot table weighted by IUCN rarity
4. **3 unique species**: The system rolls up to 3 unique species per cell (no duplicates)

### IUCN Rarity as Loot Weights

Species rarity follows a **Path of Exile-style 10^x progression**:

| IUCN Status | Weight | Rarity |
|-------------|--------|--------|
| Least Concern (LC) | 100,000 | Very common |
| Near Threatened (NT) | 10,000 | Common |
| Vulnerable (VU) | 1,000 | Uncommon |
| Endangered (EN) | 100 | Rare |
| Critically Endangered (CR) | 10 | Very rare |
| Extinct (EX) | 1 | Ultra rare |

Higher weight = more common. Each tier is 10x rarer than the one above it.

### Determinism

The same cell ID always produces the same species. This is intentional:
- **Reproducibility**: You can revisit a cell and see the same species
- **Fairness**: Everyone who visits the same cell gets the same encounters
- **No RNG manipulation**: You can't "reroll" by leaving and re-entering

### Code Reference

- **Species service**: `lib/core/species/species_service.dart`
- **Loot table**: `lib/core/species/loot_table.dart`
- **IUCN weights**: `lib/core/models/iucn_status.dart`

```dart
// Example: Getting species for a cell
final species = speciesService.getSpeciesForCell(
  cellId: 'voronoi_37.7749_-122.4194',
  habitat: Habitat.forest,
  continent: Continent.northAmerica,
  encounterSlots: 3, // default
);
// Returns: List<SpeciesRecord> (up to 3 unique species)
```

---

## Habitats & Biomes

The game has **7 habitats**, mapped from ESA WorldCover land classification data.

### The 7 Habitats

| Habitat | ESA Land Cover Classes | Color | Description |
|---------|------------------------|-------|-------------|
| **Forest** | Tree cover | Dark green | Dense woodland |
| **Plains** | Grassland, cropland, built-up, shrubland | Yellow-green | Open grasslands, farms, cities |
| **Freshwater** | Permanent water bodies | Blue | Lakes, rivers, ponds |
| **Saltwater** | (Ocean cells) | Teal | Oceans, seas |
| **Swamp** | Herbaceous wetland, mangroves | Olive green | Marshes, swamps |
| **Mountain** | Snow/ice, moss/lichen | Brown | High elevation, tundra |
| **Desert** | Bare/sparse vegetation | Tan | Arid regions |

### ESA WorldCover Mapping

The game uses ESA WorldCover v2 land classification codes to assign habitats to cells:

```dart
// ESA code → Habitat mapping
10 (tree cover) → Forest
20 (shrubland) → Plains
30 (grassland) → Plains
40 (cropland) → Plains
50 (built-up) → Plains
60 (bare/sparse) → Desert
70 (snow/ice) → Mountain
80 (permanent water) → Freshwater
90 (herbaceous wetland) → Swamp
95 (mangroves) → Swamp
100 (moss/lichen) → Mountain
```

### Habitat Classification

Currently, the app uses a **fallback strategy** — all cells default to Plains unless ESA data is loaded. The `HabitatService` supports pluggable lookup strategies:

- **DefaultHabitatLookup**: Always returns Plains (current default)
- **CoordinateHabitatLookup**: In-memory map of grid cells → ESA codes (for future GeoTIFF integration)

### Code Reference

- **Habitat enum**: `lib/core/models/habitat.dart`
- **ESA mapping**: `lib/features/biome/models/esa_land_cover.dart`
- **Habitat service**: `lib/features/biome/services/biome_service.dart`

---

## Continents & Geographic Distribution

Species are filtered by **6 continents** to ensure geographic realism.

### The 6 Continents

1. **Asia**
2. **North America**
3. **South America**
4. **Africa**
5. **Oceania**
6. **Europe**

### Continent Resolution

Your GPS coordinates are mapped to a continent using bounding boxes:

```dart
// Example bounding boxes (simplified)
Europe: lat 35-72, lon -25 to 45
Africa: lat -35 to 38, lon -20 to 52 (split at 20°E)
Asia: lat -12 to 82, lon 25 to 180
North America: lat 7-84, lon -170 to -50
South America: lat -60 to 15, lon -82 to -34
Oceania: lat -50 to 0, lon 110 to 180
```

The `ContinentResolver` uses these boxes to determine which continent you're in. Species encounters are filtered to only include species native to your continent.

### Code Reference

- **Continent enum**: `lib/core/models/continent.dart`
- **Continent resolver**: `lib/core/species/continent_resolver.dart`

---

## Seasonal System

The game has **2 seasons**: Summer and Winter. Species availability changes with the season.

### Season Definitions

| Season | Months | Description |
|--------|--------|-------------|
| **Summer** | May–October | Warm season |
| **Winter** | November–April | Cold season |

### Species Availability

Each species is assigned a seasonal availability:

- **80%** are **year-round** (available in both seasons)
- **10%** are **summer-only**
- **10%** are **winter-only**

This assignment is **deterministic** — based on the species ID hash. Same species always has the same availability.

### How It Works

When you enter a cell, the species pool is filtered by the current season:

1. Determine current season from `DateTime.now()` (May–Oct = summer, Nov–Apr = winter)
2. Filter species pool to only include year-round + current season species
3. Roll 3 species from the filtered pool

### Code Reference

- **Season enum**: `lib/core/models/season.dart`
- **Season service**: `lib/features/seasonal/services/season_service.dart`
- **Seasonal availability**: `lib/features/seasonal/models/seasonal_species.dart`

```dart
// Example: Filtering species by season
final currentSeason = Season.fromDate(DateTime.now());
final availableSpecies = seasonService.filterBySeason(allSpecies, currentSeason);
```

---

## Restoration Mechanic

Restoring habitats is the core progression system. Collect species to restore cells.

### Restoration Formula

```
restorationLevel = min(uniqueSpeciesCount, 3) / 3.0
```

- **0 species** = 0% restored
- **1 species** = 33% restored
- **2 species** = 67% restored
- **3 species** = 100% restored (fully restored)

### How It Works

1. Enter a cell and discover species
2. Collect a species (add to your collection)
3. The cell's restoration level increases by 1/3
4. At 3 unique species, the cell is fully restored

### Why 3 Species?

This is a deliberate design choice:
- **No grinding**: You can't collect the same species twice in the same cell
- **Achievable goal**: 3 species is a clear, finite target
- **Encourages exploration**: To restore more cells, you need to visit new areas

### Code Reference

- **Restoration service**: `lib/features/restoration/services/restoration_service.dart`

```dart
// Example: Recording a collection
restorationService.recordCollection(cellId, speciesId);
final level = restorationService.getRestorationLevel(cellId);
// Returns: 0.0, 0.33, 0.67, or 1.0
```

---

## Sanctuary

The sanctuary is your personal species collection, grouped by habitat.

### What It Shows

- **Species by habitat**: All collected species, organized by their primary habitat
- **Collection progress**: Total collected / total available
- **Health percentage**: Overall completion (collected / pool size)
- **Current streak**: Daily visit streak (from caretaking system)

### How It Works

The sanctuary is a **computed view** of your collection:

1. Load all species from the IUCN dataset
2. Filter to only collected species (by ID)
3. Group by primary habitat (first habitat in the species' habitat list)
4. Display in a scrollable list

### Code Reference

- **Sanctuary provider**: `lib/features/sanctuary/providers/sanctuary_provider.dart`
- **Sanctuary screen**: `lib/features/sanctuary/screens/sanctuary_screen.dart`

---

## Achievement System

Achievements track your exploration milestones.

### Achievement Categories

| Category | Examples |
|----------|----------|
| **Exploration** | First Steps (1 cell), Explorer (10 cells), Cartographer (50 cells) |
| **Collection** | Naturalist (10 species), Biologist (50 species), Taxonomist (100 species) |
| **Habitat Mastery** | Forest Friend (all forest species), Ocean Explorer (all saltwater species) |
| **Dedication** | Dedicated (7-day streak), Devoted (30-day streak) |
| **Distance** | Marathon (10 km walked) |
| **Restoration** | Restorer (10 fully restored cells) |

### How Achievements Work

Achievements are **evaluated on every state change**:

1. Player stats change (cells explored, species collected, streak updated, etc.)
2. `AchievementService.evaluate()` is called with the new stats
3. Each achievement's condition is checked
4. If the condition is met and the achievement is not yet unlocked, it unlocks
5. A toast notification is shown

### Code Reference

- **Achievement service**: `lib/features/achievements/services/achievement_service.dart`
- **Achievement models**: `lib/features/achievements/models/achievement.dart`

```dart
// Example: Evaluating achievements
final context = AchievementContext(
  cellsObserved: 10,
  speciesCollected: 5,
  currentStreak: 3,
  totalDistanceKm: 2.5,
  restoredCellCount: 1,
  collectedByHabitat: {'Forest': 3, 'Plains': 2},
  totalByHabitat: {'Forest': 100, 'Plains': 150},
);
final newState = achievementService.evaluate(currentState, context);
```

---

## Caretaking & Daily Streaks

Caretaking tracks your daily visit streak — how many consecutive days you've played.

### Streak Rules

- **First visit**: Streak = 1
- **Same day visit**: No change (no double-counting)
- **Consecutive day visit**: Streak increments by 1
- **Missed day**: Streak resets to 1, longest streak is preserved

### How It Works

1. On app launch, check if you've visited today
2. If not, call `CaretakingService.recordVisit()`
3. Compare last visit date to today
4. Update current streak and longest streak
5. Sync to player profile

### Code Reference

- **Caretaking service**: `lib/features/caretaking/services/caretaking_service.dart`
- **Caretaking state**: `lib/features/caretaking/models/caretaking_state.dart`

```dart
// Example: Recording a visit
final newState = caretakingService.recordVisit(currentState, DateTime.now());
// Returns: CaretakingState with updated streak
```

---

## Game Balance Constants

All game-balance values are centralized in `lib/shared/constants.dart`:

| Constant | Value | Purpose |
|----------|-------|---------|
| `kDetectionRadiusMeters` | 50,000 m (50 km) | Fog detection radius |
| `kFogLevels` | 5 | Number of fog states |
| `kHabitatCount` | 7 | Number of habitats |
| `kIucnStatusTiers` | 6 | Number of rarity tiers |
| `kSeasons` | 2 | Number of seasons |
| `kContinentCount` | 6 | Number of continents |
| `kGpsAccuracyThreshold` | 50 m | GPS accuracy threshold |
| `kGpsUpdateFrequency` | 1 Hz | GPS update rate |
| `kMinZoom` | 12.0 | Minimum map zoom |
| `kMaxZoom` | 18.0 | Maximum map zoom |
| `kDefaultZoom` | 15.0 | Default map zoom |

These constants are used throughout the codebase to ensure consistency and simplify tuning.

---

# Part 2 — Technical Architecture

## High-Level Module Diagram

```
lib/
├── main.dart                   # App entry point (ProviderScope → FogOfWorldApp)
├── core/                       # Domain logic, models, state, persistence (NO UI)
│   ├── cells/                  # Spatial indexing (CellService interface + impls)
│   ├── config/                 # SupabaseConfig (env vars)
│   ├── database/               # Drift ORM (3 tables)
│   ├── fog/                    # FogStateResolver (computed visibility)
│   ├── models/                 # 8 immutable value objects
│   ├── persistence/            # Repository pattern (3 repos)
│   ├── species/                # Loot table, species loader, continent resolver
│   └── state/                  # Riverpod providers (fog, location, collection, season)
├── features/                   # Feature modules (UI + feature-specific logic)
│   ├── achievements/           # Achievement tracking + toast notifications
│   ├── auth/                   # Mock auth (swappable to Supabase)
│   ├── biome/                  # ESA land cover → habitat mapping
│   ├── caretaking/             # Daily visit streaks
│   ├── discovery/              # Species encounter events
│   ├── journal/                # Collection viewer with filters
│   ├── location/               # GPS, simulation, filtering (services only)
│   ├── map/                    # Map rendering, fog overlay, camera (14 files)
│   ├── restoration/            # Cell restoration progress
│   ├── sanctuary/              # Species sanctuary grouped by habitat
│   ├── seasonal/               # Summer/winter species availability
│   └── sync/                   # Offline-first sync to Supabase
└── shared/
    ├── constants.dart          # All game-balance constants
    └── widgets/                # Reusable UI components
```

### Module Boundaries

- **core/**: Pure business logic. No Flutter dependencies. No UI. Testable without widgets.
- **features/**: Feature-specific logic + UI. Can depend on core/, but not on other features/.
- **shared/**: Cross-cutting concerns (constants, theme, reusable widgets).

### Dependency Rules

```
features/ → core/ → models/
   ↓
shared/
```

- Features can depend on core/ and shared/
- Core can depend on models/ and external packages (geobase, drift, riverpod)
- Models have no dependencies (pure value objects)

---

## State Management

The app uses **Riverpod 3.2.1** with the **Notifier pattern** (not StateNotifier, not ChangeNotifier).

### Riverpod v3 Notifier Pattern

All mutable state uses `NotifierProvider<T, S>`:

```dart
// Provider definition
final fogProvider = NotifierProvider<FogNotifier, Map<String, FogState>>(
  () => FogNotifier(),
);

// Notifier implementation
class FogNotifier extends Notifier<Map<String, FogState>> {
  @override
  Map<String, FogState> build() {
    // Initialize state
    return {};
  }
  
  void updateCellFogState(String cellId, FogState newState) {
    // Immutable state replacement
    state = {...state, cellId: newState};
  }
}
```

### Key Rules

- `build()` returns the initial state
- `state = newState` triggers listeners (immutable replacement)
- Use `ref.watch()` in `build()` for reactive dependencies
- Use `ref.read()` in methods for one-shot reads
- Guard async gaps with `if (!ref.mounted) return;`

### Global Providers

| Provider | State Type | Purpose |
|----------|------------|---------|
| `fogProvider` | `Map<String, FogState>` | Per-cell fog state |
| `locationProvider` | `LocationState` | Current position, accuracy, tracking status |
| `collectionProvider` | `CollectionState` | Collected species IDs |
| `seasonProvider` | `Season` | Current season (summer/winter) |
| `authProvider` | `AuthState` | Auth status, user ID |

### State Synchronization Patterns

| Pattern | Use Case | Example |
|---------|----------|---------|
| `ref.listen()` in `build()` | React to changes without resetting state | Journal filters persist when collection changes |
| `ref.read(...notifier)` in method | Bidirectional sync between providers | Caretaking syncs streak with PlayerProvider |
| Stream subscription + `ref.onDispose()` | External event source | LocationNotifier subscribes to GPS stream |

### Code Reference

- **Fog provider**: `lib/core/state/fog_provider.dart`
- **Location provider**: `lib/core/state/location_provider.dart`
- **Collection provider**: `lib/core/state/collection_provider.dart`

---

## Data Flow Pipeline

The core game loop follows this pipeline:

```
GPS → Location → Fog → Discovery → Collection → Persistence
```

### Step-by-Step Flow

1. **GPS Update**
   - `LocationService` emits a new position
   - `LocationNotifier` updates `locationProvider` state

2. **Fog Computation**
   - `FogStateResolver.onLocationUpdate(lat, lon)` is called
   - Current cell becomes Observed
   - Neighbors become Concealed
   - Previously visited cells become Hidden
   - `onVisitedCellAdded` stream emits for new cells

3. **Discovery**
   - `DiscoveryService` listens to `onVisitedCellAdded`
   - For each new cell, rolls 3 species from the loot table
   - Emits `DiscoveryEvent` for each species

4. **Collection**
   - UI shows discovery notification
   - User taps "Collect"
   - `CollectionNotifier.addSpecies(speciesId)` is called
   - Species ID is added to `collectionProvider` state

5. **Persistence**
   - `CollectionRepository.addCollectedSpecies()` writes to SQLite
   - If Supabase is configured, `SupabasePersistence.addToCollection()` syncs to cloud

### Code Reference

- **Location service**: `lib/features/location/services/location_service.dart`
- **Fog resolver**: `lib/core/fog/fog_state_resolver.dart`
- **Discovery service**: `lib/features/discovery/services/discovery_service.dart`
- **Collection provider**: `lib/core/state/collection_provider.dart`
- **Collection repository**: `lib/core/persistence/collection_repository.dart`

---

## Persistence Layer

The app uses **Drift 2.14.0** (SQLite ORM) for offline-first persistence.

### Database Schema

3 tables:

#### 1. `LocalCellProgressTable`

Tracks per-cell fog state, distance walked, visit count, restoration level.

| Column | Type | Description |
|--------|------|-------------|
| `id` | TEXT (PK) | Unique ID (UUID) |
| `userId` | TEXT | User ID |
| `cellId` | TEXT | Cell ID |
| `fogState` | TEXT | Fog state (stored as string: 'observed', 'hidden', etc.) |
| `distanceWalked` | REAL | Distance walked in this cell (meters) |
| `visitCount` | INTEGER | Number of visits |
| `restorationLevel` | REAL | Restoration level (0.0–1.0) |
| `lastVisited` | DATETIME | Last visit timestamp |
| `createdAt` | DATETIME | Creation timestamp |
| `updatedAt` | DATETIME | Last update timestamp |

**Unique constraint**: `(userId, cellId)`

#### 2. `LocalCollectedSpeciesTable`

Tracks collected species per user per cell.

| Column | Type | Description |
|--------|------|-------------|
| `id` | TEXT (PK) | Unique ID (UUID) |
| `userId` | TEXT | User ID |
| `speciesId` | TEXT | Species ID (scientific name) |
| `cellId` | TEXT | Cell ID where collected |
| `collectedAt` | DATETIME | Collection timestamp |

**Unique constraint**: `(userId, speciesId, cellId)`

#### 3. `LocalPlayerProfileTable`

Tracks player stats (streaks, distance, season).

| Column | Type | Description |
|--------|------|-------------|
| `id` | TEXT (PK) | User ID |
| `displayName` | TEXT | Display name |
| `currentStreak` | INTEGER | Current daily visit streak |
| `longestStreak` | INTEGER | Longest streak ever |
| `totalDistanceKm` | REAL | Total distance walked (km) |
| `currentSeason` | TEXT | Current season ('summer' or 'winter') |
| `createdAt` | DATETIME | Creation timestamp |
| `updatedAt` | DATETIME | Last update timestamp |

### Repository Pattern

Each table has a corresponding repository:

- **ProfileRepository**: Player profile CRUD
- **CellProgressRepository**: Per-cell fog state + distance + visits
- **CollectionRepository**: Collected species per user per cell

Repositories wrap `AppDatabase` and provide domain-specific methods:

```dart
// Example: Adding a collected species
await collectionRepository.addCollectedSpecies(
  SpeciesRecord(...),
  cellId: 'voronoi_37.7749_-122.4194',
);
```

### Drift Conventions

- **`copyWith` uses `Value<T>` wrappers**: `Value(x)` to set, `Value.absent()` to skip
- **FogState stored as string**: e.g., `'observed'`, `'hidden'`
- **Upsert semantics**: `onConflict: DoUpdate((old) => ...)`
- **Platform-aware**: `connection_native.dart` (file-backed) vs `connection_web.dart` (in-memory)

### Code Reference

- **Database schema**: `lib/core/database/app_database.dart`
- **Repositories**: `lib/core/persistence/`

---

## Cell System

The cell system divides the world into spatial regions. Each cell has a unique ID and a geographic boundary.

### CellService Interface

All game logic depends on the `CellService` interface, not a specific implementation:

```dart
abstract interface class CellService {
  String getCellId(double lat, double lon);
  Geographic getCellCenter(String cellId);
  List<Geographic> getCellBoundary(String cellId);
  List<String> getNeighborIds(String cellId);
  List<String> getCellsInRing(String cellId, int k);
  double get cellEdgeLengthMeters;
  String get systemName;
}
```

### Voronoi Implementation

The production implementation uses **Voronoi tessellation**:

- **Seed points**: Deterministic jittered grid (40×40 = 1,600 cells)
- **Cell membership**: Nearest-neighbor (brute-force O(n))
- **Cell IDs**: String-encoded integer indices (`"0"`, `"1"`, `"42"`, etc.)
- **Neighbor detection**: 50×50 sampling grid scan (built once, cached)

### H3 Fallback

An H3 implementation exists as a fallback:

- **Resolution 10**: ~15 m edge length
- **Cell IDs**: H3 hex strings (e.g., `"8a2a1072b59ffff"`)
- **Neighbor detection**: H3 ring API

### Why Voronoi?

Voronoi cells are **irregular** and **organic**, which makes the fog-of-war feel more natural. H3 hexagons are perfectly regular, which can feel artificial.

### Code Reference

- **CellService interface**: `lib/core/cells/cell_service.dart`
- **Voronoi implementation**: `lib/core/cells/voronoi_cell_service.dart`
- **H3 implementation**: `lib/core/cells/h3_cell_service.dart`

---

## Map Rendering Pipeline

The map is the centerpiece of the app. It renders a MapLibre GL base map with a fog-of-war overlay composited via Canvas.

### Rendering Layers (Bottom to Top)

```
1. MapLibre base map (tiles)
2. Fog canvas overlay (full-screen)
3. Player marker (geo-anchored via WidgetLayer)
4. Status bar (translucent top panel)
5. Discovery notification overlay
6. Debug HUD (toggle-able)
7. Map controls (recenter + debug FABs)
```

### MapLibre Specifics

- **Package**: `maplibre` by josxha v0.1.2 (NOT `maplibre_gl`)
- **Position constructor**: `Position(lng, lat)` — **longitude first!**
- **Camera animation**: `MapController.animateCamera(center: Position(lng, lat), nativeDuration: Duration(...))`

### Fog Overlay Rendering

The fog overlay uses **Canvas compositing** to punch holes in the fog layer:

```dart
// Pseudo-code
canvas.saveLayer();
canvas.drawRect(fullScreen, fogColor); // Fill with fog
for (cell in visibleCells) {
  canvas.drawPath(cell.polygon, clearPaint); // Punch hole with BlendMode.dstOut
}
canvas.restore();
```

**FogState density values** map to opacity:
- 1.0 = fully fogged (Undetected)
- 0.75 = Unexplored
- 0.5 = Hidden
- 0.25 = Concealed
- 0.0 = fully revealed (Observed)

### Fog Overlay Controller

`FogOverlayController` computes the list of `CellRenderData` for the current viewport:

1. **Discover visible cells**: Grid-sample the viewport + 20% padding
2. **Expand by one ring**: Add neighbors to cover edge gaps
3. **Resolve fog state**: Skip Undetected cells (stay fully fogged)
4. **Project to screen**: Convert cell boundary vertices to screen coordinates
5. **Increment render version**: Trigger repaint

### Mercator Projection

`MercatorProjection` converts between geographic coordinates and screen coordinates:

```dart
// Geographic → Screen
final screenPoint = MercatorProjection.geoToScreen(
  lat: 37.7749, lon: -122.4194,
  cameraLat: 37.7749, cameraLon: -122.4194,
  zoom: 15.0, viewportSize: Size(400, 800),
);

// Screen → Geographic
final geo = MercatorProjection.screenToGeo(
  screenPoint: Offset(200, 400),
  cameraLat: 37.7749, cameraLon: -122.4194,
  zoom: 15.0, viewportSize: Size(400, 800),
);
```

### Camera Modes

- **Follow mode**: Camera locked to player position, updates on location change
- **Free mode**: User can pan/zoom freely, camera does not follow player

### Code Reference

- **Map screen**: `lib/features/map/map_screen.dart`
- **Fog overlay controller**: `lib/features/map/controllers/fog_overlay_controller.dart`
- **Fog canvas overlay**: `lib/features/map/layers/fog_canvas_overlay.dart`
- **Fog canvas painter**: `lib/features/map/layers/fog_canvas_painter.dart`
- **Mercator projection**: `lib/features/map/utils/mercator_projection.dart`

---

## Service Injection Pattern

Services are **pure Dart classes** with no Riverpod dependency. They receive dependencies via constructor or method parameters.

### Service Pattern

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

### Provider Injection

Services are provided via Riverpod providers:

```dart
final achievementServiceProvider = Provider<AchievementService>(
  (ref) => const AchievementService(),
);
```

### Why This Pattern?

- **Testability**: Services can be tested without Riverpod (no `ProviderContainer` needed)
- **Reusability**: Services can be used in isolates, background tasks, or non-Flutter contexts
- **Separation of concerns**: Business logic is decoupled from state management

### Exception

`SyncService` reads `authProvider` because it needs auth state for cloud sync. This is the only service that depends on Riverpod.

### Code Reference

- **Achievement service**: `lib/features/achievements/services/achievement_service.dart`
- **Discovery service**: `lib/features/discovery/services/discovery_service.dart`
- **Restoration service**: `lib/features/restoration/services/restoration_service.dart`

---

## Auth System

The app supports **conditional Supabase auth** with a **mock auth fallback**.

### Auth Flow

1. **App launch**: Check for Supabase credentials (`SUPABASE_URL`, `SUPABASE_ANON_KEY`)
2. **If credentials exist**: Use `SupabaseAuthService` (anonymous sign-in)
3. **If no credentials**: Use `MockAuthService` (local-only, no network)

### Auth States

| State | Description |
|-------|-------------|
| `initial` | Loading (checking for existing session) |
| `unauthenticated` | No session |
| `authenticated` | Signed in with email/password |
| `guest` | Signed in anonymously |
| `loading` | Auth operation in progress |
| `error` | Auth operation failed |

### Mock Auth

`MockAuthService` provides a local-only auth experience:

- **No network**: All operations are synchronous
- **No persistence**: Session is lost on app restart
- **Guest mode**: Always returns a mock user ID

### Supabase Auth

`SupabaseAuthService` provides real auth:

- **Anonymous sign-in**: Users can play without creating an account
- **Email/password**: Users can upgrade to a full account
- **Session persistence**: Supabase SDK handles token refresh

### Code Reference

- **Auth provider**: `lib/features/auth/providers/auth_provider.dart`
- **Auth service interface**: `lib/features/auth/services/auth_service.dart`
- **Mock auth**: `lib/features/auth/services/mock_auth_service.dart`
- **Supabase auth**: `lib/features/auth/services/supabase_auth_service.dart`

---

## Key Architectural Decisions

These are **locked in** — do not revisit without explicit instruction.

### 1. Computed Fog State

**Decision**: FogState is derived on-demand from player position + visit history, like Civilization fog-of-war. Only `visitedCellIds` are persisted. Never store per-cell fog state.

**Rationale**:
- **Simplicity**: No need to sync fog state across devices
- **Correctness**: Fog state is always consistent with visit history
- **Performance**: Computing fog state is O(1) per cell (hash lookup)

**Code**: `lib/core/fog/fog_state_resolver.dart`

### 2. Deterministic Species Encounters

**Decision**: Species for a cell are seeded by cell ID via SHA-256 hash. Same cell always yields the same species.

**Rationale**:
- **Reproducibility**: Same cell always yields same species
- **Fairness**: Everyone who visits the same cell gets the same encounters
- **No RNG manipulation**: You can't "reroll" by leaving and re-entering

**Code**: `lib/core/species/loot_table.dart`

### 3. Voronoi Cells

**Decision**: The cell system uses Voronoi tessellation (not H3). `CellService` is an abstract interface; H3 exists as a fallback.

**Rationale**:
- **Organic feel**: Voronoi cells are irregular, which makes fog-of-war feel natural
- **Flexibility**: Interface allows swapping implementations without changing game logic

**Code**: `lib/core/cells/voronoi_cell_service.dart`

### 4. IUCN Rarity = Loot Weights

**Decision**: 6 IUCN statuses map to 10^x weights: LC (100k), NT (10k), VU (1k), EN (100), CR (10), EX (1). Path of Exile style.

**Rationale**:
- **Real-world data**: IUCN status is a real conservation metric
- **Rarity progression**: 10x per tier creates a clear rarity curve
- **Collectibility**: Rare species feel special

**Code**: `lib/core/models/iucn_status.dart`

### 5. Offline-First

**Decision**: SQLite (Drift) is the source of truth. Supabase write-through syncs data when credentials are configured. No sync queue — writes go directly to Supabase via `SupabasePersistence`.

**Rationale**:
- **Works offline**: Core gameplay never requires network
- **Simple sync**: Write-through is easier to reason about than a sync queue
- **Optional cloud**: Supabase is a feature, not a requirement

**Code**: `lib/features/sync/services/supabase_persistence.dart`

### 6. Riverpod v3 Notifier

**Decision**: All mutable state uses `NotifierProvider<T, S>` (not `StateNotifier`, not `ChangeNotifier`). Immutable state classes with `copyWith()`.

**Rationale**:
- **Modern Riverpod**: v3 Notifier is the recommended pattern
- **Type safety**: Notifier pattern is more type-safe than StateNotifier
- **Immutability**: Immutable state prevents accidental mutations

**Code**: `lib/core/state/fog_provider.dart`

### 7. 7 Habitats

**Decision**: Forest, Plains, Freshwater, Saltwater, Swamp, Mountain, Desert.

**Rationale**:
- **Simplicity**: 7 habitats cover most real-world biomes
- **ESA mapping**: Maps cleanly to ESA WorldCover land classification
- **Collectibility**: 7 habitats is a manageable collection goal

**Code**: `lib/core/models/habitat.dart`

### 8. 2 Seasons

**Decision**: Summer (May–Oct), Winter (Nov–Apr). 80% of species are year-round, 10% summer-only, 10% winter-only.

**Rationale**:
- **Simplicity**: 2 seasons is easy to understand
- **Replayability**: Seasonal species encourage revisiting cells
- **Balance**: 80% year-round ensures most species are always available

**Code**: `lib/core/models/season.dart`

### 9. Restoration Formula

**Decision**: 3 unique species in a cell = fully restored (level 1.0). Formula: `min(uniqueSpeciesCount, 3) / 3.0`.

**Rationale**:
- **No grinding**: You can't collect the same species twice in the same cell
- **Achievable goal**: 3 species is a clear, finite target
- **Encourages exploration**: To restore more cells, you need to visit new areas

**Code**: `lib/features/restoration/services/restoration_service.dart`

### 10. Conditional Supabase

**Decision**: When `SUPABASE_URL` and `SUPABASE_ANON_KEY` are supplied via `--dart-define`, the app uses `SupabaseAuthService` (with anonymous sign-in) and `SupabasePersistence` (write-through to Supabase tables). Without credentials, `MockAuthService` is used and sync is disabled.

**Rationale**:
- **Optional cloud**: Supabase is a feature, not a requirement
- **Local development**: Developers can run the app without Supabase credentials
- **Graceful degradation**: App works offline even if Supabase is down

**Code**: `lib/features/auth/providers/auth_provider.dart`

---

# Part 3 — Data Model

## Database Schema

See [Persistence Layer](#persistence-layer) for full schema details.

### Summary

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `LocalCellProgressTable` | Per-cell fog state, distance, visits, restoration | `userId`, `cellId`, `fogState`, `restorationLevel` |
| `LocalCollectedSpeciesTable` | Collected species per user per cell | `userId`, `speciesId`, `cellId` |
| `LocalPlayerProfileTable` | Player stats (streaks, distance, season) | `id`, `currentStreak`, `longestStreak`, `totalDistanceKm` |

---

## Domain Models

### FogState

5 discrete fog-of-war visibility states.

```dart
enum FogState {
  undetected(1.0),   // Completely opaque
  unexplored(0.75),  // Detected but not entered
  hidden(0.5),       // Previously visited, not in current view
  concealed(0.25),   // Adjacent to current cell
  observed(0.0);     // Fully revealed
  
  final double density;
  const FogState(this.density);
}
```

**File**: `lib/core/models/fog_state.dart`

### IucnStatus

IUCN Red List conservation status, used as rarity tiers.

```dart
enum IucnStatus {
  leastConcern(100000),
  nearThreatened(10000),
  vulnerable(1000),
  endangered(100),
  criticallyEndangered(10),
  extinct(1);
  
  final int weight;
  const IucnStatus(this.weight);
}
```

**File**: `lib/core/models/iucn_status.dart`

### SpeciesRecord

A species from the IUCN dataset.

```dart
class SpeciesRecord {
  final String commonName;
  final String scientificName;
  final String taxonomicClass;
  final List<Continent> continents;
  final List<Habitat> habitats;
  final IucnStatus iucnStatus;
  
  String get id => scientificName.toLowerCase().replaceAll(' ', '_');
}
```

**File**: `lib/core/models/species.dart`

### Habitat

The 7 habitat types.

```dart
enum Habitat {
  forest,
  plains,
  freshwater,
  saltwater,
  swamp,
  mountain,
  desert;
}
```

**File**: `lib/core/models/habitat.dart`

### Continent

The 6 continents.

```dart
enum Continent {
  asia,
  northAmerica,
  southAmerica,
  africa,
  oceania,
  europe;
}
```

**File**: `lib/core/models/continent.dart`

### Season

The 2 seasons.

```dart
enum Season {
  summer,
  winter;
  
  static Season fromDate(DateTime date) {
    final month = date.month;
    if (month >= 5 && month <= 10) return Season.summer;
    return Season.winter;
  }
}
```

**File**: `lib/core/models/season.dart`

### LocationState

Current player location and tracking status.

```dart
class LocationState {
  final Geographic? currentPosition;
  final double? accuracy;
  final bool isTracking;
  final LocationError locationError;
}
```

**File**: `lib/core/state/location_provider.dart`

### CollectionState

Collected species IDs.

```dart
class CollectionState {
  final List<String> collectedSpeciesIds;
  
  int get totalCollected => collectedSpeciesIds.length;
}
```

**File**: `lib/core/state/collection_provider.dart`

---

## Species Data Format

The app bundles **32,752 real IUCN species records** in `assets/species_data.json` (6 MB).

### JSON Structure

```json
[
  {
    "commonName": "American Black Bear",
    "scientificName": "Ursus americanus",
    "taxonomicClass": "Mammalia",
    "continents": ["North America"],
    "habitats": ["Forest"],
    "iucnStatus": "Least Concern"
  },
  {
    "commonName": "Giant Panda",
    "scientificName": "Ailuropoda melanoleuca",
    "taxonomicClass": "Mammalia",
    "continents": ["Asia"],
    "habitats": ["Forest", "Mountain"],
    "iucnStatus": "Vulnerable"
  }
]
```

### Loading

Species data is loaded at app startup via `SpeciesDataLoader`:

```dart
final loader = SpeciesDataLoader();
final species = await loader.loadSpeciesData();
// Returns: List<SpeciesRecord> (32,752 species)
```

**File**: `lib/core/species/species_data_loader.dart`

---

## Tech Stack Summary

| Layer | Technology | Version |
|-------|------------|---------|
| **Framework** | Flutter | 3.41.3 |
| **Language** | Dart | 3.x |
| **State Management** | Riverpod | 3.2.1 |
| **Map Rendering** | MapLibre (josxha) | 0.1.2 |
| **Persistence** | Drift (SQLite ORM) | 2.14.0 |
| **Backend** | Supabase (optional) | 2.12.0 |
| **Geospatial** | geobase | 1.5.0 |
| **Cell System** | h3_flutter_plus | 1.0.0 |
| **GPS** | geolocator | 13.0.2 |

---

## Testing

### Test Structure

Tests mirror `lib/` exactly:
- `test/core/cells/cell_cache_test.dart` tests `lib/core/cells/cell_cache.dart`

### Test Patterns

| Pattern | Usage |
|---------|-------|
| `setUp()` / `tearDown()` | Fresh instance per test |
| `ProviderContainer` + `addTearDown(container.dispose)` | Riverpod provider tests |
| `testWidgets()` + `MaterialApp` wrapper | Widget tests |
| `NativeDatabase.memory()` | In-memory Drift for integration tests |
| Hand-written `Mock<Interface>` | Implements interface with deterministic behavior |
| `make<ClassName>()` factory functions | Inline builders with sensible defaults |

### Test Stats

- **910 passing tests**
- **0 analysis issues**
- **No mockito/mocktail** — all mocks are hand-written

### Running Tests

```bash
# Set up Flutter environment
eval "$(~/.local/bin/mise activate bash)"

# Run tests (H3 FFI needs LD_LIBRARY_PATH)
LD_LIBRARY_PATH=. flutter test

# Run analysis
flutter analyze
```

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

| Issue | Location | Severity |
|-------|----------|----------|
| Singleton `AchievementService` | `achievement_provider.dart:83` | Medium — should be a Provider |
| `ref.read()` in `build()` | journal, sanctuary, achievement providers | Medium — should use `ref.watch()` |
| Bidirectional notifier coupling | `caretaking_provider.dart:37,51` | Low — works but tight coupling |
| Spike code with StatefulWidget | `fog_spike_screen.dart` | Low — experimental, not production |

---

## Future Work (Not Started)

- Camera/AI species identification
- Multiplayer, social features, leaderboards, trading
- Real-time Supabase sync (currently manual only)
- Push notifications
- Particle effects at fog edges (v2 visual polish)
- Real tile provider (MBTiles or Mapbox API)
- Analytics / engagement tracking

---

## Debugging Checklist

When a feature misbehaves:

1. **Capture exact inputs/outputs** — log player location, cell ID, fog state, API responses
2. **Apply 5-why analysis** — find root cause, not symptom
3. **Isolate the system** — disable unrelated features to narrow scope
4. **Check constraints** — verify no scope ceiling violations
5. **Verify reversibility** — ensure any fix can be toggled off

### High-Signal Log Points

- GPS updates: accuracy, timestamp, tile coordinate
- Fog state transitions: cell ID, old → new state, trigger
- Persistence operations: operation type, row count, latency
- Sync events: type, status, retry count
- Tile requests: URL (masked key), HTTP status, response size

---

## Glossary

| Term | Definition |
|------|------------|
| **Cell** | A spatial region on the map (Voronoi or H3 hexagon) |
| **Fog-of-war** | The visibility system that reveals the map as you explore |
| **Species encounter** | A species that appears in a cell when you visit it |
| **Loot table** | A weighted random selection system (Path of Exile style) |
| **Restoration** | The process of collecting species to restore a cell's habitat |
| **Sanctuary** | Your personal species collection, grouped by habitat |
| **Caretaking** | Daily visit streak tracking |
| **Achievement** | A milestone that unlocks when you meet a condition |
| **Habitat** | One of 7 biome types (Forest, Plains, Freshwater, etc.) |
| **Continent** | One of 6 geographic regions (Asia, North America, etc.) |
| **Season** | Summer (May–Oct) or Winter (Nov–Apr) |
| **IUCN status** | Conservation status from the IUCN Red List (LC, NT, VU, EN, CR, EX) |
| **Detection radius** | 50 km radius around the player where cells are at least Unexplored |
| **Exploration frontier** | Cells adjacent to visited cells (Unexplored state) |

---

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

---

## Contact & Contributing

This is a living document. If you find errors, outdated information, or missing details, please update this file and submit a PR.

For questions about the architecture or design, refer to:
- `AGENTS.md` — Agent guidance (AI-focused)
- `lib/core/AGENTS.md` — Core subsystem details
- `lib/features/map/AGENTS.md` — Map feature details

---

**Last Updated**: 2026-03-03  
**Document Version**: 1.0.0
