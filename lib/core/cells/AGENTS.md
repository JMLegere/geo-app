# Cell System

Voronoi spatial indexing behind CellService interface. CellCache decorator for memoization.

## LazyVoronoiCellService (Primary)

Infinite-world Voronoi with lazy seed materialization:
- Grid: seeds placed at `gridStep` (0.002°, ~180m at 45° lat) spacing with deterministic jitter
- Jitter: `jitterFactor` (0.75) × `gridStep`, seeded by `globalSeed` (42) + grid position
- Cell ID: `"v_{row}_{col}"` — globally unique, deterministic, parseable
- Boundaries: Delaunay triangulation (Bowyer-Watson) → dual Voronoi. Computed lazily on first `getCellBoundary()` call.
- Neighbor radius: 3 (materializes 7×7 = 49 seeds around query point for accurate Delaunay)
- Median cell diameter: ~180m (tuned for 2-min walking between discoveries at 5 km/h)

## CellCache (Decorator)

Memoizes: `getCellCenter()`, `getCellBoundary()`, `getNeighborIds()`, `getCellsInRing(cellId, k)` (keyed by `"cellId:k"`).
Does NOT cache `getCellId()` — already O(1) lookup.
Public: `clearCache()`, `cacheSize` getter. Use `clearCache()` in tests.

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

## Moved Out of cells/

- `CellPropertyResolver` → `features/world/` (biome + climate + continent resolution)
- `EventResolver` → `features/world/` (deterministic daily cell events)
- `H3CellService` → deleted (Voronoi is the sole implementation)

## Performance

- `getCellId(lat, lon)`: O(9) — checks 3×3 grid around nearest grid point
- `getCellBoundary(cellId)`: O(n log n) first call (Delaunay), O(1) cached
- `getNeighborIds(cellId)`: Computed together with boundary (same Delaunay pass)
- `getCellsInRing(cellId, k)`: BFS k rings. k=0 returns [cellId]. k=1 = immediate neighbors.
- `CountryResolver.resolve()`: O(countries × vertices) worst case, but bbox pre-filter makes it fast in practice

## Gotchas

- Voronoi boundaries are NOT closed polygons — first vertex is NOT repeated as last
- `getCellsAroundLocation(lat, lon, k)` is a convenience: resolves cellId first, then calls getCellsInRing
- Grid step is in degrees, not meters — actual cell size varies with latitude
- Bowyer-Watson requires super-triangle — implementation handles edge cases near grid boundaries
- CellCache ring key format: `"cellId:k"` — cache miss if same ring requested with different k
- CountryResolver 110m resolution excludes some coastal points — fallback to legacy ContinentResolver
