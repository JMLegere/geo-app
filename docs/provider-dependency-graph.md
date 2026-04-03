# Complete Riverpod Provider Dependency Graph

**EarthNova** — Flutter 3.41.3 + Riverpod 3.2.1 (Notifier pattern)

Generated: 2026-04-02

---

## Summary

- **Total Providers**: 64
- **NotifierProviders**: 15 (mutable state)
- **Providers**: 44 (stateless services, infrastructure)
- **FutureProviders**: 2 (async asset loading)
- **StreamProviders**: 0

---

## Quick Navigation

- [TIER 0: Leaf Nodes](#tier-0-no-dependencies-leaf-nodes) — 30 providers with no dependencies
- [TIER 1: Single-Level Dependencies](#tier-1-single-level-dependencies) — 32 providers
- [TIER 2: Multi-Level Dependencies](#tier-2-multi-level-dependencies) — 2 providers
- [TIER 3: Central Orchestrator](#tier-3-central-orchestrator-gamecoordinator) — gameCoordinatorProvider
- [Dependency Layers](#dependency-layers-topological-sort) — Organized by depth
- [Cross-Provider Listeners](#cross-provider-listeners-reflisten) — Reactive updates
- [Testing Patterns](#testing-patterns) — How to test providers

---

## TIER 0: No Dependencies (Leaf Nodes)

These providers have no upstream dependencies.

### Infrastructure Providers

| Provider | Type | File | Returns |
|----------|------|------|---------|
| `cellServiceProvider` | `Provider<CellService>` | `lib/core/state/cell_service_provider.dart` | `CellCache(LazyVoronoiCellService)` |
| `appDatabaseProvider` | `Provider<AppDatabase>` | `lib/core/state/app_database_provider.dart` | `AppDatabase` with species seeding |
| `supabaseBootstrapProvider` | `Provider<bool>` | `lib/core/state/supabase_bootstrap_provider.dart` | Boolean (pre-initialized in main) |
| `seasonServiceProvider` | `Provider<SeasonService>` | `lib/features/calendar/providers/season_service_provider.dart` | `SeasonService()` singleton |
| `stepServiceProvider` | `Provider<StepService>` | `lib/features/steps/providers/step_provider.dart` | `StepService()` singleton |
| `achievementServiceProvider` | `Provider<AchievementService>` | `lib/features/achievements/providers/achievement_provider.dart` | `AchievementService()` singleton |
| `locationServiceProvider` | `Provider<LocationService>` | `lib/features/map/providers/location_service_provider.dart` | `LocationService()` (not auto-started) |
| `fogOverlayControllerProvider` | `Provider<FogOverlayController>` | `lib/features/map/providers/fog_overlay_controller_provider.dart` | `FogOverlayController()` |
| `detectionZoneServiceProvider` | `Provider<DetectionZoneService>` | `lib/core/state/detection_zone_provider.dart` | `DetectionZoneService()` |
| `locationEnrichmentProvider` | `Provider<LocationEnrichmentService>` | `lib/features/sync/providers/location_enrichment_provider.dart` | `LocationEnrichmentService()` |

### State Notifiers (Mutable State)

| Provider | Type | File | State | Build |
|----------|------|------|-------|-------|
| `seasonProvider` | `NotifierProvider<SeasonNotifier, Season>` | `lib/core/state/season_provider.dart` | `Season` (summer/winter) | `Season.fromDate(DateTime.now())` |
| `playerProvider` | `NotifierProvider<PlayerNotifier, PlayerState>` | `lib/core/state/player_provider.dart` | `PlayerState` (streaks, distance, cells, steps) | `PlayerState()` empty |
| `locationProvider` | `NotifierProvider<LocationNotifier, LocationState>` | `lib/core/state/location_provider.dart` | `LocationState` (position, accuracy, tracking) | `LocationState()` empty |
| `fogProvider` | `NotifierProvider<FogNotifier, Map<String, FogState>>` | `lib/core/state/fog_provider.dart` | `Map<cellId, FogState>` | `{}` empty map |
| `tabIndexProvider` | `NotifierProvider<TabIndexNotifier, int>` | `lib/core/state/tab_index_provider.dart` | `int` (0=Map, 1=Home, 2=Town, 3=Pack) | `0` (default to Map) |
| `onboardingProvider` | `NotifierProvider<OnboardingNotifier, bool?>` | `lib/features/onboarding/providers/onboarding_provider.dart` | `bool?` (null=loading, false=not done, true=done) | `null` (loading) |
| `zoneReadyProvider` | `NotifierProvider<ZoneReadyNotifier, bool>` | `lib/core/state/zone_ready_provider.dart` | `bool` (detection zone resolved) | `false` |
| `playerLocatedProvider` | `NotifierProvider<PlayerLocatedNotifier, bool>` | `lib/core/state/player_located_provider.dart` | `bool` (rubber-band converged) | `false` |
| `mapStateProvider` | `NotifierProvider<MapStateNotifier, MapState>` | `lib/features/map/providers/map_state_provider.dart` | `MapState` (isReady, camera, zoom) | `MapState(isReady: false, zoom: 15.0)` |
| `itemsProvider` | `NotifierProvider<ItemsNotifier, ItemsState>` | `lib/features/items/providers/items_provider.dart` | `ItemsState` (items: List<ItemInstance>) | `ItemsState()` empty |
| `caretakingProvider` | `NotifierProvider<CaretakingNotifier, CaretakingState>` | `lib/features/caretaking/providers/caretaking_provider.dart` | `CaretakingState` (streaks, lastVisitDate) | `CaretakingState()` empty |
| `discoveryProvider` | `NotifierProvider<DiscoveryNotifier, DiscoveryState>` | `lib/features/discovery/providers/discovery_provider.dart` | `DiscoveryState` (recentDiscoveries, queue) | `DiscoveryState()` empty |
| `achievementNotificationProvider` | `NotifierProvider<AchievementNotificationNotifier, AchievementNotificationState>` | `lib/features/achievements/providers/achievement_provider.dart` | `AchievementNotificationState` (hasActive, current) | `AchievementNotificationState()` empty |
| `authProvider` | `NotifierProvider<AuthNotifier, AuthState>` | `lib/features/auth/providers/auth_provider.dart` | `AuthState` (status, user, errorMessage) | `AuthState.loading()` |
| `cellSelectionProvider` | `NotifierProvider<CellSelectionNotifier, String?>` | `lib/features/map/providers/cell_selection_provider.dart` | `String?` (selected cell ID) | `null` |
| `upgradePromptProvider` | `NotifierProvider<UpgradePromptNotifier, bool>` | `lib/features/auth/providers/upgrade_prompt_provider.dart` | `bool` (show upgrade prompt) | `false` |
| `syncToastProvider` | `NotifierProvider<SyncToastNotifier, SyncToastState>` | `lib/features/sync/providers/sync_toast_provider.dart` | `SyncToastState` (message, type) | `SyncToastState()` empty |

### Utility Providers

| Provider | Type | File | Returns |
|----------|------|------|---------|
| `debugLogProvider` | `Provider<List<String>>` | `lib/core/state/debug_log_provider.dart` | Empty list (debug log buffer) |
| `cachedFunFactsProvider` | `Provider<List<String>>` | `lib/core/state/fun_facts_provider.dart` | Empty list (cached fun facts) |
| `gpsPermissionProvider` | `Provider<GpsPermissionStatus>` | `lib/core/state/gps_permission_provider.dart` | GPS permission status |

---

## TIER 1: Single-Level Dependencies

### Fog & Cell System

| Provider | Type | File | Dependencies | Returns |
|----------|------|------|--------------|---------|
| `fogResolverProvider` | `Provider<FogStateResolver>` | `lib/core/state/fog_resolver_provider.dart` | `cellServiceProvider` (watches) | `FogStateResolver` instance |

### Async Asset Loaders

| Provider | Type | File | Dependencies | Returns |
|----------|------|------|--------------|---------|
| `countryResolverProvider` | `FutureProvider<CountryResolver>` | `lib/core/state/country_resolver_provider.dart` | None (uses rootBundle) | `CountryResolver` (async) |
| `biomeFeatureIndexProvider` | `FutureProvider<BiomeFeatureIndex>` | `lib/features/world/providers/habitat_service_provider.dart` | None (uses rootBundle) | `BiomeFeatureIndex` (async, 10s delay on web) |

### Supabase Infrastructure

| Provider | Type | File | Dependencies | Returns |
|----------|------|------|--------------|---------|
| `_supabaseReadyProvider` | `Provider<bool>` | `lib/features/sync/providers/sync_provider.dart` | `supabaseBootstrapProvider` (watches) | Boolean |
| `supabaseClientProvider` | `Provider<SupabaseClient?>` | `lib/features/sync/providers/sync_provider.dart` | `_supabaseReadyProvider` (watches) | `SupabaseClient` or null |
| `supabasePersistenceProvider` | `Provider<SupabasePersistence?>` | `lib/features/sync/providers/sync_provider.dart` | `supabaseClientProvider` (watches) | `SupabasePersistence` or null |

### Database Repositories

| Provider | Type | File | Dependencies | Returns |
|----------|------|------|--------------|---------|
| `profileRepositoryProvider` | `Provider<ProfileRepository>` | `lib/core/state/profile_repository_provider.dart` | `appDatabaseProvider` (watches) | `ProfileRepository` |
| `cellProgressRepositoryProvider` | `Provider<CellProgressRepository>` | `lib/core/state/cell_progress_repository_provider.dart` | `appDatabaseProvider` (watches) | `CellProgressRepository` |
| `cellPropertyRepositoryProvider` | `Provider<CellPropertyRepository>` | `lib/core/state/cell_property_repository_provider.dart` | `appDatabaseProvider` (watches) | `CellPropertyRepository` |
| `itemInstanceRepositoryProvider` | `Provider<ItemInstanceRepository>` | `lib/core/state/item_instance_repository_provider.dart` | `appDatabaseProvider` (watches) | `ItemInstanceRepository` |
| `writeQueueRepositoryProvider` | `Provider<WriteQueueRepository>` | `lib/core/state/write_queue_repository_provider.dart` | `appDatabaseProvider` (watches) | `WriteQueueRepository` |
| `hierarchyRepositoryProvider` | `Provider<HierarchyRepository>` | `lib/core/state/hierarchy_repository_provider.dart` | `appDatabaseProvider` (watches) | `HierarchyRepository` |
| `speciesRepositoryProvider` | `Provider<SpeciesRepository>` | `lib/core/state/species_repository_provider.dart` | `appDatabaseProvider` (watches) | `DriftSpeciesRepository` |
| `speciesCacheProvider` | `Provider<SpeciesCache>` | `lib/core/state/species_repository_provider.dart` | `speciesRepositoryProvider` (watches) | `SpeciesCache` |

### Services

| Provider | Type | File | Dependencies | Returns |
|----------|------|------|--------------|---------|
| `dailySeedServiceProvider` | `Provider<DailySeedService>` | `lib/core/state/daily_seed_provider.dart` | `supabaseBootstrapProvider` (watches) | `DailySeedService` with optional Supabase RPC |
| `habitatServiceProvider` | `Provider<HabitatService>` | `lib/features/world/providers/habitat_service_provider.dart` | `biomeFeatureIndexProvider` (watches) | `HabitatService` (with fallback to plains) |
| `speciesServiceProvider` | `Provider<SpeciesService>` | `lib/features/discovery/providers/discovery_provider.dart` | `speciesCacheProvider` (watches) | `SpeciesService.fromCache()` or empty |
| `queueProcessorProvider` | `Provider<QueueProcessor>` | `lib/features/sync/providers/queue_processor_provider.dart` | `supabaseClientProvider` (reads) | `QueueProcessor` |

### Stats & Exploration

| Provider | Type | File | Dependencies | Returns |
|----------|------|------|--------------|---------|
| `explorationStatsProvider` | `Provider<ExplorationStats>` | `lib/core/state/exploration_stats_provider.dart` | `playerProvider`, `cellProgressRepositoryProvider` (reads) | `ExplorationStats` snapshot |

---

## TIER 2: Multi-Level Dependencies

### Cell Property Resolution

```
cellPropertyResolverProvider
  Type: Provider<CellPropertyResolver?>
  File: lib/core/state/cell_property_resolver_provider.dart
  
  Dependencies:
    - biomeFeatureIndexProvider (watches) — FutureProvider
    - habitatServiceProvider (watches)
    - countryResolverProvider (watches) — FutureProvider
  
  Returns: CellPropertyResolver or null (while loading)
  
  Note: Returns null until biome feature index is loaded to prevent 
        incorrect habitat caching. Falls back to plains + legacy continent resolver.
```

### Discovery Service

```
discoveryServiceProvider
  Type: Provider<DiscoveryService>
  File: lib/features/map/providers/discovery_service_provider.dart
  
  Dependencies (watches):
    - fogResolverProvider
    - cellServiceProvider
    - seasonServiceProvider
    - dailySeedServiceProvider
  
  Dependencies (reads for fallback):
    - speciesServiceProvider
    - habitatServiceProvider
  
  Lazy Getters (resolved at event time):
    - speciesServiceProvider (getter)
    - habitatServiceProvider (getter)
  
  Returns: DiscoveryService instance
  Lifecycle: ref.onDispose() → service.dispose()
  
  Note: Uses lazy getter pattern to avoid rebuilding gameCoordinatorProvider 
        when async providers load. During loading window, getters return 
        fallback instances (empty SpeciesService / plains-only HabitatService).
```

### Sync Provider

```
syncProvider
  Type: NotifierProvider<SyncNotifier, SyncStatus>
  File: lib/features/sync/providers/sync_provider.dart
  
  State: SyncStatus (type, errorMessage, pendingCount)
  Build: SyncStatus based on supabasePersistenceProvider availability
  
  Dependencies (watches):
    - supabasePersistenceProvider
  
  Dependencies (reads in methods):
    - authProvider (in _currentUserId getter)
    - queueProcessorProvider (in syncNow)
    - writeQueueRepositoryProvider (in syncNow)
    - itemsProvider (in applyFirstBadges)
    - cellProgressRepositoryProvider (in syncNow)
    - fogProvider (in processRejections)
  
  Mutations: syncNow, refreshPendingCount, processRejections, applyFirstBadges
```

### Achievement Provider

```
achievementProvider
  Type: NotifierProvider<AchievementNotifier, AchievementsState>
  File: lib/features/achievements/providers/achievement_provider.dart
  
  State: AchievementsState (achievements: Map<AchievementId, AchievementProgress>)
  Build: All achievements initialized as locked
  
  Dependencies (watches in checkAchievements):
    - itemsProvider
    - playerProvider
    - discoveryProvider
  
  Mutations: checkAchievements
  
  Note: Dual notifier pattern with achievementNotificationProvider
```

### Pack & Sanctuary Providers

```
packProvider
  Type: NotifierProvider<PackNotifier, PackState>
  File: lib/features/pack/providers/pack_provider.dart
  
  State: PackState (itemsByCategory, activeTab, playerStats)
  Build: PackState() empty
  
  Dependencies (watches):
    - itemsProvider
    - playerProvider
  
  Mutations: setActiveTab

sanctuaryProvider
  Type: NotifierProvider<SanctuaryNotifier, SanctuaryState>
  File: lib/features/sanctuary/providers/sanctuary_provider.dart
  
  State: SanctuaryState (speciesByHabitat, totalCollected, totalInPool, currentStreak, activeTab)
  Build: SanctuaryState() empty
  
  Dependencies (watches):
    - itemsProvider
    - playerProvider
    - speciesServiceProvider
  
  Mutations: setActiveTab
```

---

## TIER 3: Central Orchestrator (GameCoordinator)

```
gameCoordinatorProvider
  Type: Provider<GameCoordinator>
  File: lib/core/state/game_coordinator_provider.dart
  
  Returns: GameCoordinator instance (central game loop)
  
  Dependencies (watches):
    - fogResolverProvider
    - cellServiceProvider
    - locationServiceProvider
    - discoveryServiceProvider
    - itemInstanceRepositoryProvider
    - cellProgressRepositoryProvider
    - profileRepositoryProvider
    - queueProcessorProvider
    - cellPropertyRepositoryProvider
    - cellPropertyResolverProvider
  
  Dependencies (reads):
    - supabaseClientProvider
    - appDatabaseProvider
    - authProvider
    - dailySeedServiceProvider
    - speciesRepositoryProvider
    - detectionZoneServiceProvider
    - stepServiceProvider
    - locationEnrichmentProvider
    - syncProvider
  
  Lifecycle: ref.onDispose() → engine.dispose()
  
  Responsibilities:
    1. Hydrates inventory, cell progress, profile from SQLite on startup
    2. Fetches daily seed on startup
    3. Starts game loop (~10 Hz)
    4. Subscribes to GPS stream
    5. Processes discovery events
    6. Persists discoveries, cell visits, profile changes to SQLite + write queue
    7. Listens to playerProvider for profile write-through
    8. Wires cellPropertiesLookup on DiscoveryService
    9. Triggers locationEnrichmentService for cells without locationId
  
  Note: JUSTIFIED exception to "core/ does not import features/" rule — 
        central orchestrator wiring layer that bridges pure game logic 
        with Riverpod providers and feature services.

engineRunnerProvider
  Type: Provider<EngineRunner>
  File: lib/core/state/game_coordinator_provider.dart
  
  Returns: EngineRunner instance
  
  Dependencies:
    - gameCoordinatorProvider (watches)
```

---

## Dependency Layers (Topological Sort)

### Layer 0: Leaf Nodes (30 providers)
No dependencies. Can be instantiated immediately.

```
cellServiceProvider, seasonServiceProvider, stepServiceProvider,
achievementServiceProvider, appDatabaseProvider, supabaseBootstrapProvider,
seasonProvider, playerProvider, locationProvider, fogProvider,
tabIndexProvider, onboardingProvider, zoneReadyProvider, playerLocatedProvider,
mapStateProvider, itemsProvider, caretakingProvider, discoveryProvider,
achievementNotificationProvider, authProvider, cellSelectionProvider,
upgradePromptProvider, syncToastProvider, locationEnrichmentProvider,
detectionZoneServiceProvider, debugLogProvider, cachedFunFactsProvider,
gpsPermissionProvider, locationServiceProvider, fogOverlayControllerProvider
```

### Layer 1: Single-Level Dependencies (32 providers)
Depend only on Layer 0 providers.

```
fogResolverProvider (← cellServiceProvider)
countryResolverProvider (async asset)
biomeFeatureIndexProvider (async asset)
_supabaseReadyProvider (← supabaseBootstrapProvider)
supabaseClientProvider (← _supabaseReadyProvider)
supabasePersistenceProvider (← supabaseClientProvider)
profileRepositoryProvider (← appDatabaseProvider)
cellProgressRepositoryProvider (← appDatabaseProvider)
cellPropertyRepositoryProvider (← appDatabaseProvider)
itemInstanceRepositoryProvider (← appDatabaseProvider)
writeQueueRepositoryProvider (← appDatabaseProvider)
hierarchyRepositoryProvider (← appDatabaseProvider)
speciesRepositoryProvider (← appDatabaseProvider)
speciesCacheProvider (← speciesRepositoryProvider)
dailySeedServiceProvider (← supabaseBootstrapProvider)
habitatServiceProvider (← biomeFeatureIndexProvider)
speciesServiceProvider (← speciesCacheProvider)
queueProcessorProvider (reads supabaseClientProvider)
explorationStatsProvider (reads playerProvider, cellProgressRepositoryProvider)
```

### Layer 2: Multi-Level Dependencies (6 providers)
Depend on Layer 0 and Layer 1 providers.

```
cellPropertyResolverProvider (← biomeFeatureIndexProvider, habitatServiceProvider, countryResolverProvider)
discoveryServiceProvider (← fogResolverProvider, cellServiceProvider, seasonServiceProvider, dailySeedServiceProvider, speciesServiceProvider, habitatServiceProvider)
syncProvider (← supabasePersistenceProvider, authProvider, queueProcessorProvider, writeQueueRepositoryProvider, itemsProvider, cellProgressRepositoryProvider, fogProvider)
achievementProvider (← itemsProvider, playerProvider, discoveryProvider)
packProvider (← itemsProvider, playerProvider)
sanctuaryProvider (← itemsProvider, playerProvider, speciesServiceProvider)
```

### Layer 3: Central Orchestrator (2 providers)
Depend on all previous layers.

```
gameCoordinatorProvider (← 20+ providers from layers 0-2)
engineRunnerProvider (← gameCoordinatorProvider)
```

---

## Cross-Provider Listeners (ref.listen)

These providers actively listen to other providers for reactive updates:

### packProvider
```dart
Listens to: itemsProvider, playerProvider
Action: Rebuilds itemsByCategory and playerStats on change
```

### sanctuaryProvider
```dart
Listens to: itemsProvider, playerProvider, speciesServiceProvider
Action: Rebuilds speciesByHabitat and stats on change
```

### achievementProvider
```dart
Listens to: itemsProvider, playerProvider, discoveryProvider
Action: Re-evaluates achievements on state change
```

### caretakingProvider
```dart
Reads: playerProvider.notifier (in _syncStreakToPlayer)
Action: Syncs streak changes bidirectionally
```

### syncProvider
```dart
Reads: authProvider (in _currentUserId getter)
Reads: queueProcessorProvider (in syncNow)
Reads: writeQueueRepositoryProvider (in syncNow)
Reads: itemsProvider (in applyFirstBadges)
Reads: cellProgressRepositoryProvider (in syncNow)
Reads: fogProvider (in processRejections)
Action: Processes sync operations and applies server responses
```

### gameCoordinatorProvider
```dart
Listens to: playerProvider (for profile write-through)
Action: Persists profile changes to SQLite + write queue
```

---

## Provider Mutation Patterns

### Direct State Mutations (Notifier.state = ...)
All NotifierProviders use immutable state replacement:
```dart
state = state.copyWith(field: newValue)
```

### Async Mutations (Future<void>)
- `tabIndexProvider.notifier.setTab(index)` — persists to SharedPreferences
- `onboardingProvider.notifier.markCompleted()` — persists to SharedPreferences
- `authProvider.notifier.sendOtp(phone)` — calls auth service
- `authProvider.notifier.verifyOtp(phone, code)` — calls auth service
- `syncProvider.notifier.syncNow()` — flushes write queue to Supabase

### Bidirectional Sync
- `caretakingProvider` ↔ `playerProvider` (streak sync)
- `gameCoordinatorProvider` → `playerProvider` (profile write-through)
- `gameCoordinatorProvider` → `itemsProvider` (discovery persistence)
- `gameCoordinatorProvider` → `cellProgressRepositoryProvider` (cell visit persistence)

---

## Initialization Order (Startup Sequence)

1. **supabaseBootstrapProvider** — Pre-initialized in main() before runApp()
2. **appDatabaseProvider** — Opened, species table seeded from JSON
3. **Leaf providers** — All instantiated (cellServiceProvider, seasonProvider, etc.)
4. **Layer 1 providers** — Repositories, services, async asset loaders
5. **Layer 2 providers** — Composed services (discoveryServiceProvider, cellPropertyResolverProvider)
6. **gameCoordinatorProvider** — Hydrates from SQLite, starts game loop
7. **UI providers** — mapStateProvider, packProvider, sanctuaryProvider, etc.

### Hydration Gates (in main.dart)
- `playerProvider.isHydrated` — profile loaded from SQLite
- `zoneReadyProvider` — detection zone resolved
- `playerLocatedProvider` — rubber-band converged
- `onboardingProvider` — onboarding completion status loaded

---

## Provider Lifecycle Management

### Disposal Hooks (ref.onDispose)
- `appDatabaseProvider` → `db.close()`
- `fogResolverProvider` → `resolver.dispose()`
- `discoveryServiceProvider` → `service.dispose()`
- `locationServiceProvider` → `service.dispose()`
- `fogOverlayControllerProvider` → `controller.dispose()`
- `gameCoordinatorProvider` → `engine.dispose()`

### Stream Subscriptions
- `locationProvider` — GPS stream subscription (managed by LocationNotifier)
- `gameCoordinatorProvider` — GPS stream subscription (managed by GameCoordinator)
- `discoveryServiceProvider` — Fog state change stream (managed by DiscoveryService)

### Async Loading
- `countryResolverProvider` — Loads assets/country_boundaries.json
- `biomeFeatureIndexProvider` — Loads assets/biome_features.json (10s delay on web)
- `tabIndexProvider` — Loads from SharedPreferences
- `onboardingProvider` — Loads from SharedPreferences

---

## Gotchas & Anti-Patterns

### 1. Lazy Getter Pattern (discoveryServiceProvider)
**Why**: Avoid rebuilding gameCoordinatorProvider when async providers load

```dart
final speciesService = ref.read(speciesServiceProvider);  // Fallback
final speciesServiceGetter = () => ref.read(speciesServiceProvider);  // Event-time
```

### 2. Null Fallback (cellPropertyResolverProvider)
**Why**: Prevent incorrect habitat caching while biome data loads

```dart
if (biomeAsync is! AsyncData<BiomeFeatureIndex>) return null;
```

### 3. Bidirectional Sync (caretakingProvider ↔ playerProvider)
**Why**: Keep streak state consistent across features

```dart
ref.read(playerProvider.notifier).setStreak(current: ..., longest: ...)
```

### 4. Fire-and-Forget Persistence (gameCoordinatorProvider)
**Why**: Non-blocking writes to SQLite + write queue

```dart
// Async/await with try/catch, no await in caller
() async {
  await itemRepo.create(instance);
  await writeQueueRepo.enqueue(entry);
}();
```

### 5. Guard Against Disposed Provider (async mutations)
**Why**: Prevent state updates after provider disposal

```dart
if (!ref.mounted) return;
state = newState;
```

---

## Testing Patterns

### Override Providers in Tests
```dart
final container = ProviderContainer(
  overrides: [
    appDatabaseProvider.overrideWithValue(testDb),
    speciesServiceProvider.overrideWithValue(testSpeciesService),
  ],
);
```

### Hand-Written Mocks (No mockito/mocktail)
```dart
class MockCellService implements CellService {
  @override
  String getCellId(double lat, double lon) => 'test_cell';
  // ... other methods
}
```

### Fixture Factories
```dart
ItemInstance makeItemInstance({
  String? id,
  String? definitionId,
  List<Affix>? affixes,
}) {
  return ItemInstance(
    id: id ?? 'test_${uuid.v4()}',
    definitionId: definitionId ?? 'test_species',
    affixes: affixes ?? [],
    // ... other fields
  );
}
```

---

## Summary Statistics

| Metric | Count |
|--------|-------|
| Total Providers | 64 |
| NotifierProviders | 15 |
| Providers (stateless) | 44 |
| FutureProviders | 2 |
| StreamProviders | 0 |
| Providers with ref.watch | 18 |
| Providers with ref.read | 12 |
| Providers with ref.listen | 5 |
| Providers with ref.onDispose | 8 |
| Max dependency depth | 3 (gameCoordinatorProvider) |
| Circular dependencies | 0 |

---

## Related Documentation

- `docs/architecture.md` — Layer diagram and dependency rules
- `docs/state.md` — Provider state shapes and mutation patterns
- `docs/game-loop.md` — GPS→render pipeline and game tick rates
- `AGENTS.md` — Design decisions and forbidden patterns
