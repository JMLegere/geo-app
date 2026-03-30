# Data Model

All domain models, database schema, and persistence contracts.

## Domain Models (lib/core/models/)

### Enums

| Enum | Values | Key Getter |
|------|--------|-----------|
| `FogState` | unknown, detected, nearby, explored, present | `density` → 1.0, 0.85, 0.95, 0.5, 0.0 |
| `IucnStatus` | leastConcern, nearThreatened, vulnerable, endangered, criticallyEndangered, extinct | `weight` → 100000, 10000, 1000, 100, 10, 1 |
| `Habitat` | forest, plains, freshwater, saltwater, swamp, mountain, desert | `displayName`, `colorHex` |
| `Season` | summer (May-Oct), winter (Nov-Apr) | `fromDate(DateTime)`, `opposite` |
| `Continent` | asia, northAmerica, southAmerica, africa, oceania, europe | `fromDataString()` handles IUCN format |
| `AnimalType` | mammal, bird, fish, reptile, bug | Auto-computed from IUCN `taxonomicClass` |
| `AnimalClass` | 35 values (carnivore, songbird, rodent, crocodile, etc.) | AI-enriched on first discovery |
| `Climate` | tropic, temperate, boreal, frigid | Derived from latitude (0°-23.5°, 23.5°-55°, 55°-66.5°, 66.5°-90°) |
| `FoodType` | critter, fish, fruit, grub, nectar, seed, veg | Food category for sanctuary feeding |
| `OrbDimension` | habitat, class, climate | Orb type dimension (3 dimensions, ~46 total types) |
| `ActivityType` | photograph, forage, lure, survey | Cell activity types (future) |
| `CellEventType` | migration, nestingSite | Daily rotating cell events (~12% of cells) |
| `AdminLevel` | world, continent, country, state, city, district | Location hierarchy level (6 tiers) |

### Value Objects

| Class | Fields | Equality | Notes |
|-------|--------|----------|-------|
| `ItemDefinition` (sealed) | Base class for all item types | — | 7 subclasses: FaunaDefinition, FloraDefinition, MineralDefinition, FossilDefinition, ArtifactDefinition, FoodDefinition, OrbDefinition |
| `FaunaDefinition` | scientificName, commonName, taxonomicClass, continents, habitats, iucnStatus, animalType, animalClass, foodPreference, climate, brawn, wit, speed, size: AnimalSize?, enrichedAt: DateTime? | `scientificName` only | 32,752 IUCN records. Enrichment fields populated server-side by `process-enrichment-queue`. |
| `FloraDefinition` | plantType | — | Stub (no dataset yet) |
| `MineralDefinition` | crystalSystem, hardness | — | Stub (no dataset yet) |
| `FossilDefinition` | era, fossilType | — | Stub (no dataset yet) |
| `ArtifactDefinition` | period, origin | — | Stub (no dataset yet) |
| `FoodDefinition` | foodType: `FoodType` | — | Predefined (7 types: critter, fish, fruit, grub, nectar, seed, veg) |
| `OrbDefinition` | dimension: `OrbDimension`, variant: String | — | Predefined (3 dimensions: habitat, class, climate; ~46 total types) |
| `ItemInstance` | id (UUID), definitionId, category, affixes: `List<Affix>`, parentAId, parentBId, dailySeed, status, createdAt | all fields | Unique item with rolled stats |
| `Affix` | type (prefix/suffix), key, value | all fields | Flexible key-value stats |
| `ItemCategory` | enum: fauna, flora, mineral, fossil, artifact, food, orb | — | Item type classification (7 categories) |
| `ItemInstanceStatus` | enum: active, donated, placed, released, traded | — | Lifecycle state |
| `CellProperties` | cellId, habitats: Set\<Habitat\>, climate: Climate, continent: Continent, locationId: String?, createdAt | cellId | Permanent geo-derived cell properties. `fromDrift()`/`toDriftRow()`/`toDriftCompanion()` |
| `CellEvent` | type: CellEventType, cellId, dailySeed | — | Rotating daily event (not persisted, recomputable). ~12% of cells per day |
| `LocationNode` | id, name, adminLevel: AdminLevel, parentId, osmId, geometry | id | Location hierarchy node. 6 levels: world→continent→country→state→city→district |
| `DiscoveryEvent` | *(existing)* + `cellEventType: CellEventType?` | — | Added nullable field to indicate which cell event triggered the encounter (null = normal) |
| `CellData` | id, center: Geographic, fogState, speciesIds, restorationLevel, distanceWalked, visitCount, lastVisited | — | `restorationLevel` clamped [0.0, 1.0] |
| `PlayerProgress` | userId, cellsObserved, speciesCollected, currentStreak, longestStreak, totalDistanceKm | — | Player stats aggregate |

