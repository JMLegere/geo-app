# Bootstrap & Initialization — Quick Reference

## TL;DR

**Three phases, ~3-5 seconds to interactive:**

1. **Pre-Flutter (0-700ms):** Supabase init, auth service, error handlers, zone setup
2. **Widget Tree (700-1000ms):** EarthNovaApp mounts, gameCoordinatorProvider eagerly initialized
3. **Hydration & Game Loop (1000-3000ms):** SQLite loads, game loop runs, loading screen gates settle

**Critical path:** Auth settles → Hydration → Game loop → Zone resolves → GPS converges → Map visible

---

## Key Files

| File | Lines | Purpose |
|------|-------|---------|
| `lib/main.dart` | 554 | Entry point, error handlers, zone setup, routing |
| `lib/core/state/game_coordinator_provider.dart` | 1384 | Central orchestrator, hydration, callbacks |
| `lib/core/state/player_provider.dart` | 172 | Player state, hydration flag |
| `lib/features/auth/providers/auth_provider.dart` | 136 | Auth state, action wrappers |
| `lib/shared/widgets/tab_shell.dart` | 338 | 4-tab navigation, map always mounted |

---

## Initialization Checklist

### Phase 0: Pre-Flutter
- [ ] `WidgetsFlutterBinding.ensureInitialized()`
- [ ] Image cache configured (platform-aware)
- [ ] `SupabaseBootstrap.initialize()` (validates env vars)
- [ ] `AuthService` created (Supabase or Mock)
- [ ] `ProviderContainer` created with overrides
- [ ] `authServiceProvider` injected
- [ ] `authService.restoreSession()` called
- [ ] `authProvider.setState()` called with result
- [ ] Auth stream bridged to provider
- [ ] Global error handlers registered
- [ ] Zone setup with `runZonedGuarded()`

### Phase 1: Widget Tree
- [ ] `EarthNovaApp.build()` called
- [ ] `gameCoordinatorProvider` eagerly read (triggers Phase 2)
- [ ] `authProvider` watched for routing
- [ ] Root route determined by `_resolveHome()`

### Phase 2: Game Coordinator
- [ ] `GameEngine` created
- [ ] All callbacks wired (location, GPS error, cell visit, discovery, cell properties)
- [ ] All listeners registered (detection zone, location enrichment, queue processor)
- [ ] `ObservabilityBuffer` singleton created
- [ ] `LogFlushService` created (if Supabase configured)
- [ ] Startup diagnostics emitted

### Phase 3: Hydration
- [ ] `handleAuthState()` called with current auth state
- [ ] If authenticated: `hydrateAndStart(userId)` called
- [ ] `rehydrateData()` reads SQLite in parallel
- [ ] Inventory loaded: `itemsProvider.notifier.loadItems()`
- [ ] Cell progress loaded: `fogResolver.loadVisitedCells()`
- [ ] Player profile loaded: `playerProvider.notifier.loadProfile()`
- [ ] Hydration marked: `playerProvider.notifier.markHydrated()` ✓ Gate 1
- [ ] Species cache warmed
- [ ] Enrichment backfill queued
- [ ] `startLoop()` called
- [ ] Daily seed fetched
- [ ] Coordinator subscribed to GPS stream
- [ ] Location service started

### Phase 4: Loading Screen Gates
- [ ] Gate 1: `playerState.isHydrated` ✓
- [ ] Gate 2: `zoneReadyProvider` (set when zone resolves)
- [ ] Gate 3: `playerLocatedProvider` (set when rubber-band converges)
- [ ] Gate 4: `gpsPermissionState != unknown`
- [ ] When all 4 true: Loading screen fades out (400ms)
- [ ] Map becomes interactive

### Phase 5: Background Sync
- [ ] `hydrateFromSupabase()` runs in background
- [ ] Supabase data upserted to SQLite
- [ ] Species enrichment delta-synced
- [ ] Hierarchy tables synced
- [ ] Species cache refreshed
- [ ] On cold start: providers re-hydrated from SQLite
- [ ] Intrinsic affixes backfilled
- [ ] Fun facts cache refreshed

---

## Loading Screen Gates

