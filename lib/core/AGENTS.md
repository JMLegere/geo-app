# Core Subsystem

Shared domain logic, models, state management, and persistence for the geo-game. No UI, no platform-specific code. Everything in `lib/core/` is pure business logic that features/ can depend on.

---

## Subdirectories

### cells/

**Purpose**: Cell geometry and spatial queries. Abstracts H3 and Voronoi implementations behind a common interface.

**Public API**:
- `CellService` interface: `getCellId(lat, lon)`, `getCellCenter(cellId)`, `getCellBoundary(cellId)`, `getNeighborIds(cellId)`, `getCellsInRing(cellId, k)`, `getCellsAroundLocation(lat, lon, k)`, `cellEdgeLengthMeters`, `systemName`
- `LazyVoronoiCellService`: Infinite-world Voronoi with lazy seed materialization. Cell IDs: `"v_{row}_{col}"`. ~180m median diameter.
- `H3CellService`: H3 hexagons at resolution 9 (~174m edge length). Cell IDs: hex BigInt strings.
- `CellCache`: Decorator that memoizes center/boundary/neighbor/ring lookups. Does NOT cache `getCellId()`.

**Conventions**:
- Cell IDs are opaque strings (H3 uses hex strings, Voronoi uses `"v_{row}_{col}"`)
- `getCellBoundary()` returns ordered polygon vertices, does NOT repeat first vertex
- `getCellsInRing(cellId, k: 0)` returns a list containing only `cellId`
- `getCellsInRing(cellId, k: 1)` returns the 6 immediate neighbors (H3) or nearest Voronoi cells
- Strategy pattern: inject via `cellServiceProvider` (currently `CellCache(LazyVoronoiCellService(...))`)

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
  - `LocalItemInstanceTable`: `id` (text PK), `userId`, `definitionId`, `categoryName`, `affixesJson`, `parentAId`, `parentBId`, `dailySeed`, `status`, `createdAt`
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
- Priority order: Observed (in current cell) > Hidden (previously visited) > Concealed (adjacent to current) > Unexplored (frontier or within detection radius) > Undetected (default)
- `onLocationUpdate()` emits a stream of `(cellId, FogState)` tuples for all cells whose state changed
- Stream controller uses `sync: true` — events are emitted synchronously
- Exploration frontier (Unexplored cells) is maintained incrementally: when a cell becomes Observed, its unvisited neighbors become Unexplored

---

### models/

**Purpose**: Immutable value objects for domain entities.

**Public API** (18 models):
- `FogState`: enum with 5 values (undetected, unexplored, concealed, hidden, observed). `density` getter returns doubles for shader (1.0, 1.0, 0.95, 0.5, 0.0).
- `IucnStatus`: enum (leastConcern, nearThreatened, vulnerable, endangered, criticallyEndangered, extinct). `weight` getter follows 10^x progression (PoE loot table style): LC=100000, NT=10000, VU=1000, EN=100, CR=10, EX=1.
- `ItemDefinition` (sealed): Base class for all 7 item types. Subclasses: `FaunaDefinition`, `FloraDefinition`, `MineralDefinition`, `FossilDefinition`, `ArtifactDefinition`, `FoodDefinition`, `OrbDefinition`.
- `FaunaDefinition`: `scientificName`, `displayName`, `taxonomicClass`, `animalType`, `animalClass`, `foodPreference`, `climate`, `continents`, `habitats`, `rarity`. Equality by `id`. `animalType` auto-computed from `taxonomicClass`.
- `FloraDefinition`, `MineralDefinition`, `FossilDefinition`, `ArtifactDefinition`: Stubs for Phase 1b. No dataset yet.
- `FoodDefinition`: `foodType: FoodType`. Discovered during exploration, fed to sanctuary animals.
- `OrbDefinition`: `dimension: OrbDimension`, `variant: String`. Primary currency, produced via sanctuary feeding.
- `ItemInstance`: `id` (UUID), `definitionId`, `category`, `affixes: List<Affix>`, `parentAId`, `parentBId`, `dailySeed`, `status`, `createdAt`. Represents unique item with rolled stats.
- `Affix`: `type` (prefix/suffix), `key`, `value`. Flexible key-value stats for item instances.
- `ItemCategory`: enum (fauna, flora, mineral, fossil, artifact, food, orb). 7 categories.
- `ItemInstanceStatus`: enum (active, donated, placed, released, traded).
- `AnimalType`: enum (mammal, bird, fish, reptile, bug). Deterministic from IUCN `taxonomicClass` via `fromTaxonomicClass()`.
- `AnimalClass`: enum with 35 values (7 bird, 9 bug, 6 fish, 8 mammal, 5 reptile). `parentType` maps to `AnimalType`. AI-determined on first discovery.
- `Climate`: enum (tropic, temperate, boreal, frigid). `fromLatitude(double)` derives from `abs(lat)` with boundaries 23.5°/55°/66.5°.
- `FoodType`: enum (critter, fish, fruit, grub, nectar, veg). `id` getter: `'food-$name'`.
- `OrbDimension`: enum (habitat, animalClass, climate). The 3 dimensions of orb types.
- `ActivityType`: enum (explore, forage, dig, survey). Determines eligible loot categories.
- `CellData`: `id`, `center: Geographic`, `fogState`, `speciesIds`, `restorationLevel`, `distanceWalked`, `visitCount`, `lastVisited`.
- `PlayerProgress`: `userId`, `cellsObserved`, `speciesCollected`, `currentStreak`, `longestStreak`, `totalDistanceKm`.
- `Season`: enum (summer, winter). `fromDate(DateTime)` uses month ranges: summer = May-Oct, winter = Nov-Apr.
- `Continent`: enum (asia, northAmerica, southAmerica, africa, oceania, europe). `fromDataString(String)` handles IUCN format strings.
- `Habitat`: enum (forest, plains, freshwater, saltwater, swamp, mountain, desert).

