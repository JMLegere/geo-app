# Performance Audit — Mobile Web

> Audit date: 2026-03-15. Target: iPhone + Firefox Focus. App feels slow on initial load and during gameplay.

---

## Executive Summary

Three categories of bottleneck, in order of impact:

1. **Boot: 28 MB biome asset blocks the main thread for 3-12 seconds** — everything waits on `jsonDecode()` of `biome_features.json`
2. **Runtime: 9 MapLibre JS interop calls per 100ms frame** — each one serializes large GeoJSON strings across the Dart→JS bridge
3. **Rebuilds: Missing `.select()` scoping** — fog updates at 10Hz cascade to unrelated widgets

Fixing these three gets you from "slow" to "responsive" on mobile web.

---

## Boot Path (URL → First Interactive Frame)

### Current Timeline

```
0ms      main() starts
100ms    Supabase.initialize() [AWAIT — 500-2000ms network]
2100ms   authService.restoreSession() [AWAIT — 500-1000ms network]
3100ms   Providers created
         ├─ biome_features.json [28 MB] — load + jsonDecode + grid build [3-12s]
         ├─ species_data.json [6.1 MB] — load + jsonDecode + 32K records [1-3.5s]
         ├─ country_boundaries.json [146 KB] — load + jsonDecode [150-500ms]
         └─ Supabase hydration — 4 parallel RPCs + SQLite upserts [1.5-4s]
~8-10s   First interactive frame (desktop)
~15-30s  First interactive frame (mobile 3G/4G)
```

### Bottlenecks

