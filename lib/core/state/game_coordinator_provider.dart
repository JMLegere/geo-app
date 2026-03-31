import 'dart:async';
import 'dart:convert';
import 'dart:io' as io show Platform;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geobase/geobase.dart';

import 'package:earth_nova/core/database/app_database.dart';
import 'package:earth_nova/core/database/connection.dart';
import 'package:earth_nova/core/engine/engine_runner.dart';
import 'package:earth_nova/core/services/log_flush_service.dart';
import 'package:earth_nova/core/services/observability_buffer.dart';
import 'package:earth_nova/core/services/startup_beacon.dart';
import 'package:earth_nova/core/engine/game_engine.dart';
import 'package:earth_nova/core/engine/main_thread_engine_runner.dart';
import 'package:earth_nova/core/engine/game_coordinator.dart';
import 'package:earth_nova/core/state/cell_service_provider.dart';
import 'package:earth_nova/core/models/animal_size.dart';
import 'package:earth_nova/core/models/fog_state.dart';
import 'package:earth_nova/core/models/item_category.dart';
import 'package:earth_nova/core/models/item_instance.dart';
import 'package:earth_nova/core/models/cell_properties.dart';
import 'package:earth_nova/features/items/services/stats_service.dart';
import 'package:earth_nova/core/state/app_database_provider.dart';
import 'package:earth_nova/core/state/cell_progress_repository_provider.dart';
import 'package:earth_nova/core/state/cell_property_repository_provider.dart';
import 'package:earth_nova/features/world/services/cell_property_resolver.dart';
import 'package:earth_nova/core/state/cell_property_resolver_provider.dart';
import 'package:earth_nova/core/state/zone_ready_provider.dart';
import 'package:earth_nova/core/state/daily_seed_provider.dart';
import 'package:earth_nova/core/state/fog_resolver_provider.dart';
import 'package:earth_nova/features/map/providers/fog_overlay_controller_provider.dart';
import 'package:earth_nova/features/items/providers/items_provider.dart';
import 'package:earth_nova/core/state/item_instance_repository_provider.dart';
import 'package:earth_nova/core/state/location_provider.dart';
import 'package:earth_nova/core/state/player_provider.dart';
import 'package:earth_nova/core/state/profile_repository_provider.dart';
import 'package:earth_nova/core/state/persistence_consumer.dart';
import 'package:earth_nova/features/auth/models/auth_state.dart';
import 'package:earth_nova/features/auth/providers/auth_provider.dart';
import 'package:earth_nova/features/discovery/providers/discovery_provider.dart';
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

