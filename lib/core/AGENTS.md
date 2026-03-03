# Core Subsystem

Shared domain logic, models, state management, and persistence for the geo-game. No UI, no platform-specific code. Everything in `lib/core/` is pure business logic that features/ can depend on.

---

## Subdirectories

### cells/

**Purpose**: Cell geometry and spatial queries. Abstracts H3 and Voronoi implementations behind a common interface.

**Public API**:
- `CellService` interface: `getCellId(Geographic)`, `getCellCenter(String)`, `getCellBoundary(String)`, `getCellsInRing(String, int)`, `getDistance(String, String)`
- `H3CellService`: H3 hexagons at resolution 10 (~15m edge length)
- `VoronoiCellService`: Voronoi cells from seed points
- `CellCache`: Decorator that memoizes boundary/center lookups

**Conventions**:
- Cell IDs are opaque strings (H3 uses hex strings, Voronoi uses "voronoi_lat_lon")
- `getCellBoundary()` returns a closed polygon but does NOT repeat the first vertex as the last
- `getCellsInRing(cellId, k: 0)` returns a list containing only `cellId`
- `getCellsInRing(cellId, k: 1)` returns the 6 immediate neighbors (H3) or nearest Voronoi cells
- Strategy pattern: inject the service via Riverpod provider

---

### config/

**Purpose**: Environment configuration and validation.

**Public API**:
- `SupabaseConfig`: `url`, `anonKey`, `validate()`

**Conventions**:
- Uses `String.fromEnvironment('SUPABASE_URL')` and `String.fromEnvironment('SUPABASE_ANON_KEY')`
- `validate()` throws if either value is empty — fail fast at app startup
- No fallback values, no defaults

---

### database/

**Purpose**: Drift ORM schema and database connection.

**Public API**:
- `AppDatabase`: Drift database with 3 tables
  - `LocalCellProgressTable`: `id` (text PK), `userId`, `cellId`, `fogState`, `distanceWalked`, `visitCount`, `restorationLevel`, `lastVisited`, `createdAt`, `updatedAt`
  - `LocalCollectedSpeciesTable`: `id` (text PK), `userId`, `speciesId`, `cellId`, `collectedAt`
  - `LocalPlayerProfileTable`: `id` (text PK), `displayName`, `currentStreak`, `longestStreak`, `totalDistanceKm`, `currentSeason`, `createdAt`, `updatedAt`
- `createDatabaseConnection()`: Platform-aware connection factory (conditional import)

**Conventions**:
- FogState stored as string enum name (e.g., "observed", "concealed")
- Uses `part 'app_database.g.dart'` — run `dart run build_runner build` after schema changes
- Upsert semantics: `onConflict: DoUpdate((old) => ...)`
- All tables use explicit text PKs (no auto-increment)
- Platform-aware: `connection_native.dart` (file-backed) vs `connection_web.dart` (in-memory)
- Nullable fields in updates use `Value.absent()`, not null

---

### fog/

**Purpose**: Fog-of-war state resolution. Computes per-cell fog state from player position and visit history.

**Public API**:
- `FogStateResolver`: `resolve(String cellId, Geographic playerPos, Set<String> visitedCellIds, CellService)`, `onLocationUpdate(Geographic, Set<String>, CellService)`

**CRITICAL CONVENTIONS**:
- **FogState is COMPUTED, not stored.** Only `visitedCellIds` are persisted. Never write per-cell fog state to the database.
- `resolve()` derives state from:
  - Player's current cell
  - Distance from player position to cell center
  - Whether cell is in `visitedCellIds`
- Detection radius from `kDetectionRadiusMeters` constant
- Priority order: Observed > Concealed > Hidden > Unexplored > Undetected
- `onLocationUpdate()` emits a stream of `(cellId, FogState)` tuples for all cells whose state changed
- Stream controller uses `sync: true` — events are emitted synchronously
- Exploration frontier (Unexplored cells) is maintained incrementally: when a cell becomes Observed, its unvisited neighbors become Unexplored

---

### models/

**Purpose**: Immutable value objects for domain entities.

**Public API** (8 models):
- `FogState`: enum with 5 values (undetected, unexplored, hidden, concealed, observed). `density` getter returns doubles for shader (1.0, 0.75, 0.5, 0.25, 0.0).
- `IucnStatus`: enum (LC, NT, VU, EN, CR, EW, EX, DD, NE). `weight` getter follows 10^x progression (PoE loot table style): LC=1, NT=10, VU=100, EN=1000, CR=10000, EW=100000, EX=1000000, DD=1, NE=1.
- `SpeciesRecord`: `scientificName`, `commonName`, `iucnStatus`, `habitat`, `continent`. Equality by `scientificName` only.
- `PlayerLocation`: `position` (Geographic), `accuracy` (double), `timestamp` (DateTime), `isTracking` (bool).
- `PlayerStats`: `totalDistance`, `cellsExplored`, `currentStreak`, `longestStreak`.
- `Season`: enum (summer, winter). `fromDate(DateTime)` uses month ranges: summer = Apr-Sep, winter = Oct-Mar.
- `Continent`: enum (africa, asia, europe, northAmerica, southAmerica, oceania). `fromDataString(String)` handles IUCN format strings (e.g., "Africa", "North America").
- `Habitat`: enum (forest, grassland, wetland, desert, urban, marine).

**Conventions**:
- All models are immutable with `@immutable` annotation
- Manual `toJson()` / `fromJson()` — no code generation
- `FogState.density` doubles for shader interpolation
- `IucnStatus.weight` for weighted random selection
- `SpeciesRecord` equality ignores all fields except `scientificName`

---

### persistence/

