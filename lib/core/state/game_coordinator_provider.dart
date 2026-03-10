import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geobase/geobase.dart';
import 'package:uuid/uuid.dart';

import 'package:earth_nova/core/database/app_database.dart';
import 'package:earth_nova/core/game/game_coordinator.dart';
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
import 'package:earth_nova/core/persistence/cell_progress_repository.dart';
import 'package:earth_nova/core/persistence/enrichment_repository.dart';
import 'package:earth_nova/core/persistence/item_instance_repository.dart';
import 'package:earth_nova/core/persistence/profile_repository.dart';
import 'package:earth_nova/core/persistence/write_queue_repository.dart';
import 'package:earth_nova/core/species/stats_service.dart';
import 'package:earth_nova/core/state/cell_progress_repository_provider.dart';
import 'package:earth_nova/core/state/daily_seed_provider.dart';
import 'package:earth_nova/core/state/fog_resolver_provider.dart';
import 'package:earth_nova/core/state/inventory_provider.dart';
import 'package:earth_nova/core/state/item_instance_repository_provider.dart';
import 'package:earth_nova/core/state/location_provider.dart';
import 'package:earth_nova/core/state/player_provider.dart';
import 'package:earth_nova/core/state/profile_repository_provider.dart';
import 'package:earth_nova/features/auth/models/auth_state.dart';
import 'package:earth_nova/features/auth/providers/auth_provider.dart';
import 'package:earth_nova/features/discovery/providers/discovery_provider.dart';
import 'package:earth_nova/features/enrichment/providers/enrichment_provider.dart';
import 'package:earth_nova/features/location/services/location_service.dart';
import 'package:earth_nova/features/location/services/location_simulator.dart';
import 'package:earth_nova/features/location/services/real_gps_service.dart';
import 'package:earth_nova/features/map/providers/discovery_service_provider.dart';
import 'package:earth_nova/features/map/providers/location_service_provider.dart';
import 'package:earth_nova/features/sync/providers/queue_processor_provider.dart';
import 'package:earth_nova/features/sync/providers/sync_provider.dart';
import 'package:earth_nova/features/sync/services/queue_processor.dart';
import 'package:earth_nova/features/sync/services/supabase_persistence.dart';
import 'package:earth_nova/shared/constants.dart';

