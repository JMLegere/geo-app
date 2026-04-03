# Bootstrap and Initialization Sequence Report

**Generated:** 2026-04-02  
**Scope:** Complete app initialization from `main()` to first interactive frame  
**Key Files:**
- `lib/main.dart` — Entry point, error handling, zone setup
- `lib/core/state/game_coordinator_provider.dart` — Central orchestrator (1384 lines)
- `lib/core/state/player_provider.dart` — Player state hydration
- `lib/features/auth/providers/auth_provider.dart` — Auth state management
- `lib/shared/widgets/tab_shell.dart` — Navigation shell

---

## 1. Initialization Timeline

### Phase 0: Pre-Flutter (Synchronous, ~0-50ms)

```
main() called
  ↓
WidgetsFlutterBinding.ensureInitialized()
  ↓
Image cache configuration (platform-aware)
  ├─ iOS/Android mobile: 50MB cache, 200 items max
  └─ Desktop/Web: 200MB cache, 500 items max
  ↓
StartupBeacon.emit('supabase_init')
  ↓
SupabaseBootstrap.initialize(httpClient: ObservableHttpClient())
  ├─ Validates SUPABASE_URL and SUPABASE_ANON_KEY env vars
  ├─ If both present: initializes Supabase client
  └─ If missing: sets initialized=false (offline mode)
  ↓
StartupBeacon.promote(Supabase.instance.client) [if initialized]
```

**Outcome:** Supabase client ready (or null for offline mode).

---

### Phase 1: Auth Service Creation (Synchronous, ~50-100ms)

```
Create AuthService based on Supabase availability
  ├─ If Supabase initialized: SupabaseAuthService()
  └─ If offline: MockAuthService()
  ↓
Load cached fun facts from SharedPreferences
  ├─ Key: 'fun_facts_cache'
  └─ Used by LoadingScreen while auth restores
  ↓
Create ProviderContainer with overrides
  ├─ Override cachedFunFactsProvider with loaded facts
  └─ Container is the root of the Riverpod graph
  ↓
Inject AuthService into authServiceProvider
  └─ container.read(authServiceProvider.notifier).set(authService)
```

**Outcome:** ProviderContainer ready, AuthService injected.

---

### Phase 2: Session Restore (Async, ~100-500ms)

```
StartupBeacon.emit('session_restore')
  ↓
authService.restoreSession()
  ├─ Supabase: checks for stored session token
  └─ Mock: always returns false
  ↓
If session exists:
  ├─ authService.getCurrentUser() → User object
  └─ container.read(authProvider.notifier).setState(AuthState.authenticated(user))
Else:
  └─ container.read(authProvider.notifier).setState(AuthState.unauthenticated())
  ↓
Bridge authService stream → authProvider
  └─ authService.authStateChanges.listen((user) { ... })
     (Handles token refresh, session expiry, external sign-out)
  ↓
StartupBeacon.emit('session_restore_done')
```

**Outcome:** Auth state settled (authenticated or unauthenticated).

---

### Phase 3: Error Handlers & Observability (Synchronous, ~500-600ms)

```
FlutterError.onError = (details) { ... }
  ├─ Logs to DebugLogBuffer
  └─ Captures stack trace (first 15 frames)
  ↓
ErrorWidget.builder = _GlobalErrorFallback
  └─ Replaces red/blue crash screen with recovery UI
  ↓
Timer.periodic(1s) → DebugLogBuffer.drainPending()
  └─ Feeds lines to LogFlushService for debounced Supabase shipping
  ↓
DebugLogBuffer.onCrash / onAuthEvent callbacks
  └─ Trigger immediate flush on critical events
```

**Outcome:** Global error handling active, observability pipeline ready.

---

### Phase 4: Zone Setup & App Launch (Synchronous, ~600-700ms)

```
runZonedGuarded(
  () {
    runApp(UncontrolledProviderScope(
      container: container,
      child: _ObservabilityLifecycleObserver(
        child: EarthNovaApp()
      )
    ))
    _setupPerfMonitoring(container)
  },
  (error, stack) { ... }  // Unhandled zone errors
)
```

