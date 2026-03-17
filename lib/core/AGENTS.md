# Core Subsystem

Shared domain logic, models, state management, and persistence for the geo-game. No UI, no platform-specific code. Everything in `lib/core/` is pure business logic that features/ can depend on.

---

## Subdirectories

### cells/

**Purpose**: Cell geometry and spatial queries. Abstracts Voronoi implementation behind a common interface.

**Public API**:
- `CellService` interface: `getCellId(lat, lon)`, `getCellCenter(cellId)`, `getCellBoundary(cellId)`, `getNeighborIds(cellId)`, `getCellsInRing(cellId, k)`, `getCellsAroundLocation(lat, lon, k)`, `cellEdgeLengthMeters`, `systemName`
- `LazyVoronoiCellService`: Infinite-world Voronoi with lazy seed materialization. Cell IDs: `"v_{row}_{col}"`. ~180m median diameter.
- `CellCache`: Decorator that memoizes center/boundary/neighbor/ring lookups. Does NOT cache `getCellId()`.
- `CountryResolver`: `resolve(lat, lon)` → `Continent`. Ray-casting against bundled Natural Earth 1:110m country polygons. Implements `ContinentLookup`.

**Conventions**:
- Cell IDs are opaque strings. Voronoi uses `"v_{row}_{col}"`.
- `getCellBoundary()` returns ordered polygon vertices, does NOT repeat first vertex
- `getCellsInRing(cellId, k: 0)` returns a list containing only `cellId`
- `getCellsInRing(cellId, k: 1)` returns nearest Voronoi cells
- Strategy pattern: inject via `cellServiceProvider` (currently `CellCache(LazyVoronoiCellService(...))`)
- `CountryResolver.load(jsonString)` factory — loaded by `countryResolverProvider` (FutureProvider)
- `CellPropertyResolver` and `EventResolver` moved to `features/world/`

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
- `AppDatabase`: Drift database with 7 tables
  - `LocalCellProgressTable`: `id` (text PK), `userId`, `cellId`, `fogState`, `distanceWalked`, `visitCount`, `restorationLevel`, `lastVisited`, `createdAt`, `updatedAt`
  - `LocalItemInstanceTable`: `id` (text PK), `userId`, `definitionId`, `categoryName`, `affixesJson`, `parentAId`, `parentBId`, `dailySeed`, `status`, `createdAt`
  - `LocalPlayerProfileTable`: `id` (text PK), `displayName`, `currentStreak`, `longestStreak`, `totalDistanceKm`, `currentSeason`, `createdAt`, `updatedAt`
  - `LocalSpeciesEnrichmentTable`: `definitionId` (text PK), `animalClass`, `foodPreference`, `climate`, `brawn`, `wit`, `speed`, `size` (nullable text — `AnimalSize` enum name), `artUrl` (nullable), `enrichedAt`
  - `LocalWriteQueueTable`: `id` (int, autoIncrement PK), `entityType`, `entityId`, `operation`, `payload`, `userId`, `status` (default 'pending'), `attempts` (default 0), `lastError` (nullable), `createdAt`, `updatedAt`
  - `LocalCellPropertiesTable`: `cellId` (text PK), `habitatsJson` (text), `climate` (text), `continent` (text), `locationId` (text nullable), `createdAt` (datetime). Globally shared (no userId).
  - `LocalLocationNodeTable`: `id` (text PK), `name` (text), `adminLevel` (text), `parentId` (text nullable), `osmId` (text nullable), `colorHex` (text nullable), `geometryJson` (text nullable), `createdAt` (datetime)
- Write queue query methods: `enqueueEntry`, `getPendingEntries`, `getRejectedEntries`, `countPendingEntries`, `confirmEntry`, `rejectEntry`, `incrementEntryAttempts`
- Cell property query methods: `getCellProperties(cellId)`, `upsertCellProperties(companion)`, `getAllCellProperties()`, `getLocationNode(id)`, `upsertLocationNode(companion)`, `getLocationNodeByOsmId(osmId)`, `getLocationNodeChildren(parentId)`
- `createDatabaseConnection()`: Platform-aware connection factory (conditional import)
- `schemaVersion = 13`. Migrations: v2→v3 LocalSpeciesEnrichmentTable, v3→v4 LocalWriteQueueTable, v4→v5 through v8 enrichment columns (brawn/wit/speed/artUrl), v8→v9 `size` column, v10→v11 LocalCellPropertiesTable + LocalLocationNodeTable, v11→v12 LocalLocationNodeTable osmId nullable (table recreation for SQLite), v12→v13 `geometry_json` column added to `LocalLocationNodeTable` via `m.addColumn`.

