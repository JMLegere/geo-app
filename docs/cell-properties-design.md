# Cell Properties Design

> Every cell has permanent geo-derived properties and a rotating event layer. Properties determine encounter context, map icons, and territory borders. Design jam decision (2026-03-10).

---

## Core Concept

**Cells are not empty containers.** Each Voronoi cell has intrinsic properties — habitat(s), climate, location in a real-world admin hierarchy — plus a daily-rotating event slot. Properties are resolved when a cell becomes adjacent, cached globally in Supabase (shared across all players), and used as encounter context when the player enters the cell.

**Two layers:**
- **Permanent layer** — geo-derived from real-world data, never changes. Habitats, climate, location hierarchy.
- **Rotating layer** — deterministic from daily seed + cell ID, changes daily. Events (migration, nesting site).

**Events replace base encounters.** A cell with an active event skips the normal species roll entirely. The event defines its own encounter logic.

---

## Data Model

### CellProperties (Cached Per-Cell)

Resolved once when any player first makes the cell adjacent. Globally shared — not per-user.

```dart
@immutable
class CellProperties {
  final String cellId;
  final Set<Habitat> habitats;          // 1+ per cell, never empty
  final Climate climate;                // single value from latitude
  final String? locationId;             // FK → LocationNode, null until enriched
  final Continent continent;            // from country boundaries (fast)
  final DateTime createdAt;

  // Not persisted — recomputed from daily seed:
  // final CellEvent? event;
}
```

**Key rules:**
- `habitats` always has at least one entry (Plains is the fallback)
- `climate` derived from `abs(cellCenter.lat)` via `Climate.fromLatitude()`
- `continent` derived from bundled country boundaries (instant, offline-capable)
- `locationId` backfilled async via Nominatim — null is valid (enrichment pending)
- `event` is NOT stored — deterministic from seed, recomputed on access

### CellEvent (Rotating Layer)

```dart
enum CellEventType {
  migration,
  nestingSite;

  String get displayName => switch (this) {
    CellEventType.migration => 'Migration',
    CellEventType.nestingSite => 'Nesting Site',
  };
}

@immutable
class CellEvent {
  final CellEventType type;
  final String cellId;
  final String dailySeed;
}
```

**Event resolution:** `SHA-256(dailySeed + "_event_" + cellId)`:
1. First 4 bytes → `uint32` → `eventChance = uint32 % 100`
2. `eventChance < 12` → event fires (~12% of cells). Otherwise null.
3. Next 4 bytes → `uint32` → `eventIndex = uint32 % CellEventType.values.length`
4. Equal weights across all event types. Self-balancing as types are added.

### LocationNode (Admin Hierarchy)

```dart
@immutable
class LocationNode {
  final String id;                      // UUID
  final int osmId;                      // OSM relation ID
  final String name;                    // "Fredericton", "New Brunswick", etc.
  final AdminLevel adminLevel;          // continent, country, state, city, district
  final String? parentId;               // FK → parent LocationNode
  final String? colorHex;               // territory color from flag, or null
}

enum AdminLevel {
  continent,                            // admin_level 1
  country,                              // admin_level 2
  state,                                // admin_level 4
  city,                                 // admin_level 6-8
  district;                             // admin_level 9-10

  String get displayName => switch (this) {
    AdminLevel.continent => 'Continent',
    AdminLevel.country => 'Country',
    AdminLevel.state => 'State/Province',
    AdminLevel.city => 'City',
    AdminLevel.district => 'District',
  };
}
```

**Hierarchy:** World > Continent > Country > State > City > District.

Continent is derived FROM country (static mapping table, ~200 entries). Every country belongs to exactly one continent.

---

## Permanent Layer

### Habitats (7)

A cell may have **multiple** habitats. Resolved from `BiomeFeatureIndex` spatial queries against the cell center coordinate.

