# Data Model

All domain models, database schema, and persistence contracts.

## Domain Models (lib/core/models/)

### Enums

| Enum | Values | Key Getter |
|------|--------|-----------|
| `FogState` | undetected, unexplored, concealed, hidden, observed | `density` → 1.0, 1.0, 0.95, 0.5, 0.0 |
| `IucnStatus` | leastConcern, nearThreatened, vulnerable, endangered, criticallyEndangered, extinct | `weight` → 100000, 10000, 1000, 100, 10, 1 |
| `Habitat` | forest, plains, freshwater, saltwater, swamp, mountain, desert | `displayName`, `colorHex` |
| `Season` | summer (May-Oct), winter (Nov-Apr) | `fromDate(DateTime)`, `opposite` |
| `Continent` | asia, northAmerica, southAmerica, africa, oceania, europe | `fromDataString()` handles IUCN format |
| `AnimalType` | mammal, bird, fish, reptile, bug | Auto-computed from IUCN `taxonomicClass` |
| `AnimalClass` | 35 values (carnivore, songbird, rodent, crocodile, etc.) | AI-enriched on first discovery |
| `Climate` | tropic, temperate, boreal, frigid | Derived from latitude (0°-23.5°, 23.5°-55°, 55°-66.5°, 66.5°-90°) |
| `FoodType` | critter, fish, fruit, grub, nectar, veg | Food category for sanctuary feeding |
| `OrbDimension` | habitat, class, climate | Orb type dimension (3 dimensions, ~46 total types) |
| `ActivityType` | photograph, forage, lure, survey | Cell activity types (future) |

### Value Objects

| Class | Fields | Equality | Notes |
|-------|--------|----------|-------|
| `ItemDefinition` (sealed) | Base class for all item types | — | 7 subclasses: FaunaDefinition, FloraDefinition, MineralDefinition, FossilDefinition, ArtifactDefinition, FoodDefinition, OrbDefinition |
| `FaunaDefinition` | scientificName, commonName, taxonomicClass, continents, habitats, iucnStatus, animalType, animalClass, foodPreference, climate | `scientificName` only | 32,752 IUCN records + AI enrichment fields |
| `FloraDefinition` | plantType | — | Stub (no dataset yet) |
| `MineralDefinition` | crystalSystem, hardness | — | Stub (no dataset yet) |
| `FossilDefinition` | era, fossilType | — | Stub (no dataset yet) |
| `ArtifactDefinition` | period, origin | — | Stub (no dataset yet) |
| `FoodDefinition` | foodType: `FoodType` | — | Predefined (6 types: critter, fish, fruit, grub, nectar, veg) |
| `OrbDefinition` | dimension: `OrbDimension`, variant: String | — | Predefined (3 dimensions: habitat, class, climate; ~46 total types) |
| `ItemInstance` | id (UUID), definitionId, category, affixes: `List<Affix>`, parentAId, parentBId, dailySeed, status, createdAt | all fields | Unique item with rolled stats |
| `Affix` | type (prefix/suffix), key, value | all fields | Flexible key-value stats |
| `ItemCategory` | enum: fauna, flora, mineral, fossil, artifact, food, orb | — | Item type classification (7 categories) |
| `ItemInstanceStatus` | enum: active, donated, placed, released, traded | — | Lifecycle state |
| `CellData` | id, center: Geographic, fogState, speciesIds, restorationLevel, distanceWalked, visitCount, lastVisited | — | `restorationLevel` clamped [0.0, 1.0] |
| `PlayerProgress` | userId, cellsObserved, speciesCollected, currentStreak, longestStreak, totalDistanceKm | — | Player stats aggregate |

### Auth Models (lib/features/auth/models/)

| Class | Fields | Notes |
|-------|--------|-------|
| `UserProfile` | id, email, displayName?, createdAt, isAnonymous | Immutable. `copyWith()`, `toJson()`/`fromJson()`. Anonymous users have `isAnonymous: true` |
| `AuthState` | status: `AuthStatus`, user: `UserProfile?`, errorMessage? | Status enum: `{unauthenticated, loading, authenticated}` |
| `UpgradePromptState` | shouldShow, hasBeenShown, showBanner | Computed from auth status (anonymous) + collection count (≥5 species) |

All models are immutable with manual `toJson()`/`fromJson()`. No code generation (no freezed).

### Species JSON Format (assets/species_data.json)

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

Loaded at startup by `SpeciesDataLoader`. Parsed into `List<FaunaDefinition>`.

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

## Repositories (lib/core/persistence/)

| Repository | Table | Key Operations |
|------------|-------|---------------|
| `ProfileRepository` | LocalPlayerProfile | `create`, `read(userId)`, `update`, `updateCurrentStreak`, `addDistance`, `getAllProfiles` |
| `CellProgressRepository` | LocalCellProgress | `create`, `read(userId, cellId)`, `readByUser`, `updateFogState`, `addDistance`, `getCellsByFogState` |
| `ItemInstanceRepository` | LocalItemInstance | `create`, `read(id)`, `readAll(userId)`, `update`, `delete(id)`, `readByStatus(userId, status)` |

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

When `SUPABASE_URL` is empty, `SupabasePersistence` is null. App runs offline-only. No sync queue — writes go directly.

### Startup Hydration

On app start, `gameCoordinatorProvider` hydrates inventory from SQLite before starting the game loop:

```
Auth settles (userId available)
  → itemInstanceRepositoryProvider.getItemsByUser(userId)
    → inventoryProvider.notifier.loadItems(items)
    → discoveryService.markCollected() for each item
      → startLoop()
```

**Race condition prevention**: `loadItems()` replaces inventory state entirely. The game loop must NOT start until hydration completes — a discovery during the race window would be wiped by the subsequent `loadItems()` call.

**Auth timing**: Auth initializes asynchronously (awaits Supabase bootstrap, then auto-signs-in). `gameCoordinatorProvider` reads `authProvider` — if userId is available immediately, it hydrates then starts. If auth is still loading, it uses `ref.listen<AuthState>` with a `started` guard to wait for auth to settle.

**Discovery persistence**: New discoveries are persisted fire-and-forget (`itemRepo.addItem().catchError(...)`) — the game loop is not blocked. TODO(T-writequeue) for Phase 3 write queue with retry.

### Design Target: Inventory Model
> Phase 1 COMPLETE. ItemInstance model is now live. Remaining: breeding, bundles, museum, daily seed.

Current model: `ItemInstance` with affixes, status lifecycle, breeding lineage fields.
Target model: Full breeding system, bundles, museum donations, daily seed rotation.

Key changes planned:
- Species stacked in Pack (inventory): "Mallard ×3" not just "Mallard: collected"
- Museum donations consume from inventory (permanent — cannot retrieve)
- Sanctuary placements consume from inventory (flexible — can rearrange)
- Release mechanic: return unwanted species to the wild
- Daily world seed: cells offer different species each day (midnight GMT rotation)
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