| # | What | Size | Cost | Fix |
|---|------|------|------|-----|
| 1 | `biome_features.json` load + parse | 28 MB | 3-12s | Defer until after map interactive; fallback returns `{plains}` |
| 2 | `species_data.json` load + parse | 6.1 MB | 1-3.5s | Defer until after map interactive; empty service during boot |
| 3 | Supabase init + auth restore | Network | 1-3s | Parallelize with asset loads (don't await sequentially) |
| 4 | Supabase hydration (4 RPCs) | Network | 1.5-4s | Already parallel; add per-fetch timeout |
| 5 | `country_boundaries.json` | 146 KB | 150-500ms | Defer; bounding-box fallback already exists |

### Quick Wins

**Defer biome + species loading** — these assets aren't needed for the first frame. The map renders, fog works, camera moves — all without biome data or species catalogs. Fallback services already exist:
- `DefaultHabitatLookup` returns `{plains}` when biome index isn't loaded
- `SpeciesService` works with an empty catalog (no discoveries fire, but the map is interactive)

**Parallelize Supabase init** — don't `await` it in `main()`. Fire it in the background, let the app boot with whatever auth state is cached, resolve once Supabase responds.

**Target: <3s to first interactive frame on 4G.**

---

## Runtime (10Hz Game Loop + Rendering)

### Current Per-Frame Budget

At 10Hz, each frame has 100ms. Here's what currently runs:

| Operation | Cost | Frequency | Blocks Main Thread |
|-----------|------|-----------|-------------------|
| 9× `updateGeoJsonSource()` JS interop | 45-135ms | 10Hz | Yes |
| 6× GeoJSON string builders | 5-10ms | 10Hz | Yes |
| Territory border BFS + shared edge detection | 2-5ms | 10Hz | Yes |
| Viewport sampling (779 samples + neighbor expansion) | ~2ms | 10Hz | Yes |
| GeoJSON string serialization | 1-2ms | 10Hz | Yes |
| **Total** | **55-154ms** | **10Hz** | |

The frame budget is 100ms. We're spending **55-154ms** — regularly exceeding it. On mobile web (slower JS engine), the upper end dominates.

### Bottlenecks

| # | What | Cost | Fix |
|---|------|------|-----|
| 1 | **9 MapLibre JS interop calls** per frame | 45-135ms | Batch into 2-3 calls; only update sources that changed |
| 2 | **Territory border `_findSharedEdge()`** — O(P²) brute force per cell pair | 2-5ms | Spatial hashing or pre-compute shared edges |
| 3 | **6 GeoJSON builders** run every frame, even when nothing changed | 5-10ms | Dirty-flag: skip unchanged layers |
| 4 | **Territory BFS** runs when location cache is empty | 2-5ms | Early exit guard |

### The Big Fix: Conditional Source Updates

Most frames, only the fog layers change (player moved). Territory borders, admin boundaries, habitat fills, and cell icons rarely change. But all 9 sources are rebuilt and pushed every frame.

**Fix: Track what changed and only update dirty sources.**

```
Frame where player moved (most frames):
  → Rebuild fog (base + mid + borders) — 3 sources
  → Skip territory, admin, habitat, icons — 0 sources
  → 3 JS interop calls instead of 9

Frame where cell entered (occasional):
  → Rebuild fog + icons — 4 sources
  → Skip territory, admin, habitat — 0 sources

Frame where enrichment arrived (rare):
  → Rebuild territory + admin — 4 sources
  → Fog unchanged — 0 sources
```

**Expected improvement: 45-135ms → 15-45ms per frame (3x faster).**

---

## Widget Rebuild Cascades

### Current State

| Widget | Provider Watched | Change Frequency | Uses `.select()` | Rebuilds |
|--------|-----------------|-----------------|-------------------|----------|
| MapScreen | `cameraModeProvider` | Rare | No | Full MapScreen on toggle |
| StatusBar | `playerProvider` | Variable | No (watches all 8 fields) | On any player change |
| CellInfoSheet | `playerProvider` | Variable | No | On any player change |
| ZooTab | `sanctuaryProvider` | Variable | No (watches all 5 fields) | Full scroll view |
| FaunaGridTab | `packProvider` | Variable | No | Full grid rebuild |
| LocationBanner | `locationProvider` | Variable | **Yes** ✅ | Only on error change |
| PlayerMarkerLayer | `ValueNotifier` | 60fps | **Yes** ✅ | Only marker position |

### Fixes

**StatusBar** — only needs `cellsObserved`, `totalSteps`, `currentStreak`:
```dart
final cellsObserved = ref.watch(playerProvider.select((p) => p.cellsObserved));
```

**ZooTab** — only needs `speciesByHabitat`, `healthPercentage`, `currentStreak`:
```dart
final speciesByHabitat = ref.watch(sanctuaryProvider.select((s) => s.speciesByHabitat));
```

**FaunaGridTab** — only needs fauna items:
```dart
final faunaItems = ref.watch(packProvider.select((p) => p.itemsByCategory[ItemCategory.fauna]));
```

**CellInfoSheet** — only needs `totalSteps`:
```dart
final totalSteps = ref.watch(playerProvider.select((p) => p.totalSteps));
```

---

## Prioritized Fix List

| Priority | Category | Fix | Effort | Impact |
|----------|----------|-----|--------|--------|
| 🔴 P0 | Boot | Defer biome + species loading until after map interactive | 30 min | 4-15s saved |
| 🔴 P0 | Runtime | Only update MapLibre sources that actually changed (dirty flags) | 2-3 hours | 3x frame speed |
| 🟠 P1 | Boot | Parallelize Supabase init (don't await in main) | 15 min | 1-3s saved |
| 🟠 P1 | Rebuild | Add `.select()` to StatusBar, ZooTab, FaunaGridTab, CellInfoSheet | 30 min | Eliminates cascade |
| 🟡 P2 | Runtime | Spatial hashing for territory border shared edges | 1-2 hours | 2-5ms/frame |
| 🟡 P2 | Runtime | Early exit for territory BFS when location cache empty | 5 min | 2-5ms/frame |
| 🟡 P2 | Runtime | Lazy-rebuild territory borders (event-driven, not 10Hz) | 1 hour | 2-5ms/frame |
| 🟢 P3 | Boot | Split biome_features.json by region (load only nearby) | 1-2 days | 20-25 MB saved |
| 🟢 P3 | Boot | Split species_data.json by continent | 1-2 days | 4-5 MB saved |

---

## Target Performance

| Metric | Current | After P0+P1 | After All |
|--------|---------|-------------|-----------|
| Boot to interactive (4G) | 8-10s | 3-4s | 2-3s |
| Boot to interactive (3G) | 15-30s | 5-8s | 3-5s |
| Frame time (10Hz) | 55-154ms | 15-45ms | 10-20ms |
| MapLibre JS calls/frame | 9 | 2-3 | 2-3 |
| Widget rebuilds/fog tick | All watched widgets | Only fog-dependent widgets | Same |