| Habitat | Triggers |
|---------|----------|
| **Forest** | Forest region, park, garden, cemetery, golf course, university campus, allotment garden |
| **Plains** | Farmland, cropland, grassland, meadow, sports field, schoolyard — OR default fallback if nothing else matches |
| **Freshwater** | River, lake, canal, reservoir, fountain, urban pond |
| **Saltwater** | Coastline, marina, harbor, pier, wharf, beach |
| **Swamp** | Wetland (bog, marsh, fen, mangrove, mudflat), constructed wetland, stormwater pond |
| **Mountain** | Peak point with radius = `elevation_m / 100` km (e.g., 500m peak → 5km radius, Everest → 88km) |
| **Desert** | Desert region (centroid + radius) |

**Implementation change:** Current `BiomeFeatureIndex` supports coastline, rivers, lakes, mountains, deserts, wetlands, forests. Must be expanded with new feature layers for: parks, gardens, cemeteries, golf courses, universities, allotment gardens, farmland, cropland, grassland, meadows, sports fields, schoolyards, canals, reservoirs, fountains, urban ponds, marinas, harbors, piers, wharfs, beaches, constructed wetlands, stormwater ponds. The `biome_features.json` asset needs corresponding data.

**Mountain radius formula:** Each peak point has an elevation-derived radius. A cell within `elevation_m / 100` km of the peak gets the Mountain habitat. This means Everest (8849m) creates an 88km mountain zone, while a 500m hill creates a 5km zone.

### Climate (4)

Single value per cell. Already implemented in `Climate.fromLatitude()`.

| Zone | Latitude range | Example |
|------|---------------|---------|
| Tropic | 0°–23.5° | Equatorial belt |
| Temperate | 23.5°–55° | Most of US, Europe |
| Boreal | 55°–66.5° | Northern Canada, Scandinavia |
| Frigid | 66.5°–90° | Arctic, Antarctic |

Derived from `abs(cellCenter.lat)`. No network call needed.

### Location (6-level hierarchy)

```
World > Continent > Country > State/Province > City > District/Neighborhood
```

**Resolution:**
1. **Continent + Country** — resolved locally from bundled Natural Earth 1:110m country boundary polygons. Point-in-polygon test against cell center. Instant, offline-capable. Country → Continent via static mapping table.
2. **State → City → District** — resolved async via Supabase Edge Function → Nominatim reverse geocode. Backfilled after cell properties are created.

**Data source:** OSM admin boundaries via Nominatim. Supabase is the global cache — first player to encounter a cell pays the Nominatim cost, subsequent players get a cache hit.

**Country boundaries asset:** Natural Earth 1:110m Admin-0 Countries dataset (~200 polygons). Bundled as `assets/country_boundaries.json`. Gives offline country/continent resolution with no network dependency. Approximate borders sufficient for continent-level species filtering.

**Country → Continent mapping:** Static `Map<String, Continent>` keyed by ISO 3166-1 country code. ~200 entries. Bundled in the `CountryResolver` service.

---

## Rotating Layer (Events)

### Event Types

| Event | Effect on encounter | Details |
|-------|-------------------|---------|
| **Migration** | Replaces base encounter | Species from a **different continent** AND **different climate** than the cell's own. Gives access to species normally unavailable in this area. |
| **Nesting Site** | Replaces base encounter | Guaranteed EN, CR, or EX rarity species from the cell's **native habitat**. Rare species hunt. |

**Deferred events** (not yet implemented):
- Dig Site — fossils, minerals, artifacts
- Treasure Trail — quest chain
- Wandering Trader — special offers

### Event Rules

- **~12% of cells** have an event on any given day
- **Equal weights** for all event types (currently 50/50 with 2 events, self-balancing as more are added)
- **Events replace base encounters** — the normal species roll does NOT fire. The event defines its own encounter logic.
- **No habitat lock** — any event can appear on any cell regardless of habitat
- **Deterministic** — `SHA-256(dailySeed + "_event_" + cellId)` → same cell + same seed = same event
- **Not persisted** — recomputed on demand from seed + cell ID

### Event Encounter Logic

**Migration:**
```
1. Get cell's continent and climate
2. Pick a different continent (deterministic from seed)
3. Pick a different climate (deterministic from seed)
4. Build species pool: habitats × foreignContinent filtered to foreignClimate
5. Roll from this pool using standard LootTable mechanics
```