**Outcome:** App widget tree mounted, zone error handler active.

---

### Phase 5: Widget Tree Build (Async, ~700-1000ms)

```
EarthNovaApp.build()
  ↓
ref.read(gameCoordinatorProvider)  ← EAGER INIT
  └─ Triggers full game coordinator initialization (see Phase 6)
  ↓
ref.watch(authProvider)
  ↓
MaterialApp(
  home: AnimatedSwitcher(
    child: _resolveHome(authState)
  )
)
```

**Routing Decision Tree:**
```
authState.status:
  ├─ loading → LoadingScreen (auth/hydration in progress)
  ├─ otpSent → OtpVerificationScreen
  ├─ otpVerifying → OtpVerificationScreen (same screen, no rebuild)
  ├─ unauthenticated → LoginScreen
  └─ authenticated:
      ├─ !hasCompletedOnboarding → OnboardingScreen
      └─ hasCompletedOnboarding → _SteadyStateShell
```

**Outcome:** Root route determined by auth state.

---

### Phase 6: Game Coordinator Initialization (Async, ~1000-3000ms)

This is the **critical path** for gameplay readiness. Happens in `gameCoordinatorProvider.build()`:

#### 6a. Infrastructure Setup (Synchronous, ~1000-1100ms)

```
Create GameEngine
  ├─ Wraps GameCoordinator (pure Dart)
  ├─ Injects FogStateResolver, CellService, StatsService
  └─ Initializes dual-position model (rawGpsPosition, playerPosition)
  ↓
Wire cell property resolver
  └─ coordinator.setCellPropertyResolver(cellPropertyResolver)
  ↓
Wire discovery service cell properties lookup
  └─ discoveryService.cellPropertiesLookup = (cellId) => cache[cellId]
  ↓
Wire enrichment stats lookup
  └─ coordinator.enrichedStatsLookup = (definitionId) => speciesCache.getByIdSync()
  ↓
Create ObservabilityBuffer singleton
  └─ ObservabilityBuffer.instance = obs
  ↓
Create LogFlushService (if Supabase configured)
  └─ Debounced 5s flush to app_logs table
```

**Outcome:** Game engine ready, callbacks wired.

#### 6b: Startup Diagnostics (Fire-and-Forget, ~1100-1200ms)

```
Async block (no await):
  ├─ Query SQLite for counts (species, items, cells, enriched)
  ├─ Collect platform info (OS, version, locale, Dart version)
  ├─ Emit 'app_startup' event with full diagnostics
  └─ Log to debugPrint
```

**Outcome:** Observability event queued.

#### 6c: Callback Chaining (Synchronous, ~1200-1300ms)

Wire engine callbacks → provider mutations:

```
coordinator.onPlayerLocationUpdate
  ├─ Engine callback fires first (event emission)
  └─ Provider logic follows (locationProvider.updateLocation)
  ↓
coordinator.onGpsErrorChanged
  ├─ Engine callback fires first
  └─ Provider logic follows (locationProvider.setError)
  ↓
coordinator.onCellVisited
  ├─ Engine callback fires first
  ├─ Provider logic: playerProvider.incrementCellsObserved()
  ├─ Persist cell visit to SQLite + write queue
  └─ Request location enrichment (cell + neighbors)
  ↓
coordinator.onItemDiscovered
  ├─ Engine callback fires first
  ├─ Award first-discovery badge (if offline mode)
  ├─ Provider logic: discoveryProvider.showDiscovery(), itemsProvider.addItem()
  └─ Persist to SQLite + write queue
  ↓
coordinator.onCellPropertiesResolved
  ├─ Engine callback fires first
  └─ Persist cell properties to SQLite + write queue
```

**Outcome:** All callbacks wired, mutations will fire on events.

#### 6d: Detection Zone Listener (Async, ~1300-1400ms)

