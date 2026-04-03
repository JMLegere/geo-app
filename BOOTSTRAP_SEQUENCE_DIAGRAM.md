# Bootstrap Sequence Diagram

## Timeline: main() → Interactive Map

```
TIME    PHASE                   COMPONENT                    STATE
────────────────────────────────────────────────────────────────────────────
0ms     Pre-Flutter             WidgetsFlutterBinding        Initializing
        ↓                       Image cache config
        ↓                       SupabaseBootstrap.init()
        ↓                       AuthService creation
        ↓                       ProviderContainer creation
        ↓                       Error handlers setup
        ↓                       Zone setup
        ↓                       runZonedGuarded()
        ↓
~700ms  Widget Tree             EarthNovaApp.build()         Building
        ↓                       ref.read(gameCoordinatorProvider) ← EAGER
        ↓
~1000ms Game Coordinator        GameEngine creation          Initializing
        ↓                       Callback wiring
        ↓                       Observability setup
        ↓                       Listener registration
        ↓
~1600ms Hydration Start         rehydrateData(userId)        Loading from SQLite
        ├─ itemRepo.getItemsByUser()
        ├─ cellProgressRepo.readByUser()
        ├─ profileRepo.read()
        └─ cellPropertyRepo.getAll()
        ↓
~2000ms Hydration Complete      playerProvider.markHydrated() ✓ Gate 1 open
        ↓                       startLoop()
        ↓                       coordinator.start(gpsStream)
        ↓                       locationService.start()
        ↓
~2100ms Game Loop Running       ~10Hz tick rate              Discovering cells
        ↓                       Detection zone service       Resolving zone
        ↓                       Location enrichment          Querying Nominatim
        ↓
~3000ms Zone Resolution         zoneReadyProvider.markReady() ✓ Gate 2 open
        ↓                       fogResolver.setDetectionZone()
        ↓                       Fog overlay updated
        ↓
~3500ms GPS Convergence         playerLocatedProvider.markLocated() ✓ Gate 3 open
        ↓                       Rubber-band within threshold
        ↓
~3500ms Loading Dismissed       AnimatedOpacity(opacity: 0.0) ✓ Map visible
        ↓                       IgnorePointer(ignoring: true)
        ↓
~3500ms INTERACTIVE             User can tap, pan, zoom      ✓ Ready
        ↓
~4000ms Background Sync         hydrateFromSupabase()        Running (non-blocking)
        ├─ Fetch profile, cells, items
        ├─ Upsert to SQLite
        ├─ Delta-sync species
        └─ Refresh caches
        ↓
~5000ms Background Complete     Supabase hydration done      ✓ Data synced
```

---

## Parallel Initialization Streams

```
STREAM 1: Auth & Session
─────────────────────────────────────────────────────────────
main()
  ↓
SupabaseBootstrap.initialize()
  ↓
AuthService creation (Supabase or Mock)
  ↓
authService.restoreSession()
  ↓
authProvider.setState(authenticated or unauthenticated)
  ↓
[GATE: Auth settled]


STREAM 2: Game Coordinator
─────────────────────────────────────────────────────────────
EarthNovaApp.build()
  ↓
ref.read(gameCoordinatorProvider) ← Waits for auth
  ↓
GameEngine creation
  ↓
Callback wiring
  ↓
handleAuthState(authProvider) ← Triggered by auth
  ↓
hydrateAndStart(userId)
  ├─ rehydrateData() [SQLite]
  ├─ startLoop()
  └─ hydrateFromSupabase() [Background]
  ↓
[GATE: Hydrated]


STREAM 3: Detection Zone
─────────────────────────────────────────────────────────────
locationService.start()
  ↓
GPS stream emits position
  ↓
coordinator.updatePlayerPosition()
  ↓
detectionZoneService.updatePlayerPosition()
  ↓
Zone computation (Voronoi + Nominatim)
  ↓
onDetectionZoneChanged.listen()
  ├─ Resolve cell properties
  ├─ Warm species cache
  └─ zoneReadyProvider.markReady()
  ↓
[GATE: Zone ready]


STREAM 4: Rubber-Band Convergence
─────────────────────────────────────────────────────────────
MapScreen.build()
  ↓
RubberBandMarker animation
  ├─ Target: raw GPS position
  └─ Interpolate at 60fps
  ↓
When distance < threshold:
  └─ playerLocatedProvider.markLocated()
  ↓
[GATE: Player located]


STREAM 5: GPS Permission
─────────────────────────────────────────────────────────────
gpsPermissionProvider.build()
  ↓
locationService.checkPermission()
  ↓
gpsPermissionState = granted | denied | deniedForever | serviceDisabled
  ↓
[GATE: Permission settled]
```

