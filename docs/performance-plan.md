# Performance Implementation Plan

> Based on `docs/performance-audit.md` (2026-03-15). Two targets:
> - **Boot: ≤4s to interactive** (map renders, camera moves, fog visible)
> - **Runtime: ≤10ms p90 interaction latency** (taps, pans, tab switches respond within one frame)
>
> Four phases, each independently shippable.

---

## The Targets

**Boot (≤10s):** LoadingScreen appears instantly (~500ms). Background work runs (Supabase init, auth, SQLite hydration, asset parsing). Map transition happens when the minimum set is ready (auth settled + SQLite hydrated). Heavy assets (biome 28MB, species 6.1MB) continue parsing after map renders — fallback services handle the gap. Total: LoadingScreen for ≤10s on any connection, then map is interactive.

**Runtime (≤10ms p90):** From the moment the map renders, 90% of frames complete all main-thread work within 10ms. No fog tick, widget rebuild, or MapLibre interop call blocks the main thread for >10ms. One 60fps frame = 16.67ms — a 10ms budget leaves 6ms headroom for the browser.

---

## Phase A: 4-Second Boot

> Map interactive in ≤4s on 4G. Assets load invisibly in background.

### A1. Non-blocking asset loading

`biome_features.json` (28 MB) and `species_data.json` (6.1 MB) currently `jsonDecode()` on the main thread. Even if deferred, the decode blocks for 1-12s when it eventually runs.

**Change:** Parse both assets using `Isolate.run()` on native, chunked async on web:

```dart
// Native: true background thread
final biomeIndex = await Isolate.run(() {
  final json = rootBundle.loadString('assets/biome_features.json');
  return BiomeFeatureIndex.load(json);
});

// Web: chunked parse that yields every N records
Future<BiomeFeatureIndex> parseChunked(String json) async {
  final decoded = await _jsonDecodeChunked(json, chunkSize: 500);
  // yield between chunks via Future.delayed(Duration.zero)
  return BiomeFeatureIndex.fromParsed(decoded);
}
```

`Isolate.run()` doesn't work on web — use the conditional import pattern (same as `CrashLogPersistence`). On web, chunk the parse into <10ms pieces with `await Future.delayed(Duration.zero)` between chunks.

**Fallback services** (`DefaultHabitatLookup`, empty `SpeciesService`) handle the gap. Map renders immediately, habitats/discoveries populate as assets finish parsing.

**Verify:** Main thread never blocks >10ms during asset loading. DevTools timeline shows no long frames during boot.

### A2. Fire-and-forget Supabase init

Currently `main()` awaits Supabase init + auth restore sequentially (1-3s).