```
detectionZoneService.onDetectionZoneChanged.listen((zoneCellIds) {
  // Phase 1: In-memory resolution (synchronous, <50ms)
  ├─ fogResolver.setDetectionZone(zoneCellIds)
  ├─ Pre-resolve cell properties into memory cache (no persist)
  ├─ Stamp locationId into memory cache
  ├─ Feed fog overlay with fully-populated cache
  └─ Warm species cache for all unique (habitat, continent) combos
  
  // Phase 2: Deferred persistence (batched microtask, ~75ms/batch)
  └─ Persist to SQLite + enqueue for Supabase (batches of 5 with yields)
  
  // Signal zone ready
  └─ zoneReadyProvider.notifier.markReady() [if zoneCellIds.isNotEmpty]
})
```

**Outcome:** Zone listener active, will trigger when zone resolves.

#### 6e: Location Enrichment Listener (Async, ~1400-1500ms)

```
locationEnrichmentSvc.onLocationEnriched.listen((event) {
  // Update in-memory cell properties cache with locationId
  └─ coordinator.updateCellPropertyLocationId(cellId, locationId)
})
```

**Outcome:** Enrichment listener active.

#### 6f: Queue Processor Auto-Flush Callback (Synchronous, ~1500-1600ms)

```
queueProcessor.onAutoFlushComplete = (summary) async {
  ├─ Emit 'sync_flushed' event
  ├─ If rejections: processRejections()
  ├─ If first badges: applyFirstBadges()
  └─ Refresh pending count in sync UI
}
```

**Outcome:** Auto-flush callback wired.

#### 6g: Hydration & Game Loop Start (Async, ~1600-3000ms)

```
hydrateAndStart(userId) called when auth settles
  ↓
Phase 1: SQLite Hydration (fast, ~200-500ms)
  ├─ rehydrateData(userId):
  │   ├─ itemRepo.getItemsByUser(userId)
  │   ├─ cellProgressRepo.readByUser(userId)
  │   ├─ profileRepo.read(userId)
  │   └─ cellPropertyRepo.getAll()
  │
  ├─ Load cell properties into memory cache
  ├─ Re-resolve plains-only cells (if biome data now available)
  ├─ Hydrate inventory: itemsProvider.notifier.loadItems(items)
  ├─ Hydrate cell progress: fogResolver.loadVisitedCells(visitedCellIds)
  ├─ Hydrate player profile: playerProvider.notifier.loadProfile(...)
  ├─ Mark hydrated: playerProvider.notifier.markHydrated()
  ├─ Hydrate step counter: stepProvider.notifier.hydrate(...)
  └─ Capture lastPersistedProfile (guard for write-through listener)
  ↓
  Warm species cache:
  ├─ For all unique (habitat, continent) combos in cell properties
  └─ For all owned species IDs (Pack grid resolution)
  ↓
  Startup enrichment backfill:
  ├─ Priority: current cell + neighbors (unblocks zone fast)
  └─ Remaining: all cached cells without locationId (capped at 50)
  ↓
  startLoop():
  ├─ Fetch daily seed: dailySeedService.fetchSeed()
  ├─ Subscribe coordinator to GPS stream
  ├─ Start location service: locationService.start()
  └─ Game loop now running at ~10Hz
  ↓
  Start live pedometer (native only)
  ↓
Phase 2: Supabase Hydration (background, ~500-2000ms)
  ├─ hydrateFromSupabase(userId):
  │   ├─ Fetch profile, cell progress, items in parallel
  │   ├─ Fetch cell properties for visited cells
  │   ├─ Upsert all rows to SQLite (with yields every 50 rows)
  │   ├─ Delta-sync species enrichment (full sync, no watermark)
  │   ├─ Upsert hierarchy tables (countries, states, cities, districts)
  │   └─ Refresh species cache
  │
  ├─ Reload cell properties from SQLite
  ├─ Recompute detection zone (picks up new districts)
  ├─ On cold start: re-hydrate providers from Supabase-populated SQLite
  ├─ Backfill intrinsic affixes for items missing stats
  └─ Refresh fun facts cache + trigger pool growth
```