**Conventions**:
- FogState stored as string enum name (e.g., "observed", "concealed")
- Uses `part 'app_database.g.dart'` — run `dart run build_runner build` after schema changes
- Upsert semantics: `onConflict: DoUpdate((old) => ...)`
- All tables use explicit text PKs except `LocalWriteQueueTable` (auto-increment int PK)
- Platform-aware: `connection_native.dart` (file-backed) vs `connection_web.dart` (in-memory)
- Nullable fields in updates use `Value.absent()`, not null

---

### services/

**Purpose**: Pure Dart services that don't fit a specific subdomain. No Flutter, no Riverpod dependency.

**Public API**:
- `DailySeedService`: `fetchSeed()`, `refreshSeed()`, `currentSeed`, `isDiscoveryPaused`, `state` (DailySeedState). Pure Dart — accepts a `SeedFetcher` callback (`Future<String> Function()`) instead of importing Supabase directly.
- `DailySeedState`: Immutable state with `seedValue`, `fetchedAt`, `isStale` (checks `kDailySeedGraceHours`).
- `SeedFetcher`: typedef `Future<String> Function()` — wired to Supabase RPC by `dailySeedServiceProvider`.

**Conventions**:
- `DailySeedService` is network-free in `core/` — the offline audit test enforces no Supabase imports in `lib/core/` (with allowlist exception for `daily_seed_provider.dart`).
- Seed is cached in-memory only (24h TTL). No Drift table needed — seed is ephemeral.
- `fetchSeed()` catches exceptions and falls back to `kDailySeedOfflineFallback` (`'offline_no_rotation'`).
- `isDiscoveryPaused` returns true only when seed is stale AND no fallback available (currently always false since fallback always works).

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

### engine/

**Purpose**: Central game logic coordinator. Pure Dart — no Flutter, no Riverpod dependency. (Formerly `game/`.)

**Public API**:
- `GameCoordinator`: `start(gpsStream, discoveryStream)`, `stop()`, `dispose()`, `updatePlayerPosition(lat, lon)`, `onRawGpsUpdate` stream
- `GpsError`: enum (none, permissionDenied, permissionDeniedForever, serviceDisabled, lowAccuracy)
- `GpsPermissionResult`: enum (granted, denied, deniedForever, serviceDisabled)

**Dual-Position Model**:
- `rawGpsPosition` — from GPS stream (1Hz). Used for rubber-band target + GPS accuracy UI.
- `playerPosition` — from rubber-band feedback (60fps). Used for ALL game logic (fog, discovery, cell transitions).

**Conventions**:
- Game logic throttled to ~10Hz (every 6th frame at 60fps). First call always processes immediately.
- Output via callbacks (onPlayerLocationUpdate, onGpsErrorChanged, onCellVisited, onItemDiscovered) — wired by `gameCoordinatorProvider`.
- `onRawGpsUpdate` uses broadcast StreamController with `sync: true`.
- `GpsError` and `GpsPermissionResult` mirror feature-layer enums to avoid core→features dependency.
- Discovery processing: rolls intrinsic affix via `StatsService` (now in `features/items/services/`), creates ItemInstance with UUID. When enrichment includes `AnimalSize`, also rolls `weightGrams` via `StatsService.rollWeightGrams()` and adds `size` + `weightGrams` to intrinsic affix values map.
- `enrichedStatsLookup` callback type: `({int speed, int brawn, int wit, AnimalSize? size})? Function(String definitionId)?`

---

### models/

**Purpose**: Immutable value objects for domain entities.