**Nesting Site:**
```
1. Get cell's habitats and continent
2. Build species pool: cell habitats × continent, filtered to EN + CR + EX only
3. Roll from this pool (guaranteed rare)
```

---

## Resolution Flow

### Trigger

Cell becomes **adjacent** (GameCoordinator detects new neighbor). NOT at detection radius, NOT on entry.

### Sequence

```
Cell becomes adjacent
  │
  ├─ Check SQLite cache → HIT → use cached CellProperties, done
  │
  └─ MISS → Check Supabase → HIT → cache to SQLite, done
       │
       └─ MISS → Resolve fresh:
            ├─ Habitat:   BiomeFeatureIndex.getBiomesNear(lat, lon) → Set<Habitat>   [instant]
            ├─ Climate:   Climate.fromLatitude(lat)                                   [instant]
            ├─ Continent: CountryResolver.resolve(lat, lon) → Country → Continent     [instant]
            ├─ Event:     EventResolver.resolve(dailySeed, cellId) → CellEvent?       [instant]
            └─ Location:  Supabase Edge Function → Nominatim reverse geocode          [async, backfill]
            
            → Save to SQLite (local cache)
            → Write-through to Supabase (global cache, keyed by cell_id)
            → Location backfills when Nominatim responds (updates both SQLite + Supabase)
```

### Timing

Properties are resolved when **adjacent**. Discovery fires when **entered**. The gap (player walks from adjacency to entry) gives async location enrichment time to complete. In practice:

- Habitat, Climate, Continent, Event: ready instantly
- Location (state/city/district): typically ready in <500ms (Nominatim response time)
- Edge case — app launch (player already in cell): adjacency and entry are simultaneous. Habitat + climate + continent are still instant. Location may be briefly null.

### Offline Behavior

| Property | Offline source | Status |
|----------|---------------|--------|
| Habitat | BiomeFeatureIndex (bundled asset) | Works |
| Climate | Latitude math | Works |
| Continent | Bundled country boundaries | Works |
| Event | Local hash of cached daily seed | Works |
| Location (state+) | SQLite cache from previous sessions | Works if previously visited area |
| Location (new area) | Not available until online | Gracefully null |

**Discovery never blocks on network.** Habitat + Climate + Continent are always available locally. Species filtering needs only continent (from bundled data). Location below country is display-only — does not affect encounter rolls.

---

## Discovery Integration

### Current Flow (unchanged for cells without events)

```
Player enters cell
  → SpeciesService.getSpeciesForCell(
      cellId, habitats, continent,
      dailySeed, encounterSlots
    )
  → LootTable roll → List<FaunaDefinition>
  → Create ItemInstances → InventoryProvider → UI toast
```

**Change:** `habitats` and `continent` now come from cached `CellProperties` instead of being computed on-the-fly by `HabitatService` + `ContinentResolver`.

### New Flow (cells with events)

```
Player enters cell
  → Check CellProperties.event
  │
  ├─ null → Normal encounter (unchanged flow above)
  │
  ├─ Migration → MigrationEncounter:
  │    1. foreignContinent = pickDifferent(cell.continent, seed)
  │    2. foreignClimate = pickDifferent(cell.climate, seed)
  │    3. pool = speciesService.getPoolForArea(
  │         habitats: cell.habitats,
  │         continent: foreignContinent,
  │       ).where((s) => s.climate == foreignClimate)
  │    4. Roll from pool → ItemInstances → UI toast (with Migration badge)
  │
  └─ NestingSite → NestingSiteEncounter:
       1. pool = speciesService.getPoolForArea(
            habitats: cell.habitats,
            continent: cell.continent,
          ).where((s) => s.rarity is EN or CR or EX)
       2. Roll from pool → ItemInstances → UI toast (with Nesting Site badge)
```

### DiscoveryService Changes

`DiscoveryService` gains a `CellProperties` parameter:

```dart
class DiscoveryService {
  /// Roll encounter for a cell. If cell has an event, the event
  /// replaces the base encounter entirely.
  List<FaunaDefinition> rollEncounter({
    required String cellId,
    required String dailySeed,
    required CellProperties properties,
    int encounterSlots = kEncounterSlotsPerCell,
  }) {
    final event = EventResolver.resolve(dailySeed, cellId);
    if (event != null) {
      return _rollEventEncounter(event, properties, dailySeed);
    }
    return _speciesService.getSpeciesForCell(
      cellId: cellId,
      dailySeed: dailySeed,
      habitats: properties.habitats,
      continent: properties.continent,
      encounterSlots: encounterSlots,
    );
  }
}
```

