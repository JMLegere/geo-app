import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geobase/geobase.dart';
import 'package:uuid/uuid.dart';

import 'package:fog_of_world/core/database/app_database.dart';
import 'package:fog_of_world/core/game/game_coordinator.dart';
import 'package:fog_of_world/core/models/fog_state.dart';
import 'package:fog_of_world/core/models/item_definition.dart';
import 'package:fog_of_world/core/models/item_instance.dart';
import 'package:fog_of_world/core/models/season.dart';
import 'package:fog_of_world/core/models/write_queue_entry.dart';
import 'package:fog_of_world/core/persistence/cell_progress_repository.dart';
import 'package:fog_of_world/core/persistence/item_instance_repository.dart';
import 'package:fog_of_world/core/persistence/profile_repository.dart';
import 'package:fog_of_world/core/persistence/write_queue_repository.dart';
import 'package:fog_of_world/core/species/stats_service.dart';
import 'package:fog_of_world/shared/constants.dart';
import 'package:fog_of_world/core/state/cell_progress_repository_provider.dart';
import 'package:fog_of_world/core/state/daily_seed_provider.dart';
import 'package:fog_of_world/core/state/fog_resolver_provider.dart';
import 'package:fog_of_world/core/state/inventory_provider.dart';
import 'package:fog_of_world/core/state/item_instance_repository_provider.dart';
import 'package:fog_of_world/core/state/location_provider.dart';
import 'package:fog_of_world/core/state/player_provider.dart';
import 'package:fog_of_world/core/state/profile_repository_provider.dart';
import 'package:fog_of_world/core/state/write_queue_repository_provider.dart';
import 'package:fog_of_world/features/auth/models/auth_state.dart';
import 'package:fog_of_world/features/auth/providers/auth_provider.dart';
import 'package:fog_of_world/features/discovery/providers/discovery_provider.dart';
import 'package:fog_of_world/features/enrichment/providers/enrichment_provider.dart';
import 'package:fog_of_world/features/location/services/location_service.dart';
import 'package:fog_of_world/features/location/services/location_simulator.dart';
import 'package:fog_of_world/features/location/services/real_gps_service.dart';
import 'package:fog_of_world/features/map/providers/discovery_service_provider.dart';
import 'package:fog_of_world/features/map/providers/location_service_provider.dart';

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
  final writeQueueRepo = ref.watch(writeQueueRepositoryProvider);

  final coordinator = GameCoordinator(
    fogResolver: fogResolver,
    statsService: const StatsService(),
    isRealGps: locationService.mode == LocationMode.realGps,
  );

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
        writeQueueRepo: writeQueueRepo,
      );
    }
  };

  coordinator.onItemDiscovered = (event, instance) {
    // Check if this is the first instance of this species in the player's
    // inventory. If so, award the first-discovery badge (shiny foil).
    final inventory = ref.read(inventoryProvider);
    final isFirst = !inventory.hasDefinition(instance.definitionId);
    final badgedInstance = isFirst
        ? instance.copyWith(badges: {...instance.badges, kBadgeFirstDiscovery})
        : instance;

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
        writeQueueRepo: writeQueueRepo,
      );
    }

    // Fire enrichment request for fauna items (fire-and-forget).
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
          .catchError((Object e) {
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

  void hydrateAndStart(String userId) {
    Future.wait<Object?>([
      itemRepo.getItemsByUser(userId),
      cellProgressRepo.readByUser(userId),
      profileRepo.read(userId),
    ]).then((results) {
      final items = results[0]! as List<ItemInstance>;
      final cellRows = results[1]! as List<LocalCellProgress>;
      final profile = results[2] as LocalPlayerProfile?;

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

      if (profile != null) {
        ref.read(playerProvider.notifier).loadProfile(
              cellsObserved: cellsObserved,
              totalDistanceKm: profile.totalDistanceKm,
              currentStreak: profile.currentStreak,
              longestStreak: profile.longestStreak,
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

      startLoop();
    }).catchError((Object e) {
      debugPrint('[GameCoordinator] failed to hydrate: $e');
      startLoop(); // Degrade gracefully — start without hydrated data.
    });
  }

  // Auth initializes asynchronously (awaits Supabase bootstrap, then
  // auto-signs-in). userId may be null here if auth hasn't settled yet.
  final authState = ref.read(authProvider);
  final userId = authState.user?.id;

  if (userId != null) {
    // Auth already settled — hydrate then start.
    hydrateAndStart(userId);
  } else {
    // Auth still loading — listen for it to settle, then hydrate + start.
    var started = false;
    ref.listen<AuthState>(authProvider, (_, next) {
      if (started) return;
      final id = next.user?.id;
      if (id != null) {
        started = true;
        hydrateAndStart(id);
      } else if (next.status == AuthStatus.unauthenticated) {
        // Auth settled but no user — start without hydration.
        started = true;
        startLoop();
      }
    });
  }

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

    _persistProfileState(
      userId: userId,
      playerState: next,
      profileRepo: profileRepo,
      writeQueueRepo: writeQueueRepo,
    );
  });

  // --- Cleanup ---

  ref.onDispose(() {
    coordinator.dispose();
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
  required WriteQueueRepository writeQueueRepo,
}) async {
  // 1. Write to SQLite (local cache).
  try {
    await itemRepo.addItem(instance, userId);
  } catch (e) {
    debugPrint('[GameCoordinator] failed to persist item: $e');
  }

  // 2. Enqueue for Supabase sync.
  try {
    final payload = jsonEncode({
      'id': instance.id,
      'definition_id': instance.definitionId,
      'affixes': instance.affixesToJson(),
      'parent_a_id': instance.parentAId,
      'parent_b_id': instance.parentBId,
      'acquired_at': instance.acquiredAt.toIso8601String(),
      'acquired_in_cell_id': instance.acquiredInCellId,
      'daily_seed': instance.dailySeed,
      'status': instance.status.name,
    });

    await writeQueueRepo.enqueue(
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
  required WriteQueueRepository writeQueueRepo,
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

  // 2. Enqueue for Supabase sync with current DB state.
  try {
    final payload = jsonEncode({
      'cell_id': cellId,
      'fog_state': FogState.observed.name,
      'visit_count': visitCount,
      'distance_walked': distanceWalked,
      'restoration_level': restorationLevel,
      'last_visited': now.toIso8601String(),
    });

    await writeQueueRepo.enqueue(
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
Future<void> _persistProfileState({
  required String userId,
  required PlayerState playerState,
  required ProfileRepository profileRepo,
  required WriteQueueRepository writeQueueRepo,
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
      );
    } else {
      await profileRepo.create(
        userId: userId,
        displayName: 'Explorer',
        currentStreak: playerState.currentStreak,
        longestStreak: playerState.longestStreak,
        totalDistanceKm: playerState.totalDistanceKm,
        currentSeason: season.name,
      );
    }
  } catch (e) {
    debugPrint('[GameCoordinator] failed to persist profile: $e');
  }

  // 2. Enqueue for Supabase sync.
  try {
    final payload = jsonEncode({
      'display_name': 'Explorer',
      'current_streak': playerState.currentStreak,
      'longest_streak': playerState.longestStreak,
      'total_distance_km': playerState.totalDistanceKm,
      'current_season': season.name,
    });

    await writeQueueRepo.enqueue(
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