**Change:** Fire Supabase init as a background future. Don't await it. The auth provider listens for when it completes and transitions from `loading` → `authenticated`. Add a 3s timeout.

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fire and forget — don't await
  unawaited(SupabaseBootstrap.initialize().timeout(
    const Duration(seconds: 3),
    onTimeout: () => null, // proceed without Supabase
  ));
  runApp(const ProviderScope(child: EarthNovaApp()));
}
```

**Verify:** App reaches loading screen within 500ms. Supabase features activate when init completes.

### A3. Lazy hydration

GameCoordinator hydration fetches 4 tables from Supabase + writes to SQLite. This blocks the game loop from starting.

**Change:** Start the game loop immediately with whatever is in SQLite (local cache). Fetch from Supabase in background. Merge results into state as they arrive.

Current: `fetchSupabase → writeSQLite → readSQLite → start loop`
Target: `readSQLite → start loop → fetchSupabase → merge`

**Verify:** Map is interactive before Supabase responds. Inventory/progress updates when Supabase data arrives.

**Phase A target: LoadingScreen ≤10s on any connection, then map interactive. Assets parse in background without blocking UI.**

---

## Phase B: Sub-10ms Fog Frames

> Every fog tick completes within 10ms on the main thread. The rendering pipeline never jank.

### B1. Conditional source updates (dirty flags)

9 MapLibre `updateGeoJsonSource()` calls per frame → only update what changed.

**Change:** Add dirty flags to `FogOverlayController`:

| Flag | Set when | Sources updated |
|------|----------|-----------------|
| `_fogDirty` | Player moves | fog-base, fog-mid, fog-border (3) |
| `_iconsDirty` | Cell entered | cell-icons (1) |
| `_borderDirty` | Location nodes loaded | border-fill, border-lines (2) |
| `_adminDirty` | Admin boundaries resolved | admin-fill, admin-lines (2) |
| `_habitatDirty` | New habitat cell entered | habitat-fill (1) |

Most frames: only fog is dirty → 3 calls instead of 9 → 15-45ms → **~5-15ms** with the GeoJSON already built.

**But 15ms still exceeds 10ms.** So also:

### B2. Stagger MapLibre updates across frames

Even 3 JS interop calls at 5-15ms each can exceed 10ms. Spread them across consecutive frames:

**Change:** Instead of `Future.wait([source1, source2, source3])`, update one source per frame:

```
Frame N:   update fog-base-src       (~5ms)
Frame N+1: update fog-mid-src        (~5ms)  
Frame N+2: update fog-border-src     (~5ms)
Frame N+3: idle                      (~0ms)
... repeat at ~10Hz
```

At 60fps, this means fog updates spread across 3 frames (50ms total) instead of jamming into one frame. Each individual frame stays <10ms. The visual difference is imperceptible — fog-base, fog-mid, and fog-border update within 33ms of each other.

**Verify:** No single frame exceeds 10ms of JS interop. Fog still looks smooth.

### B3. Event-driven territory + admin borders

Territory BFS and admin boundary GeoJSON rebuild every frame (2-5ms) even though they change rarely.

**Change:** Rebuild only on trigger events:
- Territory borders: rebuild when `locationNodesCache` setter is called
- Admin boundaries: rebuild when `onBoundariesResolved` fires
- Cache the built GeoJSON strings, reuse until next trigger

**Verify:** Borders still render. Updates visible within 1 frame of trigger.

### B4. Optimize shared edge detection

`_findSharedEdge()` is O(P²) per cell pair. Pre-compute via vertex hash.

**Change:** During cell boundary generation, hash each vertex to `"${(lat*1e6).round()}_${(lon*1e6).round()}"`. Build a map of `vertexHash → [cellId, cellId]`. Shared edges are vertices appearing in exactly 2 cells. Lookup is O(1).

**Verify:** Border lines render identically.

**Phase B target: No fog frame exceeds 10ms on the main thread. Territory/admin borders computed <1ms.**

---

## Phase C: Scoped Rebuilds

> Widget rebuilds are O(1) — only the widget that needs to update rebuilds.

### C1. Add `.select()` everywhere

| Widget | Current (rebuilds on) | Fix (rebuilds on) |
|--------|----------------------|-------------------|
| StatusBar | Any of 8 playerProvider fields | `cellsObserved`, `totalSteps`, `currentStreak` only |
| CellInfoSheet | Any playerProvider field | `totalSteps` only |
| ZooTab | Any of 5 sanctuaryProvider fields | `speciesByHabitat`, `healthPercentage`, `currentStreak` only |
| FaunaGridTab | Any packProvider field | `itemsByCategory[fauna]` only |
| PackScreen | Full authProvider | `user?.id` only |
| SanctuaryScreen | Full authProvider | `user?.id` only |

### C2. Audit MapScreen ref.watch

MapScreen `ref.watch(cameraModeProvider)` triggers full MapScreen rebuild. If cameraMode is only used in callbacks → `ref.read()`. If used in build tree → keep but verify rebuild cost <10ms.

### C3. Extract high-frequency sub-widgets

If any widget's rebuild exceeds 10ms even with `.select()`, extract the dynamic part into a child widget with its own `Consumer`:

```dart
// Instead of rebuilding the entire StatusBar:
class StatusBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _CellCount(),      // Consumer that watches cellsObserved only
      _StepCount(),      // Consumer that watches totalSteps only
      _StreakIndicator(), // Consumer that watches currentStreak only
    ]);
  }
}
```

Each sub-widget rebuilds independently. No cascade.

**Phase C target: No single widget rebuild exceeds 10ms. Provider changes only affect the widgets that display the changed data.**

---

## Phase D: Measure and Enforce

> Continuous performance monitoring — regressions caught before deploy.

### D1. Performance events with timing

Emit `performance` category events for every operation that could exceed 10ms:

```dart
eventSink.add(GameEvent.performance('fog_frame', {
  'geojson_build_ms': buildTime,
  'source_update_ms': updateTime,
  'total_ms': totalTime,
  'sources_updated': dirtyCount,
  'cells_visible': cellCount,
}));
```

### D2. P90 dashboard query

```sql
SELECT 
  percentile_cont(0.90) WITHIN GROUP (ORDER BY (data->>'total_ms')::int) as p90_ms,
  percentile_cont(0.50) WITHIN GROUP (ORDER BY (data->>'total_ms')::int) as p50_ms,
  max((data->>'total_ms')::int) as max_ms