```
allReady = playerState.isHydrated 
        && zoneReadyProvider 
        && playerLocatedProvider 
        && gpsPermissionState != unknown
```

| Gate | Set By | Typical Time | Fallback |
|------|--------|--------------|----------|
| `isHydrated` | `playerProvider.notifier.markHydrated()` | ~500ms | 15s timeout |
| `zoneReady` | `zoneReadyProvider.notifier.markReady()` | ~3-8s | 15s timeout |
| `playerLocated` | `playerLocatedProvider.notifier.markLocated()` | ~5-10s | 15s timeout |
| `gpsPermission` | `gpsPermissionProvider` | ~1-2s | N/A (must settle) |

**Timeout:** If any gate not set after 15s, `_EarthNovaAppState.initState()` forces them true.

---

## Eager vs Lazy Initialization

### Eager (Before First Frame)
- `SupabaseBootstrap`
- `AuthService`
- `ProviderContainer`
- `gameCoordinatorProvider` ← Triggers everything
- `GameEngine`
- `ObservabilityBuffer`
- `LogFlushService`
- `LocationService`
- `DiscoveryService`
- `FogStateResolver`
- `CellService`

### Lazy (On Demand)
- `TabShell` (after auth)
- `MapScreen` (tab 0)
- `SanctuaryScreen` (tab 1)
- `PackScreen` (tab 3)
- `OnboardingScreen` (first-run)
- `SpeciesCache` (first discovery)
- `CountryResolver` (FutureProvider)
- `HabitatService` (async biome load)

---

## Critical Races & Prevention

| Race | Symptom | Prevention |
|------|---------|-----------|
| Discovery during hydration | Item lost | `loadItems()` only if non-empty; game loop starts after |
| Auth change during hydration | Wrong user | `lastHydratedUserId` guard |
| Provider disposed during async | Null ref crash | `_providerDisposed` flag checked before every `ref.read()` |
| Biome data loads after zone | Cells have {plains} | `ref.listen(cellPropertyResolverProvider)` re-resolves |
| Cold start Supabase sync | Fog black | Re-hydrate providers after Supabase sync |

---

## Hydration Order (CRITICAL)

```
1. Load from SQLite (parallel queries)
2. Load cell properties into memory
3. Re-resolve plains-only cells
4. Hydrate inventory: itemsProvider.notifier.loadItems()
5. Hydrate cell progress: fogResolver.loadVisitedCells()
6. Hydrate player profile: playerProvider.notifier.loadProfile()
7. Mark hydrated: playerProvider.notifier.markHydrated() ✓
8. Hydrate step counter: stepProvider.notifier.hydrate()
9. Capture lastPersistedProfile (guard for listener)
10. Warm species cache
11. Queue enrichment backfill
12. startLoop()
13. hydrateFromSupabase() [background]
```

**Why this order?**
- `loadItems()` replaces inventory, must complete before game loop
- `markHydrated()` gates loading screen, must come after all data loads
- `lastPersistedProfile` capture guards write-through listener, must come after all mutations

---

## Error Recovery

| Failure | Behavior |
|---------|----------|
| Supabase not configured | Use MockAuthService, offline-only |
| Session restore fails | Show LoginScreen |
| SQLite hydration fails | Start loop with empty state |
| Supabase hydration fails | Continue with SQLite-only data |
| Database corruption (web) | Wipe databases, reload page |
| Zone resolution timeout (15s) | Dismiss loading screen anyway |
| GPS permission denied | Show map, no tracking |
| Biome data load fails | Use {plains} fallback, re-resolve later |

---

## Startup Beacons (Observability)

Emitted at key milestones:

```
supabase_init
  ↓
session_restore
  ↓
session_restore_done
  ↓
provider_init
  ↓
hydration_start
  ↓
hydration_complete
  ↓
run_app
  ↓
resolve_home
  ↓
loading_dismissed
```

Query via `StartupBeacon.emit()` and `StartupBeacon.promote()`.

---

## Performance Targets

