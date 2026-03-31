# State Map

All Riverpod providers, their types, state shapes, and dependency wiring.

## Provider Inventory

### Core Providers (lib/core/state/)

| Provider | Type | State Shape | Dependencies |
|----------|------|-------------|-------------|
| `fogProvider` | `NotifierProvider<FogNotifier, Map<String, FogState>>` | `{cellId: FogState}` | none |
| `locationProvider` | `NotifierProvider<LocationNotifier, LocationState>` | `{currentPosition?, accuracy?, isTracking, locationError}` | none |
| `playerProvider` | `NotifierProvider<PlayerNotifier, PlayerState>` | `{currentStreak, longestStreak, totalDistanceKm, cellsObserved}` | none |
| `itemsProvider` | `NotifierProvider<ItemsNotifier, ItemsState>` | `{items: List<ItemInstance>, itemsByStatus: Map<ItemInstanceStatus, List<ItemInstance>>}` | none |
| `seasonProvider` | `NotifierProvider<SeasonNotifier, Season>` | `Season.summer \| Season.winter` | none |
| `cellServiceProvider` | `Provider<CellService>` | CellCache(LazyVoronoiCellService) | none |
| `fogResolverProvider` | `Provider<FogStateResolver>` | singleton | watches: cellServiceProvider |
| `supabaseBootstrapProvider` | `Provider<SupabaseBootstrap>` | singleton | pre-initialized in main() |
| `appDatabaseProvider` | `Provider<AppDatabase>` | singleton | none. Disposes on shutdown via `ref.onDispose` |
| `itemInstanceRepositoryProvider` | `Provider<ItemInstanceRepository>` | singleton | watches: appDatabaseProvider |
| `speciesRepositoryProvider` | `Provider<SpeciesRepository>` | singleton | watches: appDatabaseProvider. Sync provider backed by `DriftSpeciesRepository`. |
| `writeQueueRepositoryProvider` | `Provider<WriteQueueRepository>` | singleton | watches: appDatabaseProvider |
| `cellProgressRepositoryProvider` | `Provider<CellProgressRepository>` | singleton | watches: appDatabaseProvider |
| `profileRepositoryProvider` | `Provider<ProfileRepository>` | singleton | watches: appDatabaseProvider |
| `dailySeedServiceProvider` | `Provider<DailySeedService>` | singleton | reads: supabaseClientProvider. Wires Supabase RPC `ensure_daily_seed()` as `SeedFetcher` callback. Returns null-safe service (works without Supabase). |
| `cellPropertyRepositoryProvider` | `Provider<CellPropertyRepository>` | singleton | watches: appDatabaseProvider. Cell properties CRUD (get, upsert, updateLocationId, getAll). |
| `countryResolverProvider` | `FutureProvider<CountryResolver>` | singleton | Loads `assets/country_boundaries.json` via rootBundle. Returns `CountryResolver` for offline country→continent resolution. |
| `cellPropertyResolverProvider` | `Provider<CellPropertyResolver>` | singleton | watches: habitatServiceProvider, countryResolverProvider. Falls back to DefaultHabitatLookup + legacy ContinentResolver during loading. |
| `gameCoordinatorProvider` | `Provider<GameCoordinator>` | singleton (runs forever) | watches: fogResolverProvider, locationServiceProvider, discoveryServiceProvider, itemInstanceRepositoryProvider, writeQueueRepositoryProvider, cellProgressRepositoryProvider, profileRepositoryProvider, cellPropertyRepositoryProvider, cellPropertyResolverProvider, locationEnrichmentServiceProvider. reads: authProvider, dailySeedServiceProvider. listens: playerProvider. Wires cellPropertiesLookup on discoveryService. Triggers location enrichment for cells without locationId. Wiring exception: imports features/ |

### Feature Providers