**Outcome:** Game loop running, providers hydrated, background sync in flight.

---

### Phase 7: Steady-State Shell & Loading Dismissal (Async, ~2000-3000ms)

```
_SteadyStateShell.build()
  ↓
Watch gates:
  ├─ playerState.isHydrated (set by markHydrated())
  ├─ zoneReadyProvider (set when zone resolves with >0 cells)
  ├─ playerLocatedProvider (set when rubber-band converges or 15s timeout)
  └─ gpsPermissionState (not unknown)
  ↓
If onboarding incomplete:
  └─ Show OnboardingScreen (no map)
Else:
  ├─ Mount TabShell (map always mounted via Offstage)
  └─ Overlay LoadingScreen with AnimatedOpacity
      ├─ Opacity: 1.0 while !allReady
      └─ Opacity: 0.0 when allReady (400ms fade)
  ↓
When allReady:
  ├─ IgnorePointer(ignoring: true) on loading screen
  ├─ Map gestures become responsive
  └─ StartupBeacon.emit('loading_dismissed')
```

**Outcome:** Map visible, loading screen fading out.

---

### Phase 8: Performance Monitoring (Continuous, ~3000ms+)

```
_setupPerfMonitoring(container)
  ↓
SchedulerBinding.addTimingsCallback()
  ├─ Track frame build/raster times
  ├─ Log frames >200ms as JANK
  └─ Emit 'long_frame' events
  ↓
Timer.periodic(10s)
  ├─ Log image cache stats
  └─ Log slow frame count
  ↓
Timer.periodic(3s)
  ├─ Detect rendering stalls (no frames for 3s+)
  ├─ Emit 'rendering_stalled' event
  └─ On 60s+ stall: force re-hydration (iOS WebView recovery)
```

**Outcome:** Performance monitoring active.

---

## 2. Eager vs Lazy Initialization

### Eagerly Initialized (Before First Frame)

| Component | When | Why |
|-----------|------|-----|
| `SupabaseBootstrap` | `main()` | Env var validation, client setup |
| `AuthService` | `main()` | Session restore needs it immediately |
| `ProviderContainer` | `main()` | Root of Riverpod graph |
| `gameCoordinatorProvider` | `EarthNovaApp.build()` | Hydration must start immediately on auth |
| `GameEngine` | `gameCoordinatorProvider` | Wraps coordinator, wires callbacks |
| `ObservabilityBuffer` | `gameCoordinatorProvider` | Singleton for telemetry |
| `LogFlushService` | `gameCoordinatorProvider` | Debounced log shipping |
| `LocationService` | `gameCoordinatorProvider` | GPS/simulation stream |
| `DiscoveryService` | `gameCoordinatorProvider` | Species encounter logic |
| `FogStateResolver` | `gameCoordinatorProvider` | Fog computation |
| `CellService` | `gameCoordinatorProvider` | Voronoi cell queries |

### Lazily Initialized (On Demand)

| Component | Trigger | Why |
|-----------|---------|-----|
| `TabShell` | First authenticated frame | Not needed until auth complete |
| `MapScreen` | Tab 0 selected | Expensive MapLibre initialization |
| `SanctuaryScreen` | Tab 1 selected | Built on demand, disposed when hidden |
| `PackScreen` | Tab 3 selected | Built on demand, disposed when hidden |
| `OnboardingScreen` | First-run after auth | Only shown once |
| `SpeciesCache` | First discovery/pack access | Lazy warmUp on demand |
| `CountryResolver` | First cell property resolution | FutureProvider, loaded async |
| `HabitatService` | First cell property resolution | Async biome data loading |

---

## 3. Provider Dependency Graph