---

## Loading Screen Gate Logic

```
                    ┌─────────────────────────────────────┐
                    │   _SteadyStateShell.build()         │
                    └─────────────────────────────────────┘
                                    ↓
                    ┌─────────────────────────────────────┐
                    │  Watch 4 gates:                     │
                    │  1. playerState.isHydrated          │
                    │  2. zoneReadyProvider               │
                    │  3. playerLocatedProvider           │
                    │  4. gpsPermissionState != unknown   │
                    └─────────────────────────────────────┘
                                    ↓
                    ┌─────────────────────────────────────┐
                    │  allReady = all 4 gates true?       │
                    └─────────────────────────────────────┘
                                    ↓
                    ┌───────────────┴───────────────┐
                    ↓                               ↓
            allReady = false                  allReady = true
                    ↓                               ↓
        ┌───────────────────────┐      ┌───────────────────────┐
        │ LoadingScreen visible │      │ LoadingScreen hidden  │
        │ opacity: 1.0          │      │ opacity: 0.0 (400ms)  │
        │ IgnorePointer: false  │      │ IgnorePointer: true   │
        │ Map gestures blocked  │      │ Map gestures active   │
        └───────────────────────┘      └───────────────────────┘
                    ↓                               ↓
            [Waiting for gates]            [INTERACTIVE]
                    ↓
        ┌───────────────────────┐
        │ 15s timeout fallback  │
        │ Force all gates true  │
        │ (prevents infinite    │
        │  loading)             │
        └───────────────────────┘
```

---

## Hydration Sequence (Detailed)

```
hydrateAndStart(userId)
│
├─ Phase 1: SQLite Hydration (Fast, ~200-500ms)
│  │
│  ├─ rehydrateData(userId)
│  │  │
│  │  ├─ Parallel queries:
│  │  │  ├─ itemRepo.getItemsByUser(userId)
│  │  │  ├─ cellProgressRepo.readByUser(userId)
│  │  │  ├─ profileRepo.read(userId)
│  │  │  └─ cellPropertyRepo.getAll()
│  │  │
│  │  ├─ Load cell properties into memory
│  │  │  └─ coordinator.loadCellProperties(propsMap)
│  │  │
│  │  ├─ Re-resolve plains-only cells
│  │  │  └─ coordinator.reResolvePlainsOnlyCells()
│  │  │
│  │  ├─ Hydrate inventory
│  │  │  └─ itemsProvider.notifier.loadItems(items)
│  │  │
│  │  ├─ Hydrate cell progress
│  │  │  └─ fogResolver.loadVisitedCells(visitedCellIds)
│  │  │
│  │  ├─ Hydrate player profile
│  │  │  └─ playerProvider.notifier.loadProfile(...)
│  │  │
│  │  ├─ Mark hydrated ✓
│  │  │  └─ playerProvider.notifier.markHydrated()
│  │  │
│  │  ├─ Hydrate step counter
│  │  │  └─ stepProvider.notifier.hydrate(...)
│  │  │
│  │  └─ Capture lastPersistedProfile
│  │     └─ Guard for write-through listener
│  │
│  ├─ Warm species cache
│  │  ├─ For all (habitat, continent) combos in cell properties
│  │  └─ For all owned species IDs
│  │
│  ├─ Startup enrichment backfill
│  │  ├─ Priority: current cell + neighbors
│  │  └─ Remaining: all cells without locationId (capped at 50)
│  │
│  └─ startLoop()
│     ├─ Fetch daily seed
│     ├─ Subscribe coordinator to GPS stream
│     └─ Start location service
│
├─ Phase 2: Supabase Hydration (Background, ~500-2000ms)
│  │
│  └─ hydrateFromSupabase(userId)
│     │
│     ├─ Fetch from Supabase in parallel
│     │  ├─ Profile
│     │  ├─ Cell progress
│     │  ├─ Items
│     │  └─ Cell properties
│     │
│     ├─ Upsert to SQLite (with yields every 50 rows)
│     │  ├─ Profile
│     │  ├─ Cell progress
│     │  ├─ Items
│     │  └─ Cell properties
│     │
│     ├─ Delta-sync species enrichment
│     │  ├─ Fetch updates from species table
│     │  ├─ Update LocalSpeciesTable
│     │  └─ Refresh species cache
│     │
│     ├─ Upsert hierarchy tables
│     │  ├─ Countries
│     │  ├─ States
│     │  ├─ Cities
│     │  └─ Districts
│     │
│     ├─ Reload cell properties from SQLite
│     │  └─ coordinator.loadCellProperties(freshProps)
│     │
│     ├─ Recompute detection zone
│     │  └─ detectionZoneService.recomputeCurrentZone()
│     │
│     ├─ On cold start: re-hydrate providers
│     │  ├─ rehydrateData(userId) [again]
│     │  └─ Invalidate fogOverlayControllerProvider
│     │
│     ├─ Backfill intrinsic affixes
│     │  └─ backfillAllMissingAffixes(...)
│     │
│     └─ Refresh fun facts cache
│        └─ Fetch up to 50 facts, cache in SharedPreferences
│
└─ [Game loop running, map visible, background sync in flight]
```