**Public API** (23 models):
- `FogState`: enum with 5 values (undetected, unexplored, concealed, hidden, observed). `density` getter returns doubles for shader (1.0, 1.0, 0.95, 0.5, 0.0).
- `IucnStatus`: enum (leastConcern, nearThreatened, vulnerable, endangered, criticallyEndangered, extinct). `weight` getter follows 3^x progression: LC=243, NT=81, VU=27, EN=9, CR=3, EX=1.
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
- `FoodType`: enum (critter, fish, fruit, grub, nectar, seed, veg). `id` getter: `'food-$name'`.
- `OrbDimension`: enum (habitat, animalClass, climate). The 3 dimensions of orb types.
- `ActivityType`: enum (explore, forage, dig, survey). Determines eligible loot categories.
- `CellData`: `id`, `center: Geographic`, `fogState`, `speciesIds`, `restorationLevel`, `distanceWalked`, `visitCount`, `lastVisited`.
- `PlayerProgress`: `userId`, `cellsObserved`, `speciesCollected`, `currentStreak`, `longestStreak`, `totalDistanceKm`.
- `Season`: enum (summer, winter). `fromDate(DateTime)` uses month ranges: summer = May-Oct, winter = Nov-Apr.
- `Continent`: enum (asia, northAmerica, southAmerica, africa, oceania, europe). `fromDataString(String)` handles IUCN format strings.
- `Habitat`: enum (forest, plains, freshwater, saltwater, swamp, mountain, desert).
- `CellProperties`: `cellId`, `habitats: Set<Habitat>`, `climate: Climate`, `continent: Continent`, `locationId: String?`, `createdAt`. Permanent geo-derived cell properties. `fromDrift()`/`toDriftRow()`/`toDriftCompanion()` for persistence.
- `CellEvent`: `type: CellEventType`, `cellId`, `dailySeed`. Rotating daily event. `CellEventType` enum: migration, nestingSite. Not persisted — deterministic from seed + cellId.
- `LocationNode`: `id`, `name`, `adminLevel: AdminLevel`, `parentId`, `osmId`, `colorHex: String?`, `geometryJson: String?`. `AdminLevel` enum: world, continent, country, state, city, district. 6-level location hierarchy. `geometryJson` = GeoJSON polygon (Polygon or MultiPolygon), null until fetched via `resolve-admin-boundaries` Edge Function.
- `DiscoveryEvent`: *(existing)* — added `cellEventType: CellEventType?` nullable field indicating which cell event triggered the encounter (null = normal).
- `AnimalSize`: enum (fine, diminutive, tiny, small, medium, large, huge, gargantuan, colossal). Each value has `minGrams` and `maxGrams` (metric). `rangeSpan` = maxGrams - minGrams + 1. `fromString(String)` parser (case-insensitive). 9 size categories from fine (1–49g) to colossal (15M–247M g). Colossal max = 130% of ~190t blue whale record.
- `SpeciesEnrichment`: `definitionId`, `animalClass: AnimalClass`, `foodPreference: FoodType`, `climate: Climate`, `brawn: int`, `wit: int`, `speed: int`, `size: AnimalSize?`, `artUrl: String?`, `enrichedAt: DateTime`. Immutable value object for cached AI enrichment data. All fields required except `size` and `artUrl`. Validates `brawn + wit + speed == 90` at runtime (throws `ArgumentError`). Equality by `definitionId`.

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
- `CellProgressRepository`: `getCellProgress(String)`, `upsertCellProgress(CellProgressData)`, `addDistance(String, double)`, `getAllVisitedCells()`, `incrementVisitCount(String)`
- `ItemInstanceRepository`: `create(ItemInstance)`, `read(String id)`, `readAll(String userId)`, `update(ItemInstance)`, `deleteItem(String id)`, `readByStatus(String userId, ItemInstanceStatus)`. Full CRUD with Drift domain conversion.
- `ProfileRepository`: `getProfile(String)`, `upsertProfile(PlayerStats, String)`, `incrementCellsExplored(String)`, `updateStreak(String, int)`
- `EnrichmentRepository`: `getEnrichment(String definitionId)`, `getAllEnrichments()`, `upsertEnrichment(SpeciesEnrichment)`, `upsertAll(List<SpeciesEnrichment>)`, `getEnrichmentsSince(DateTime since)`. Local cache CRUD for AI enrichment data.
- `WriteQueueRepository`: `enqueue(WriteQueueEntry)`, `getPending(limit)`, `getRejected()`, `countPending()`, `deleteEntry(id)`, `markRejected(id, error)`, `incrementAttempts(id, error)`, `deleteStale(cutoff)`, `clearUser(userId)`. Offline write queue CRUD.
- `CellPropertyRepository`: `get(cellId)`, `upsert(CellProperties)`, `updateLocationId(cellId, locationId)`, `getAll()`. Cell property CRUD. Globally shared (not per-user).
- `LocationNodeRepository`: `get(id)`, `getByOsmId(osmId)`, `upsert(LocationNode)`, `getChildren(parentId)`. Location hierarchy CRUD.

**Conventions**:
- Repositories take `AppDatabase` in constructor
- Drift `Value<T>` wrappers for nullable fields: `Value(x)` or `Value.absent()`
- Read-modify-write pattern for incremental updates (e.g., `addDistance` reads current, adds delta, writes back)
- All methods return `Future<T>` — no synchronous database access

