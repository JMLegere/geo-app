import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geobase/geobase.dart';
import 'package:uuid/uuid.dart';

import 'package:earth_nova/core/database/app_database.dart';
import 'package:earth_nova/core/engine/engine_runner.dart';
import 'package:earth_nova/core/services/observability_buffer.dart';
import 'package:earth_nova/core/engine/game_engine.dart';
import 'package:earth_nova/core/engine/main_thread_engine_runner.dart';
import 'package:earth_nova/core/engine/game_coordinator.dart';
import 'package:earth_nova/core/state/cell_service_provider.dart';
import 'package:earth_nova/core/models/affix.dart';
import 'package:earth_nova/core/models/animal_size.dart';
import 'package:earth_nova/core/models/fog_state.dart';
import 'package:earth_nova/core/models/animal_class.dart';
import 'package:earth_nova/core/models/climate.dart';
import 'package:earth_nova/core/models/food_type.dart';
import 'package:earth_nova/core/models/item_category.dart';
import 'package:earth_nova/core/models/item_definition.dart';
import 'package:earth_nova/core/models/item_instance.dart';
import 'package:earth_nova/core/models/iucn_status.dart';
import 'package:earth_nova/core/models/species_enrichment.dart';
import 'package:earth_nova/core/models/season.dart';
import 'package:earth_nova/core/models/write_queue_entry.dart';
import 'package:earth_nova/core/models/cell_properties.dart';
import 'package:earth_nova/core/persistence/cell_progress_repository.dart';
import 'package:earth_nova/core/persistence/cell_property_repository.dart';
import 'package:earth_nova/core/persistence/enrichment_repository.dart';
import 'package:earth_nova/core/persistence/item_instance_repository.dart';
import 'package:earth_nova/core/persistence/profile_repository.dart';
import 'package:earth_nova/features/items/services/stats_service.dart';
import 'package:earth_nova/core/state/cell_progress_repository_provider.dart';
import 'package:earth_nova/core/state/cell_property_repository_provider.dart';
import 'package:earth_nova/features/world/services/cell_property_resolver.dart';
import 'package:earth_nova/core/state/cell_property_resolver_provider.dart';
import 'package:earth_nova/core/state/daily_seed_provider.dart';
import 'package:earth_nova/core/state/fog_resolver_provider.dart';
import 'package:earth_nova/features/items/providers/items_provider.dart';
import 'package:earth_nova/core/state/item_instance_repository_provider.dart';
import 'package:earth_nova/core/state/location_provider.dart';
import 'package:earth_nova/core/state/player_provider.dart';
import 'package:earth_nova/core/state/profile_repository_provider.dart';
import 'package:earth_nova/core/state/persistence_consumer.dart';
import 'package:earth_nova/features/auth/models/auth_state.dart';
import 'package:earth_nova/features/auth/providers/auth_provider.dart';
import 'package:earth_nova/features/discovery/providers/discovery_provider.dart';
import 'package:earth_nova/features/sync/providers/enrichment_provider.dart';
import 'package:earth_nova/features/location/services/location_service.dart';
import 'package:earth_nova/features/location/services/location_simulator.dart';
import 'package:earth_nova/features/location/services/real_gps_service.dart';
import 'package:earth_nova/features/map/providers/discovery_service_provider.dart';
import 'package:earth_nova/features/map/providers/location_service_provider.dart';
import 'package:earth_nova/features/steps/providers/step_provider.dart';
import 'package:earth_nova/features/sync/providers/admin_boundary_provider.dart';
import 'package:earth_nova/features/sync/providers/location_enrichment_provider.dart';
import 'package:earth_nova/features/sync/providers/queue_processor_provider.dart';
import 'package:earth_nova/features/sync/providers/sync_provider.dart';
import 'package:earth_nova/features/sync/services/enrichment_service.dart';
import 'package:earth_nova/features/sync/services/queue_processor.dart';
import 'package:earth_nova/features/sync/services/supabase_persistence.dart';
import 'package:earth_nova/shared/constants.dart';
import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/state/enrichment_consumer.dart';
import 'package:earth_nova/core/state/species_repository_provider.dart';