### Auth Models (lib/features/auth/models/)

| Class | Fields | Notes |
|-------|--------|-------|
| `UserProfile` | id, email, displayName?, createdAt, isAnonymous | Immutable. `copyWith()`, `toJson()`/`fromJson()`. Anonymous users have `isAnonymous: true` |
| `AuthState` | status: `AuthStatus`, user: `UserProfile?`, errorMessage? | Status enum: `{unauthenticated, loading, authenticated}` |
| `UpgradePromptState` | shouldShow, hasBeenShown, showBanner | Computed from auth status (anonymous) + collection count (≥5 species) |

All models are immutable with manual `toJson()`/`fromJson()`. No code generation (no freezed).

### Species Data Format (assets/species_data.json → LocalSpeciesTable)

32,752 records. Each entry:

```json
{
  "commonName": "Giant Panda",
  "scientificName": "Ailuropoda melanoleuca",
  "taxonomicClass": "Mammalia",
  "continents": ["Asia"],
  "habitats": ["Forest", "Mountain"],
  "iucnStatus": "Vulnerable"
}
```

Seeded from `assets/species_data.json` into Drift `LocalSpeciesTable` at first run. `assets/species.db` has been deleted. Queried on demand via `DriftSpeciesRepository`, cached in `SpeciesCache`.

Supabase `species` table (32,752 rows, global/shared) mirrors IUCN data plus AI-enriched columns (`animal_class`, `food_preference`, `climate`, `brawn`, `wit`, `speed`, `size`, `art_url`, `enriched_at`). RLS: all authenticated users can read; only service_role can write (via `process-enrichment-queue` Edge Function).

### ESA WorldCover → Habitat Mapping

`BiomeService` maps ESA land cover codes to game habitats:

| ESA Code | Land Cover | Habitat |
|----------|-----------|---------|
| 10 | Tree cover | Forest |
| 20 | Shrubland | Plains |
| 30 | Grassland | Plains |
| 40 | Cropland | Plains |
| 50 | Built-up | Plains |
| 60 | Bare/sparse vegetation | Desert |
| 70 | Snow/ice | Mountain |
| 80 | Permanent water | Freshwater |
| 90 | Herbaceous wetland | Swamp |
| 95 | Mangroves | Swamp |
| 100 | Moss/lichen | Mountain |

**Fallback strategy:** `DefaultHabitatLookup` returns Plains for all cells. Active until GeoTIFF integration is implemented. `CoordinateHabitatLookup` supports in-memory grid→ESA code mapping for future use.

## Database Schema (Drift SQLite)

Schema version: **18** (v10→v11 adds `LocalCellPropertiesTable` + `LocalLocationNodeTable`, v11→v12 osmId nullable, v12→v13 `geometry_json`, v13→v18 drops `LocalSpeciesEnrichmentTable` + adds `LocalSpeciesTable`).

### LocalCellProgressTable

| Column | Type | Default | Notes |
|--------|------|---------|-------|
| `id` | text PK | — | Explicit text PK |
| `userId` | text | — | |
| `cellId` | text | — | |
| `fogState` | text | — | Stored as enum name string: "observed", "concealed", etc. |
| `distanceWalked` | real | 0.0 | |
| `visitCount` | int | 0 | |
| `restorationLevel` | real | 0.0 | |
| `lastVisited` | datetime | nullable | |
| `createdAt` | datetime | — | |
| `updatedAt` | datetime | — | |

Unique constraint: `{userId, cellId}`

### LocalItemInstanceTable

| Column | Type | Default | Notes |
|--------|------|---------|-------|
| `id` | text PK | — | UUID v4 |
| `userId` | text | — | |
| `definitionId` | text | — | References ItemDefinition (e.g., scientificName for fauna) |
| `categoryName` | text | — | Stored as enum name: "fauna", "flora", etc. |
| `affixesJson` | text | — | JSON-serialized List<Affix> |
| `parentAId` | text | nullable | For breeding lineage |
| `parentBId` | text | nullable | For breeding lineage |
| `dailySeed` | text | nullable | Server validation seed |
| `status` | text | "active" | Stored as enum name: "active", "donated", etc. |
| `createdAt` | datetime | — | |