---

### species/

**Purpose**: Deterministic species encounter generation and data loading.

**Public API**:
- `SpeciesService`: `getSpeciesForCell(cellId, habitats, continent, {required dailySeed, encounterSlots})`, `rollMultiple(LootTable, int n, String seed)`, `getSpeciesForMigration(habitats, nativeContinent, nativeClimate, dailySeed, cellId)`, `getSpeciesForNestingSite(habitats, continent, dailySeed, cellId)`
- `LootTable<T>`: Generic weighted random selection. `add(T item, int weight)`, `roll(String seed)`.
- `SpeciesRepository`: SQLite-backed species store. `getCandidates(habitats, continent)`, `getAll()`, `count()`. Primary data path.
- `SpeciesCache`: In-memory cache over `SpeciesRepository`. Used by `SpeciesService.fromCache()`.
- `ContinentResolver`: `getContinent(Geographic)` uses bounding boxes. Africa split at 20°E.

**Note**: `StatsService` moved to `features/items/services/`. See `features/items/AGENTS.md`.

**Conventions**:
- **Species encounters are deterministic by daily seed + cell ID.** Same cell + same day = same species. Different day = different species. Seed format: `"${dailySeed}_${cellId}"`.
- `rollMultiple(table, n, seed)` uses `"${baseSeed}_$attempt"` for uniqueness across rolls
- `maxAttempts = n * 10` to avoid infinite loops on small tables
- `SpeciesRepository` silently skips rows with unknown habitats, continents, or IUCN statuses
- `ContinentResolver` bounding boxes: Africa split at 20°E (west=Africa, east=Africa), Europe/Asia split at 60°E
- Species data is 33k IUCN records in `assets/species.db` (pre-compiled SQLite; source JSON at `assets/species_data.json`)

---

### state/

**Purpose**: Riverpod v3 state management. Global app state providers.

**Public API** (21 providers):
- `tabIndexProvider`: `NotifierProvider<TabIndexNotifier, int>` — selected tab index (0=Map, 1=Home, 2=Town, 3=Pack). Persists to SharedPreferences.
- `fogProvider`: `NotifierProvider<FogNotifier, Map<String, FogState>>` — per-cell fog state cache
- `locationProvider`: `NotifierProvider<LocationNotifier, LocationState>` — current position, accuracy, tracking status, errors
- `playerProvider`: `NotifierProvider<PlayerNotifier, PlayerState>` — streaks, distance, cells observed
- `seasonProvider`: `NotifierProvider<SeasonNotifier, Season>` — current season
- **Note**: `inventoryProvider`/`InventoryNotifier`/`InventoryState` renamed to `itemsProvider`/`ItemsNotifier`/`ItemsState` and moved to `features/items/providers/` — see `features/items/AGENTS.md`
- `fogResolverProvider`: `Provider<FogStateResolver>` — singleton fog computation (watches cellServiceProvider)
- `cellServiceProvider`: `Provider<CellService>` — singleton CellCache(LazyVoronoiCellService)
- `supabaseBootstrapProvider`: `Provider<SupabaseBootstrap>` — pre-initialized in main(), overridden
- `appDatabaseProvider`: `Provider<AppDatabase>` — singleton database with lifecycle management. Disposes on shutdown.
- `itemInstanceRepositoryProvider`: `Provider<ItemInstanceRepository>` — watches appDatabaseProvider. Used by gameCoordinatorProvider for persistence and hydration.
- `enrichmentRepositoryProvider`: `Provider<EnrichmentRepository>` — watches appDatabaseProvider. Local cache CRUD for species enrichments.
- `writeQueueRepositoryProvider`: `Provider<WriteQueueRepository>` — watches appDatabaseProvider. Offline write queue CRUD.
- `cellProgressRepositoryProvider`: `Provider<CellProgressRepository>` — watches appDatabaseProvider. Cell visit persistence.
- `profileRepositoryProvider`: `Provider<ProfileRepository>` — watches appDatabaseProvider. Player profile persistence.
- `dailySeedServiceProvider`: `Provider<DailySeedService>` — reads `supabaseClientProvider`. Wires Supabase RPC `ensure_daily_seed()` as `SeedFetcher` callback. Works without Supabase (offline fallback).
- `cellPropertyRepositoryProvider`: `Provider<CellPropertyRepository>` — watches appDatabaseProvider. Cell property CRUD (get, upsert, updateLocationId, getAll).
- `locationNodeRepositoryProvider`: `Provider<LocationNodeRepository>` — watches appDatabaseProvider. Location hierarchy node CRUD (get, upsert, getChildren, getByOsmId).
- `countryResolverProvider`: `FutureProvider<CountryResolver>` — loads `assets/country_boundaries.json`. Offline country→continent resolution via ray-casting.
- `cellPropertyResolverProvider`: `Provider<CellPropertyResolver>` — watches habitatServiceProvider + countryResolverProvider. Falls back to DefaultHabitatLookup + legacy ContinentResolver during loading.
- `gameCoordinatorProvider`: `Provider<GameCoordinator>` — central game loop, bridges core + features (justified exception to dependency rule). Hydrates inventory + cell progress + profile + cell properties from SQLite on startup. Fetches daily seed on startup. Persists discoveries, cell visits, profile changes, and cell properties to SQLite + write queue. Listens to `playerProvider` for profile write-through. Wires `cellPropertiesLookup` on DiscoveryService. Triggers `locationEnrichmentServiceProvider` for cells without locationId. Enrichment cache type: `Map<String, ({int speed, int brawn, int wit, AnimalSize? size})>`. Rolls weight when size is available during discovery/backfill.

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
cells/  (depends on: geobase, models/)
  ↓