```
┌─────────────────────────────────────────────────────────────────┐
│                      gameCoordinatorProvider                     │
│                    (Central Orchestrator)                        │
└─────────────────────────────────────────────────────────────────┘
                              ↓
        ┌─────────────────────┼─────────────────────┐
        ↓                     ↓                     ↓
   fogResolverProvider   cellServiceProvider   locationServiceProvider
        ↓                     ↓                     ↓
   fogProvider          cellProgressRepo      locationProvider
        ↓                     ↓                     ↓
   (fog state)          (cell visits)         (GPS position)
        
        ↓                     ↓                     ↓
   discoveryServiceProvider  itemInstanceRepo  playerProvider
        ↓                     ↓                     ↓
   discoveryProvider    itemsProvider         (streaks, distance)
        ↓                     ↓
   (discovery events)   (inventory)
        
        ↓
   dailySeedServiceProvider
        ↓
   (daily seed)
        
        ↓
   queueProcessorProvider
        ↓
   (write queue)
        
        ↓
   authProvider
        ↓
   (auth state)
```

**Key Dependency Rules:**
- `gameCoordinatorProvider` watches all infrastructure providers
- Infrastructure providers (`fogResolverProvider`, `cellServiceProvider`) are `Provider<T>` (not Notifier)
- Notifier providers (`playerProvider`, `itemsProvider`, `discoveryProvider`) are watched by `gameCoordinatorProvider`
- `authProvider` is listened to (not watched) to avoid rebuilding the entire provider on auth changes

---

## 4. Hydration Sequence (Detailed)

### 4a. SQLite Hydration (Phase 1, ~200-500ms)

```
rehydrateData(userId)
  ↓
Parallel queries:
  ├─ itemRepo.getItemsByUser(userId)
  ├─ cellProgressRepo.readByUser(userId)
  ├─ profileRepo.read(userId)
  └─ cellPropertyRepo.getAll()
  ↓
Load cell properties into memory:
  └─ coordinator.loadCellProperties(propsMap)
  ↓
Re-resolve plains-only cells:
  ├─ coordinator.reResolvePlainsOnlyCells()
  └─ Persist corrected properties
  ↓
Hydrate inventory:
  ├─ itemsProvider.notifier.loadItems(items)
  └─ Mark all items as collected in discoveryService
  ↓
Hydrate cell progress:
  ├─ Extract visitedCellIds (fog state = present or explored)
  └─ fogResolver.loadVisitedCells(visitedCellIds)
  ↓
Hydrate player profile:
  ├─ Derive cellsObserved from visited cell count
  ├─ Merge onboarding flag (monotonic: once true, never reset)
  └─ playerProvider.notifier.loadProfile(...)
  ↓
Mark hydrated:
  └─ playerProvider.notifier.markHydrated()
  ↓
Hydrate step counter:
  └─ stepProvider.notifier.hydrate(...)
  ↓
Capture lastPersistedProfile:
  └─ Guard for write-through listener (suppress redundant persists)
```

**Critical Ordering:**
1. `loadItems()` MUST complete before `startLoop()` (replaces inventory)
2. `markHydrated()` MUST come after all data loads (gates loading screen)
3. `lastPersistedProfile` capture MUST come after all mutations (guards listener)

### 4b. Supabase Hydration (Phase 2, Background, ~500-2000ms)