---

## Map Visualization

### Property Icons

Icons are small sprites displayed on cell polygons showing their properties.

| Cell state | What renders |
|------------|-------------|
| **Current cell** | Full property grid: small habitat + climate icons at edges, large event icon centered |
| **Adjacent cell** | Event icon only (if present) |
| **Unvisited cell with event** | Solo "?" icon (Witcher 3 style) — event exists but type unknown |
| **Visited cell** | Full property grid shown permanently |
| **Stale cell** (daily seed changed since last visit) | Permanent facts stay (habitat, climate), "?" replaces event slot |

**Zoom-gated:** Icons only render above a threshold zoom level (e.g., zoom 14+).

### Information Model (AoE2/RTS Fog-of-War)

| State | Definition | Properties shown |
|-------|-----------|-----------------|
| **Live** | Current cell + adjacent cells | Real-time properties, freshly resolved |
| **Last Known** | Visited, not adjacent, seed unchanged | Snapshot from last adjacency — persists as-is |
| **Stale** | Visited, not adjacent, seed changed since last visit | Permanent facts stay, "?" on event slot |

**Cell info only updates when adjacent.** Moving away preserves last-known state. Revisiting (becoming adjacent again) refreshes all properties.

### Territory Borders (Stellaris-Style)

**Concept:** Admin boundaries rendered along Voronoi cell edges. Where two adjacent cells belong to different admin regions, the shared edge is a border.

**Not** smooth OSM polygon curves. Borders snap to cell edges — the Voronoi grid IS the world map, like Stellaris hex borders.

#### Border Lines

Solid colored line on Voronoi edges where admin regions differ at any level.

| Admin level | Line weight | Zoom gate |
|-------------|------------|-----------|
| Country | Thickest (3px) | Always visible |
| State | Medium (2px) | Mid zoom+ |
| City | Thin (1.5px) | Close zoom+ |
| District | Thinnest (1px) | Closest zoom only |

#### Gradient Fill

Cells near a border are tinted with their own region's color, fading inward. Each cell is a discrete unit — gradient is stepped by cell distance from the border.

**6 conceptual layers with quadratic opacity falloff:**

| Distance from border | Opacity | Visual |
|---------------------|---------|--------|
| Border cell (0 cells) | ~0.15 | Clearly tinted |
| 1 cell in | ~0.04 | Subtle tint |
| 2 cells in | ~0.01 | Barely visible |
| 3+ cells in | 0.00 | Clean map |

With cells averaging ~150m, 2 cells of fade ≈ 250m. Matches design spec.

**Implementation:** Each cell polygon in the MapLibre GeoJSON layer gets additional feature properties:

```json
{
  "cell_id": "v_123_456",
  "border_distance_district": 0,
  "border_distance_city": 3,
  "border_distance_state": 8,
  "border_distance_country": 15,
  "region_color_district": "#3B7DD8",
  "region_color_city": "#2E8B57"
}
```

Three MapLibre layers per visible admin level:
1. **Fill layer** — `fill-color` from region color, `fill-opacity` driven by border distance (data expression, quadratic curve)
2. **Line layer** — Voronoi edges where admin regions differ, width by admin level
3. Both zoom-gated per admin level

#### Border Colors

- **Primary color of the territory's flag** (if available in OSM data or manually curated)
- **Deterministic random** from OSM relation ID if no flag color: `SHA-256(osmId) → first 3 bytes → RGB`
- Stored in `LocationNode.colorHex` (nullable — null triggers deterministic random)

#### Stacking Rules

- Only the **lowest-level differing border** renders between two adjacent cells
- Two cells in same country + same state + different districts → district border only
- Two cells in different countries → country border (thickest)
- Interior cells (3+ cells from any border) → no tint, clean map
- **95% of map surface is clean/uncolored**

---

