# State Map

All Riverpod providers, their types, state shapes, and dependency wiring.

## Provider Inventory

### Core Providers (lib/core/state/)

| Provider | Type | State Shape | Dependencies |
|----------|------|-------------|-------------|
| `fogProvider` | `NotifierProvider<FogNotifier, Map<String, FogState>>` | `{cellId: FogState}` | none |
| `locationProvider` | `NotifierProvider<LocationNotifier, LocationState>` | `{currentPosition?, accuracy?, isTracking, locationError}` | none |
| `playerProvider` | `NotifierProvider<PlayerNotifier, PlayerState>` | `{currentStreak, longestStreak, totalDistanceKm, cellsObserved}` | none |
| `inventoryProvider` | `NotifierProvider<InventoryNotifier, InventoryState>` | `{items: List<ItemInstance>, itemsByStatus: Map<ItemInstanceStatus, List<ItemInstance>>}` | none |
| `seasonProvider` | `NotifierProvider<SeasonNotifier, Season>` | `Season.summer \| Season.winter` | none |
| `cellServiceProvider` | `Provider<CellService>` | CellCache(LazyVoronoiCellService) | none |
| `fogResolverProvider` | `Provider<FogStateResolver>` | singleton | watches: cellServiceProvider |
| `supabaseBootstrapProvider` | `Provider<SupabaseBootstrap>` | singleton | pre-initialized in main() |
| `appDatabaseProvider` | `Provider<AppDatabase>` | singleton | none. Disposes on shutdown via `ref.onDispose` |
| `itemInstanceRepositoryProvider` | `Provider<ItemInstanceRepository>` | singleton | watches: appDatabaseProvider |
| `gameCoordinatorProvider` | `Provider<GameCoordinator>` | singleton (runs forever) | watches: fogResolverProvider, locationServiceProvider, discoveryServiceProvider, itemInstanceRepositoryProvider. reads: authProvider. Wiring exception: imports features/ |

### Feature Providers

| Provider | Feature | Type | Dependencies |
|----------|---------|------|-------------|
| `authProvider` | auth | `NotifierProvider<AuthNotifier, AuthState>` | reads: supabaseBootstrapProvider. States: unauthenticated, loading, authenticated |
| `upgradePromptProvider` | auth | `NotifierProvider<UpgradePromptNotifier, UpgradePromptState>` | watches: authProvider, inventoryProvider. Triggers save-progress banner at 5 collected species for anonymous users |
| `onboardingProvider` | onboarding | `NotifierProvider<OnboardingNotifier, bool?>` | none (SharedPreferences) |
| `achievementProvider` | achievements | `NotifierProvider<AchievementNotifier, AchievementsState>` | reads: player, collection, restoration, speciesService |
| `achievementNotificationProvider` | achievements | `NotifierProvider` | none (toast queue) |
| `caretakingProvider` | caretaking | `NotifierProvider<CaretakingNotifier, CaretakingState>` | reads: playerProvider.notifier |
| `discoveryProvider` | discovery | `NotifierProvider<DiscoveryNotifier, DiscoveryState>` | none (notification queue) |
| `speciesDataProvider` | discovery | `FutureProvider<List<FaunaDefinition>>` | async asset load (rootBundle) |
| `speciesServiceProvider` | discovery | `Provider<SpeciesService>` | watches: speciesDataProvider. Empty fallback during loading/error |
| `packProvider` | pack | `NotifierProvider<PackNotifier, PackState>` | watches: speciesService; listens: inventory |
| `tabIndexProvider` | navigation | `NotifierProvider<TabIndexNotifier, int>` | none (SharedPreferences) |
| `restorationProvider` | restoration | `NotifierProvider<RestorationNotifier, RestorationState>` | none |
| `sanctuaryProvider` | sanctuary | `NotifierProvider<SanctuaryNotifier, SanctuaryState>` | watches: speciesService; listens: inventory, player |
| `supabasePersistenceProvider` | sync | `Provider<SupabasePersistence?>` | reads: supabaseBootstrapProvider |
| `syncProvider` | sync | `NotifierProvider<SyncNotifier, SyncStatus>` | watches: supabasePersistence |

