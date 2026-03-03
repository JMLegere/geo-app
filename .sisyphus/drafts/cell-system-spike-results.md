# Cell System Spike Results

**Date**: 2026-03-02  
**Task**: Compare H3 hexagonal grid vs brute-force Voronoi tessellation for the fog-of-world cell system.  
**Test location**: San Francisco (37.7749, -122.4194)

---

## Implementations

| File | Class | Approach |
|------|-------|----------|
| `lib/features/spikes/h3_spike.dart` | `H3CellService` | Wraps `h3_flutter_plus` (FFI → Uber's C H3 library) |
| `lib/features/spikes/voronoi_spike.dart` | `VoronoiCellService` | Brute-force nearest-neighbor, jittered grid seeds |

---

## Cell Shape Comparison

### H3 (Hexagons)

- **Shape**: Uniform regular hexagons (5-vertex pentagons at icosahedron vertices, ~12 per globe)
- **Size**: Resolution 9 → ~174m edge length, ~0.1 km² area
- **Coverage**: Full global tiling with mathematically guaranteed no gaps, no overlaps
- **Visual**: Clean, predictable honeycomb pattern aligned to a global index
- **Uniformity**: Every cell has exactly 6 neighbors (except pentagons with 5); all cells same size

### Voronoi

- **Shape**: Irregular convex polygons derived from nearest-neighbor partition
- **Size**: Variable — cells near the bbox edges tend to be larger, interior cells compressed
- **Coverage**: Covers the bounding box only; no concept of global tiling
- **Visual**: Organic, irregular pattern; cell sizes vary significantly with jitter
- **Uniformity**: Neighbor count varies (typically 4-8 per cell in a jittered grid)

---

## Performance Benchmarks

All measurements from `flutter test` on Linux (debug mode). Actual values from test run:

### Generate 500+ Cells Around a Point

| Approach | Cells Generated | Time |
|----------|----------------|------|
| H3 (k=13 gridDisk) | 547 cells | **~4 ms** |
| Voronoi (20×25 grid, seed gen only) | 500 cells | **<1 ms** |

**Note**: Voronoi seed generation is O(n) list construction — fast because it's just computing random offsets. H3 uses FFI into a C library with allocation overhead per cell.

### 1000 Point-in-Cell Lookups

| Approach | Lookups | Time |
|----------|---------|------|
| H3 `getCellId` | 1000 | **6 ms** (~6 µs/lookup) |
| Voronoi `getCellForPoint` | 1000 | **<1 ms** (<1 µs/lookup) |

**Note**: Voronoi lookups scan all 400 seeds (brute force O(n)), but n=400 and no FFI overhead → faster in practice. H3 has FFI marshalling cost per call. At n=10,000 seeds Voronoi would cross over.

### Find Neighbors for 100 Cells

| Approach | Cells | Time |
|----------|-------|------|
| H3 `getNeighbors` k=1 | 91 cells | **2 ms** (~22 µs/cell) |
| Voronoi `getNeighbors` | 17 unique cells | **26 ms** (~1.5 ms/cell) |

**Note**: Voronoi neighbor detection requires a 50×50 grid scan (2500 point lookups) per cell — O(n·m) where n=seeds, m=sample grid size. H3 `gridDisk` is a pure index computation, O(1).

---

## Determinism

| Property | H3 | Voronoi |
|----------|----|----|
| Same lat/lon → same cell ID | ✅ Globally guaranteed | ✅ Within same seed/grid config |
| Cross-device reproducibility | ✅ Absolute (algorithm-defined) | ✅ With fixed seed (dart:math Random) |
| Cross-version reproducibility | ✅ H3 spec is versioned | ⚠️ Depends on dart:math RNG stability |
| Cell IDs are portable | ✅ H3 BigInt hex strings, e.g. `8928308280fffff` | ❌ Integer index, meaningless outside a session |

---

## Neighbor Lookup Comparison

| Property | H3 | Voronoi |
|----------|----|----|
| Neighbor count | Always 6 (hexagons) or 5 (pentagons) | Variable (4-8+ typical) |
| Algorithm complexity | O(1) — pure index math | O(n·m) — brute force grid scan |
| k-ring (multi-hop) | `gridDisk(k)` → exact k-ring in O(k²) | Requires BFS over neighbor graph |
| Cross-antimeridian | ✅ Handled by H3 | N/A (bounding box only) |

---

## Dart Ecosystem Quality

| Dimension | H3 (`h3_flutter_plus`) | Voronoi (hand-rolled) |
|-----------|------------------------|----------------------|
| Library maturity | Published package, wraps Uber's H3 v4.2.1 | Spike-quality brute force |
| API surface | Full H3 spec (polygonToCells, compacting, etc.) | Minimal (lookup, boundary, neighbors) |
| Web support | ✅ WASM fallback via h3-js | ❌ Dart-only |
| iOS/Android | ✅ FFI + prebuilt .so | ✅ Pure Dart |
| Testing surface | Battle-tested by Uber at scale | Spike only; boundary heuristics are approximate |
| Polygon-to-cells | ✅ `polygonToCells()` built-in | ❌ Would require custom implementation |
| Compacting/uncompacting | ✅ Multi-resolution hierarchy | ❌ Not possible |
| Integration cost | Import + `H3Factory().load()` | ~200 lines + ongoing maintenance |

---

## Key Limitations Observed

### H3
- **FFI startup cost**: `H3Factory().load()` touches the native library once; subsequent calls are fast.
- **Pentagon edge case**: ~12 pentagonal cells exist per globe at each resolution. At res 9, extremely unlikely to encounter in practice.
- **k-ring size formula**: `3k²+3k+1` cells — k=13 → 547 cells, not k=12 → 469. Tests must use exact formula.

### Voronoi
- **Boundary approximation**: Cells with only 1-2 sample points in the sampling grid get a synthetic triangle fallback — boundary is not accurate for small cells.
- **Neighbor detection O(n·m)**: 26ms for 17 cells; would be >150ms for 100 cells at production scale.
- **No global identity**: Cell IDs are indices into a session-local list; cannot be stored, synced, or referenced across app restarts without serializing the full seed list.
- **Bounding box required**: The service must be re-instantiated (or extended) if the player moves outside the initial bbox.

---

## Recommendation

**Use H3.**

### Rationale

1. **Portability of cell IDs**: H3 cell IDs are globally unique 64-bit integers encodable as hex strings. They can be stored in SQLite, synced to Supabase, and decoded on any device without any additional state. Voronoi IDs are session-local indices — syncing explored cells across sessions or devices would require transmitting the entire seed list.

2. **Neighbor lookup is O(1)**: `gridDisk` is pure index arithmetic. At GPS update frequency (1 Hz) this is trivially cheap. Voronoi's O(n·m) neighbor scan is already 26ms at 400 seeds and scales quadratically.

3. **No bounding box constraint**: Voronoi requires a pre-defined bbox. H3 tiles the globe; the player can walk anywhere without reconfiguring the service.

4. **Ecosystem**: `h3_flutter_plus` wraps the production-hardened Uber H3 C library. We get polygon-to-cells, multi-resolution compacting, and web WASM support for free. The Voronoi approach would require ~500+ lines of production-quality code to reach equivalent functionality.

5. **Predictable cell size**: Uniform hexagons make game balance deterministic — every cell at resolution 9 is ~0.1 km², meaning species spawn rates, restoration mechanics, and fog density are consistent everywhere on the map.

6. **Integration with CellData**: `CellData.id` (String) maps directly to the H3 hex string. `CellData.center` (Geographic) maps to `(centerLat, centerLon)` from `getCellCenter`. No schema changes required.

### When Voronoi Would Win
Voronoi would be the right choice if: (a) cells needed to follow geographic features (rivers, roads, park boundaries), (b) we needed variable-density cells (dense urban, sparse rural), or (c) we were targeting a small fixed region with no sync requirement. None of these apply to fog-of-world.

---

## Implementation Notes for Task 12

```dart
// Create the service once at app startup
final cellService = H3CellService(resolution: 9);

// GPS update → cell ID
final cellId = cellService.getCellId(location.lat, location.lon);

// Hydrate CellData
final (cLat, cLon) = cellService.getCellCenter(cellId);
final cell = CellData(
  id: cellId,
  center: Geographic(lat: cLat, lon: cLon),
  fogState: FogState.undetected,
  // ...
);

// Neighbor traversal (fog reveal radius)
final nearby = cellService.getNeighbors(cellId, k: 2); // 19 cells
```

The `H3CellService` can be exposed as a Riverpod `Provider` (not `StateNotifier` — it is stateless) and injected into the fog state system.
