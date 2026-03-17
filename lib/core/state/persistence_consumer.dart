import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:earth_nova/core/models/animal_class.dart';
import 'package:earth_nova/core/models/animal_size.dart';
import 'package:earth_nova/core/models/cell_properties.dart';
import 'package:earth_nova/core/models/climate.dart';
import 'package:earth_nova/core/models/fog_state.dart';
import 'package:earth_nova/core/models/food_type.dart';
import 'package:earth_nova/core/models/item_category.dart';
import 'package:earth_nova/core/models/item_instance.dart';
import 'package:earth_nova/core/models/iucn_status.dart';
import 'package:earth_nova/core/models/season.dart';
import 'package:earth_nova/core/models/species_enrichment.dart';
import 'package:earth_nova/core/models/write_queue_entry.dart';
import 'package:earth_nova/core/persistence/cell_progress_repository.dart';
import 'package:earth_nova/core/persistence/cell_property_repository.dart';
import 'package:earth_nova/core/persistence/enrichment_repository.dart';
import 'package:earth_nova/core/persistence/item_instance_repository.dart';
import 'package:earth_nova/core/persistence/profile_repository.dart';
import 'package:earth_nova/core/services/observability_buffer.dart';
import 'package:earth_nova/core/state/player_provider.dart';
import 'package:earth_nova/features/sync/services/queue_processor.dart';
import 'package:earth_nova/features/sync/services/supabase_persistence.dart';

const uuid = Uuid();

/// Persist an item discovery to SQLite and enqueue for Supabase sync.
///
/// The enqueue step only runs when the SQLite write succeeds, so that an
/// item which failed to persist locally is never queued for server sync.
Future<void> persistItemDiscovery({
  required ItemInstance instance,
  required String userId,
  required ItemInstanceRepository itemRepo,
  required QueueProcessor queueProcessor,
  ObservabilityBuffer? obs,
  CellProgressRepository? cellProgressRepo,
}) async {
  // 1. Write to SQLite (local cache).
  try {
    final sw = Stopwatch()..start();
    await itemRepo.addItem(instance, userId);
    sw.stop();
    if (sw.elapsedMilliseconds > 50) {
      obs?.event('sqlite_slow', {
        'operation': 'persist_item',
        'duration_ms': sw.elapsedMilliseconds,
      });
    }
  } catch (e) {
    debugPrint('[GameCoordinator] failed to persist item: $e');
    obs?.event('persistence_error', {
      'operation': 'persist_item',
      'entity_id': instance.id,
      'error': e.toString(),
    });
    return; // Do not enqueue — item was not persisted locally.
  }

  // 1b. Recompute restoration level if cell ID is known.
  final cellId = instance.acquiredInCellId;
  if (cellId != null && cellProgressRepo != null) {
    try {
      final cellItems = await itemRepo.getItemsByCell(userId, cellId);
      final uniqueCount = cellItems.map((i) => i.definitionId).toSet().length;
      final newLevel = (uniqueCount.clamp(0, 3) / 3.0);
      final existing = await cellProgressRepo.read(userId, cellId);
      final oldLevel = existing?.restorationLevel ?? 0.0;
      if ((newLevel - oldLevel).abs() > 0.001) {
        await cellProgressRepo.update(
          userId: userId,
          cellId: cellId,
          restorationLevel: newLevel,
        );
        obs?.event('cell_restored', {
          'cell_id': cellId,
          'restoration_level': newLevel,
          'unique_species': uniqueCount,
        });
      }
    } catch (e) {
      debugPrint('[GameCoordinator] failed to update restoration level: $e');
    }
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
    obs?.event('persistence_error', {
      'operation': 'enqueue_item',
      'entity_id': instance.id,
      'error': e.toString(),
    });
  }
}

/// Persist cell properties to SQLite and enqueue for Supabase sync.
///
/// Cell properties are globally shared (not per-user), so the SQLite write
/// has no userId. The write queue entry still needs userId for routing.
///
/// The enqueue step only runs when the SQLite write succeeds.
Future<void> persistCellProperties({
  required CellProperties properties,
  required CellPropertyRepository cellPropertyRepo,
  required QueueProcessor queueProcessor,
  required String? userId,
  ObservabilityBuffer? obs,
}) async {
  // 1. Write to SQLite (local cache).
  try {
    await cellPropertyRepo.upsert(properties);
  } catch (e) {
    debugPrint('[GameCoordinator] failed to persist cell properties: $e');
    obs?.event('persistence_error', {
      'operation': 'persist_cell_properties',
      'entity_id': properties.cellId,
      'error': e.toString(),
    });
    return; // Do not enqueue — cell properties were not persisted locally.
  }

  // 2. Enqueue for Supabase sync (auto-schedules flush).
  if (userId != null) {
    try {
      final payload = jsonEncode({
        'cell_id': properties.cellId,
        'habitats': properties.habitats.map((h) => h.name).toList(),
        'climate': properties.climate.name,
        'continent': properties.continent.name,
        'location_id': properties.locationId,
      });

      await queueProcessor.enqueue(
        entityType: WriteQueueEntityType.cellProperties,
        entityId: properties.cellId,
        operation: WriteQueueOperation.upsert,
        payload: payload,
        userId: userId,
      );
    } catch (e) {
      debugPrint('[GameCoordinator] failed to enqueue cell properties: $e');
      obs?.event('persistence_error', {
        'operation': 'enqueue_cell_properties',
        'entity_id': properties.cellId,
        'error': e.toString(),
      });
    }
  }
}