```
hydrateFromSupabase(userId)
  ↓
Fetch from Supabase in parallel:
  ├─ persistence.fetchProfile(userId)
  ├─ persistence.fetchCellProgress(userId)
  └─ persistence.fetchItemInstances(userId)
  ↓
Fetch cell properties for visited cells:
  └─ persistence.fetchCellProperties(visitedCellIds)
  ↓
Upsert to SQLite (with yields every 50 rows):
  ├─ Profile → profileRepo.create()
  ├─ Cell progress → cellProgressRepo.create() [upsert]
  ├─ Items → itemRepo.upsertItem() [upsert]
  └─ Cell properties → cellPropertyRepo.upsert() [upsert]
  ↓
Delta-sync species enrichment:
  ├─ persistence.fetchSpeciesUpdates(since: DateTime(2020))
  ├─ db.updateSpeciesEnrichment() for each row
  └─ speciesCache.refresh() [re-queries all cached combos]
  ↓
Upsert hierarchy tables:
  ├─ Countries, States, Cities, Districts
  └─ Yields every 50 rows
  ↓
Reload cell properties from SQLite:
  └─ coordinator.loadCellProperties(freshProps)
  ↓
Recompute detection zone:
  └─ detectionZoneService.recomputeCurrentZone()
  ↓
On cold start (empty SQLite):
  ├─ Re-hydrate providers from Supabase-populated SQLite
  └─ Invalidate fogOverlayControllerProvider (force rebuild)
  ↓
Backfill intrinsic affixes:
  ├─ Build stats map from species cache
  └─ backfillAllMissingAffixes() [fire-and-forget]
  ↓
Refresh fun facts cache:
  └─ Fetch up to 50 facts, cache in SharedPreferences
```

**Non-Blocking:** Supabase hydration runs in background. Game loop already started.

### 4c: Hydration Error Recovery

```
If SQLite hydration fails:
  ├─ Check if error looks like database corruption
  ├─ If web + corruption: wipe all browser databases, reload page
  └─ Else: mark hydrated anyway, start loop with empty state
  ↓
If Supabase hydration fails:
  ├─ Log error, emit 'network_error' event
  └─ Continue with SQLite-only data (graceful degradation)
```

---

## 5. Race Conditions & Ordering Dependencies

### 5a: Critical Races

| Race | Symptom | Prevention |
|------|---------|-----------|
| Discovery during hydration | Item lost when `loadItems()` replaces inventory | `loadItems()` only called if items.isNotEmpty; game loop starts after hydration |
| Auth change during hydration | Hydrate for wrong user | `lastHydratedUserId` guard: skip if already hydrated for this user |
| Provider disposed during async | Null ref, crash | `_providerDisposed` flag checked before every `ref.read()` |
| Biome data loads after zone resolves | Cells have {plains} fallback | `ref.listen(cellPropertyResolverProvider)` re-resolves when biome loads |
| Cold start Supabase sync | Providers empty, fog black | Re-hydrate providers from SQLite after Supabase sync completes |

### 5b: Ordering Dependencies

| Dependency | Why | Enforced By |
|------------|-----|------------|
| `loadItems()` before `startLoop()` | Replaces inventory state | Sequential `.then()` chain |
| `markHydrated()` after all data loads | Gates loading screen | Explicit call at end of `rehydrateData()` |
| `lastPersistedProfile` capture after mutations | Guards write-through listener | Explicit assignment after `addSteps()` |
| `coordinator.start()` after `coordinator.subscribe()` | Keyboard mode emits sync | Explicit ordering in `startLoop()` |
| `locationService.start()` after `coordinator.start()` | Coordinator must be ready | Explicit ordering in `startLoop()` |
| Biome data load before zone resolution | Cells need real habitats | `cellPropertyResolverProvider` is FutureProvider, loaded early |
| Species cache warmUp before discoveries | Cache miss = 0 species | Warmup happens before `startLoop()` |

---

## 6. Loading Screen Gates

Three independent gates must all be true to dismiss the loading screen:

```
allReady = playerState.isHydrated 
        && isZoneReady 
        && isPlayerLocated 
        && gpsPermissionState != unknown
```

| Gate | Set By | Typical Time | Fallback |
|------|--------|--------------|----------|
| `isHydrated` | `playerProvider.notifier.markHydrated()` | ~500ms | 15s timeout |
| `isZoneReady` | `zoneReadyProvider.notifier.markReady()` | ~3-8s | 15s timeout |
| `isPlayerLocated` | `playerLocatedProvider.notifier.markLocated()` | ~5-10s | 15s timeout |
| `gpsPermissionState` | `gpsPermissionProvider` | ~1-2s | N/A (must settle) |

**Timeout Fallback:** If any gate not set after 15s, `_EarthNovaAppState.initState()` forces them true.

