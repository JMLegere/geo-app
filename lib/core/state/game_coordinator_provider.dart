import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geobase/geobase.dart';

import 'package:fog_of_world/core/game/game_coordinator.dart';
import 'package:fog_of_world/core/species/stats_service.dart';
import 'package:fog_of_world/core/state/fog_resolver_provider.dart';
import 'package:fog_of_world/core/state/inventory_provider.dart';
import 'package:fog_of_world/core/state/item_instance_repository_provider.dart';
import 'package:fog_of_world/core/state/location_provider.dart';
import 'package:fog_of_world/core/state/player_provider.dart';
import 'package:fog_of_world/features/auth/models/auth_state.dart';
import 'package:fog_of_world/features/auth/providers/auth_provider.dart';
import 'package:fog_of_world/features/discovery/providers/discovery_provider.dart';
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
/// 4. Starts the game loop
/// 5. Disposes on provider invalidation
final gameCoordinatorProvider = Provider<GameCoordinator>((ref) {
  final fogResolver = ref.watch(fogResolverProvider);
  final locationService = ref.watch(locationServiceProvider);
  final discoveryService = ref.watch(discoveryServiceProvider);
  final itemRepo = ref.watch(itemInstanceRepositoryProvider);

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

  coordinator.onCellVisited = () {
    ref.read(playerProvider.notifier).incrementCellsObserved();
  };

  coordinator.onItemDiscovered = (event, instance) {
    ref.read(discoveryProvider.notifier).showDiscovery(event);
    ref.read(inventoryProvider.notifier).addItem(instance);
    discoveryService.markCollected(instance.definitionId);

    // Persist to SQLite (fire-and-forget — don't block the game loop).
    // TODO(T-writequeue): Retry failed writes via write queue (Phase 3).
    final userId = ref.read(authProvider).user?.id;
    if (userId != null) {
      itemRepo.addItem(instance, userId).catchError((Object e) {
        debugPrint('[GameCoordinator] failed to persist item: $e');
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
      GpsPermissionStatus.serviceDisabled => GpsPermissionResult.serviceDisabled,
    };
  };

  // --- Map LocationService stream → core stream type ---

  final gpsStream = locationService.filteredLocationStream.map(
    (SimulatedLocation loc) => (position: loc.position, accuracy: loc.accuracy),
  );

  // --- Hydrate inventory then start game loop ---
  //
  // CRITICAL: loadItems() replaces inventory state, so the game loop must NOT
  // start until hydration completes. Otherwise a discovery that fires during
  // the race window would be wiped by loadItems(). We start the loop inside
  // the hydration callback (or immediately when no auth / on error).

  void startLoop() {
    locationService.start();
    coordinator.start(
      gpsStream: gpsStream,
      discoveryStream: discoveryService.onDiscovery,
    );
  }

  void hydrateAndStart(String userId) {
    itemRepo.getItemsByUser(userId).then((items) {
      if (items.isNotEmpty) {
        ref.read(inventoryProvider.notifier).loadItems(items);
        // Seed DiscoveryService with already-collected definition IDs so
        // isNew is correct for species the player already has.
        for (final item in items) {
          discoveryService.markCollected(item.definitionId);
        }
      }
      startLoop();
    }).catchError((Object e) {
      debugPrint('[GameCoordinator] failed to hydrate inventory: $e');
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

  // --- Cleanup ---

  ref.onDispose(() {
    coordinator.dispose();
    locationService.stop();
  });

  return coordinator;
});