## Persistence

### SQLite (Drift — Local Cache)

```dart
@DataClassName('LocalCellPropertiesData')
class LocalCellPropertiesTable extends Table {
  TextColumn get cellId => text()();                          // Voronoi cell ID (PK)
  TextColumn get habitats => text()();                        // JSON array of habitat names
  TextColumn get climate => text()();                         // Climate enum name
  TextColumn get continent => text()();                       // Continent enum name
  TextColumn get locationId => text().nullable()();           // FK → location_nodes
  TextColumn get createdBy => text()();                       // user ID who first resolved
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {cellId};
}

@DataClassName('LocalLocationNodeData')
class LocalLocationNodeTable extends Table {
  TextColumn get id => text()();                              // UUID (PK)
  IntColumn get osmId => integer()();                         // OSM relation ID
  TextColumn get name => text()();                            // "Fredericton"
  TextColumn get adminLevel => text()();                      // AdminLevel enum name
  TextColumn get parentId => text().nullable()();             // FK → parent node
  TextColumn get colorHex => text().nullable()();             // hex from flag, or null
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
```

### Supabase (Source of Truth)

```sql
-- Cell properties: global, shared across all players
create table cell_properties (
  cell_id         text primary key,
  habitats        text[] not null,                            -- e.g. {'forest', 'freshwater'}
  climate         text not null,                              -- enum name
  continent       text not null,                              -- enum name
  location_id     uuid references location_nodes(id),         -- nullable, backfilled async
  created_by      uuid references auth.users not null,
  created_at      timestamptz not null default now()
);

-- No RLS — cell properties are global (read by all, written by first discoverer)
create index idx_cell_properties_location on cell_properties(location_id);

-- Location hierarchy: admin boundaries from OSM
create table location_nodes (
  id              uuid primary key default gen_random_uuid(),
  osm_id          bigint unique not null,
  name            text not null,
  admin_level     text not null,                              -- AdminLevel enum name
  parent_id       uuid references location_nodes(id),
  color_hex       text,                                       -- hex from flag, or null for random
  created_at      timestamptz not null default now()
);

create index idx_location_nodes_parent on location_nodes(parent_id);
create index idx_location_nodes_osm on location_nodes(osm_id);
```

**No geometry column on location_nodes.** Border rendering uses cell-edge detection (adjacent cells with different `locationId`), not polygon geometry. The admin boundary geometry is only used server-side during Nominatim enrichment to determine which location_node a cell belongs to.

### Write-Through Pattern

```
CellPropertyResolver resolves new cell
  → INSERT into LocalCellPropertiesTable (SQLite)
  → Enqueue to WriteQueueRepository (existing write queue)
  → WriteQueue flushes to Supabase cell_properties table

LocationEnrichment completes (Nominatim response)
  → INSERT into LocalLocationNodeTable (if new nodes)
  → UPDATE LocalCellPropertiesTable.locationId
  → Enqueue updates to WriteQueue
```

---

## Services

### CellPropertyResolver (New — `lib/core/cells/`)

Pure Dart service. Resolves all cell properties from inputs.

```dart
class CellPropertyResolver {
  final HabitatService _habitatService;
  final CountryResolver _countryResolver;

  /// Resolve permanent properties for a cell. Instant, no network.
  CellProperties resolve({
    required String cellId,
    required double lat,
    required double lon,
    required String userId,
  }) {
    final habitats = _habitatService.classifyLocation(lat, lon);
    final climate = Climate.fromLatitude(lat);
    final continent = _countryResolver.resolveContinent(lat, lon);

    return CellProperties(
      cellId: cellId,
      habitats: habitats,
      climate: climate,
      continent: continent,
      locationId: null,   // backfilled async
      createdAt: DateTime.now(),
    );
  }
}
```

### CountryResolver (New — `lib/core/cells/`)

Replaces `ContinentResolver` bounding-box heuristics with real country boundary data.