**Purpose**: Repository pattern wrapping `AppDatabase`. CRUD abstractions for features/.

**Public API**:
- `CellProgressRepository`: `getCellProgress(String)`, `upsertCellProgress(CellProgressData)`, `addDistance(String, double)`, `getAllVisitedCells()`
- `CollectedSpeciesRepository`: `getCollectedSpecies(String)`, `addCollectedSpecies(SpeciesRecord, String)`, `getAllCollectedSpecies()`
- `ProfileRepository`: `getProfile(String)`, `upsertProfile(PlayerStats, String)`, `incrementCellsExplored(String)`, `updateStreak(String, int)`

**Conventions**:
- Repositories take `AppDatabase` in constructor
- Drift `Value<T>` wrappers for nullable fields: `Value(x)` or `Value.absent()`
- Read-modify-write pattern for incremental updates (e.g., `addDistance` reads current, adds delta, writes back)
- All methods return `Future<T>` — no synchronous database access

---

### species/

**Purpose**: Deterministic species encounter generation and data loading.

**Public API**:
- `SpeciesService`: `getEncountersForCell(String cellId, Season, List<SpeciesRecord>)`, `rollMultiple(LootTable, int n, String seed)`
- `LootTable<T>`: Generic weighted random selection. `add(T item, int weight)`, `roll(String seed)`.
- `SpeciesDataLoader`: `loadSpeciesData()` returns `Future<List<SpeciesRecord>>` from `assets/species_data.json`.
- `ContinentResolver`: `getContinent(Geographic)` uses bounding boxes. Africa split at 20°E.

**Conventions**:
- **Species encounters are deterministic by cell ID.** Same cell always yields same species (seeded by SHA-256 hash of cell ID).
- `rollMultiple(table, n, seed)` uses `"${baseSeed}_$attempt"` for uniqueness across rolls
- `maxAttempts = n * 10` to avoid infinite loops on small tables
- `SpeciesDataLoader` silently skips records with unknown habitats or continents (logs warning, continues)
- `ContinentResolver` bounding boxes: Africa split at 20°E (west=Africa, east=Africa), Europe/Asia split at 60°E
- Species data is 33k IUCN records in `assets/species_data.json`

---

### state/

**Purpose**: Riverpod v3 state management. Global app state providers.

**Public API** (5 providers):
- `fogStateProvider`: `NotifierProvider<FogStateNotifier, Map<String, FogState>>` — per-cell fog state
- `locationProvider`: `NotifierProvider<LocationNotifier, PlayerLocation>` — current position, accuracy, tracking status
- `playerStatsProvider`: `NotifierProvider<PlayerStatsNotifier, PlayerStats>` — streaks, distance, cells explored
- `collectionProvider`: `NotifierProvider<CollectionNotifier, Set<String>>` — collected species IDs (scientificName)
- `seasonProvider`: `NotifierProvider<SeasonNotifier, Season>` — current season

**Conventions**:
- Uses Riverpod v3.2.1 `Notifier` pattern (NOT `StateNotifier`)
- Notifiers extend `Notifier<T>` and override `build()` for initialization
- `LocationNotifier.connectToService(LocationService)` takes the service from `features/location/` — core/ does NOT depend on features/
- `SeasonNotifier.build()` initializes from `DateTime.now()` via `Season.fromDate()`
- State updates are synchronous — no async state setters
- Providers are global singletons — no `.family` or `.autoDispose` modifiers

---

## Dependency Graph

```
models/  (no dependencies)
  ↓
config/  (no dependencies)
  ↓
cells/  (depends on: geobase)
  ↓
database/  (depends on: models/, drift)
  ↓
persistence/  (depends on: database/, models/)
  ↓
fog/  (depends on: models/, cells/)
  ↓
species/  (depends on: models/, cells/)
  ↓
state/  (depends on: models/, persistence/, fog/, riverpod)
```

External dependencies: `geobase` (Geographic type), `h3_flutter_plus` (H3 cells), `drift` (ORM), `riverpod` (state).

---

## Gotchas

### geobase Geographic Type
- Use `Geographic(lat: y, lon: x)` constructor (named parameters, lat first)
- NOT `LatLng(x, y)` — different package, different order

### Drift Value Wrappers
- Nullable fields in `copyWith()` use `Value<T>` wrappers
- `Value(x)` to set a value, `Value.absent()` to leave unchanged
- Example: `entity.copyWith(fogState: Value('observed'), distanceTraveled: Value.absent())`

### Drift Auto-Increment
- Tables with `autoIncrement()` must NOT override `primaryKey` getter
- Only `SyncQueue.id` uses auto-increment — all other tables use explicit PKs

### FogState is Computed
- **Never persist per-cell fog state.** Only store `visitedCellIds` in `CellProgress`.
- `FogStateResolver.resolve()` computes state on-demand from position + history
- Storing computed state causes desync between database and runtime

### Deterministic Species Encounters
- Same cell ID always yields same species (seeded by SHA-256)
- Changing the seed algorithm breaks reproducibility
- `rollMultiple()` appends `_$attempt` to seed for uniqueness

### onLocationUpdate Stream
- `FogStateResolver.onLocationUpdate()` stream controller uses `sync: true`
- Events are emitted synchronously during the call
- Listeners must not perform async work in the callback

### Season Date Ranges
- `Season.fromDate()` uses month ranges: Apr-Sep = summer, Oct-Mar = winter
- Boundary months (Apr, Oct) are inclusive to the new season
- No support for southern hemisphere seasons

### Continent Bounding Boxes
- Africa split at 20°E: west of 20°E = Africa, east of 20°E = Africa (both map to same enum)
- Europe/Asia split at 60°E
- Bounding boxes are approximate — edge cases near borders may misclassify
