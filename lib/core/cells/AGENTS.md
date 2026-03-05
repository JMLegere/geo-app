# Cell System

Voronoi + H3 spatial indexing behind CellService interface. CellCache decorator for memoization.

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

## Performance

- `getCellId(lat, lon)`: O(9) — checks 3×3 grid around nearest grid point
- `getCellBoundary(cellId)`: O(n log n) first call (Delaunay), O(1) cached
- `getNeighborIds(cellId)`: Computed together with boundary (same Delaunay pass)
- `getCellsInRing(cellId, k)`: BFS k rings. k=0 returns [cellId]. k=1 = immediate neighbors.

## Gotchas

- Voronoi boundaries are NOT closed polygons — first vertex is NOT repeated as last
- `getCellsAroundLocation(lat, lon, k)` is a convenience: resolves cellId first, then calls getCellsInRing
- Grid step is in degrees, not meters — actual cell size varies with latitude
- Bowyer-Watson requires super-triangle — implementation handles edge cases near grid boundaries
- H3 FFI requires native library: test with `LD_LIBRARY_PATH=. flutter test`
- CellCache ring key format: `"cellId:k"` — cache miss if same ring requested with different k