### LocalPlayerProfileTable

| Column | Type | Default | Notes |
|--------|------|---------|-------|
| `id` | text PK | — | |
| `displayName` | text | — | |
| `currentStreak` | int | 0 | |
| `longestStreak` | int | 0 | |
| `totalDistanceKm` | real | 0.0 | |
| `currentSeason` | text | "summer" | |
| `createdAt` | datetime | — | |
| `updatedAt` | datetime | — | |

### LocalSpeciesTable

| Column | Type | Default | Notes |
|--------|------|---------|-------|
| `definitionId` | text PK | — | Matches `FaunaDefinition.id` (scientificName) |
| `commonName` | text | — | |
| `scientificName` | text | — | |
| `taxonomicClass` | text | — | IUCN class string (e.g., "Mammalia") |
| `continentsJson` | text | — | JSON array of continent name strings |
| `habitatsJson` | text | — | JSON array of habitat name strings |
| `iucnStatus` | text | — | IUCN status string |
| `animalClass` | text | nullable | AI-enriched AnimalClass enum name |
| `foodPreference` | text | nullable | AI-enriched FoodType enum name |
| `climate` | text | nullable | AI-enriched Climate enum name |
| `brawn` | int | nullable | AI-enriched stat (brawn+wit+speed=90) |
| `wit` | int | nullable | AI-enriched stat |
| `speed` | int | nullable | AI-enriched stat |
| `size` | text | nullable | AI-enriched AnimalSize enum name |
| `artUrl` | text | nullable | AI-generated watercolor URL |
| `enrichedAt` | datetime | nullable | When backend enrichment ran |

32,752 rows seeded from `assets/species_data.json`. Enrichment columns populated async by backend `process-enrichment-queue`. Replaces `LocalSpeciesEnrichmentTable` (dropped in schema v18).

### LocalWriteQueueTable

| Column | Type | Default | Notes |
|--------|------|---------|-------|
| `id` | int PK | autoIncrement | Auto-incrementing PK — do NOT override `primaryKey` getter |
| `entityType` | text | — | `'itemInstance'`, `'cellProgress'`, `'profile'`, `'cellProperties'` |
| `entityId` | text | — | Entity's primary key |
| `operation` | text | — | `'upsert'`, `'delete'` |
| `payload` | text | — | JSON snapshot of entity state |
| `userId` | text | — | Owner's auth ID |
| `status` | text | `'pending'` | `'pending'`, `'rejected'` |
| `attempts` | int | 0 | Retry count |
| `lastError` | text | nullable | Last sync error message |
| `createdAt` | datetime | — | When enqueued |
| `updatedAt` | datetime | — | Last status change |

### LocalCellPropertiesTable

| Column | Type | Default | Notes |
|--------|------|---------|-------|
| `cellId` | text PK | — | Voronoi cell ID (e.g., "v_123_456") |
| `habitatsJson` | text | — | JSON array of Habitat enum names |
| `climate` | text | — | Climate enum name |
| `continent` | text | — | Continent enum name |
| `locationId` | text | nullable | FK → LocationNode (backfilled async) |
| `createdAt` | datetime | — | When properties were first resolved |

Cell properties are **globally shared** (not per-user). No userId column.

### LocalLocationNodeTable

| Column | Type | Default | Notes |
|--------|------|---------|-------|
| `id` | text PK | — | Unique location ID |
| `name` | text | — | Display name (e.g., "New Brunswick") |
| `adminLevel` | text | — | AdminLevel enum name |
| `parentId` | text | nullable | FK → parent LocationNode |
| `osmId` | text | nullable | OpenStreetMap ID |
| `geometryJson` | text | nullable | GeoJSON geometry (optional) |
| `createdAt` | datetime | — | When node was created |

## Repositories (lib/core/persistence/)

