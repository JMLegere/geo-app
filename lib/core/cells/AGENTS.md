# Cell System

Voronoi + H3 spatial indexing behind CellService interface. CellCache decorator for memoization. Cell property resolution (habitat, climate, continent, events).

## LazyVoronoiCellService (Primary)

Infinite-world Voronoi with lazy seed materialization:
- Grid: seeds placed at `gridStep` (0.002°, ~180m at 45° lat) spacing with deterministic jitter
- Jitter: `jitterFactor` (0.75) × `gridStep`, seeded by `globalSeed` (42) + grid position
- Cell ID: `"v_{row}_{col}"` — globally unique, deterministic, parseable
- Boundaries: Delaunay triangulation (Bowyer-Watson) → dual Voronoi. Computed lazily on first `getCellBoundary()` call.
- Neighbor radius: 3 (materializes 7×7 = 49 seeds around query point for accurate Delaunay)
- Median cell diameter: ~180m (tuned for 2-min walking between discoveries at 5 km/h)

## H3CellService (Fallback)

- Resolution 9: ~174m edge length, ~0.1 km² area
- Cell IDs: hex string of BigInt H3 index (e.g., "8928308280fffff")
- Always 6 neighbors (hex ring k=1)
- Requires `LD_LIBRARY_PATH=.` for FFI at runtime

## CellCache (Decorator)

Memoizes: `getCellCenter()`, `getCellBoundary()`, `getNeighborIds()`, `getCellsInRing(cellId, k)` (keyed by `"cellId:k"`).
Does NOT cache `getCellId()` — already O(1) lookup in both implementations.
Public: `clearCache()`, `cacheSize` getter. Use `clearCache()` in tests.

## CellPropertyResolver

Resolves permanent geo-derived properties for a cell. **Synchronous and instant** — runs in the game tick.

**Public API**: `resolve(String cellId, double lat, double lon)` → `CellProperties`

**Resolution**:
1. `HabitatLookup.classifyLocation(lat, lon)` → `Set<Habitat>` (from BiomeFeatureIndex / DefaultHabitatLookup)
2. `Climate.fromLatitude(lat)` → `Climate` enum
3. `ContinentLookup.resolve(lat, lon)` → `Continent` enum (from CountryResolver)
4. `locationId` starts null — backfilled async via Nominatim Edge Function

**Interfaces**:
- `HabitatLookup`: `Set<Habitat> classifyLocation(double lat, double lon)`. Implemented by `HabitatService` (features/biome/).
- `ContinentLookup`: `Continent resolve(double lat, double lon)`. Implemented by `CountryResolver`.
- `DefaultHabitatLookup`: Fallback — returns `{Habitat.plains}` for all coordinates.

**Test doubles**: `implement CellPropertyResolver` (not extend) — override `resolve()`.

## EventResolver

Deterministic daily event assignment for cells. ~12% of cells get an event per day.

**Public API**: `static CellEvent? resolve(String dailySeed, String cellId)`

**Determinism**: `SHA-256("${dailySeed}_event_${cellId}")` → first 4 bytes → mod 100. If < 12, event fires.
**Event selection**: same hash → mod eventCount → picks `CellEventType`. Equal weights for all events.

**Event types** (`CellEventType` enum):
- `migration` — species from a different continent (prefers different climate when enrichment available)
- `nestingSite` — guaranteed EN/CR/EX species from cell's native habitats

**Key rule**: Events REPLACE base encounters (not additive). Not persisted — recomputable from seed + cellId.

## CountryResolver

Offline country→continent resolution using bundled Natural Earth 1:110m country boundaries.

**Public API**: `Continent resolve(double lat, double lon)` (implements `ContinentLookup`)

**Algorithm**:
1. Bounding-box pre-filter (skip countries whose bbox doesn't contain the point)
2. Ray-casting point-in-polygon test against polygon rings
3. Country → continent via static `_countryToContinent` mapping (~175 countries)
4. Fallback: legacy `ContinentResolver` bounding-box heuristics (for ocean coordinates)

**Asset**: `assets/country_boundaries.json` (146KB, 175 countries, ~10K coordinate points)

**Loading**: `CountryResolver.load(String jsonString)` factory — called by `countryResolverProvider` (FutureProvider).

**Gotcha**: NYC (40.7, -74.0) falls outside 110m-resolution US polygon — coastal coordinates may be excluded at this simplification level. Fallback handles these gracefully.

## Performance

- `getCellId(lat, lon)`: O(9) — checks 3×3 grid around nearest grid point
- `getCellBoundary(cellId)`: O(n log n) first call (Delaunay), O(1) cached
- `getNeighborIds(cellId)`: Computed together with boundary (same Delaunay pass)
- `getCellsInRing(cellId, k)`: BFS k rings. k=0 returns [cellId]. k=1 = immediate neighbors.
- `CellPropertyResolver.resolve()`: O(1) — all lookups are array/map scans or latitude math
- `CountryResolver.resolve()`: O(countries × vertices) worst case, but bbox pre-filter makes it fast in practice

## Gotchas

- Voronoi boundaries are NOT closed polygons — first vertex is NOT repeated as last
- `getCellsAroundLocation(lat, lon, k)` is a convenience: resolves cellId first, then calls getCellsInRing
- Grid step is in degrees, not meters — actual cell size varies with latitude
- Bowyer-Watson requires super-triangle — implementation handles edge cases near grid boundaries
- H3 FFI requires native library: test with `LD_LIBRARY_PATH=. flutter test`
- CellCache ring key format: `"cellId:k"` — cache miss if same ring requested with different k
- CellPropertyResolver is a class, NOT abstract — test doubles must `implement` it
- CountryResolver 110m resolution excludes some coastal points — fallback to legacy ContinentResolver
- EventResolver seed format: `"${dailySeed}_event_${cellId}"` — changing this breaks event reproducibility