/// Bridges [GameCoordinator] (core, pure Dart) with feature-layer services.
///
/// This is the ONE justified exception to the "core/ does not import features/"
/// rule — it's the central orchestrator wiring layer that connects the pure
/// game logic engine to Riverpod providers and feature services.
///
/// ## Wiring responsibilities
///
/// 1. Creates GameCoordinator with core dependencies (fogResolver, statsService)
/// 2. Maps LocationService.filteredLocationStream (SimulatedLocation) → core stream type
/// 3. Wires output callbacks → Riverpod notifiers (location, player, inventory, discovery)
/// 4. Wires write paths: SQLite persistence + write queue for Supabase sync
/// 5. Hydrates inventory, cell progress, and profile from SQLite on startup
/// 6. Starts the game loop
/// 7. Disposes on provider invalidation
final gameCoordinatorProvider = Provider<GameCoordinator>((ref) {
  final fogResolver = ref.watch(fogResolverProvider);
  final locationService = ref.watch(locationServiceProvider);
  final discoveryService = ref.watch(discoveryServiceProvider);
  final itemRepo = ref.watch(itemInstanceRepositoryProvider);
  final cellProgressRepo = ref.watch(cellProgressRepositoryProvider);
  final profileRepo = ref.watch(profileRepositoryProvider);
  final queueProcessor = ref.watch(queueProcessorProvider);

  final enrichmentRepo = ref.watch(enrichmentRepositoryProvider);

  // In-memory enrichment cache for synchronous stat lookups during discovery.
  // Populated during hydration, updated when new enrichments arrive.
  final enrichmentCache =
      <String, ({int speed, int brawn, int wit, AnimalSize? size})>{};

  final coordinator = GameCoordinator(
    fogResolver: fogResolver,
    statsService: const StatsService(),
    isRealGps: locationService.mode == LocationMode.realGps,
  );

  // Wire synchronous enrichment lookup for stat rolling.
  coordinator.enrichedStatsLookup = (definitionId) {
    return enrichmentCache[definitionId];
  };

  // --- Wire auto-flush callback → post-flush badge/rejection processing ---

  queueProcessor.onAutoFlushComplete = (summary) async {
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

  // --- Wire output callbacks → Riverpod notifiers ---

  coordinator.onPlayerLocationUpdate = (Geographic position, double accuracy) {
    ref.read(locationProvider.notifier).updateLocation(position, accuracy);
  };

  coordinator.onGpsErrorChanged = (GpsError error) {
    final locationError = switch (error) {
      GpsError.none => LocationError.none,
      GpsError.permissionDenied => LocationError.permissionDenied,
      GpsError.permissionDeniedForever => LocationError.permissionDeniedForever,
      GpsError.serviceDisabled => LocationError.serviceDisabled,
      GpsError.lowAccuracy => LocationError.lowAccuracy,
    };
    ref.read(locationProvider.notifier).setError(locationError);
  };

  coordinator.onCellVisited = (String cellId) {
    ref.read(playerProvider.notifier).incrementCellsObserved();

    // Persist cell visit to SQLite + enqueue for Supabase sync.
    final userId = ref.read(authProvider).user?.id;
    if (userId != null) {
      _persistCellVisit(
        cellId: cellId,
        userId: userId,
        cellProgressRepo: cellProgressRepo,
        queueProcessor: queueProcessor,
      );
    }
  };

  coordinator.onItemDiscovered = (event, instance) {
    // First-discovery badge (★):
    // - When Supabase IS configured: server-validated after write queue
    //   flushes and validate-encounter confirms first global discovery.
    // - When Supabase is NOT configured (mock/offline): awarded locally
    //   if this definition hasn't been collected before.
    final supabase = ref.read(supabasePersistenceProvider);
    var badgedInstance = instance;
    if (supabase == null) {
      // Offline/mock mode: check local inventory for first-of-species.
      final inventory = ref.read(inventoryProvider);
      if (!inventory.hasDefinition(instance.definitionId)) {
        badgedInstance = instance.copyWith(
          badges: {...instance.badges, kBadgeFirstDiscovery},
        );
      }
    }

    ref.read(discoveryProvider.notifier).showDiscovery(event);
    ref.read(inventoryProvider.notifier).addItem(badgedInstance);
    discoveryService.markCollected(badgedInstance.definitionId);

    // Persist to SQLite + enqueue for Supabase sync.
    final userId = ref.read(authProvider).user?.id;
    if (userId != null) {
      _persistItemDiscovery(
        instance: badgedInstance,
        userId: userId,
        itemRepo: itemRepo,
        queueProcessor: queueProcessor,
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
            await _backfillIntrinsicAffixes(
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

  // --- Hydrate all state then start game loop ---
  //
  // CRITICAL: loadItems() replaces inventory state, so the game loop must NOT
  // start until hydration completes. Otherwise a discovery that fires during
  // the race window would be wiped by loadItems(). We start the loop inside
  // the hydration callback (or immediately when no auth / on error).

  final dailySeedService = ref.read(dailySeedServiceProvider);

  void startLoop() {
    // Fetch daily seed before starting the game loop so encounters
    // have the seed available from the first cell visit.
    dailySeedService.fetchSeed().then((_) {
      debugPrint('[GameCoordinator] daily seed ready: '
          '${dailySeedService.currentSeed}');
    }).catchError((Object e) {
      debugPrint('[GameCoordinator] daily seed fetch failed: $e');
    }).whenComplete(() {
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
      ]);

      final items = results[0]! as List<ItemInstance>;
      final cellRows = results[1]! as List<LocalCellProgress>;
      final profile = results[2] as LocalPlayerProfile?;
      final enrichments = results[3]! as List<SpeciesEnrichment>;

      // 0. Populate enrichment cache for synchronous stat lookups.
      for (final e in enrichments) {
        enrichmentCache[e.definitionId] =
            (speed: e.speed, brawn: e.brawn, wit: e.wit, size: e.size);
      }

      // 1. Hydrate inventory
      if (items.isNotEmpty) {
        ref.read(inventoryProvider.notifier).loadItems(items);
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

      // Capture hydrated profile state so the write-through listener
      // doesn't redundantly persist the data we just loaded from SQLite.
      lastPersistedProfile = ref.read(playerProvider);
    } catch (e) {
      debugPrint('[GameCoordinator] failed to hydrate: $e');
    }
  }

  void hydrateAndStart(String userId) {
    // CRITICAL: On web, IndexedDB-backed SQLite may lose data between
    // sessions. Fetch from Supabase first to populate the local cache,
    // then run the existing SQLite hydration path.
    //
    // The game loop MUST start even if hydration fails (e.g. Ref disposed
    // due to provider rebuild race). Without .catchError, a rejected Future
    // from rehydrateData() would prevent startLoop() from ever firing,
    // leaving the map with zero GPS processing.
    hydrateFromSupabase(
      userId: userId,
      persistence: ref.read(supabasePersistenceProvider),
      profileRepo: profileRepo,
      cellProgressRepo: cellProgressRepo,
      itemRepo: itemRepo,
      enrichmentRepo: enrichmentRepo,
    ).then((_) => rehydrateData(userId)).then((_) async {
      // Restore last known position before starting the game loop.
      // This ensures the map and keyboard service start at the player's
      // previous location instead of the hardcoded Fredericton default.
      final profile = await profileRepo.read(userId);
      if (profile?.lastLat != null && profile?.lastLon != null) {
        locationService.setInitialPosition(
          profile!.lastLat!,
          profile.lastLon!,
        );
        debugPrint('[GameCoordinator] restored position: '
            '${profile.lastLat}, ${profile.lastLon}');
      }

      // Re-queue enrichment for any fauna in inventory that lacks it.
      // Runs async after game loop starts — non-blocking. Covers:
      //   - Enrichment requests dropped by daily rate limit (Groq 14.4k/day)
      //   - Enrichment requests lost to app restart (in-memory queue)
      //   - New enrichment pipeline deployed after species were discovered
      _requeueUnenrichedSpecies(
        ref: ref,
        enrichmentCache: enrichmentCache,
      );

      // Backfill intrinsic affixes for items that were discovered before
      // enrichment was available. This is the primary safety net — runs
      // on every startup after both inventory and enrichment cache are
      // populated. Catches ALL edge cases: items from before this fix,
      // missed onEnriched callbacks, race conditions, etc.
      _backfillAllMissingAffixes(
        ref: ref,
        enrichmentCache: enrichmentCache,
        statsService: coordinator.statsService,
        itemRepo: itemRepo,
        queueProcessor: queueProcessor,
        userId: userId,
      );
    }).catchError((Object e) {
      debugPrint('[GameCoordinator] hydration chain failed '
          '(starting loop anyway): $e');
    }).whenComplete(() {
      startLoop();
    });
  }

  // --- Auth state handler ---
  //
  // Called on initial provider creation (for the case where auth is already
  // authenticated before this provider is first accessed) and on every future
  // auth state transition via ref.listen.

  void handleAuthState(AuthState authState) {
    final userId = authState.user?.id;
    if (authState.status == AuthStatus.authenticated && userId != null) {
      if (userId == lastHydratedUserId) return; // Already hydrated — no-op.
      lastHydratedUserId = userId;
      coordinator.setCurrentUserId(userId);
      hydrateAndStart(userId);
    } else if (authState.status == AuthStatus.unauthenticated) {
      coordinator.setCurrentUserId(null);
      lastHydratedUserId = null;
      ref.read(playerProvider.notifier).loadProfile(
            cellsObserved: 0,
            totalDistanceKm: 0.0,
            currentStreak: 0,
            longestStreak: 0,
            hasCompletedOnboarding: false, // explicit reset on sign-out
          );
      ref.read(inventoryProvider.notifier).loadItems([]);
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

    _persistProfileState(
      userId: userId,
      playerState: next,
      profileRepo: profileRepo,
      queueProcessor: queueProcessor,
      lastLat: currentPos?.lat,
      lastLon: currentPos?.lon,
    );
  });

  // --- Cleanup ---

  ref.onDispose(() {
    coordinator.dispose();
    queueProcessor.dispose();
    locationService.stop();
  });

  return coordinator;
});

// =============================================================================
// Private helpers — fire-and-forget persistence + queue enqueue
// =============================================================================

const _uuid = Uuid();

/// Persist an item discovery to SQLite and enqueue for Supabase sync.
Future<void> _persistItemDiscovery({
  required ItemInstance instance,
  required String userId,
  required ItemInstanceRepository itemRepo,
  required QueueProcessor queueProcessor,
}) async {
  // 1. Write to SQLite (local cache).
  try {
    await itemRepo.addItem(instance, userId);
  } catch (e) {
    debugPrint('[GameCoordinator] failed to persist item: $e');
  }

  // 2. Enqueue for Supabase sync (auto-schedules flush).
  try {
    final payload = jsonEncode({
      'id': instance.id,
      'definition_id': instance.definitionId,
      'display_name': instance.displayName,
      'scientific_name': instance.scientificName,
      'category_name': instance.category.name,
      'rarity_name': instance.rarity?.name,
      'habitats_json': instance.habitatsToJson(),
      'continents_json': instance.continentsToJson(),
      'taxonomic_class': instance.taxonomicClass,
      'affixes': instance.affixesToJson(),
      'badges_json': instance.badgesToJson(),
      'parent_a_id': instance.parentAId,
      'parent_b_id': instance.parentBId,
      'acquired_at': instance.acquiredAt.toIso8601String(),
      'acquired_in_cell_id': instance.acquiredInCellId,
      'daily_seed': instance.dailySeed,
      'status': instance.status.name,
    });

    await queueProcessor.enqueue(
      entityType: WriteQueueEntityType.itemInstance,
      entityId: instance.id,
      operation: WriteQueueOperation.upsert,
      payload: payload,
      userId: userId,
    );
  } catch (e) {
    debugPrint('[GameCoordinator] failed to enqueue item: $e');
  }
}

/// Persist a cell visit to SQLite and enqueue for Supabase sync.
Future<void> _persistCellVisit({
  required String cellId,
  required String userId,
  required CellProgressRepository cellProgressRepo,
  required QueueProcessor queueProcessor,
}) async {
  final now = DateTime.now();
  int visitCount = 1;
  double distanceWalked = 0.0;
  double restorationLevel = 0.0;

  // 1. Upsert cell progress in SQLite (create if first visit, update if returning).
  try {
    final existing = await cellProgressRepo.read(userId, cellId);
    if (existing != null) {
      // Returning visit — increment visit count. Use current DB values for payload.
      await cellProgressRepo.incrementVisitCount(userId, cellId);
      visitCount = existing.visitCount + 1;
      distanceWalked = existing.distanceWalked;
      restorationLevel = existing.restorationLevel;
    } else {
      // First visit — create new record.
      final progressId = _uuid.v4();
      await cellProgressRepo.create(
        id: progressId,
        userId: userId,
        cellId: cellId,
        fogState: FogState.observed,
        visitCount: 1,
        lastVisited: now,
      );
    }
  } catch (e) {
    debugPrint('[GameCoordinator] failed to persist cell visit: $e');
  }

  // 2. Enqueue for Supabase sync (auto-schedules flush).
  try {
    final payload = jsonEncode({
      'cell_id': cellId,
      'fog_state': FogState.observed.name,
      'visit_count': visitCount,
      'distance_walked': distanceWalked,
      'restoration_level': restorationLevel,
      'last_visited': now.toIso8601String(),
    });

    await queueProcessor.enqueue(
      entityType: WriteQueueEntityType.cellProgress,
      entityId: '$userId:$cellId',
      operation: WriteQueueOperation.upsert,
      payload: payload,
      userId: userId,
    );
  } catch (e) {
    debugPrint('[GameCoordinator] failed to enqueue cell visit: $e');
  }
}

/// Persist player profile state to SQLite and enqueue for Supabase sync.
///
/// Called whenever [PlayerNotifier] state changes (cells observed, distance,
/// streaks). Fire-and-forget — errors are logged but don't crash the UI.
///
/// [lastLat] and [lastLon] are the player's current position, saved so the
/// next session can restore from their last known location.
Future<void> _persistProfileState({
  required String userId,
  required PlayerState playerState,
  required ProfileRepository profileRepo,
  required QueueProcessor queueProcessor,
  double? lastLat,
  double? lastLon,
}) async {
  final season = Season.fromDate(DateTime.now());

  // 1. Persist to SQLite.
  try {
    final existing = await profileRepo.read(userId);
    if (existing != null) {
      await profileRepo.update(
        userId: userId,
        currentStreak: playerState.currentStreak,
        longestStreak: playerState.longestStreak,
        totalDistanceKm: playerState.totalDistanceKm,
        currentSeason: season.name,
        hasCompletedOnboarding: playerState.hasCompletedOnboarding,
        lastLat: lastLat,
        lastLon: lastLon,
        updateLastPosition: lastLat != null && lastLon != null,
      );
    } else {
      await profileRepo.create(
        userId: userId,
        displayName: 'Explorer',
        currentStreak: playerState.currentStreak,
        longestStreak: playerState.longestStreak,
        totalDistanceKm: playerState.totalDistanceKm,
        currentSeason: season.name,
        hasCompletedOnboarding: playerState.hasCompletedOnboarding,
        lastLat: lastLat,
        lastLon: lastLon,
      );
    }
  } catch (e) {
    debugPrint('[GameCoordinator] failed to persist profile: $e');
  }

  // 2. Enqueue for Supabase sync (auto-schedules flush).
  try {
    final payload = jsonEncode({
      'display_name': 'Explorer',
      'current_streak': playerState.currentStreak,
      'longest_streak': playerState.longestStreak,
      'total_distance_km': playerState.totalDistanceKm,
      'current_season': season.name,
      'has_completed_onboarding': playerState.hasCompletedOnboarding,
      if (lastLat != null) 'last_lat': lastLat,
      if (lastLon != null) 'last_lon': lastLon,
    });

    await queueProcessor.enqueue(
      entityType: WriteQueueEntityType.profile,
      entityId: userId,
      operation: WriteQueueOperation.upsert,
      payload: payload,
      userId: userId,
    );
  } catch (e) {
    debugPrint('[GameCoordinator] failed to enqueue profile: $e');
  }
}

/// Fetch player data from Supabase and populate local SQLite cache.
///
/// On web, IndexedDB-backed SQLite may lose data between sessions. This
/// step pulls the authoritative server state into the local cache so the
/// existing [rehydrateData] path (which reads from SQLite) has fresh data.
///
/// Gracefully handles:
/// - Supabase not configured ([persistence] is null) → no-op
/// - Network errors → logs and continues (SQLite-only fallback)
/// - Empty server data → no-op (fresh account)
@visibleForTesting
Future<void> hydrateFromSupabase({
  required String userId,
  required SupabasePersistence? persistence,
  required ProfileRepository profileRepo,
  required CellProgressRepository cellProgressRepo,
  required ItemInstanceRepository itemRepo,
  required EnrichmentRepository enrichmentRepo,
}) async {
  if (persistence == null) {
    debugPrint('[GameCoordinator] Supabase not configured — skipping '
        'server hydration');
    return;
  }

  try {
    debugPrint('[GameCoordinator] hydrating from Supabase for $userId...');

    // Fetch all data in parallel.
    final results = await Future.wait<Object?>([
      persistence.fetchProfile(userId),
      persistence.fetchCellProgress(userId),
      persistence.fetchItemInstances(userId),
      persistence.fetchEnrichments(),
    ]);

    final profileMap = results[0] as Map<String, dynamic>?;
    final cellRows = results[1]! as List<Map<String, dynamic>>;
    final itemRows = results[2]! as List<Map<String, dynamic>>;
    final enrichmentRows = results[3]! as List<Map<String, dynamic>>;

    // 1. Profile → SQLite
    if (profileMap != null) {
      await profileRepo.create(
        userId: userId,
        displayName: profileMap['display_name'] as String? ?? 'Explorer',
        currentStreak: profileMap['current_streak'] as int? ?? 0,
        longestStreak: profileMap['longest_streak'] as int? ?? 0,
        totalDistanceKm:
            (profileMap['total_distance_km'] as num?)?.toDouble() ?? 0.0,
        currentSeason: profileMap['current_season'] as String? ?? 'summer',
        hasCompletedOnboarding:
            profileMap['has_completed_onboarding'] as bool? ?? false,
      );
    }

    // 2. Cell progress → SQLite (upsert each row)
    for (final row in cellRows) {
      final cellId = row['cell_id'] as String;
      final id = row['id'] as String? ?? '${userId}_$cellId';
      final fogState =
          FogState.fromString(row['fog_state'] as String? ?? 'observed');
      final visitCount = row['visit_count'] as int? ?? 1;
      final distanceWalked =
          (row['distance_walked'] as num?)?.toDouble() ?? 0.0;
      final restorationLevel =
          (row['restoration_level'] as num?)?.toDouble() ?? 0.0;
      final lastVisitedStr = row['last_visited'] as String?;
      final lastVisited =
          lastVisitedStr != null ? DateTime.tryParse(lastVisitedStr) : null;

      await cellProgressRepo.create(
        id: id,
        userId: userId,
        cellId: cellId,
        fogState: fogState,
        distanceWalked: distanceWalked,
        visitCount: visitCount,
        restorationLevel: restorationLevel,
        lastVisited: lastVisited,
      );
    }

    // 3. Item instances → SQLite (upsert each row)
    for (final row in itemRows) {
      final acquiredAtStr = row['acquired_at'] as String?;
      final acquiredAt = acquiredAtStr != null
          ? DateTime.parse(acquiredAtStr)
          : DateTime.now();

      final instance = ItemInstance(
        id: row['id'] as String,
        definitionId: row['definition_id'] as String,
        displayName: row['display_name'] as String? ?? '',
        scientificName: row['scientific_name'] as String?,
        category: ItemCategory.values.firstWhere(
          (c) => c.name == (row['category_name'] as String? ?? 'fauna'),
          orElse: () => ItemCategory.fauna,
        ),
        rarity: row['rarity_name'] != null
            ? IucnStatus.values.firstWhere(
                (r) => r.name == row['rarity_name'],
                orElse: () => IucnStatus.leastConcern,
              )
            : null,
        habitats:
            ItemInstance.habitatsFromJson(row['habitats_json'] as String?),
        continents:
            ItemInstance.continentsFromJson(row['continents_json'] as String?),
        taxonomicClass: row['taxonomic_class'] as String?,
        affixes:
            ItemInstance.affixesFromJson(row['affixes'] as String? ?? '[]'),
        badges:
            ItemInstance.badgesFromJson(row['badges_json'] as String? ?? '[]'),
        acquiredAt: acquiredAt,
        acquiredInCellId: row['acquired_in_cell_id'] as String?,
        dailySeed: row['daily_seed'] as String?,
        parentAId: row['parent_a_id'] as String?,
        parentBId: row['parent_b_id'] as String?,
        status:
            ItemInstanceStatus.fromString(row['status'] as String? ?? 'active'),
      );

      try {
        await itemRepo.addItem(instance, userId);
      } catch (_) {
        // Item may already exist locally — that's OK (duplicate PK).
        // The server data is authoritative but we don't want to crash
        // on a duplicate insert.
      }
    }

    // 4. Enrichments → SQLite
    for (final row in enrichmentRows) {
      try {
        final enrichedAtStr = row['enriched_at'] as String?;
        final enrichedAt = enrichedAtStr != null
            ? DateTime.parse(enrichedAtStr)
            : DateTime.now();

        // Parse optional size (may be null for enrichments created before
        // the size field was added).
        final sizeStr = row['size'] as String?;
        AnimalSize? size;
        if (sizeStr != null) {
          try {
            size = AnimalSize.fromString(sizeStr);
          } catch (_) {
            // Unknown size value — leave null.
          }
        }

        final enrichment = SpeciesEnrichment(
          definitionId: row['definition_id'] as String,
          animalClass: AnimalClass.values.firstWhere(
            (c) => c.name == row['animal_class'],
            orElse: () => AnimalClass.carnivore,
          ),
          foodPreference: FoodType.values.firstWhere(
            (f) => f.name == row['food_preference'],
            orElse: () => FoodType.critter,
          ),
          climate: Climate.values.firstWhere(
            (c) => c.name == row['climate'],
            orElse: () => Climate.temperate,
          ),
          brawn: row['brawn'] as int? ?? 30,
          wit: row['wit'] as int? ?? 30,
          speed: row['speed'] as int? ?? 30,
          size: size,
          artUrl: row['art_url'] as String?,
          enrichedAt: enrichedAt,
        );
        await enrichmentRepo.upsertEnrichment(enrichment);
      } catch (e) {
        debugPrint('[GameCoordinator] failed to hydrate enrichment: $e');
      }
    }

    debugPrint('[GameCoordinator] Supabase hydration complete: '
        'profile=${profileMap != null}, '
        'cells=${cellRows.length}, '
        'items=${itemRows.length}, '
        'enrichments=${enrichmentRows.length}');
  } catch (e) {
    // Network error, Supabase down, etc. — continue with SQLite-only.
    debugPrint('[GameCoordinator] Supabase hydration failed (continuing '
        'with local data): $e');
  }
}

/// Check if an item needs intrinsic affix backfill.
///
/// Returns true when EITHER:
/// - Item has no intrinsic affix at all (needs stats + weight)
/// - Item has intrinsic affix but lacks weight AND enrichment now has size
///   (was enriched before size field was added, needs weight rolled)
bool _needsIntrinsicBackfill(
  ItemInstance item,
  ({int speed, int brawn, int wit, AnimalSize? size}) enrichedStats,
) {
  final intrinsic = item.affixes
      .cast<Affix?>()
      .firstWhere((a) => a!.type == AffixType.intrinsic, orElse: () => null);

  // No intrinsic affix at all — needs full backfill.
  if (intrinsic == null) return true;

  // Has intrinsic affix but enrichment now has size and item lacks weight.
  if (enrichedStats.size != null &&
      !intrinsic.values.containsKey(kWeightAffixKey)) {
    return true;
  }

  return false;
}

/// Roll an intrinsic affix for a single item and persist the update.
///
/// Shared by both the real-time [onEnriched] path and the startup sweep.
/// Updates: in-memory inventory, SQLite, and write queue.
Future<void> _rollAndPersistIntrinsicAffix({
  required ItemInstance item,
  required ({int speed, int brawn, int wit, AnimalSize? size}) enrichedStats,
  required Ref ref,
  required StatsService statsService,
  required ItemInstanceRepository itemRepo,
  required QueueProcessor queueProcessor,
  required String userId,
}) async {
  final baseStats = (
    speed: enrichedStats.speed,
    brawn: enrichedStats.brawn,
    wit: enrichedStats.wit,
  );
  final intrinsic = statsService.rollIntrinsicAffix(
    scientificName: item.scientificName ?? '',
    instanceSeed: item.id,
    enrichedBaseStats: baseStats,
  );

  // If size is known, roll a deterministic weight and merge into affix.
  Affix finalAffix;
  final size = enrichedStats.size;
  if (size != null) {
    final weightGrams = statsService.rollWeightGrams(
      size: size,
      instanceSeed: item.id,
    );
    finalAffix = Affix(
      id: intrinsic.id,
      type: intrinsic.type,
      values: {
        ...intrinsic.values,
        kSizeAffixKey: size.name,
        kWeightAffixKey: weightGrams,
      },
    );
  } else {
    finalAffix = intrinsic;
  }

  // Replace existing intrinsic affix if present (e.g., re-enrichment added
  // size to a previously stats-only affix), otherwise prepend new one.
  final existingIntrinsic =
      item.affixes.any((a) => a.type == AffixType.intrinsic);
  final List<Affix> newAffixes;
  if (existingIntrinsic) {
    newAffixes = item.affixes
        .map((a) => a.type == AffixType.intrinsic ? finalAffix : a)
        .toList();
  } else {
    newAffixes = [finalAffix, ...item.affixes];
  }

  final updated = item.copyWith(
    affixes: newAffixes,
  );

  // 1. Update in-memory inventory.
  ref.read(inventoryProvider.notifier).updateItem(updated);

  // 2. Persist to SQLite.
  try {
    await itemRepo.updateItem(updated, userId);
  } catch (e) {
    debugPrint('[GameCoordinator] failed to persist backfilled item '
        '${item.id}: $e');
  }

  // 3. Enqueue for Supabase sync.
  try {
    final payload = jsonEncode({
      'id': updated.id,
      'definition_id': updated.definitionId,
      'display_name': updated.displayName,
      'scientific_name': updated.scientificName,
      'category_name': updated.category.name,
      'rarity_name': updated.rarity?.name,
      'habitats_json': updated.habitatsToJson(),
      'continents_json': updated.continentsToJson(),
      'taxonomic_class': updated.taxonomicClass,
      'affixes': updated.affixesToJson(),
      'badges_json': updated.badgesToJson(),
      'parent_a_id': updated.parentAId,
      'parent_b_id': updated.parentBId,
      'acquired_at': updated.acquiredAt.toIso8601String(),
      'acquired_in_cell_id': updated.acquiredInCellId,
      'daily_seed': updated.dailySeed,
      'status': updated.status.name,
    });

    await queueProcessor.enqueue(
      entityType: WriteQueueEntityType.itemInstance,
      entityId: updated.id,
      operation: WriteQueueOperation.upsert,
      payload: payload,
      userId: userId,
    );
  } catch (e) {
    debugPrint('[GameCoordinator] failed to enqueue backfilled item '
        '${item.id}: $e');
  }
}

/// Retroactively roll intrinsic affixes for items of a single species.
///
/// Called by [onEnriched] when a new enrichment arrives in-session.
Future<void> _backfillIntrinsicAffixes({
  required String definitionId,
  required ({int speed, int brawn, int wit, AnimalSize? size}) enrichedStats,
  required Ref ref,
  required StatsService statsService,
  required ItemInstanceRepository itemRepo,
  required QueueProcessor queueProcessor,
  required String userId,
}) async {
  final inventory = ref.read(inventoryProvider);
  final itemsToFix = inventory.items
      .where((item) =>
          item.definitionId == definitionId &&
          _needsIntrinsicBackfill(item, enrichedStats))
      .toList();

  if (itemsToFix.isEmpty) return;

  debugPrint('[GameCoordinator] backfilling intrinsic affixes for '
      '${itemsToFix.length} items of $definitionId');

  for (final item in itemsToFix) {
    await _rollAndPersistIntrinsicAffix(
      item: item,
      enrichedStats: enrichedStats,
      ref: ref,
      statsService: statsService,
      itemRepo: itemRepo,
      queueProcessor: queueProcessor,
      userId: userId,
    );
  }
}

/// Startup sweep: backfill intrinsic affixes for ALL items in inventory
/// where enrichment data exists but the item has no intrinsic affix.
///
/// This is the primary safety net — runs on every startup after both
/// inventory and enrichment cache are populated. Catches:
///   - Items discovered before this fix was deployed
///   - Missed onEnriched callbacks (app crash, race conditions)
///   - Items hydrated from Supabase that were created without affixes
///   - Any other edge case where enrichment exists but stats don't
Future<void> _backfillAllMissingAffixes({
  required Ref ref,
  required Map<String, ({int speed, int brawn, int wit, AnimalSize? size})>
      enrichmentCache,
  required StatsService statsService,
  required ItemInstanceRepository itemRepo,
  required QueueProcessor queueProcessor,
  required String userId,
}) async {
  try {
    final inventory = ref.read(inventoryProvider);
    final itemsToFix = inventory.items
        .where((item) =>
            enrichmentCache.containsKey(item.definitionId) &&
            _needsIntrinsicBackfill(item, enrichmentCache[item.definitionId]!))
        .toList();

    if (itemsToFix.isEmpty) return;

    debugPrint('[GameCoordinator] startup backfill: ${itemsToFix.length} '
        'items need intrinsic affix update');

    for (final item in itemsToFix) {
      await _rollAndPersistIntrinsicAffix(
        item: item,
        enrichedStats: enrichmentCache[item.definitionId]!,
        ref: ref,
        statsService: statsService,
        itemRepo: itemRepo,
        queueProcessor: queueProcessor,
        userId: userId,
      );
    }

    debugPrint('[GameCoordinator] startup backfill complete: '
        '${itemsToFix.length} items fixed');
  } catch (e) {
    debugPrint('[GameCoordinator] startup backfill failed: $e');
  }
}

/// Re-queue enrichment requests for fauna in inventory that lack enrichment
/// or have incomplete enrichment (e.g., enriched before size field was added).
///
/// Covers species that were dropped due to rate limits, app restarts (in-memory
/// queue lost), pipeline changes, or new enrichment fields added after initial
/// enrichment. Waits for species data to load, then compares inventory fauna
/// against the enrichment cache.
Future<void> _requeueUnenrichedSpecies({
  required Ref ref,
  required Map<String, ({int speed, int brawn, int wit, AnimalSize? size})>
      enrichmentCache,
}) async {
  try {
    final speciesData = await ref.read(speciesDataProvider.future);
    final inventory = ref.read(inventoryProvider);
    final enrichmentService = ref.read(enrichmentServiceProvider);

    // Build lookup map for fauna definitions by ID.
    final faunaById = <String, FaunaDefinition>{};
    for (final fauna in speciesData) {
      faunaById[fauna.id] = fauna;
    }

    // Find unique fauna definition IDs in inventory that lack enrichment
    // or have incomplete enrichment (e.g., missing size from older pipeline).
    // Uses faunaById to naturally filter to fauna items only (ItemInstance
    // has no category field — the species data map is the filter).
    final unenrichedIds = <String>{};
    final incompleteIds = <String>{};
    for (final item in inventory.items) {
      if (!faunaById.containsKey(item.definitionId)) continue;

      if (!enrichmentCache.containsKey(item.definitionId)) {
        unenrichedIds.add(item.definitionId);
      } else if (enrichmentCache[item.definitionId]!.size == null) {
        incompleteIds.add(item.definitionId);
      }
    }

    final allIds = {...unenrichedIds, ...incompleteIds};

    // Queue enrichment requests for the gap set.
    for (final defId in allIds) {
      final fauna = faunaById[defId]!;
      enrichmentService.requestEnrichment(
        definitionId: fauna.id,
        scientificName: fauna.scientificName,
        commonName: fauna.displayName,
        taxonomicClass: fauna.taxonomicClass,
      );
    }

    if (unenrichedIds.isNotEmpty) {
      debugPrint('[GameCoordinator] re-queued ${unenrichedIds.length} '
          'unenriched species for enrichment');
    }
    if (incompleteIds.isNotEmpty) {
      debugPrint('[GameCoordinator] re-queued ${incompleteIds.length} '
          'species with incomplete enrichment (missing size)');
    }
  } catch (e) {
    debugPrint('[GameCoordinator] failed to re-queue unenriched species: $e');
  }
}