---

## Provider Initialization Order

```
1. ProviderContainer created
   └─ cachedFunFactsProvider overridden with loaded facts

2. authServiceProvider injected
   └─ container.read(authServiceProvider.notifier).set(authService)

3. authProvider state set
   └─ container.read(authProvider.notifier).setState(...)

4. EarthNovaApp.build() called
   └─ ref.read(gameCoordinatorProvider) ← EAGER

5. gameCoordinatorProvider.build() called
   ├─ fogResolverProvider watched
   ├─ cellServiceProvider watched
   ├─ locationServiceProvider watched
   ├─ discoveryServiceProvider watched
   ├─ itemInstanceRepositoryProvider watched
   ├─ cellProgressRepositoryProvider watched
   ├─ profileRepositoryProvider watched
   ├─ queueProcessorProvider watched
   ├─ cellPropertyRepositoryProvider watched
   ├─ cellPropertyResolverProvider read
   ├─ speciesCacheProvider read
   ├─ supabaseClientProvider read
   ├─ appDatabaseProvider read
   ├─ dailySeedServiceProvider read
   ├─ locationEnrichmentServiceProvider read
   ├─ detectionZoneServiceProvider read
   ├─ fogOverlayControllerProvider read
   ├─ itemsProvider watched
   ├─ discoveryProvider watched
   ├─ syncProvider watched
   ├─ stepProvider watched
   ├─ authProvider listened to
   ├─ playerProvider listened to
   ├─ cellPropertyResolverProvider listened to
   └─ [All callbacks wired, listeners registered]

6. handleAuthState(authProvider) called
   └─ If authenticated: hydrateAndStart(userId)

7. rehydrateData(userId) called
   ├─ itemsProvider.notifier.loadItems(items)
   ├─ fogResolver.loadVisitedCells(visitedCellIds)
   ├─ playerProvider.notifier.loadProfile(...)
   ├─ playerProvider.notifier.markHydrated()
   └─ stepProvider.notifier.hydrate(...)

8. startLoop() called
   ├─ coordinator.start(gpsStream, discoveryStream)
   └─ locationService.start()

9. hydrateFromSupabase(userId) called (background)
   ├─ Fetch from Supabase
   ├─ Upsert to SQLite
   ├─ Refresh caches
   └─ [Game loop already running]
```

---

## Error Recovery Paths

```
                    ┌──────────────────────┐
                    │  Startup Error       │
                    └──────────────────────┘
                                ↓
                    ┌──────────────────────┐
                    │  Error Type?         │
                    └──────────────────────┘
                    ↙           ↓           ↘
        ┌─────────────┐  ┌──────────────┐  ┌──────────────┐
        │ Supabase    │  │ SQLite       │  │ Database     │
        │ not config  │  │ hydration    │  │ corruption   │
        │             │  │ fails        │  │ (web only)   │
        └─────────────┘  └──────────────┘  └──────────────┘
             ↓                ↓                    ↓
        Use Mock         Mark hydrated      Wipe databases
        AuthService      anyway             Reload page
             ↓                ↓
        Offline-only      Start loop
        mode              with empty
             ↓             state
        Continue          ↓
        gameplay      Continue
                      gameplay
```

---

## Callback Wiring Diagram