import 'package:earth_nova/shared/constants.dart';
import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/state/affix_backfill.dart';
import 'package:earth_nova/core/species/species_cache.dart';
import 'package:earth_nova/core/state/detection_zone_provider.dart';
import 'package:earth_nova/core/state/location_node_repository_provider.dart';
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
  StartupBeacon.emit('provider_init');
  final fogResolver = ref.watch(fogResolverProvider);
  final cellService = ref.watch(cellServiceProvider);
  final locationService = ref.watch(locationServiceProvider);
  final discoveryService = ref.watch(discoveryServiceProvider);
  final itemRepo = ref.watch(itemInstanceRepositoryProvider);
  final cellProgressRepo = ref.watch(cellProgressRepositoryProvider);
  final profileRepo = ref.watch(profileRepositoryProvider);
  final queueProcessor = ref.watch(queueProcessorProvider);

  final cellPropertyResolver = ref.read(cellPropertyResolverProvider);
  final cellPropertyRepo = ref.watch(cellPropertyRepositoryProvider);

  // Structured event telemetry — thin debugPrint wrapper.
  // Events flow through DebugLogBuffer → LogFlushService → app_logs.
  final supabaseClient = ref.read(supabaseClientProvider);
  final obs = ObservabilityBuffer();
  ObservabilityBuffer.instance = obs;

  // Debug log flush — ships DebugLogBuffer text to app_logs table.
  // Debounced: 5s after first line, no fixed timer when idle.
  if (supabaseClient != null) {
    final logFlush = LogFlushService(
      flusher: (row) => supabaseClient.from('app_logs').insert(row),
    );
    logFlush.sessionId = obs.sessionId;
    logFlush.deviceId = obs.deviceId;
    LogFlushService.instance = logFlush;
    ref.onDispose(() {
      logFlush.flush(); // best-effort drain before teardown
      logFlush.dispose();
      LogFlushService.instance = null;
    });
  }

  // ── Startup diagnostics ──────────────────────────────────────────────────
  // Log comprehensive device/app/session info on every cold start.
  // Useful for debugging user-reported issues — never know what helps.
  () async {
    try {
      final db = ref.read(appDatabaseProvider);
      // Single query for all startup counts — avoids 5 sequential COUNT(*)
      // queries that each block the main thread (~50ms each on web).
      final counts = await db.customSelect('''
        SELECT
          (SELECT COUNT(*) FROM local_species_table) AS species_total,
          (SELECT COUNT(*) FROM local_item_instance_table) AS item_total,
          (SELECT COUNT(*) FROM local_cell_progress_table) AS cell_total,
          (SELECT COUNT(*) FROM local_species_table WHERE animal_class IS NOT NULL) AS enriched_total,
          (SELECT COUNT(*) FROM local_species_table WHERE icon_url IS NOT NULL) AS with_art_total
      ''').getSingle();
      final speciesCount = counts.read<int>('species_total');
      final itemCount = counts.read<int>('item_total');
      final cellCount = counts.read<int>('cell_total');
      final enrichedCount = counts.read<int>('enriched_total');
      final withArtCount = counts.read<int>('with_art_total');

      // Platform info — dart:io not available on web
      String platformOs = 'web';
      String platformVersion = 'browser';
      String platformLocale = 'unknown';
      String dartVersion = 'unknown';
      if (!kIsWeb) {
        try {
          platformOs = io.Platform.operatingSystem;
          platformVersion = io.Platform.operatingSystemVersion;
          platformLocale = io.Platform.localeName;
          dartVersion = io.Platform.version.split(' ').first;
        } catch (_) {}
      }

      final diagnostics = {
        // Session
        'session_id': obs.sessionId,
        'device_id': obs.deviceId,

        // App
        'app_version': '0.1.0+1',
        'schema_version': db.schemaVersion,
        'dart_version': dartVersion,

        // Platform
        'platform_os': platformOs,
        'platform_version': platformVersion,
        'platform_locale': platformLocale,
        'is_web': kIsWeb,
        'is_debug': kDebugMode,

        // Database
        'species_total': speciesCount,
        'species_enriched': enrichedCount,
        'species_with_art': withArtCount,
        'item_instances': itemCount,
        'cells_visited': cellCount,

        // Config
        'supabase_configured': supabaseClient != null,
        'location_mode': locationService.mode.name,

        // Timing
        'startup_ts': DateTime.now().toUtc().toIso8601String(),
      };

      obs.event('app_startup', diagnostics);
      debugPrint('[Startup] $diagnostics');
    } catch (e) {
      debugPrint('[Observability] startup diagnostics failed: $e');
    }
  }();

  // LocalAppEventsTable removed — trimAppEvents no longer needed.

  // Guard flag: set to true in ref.onDispose to prevent callbacks and
  // startLoop() from calling ref.read() on a dead provider reference.
  // This closes the race where .whenComplete() fires after disposal.
  var _providerDisposed = false;

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

  // Wire synchronous enrichment lookup for stat rolling (reads from species cache).
  final speciesCacheForStats = ref.read(speciesCacheProvider);
  coordinator.enrichedStatsLookup = (definitionId) {
    final def = speciesCacheForStats.getByIdSync(definitionId);
    if (def == null) {
      obs.event('enrichment_cache_miss', {'definition_id': definitionId});
      return null;
    }
    if (def.brawn == null) {
      obs.event('enrichment_not_ready', {'definition_id': definitionId});
      return null;
    }
    return (
      speed: def.speed!,
      brawn: def.brawn!,
      wit: def.wit!,
      size: def.size != null ? AnimalSize.fromString(def.size!) : null,
    );
  };

  // --- Wire auto-flush callback → post-flush badge/rejection processing ---

  queueProcessor.onAutoFlushComplete = (summary) async {
    if (_providerDisposed) return;
    obs.event('sync_flushed', {
      'confirmed': summary.confirmed,
      'rejected': summary.rejected,
      'retried': summary.retried,
      'stale_deleted': summary.staleDeleted,
    });
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

  final detectionZoneService = ref.read(detectionZoneServiceProvider);

  final engineOnLocation = coordinator.onPlayerLocationUpdate;
  coordinator.onPlayerLocationUpdate = (Geographic position, double accuracy) {
    engineOnLocation?.call(position, accuracy);
    if (_providerDisposed) return;
    ref.read(locationProvider.notifier).updateLocation(position, accuracy);
    detectionZoneService.updatePlayerPosition(position.lat, position.lon);
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

  // When enrichment resolves a locationId for a cell, update the in-memory
  // cache. Detection zone now uses radius-based expansion from GPS position.
  final locationEnrichmentSvc = ref.read(locationEnrichmentServiceProvider);

  locationEnrichmentSvc.onLocationEnriched.listen((event) async {
    if (_providerDisposed) return;

    // Update the enriched cell's in-memory cache.
    final cached = coordinator.cellPropertiesCache[event.cellId];
    if (cached != null && cached.locationId == null) {
      coordinator.updateCellPropertyLocationId(event.cellId, event.locationId);
    }
  });

  detectionZoneService.onDetectionZoneChanged.listen((zoneCellIds) {
    if (_providerDisposed) return;

    // ── Phase 1: In-memory resolution (synchronous, <50ms) ──
    // Resolve cell properties + stamp locationId into the in-memory cache
    // WITHOUT persisting to SQLite. This gives the fog overlay everything
    // it needs to render the detection zone immediately.

    fogResolver.setDetectionZone(zoneCellIds);

    // 1a. Pre-resolve cell properties into memory cache (no persist).
    final resolver = ref.read(cellPropertyResolverProvider);
    final cellsToPersist = <CellProperties>[];
    if (resolver != null) {
      for (final cellId in zoneCellIds) {
        if (coordinator.cellPropertiesCache.containsKey(cellId)) continue;
        final center = cellService.getCellCenter(cellId);
        final props = resolver.resolve(
          cellId: cellId,
          lat: center.lat,
          lon: center.lon,
        );
        coordinator.loadCellProperties({cellId: props});
        cellsToPersist.add(props);
      }
      if (cellsToPersist.isNotEmpty) {
        debugPrint('[DetectionZone] pre-resolved ${cellsToPersist.length} '
            'cell properties into memory');
      }
    }

    // 1b. Stamp locationId into memory cache (no persist).
    final attribution = detectionZoneService.cellDistrictAttribution;
    final locationIdUpdates = <CellProperties>[];
    for (final entry in attribution.entries) {
      final cellId = entry.key;
      final districtId = entry.value;
      var props = coordinator.cellPropertiesCache[cellId];
      if (props == null) continue;
      if (props.locationId == districtId) continue;

      props = props.copyWith(locationId: districtId);
      coordinator.loadCellProperties({cellId: props});
      locationIdUpdates.add(props);
    }
    if (locationIdUpdates.isNotEmpty) {
      debugPrint('[DetectionZone] stamped locationId on '
          '${locationIdUpdates.length} cells in memory');
    }

    // 1c. Feed fog overlay with fully-populated cache — triggers dirty flag
    // so the next 2Hz fog tick renders all zone cells.
    ref.read(fogOverlayControllerProvider).addDetectionZoneCells(
          zoneCellIds,
          coordinator.cellPropertiesCache,
        );

    // 1d. Warm species cache (fire-and-forget, no await needed).
    final speciesCache = ref.read(speciesCacheProvider);
    if (!speciesCache.isEmpty) {
      final seen = <String>{};
      for (final cellId in zoneCellIds) {
        final props = coordinator.cellPropertiesCache[cellId];
        if (props == null) continue;
        final key = SpeciesCache.cacheKey(props.habitats, props.continent);
        if (seen.add(key)) {
          speciesCache.warmUp(
              habitats: props.habitats, continent: props.continent);
        }
      }
    }

    debugPrint(
      '[DetectionZone] zone updated: ${zoneCellIds.length} cells, '
      'district=${detectionZoneService.currentDistrictId}',
    );

    // Signal that the detection zone is ready — dismisses loading screen.
    if (zoneCellIds.isNotEmpty && !ref.read(zoneReadyProvider)) {
      ref.read(zoneReadyProvider.notifier).markReady();
      debugPrint('[GameCoordinator] zone ready — loading screen will dismiss');
      ObservabilityBuffer.instance?.event('zone_ready', {
        'cell_count': zoneCellIds.length,
        'district': detectionZoneService.currentDistrictId,
      });
    }

    // ── Phase 2: Deferred persistence (batched microtask, ~75ms/batch) ──
    // Persist to SQLite + enqueue for Supabase in batches of 5 with yields
    // between batches. Each SQLite write takes 10-15ms on iOS IndexedDB,
    // so batches of 5 = ~75ms per batch — under the JANK threshold.
    final allToPersist = [...cellsToPersist, ...locationIdUpdates];
    if (allToPersist.isNotEmpty) {
      final userId = ref.read(authProvider).user?.id;
      Future.microtask(() async {
        var persisted = 0;
        for (var i = 0; i < allToPersist.length; i++) {
          if (_providerDisposed) return;
          await persistCellProperties(
            properties: allToPersist[i],
            cellPropertyRepo: cellPropertyRepo,
            queueProcessor: queueProcessor,
            userId: userId,
            obs: obs,
          );
          persisted++;
          // Yield every 5 writes so the UI can render frames.
          if (persisted % 5 == 0) {
            await Future<void>.delayed(Duration.zero);
          }
        }
        debugPrint('[DetectionZone] persisted $persisted cell properties '
            '(batched, ${allToPersist.length} total)');
      });
    }
  });

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
    debugPrint(
        '[DISCOVERY] provider_received instance=${instance.id} definition=${instance.definitionId}');
    if (_providerDisposed) {
      debugPrint(
          '[DISCOVERY] provider_disposed_dropped instance=${instance.id}');
      return;
    }
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
        cellProgressRepo: cellProgressRepo,
      );
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

    obs.event('game_loop_started', {
      'user_id': coordinator.currentUserId,
      'daily_seed': dailySeedService.currentSeed,
    });

    // Fetch daily seed before starting the game loop so encounters
    // have the seed available from the first cell visit.
    final previousSeedValue = dailySeedService.currentSeed?.seed;
    dailySeedService.fetchSeed().then((newSeedState) {
      debugPrint(
        '[GameCoordinator] daily seed ready: '
        '${dailySeedService.currentSeed}',
      );
      // Emit seed_rotated only when the seed actually changed.
      if (previousSeedValue != null && previousSeedValue != newSeedState.seed) {
        obs.event('seed_rotated', {
          'seed_date': newSeedState.seedDate,
          'is_server_seed': newSeedState.isServerSeed,
        });
      }
    }).catchError((Object e) {
      debugPrint('[GameCoordinator] daily seed fetch failed: $e');
    }).whenComplete(() {
      if (_providerDisposed) return;
      // Subscribe coordinator to GPS stream BEFORE starting the location
      // service. In keyboard mode, kb.start() emits the initial position
      // synchronously on a broadcast stream. If the coordinator subscribes
      // after locationService.start(), that initial emission is lost —
      // causing a blank map until the user presses a key.
      coordinator.start(
        gpsStream: gpsStream,
        discoveryStream: discoveryService.onDiscovery,
      );
      locationService.start();
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

  /// Load player data from SQLite into providers (inventory, cells, profile).
  /// Does NOT start the game loop — call [startLoop] separately after this completes.
  Future<void> rehydrateData(String userId) async {
    try {
      final results = await Future.wait<Object?>([
        itemRepo.getItemsByUser(userId),
        cellProgressRepo.readByUser(userId),
        profileRepo.read(userId),
        cellPropertyRepo.getAll(),
      ]);

      final items = results[0]! as List<ItemInstance>;
      final cellRows = results[1]! as List<LocalCellProgress>;
      final profile = results[2] as LocalPlayerProfile?;
      final cellProperties = results[3]! as List<CellProperties>;

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
          if (fog == FogState.present || fog == FogState.explored) {
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
        return fog == FogState.present || fog == FogState.explored;
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

      obs.event('sqlite_hydration_complete', {
        'user_id': userId,
        'item_count': items.length,
        'cell_count': cellRows.length,
        'has_profile': profile != null,
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

      // Capture final hydrated profile state so the write-through listener
      // doesn't redundantly persist or enqueue data we just loaded.
      // Placed AFTER step hydration so loadProfile(), markHydrated(), and
      // addSteps() mutations are all suppressed by the listener guard.
      lastPersistedProfile = ref.read(playerProvider);
    } catch (e) {
      debugPrint('[GameCoordinator] failed to hydrate: $e');
      // Rethrow so hydrateAndStart's .catchError handles it in one place.
      // Without this, the .then() block runs (because the error was
      // swallowed), hits the same missing-table problem at profileRepo.read,
      // and produces confusing cascading error logs.
      rethrow;
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
    StartupBeacon.emit('hydration_start', {'user_id': userId});
    obs.event('hydration_started', {'user_id': userId});

    final hydrationStopwatch = Stopwatch()..start();

    // Phase 1: SQLite → providers → markHydrated() → startLoop().
    rehydrateData(userId).then((_) async {
      // Warm species cache for ALL unique (habitat, continent) combos in
      // the cell properties cache. Previously only warmed the first combo,
      // causing 46% of cells to produce 0 species (cache miss).
      final speciesCache = ref.read(speciesCacheProvider);
      if (!speciesCache.isEmpty) {
        final cachedProps = coordinator.cellPropertiesCache.values;
        if (cachedProps.isNotEmpty) {
          final seen = <String>{};
          final warmUpFutures = <Future<void>>[];
          for (final props in cachedProps) {
            final key = SpeciesCache.cacheKey(props.habitats, props.continent);
            if (seen.add(key)) {
              warmUpFutures.add(speciesCache.warmUp(
                habitats: props.habitats,
                continent: props.continent,
              ));
            }
          }
          await Future.wait(warmUpFutures);
        } else {
          // No cached cells yet — warm default habitats for a common area.
          await speciesCache.warmUp(
            habitats: {Habitat.forest, Habitat.plains},
            continent: Continent.northAmerica,
          );
        }

        // Ensure all owned species are in the _byId cache so the Pack
        // grid can resolve definitions. warmUp() only covers habitat+
        // continent combos the player has visited — this fills the gaps.
        final ownedIds = ref
            .read(itemsProvider)
            .items
            .map((i) => i.definitionId)
            .toSet()
            .toList();
        await speciesCache.warmUpByIds(ownedIds);
      }

      // Restore last known position before starting the game loop.
      // This ensures the map and keyboard service start at the player's
      // previous location instead of the hardcoded Fredericton default.
      // Captured for defense-in-depth: if the keyboard's initial GPS
      // emission is lost (broadcast stream timing), the post-hydration
      // block can seed the fog resolver from this position.
      double? restoredLat;
      double? restoredLon;
      final profile = await profileRepo.read(userId);
      if (profile?.lastLat != null && profile?.lastLon != null) {
        restoredLat = profile!.lastLat;
        restoredLon = profile.lastLon;
        locationService.setInitialPosition(restoredLat!, restoredLon!);
        debugPrint(
          '[GameCoordinator] restored position: '
          '$restoredLat, $restoredLon',
        );
      }

      hydrationStopwatch.stop();
      StartupBeacon.emit('hydration_complete', {
        'duration_ms': '${hydrationStopwatch.elapsedMilliseconds}',
      });
      final inventory = ref.read(itemsProvider);
      obs.event('hydration_complete', {
        'user_id': userId,
        'duration_ms': hydrationStopwatch.elapsedMilliseconds,
        'item_count': inventory.items.length,
        'source': 'sqlite',
      });

      // ── Startup enrichment backfill ──────────────────────────────────────
      // Queue cells without locationId for enrichment. Priority order:
      // 1. Player's current cell + neighbors (unblocks detection zone fast)
      // 2. Remaining cells without locationId (capped at 50 per session)
      //
      // Also seed detection zone from any cached locationId.
      {
        // Reset circuit breaker on fresh session — previous auth failures
        // should not persist across app restarts.
        locationEnrichmentSvc.resetAuthCircuitBreaker();

        final unenriched = <({String cellId, double lat, double lon})>[];
        String? currentCellId;

        // Scan for un-enriched cells (no detection zone trigger here —
        // zone computation fires once after Supabase hydration completes).
        if (profile?.lastLat != null && profile?.lastLon != null) {
          currentCellId =
              cellService.getCellId(profile!.lastLat!, profile.lastLon!);
        }

        // Priority pass: current cell + neighbors
        if (currentCellId != null) {
          for (final cellId in [
            currentCellId,
            ...cellService.getNeighborIds(currentCellId),
          ]) {
            final props = coordinator.cellPropertiesCache[cellId];
            if (props == null) continue;
            if (props.locationId == null) {
              final center = cellService.getCellCenter(cellId);
              unenriched
                  .add((cellId: cellId, lat: center.lat, lon: center.lon));
            }
          }
        }

        // Remaining pass: all cached cells (capped)
        const backfillCap = 50;
        for (final entry in coordinator.cellPropertiesCache.entries) {
          if (unenriched.length >= backfillCap) break;
          if (entry.value.locationId == null) {
            // Skip if already queued from priority pass
            if (unenriched.any((e) => e.cellId == entry.key)) continue;
            final center = cellService.getCellCenter(entry.key);
            unenriched
                .add((cellId: entry.key, lat: center.lat, lon: center.lon));
          }
        }

        // Queue un-enriched cells for background enrichment
        if (unenriched.isNotEmpty) {
          debugPrint('[LocationEnrichment] startup backfill: '
              'queuing ${unenriched.length} cells '
              '(${unenriched.length >= backfillCap ? "capped" : "all"})');
          for (final cell in unenriched) {
            locationEnrichmentSvc.requestEnrichment(
              cellId: cell.cellId,
              lat: cell.lat,
              lon: cell.lon,
            );
          }
        }
      }

      // Start game loop immediately with cached data.
      if (_providerDisposed) return;
      startLoop();

      // Start live pedometer stream after game loop is running (native only).
      // Must be after hydrate() so _lastStreamValue is set as the baseline.
      if (!kIsWeb) {
        ref.read(stepProvider.notifier).startLiveStream();
      }

      // Track whether SQLite was empty so we know to refresh providers
      // after Supabase hydration (cold start = fresh browser / cleared storage).
      final wasEmptyCache = ref.read(itemsProvider).items.isEmpty;

      // Fun facts cache refresh — defined here so it's in scope for the
      // .then() callback below.
      void refreshFunFactsCache() async {
        try {
          final supabase = ref.read(supabaseClientProvider);
          if (supabase == null) return;

          // Fetch up to 50 facts from the pool
          final response =
              await supabase.from('fun_facts').select('fact_text').limit(50);

          if (_providerDisposed) return;

          final facts =
              (response as List).map((r) => r['fact_text'] as String).toList();

          if (facts.isNotEmpty) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('fun_facts_cache', jsonEncode(facts));
            debugPrint(
                '[FunFacts] cached ${facts.length} facts for next session');
          }

          // Trigger pool growth (fire-and-forget)
          unawaited(supabase.functions.invoke('generate-fun-facts').then((_) {
            debugPrint('[FunFacts] generation triggered');
          }).catchError((e) {
            debugPrint('[FunFacts] generation failed (non-critical): $e');
          }));
        } catch (e) {
          debugPrint('[FunFacts] cache refresh failed (non-critical): $e');
        }
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
        cellPropertyRepo: cellPropertyRepo,
        locationNodeRepo: ref.read(locationNodeRepositoryProvider),
        db: ref.read(appDatabaseProvider),
        speciesCache: ref.read(speciesCacheProvider),
        obs: obs,
      ).then((_) async {
        if (_providerDisposed) return;

        obs.event('background_sync_complete', {'user_id': userId});

        // Reload cell properties cache from SQLite (now includes Supabase data).
        final freshProps = await cellPropertyRepo.getAll();
        if (freshProps.isNotEmpty) {
          coordinator.loadCellProperties({
            for (final p in freshProps) p.cellId: p,
          });
          debugPrint(
            '[GameCoordinator] reloaded ${freshProps.length} cell properties '
            'after Supabase sync',
          );
        }

        // Detection zone now computes automatically from GPS position via
        // updatePlayerPosition. Seed the fog resolver from the restored
        // position if GPS hasn't arrived yet so the map starts correctly.
        if (restoredLat != null && restoredLon != null) {
          fogResolver.onLocationUpdate(restoredLat, restoredLon);
          await detectionZoneService.updatePlayerPosition(
              restoredLat, restoredLon);
          debugPrint('[DetectionZone] seeded from restored position: '
              '$restoredLat, $restoredLon');
        }

        // Species cache is already refreshed inside hydrateFromSupabase()
        // via speciesCache.refresh() — no additional warmUp needed here.

        // On cold start (empty SQLite), Supabase sync wrote data to SQLite
        // but providers are still empty. Re-hydrate providers from the
        // now-populated SQLite cache. Safe because no discoveries can be
        // in-flight on an empty inventory.
        if (wasEmptyCache) {
          debugPrint(
            '[GameCoordinator] cold start detected — refreshing providers '
            'from Supabase-hydrated SQLite',
          );
          try {
            await rehydrateData(userId);
            obs.event('cold_start_rehydration', {'user_id': userId});

            // Force MapScreen to rebuild fog overlay with the newly-hydrated
            // visited cells. Without this, the fog controller's
            // _discoveredCellIds remains empty (initialized before data
            // arrived) and the map stays black.
            ref.invalidate(fogOverlayControllerProvider);
          } catch (e) {
            debugPrint(
              '[GameCoordinator] cold start rehydration failed: $e',
            );
          }
        }

        // Backfill intrinsic affixes for items that were discovered before
        // enrichment was available. Primary safety net — catches all edge
        // cases: items from before this fix, missed callbacks, races, etc.
        // Build stats map from species cache (enrichment now in LocalSpeciesTable).
        final backfillStats =
            <String, ({int speed, int brawn, int wit, AnimalSize? size})>{};
        for (final item in ref.read(itemsProvider).items) {
          if (item.category != ItemCategory.fauna) continue;
          if (backfillStats.containsKey(item.definitionId)) continue;
          final def = speciesCache.getByIdSync(item.definitionId);
          if (def != null && def.brawn != null) {
            backfillStats[item.definitionId] = (
              speed: def.speed!,
              brawn: def.brawn!,
              wit: def.wit!,
              size: def.size != null ? AnimalSize.fromString(def.size!) : null,
            );
          }
        }
        backfillAllMissingAffixes(
          ref: ref,
          enrichmentCache: backfillStats,
          statsService: coordinator.statsService,
          itemRepo: itemRepo,
          queueProcessor: queueProcessor,
          userId: userId,
        );

        // Fun facts: refresh cache for next session + trigger pool growth.
        // Fire-and-forget — errors are irrelevant to gameplay.
        refreshFunFactsCache();
      }).catchError((Object e) {
        debugPrint(
          '[GameCoordinator] background Supabase sync failed: $e',
        );
        obs.event('network_error', {
          'context': 'background_supabase_sync',
          'error': e.toString(),
        });
      });
    }).catchError((Object e) {
      StartupBeacon.emit('hydration_error', {'error': e.toString()});
      debugPrint(
        '[GameCoordinator] SQLite hydration failed '
        '(starting loop anyway): $e',
      );

      // ── Corruption auto-recovery (web only) ────────────────────────
      // If the error looks like a corrupt WASM SQLite database
      // (FormatException wrapping a JS SyntaxError), wipe all browser
      // databases and reload. Supabase is the source of truth — the
      // fresh database will re-hydrate from the server on next load.
      if (kIsWeb && _looksLikeDatabaseCorruption(e)) {
        // ignore: avoid_print
        print(
          '[RECOVERY] database corruption detected during hydration: $e',
        );
        obs.event('database_corruption_recovery', {
          'error': e.toString(),
          'trigger': 'hydration_failure',
          'error_type': 'sqlite_corruption',
        });
        _triggerWebDatabaseRecovery();
        return; // Page will reload — don't start the loop.
      } else if (kIsWeb) {
        obs.event('hydration_error_non_corruption', {
          'error': e.toString(),
          'trigger': 'hydration_failure',
        });
      }

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

    if (authState.status == AuthStatus.authenticated && userId != null) {
      StartupBeacon.emit('auth_settled', {'status': 'authenticated'});
      obs.event('auth_restored', {'user_id': userId});
      LogFlushService.instance?.userId = userId;
      LogFlushService.instance?.phoneNumber = authState.user?.phoneNumber;
      if (userId == lastHydratedUserId) return; // Already hydrated — no-op.
      lastHydratedUserId = userId;

      coordinator.setCurrentUserId(userId);
      hydrateAndStart(userId);
    } else if (authState.status == AuthStatus.unauthenticated) {
      StartupBeacon.emit('auth_settled', {'status': 'unauthenticated'});
      obs.event('auth_expired', {'previous_user_id': lastHydratedUserId});
      // Clear write queue for the outgoing user BEFORE resetting state.
      // Prevents stale entries from being flushed with the next session's
      // credentials, which would trigger RLS violations on Supabase.
      final outgoingUserId = lastHydratedUserId;
      if (outgoingUserId != null) {
        queueProcessor.clearUser(outgoingUserId);
      }

      coordinator.setCurrentUserId(null);
      lastHydratedUserId = null;
      ref.read(playerProvider.notifier).loadProfile(
            cellsObserved: 0,
            totalDistanceKm: 0.0,
            currentStreak: 0,
            longestStreak: 0,
            hasCompletedOnboarding: false, // explicit reset on sign-out
          );
      ref.read(itemsProvider.notifier).loadItems([]);
      fogResolver.loadVisitedCells({});
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
  // persist to SQLite and enqueue for Supabase sync. Debounced to 5s to
  // avoid hammering IndexedDB-backed SQLite on iOS (where each write
  // takes 1.5–3s via the WASM→IndexedDB bridge).

  Timer? profileDebounceTimer;

  ref.onDispose(() => profileDebounceTimer?.cancel());

  ref.listen<PlayerState>(playerProvider, (previous, next) {
    if (previous == null) return; // Skip initial build.
    if (next == lastPersistedProfile) return; // Skip our own writes.

    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return;

    lastPersistedProfile = next;

    // Debounce: accumulate rapid changes (distance ticks, cell visits)
    // and persist once after 5 seconds of calm. On iOS WebKit, each
    // IndexedDB-backed SQLite write takes 1.5–3s — without debounce,
    // every state change triggers a blocking write that freezes the UI.
    profileDebounceTimer?.cancel();
    profileDebounceTimer = Timer(const Duration(seconds: 5), () {
      if (_providerDisposed) return;
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
      // Warm species cache for newly resolved habitats so discoveries work.
      final speciesCache = ref.read(speciesCacheProvider);
      if (!speciesCache.isEmpty) {
        final seen = <String>{};
        for (final props in reResolved) {
          final key = SpeciesCache.cacheKey(props.habitats, props.continent);
          if (seen.add(key)) {
            speciesCache.warmUp(
              habitats: props.habitats,
              continent: props.continent,
            );
          }
        }
      }
    }
  });

  // --- Cleanup ---

  ref.onDispose(() {
    _providerDisposed = true;
    engine.dispose(); // coordinator.dispose() + stream close.
    queueProcessor.dispose();
    locationService.stop();
  });

  // Store engine reference for engineRunnerProvider.
  ref.onDispose(() => _latestEngine = null);
  _latestEngine = engine;

  return coordinator;
});

GameEngine? _latestEngine;

/// Returns true if the error looks like a corrupt WASM SQLite database.
///
/// On Safari/WebKit, corrupt OPFS or IndexedDB databases produce errors
/// like: `FormatException: SyntaxError: JSON Parse error: Unexpected
/// identifier "version"`. These are unrecoverable — the only fix is to
/// wipe browser storage and start fresh.
///
/// We must distinguish real database corruption from network JSON parse
/// errors (e.g. ad blockers intercepting Supabase API calls and returning
/// HTML). Network errors contain 'postgrest', 'SupabaseClient', or
/// 'supabase' in the stack trace. Real corruption doesn't.
bool _looksLikeDatabaseCorruption(Object error) {
  final msg = error.toString();

  // Definitive SQLite corruption — always trigger recovery.
  if (msg.contains('database disk image is malformed')) return true;
  if (msg.contains('SqliteException')) return true;

  // FormatException with SyntaxError could be either corrupt DB or
  // network interception. Check that it does NOT look like a network
  // error by inspecting the full error chain.
  if ((msg.contains('FormatException') && msg.contains('SyntaxError')) ||
      msg.contains('JSON Parse error')) {
    // Network errors from the Supabase client include these markers.
    final isNetworkError = msg.contains('postgrest') ||
        msg.contains('SupabaseClient') ||
        msg.contains('GoTrueClient') ||
        msg.contains('realtime') ||
        msg.contains('FetchClient') ||
        msg.contains('http_client');
    return !isNetworkError;
  }

  return false;
}

/// Max number of automatic database wipe+reload cycles allowed per session.
///
/// After this many reloads, the recovery is skipped to prevent an infinite
/// crash loop (e.g. FormatException from a corrupt asset, not a corrupt DB).
const _kMaxRecoveryAttempts = 3;

/// Count of database wipe+reload attempts in this process lifetime.
///
/// Resets to 0 when the page/process is started fresh.  Because
/// [resetDatabaseStorage] triggers a page reload, this counter resets
/// naturally after a successful recovery.  It only accumulates when the
/// reload itself fails to fix the problem (i.e. the app crashes again
/// before the counter is reset).
int _recoveryAttemptCount = 0;

/// Wipe all web databases (OPFS + IndexedDB) and reload the page.
///
/// Uses [resetDatabaseStorage] from the platform-conditional connection
/// module (no-op on native, wipes OPFS + IndexedDB + reloads on web).
///
/// A max-retry guard prevents an infinite reload loop when the corruption
/// is caused by a bad asset (FormatException from JSON parsing) rather than
/// a truly corrupt SQLite file.  After [_kMaxRecoveryAttempts] reloads the
/// recovery is skipped and the app continues in degraded mode.
void _triggerWebDatabaseRecovery() {
  _recoveryAttemptCount++;
  if (_recoveryAttemptCount > _kMaxRecoveryAttempts) {
    debugPrint(
      '[RECOVERY] max recovery attempts ($_kMaxRecoveryAttempts) reached — '
      'skipping wipe to prevent crash loop. App will run in degraded mode.',
    );
    return;
  }
  debugPrint(
    '[RECOVERY] attempt $_recoveryAttemptCount of $_kMaxRecoveryAttempts',
  );
  resetDatabaseStorage();
}

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