```dart
class CountryResolver {
  /// Loaded from assets/country_boundaries.json
  /// List of (countryCode, continent, polygon) tuples.
  final List<CountryBoundary> _boundaries;

  /// Static mapping: ISO 3166-1 alpha-2 → Continent
  static const Map<String, Continent> _countryToContinent = {
    'CA': Continent.northAmerica,
    'US': Continent.northAmerica,
    'BR': Continent.southAmerica,
    // ... ~200 entries
  };

  /// Point-in-polygon test against bundled country boundaries.
  String? resolveCountryCode(double lat, double lon);

  /// Country code → Continent via static mapping.
  Continent resolveContinent(double lat, double lon) {
    final code = resolveCountryCode(lat, lon);
    return _countryToContinent[code] ?? _fallbackContinent(lat, lon);
  }

  /// Fallback: existing ContinentResolver bounding-box heuristic
  /// for coordinates not in any country polygon (oceans, edge cases).
  Continent _fallbackContinent(double lat, double lon);
}
```

### EventResolver (New — `lib/core/cells/`)

Pure Dart, deterministic, no state.

```dart
class EventResolver {
  /// Resolve event for a cell on a given day. Returns null for ~88% of cells.
  static CellEvent? resolve(String dailySeed, String cellId) {
    final hash = sha256('${dailySeed}_event_$cellId');
    final chance = hash.first4BytesAsUint32 % 100;
    if (chance >= kCellEventChancePercent) return null;  // 12% threshold

    final eventIndex = hash.next4BytesAsUint32 % CellEventType.values.length;
    return CellEvent(
      type: CellEventType.values[eventIndex],
      cellId: cellId,
      dailySeed: dailySeed,
    );
  }
}
```

### CellPropertyRepository (New — `lib/core/persistence/`)

```dart
class CellPropertyRepository {
  final AppDatabase _db;

  Future<CellProperties?> get(String cellId);
  Future<void> upsert(CellProperties properties);
  Future<void> updateLocationId(String cellId, String locationId);
  Future<List<CellProperties>> getForCells(List<String> cellIds);
}
```

### LocationNodeRepository (New — `lib/core/persistence/`)

```dart
class LocationNodeRepository {
  final AppDatabase _db;

  Future<LocationNode?> get(String id);
  Future<LocationNode?> getByOsmId(int osmId);
  Future<void> upsert(LocationNode node);
  Future<List<LocationNode>> getAncestors(String nodeId);  // walk parent chain
}
```

---

## GameCoordinator Integration

### Current Wiring (`game_coordinator_provider.dart`)

GameCoordinator receives callbacks for discovery, cell visits, persistence. Cell properties adds a new callback chain.

### New Callback

```dart
// In gameCoordinatorProvider setup:
coordinator.onCellBecameAdjacent = (String cellId, double lat, double lon) async {
  // 1. Check local cache
  var props = await cellPropertyRepo.get(cellId);
  if (props != null) return props;

  // 2. Check Supabase
  props = await supabasePersistence?.getCellProperties(cellId);
  if (props != null) {
    await cellPropertyRepo.upsert(props);  // cache locally
    return props;
  }

  // 3. Resolve fresh
  props = cellPropertyResolver.resolve(
    cellId: cellId, lat: lat, lon: lon, userId: userId,
  );
  await cellPropertyRepo.upsert(props);

  // 4. Write to Supabase (via write queue)
  await writeQueueRepo.enqueue(WriteQueueEntry(
    entityType: 'cell_properties',
    entityId: cellId,
    operation: 'upsert',
    payload: props.toJson(),
    userId: userId,
  ));

  // 5. Fire async location enrichment
  _enrichLocation(cellId, lat, lon);

  return props;
};
```

### Modified Discovery Flow

```dart
// In GameCoordinator.processDiscovery():
coordinator.onCellVisited = (String cellId) async {
  final props = await cellPropertyRepo.get(cellId);  // guaranteed cached from adjacency
  if (props == null) return;  // shouldn't happen

  final event = EventResolver.resolve(dailySeed, cellId);

  List<FaunaDefinition> species;
  if (event != null) {
    species = discoveryService.rollEventEncounter(
      event: event, properties: props, dailySeed: dailySeed,
    );
  } else {
    species = discoveryService.rollEncounter(
      cellId: cellId, dailySeed: dailySeed, properties: props,
    );
  }

  // ... create ItemInstances, persist, notify UI (unchanged)
};
```