### Map Providers (lib/features/map/providers/)

| Provider | Type | Dependencies |
|----------|------|-------------|
| `mapStateProvider` | `NotifierProvider<MapStateNotifier, MapState>` | none |
| `cameraModeProvider` | `NotifierProvider<CameraModeNotifier, CameraMode>` | none |
| `cameraControllerProvider` | `Provider<CameraController>` | none |
| `locationServiceProvider` | `Provider<LocationService>` | none |
| `discoveryServiceProvider` | `Provider<DiscoveryService>` | watches: fogResolver, speciesService, habitatService, cellService, seasonService |
| `fogOverlayControllerProvider` | `Provider<FogOverlayController>` | watches: cellService, fogResolver |
| `habitatServiceProvider` | `Provider<HabitatService>` | watches: biomeFeatureIndexProvider |
| `biomeFeatureIndexProvider` | `FutureProvider<BiomeFeatureIndex>` | async asset load |
| `seasonServiceProvider` | `Provider<SeasonService>` | none |

## Cross-Feature Dependency Graph

```
supabaseBootstrapProvider ──→ authProvider ──→ upgradePromptProvider
                          ──→ supabasePersistenceProvider ──→ syncProvider

inventoryProvider ──→ upgradePromptProvider (watch)

cellServiceProvider ──→ fogResolverProvider ──→ discoveryServiceProvider
                                           ──→ fogOverlayControllerProvider

fogResolverProvider ──→ gameCoordinatorProvider ──→ locationProvider (callback)
locationServiceProvider ──→ gameCoordinatorProvider    ──→ playerProvider (callback)
discoveryServiceProvider ──→ gameCoordinatorProvider   ──→ inventoryProvider (callback)
itemInstanceRepositoryProvider ──→ gameCoordinatorProvider ──→ discoveryProvider (callback)
authProvider ──→ gameCoordinatorProvider (read + listen for hydration)

appDatabaseProvider ──→ itemInstanceRepositoryProvider

speciesDataProvider ──→ speciesServiceProvider
speciesServiceProvider ──→ discoveryServiceProvider
                       ──→ packProvider
                       ──→ sanctuaryProvider
                       ──→ achievementProvider

inventoryProvider ──→ packProvider (listen)
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
| `ref.listen()` in `build()` | React to changes without resetting own state | packProvider listens to inventoryProvider (preserves filters) |
| `ref.read()` in methods | One-shot mutation from event handler | caretakingProvider reads playerProvider.notifier |
| Stream subscription | External event source (GPS, fog events) | LocationNotifier.connectToStream(), map_screen subscriptions |
| Hydrate-then-start | Load persisted state before starting game loop | gameCoordinatorProvider: loadItems() → then startLoop() |
| Auth timing listen | Wait for async auth to settle before hydrating | gameCoordinatorProvider: ref.listen(authProvider) with `started` guard |

## Startup Hydration

`gameCoordinatorProvider` handles inventory hydration on startup:

1. Read `authProvider` — if userId available, hydrate immediately
2. If auth still loading, `ref.listen<AuthState>` waits for it to settle
3. `hydrateAndStart(userId)`: loads items from SQLite via `itemInstanceRepositoryProvider`, seeds `inventoryProvider` and `discoveryService.markCollected()`, then starts game loop
4. On hydration failure: starts game loop without data (graceful degradation)

**Race condition prevention**: `loadItems()` replaces inventory state entirely. The game loop must NOT start until hydration completes — otherwise a discovery during the race window would be wiped. A `started` flag prevents double-start if auth settles during hydration.

## Auto-Initialized vs Lazy

**Eager** (initialized at app startup):
1. `supabaseBootstrapProvider` — pre-initialized in main()
2. `authProvider` — FogOfWorldApp watches it
3. `onboardingProvider` — FogOfWorldApp watches it
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