/// Persist a cell visit to SQLite and enqueue for Supabase sync.
///
/// The enqueue step only runs when the SQLite write succeeds, preventing
/// corrupt payloads (e.g. default visitCount=1) from reaching the server
/// if the local write fails.
Future<void> persistCellVisit({
  required String cellId,
  required String userId,
  required CellProgressRepository cellProgressRepo,
  required QueueProcessor queueProcessor,
  ObservabilityBuffer? obs,
}) async {
  final now = DateTime.now();
  int visitCount = 1;
  double distanceWalked = 0.0;
  double restorationLevel = 0.0;
  // 1. Upsert cell progress in SQLite (create if first visit, update if returning).
  try {
    final sw = Stopwatch()..start();
    final existing = await cellProgressRepo.read(userId, cellId);
    if (existing != null) {
      // Returning visit — increment visit count. Use current DB values for payload.
      await cellProgressRepo.incrementVisitCount(userId, cellId);
      visitCount = existing.visitCount + 1;
      distanceWalked = existing.distanceWalked;
      restorationLevel = existing.restorationLevel;
    } else {
      // First visit — create new record.
      final progressId = uuid.v4();
      await cellProgressRepo.create(
        id: progressId,
        userId: userId,
        cellId: cellId,
        fogState: FogState.observed,
        visitCount: 1,
        lastVisited: now,
      );
    }
    sw.stop();
    if (sw.elapsedMilliseconds > 50) {
      obs?.event('sqlite_slow', {
        'operation': 'persist_cell_visit',
        'duration_ms': sw.elapsedMilliseconds,
      });
    }
  } catch (e) {
    debugPrint('[GameCoordinator] failed to persist cell visit: $e');
    obs?.event('persistence_error', {
      'operation': 'persist_cell_visit',
      'entity_id': cellId,
      'error': e.toString(),
    });
    return; // Do not enqueue — payload would contain stale default values.
  }

  // 2. Enqueue for Supabase sync only when SQLite write succeeded.
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
    obs?.event('persistence_error', {
      'operation': 'enqueue_cell_visit',
      'entity_id': cellId,
      'error': e.toString(),
    });
  }
}

/// Persist player profile state to SQLite and enqueue for Supabase sync.
///
/// Called whenever [PlayerNotifier] state changes (cells observed, distance,
/// streaks). Fire-and-forget — errors are logged but don't crash the UI.
///
/// [lastLat] and [lastLon] are the player's current position, saved so the
/// next session can restore from their last known location.
///
/// The enqueue step only runs when the SQLite write succeeds.
Future<void> persistProfileState({
  required String userId,
  required PlayerState playerState,
  required ProfileRepository profileRepo,
  required QueueProcessor queueProcessor,
  double? lastLat,
  double? lastLon,
  ObservabilityBuffer? obs,
}) async {
  final season = Season.fromDate(DateTime.now());

  // 1. Persist to SQLite.
  try {
    final sw = Stopwatch()..start();
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
        totalSteps: playerState.totalSteps,
        lastKnownStepCount: playerState.lastKnownStepCount,
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
        totalSteps: playerState.totalSteps,
        lastKnownStepCount: playerState.lastKnownStepCount,
      );
    }
    sw.stop();
    if (sw.elapsedMilliseconds > 50) {
      obs?.event('sqlite_slow', {
        'operation': 'persist_profile',
        'duration_ms': sw.elapsedMilliseconds,
      });
    }
  } catch (e) {
    debugPrint('[GameCoordinator] failed to persist profile: $e');
    obs?.event('persistence_error', {
      'operation': 'persist_profile',
      'entity_id': userId,
      'error': e.toString(),
    });
    return; // Do not enqueue — profile was not persisted locally.
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
      'total_steps': playerState.totalSteps,
      'last_known_step_count': playerState.lastKnownStepCount,
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
    obs?.event('persistence_error', {
      'operation': 'enqueue_profile',
      'entity_id': userId,
      'error': e.toString(),
    });
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
  ObservabilityBuffer? obs,
}) async {
  if (persistence == null) {
    debugPrint(
      '[GameCoordinator] Supabase not configured — skipping '
      'server hydration',
    );
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
      final fogState = FogState.fromString(
        row['fog_state'] as String? ?? 'observed',
      );
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
        habitats: ItemInstance.habitatsFromJson(
          row['habitats_json'] as String?,
        ),
        continents: ItemInstance.continentsFromJson(
          row['continents_json'] as String?,
        ),
        taxonomicClass: row['taxonomic_class'] as String?,
        affixes: ItemInstance.affixesFromJson(
          row['affixes'] as String? ?? '[]',
        ),
        badges: ItemInstance.badgesFromJson(
          row['badges_json'] as String? ?? '[]',
        ),
        acquiredAt: acquiredAt,
        acquiredInCellId: row['acquired_in_cell_id'] as String?,
        dailySeed: row['daily_seed'] as String?,
        parentAId: row['parent_a_id'] as String?,
        parentBId: row['parent_b_id'] as String?,
        status: ItemInstanceStatus.fromString(
          row['status'] as String? ?? 'active',
        ),
      );

      try {
        // Upsert so that server-side updates (new badges, status changes)
        // are applied to items that already exist locally.
        await itemRepo.upsertItem(instance, userId);
      } catch (e) {
        debugPrint('[GameCoordinator] failed to upsert hydrated item: $e');
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

    debugPrint(
      '[GameCoordinator] Supabase hydration complete: '
      'profile=${profileMap != null}, '
      'cells=${cellRows.length}, '
      'items=${itemRows.length}, '
      'enrichments=${enrichmentRows.length}',
    );
  } catch (e) {
    // Network error, Supabase down, etc. — continue with SQLite-only.
    debugPrint(
      '[GameCoordinator] Supabase hydration failed (continuing '
      'with local data): $e',
    );
    obs?.event('network_error', {
      'operation': 'hydrate_from_supabase',
      'user_id': userId,
      'error': e.toString(),
    });
  }
}