| Provider | Feature | Type | Dependencies |
|----------|---------|------|-------------|
| `authProvider` | auth | `NotifierProvider<AuthNotifier, AuthState>` | Thin state holder. `build()` returns `AuthState.initial()`. State pushed by `gameCoordinatorProvider` via `setState()`. Action wrappers delegate to `authServiceProvider`. |
| `upgradePromptProvider` | auth | `NotifierProvider<UpgradePromptNotifier, UpgradePromptState>` | watches: authProvider, itemsProvider. Triggers save-progress banner at 5 collected species for anonymous users |
| `onboardingProvider` | onboarding | `NotifierProvider<OnboardingNotifier, bool?>` | none (SharedPreferences) |
| `achievementProvider` | achievements | `NotifierProvider<AchievementNotifier, AchievementsState>` | reads: player, collection, restoration, speciesService |
| `achievementNotificationProvider` | achievements | `NotifierProvider` | none (toast queue) |
| `achievementServiceProvider` | achievements | `Provider<AchievementService>` | none (pure service) |
| `caretakingProvider` | caretaking | `NotifierProvider<CaretakingNotifier, CaretakingState>` | reads: playerProvider.notifier |
| `discoveryProvider` | discovery | `NotifierProvider<DiscoveryNotifier, DiscoveryState>` | none (notification queue) |
| `speciesServiceProvider` | discovery | `Provider<SpeciesService>` | watches: speciesCacheProvider. Cache-backed. Empty service until Drift DB loads. Enrichment fields come from `LocalSpeciesTable` — no separate enrichment merge. |
| `packProvider` | pack | `NotifierProvider<PackNotifier, PackState>` | watches: speciesService; listens: inventory |
| `tabIndexProvider` | navigation | `NotifierProvider<TabIndexNotifier, int>` | none (SharedPreferences) |
| `restorationProvider` | restoration | `NotifierProvider<RestorationNotifier, RestorationState>` | none |
| `sanctuaryProvider` | sanctuary | `NotifierProvider<SanctuaryNotifier, SanctuaryState>` | watches: speciesService; listens: inventory, player |
| `supabasePersistenceProvider` | sync | `Provider<SupabasePersistence?>` | reads: supabaseBootstrapProvider |
| `syncProvider` | sync | `NotifierProvider<SyncNotifier, SyncStatus>` | watches: supabasePersistence, queueProcessorProvider. reads: writeQueueRepositoryProvider, itemsProvider, itemInstanceRepositoryProvider |
| `queueProcessorProvider` | sync | `Provider<QueueProcessor>` | watches: writeQueueRepositoryProvider, supabasePersistenceProvider |
| `supabaseClientProvider` | sync | `Provider<SupabaseClient?>` | reads: supabaseBootstrapProvider. Returns null when Supabase not configured |
| `locationEnrichmentServiceProvider` | sync | `Provider<LocationEnrichmentService>` | watches: cellPropertyRepositoryProvider, supabaseClientProvider. Async location hierarchy enrichment via Nominatim Edge Function. Rate-limited 1 req/1.2s. |
| `habitatServiceProvider` | biome | `Provider<HabitatService>` | watches: biomeFeatureIndexProvider |
| `biomeFeatureIndexProvider` | biome | `FutureProvider<BiomeFeatureIndex>` | async asset load |
| `seasonServiceProvider` | seasonal | `Provider<SeasonService>` | none |

### Map Providers (lib/features/map/providers/)

| Provider | Type | Dependencies |
|----------|------|-------------|
| `mapStateProvider` | `NotifierProvider<MapStateNotifier, MapState>` | none |
| `cameraModeProvider` | `NotifierProvider<CameraModeNotifier, CameraMode>` | none |
| `cameraControllerProvider` | `Provider<CameraController>` | none |
| `locationServiceProvider` | `Provider<LocationService>` | none |
| `discoveryServiceProvider` | `Provider<DiscoveryService>` | watches: fogResolver, speciesService, habitatService, cellService, seasonService, dailySeedServiceProvider |
| `fogOverlayControllerProvider` | `Provider<FogOverlayController>` | watches: cellService, fogResolver |

## Cross-Feature Dependency Graph