---

## 7. Error Boundaries & Fallback Behavior

### 7a: Global Error Handlers

```
FlutterError.onError
  ├─ Logs to DebugLogBuffer
  ├─ Captures stack trace
  └─ Renders _GlobalErrorFallback (dark screen + error summary)
  
Zone error handler (runZonedGuarded)
  ├─ Catches unhandled async exceptions
  ├─ Logs to DebugLogBuffer
  └─ Emits 'crash' event to ObservabilityBuffer
```

### 7b: Widget-Level Error Boundary

```
TabShell wraps all tab content in single ErrorBoundary
  ├─ Catches Flutter framework errors
  ├─ Renders DefaultErrorFallback (retry button)
  └─ Avoids cascade bug (global FlutterError.onError)
```

**Why single boundary?** `FlutterError.onError` is global. Multiple boundaries catch the same error simultaneously, blanking all tabs. One boundary protects the bottom nav bar while still catching errors.

### 7c: Graceful Degradation

| Failure | Behavior |
|---------|----------|
| Supabase not configured | Use MockAuthService, offline-only mode |
| Session restore fails | Show LoginScreen, user can sign in |
| SQLite hydration fails | Start loop with empty state, show map |
| Supabase hydration fails | Continue with SQLite-only data |
| Database corruption (web) | Wipe databases, reload page |
| Zone resolution timeout (15s) | Dismiss loading screen, show map anyway |
| GPS permission denied | Show map, no location tracking |
| Biome data load fails | Use {plains} fallback, re-resolve later |

---

## 8. Navigation Structure

### 8a: Root Navigation (Auth-Driven)

```
EarthNovaApp._resolveHome(authState)
  ├─ loading → LoadingScreen
  ├─ otpSent / otpVerifying → OtpVerificationScreen
  ├─ unauthenticated → LoginScreen
  └─ authenticated:
      ├─ !hasCompletedOnboarding → OnboardingScreen
      └─ hasCompletedOnboarding → _SteadyStateShell
```

**Transition:** `AnimatedSwitcher` with 300ms cross-fade.

### 8b: Steady-State Navigation (Tab-Based)

```
_SteadyStateShell
  ├─ Stack:
  │   ├─ TabShell (4-tab bottom bar)
  │   │   ├─ Tab 0: MapScreen (always mounted via Offstage)
  │   │   ├─ Tab 1: SanctuaryScreen (built on demand)
  │   │   ├─ Tab 2: TownPlaceholderScreen (built on demand)
  │   │   └─ Tab 3: PackScreen (built on demand)
  │   └─ LoadingScreen overlay (AnimatedOpacity, fades out when ready)
```

**Tab State:** Persisted in `tabIndexProvider` (SharedPreferences).

### 8c: Pushed Routes

```
From TabShell:
  ├─ Settings screen (pushed from Map tab)
  └─ Achievements screen (pushed from Map tab)
  
On sign-out:
  └─ Navigator.popUntil((route) => route.isFirst)
     (Clears all pushed routes, shows LoginScreen)
```

---

## 9. Startup Beacons (Observability Checkpoints)

Emitted at key milestones for debugging:

```
supabase_init
  ↓
session_restore
  ↓
session_restore_done
  ↓
provider_init (gameCoordinatorProvider)
  ↓
hydration_start
  ↓
hydration_complete
  ↓
run_app
  ↓
resolve_home → {LoadingScreen, OtpVerificationScreen, LoginScreen, SteadyStateShell}
  ↓
loading_dismissed
```

Each beacon can be queried via `StartupBeacon.emit()` and `StartupBeacon.promote()`.

---

## 10. Performance Characteristics

### 10a: Typical Startup Timeline