database/  (depends on: models/, drift)
  ↓
persistence/  (depends on: database/, models/)
  ↓
fog/  (depends on: models/, cells/)
  ↓
species/  (depends on: models/, cells/)
  ↓
services/  (depends on: models/, shared/)
  ↓
engine/  (depends on: fog/, models/, species/, cells/)
  ↓
state/  (depends on: models/, persistence/, fog/, engine/, services/, cells/, riverpod)
```

External dependencies: `geobase` (Geographic type), `drift` (ORM), `riverpod` (state).

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
- Only `LocalWriteQueueTable.id` uses auto-increment — all other tables use explicit text PKs

### FogState is Computed
- **Never persist per-cell fog state.** Only store `visitedCellIds` in `CellProgress`.
- `FogStateResolver.resolve()` computes state on-demand from position + history
- Storing computed state causes desync between database and runtime

### Deterministic Species Encounters
- Same cell + same daily seed yields same species (seeded by SHA-256 of `"${dailySeed}_${cellId}"`)
- Different day = different daily seed = different species for same cell
- Changing the seed format breaks reproducibility of ALL existing encounters
- `rollMultiple()` appends `_$attempt` to seed for uniqueness
- Offline fallback seed (`offline_no_rotation`) means species don't rotate but encounters still work
- Stale seed (>24h without refresh) pauses discoveries via `DailySeedService.isDiscoveryPaused`

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

### GameCoordinator Dual-Position Model
- `rawGpsPosition` = GPS hardware (1Hz). `playerPosition` = rubber-band interpolated (60fps).
- ALL game logic (fog, discovery, stats) uses `playerPosition`, NOT `rawGpsPosition`.
- `updatePlayerPosition()` throttles game logic to ~10Hz via frame counter.

### Cell Properties Resolution
- `CellPropertyResolver.resolve()` is **synchronous and instant** — safe to call in the ~10Hz game tick
- Cell properties are globally shared (not per-user) — no userId in SQLite table or cache
- `CountryResolver` loaded async (FutureProvider) — `cellPropertyResolverProvider` falls back to legacy `ContinentResolver` during loading
- `HabitatService implements HabitatLookup` — bridged in features/world/. Falls back to `DefaultHabitatLookup` (returns plains) during loading.
- Events (migration, nesting site) are NOT persisted — deterministic from dailySeed + cellId, recomputable
- `cellPropertiesLookup` on DiscoveryService is a mutable callback field, wired by gameCoordinatorProvider after construction. Avoids circular dependency.

### Startup Hydration Order
- `gameCoordinatorProvider` must hydrate inventory + cell progress + profile + cell properties from SQLite BEFORE starting the game loop.
- `loadItems()` replaces inventory state entirely — a discovery during the race window would be wiped.
- `cellsObserved` is hydrated from cell progress count (observed + hidden fog states), NOT from profile.currentStreak.
- Auth may not be settled when the provider initializes. Use `ref.listen(authProvider)` with a `started` guard to wait.
- On hydration failure, the loop starts without persisted data (graceful degradation).
- Persistence uses async/await with try/catch (fire-and-forget). All writes go to SQLite + write queue simultaneously.
- `ref.listen(playerProvider)` detects profile state changes and persists to `ProfileRepository` + `WriteQueueRepository`.