/// Bridges [GameEngine] (core, pure Dart) with feature-layer services.
///
/// This is the ONE justified exception to the "core/ does not import features/"
/// rule — it's the central orchestrator wiring layer that connects the pure
/// game logic engine to Riverpod providers and feature services.
///
/// ## Wiring responsibilities
///
/// 1. Creates [GameEngine] which wraps [GameCoordinator] with event stream I/O
/// 2. Maps LocationService.filteredLocationStream (SimulatedLocation) → core stream type
/// 3. Chains engine event callbacks with Riverpod notifier mutations
/// 4. Wires write paths: SQLite persistence + write queue for Supabase sync
/// 5. Hydrates inventory, cell progress, and profile from SQLite on startup
/// 6. Starts the game loop
/// 7. Disposes engine + resources on provider invalidation
///
/// ## Transitional callback chaining
///
/// [GameEngine] wires coordinator callbacks to emit [GameEvent]s. This provider
/// chains those handlers with its own Riverpod/persistence logic so BOTH event
/// emission and state mutations fire on each callback.
final gameCoordinatorProvider = Provider<GameCoordinator>((ref) {
  final fogResolver = ref.watch(fogResolverProvider);
  final cellService = ref.watch(cellServiceProvider);
  final locationService = ref.watch(locationServiceProvider);
  final discoveryService = ref.watch(discoveryServiceProvider);
  final itemRepo = ref.watch(itemInstanceRepositoryProvider);
  final cellProgressRepo = ref.watch(cellProgressRepositoryProvider);
  final profileRepo = ref.watch(profileRepositoryProvider);
  final queueProcessor = ref.watch(queueProcessorProvider);

  final enrichmentRepo = ref.watch(enrichmentRepositoryProvider);
  final cellPropertyResolver = ref.read(cellPropertyResolverProvider);
  final cellPropertyRepo = ref.watch(cellPropertyRepositoryProvider);

  // Create EventSink when Supabase is configured for structured event telemetry.
  final supabaseClient = ref.read(supabaseClientProvider);
  ObservabilityBuffer? obs;
  if (supabaseClient != null) {
    obs = ObservabilityBuffer(
      flusher: (rows) => supabaseClient.from('app_events').insert(rows),
    );
    obs.start();
    ObservabilityBuffer.instance = obs;
    // Recover previous session data from localStorage (survives jetsam kills).
    final recovered = obs.recover();
    if (recovered.isNotEmpty) {
      debugPrint('[Observability] recovering ${recovered.length} entries');
      // Replay to debug console so entries are visible locally.
      for (final row in recovered) {
        final cat = row['category'] ?? '';
        final evt = row['event'] ?? '';
        final data = row['data'];
        final ts = row['created_at'] ?? '';
        debugPrint(
          '[RECOVERED] [$ts] $cat/$evt ${data is Map ? data['msg'] ?? data['action'] ?? data : ''}',
        );
        row['session_id'] = 'recovered:${row['session_id'] ?? 'unknown'}';
      }
      supabaseClient.from('app_events').insert(recovered).catchError((
        Object e,
      ) {
        debugPrint('[Observability] recovery flush failed: $e');
      });
    }
  }

  // Guard flag: set to true in ref.onDispose to prevent callbacks and
  // startLoop() from calling ref.read() on a dead provider reference.
  // This closes the race where .whenComplete() fires after disposal.
  var _providerDisposed = false;

  // In-memory enrichment cache for synchronous stat lookups during discovery.
  // Populated during hydration, updated when new enrichments arrive.
  final enrichmentCache =
      <String, ({int speed, int brawn, int wit, AnimalSize? size})>{};

  // Deferred enrichment queue: species beyond the startup cap of
  // kStartupEnrichmentCap. Populated by _requeueUnenrichedSpecies, drained
  // lazily by a Timer.periodic every kDeferredEnrichmentIntervalSeconds.
  // Cleared on sign-out so stale species don't leak into the next session.
  final deferredEnrichmentQueue =
      <({String definitionId, FaunaDefinition fauna, bool force})>[];
  Timer? deferredDrainTimer;

  final engine = GameEngine(
    fogResolver: fogResolver,
    statsService: const StatsService(),
    cellService: cellService,
    isRealGps: locationService.mode == LocationMode.realGps,
    obs: obs,
  );
  final coordinator = engine.coordinator;

  // Wire cell property resolver for geo-derived cell properties.
  coordinator.setCellPropertyResolver(cellPropertyResolver);

  // Wire cell properties lookup on discovery service so it can use
  // pre-resolved properties and detect cell events (Migration, Nesting Site).
  // Set as a mutable field to avoid circular provider dependency — the
  // callback is only invoked at event time (never during construction).
  discoveryService.cellPropertiesLookup =
      (cellId) => coordinator.cellPropertiesCache[cellId];

  // Wire synchronous enrichment lookup for stat rolling.
  coordinator.enrichedStatsLookup = (definitionId) {
    return enrichmentCache[definitionId];
  };

  // Enrichment hook callback — shared between initial wiring and re-wiring
  // after auth cycle (logout → re-login). Updates the in-memory cache and
  // backfills intrinsic affixes for items whose enrichment arrived via the
  // startup requeue path (Path B), matching what the in-session discovery
  // path (Path A) already does.
  void enrichmentHook(SpeciesEnrichment enrichment) {
    if (_providerDisposed) return;
    debugPrint(
      '[GameCoordinator] onEnrichedHook: backfilling affixes for '
      '${enrichment.definitionId}',
    );
    enrichmentCache[enrichment.definitionId] = (
      speed: enrichment.speed,
      brawn: enrichment.brawn,
      wit: enrichment.wit,
      size: enrichment.size,
    );
    final userId = ref.read(authProvider).user?.id;
    if (userId != null) {
      backfillIntrinsicAffixes(
        definitionId: enrichment.definitionId,
        enrichedStats: enrichmentCache[enrichment.definitionId]!,
        ref: ref,
        statsService: coordinator.statsService,
        itemRepo: itemRepo,
        queueProcessor: queueProcessor,
        userId: userId,
      ).catchError((Object e) {
        debugPrint('[GameCoordinator] onEnrichedHook backfill failed: $e');
      });
    }
  }

  ref.read(enrichmentServiceProvider).onEnrichedHook = enrichmentHook;

  // --- Wire auto-flush callback → post-flush badge/rejection processing ---

  queueProcessor.onAutoFlushComplete = (summary) async {
    if (_providerDisposed) return;
    if (summary.hasRejections) {
      await ref.read(syncProvider.notifier).processRejections();
    }
    if (summary.hasFirstBadges) {
      await ref
          .read(syncProvider.notifier)
          .applyFirstBadges(summary.firstBadgeItemIds);
    }
    // Refresh pending count in sync UI.
    await ref.read(syncProvider.notifier).refreshPendingCount();
  };

  // --- Chain engine event emission with provider logic ---
  //
  // GameEngine wired callbacks in its constructor to emit GameEvents to its
  // stream + EventSink. We save those handlers and chain with provider logic
  // so BOTH event emission and Riverpod state mutations fire on each callback.
  // Engine handler fires first (event emission), then provider logic follows.

  final engineOnLocation = coordinator.onPlayerLocationUpdate;
  coordinator.onPlayerLocationUpdate = (Geographic position, double accuracy) {
    engineOnLocation?.call(position, accuracy);
    if (_providerDisposed) return;
    ref.read(locationProvider.notifier).updateLocation(position, accuracy);
  };

  final engineOnGpsError = coordinator.onGpsErrorChanged;
  coordinator.onGpsErrorChanged = (GpsError error) {
    engineOnGpsError?.call(error);
    if (_providerDisposed) return;
    final locationError = switch (error) {
      GpsError.none => LocationError.none,
      GpsError.permissionDenied => LocationError.permissionDenied,
      GpsError.permissionDeniedForever => LocationError.permissionDeniedForever,
      GpsError.serviceDisabled => LocationError.serviceDisabled,
      GpsError.lowAccuracy => LocationError.lowAccuracy,
    };
    ref.read(locationProvider.notifier).setError(locationError);
  };

  final engineOnCellVisited = coordinator.onCellVisited;
  coordinator.onCellVisited = (String cellId) {
    engineOnCellVisited?.call(cellId);
    if (_providerDisposed) return;
    ref.read(playerProvider.notifier).incrementCellsObserved();

    // Persist cell visit to SQLite + enqueue for Supabase sync.
    final userId = ref.read(authProvider).user?.id;
    if (userId != null) {
      persistCellVisit(
        cellId: cellId,
        userId: userId,
        cellProgressRepo: cellProgressRepo,
        queueProcessor: queueProcessor,
        obs: obs,
      );
    }

    // Enrich visited cell + ring-1 Voronoi neighbors.
    // Service deduplicates via _inFlight set and rate-limits to 1 req/1.2s,
    // so repeated calls for the same cell are safe.
    final locationEnrichmentSvc = ref.read(locationEnrichmentServiceProvider);
    final visitedCenter = cellService.getCellCenter(cellId);
    locationEnrichmentSvc.requestEnrichment(
      cellId: cellId,
      lat: visitedCenter.lat,
      lon: visitedCenter.lon,
    );
    for (final neighborId in cellService.getNeighborIds(cellId)) {
      final center = cellService.getCellCenter(neighborId);
      locationEnrichmentSvc.requestEnrichment(
        cellId: neighborId,
        lat: center.lat,
        lon: center.lon,
      );
    }

    // Trigger admin boundary polygon fetch for the visited cell.
    // AdminBoundaryService deduplicates by rounded lat/lon and only calls the
    // Edge Function when admin levels are missing geometry.
    final adminBoundaryService = ref.read(adminBoundaryServiceProvider);
    adminBoundaryService?.requestBoundaries(
      visitedCenter.lat,
      visitedCenter.lon,
    );
  };

  final engineOnCellProps = coordinator.onCellPropertiesResolved;
  coordinator.onCellPropertiesResolved = (CellProperties properties) {
    engineOnCellProps?.call(properties);
    if (_providerDisposed) return;
    // Persist cell properties to SQLite + enqueue for Supabase sync.
    // Cell properties are global (not per-user), so no userId needed for
    // SQLite. Write queue still needs userId for routing.
    persistCellProperties(
      properties: properties,
      cellPropertyRepo: cellPropertyRepo,
      queueProcessor: queueProcessor,
      userId: ref.read(authProvider).user?.id,
      obs: obs,
    );
  };

  final engineOnDiscovery = coordinator.onItemDiscovered;
  coordinator.onItemDiscovered = (event, instance) {
    engineOnDiscovery?.call(event, instance);
    if (_providerDisposed) return;
    // First-discovery badge (★):
    // - When Supabase IS configured: server-validated after write queue
    //   flushes and validate-encounter confirms first global discovery.
    // - When Supabase is NOT configured (mock/offline): awarded locally
    //   if this definition hasn't been collected before.
    final supabase = ref.read(supabasePersistenceProvider);
    var badgedInstance = instance;
    if (supabase == null) {
      // Offline/mock mode: check local inventory for first-of-species.
      final inventory = ref.read(itemsProvider);
      if (!inventory.hasDefinition(instance.definitionId)) {
        badgedInstance = instance.copyWith(
          badges: {...instance.badges, kBadgeFirstDiscovery},
        );
      }
    }

    ref.read(discoveryProvider.notifier).showDiscovery(event);
    ref.read(itemsProvider.notifier).addItem(badgedInstance);
    discoveryService.markCollected(badgedInstance.definitionId);

    // Persist to SQLite + enqueue for Supabase sync.
    final userId = ref.read(authProvider).user?.id;
    if (userId != null) {
      persistItemDiscovery(
        instance: badgedInstance,
        userId: userId,
        itemRepo: itemRepo,
        queueProcessor: queueProcessor,
        obs: obs,
      );
    }

    // Fire enrichment request for fauna items (fire-and-forget).
    // On success, update the in-memory cache so future discoveries of the
    // same species get biologically accurate stats immediately.
    if (event.item is FaunaDefinition) {
      final fauna = event.item as FaunaDefinition;
      ref
          .read(enrichmentServiceProvider)
          .requestEnrichment(
            definitionId: fauna.id,
            scientificName: fauna.scientificName,
            commonName: fauna.displayName,
            taxonomicClass: fauna.taxonomicClass,
          )
          .then((_) async {
        final enrichment = await enrichmentRepo.getEnrichment(fauna.id);
        if (enrichment != null) {
          final stats = (
            speed: enrichment.speed,
            brawn: enrichment.brawn,
            wit: enrichment.wit,
            size: enrichment.size,
          );
          enrichmentCache[fauna.id] = stats;

          // Retroactively roll intrinsic affixes for any existing items
          // of this species that were discovered before enrichment arrived.
          final userId = ref.read(authProvider).user?.id;
          if (userId != null) {
            await backfillIntrinsicAffixes(
              definitionId: fauna.id,
              enrichedStats: stats,
              ref: ref,
              statsService: coordinator.statsService,
              itemRepo: itemRepo,
              queueProcessor: queueProcessor,
              userId: userId,
            );
          }
        }
      }).catchError((Object e) {
        debugPrint('[GameCoordinator] enrichment request failed: $e');
      });
    }
  };

  // --- Wire permission check callback ---

  coordinator.checkPermission = () async {
    final status = await locationService.checkPermission();
    if (status == null) return null;
    return switch (status) {
      GpsPermissionStatus.granted => GpsPermissionResult.granted,
      GpsPermissionStatus.denied => GpsPermissionResult.denied,
      GpsPermissionStatus.deniedForever => GpsPermissionResult.deniedForever,
      GpsPermissionStatus.serviceDisabled =>
        GpsPermissionResult.serviceDisabled,
    };
  };

  // --- Map LocationService stream → core stream type ---

  final gpsStream = locationService.filteredLocationStream.map(
    (SimulatedLocation loc) => (position: loc.position, accuracy: loc.accuracy),
  );

  // --- Hydrate from SQLite then start game loop ---
  //
  // Phase 1: Read SQLite cache (fast: ~200ms) → hydrate providers → start loop.
  // Phase 2: Fetch from Supabase in background → write to SQLite for next launch.
  // loadItems() replaces inventory state, so it MUST complete before startLoop().
  // The Supabase fetch is non-blocking — data picked up on next app launch.

  final dailySeedService = ref.read(dailySeedServiceProvider);

  void startLoop() {
    // Guard: provider may have been disposed while the async hydration chain
    // was in flight (e.g. hot restart, auth change). Never start the loop
    // against a dead ref.
    if (_providerDisposed) return;

    obs?.event('game_loop_started', {
      'user_id': coordinator.currentUserId,
      'daily_seed': dailySeedService.currentSeed,
    });

    // Fetch daily seed before starting the game loop so encounters
    // have the seed available from the first cell visit.
    dailySeedService.fetchSeed().then((_) {
      debugPrint(
        '[GameCoordinator] daily seed ready: '
        '${dailySeedService.currentSeed}',
      );
    }).catchError((Object e) {
      debugPrint('[GameCoordinator] daily seed fetch failed: $e');
    }).whenComplete(() {
      if (_providerDisposed) return;
      locationService.start();
      coordinator.start(
        gpsStream: gpsStream,
        discoveryStream: discoveryService.onDiscovery,
      );
    });
  }

  // Track last persisted profile to avoid re-persisting hydrated state.
  // Declared before hydrateAndStart so the closure can capture it.
  PlayerState? lastPersistedProfile;

  // Track which user we last hydrated for. Used by the auth change listener
  // to detect identity changes (e.g. logout → re-login with different user).
  // We can't rely on authProvider's previous value because the previous state
  // after logout is unauthenticated (userId=null), making it impossible to
  // compare against the new userId.
  String? lastHydratedUserId;

  /// Load player data from SQLite into providers (inventory, cells, profile,
  /// enrichment cache). Does NOT start the game loop — call [startLoop]
  /// separately after this completes.
  Future<void> rehydrateData(String userId) async {
    try {
      final results = await Future.wait<Object?>([
        itemRepo.getItemsByUser(userId),
        cellProgressRepo.readByUser(userId),
        profileRepo.read(userId),
        enrichmentRepo.getAllEnrichments(),
        cellPropertyRepo.getAll(),
      ]);

      final items = results[0]! as List<ItemInstance>;
      final cellRows = results[1]! as List<LocalCellProgress>;
      final profile = results[2] as LocalPlayerProfile?;
      final enrichments = results[3]! as List<SpeciesEnrichment>;
      final cellProperties = results[4]! as List<CellProperties>;

      // 0a. Populate enrichment cache for synchronous stat lookups.
      for (final e in enrichments) {
        enrichmentCache[e.definitionId] = (
          speed: e.speed,
          brawn: e.brawn,
          wit: e.wit,
          size: e.size,
        );
      }

      // 0b. Pre-populate cell properties cache from SQLite.
      if (cellProperties.isNotEmpty) {
        final propsMap = <String, CellProperties>{};
        for (final cp in cellProperties) {
          propsMap[cp.cellId] = cp;
        }
        coordinator.loadCellProperties(propsMap);
      }

      // 0c. Re-resolve cells that were resolved before biome data loaded.
      // These cells have {plains} as their only habitat due to the fallback
      // HabitatService being active during initial loading. Now that the real
      // resolver is available, re-resolve them to get accurate habitats.
      final reResolved = coordinator.reResolvePlainsOnlyCells();
      if (reResolved.isNotEmpty) {
        debugPrint(
          '[GameCoordinator] re-resolved ${reResolved.length} '
          'plains-only cells with real biome data',
        );
        for (final props in reResolved) {
          persistCellProperties(
            properties: props,
            cellPropertyRepo: cellPropertyRepo,
            queueProcessor: queueProcessor,
            userId: ref.read(authProvider).user?.id,
            obs: obs,
          );
        }
      }

      // 1. Hydrate inventory
      if (items.isNotEmpty) {
        ref.read(itemsProvider.notifier).loadItems(items);
        for (final item in items) {
          discoveryService.markCollected(item.definitionId);
        }
      }

      // 2. Hydrate cell progress → seed visited cells into fog resolver
      if (cellRows.isNotEmpty) {
        final visitedCellIds = <String>{};
        for (final row in cellRows) {
          final fog = FogState.fromString(row.fogState);
          if (fog == FogState.observed || fog == FogState.hidden) {
            visitedCellIds.add(row.cellId);
          }
        }
        if (visitedCellIds.isNotEmpty) {
          fogResolver.loadVisitedCells(visitedCellIds);
        }
      }

      // 3. Hydrate player profile
      // cellsObserved is derived from the count of visited cell rows, NOT
      // stored in the profile table (which has no such column).
      final cellsObserved = cellRows.where((row) {
        final fog = FogState.fromString(row.fogState);
        return fog == FogState.observed || fog == FogState.hidden;
      }).length;

      // Capture the in-memory onboarding flag before hydration overwrites
      // state. Merge monotonically: once true in-memory, never reset to false
      // by a DB read (e.g. if DB write hadn't landed yet).
      final currentOnboarding = ref.read(playerProvider).hasCompletedOnboarding;

      if (profile != null) {
        ref.read(playerProvider.notifier).loadProfile(
              cellsObserved: cellsObserved,
              totalDistanceKm: profile.totalDistanceKm,
              currentStreak: profile.currentStreak,
              longestStreak: profile.longestStreak,
              hasCompletedOnboarding:
                  profile.hasCompletedOnboarding || currentOnboarding,
              totalSteps: profile.totalSteps,
              lastKnownStepCount: profile.lastKnownStepCount,
            );
      } else {
        // No profile row yet — still hydrate cellsObserved from cell progress.
        if (cellsObserved > 0) {
          ref.read(playerProvider.notifier).loadProfile(
                cellsObserved: cellsObserved,
                totalDistanceKm: 0.0,
                currentStreak: 0,
                longestStreak: 0,
              );
        }
      }

      // Signal hydration complete — ensures _resolveHome() in main.dart
      // shows LoadingScreen until profile data is available (preventing
      // an OnboardingScreen flash for returning users).
      ref.read(playerProvider.notifier).markHydrated();

      // Capture hydrated profile state so the write-through listener
      // doesn't redundantly persist the data we just loaded from SQLite.
      lastPersistedProfile = ref.read(playerProvider);

      obs?.event('sqlite_hydration_complete', {
        'user_id': userId,
        'item_count': items.length,
        'cell_count': cellRows.length,
        'has_profile': profile != null,
        'enrichment_count': enrichments.length,
        'cell_property_count': cellProperties.length,
      });

      // 4. Hydrate step counter (all platforms).
      // Must run AFTER profile hydration so totalSteps is already loaded.
      // Computes login delta: max(pedometerDelta, daysSince × kMinDailyStepGrant).
      // Web pedometer returns 0, so the daily minimum floor guarantees progress.
      // Passes profile.updatedAt as lastSessionDate for recap subtitle.
      try {
        final stepNotifier = ref.read(stepProvider.notifier);
        await stepNotifier.hydrate(
          lastKnownStepCount: profile?.lastKnownStepCount ?? 0,
          totalSteps: ref.read(playerProvider).totalSteps,
          lastSessionDate: profile?.updatedAt,
        );
      } catch (e) {
        debugPrint('[GameCoordinator] step hydration failed: $e');
      }
    } catch (e) {
      debugPrint('[GameCoordinator] failed to hydrate: $e');
    }
  }

  void hydrateAndStart(String userId) {
    // Phase 1: Read local SQLite cache first (fast: ~200ms).
    // Gets the user to the map immediately with cached data.
    //
    // Phase 2: Fetch from Supabase in background → write to SQLite.
    // Data will be picked up on next app launch. Don't re-hydrate
    // providers — avoids race with in-flight discoveries.
    //
    // The game loop MUST start even if hydration fails (e.g. Ref disposed
    // due to provider rebuild race).
    obs?.event('hydration_started', {'user_id': userId});

    final hydrationStopwatch = Stopwatch()..start();

    // Phase 1: SQLite → providers → markHydrated() → startLoop().
    rehydrateData(userId).then((_) async {
      // Warm species cache for cells already in the cell properties cache.
      // Uses the habitats/continent from the first resolved cell property;
      // subsequent warm-ups fire automatically when the player moves.
      final speciesCache = ref.read(speciesCacheProvider);
      if (!speciesCache.isEmpty) {
        final cachedProps = coordinator.cellPropertiesCache.values;
        if (cachedProps.isNotEmpty) {
          final first = cachedProps.first;
          speciesCache.warmUp(
            habitats: first.habitats,
            continent: first.continent,
          );
        } else {
          // No cached cells yet — warm default habitats for a common area.
          speciesCache.warmUp(
            habitats: {Habitat.forest, Habitat.plains},
            continent: Continent.northAmerica,
          );
        }
      }

      // Restore last known position before starting the game loop.
      // This ensures the map and keyboard service start at the player's
      // previous location instead of the hardcoded Fredericton default.
      final profile = await profileRepo.read(userId);
      if (profile?.lastLat != null && profile?.lastLon != null) {
        locationService.setInitialPosition(
          profile!.lastLat!,
          profile.lastLon!,
        );
        debugPrint(
          '[GameCoordinator] restored position: '
          '${profile.lastLat}, ${profile.lastLon}',
        );
      }

      hydrationStopwatch.stop();
      final inventory = ref.read(itemsProvider);
      obs?.event('hydration_complete', {
        'user_id': userId,
        'duration_ms': hydrationStopwatch.elapsedMilliseconds,
        'item_count': inventory.items.length,
        'enrichment_count': enrichmentCache.length,
        'source': 'sqlite',
      });

      // Start game loop immediately with cached data.
      if (_providerDisposed) return;
      startLoop();

      // Start live pedometer stream after game loop is running (native only).
      // Must be after hydrate() so _lastStreamValue is set as the baseline.
      if (!kIsWeb) {
        ref.read(stepProvider.notifier).startLiveStream();
      }

      // Phase 2: Fetch from Supabase in background → write to SQLite.
      // Non-blocking. If it fails, cached data is still valid.
      if (_providerDisposed) return;
      hydrateFromSupabase(
        userId: userId,
        persistence: ref.read(supabasePersistenceProvider),
        profileRepo: profileRepo,
        cellProgressRepo: cellProgressRepo,
        itemRepo: itemRepo,
        enrichmentRepo: enrichmentRepo,
        obs: obs,
      ).then((_) {
        if (_providerDisposed) return;

        obs?.event('background_sync_complete', {'user_id': userId});

        // Re-queue enrichment for any fauna in inventory that lacks it.
        // Runs after background sync so enrichment cache includes any
        // freshly-fetched enrichments from Supabase. Covers:
        //   - Enrichment requests dropped by daily rate limit
        //   - Enrichment requests lost to app restart (in-memory queue)
        //   - New enrichment pipeline deployed after species were discovered
        // Startup batch capped at kStartupEnrichmentCap; remainder drained
        // lazily by a Timer.periodic (handle stored in deferredDrainTimer
        // so ref.onDispose can cancel it).
        requeueUnenrichedSpecies(
          ref: ref,
          enrichmentCache: enrichmentCache,
          deferredQueue: deferredEnrichmentQueue,
          onTimerCreated: (timer) {
            deferredDrainTimer = timer;
          },
        );

        // Backfill intrinsic affixes for items that were discovered before
        // enrichment was available. Primary safety net — catches all edge
        // cases: items from before this fix, missed callbacks, races, etc.
        backfillAllMissingAffixes(
          ref: ref,
          enrichmentCache: enrichmentCache,
          statsService: coordinator.statsService,
          itemRepo: itemRepo,
          queueProcessor: queueProcessor,
          userId: userId,
        );
      }).catchError((Object e) {
        debugPrint(
          '[GameCoordinator] background Supabase sync failed: $e',
        );
        obs?.event('network_error', {
          'context': 'background_supabase_sync',
          'error': e.toString(),
        });
      });
    }).catchError((Object e) {
      debugPrint(
        '[GameCoordinator] SQLite hydration failed '
        '(starting loop anyway): $e',
      );
      if (!_providerDisposed) {
        // Mark hydrated even on failure so _resolveHome() progresses past
        // LoadingScreen. Without this, the app is stuck on "Loading your
        // world" forever when SQLite tables are missing (e.g. after
        // corruption auto-reset drops tables without recreation).
        ref.read(playerProvider.notifier).markHydrated();
        startLoop();
        if (!kIsWeb) {
          ref.read(stepProvider.notifier).startLiveStream();
        }
      }
    });
  }

  // --- Auth state handler ---
  //
  // Called on initial provider creation (for the case where auth is already
  // authenticated before this provider is first accessed) and on every future
  // auth state transition via ref.listen.

  void handleAuthState(AuthState authState) {
    final userId = authState.user?.id;

    obs?.event('auth_state_changed', {
      'status': authState.status.name,
      'user_id': userId,
    });

    if (authState.status == AuthStatus.authenticated && userId != null) {
      if (userId == lastHydratedUserId) return; // Already hydrated — no-op.
      lastHydratedUserId = userId;

      // Invalidate zombie enrichment service — after auth cycle, the old
      // service may have _authFailed = true (circuit breaker tripped).
      // Invalidation disposes the old service and creates a fresh one on
      // next read. Re-wire the onEnrichedHook on the new instance.
      ref.invalidate(enrichmentServiceProvider);
      ref.read(enrichmentServiceProvider).onEnrichedHook = enrichmentHook;

      coordinator.setCurrentUserId(userId);
      hydrateAndStart(userId);
    } else if (authState.status == AuthStatus.unauthenticated) {
      // Clear write queue for the outgoing user BEFORE resetting state.
      // Prevents stale entries from being flushed with the next session's
      // credentials, which would trigger RLS violations on Supabase.
      final outgoingUserId = lastHydratedUserId;
      if (outgoingUserId != null) {
        queueProcessor.clearUser(outgoingUserId);
      }

      coordinator.setCurrentUserId(null);
      lastHydratedUserId = null;
      // Cancel and clear deferred enrichment drain so stale species from the
      // outgoing session don't queue under the next session's credentials.
      deferredDrainTimer?.cancel();
      deferredDrainTimer = null;
      deferredEnrichmentQueue.clear();
      ref.read(playerProvider.notifier).loadProfile(
            cellsObserved: 0,
            totalDistanceKm: 0.0,
            currentStreak: 0,
            longestStreak: 0,
            hasCompletedOnboarding: false, // explicit reset on sign-out
          );
      ref.read(itemsProvider.notifier).loadItems([]);
      fogResolver.loadVisitedCells({});
      enrichmentCache.clear();
      lastPersistedProfile = null;
    }
  }

  // Immediate check — handles the case where this provider is created
  // after auth is already authenticated (no state change fires in that case).
  handleAuthState(ref.read(authProvider));

  // React to future auth state transitions (sign-in, sign-out, re-login).
  ref.listen<AuthState>(authProvider, (previous, next) {
    handleAuthState(next);
  });

  // --- Wire profile write-through: persist on PlayerState changes ---
  //
  // When PlayerNotifier state changes (cells observed, distance, streaks),
  // persist to SQLite and enqueue for Supabase sync. Uses a debounced
  // listener to avoid hammering the DB on rapid increments.

  ref.listen<PlayerState>(playerProvider, (previous, next) {
    if (previous == null) return; // Skip initial build.
    if (next == lastPersistedProfile) return; // Skip our own writes.

    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return;

    lastPersistedProfile = next;

    // Capture current position for session restore.
    final currentPos = ref.read(locationProvider).currentPosition;

    persistProfileState(
      userId: userId,
      playerState: next,
      profileRepo: profileRepo,
      queueProcessor: queueProcessor,
      lastLat: currentPos?.lat,
      lastLon: currentPos?.lon,
      obs: obs,
    );
  });

  // --- Re-resolve cells when biome data becomes available ---
  //
  // cellPropertyResolverProvider returns null while BiomeFeatureIndex is
  // loading. Once loaded, it transitions to a real CellPropertyResolver.
  // We listen for this transition to:
  //   1. Update the coordinator's resolver (so new cells get real habitats)
  //   2. Re-resolve any cells cached with the {plains} fallback
  //   3. Persist the corrected cell properties
  //
  // Using ref.listen (not ref.watch) avoids rebuilding the entire provider
  // and restarting the game loop just because biome data loaded.

  ref.listen<CellPropertyResolver?>(cellPropertyResolverProvider, (
    previous,
    next,
  ) {
    if (_providerDisposed) return;
    if (next == null) return;

    coordinator.setCellPropertyResolver(next);

    // Only re-resolve when transitioning from null → non-null (biome loaded).
    if (previous != null) return;

    final reResolved = coordinator.reResolvePlainsOnlyCells();
    if (reResolved.isNotEmpty) {
      debugPrint(
        '[GameCoordinator] biome loaded: re-resolved '
        '${reResolved.length} plains-only cells',
      );
      final userId = ref.read(authProvider).user?.id;
      for (final props in reResolved) {
        persistCellProperties(
          properties: props,
          cellPropertyRepo: cellPropertyRepo,
          queueProcessor: queueProcessor,
          userId: userId,
          obs: obs,
        );
      }
    }
  });

  // --- Cleanup ---

  ref.onDispose(() {
    _providerDisposed = true;
    deferredDrainTimer?.cancel();
    obs?.stop(); // Cancel periodic flush timer.
    engine.dispose(); // coordinator.dispose() + obs.flush() + stream close.
    queueProcessor.dispose();
    locationService.stop();
  });

  // Store engine reference for engineRunnerProvider.
  ref.onDispose(() => _latestEngine = null);
  _latestEngine = engine;

  return coordinator;
});

GameEngine? _latestEngine;

/// Exposes the [EngineRunner] for UI-layer event consumption.
///
/// Reads [gameCoordinatorProvider] to ensure the engine is created, then
/// wraps it in a [MainThreadEngineRunner]. Widgets use this to call
/// `engineRunner.send(PositionUpdate(...))` and subscribe to events.
final engineRunnerProvider = Provider<EngineRunner>((ref) {
  ref.watch(gameCoordinatorProvider);
  final engine = _latestEngine;
  if (engine == null) {
    throw StateError(
      'engineRunnerProvider read before gameCoordinatorProvider',
    );
  }
  return MainThreadEngineRunner(engine);
});