FROM app_events 
WHERE event = 'fog_frame'
AND created_at > now() - interval '24 hours';
```

### D3. Long-frame detection

Emit a `system/long_frame` event whenever a frame exceeds 10ms:

```dart
SchedulerBinding.instance.addTimingsCallback((timings) {
  for (final timing in timings) {
    final buildMs = timing.buildDuration.inMilliseconds;
    final rasterMs = timing.rasterDuration.inMilliseconds;
    if (buildMs + rasterMs > 10) {
      eventSink?.add(GameEvent.performance('long_frame', {
        'build_ms': buildMs,
        'raster_ms': rasterMs,
        'total_ms': buildMs + rasterMs,
      }));
    }
  }
});
```

**Phase D target: Real-time visibility into p90 frame time. Long frames automatically logged.**

---

## Dependency Graph

```
Phase A (Boot)               Phase B (Fog Frames)        Phase C (Rebuilds)      Phase D (Measure)
  A1 (chunked asset parse)     B1 (dirty flags)            C1 (.select())          D1 (perf events)
  A2 (Supabase fire-forget)    B2 (stagger updates)        C2 (camera audit)       D2 (p90 query)
  A3 (lazy hydration)          B3 (event-driven borders)   C3 (sub-widget extract) D3 (long frame detect)
                               B4 (edge hash)
```

All phases are independent. Within phases:
- B2 depends on B1 (stagger is only useful once dirty flags reduce the source count)
- B4 depends on B3 (edge hash only matters when borders rebuild on trigger, not every frame)
- D1 should ship with or before B1 (so you can measure the improvement)

**Recommended order:** D1 → A1 → A2 → B1 → B2 → C1 → A3 → B3 → B4 → C2 → C3 → D2 → D3

Start with D1 (measure) so you have before/after data. Then A1+A2 (biggest boot wins). Then B1+B2 (biggest frame wins).

---

## Effort Estimates

| Item | Effort | Impact |
|------|--------|--------|
| A1. Chunked/isolate asset parsing | 2-3 hours | Eliminates 3-12s main thread block |
| A2. Fire-and-forget Supabase | 30 min | Eliminates 1-3s boot block |
| A3. Lazy hydration (SQLite-first) | 2-3 hours | Eliminates 1.5-4s boot block |
| B1. Dirty-flag source updates | 2-3 hours | 9 → 3 JS interop calls/frame |
| B2. Stagger MapLibre updates | 1-2 hours | 15ms → 5ms per frame |
| B3. Event-driven borders | 1-2 hours | 2-5ms/frame → 0ms |
| B4. Spatial hash shared edges | 1-2 hours | 2ms → 0.1ms per rebuild |
| C1. Add .select() to 6 widgets | 30 min | Eliminates rebuild cascades |
| C2. Camera mode audit | 15 min | Minor |
| C3. Extract high-frequency sub-widgets | 1-2 hours | Splits large rebuilds |
| D1. Performance timing events | 1 hour | Enables measurement |
| D2. P90 dashboard query | 15 min | Visibility |
| D3. Long-frame detection | 30 min | Regression detection |
| **Total** | **~14-20 hours** | **≤10ms p90 interaction latency** |

---

## Success Criteria

| Metric | Current | Target |
|--------|---------|--------|
| LoadingScreen duration (any connection) | 8-30s | ≤10s |
| Main thread block (max) | 3-12s (jsonDecode) | <10ms |
| Fog frame time (p90) | 55-154ms | <10ms |
| MapLibre JS interop calls/frame | 9 | 1-3 (staggered) |
| Widget rebuilds per fog tick | All watched widgets | Only fog-dependent |
| Long frames (>10ms) per session | Unknown | Measured via D3, trending to 0 |