```
supabaseBootstrapProvider ──→ authProvider ──→ upgradePromptProvider
                          ──→ supabasePersistenceProvider ──→ syncProvider
                          ──→ supabaseClientProvider ──→ locationEnrichmentServiceProvider

itemsProvider ──→ upgradePromptProvider (watch)

cellServiceProvider ──→ fogResolverProvider ──→ discoveryServiceProvider
                                           ──→ fogOverlayControllerProvider

fogResolverProvider ──→ gameCoordinatorProvider ──→ locationProvider (callback)
locationServiceProvider ──→ gameCoordinatorProvider    ──→ playerProvider (callback)
discoveryServiceProvider ──→ gameCoordinatorProvider   ──→ itemsProvider (callback)
itemInstanceRepositoryProvider ──→ gameCoordinatorProvider ──→ discoveryProvider (callback)
writeQueueRepositoryProvider ──→ gameCoordinatorProvider (persist to write queue)
cellProgressRepositoryProvider ──→ gameCoordinatorProvider (persist cell visits)
profileRepositoryProvider ──→ gameCoordinatorProvider (persist profile)
authProvider ──→ gameCoordinatorProvider (read + listen for hydration)
dailySeedServiceProvider ──→ gameCoordinatorProvider (read, fetches seed on startup)
dailySeedServiceProvider ──→ discoveryServiceProvider (stale seed guard)
supabaseClientProvider ──→ dailySeedServiceProvider (Supabase RPC callback)
playerProvider ──→ gameCoordinatorProvider (listen for profile write-through)

appDatabaseProvider ──→ itemInstanceRepositoryProvider
appDatabaseProvider ──→ speciesRepositoryProvider
appDatabaseProvider ──→ writeQueueRepositoryProvider
appDatabaseProvider ──→ cellProgressRepositoryProvider
appDatabaseProvider ──→ profileRepositoryProvider
appDatabaseProvider ──→ cellPropertyRepositoryProvider

habitatServiceProvider ──→ cellPropertyResolverProvider
countryResolverProvider ──→ cellPropertyResolverProvider
cellPropertyResolverProvider ──→ gameCoordinatorProvider (cell property resolution)
cellPropertyRepositoryProvider ──→ gameCoordinatorProvider (cell property persistence)
cellPropertyRepositoryProvider ──→ locationEnrichmentServiceProvider
supabaseClientProvider ──→ locationEnrichmentServiceProvider
locationEnrichmentServiceProvider ──→ gameCoordinatorProvider (location enrichment trigger)

writeQueueRepositoryProvider ──→ queueProcessorProvider
supabasePersistenceProvider ──→ queueProcessorProvider
queueProcessorProvider ──→ syncProvider
writeQueueRepositoryProvider ──→ syncProvider (read, for rollback)
itemsProvider ──→ syncProvider (read, for rollback)
itemInstanceRepositoryProvider ──→ syncProvider (read, for rollback)

speciesCacheProvider ──→ speciesServiceProvider
speciesServiceProvider ──→ discoveryServiceProvider
                       ──→ packProvider
                       ──→ sanctuaryProvider
                       ──→ achievementProvider

itemsProvider ──→ packProvider (listen)
              ──→ sanctuaryProvider (listen)
              ──→ achievementProvider (read)

tabIndexProvider ──→ (persists to SharedPreferences)

playerProvider ──→ sanctuaryProvider (listen)
               ──→ achievementProvider (read)
               ──→ caretakingProvider (read+write, bidirectional)
```

## State Mutation Patterns

| Pattern | When | Example |
|---------|------|---------|
| `ref.watch()` in `build()` | Reactive dependency — provider rebuilds when dep changes | fogResolverProvider watches cellServiceProvider |
| `ref.listen()` in `build()` | React to changes without resetting own state | packProvider listens to itemsProvider (preserves filters) |
| `ref.read()` in methods | One-shot mutation from event handler | caretakingProvider reads playerProvider.notifier |
| Stream subscription | External event source (GPS, fog events) | LocationNotifier.connectToStream(), map_screen subscriptions |
| Hydrate-then-start | Load persisted state before starting game loop | gameCoordinatorProvider: loadItems() → then startLoop() |
| Auth timing listen | Wait for async auth to settle before hydrating | gameCoordinatorProvider: ref.listen(authProvider) with `started` guard |

## Startup Hydration

`gameCoordinatorProvider` handles full state hydration on startup:

1. Read `authProvider` — if userId available, hydrate immediately
2. If auth still loading, `ref.listen<AuthState>` waits for it to settle
3. `_hydrateAndStart(userId)`:
   - Load items from SQLite via `ItemInstanceRepository` → seed `ItemsNotifier` + `DiscoveryService.markCollected()`
   - Load cell progress from SQLite via `CellProgressRepository` → count observed/hidden cells → seed `PlayerNotifier.cellsObserved`
   - Load player profile from SQLite via `ProfileRepository` → seed `PlayerNotifier` (streaks, distance)
   - Load cell properties from SQLite via `CellPropertyRepository.getAll()` → seed `GameCoordinator.loadCellProperties()` (parallel with above)
   - Start game loop
4. On hydration failure: starts game loop without data (graceful degradation)

**Profile write-through**: `ref.listen(playerProvider)` in `gameCoordinatorProvider` detects state changes and persists to `ProfileRepository` + enqueues to `WriteQueueRepository` (fire-and-forget).

**Race condition prevention**: `loadItems()` replaces inventory state entirely. The game loop must NOT start until hydration completes — otherwise a discovery during the race window would be wiped. A `started` flag prevents double-start if auth settles during hydration.

## Auto-Initialized vs Lazy

**Eager** (initialized at app startup):
1. `supabaseBootstrapProvider` — pre-initialized in main()
2. `authProvider` — EarthNovaApp watches it
3. `onboardingProvider` — EarthNovaApp watches it
4. `seasonProvider` — auto-init in build()

**Lazy** (initialized on first access):
- All other providers — triggered when MapScreen mounts or user navigates to feature screen

## Key Invariants

- No circular dependencies. Caretaking ↔ Player is one-way read+write, not circular watch.
- All NotifierProviders are global singletons — no `.family`, no `.autoDispose`.
- State updates are synchronous. Guard async gaps with `if (!ref.mounted) return;`.
- Core providers have zero feature dependencies. Core never imports features/.
- GameCoordinator runs at ProviderScope level — never stops on tab switch. Map screen is a pure renderer.
- gameCoordinatorProvider is the ONE justified exception to "core/ never imports features/".