**Conventions**:
- All models are immutable with `@immutable` annotation
- Manual `toJson()` / `fromJson()` — no code generation
- `FogState.density` doubles for shader interpolation (1.0=opaque, 0.0=clear)
- `IucnStatus.weight` for weighted random selection (higher weight = more common)
- `ItemDefinition` equality by `id` field
- `FaunaDefinition.animalType` is auto-computed in constructor from `taxonomicClass`
- `FaunaDefinition.scientificName` narrows base `String?` to non-null `String`
- `ItemInstance.id` uses uuid package (v4 random UUIDs)
- `ItemInstance.affixes` serialized as JSON in database
- `CellData.restorationLevel` clamped to [0.0, 1.0]

---

### persistence/

**Purpose**: Repository pattern wrapping `AppDatabase`. CRUD abstractions for features/.

**Public API**:
- `CellProgressRepository`: `getCellProgress(String)`, `upsertCellProgress(CellProgressData)`, `addDistance(String, double)`, `getAllVisitedCells()`
- `ItemInstanceRepository`: `create(ItemInstance)`, `read(String id)`, `readAll(String userId)`, `update(ItemInstance)`, `delete(String id)`, `readByStatus(String userId, ItemInstanceStatus)`. Full CRUD with Drift domain conversion.
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
- `SpeciesService`: `getEncountersForCell(String cellId, Season, List<FaunaDefinition>)`, `rollMultiple(LootTable, int n, String seed)`
- `LootTable<T>`: Generic weighted random selection. `add(T item, int weight)`, `roll(String seed)`.
- `SpeciesDataLoader`: `loadSpeciesData()` returns `Future<List<FaunaDefinition>>` from `assets/species_data.json`.
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

**Public API** (8 providers):
- `fogProvider`: `NotifierProvider<FogNotifier, Map<String, FogState>>` — per-cell fog state cache
- `locationProvider`: `NotifierProvider<LocationNotifier, LocationState>` — current position, accuracy, tracking status, errors
- `playerProvider`: `NotifierProvider<PlayerNotifier, PlayerState>` — streaks, distance, cells observed
- `inventoryProvider`: `NotifierProvider<InventoryNotifier, InventoryState>` — item instances by status
- `seasonProvider`: `NotifierProvider<SeasonNotifier, Season>` — current season
- `fogResolverProvider`: `Provider<FogStateResolver>` — singleton fog computation (watches cellServiceProvider)
- `cellServiceProvider`: `Provider<CellService>` — singleton CellCache(LazyVoronoiCellService)
- `supabaseBootstrapProvider`: `Provider<SupabaseBootstrap>` — pre-initialized in main(), overridden

**Conventions**:
- Uses Riverpod v3.2.1 `Notifier` pattern (NOT `StateNotifier`)
- Notifiers extend `Notifier<T>` and override `build()` for initialization
- `LocationNotifier.connectToStream(Stream)` accepts a `({Geographic position, double accuracy})` stream — core/ does NOT depend on features/
- `SeasonNotifier.build()` initializes from `DateTime.now()` via `Season.fromDate()`
- State updates are synchronous — no async state setters
- Providers are global singletons — no `.family` or `.autoDispose` modifiers
- Infrastructure providers (`cellServiceProvider`, `fogResolverProvider`) use `Provider<T>` (not Notifier)

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
- `Season.fromDate()` uses month ranges: May-Oct = summer, Nov-Apr = winter
- Boundary months (May, Nov) are inclusive to the new season
- No support for southern hemisphere seasons

### Continent Bounding Boxes
- Africa split at 20°E: west of 20°E = Africa, east of 20°E = Africa (both map to same enum)
- Europe/Asia split at 60°E
- Bounding boxes are approximate — edge cases near borders may misclassify