| Phase | Duration | Bottleneck |
|-------|----------|-----------|
| Pre-Flutter | ~50ms | Image cache config |
| Auth service | ~50ms | Supabase init |
| Session restore | ~100-500ms | Network |
| Widget tree | ~300ms | Build |
| Game coordinator | ~500ms | Infrastructure |
| SQLite hydration | ~200-500ms | Database |
| **Loading screen visible** | ~1000-2000ms | Waiting for gates |
| Zone resolution | ~3-8s | Nominatim API |
| Rubber-band convergence | ~5-10s | GPS accuracy |
| **Map interactive** | ~3000-5000ms | All gates settled |
| Supabase hydration (bg) | ~500-2000ms | Network |

---

## Debugging Checklist

When startup hangs or crashes:

- [ ] Check `StartupBeacon` logs — which phase failed?
- [ ] Check `DebugLogBuffer` — any errors?
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

## Key Invariants

1. **Auth state is always settled** — Never `loading` after first frame
2. **Hydration is idempotent** — Can be called multiple times safely
3. **Game loop never starts before hydration** — Prevents race with discoveries
4. **Fog state is computed, never stored** — Only `visitedCellIds` persisted
5. **Species encounters are deterministic** — Same seed + cell = same species
6. **Write queue is durable** — Entries survive app restart
7. **Supabase is source of truth** — SQLite is cache + offline queue

---

## Key Guarantees

1. **User data is never lost** — Write queue persists until server confirms
2. **Discoveries are server-validated** — Offline rolls are re-derived on reconnect
3. **Onboarding is shown exactly once** — Flag persisted, never reset except on sign-out
4. **Loading screen dismisses within 15s** — Timeout fallback prevents infinite loading
5. **Map is always responsive** — Gestures work immediately after loading screen fades

---

## Callback Wiring Summary

All callbacks are wired in `gameCoordinatorProvider.build()`:

```
coordinator.onPlayerLocationUpdate
  → locationProvider.updateLocation()
  → detectionZoneService.updatePlayerPosition()

coordinator.onGpsErrorChanged
  → locationProvider.setError()

coordinator.onCellVisited
  → playerProvider.incrementCellsObserved()
  → persistCellVisit()
  → locationEnrichmentSvc.requestEnrichment()

coordinator.onItemDiscovered
  → discoveryProvider.showDiscovery()
  → itemsProvider.addItem()
  → persistItemDiscovery()

coordinator.onCellPropertiesResolved
  → persistCellProperties()

detectionZoneService.onDetectionZoneChanged
  → fogResolver.setDetectionZone()
  → Resolve cell properties
  → Warm species cache
  → zoneReadyProvider.markReady()
  → persistCellProperties() [batched]

locationEnrichmentSvc.onLocationEnriched
  → coordinator.updateCellPropertyLocationId()

queueProcessor.onAutoFlushComplete
  → processRejections()
  → applyFirstBadges()
  → refreshPendingCount()

playerProvider state changes
  → persistProfileState() [debounced 5s]

cellPropertyResolverProvider transition (null → non-null)
  → coordinator.setCellPropertyResolver()
  → Re-resolve plains-only cells
  → Warm species cache
```

---

## Navigation Structure

```
EarthNovaApp._resolveHome(authState)
  ├─ loading → LoadingScreen
  ├─ otpSent / otpVerifying → OtpVerificationScreen
  ├─ unauthenticated → LoginScreen
  └─ authenticated:
      ├─ !hasCompletedOnboarding → OnboardingScreen
      └─ hasCompletedOnboarding → _SteadyStateShell
          ├─ TabShell (4-tab bottom bar)
          │   ├─ Tab 0: MapScreen (always mounted via Offstage)
          │   ├─ Tab 1: SanctuaryScreen (built on demand)
          │   ├─ Tab 2: TownPlaceholderScreen (built on demand)
          │   └─ Tab 3: PackScreen (built on demand)
          └─ LoadingScreen overlay (AnimatedOpacity, fades out when ready)
```

---

## One-Liner Summary

**EarthNova bootstrap is a three-phase orchestration: pre-Flutter setup → eager game coordinator initialization → non-blocking SQLite hydration + background Supabase sync, with four independent loading screen gates (hydrated, zone ready, player located, GPS permission) that dismiss the overlay when all settle.**