```
GameCoordinator callbacks → Provider mutations

┌─────────────────────────────────────────────────────────────┐
│ coordinator.onPlayerLocationUpdate                          │
├─────────────────────────────────────────────────────────────┤
│ 1. Engine callback fires (event emission)                   │
│ 2. locationProvider.notifier.updateLocation(pos, accuracy)  │
│ 3. detectionZoneService.updatePlayerPosition(lat, lon)      │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ coordinator.onGpsErrorChanged                               │
├─────────────────────────────────────────────────────────────┤
│ 1. Engine callback fires (event emission)                   │
│ 2. locationProvider.notifier.setError(error)                │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ coordinator.onCellVisited                                   │
├─────────────────────────────────────────────────────────────┤
│ 1. Engine callback fires (event emission)                   │
│ 2. playerProvider.notifier.incrementCellsObserved()         │
│ 3. persistCellVisit() → SQLite + write queue                │
│ 4. locationEnrichmentSvc.requestEnrichment(cell + neighbors)│
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ coordinator.onItemDiscovered                                │
├─────────────────────────────────────────────────────────────┤
│ 1. Engine callback fires (event emission)                   │
│ 2. Award first-discovery badge (if offline mode)            │
│ 3. discoveryProvider.notifier.showDiscovery(event)          │
│ 4. itemsProvider.notifier.addItem(instance)                 │
│ 5. persistItemDiscovery() → SQLite + write queue            │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ coordinator.onCellPropertiesResolved                        │
├─────────────────────────────────────────────────────────────┤
│ 1. Engine callback fires (event emission)                   │
│ 2. persistCellProperties() → SQLite + write queue           │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ detectionZoneService.onDetectionZoneChanged                 │
├─────────────────────────────────────────────────────────────┤
│ Phase 1: In-memory resolution (<50ms)                       │
│ 1. fogResolver.setDetectionZone(zoneCellIds)                │
│ 2. Resolve cell properties into memory cache                │
│ 3. Stamp locationId into memory cache                       │
│ 4. Feed fog overlay with fully-populated cache              │
│ 5. Warm species cache for all (habitat, continent) combos   │
│ 6. zoneReadyProvider.notifier.markReady()                   │
│                                                              │
│ Phase 2: Deferred persistence (batched, ~75ms/batch)        │
│ 7. Persist to SQLite + enqueue for Supabase (batches of 5)  │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ playerProvider state changes                                │
├─────────────────────────────────────────────────────────────┤
│ Debounced 5s (guard: skip if lastPersistedProfile match)    │
│ 1. persistProfileState() → SQLite + write queue             │
└─────────────────────────────────────────────────────────────┘
```

---

## State Mutation Timeline

```
TIME    PROVIDER                STATE BEFORE        STATE AFTER
────────────────────────────────────────────────────────────────────────
~100ms  authProvider            loading             authenticated/unauthenticated
~1600ms itemsProvider           {}                  {items from SQLite}
~1600ms fogResolver             {}                  {visitedCellIds from SQLite}
~1600ms playerProvider          default             {profile from SQLite}
~1600ms playerProvider          isHydrated=false    isHydrated=true ✓
~2000ms locationProvider        default             {position, accuracy}
~2100ms detectionZoneService    {}                  {zone cells}
~3000ms zoneReadyProvider       false               true ✓
~3000ms fogProvider             {}                  {fog states for zone}
~3500ms playerLocatedProvider   false               true ✓
~3500ms gpsPermissionProvider   unknown             granted/denied/...
~3500ms [All gates true]        allReady=false      allReady=true ✓
~3500ms LoadingScreen           visible             hidden (fade out)
~4000ms itemsProvider           {items}             {items + Supabase data}
~4000ms fogResolver             {visited}           {visited + Supabase data}
~4000ms playerProvider          {profile}           {profile + Supabase data}
```

---

## Critical Path Analysis

```
Fastest path to interactive (ideal conditions):
─────────────────────────────────────────────

main()
  ↓ 50ms
SupabaseBootstrap.init()
  ↓ 100ms
AuthService.restoreSession() [cached session]
  ↓ 100ms
authProvider.setState(authenticated)
  ↓ 100ms
EarthNovaApp.build()
  ↓ 100ms
gameCoordinatorProvider.build()
  ↓ 200ms
rehydrateData() [SQLite, small inventory]
  ↓ 100ms
startLoop()
  ↓ 100ms
GPS position arrives [immediate]
  ↓ 100ms
detectionZoneService resolves [fast Nominatim]
  ↓ 100ms
zoneReadyProvider.markReady()
  ↓ 100ms
playerLocatedProvider.markLocated() [GPS accurate]
  ↓ 100ms
gpsPermissionState settled
  ↓ 100ms
Loading screen dismisses
  ↓
INTERACTIVE ✓

Total: ~1300ms (ideal)
Typical: ~3000-5000ms (network-dependent)
Worst case: ~15000ms (timeout fallback)
```

