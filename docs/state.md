# State Map

All Riverpod providers, their types, state shapes, and dependency wiring.

## Provider Inventory

### Core Providers (lib/core/state/)

| Provider | Type | State Shape | Dependencies |
|----------|------|-------------|-------------|
| `fogProvider` | `NotifierProvider<FogNotifier, Map<String, FogState>>` | `{cellId: FogState}` | none |
| `locationProvider` | `NotifierProvider<LocationNotifier, LocationState>` | `{currentPosition?, accuracy?, isTracking, locationError}` | none |
| `playerProvider` | `NotifierProvider<PlayerNotifier, PlayerState>` | `{currentStreak, longestStreak, totalDistanceKm, cellsObserved}` | none |
| `collectionProvider` | `NotifierProvider<CollectionNotifier, CollectionState>` | `{collectedSpeciesIds: List<String>}` | none |
| `seasonProvider` | `NotifierProvider<SeasonNotifier, Season>` | `Season.summer \| Season.winter` | none |
| `cellServiceProvider` | `Provider<CellService>` | CellCache(LazyVoronoiCellService) | none |
| `fogResolverProvider` | `Provider<FogStateResolver>` | singleton | watches: cellServiceProvider |
| `supabaseBootstrapProvider` | `Provider<SupabaseBootstrap>` | singleton | pre-initialized in main() |

### Feature Providers

| Provider | Feature | Type | Dependencies |
|----------|---------|------|-------------|
| `authProvider` | auth | `NotifierProvider<AuthNotifier, AuthState>` | reads: supabaseBootstrapProvider. States: initial, unauthenticated, authenticated, guest, loading, error |
| `onboardingProvider` | onboarding | `NotifierProvider<OnboardingNotifier, bool?>` | none (SharedPreferences) |
| `achievementProvider` | achievements | `NotifierProvider<AchievementNotifier, AchievementsState>` | reads: player, collection, restoration, speciesService |
| `achievementNotificationProvider` | achievements | `NotifierProvider` | none (toast queue) |
| `caretakingProvider` | caretaking | `NotifierProvider<CaretakingNotifier, CaretakingState>` | reads: playerProvider.notifier |
| `discoveryProvider` | discovery | `NotifierProvider<DiscoveryNotifier, DiscoveryState>` | none (notification queue) |
| `speciesServiceProvider` | discovery | `Provider<SpeciesService>` | none (dev fixture) |
| `packProvider` | pack | `NotifierProvider<PackNotifier, PackState>` | watches: speciesService; listens: collection |
| `tabIndexProvider` | navigation | `NotifierProvider<TabIndexNotifier, int>` | none (SharedPreferences) |
| `restorationProvider` | restoration | `NotifierProvider<RestorationNotifier, RestorationState>` | none |
| `sanctuaryProvider` | sanctuary | `NotifierProvider<SanctuaryNotifier, SanctuaryState>` | watches: speciesService; listens: collection, player |
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
supabaseBootstrapProvider ──→ authProvider
                          ──→ supabasePersistenceProvider ──→ syncProvider

cellServiceProvider ──→ fogResolverProvider ──→ discoveryServiceProvider
                                           ──→ fogOverlayControllerProvider

speciesServiceProvider ──→ discoveryServiceProvider
                       ──→ packProvider
                       ──→ sanctuaryProvider
                       ──→ achievementProvider

collectionProvider ──→ packProvider (listen)
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
| `ref.listen()` in `build()` | React to changes without resetting own state | packProvider listens to collectionProvider (preserves filters) |
| `ref.read()` in methods | One-shot mutation from event handler | caretakingProvider reads playerProvider.notifier |
| Stream subscription | External event source (GPS, fog events) | LocationNotifier.connectToStream(), map_screen subscriptions |

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