| Phase | Duration | Bottleneck |
|-------|----------|-----------|
| Pre-Flutter | ~50ms | Image cache config |
| Auth service creation | ~50ms | Supabase init |
| Session restore | ~100-500ms | Network (Supabase) |
| Error handlers | ~100ms | Setup |
| Zone setup | ~100ms | runZonedGuarded |
| Widget tree build | ~300ms | EarthNovaApp.build() |
| Game coordinator init | ~500ms | Infrastructure setup |
| SQLite hydration | ~200-500ms | Database queries |
| **Loading screen visible** | ~1000-2000ms | Waiting for zone + GPS |
| Zone resolution | ~3-8s | Nominatim API (location enrichment) |
| Rubber-band convergence | ~5-10s | GPS accuracy |
| **Map interactive** | ~3000-5000ms | All gates settled |
| Supabase hydration (bg) | ~500-2000ms | Network |
| **Total to interactive** | ~3-5s | Zone + GPS |

### 10b: Memory Footprint

| Component | Typical Size |
|-----------|--------------|
| Image cache | 50-200MB (platform-dependent) |
| SQLite database | 5-50MB (depends on inventory size) |
| Species cache | 2-5MB (habitat/continent combos) |
| Fog state (in-memory) | 1-10MB (visited cells) |
| Riverpod provider graph | 5-20MB (all state) |

---

## 11. Key Invariants & Guarantees

### 11a: Invariants

1. **Auth state is always settled** — Never `loading` after first frame
2. **Hydration is idempotent** — Can be called multiple times safely
3. **Game loop never starts before hydration** — Prevents race with discoveries
4. **Fog state is computed, never stored** — Only `visitedCellIds` persisted
5. **Species encounters are deterministic** — Same seed + cell = same species
6. **Write queue is durable** — Entries survive app restart
7. **Supabase is source of truth** — SQLite is cache + offline queue

### 11b: Guarantees

1. **User data is never lost** — Write queue persists until server confirms
2. **Discoveries are server-validated** — Offline rolls are re-derived on reconnect
3. **Onboarding is shown exactly once** — Flag persisted, never reset except on sign-out
4. **Loading screen dismisses within 15s** — Timeout fallback prevents infinite loading
5. **Map is always responsive** — Gestures work immediately after loading screen fades

---

## 12. Debugging Checklist

When startup hangs or crashes:

- [ ] Check `StartupBeacon` logs — which phase failed?
- [ ] Check `DebugLogBuffer` — any errors before the hang?
- [ ] Check `app_logs` table (Supabase) — observability events?
- [ ] Check `app_events` table (Supabase) — structured events?
- [ ] Is Supabase configured? (`SUPABASE_URL` + `SUPABASE_ANON_KEY`)
- [ ] Is session restore hanging? (Check network tab)
- [ ] Is SQLite hydration hanging? (Check database size)
- [ ] Is zone resolution hanging? (Check Nominatim API)
- [ ] Is GPS permission dialog blocking? (Check device settings)
- [ ] Is the 15s timeout being hit? (Check logs for "zone_ready_timeout")
- [ ] Is there a database corruption error? (Check for FormatException)

---

## 13. Summary

The EarthNova bootstrap is a **three-phase orchestration**:

1. **Pre-Flutter (0-700ms):** Supabase init, auth service creation, error handlers, zone setup
2. **Widget Tree (700-1000ms):** EarthNovaApp mounts, gameCoordinatorProvider eagerly initialized
3. **Hydration & Game Loop (1000-3000ms):** SQLite hydration, game loop starts, loading screen gates settle

**Key Design Principles:**
- **Eager initialization of game systems** — GameCoordinator starts immediately on auth
- **Lazy initialization of UI** — Tabs, screens, and expensive widgets built on demand
- **Non-blocking background sync** — Supabase hydration runs in background, doesn't block gameplay
- **Graceful degradation** — App works offline, with SQLite cache, with mock auth
- **Observable startup** — Beacons, events, and logs at every milestone

**Critical Path to Interactive:**
```
Auth settles → Hydration starts → SQLite loads → Game loop runs → Zone resolves → GPS converges → Loading screen dismisses
```

**Typical time: 3-5 seconds** (network-dependent).