---

## Constants (New — `lib/shared/constants.dart`)

```dart
/// Percentage of cells that have an event on any given day.
const int kCellEventChancePercent = 12;

/// Seed domain separator for event resolution.
const String kEventSeedPrefix = '_event_';

/// Default proximity radius (km) for BiomeFeatureIndex habitat queries.
const double kHabitatQueryRadiusKm = 5.0;

/// Border gradient fade distance in meters (~2 cell widths).
const double kBorderGradientFadeMeters = 250.0;

/// Number of opacity layers for border gradient fill.
const int kBorderGradientLayers = 6;

/// Maximum border fill opacity (innermost layer).
const double kBorderMaxOpacity = 0.15;

/// Zoom threshold below which cell property icons are hidden.
const double kCellIconMinZoom = 14.0;
```

---

## Migration from Current System

### What Changes

| Component | Current | After |
|-----------|---------|-------|
| Habitat resolution | `HabitatService` called per-discovery, not cached | `CellPropertyResolver` resolves on adjacency, cached globally |
| Continent resolution | `ContinentResolver` bounding-box heuristic | `CountryResolver` with real country boundaries + fallback |
| Discovery context | Computed on-the-fly | Read from cached `CellProperties` |
| Events | Don't exist | `EventResolver` + event-specific encounter logic |
| Cell identity | `CellData` (fog + progress only) | `CellData` + `CellProperties` (separate concerns) |
| Map rendering | Fog overlay only | Fog + property icons + territory borders |

### What Doesn't Change

- `CellData` model (fog state, visit count, distance, restoration) — untouched
- `FogStateResolver` — unchanged
- `LootTable` mechanics — unchanged
- `SpeciesService` — unchanged (called with different inputs)
- Write queue pattern — reused for cell property persistence
- Daily seed system — extended with event seed domain

### Implementation Order

| Step | Change | Breaking? |
|------|--------|-----------|
| 1 | Add `CellEvent`, `CellEventType`, `LocationNode`, `AdminLevel` models | No |
| 2 | Add `CellProperties` model | No |
| 3 | Bundle country boundaries asset + `CountryResolver` service | No |
| 4 | Add `EventResolver` service | No |
| 5 | Add `CellPropertyResolver` service | No |
| 6 | Add Drift tables (`LocalCellPropertiesTable`, `LocalLocationNodeTable`) + repos | Schema migration |
| 7 | Add Supabase tables (`cell_properties`, `location_nodes`) | Migration |
| 8 | Wire `CellPropertyResolver` into `gameCoordinatorProvider` (adjacency callback) | Non-breaking addition |
| 9 | Modify `DiscoveryService` to accept `CellProperties` + handle events | **Breaking** — discovery pipeline changes |
| 10 | Expand `BiomeFeatureIndex` with new feature layers | Asset update |
| 11 | Add map icon rendering layer | UI addition |
| 12 | Add territory border rendering layers | UI addition |
| 13 | Add Supabase Edge Function for Nominatim enrichment | Server-side |

Steps 1–8 are additive. Step 9 is the breaking change. Steps 10–13 are independent enhancements.

---

## Open Questions

| Question | Impact | Notes |
|----------|--------|-------|
| BiomeFeatureIndex data source for new features (parks, canals, etc.) | Asset pipeline | Need OSM extract → biome_features.json expansion |
| Mountain elevation data source for peak radius formula | Asset pipeline | Need elevation dataset (SRTM? OSM peaks?) |
| Border color curation (flag colors vs deterministic random) | Visual quality | Could start with all-random, curate top-20 countries later |
| Location enrichment Edge Function design | Server implementation | Nominatim rate limits, caching strategy |
| Event encounter slot count | Game balance | Same as base (kEncounterSlotsPerCell=1)? Different? |
| Migration: which continents/climates are "different"? | Event logic | All non-matching, or weighted by distance? |
| Nesting Site: minimum pool size guard | Edge case | What if no EN/CR/EX species exist for this habitat+continent? |
| Existing `ContinentResolver` — remove or keep as fallback? | Code cleanup | `CountryResolver` uses it as ocean fallback |