| Repository | Table | Key Operations |
|------------|-------|---------------|
| `ProfileRepository` | LocalPlayerProfile | `create`, `read(userId)`, `update`, `updateCurrentStreak`, `addDistance`, `getAllProfiles` |
| `CellProgressRepository` | LocalCellProgress | `create`, `read(userId, cellId)`, `readByUser`, `updateFogState`, `addDistance`, `getCellsByFogState`, `incrementVisitCount` |
| `ItemInstanceRepository` | LocalItemInstance | `create`, `read(id)`, `readAll(userId)`, `update`, `deleteItem(id)`, `readByStatus(userId, status)` |
| `WriteQueueRepository` | LocalWriteQueue | `enqueue(entry)`, `getPending(limit)`, `getRejected()`, `countPending()`, `deleteEntry(id)`, `markRejected(id, error)`, `incrementAttempts(id, error)`, `deleteStale(cutoff)`, `clearUser(userId)` |
| `CellPropertyRepository` | LocalCellProperties | `get(cellId)`, `upsert(CellProperties)`, `updateLocationId(cellId, locationId)`, `getAll()` |
| `LocationNodeRepository` | LocalLocationNode | `get(id)`, `getByOsmId(osmId)`, `upsert(LocationNode)`, `getChildren(parentId)` |

All methods return `Future<T>`. Read-modify-write pattern for incremental updates. Drift `Value<T>` wrappers for nullable fields.

## Persistence Flow

```
Feature code → Repository method → AppDatabase → SQLite
                                        ↓
                              SupabasePersistence.upsert*()  (write-through, if configured)
                                        ↓
                                   Supabase table
```

`appDatabaseProvider` (core/state/) provides the singleton `AppDatabase`. `itemInstanceRepositoryProvider` watches it and provides `ItemInstanceRepository` to consumers.

When `SUPABASE_URL` is empty, `SupabasePersistence` is null. App runs offline-only. The write queue still accumulates entries in SQLite, but they are not flushed until Supabase is configured.

### Supabase Tables

**species** (global, shared):
- `scientific_name` (text PK), `common_name`, `taxonomic_class`, `continents`, `habitats`, `iucn_status`, `animal_class` (nullable), `food_preference` (nullable), `climate` (nullable), `brawn` (nullable int), `wit` (nullable int), `speed` (nullable int), `size` (nullable text), `art_url` (nullable), `enriched_at` (nullable timestamptz)
- 32,752 rows. RLS: All authenticated users can read. Only service_role can write (via `process-enrichment-queue` Edge Function).

**item_instances** (per-user):
- `id` (UUID PK), `user_id`, `definition_id`, `category_name`, `affixes_json`, `parent_a_id`, `parent_b_id`, `daily_seed`, `status`, `created_at`
- RLS: Users can only CRUD their own rows.

**cell_properties** (global, shared):
- `cell_id` (text PK), `habitats_json` (text), `climate` (text), `continent` (text), `location_id` (text nullable), `created_at` (timestamptz)
- RLS: All authenticated users can read and upsert. Globally shared — not per-user.

**location_nodes** (global, shared):
- `id` (text PK), `name` (text), `admin_level` (text), `parent_id` (text nullable FK), `osm_id` (text nullable unique), `geometry_json` (text nullable), `created_at` (timestamptz)
- RLS: All authenticated users can read and upsert. Lazily populated as players encounter cells.

**daily_seeds** (server-managed):
- `seed_date` (date PK), `seed_value` (text), `created_at` (timestamptz)
- Auto-populated by `ensure_daily_seed()` PostgreSQL function (called by validate-encounter Edge Function).
- RLS: All authenticated users can read. Only service_role can write.

### Write Queue Flow

```
Game event (discovery, cell visit, profile update)
  → SQLite write (immediate)
  → WriteQueueRepository.enqueue(entry)
  → QueueProcessor.flush() (triggered by SyncNotifier)
    → For each pending entry:
      → SupabasePersistence.upsert*() (sync to Supabase)
      → validateEncounter() (Edge Function, item instances only)
      → On success: deleteEntry() (removes confirmed entry)
      → On SyncRejectedException: markRejected() (permanent)
      → On SyncException: incrementAttempts() (retry with backoff)
    → SyncNotifier._processRejections() (rollback rejected items)
```

**Exception hierarchy:**
- `SyncException` — transient error (network, timeout) → retry with exponential backoff
- `SyncValidationRejectedException` — thrown by `validateEncounter()` → permanent rejection
- `SyncRejectedException` — caught by QueueProcessor → marks entry rejected → triggers rollback

**Rollback:** Rejected item instances are removed from in-memory `ItemsNotifier` and deleted from SQLite. Cell progress and profile rejections are logged only (server reconciliation on next full sync).

### Startup Hydration

On app start, `gameCoordinatorProvider` hydrates inventory from SQLite before starting the game loop:

```
Auth settles (userId available)
  → itemInstanceRepositoryProvider.getItemsByUser(userId)
    → itemsProvider.notifier.loadItems(items)
    → discoveryService.markCollected() for each item
      → startLoop()
```

**Race condition prevention**: `loadItems()` replaces items state entirely. The game loop must NOT start until hydration completes — a discovery during the race window would be wiped by the subsequent `loadItems()` call.

**Full hydration** (Phase 3):
1. Load items from SQLite via `ItemInstanceRepository` → seed `ItemsNotifier`
2. Load cell progress from SQLite via `CellProgressRepository` → count observed cells → seed `PlayerNotifier.cellsObserved`
3. Load player profile from SQLite via `ProfileRepository` → seed `PlayerNotifier` (streaks, distance)
4. Mark collected items in `DiscoveryService`
5. Start game loop

**Auth timing**: Auth initializes asynchronously (awaits Supabase bootstrap, then auto-signs-in). `gameCoordinatorProvider` reads `authProvider` — if userId is available immediately, it hydrates then starts. If auth is still loading, it uses `ref.listen<AuthState>` with a `started` guard to wait for auth to settle.

**Persistence paths** (Phase 3 write queue):
- **Item discovery**: `ItemInstanceRepository.create()` + `WriteQueueRepository.enqueue()` (fire-and-forget, async/await with try/catch)
- **Cell visit**: `CellProgressRepository.upsertCellProgress()` + `WriteQueueRepository.enqueue()` (fire-and-forget)
- **Profile updates**: `ref.listen(playerProvider)` in `gameCoordinatorProvider` → `ProfileRepository.update()` + `WriteQueueRepository.enqueue()` (fire-and-forget)

### Design Target: Inventory Model
> Phase 1 + Phase 4 COMPLETE. ItemInstance model with daily seed rotation is now live. Remaining: breeding, bundles, museum.

Current model: `ItemInstance` with affixes, status lifecycle, breeding lineage fields, daily seed.
Target model: Full breeding system, bundles, museum donations.

Key changes planned:
- Species stacked in Pack (inventory): "Mallard ×3" not just "Mallard: collected"
- Museum donations consume from inventory (permanent — cannot retrieve)
- Sanctuary placements consume from inventory (flexible — can rearrange)
- Release mechanic: return unwanted species to the wild
- Multiple collectible categories planned: Fauna (now), Plants, Minerals, Fossils (future)

Museum structure:
- 7 habitat-based wings (Forest, Plains, Freshwater, Saltwater, Swamp, Mountain, Desert)
- Wings are unlockable via donation milestones
- Species appear in ONE wing only — duplicates needed for multiple wings
- Grid display with empty/filled slots

## Game Constants (lib/shared/constants.dart)

| Constant | Value | Domain |
|----------|-------|--------|
| `kDetectionRadiusMeters` | 1000.0 | Fog detection range |
| `kVoronoiGridStep` | 0.002 | Cell grid spacing (degrees) |
| `kVoronoiJitterFactor` | 0.75 | Cell jitter magnitude |
| `kVoronoiGlobalSeed` | 42 | Deterministic seed |
| `kDefaultMapLat/Lon` | 45.9636 / -66.6431 | Fredericton, NB |
| `kDefaultZoom` | 15.0 | Initial map zoom |
| `kGpsAccuracyThreshold` | 50.0 | Accuracy gate (meters) |
| `kMaxCellsPerTile` | 100 | Rendering budget |
| `kRubberBandMinSpeedMps` | 1.389 | Marker min speed (5 km/h) |
| `kRubberBandSnapThresholdMeters` | 0.5 | Snap distance |
| `kWriteQueueMaxRetries` | 5 | Max retry attempts before stale |
| `kWriteQueueStaleAgeHours` | 72 | Hours before stale entries deleted |
| `kWriteQueueRetryBaseSeconds` | 2 | Base delay for exponential backoff |
| `kWriteQueueFlushBatchSize` | 50 | Max entries per flush batch |
| `kDailySeedGraceHours` | 24 | Hours before cached daily seed is considered stale |
| `kDailySeedOfflineFallback` | `'offline_no_rotation'` | Static seed used when Supabase is unavailable |
