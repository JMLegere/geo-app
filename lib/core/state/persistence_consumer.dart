import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:earth_nova/core/models/cell_properties.dart';
import 'package:earth_nova/core/models/climate.dart';
import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/fog_state.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/models/item_category.dart';
import 'package:earth_nova/core/models/item_instance.dart';
import 'package:earth_nova/core/models/iucn_status.dart';
import 'package:earth_nova/core/models/season.dart';
import 'package:earth_nova/core/models/write_queue_entry.dart';
import 'package:earth_nova/core/models/hierarchy.dart';
import 'package:earth_nova/core/persistence/cell_progress_repository.dart';
import 'package:earth_nova/core/persistence/cell_property_repository.dart';
import 'package:earth_nova/core/persistence/hierarchy_repository.dart';
import 'package:earth_nova/core/persistence/item_instance_repository.dart';
import 'package:earth_nova/core/persistence/profile_repository.dart';
import 'package:earth_nova/core/database/app_database.dart';
import 'package:earth_nova/core/services/observability_buffer.dart';
import 'package:earth_nova/core/species/species_cache.dart';
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
  // 1. Upsert cell progress in SQLite (create if first visit, update if returning).
  try {
    final sw = Stopwatch()..start();
    final existing = await cellProgressRepo.read(userId, cellId);
    if (existing != null) {
      // Returning visit — increment visit count. Use current DB values for payload.
      await cellProgressRepo.incrementVisitCount(userId, cellId);
      visitCount = existing.visitCount + 1;
      distanceWalked = existing.distanceWalked;
    } else {
      // First visit — create new record.
      final progressId = uuid.v4();
      await cellProgressRepo.create(
        id: progressId,
        userId: userId,
        cellId: cellId,
        fogState: FogState.present,
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
      'fog_state': FogState.present.name,
      'visit_count': visitCount,
      'distance_walked': distanceWalked,
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
  // Yield to the event loop before starting heavy DB work.
  // On iOS WebKit, IndexedDB-backed SQLite writes take 1.5–3s.
  // Without this yield, the write blocks the current frame and
  // causes visible UI jank.
  await Future<void>.delayed(Duration.zero);

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
Future<void> hydrateFromSupabase({
  required String userId,
  required SupabasePersistence? persistence,
  required ProfileRepository profileRepo,
  required CellProgressRepository cellProgressRepo,
  required ItemInstanceRepository itemRepo,
  required CellPropertyRepository cellPropertyRepo,
  HierarchyRepository? hierarchyRepo,
  AppDatabase? db,
  SpeciesCache? speciesCache,
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
    ]);

    final profileMap = results[0] as Map<String, dynamic>?;
    final cellRows = results[1]! as List<Map<String, dynamic>>;
    final itemRows = results[2]! as List<Map<String, dynamic>>;

    // Fetch cell properties for visited cells (sequential — depends on cellRows).
    final visitedCellIds = cellRows.map((r) => r['cell_id'] as String).toList();
    final cellPropertyRows =
        await persistence.fetchCellProperties(visitedCellIds);

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

    // 2. Cell progress → SQLite (upsert each row).
    // Yield every 50 rows so the UI can render on iOS.
    for (var i = 0; i < cellRows.length; i++) {
      final row = cellRows[i];
      final cellId = row['cell_id'] as String;
      final id = row['id'] as String? ?? '${userId}_$cellId';
      final fogState = FogState.fromString(
        row['fog_state'] as String? ?? 'present',
      );
      final visitCount = row['visit_count'] as int? ?? 1;
      final distanceWalked =
          (row['distance_walked'] as num?)?.toDouble() ?? 0.0;
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
        lastVisited: lastVisited,
      );
      if (i % 50 == 49) await Future<void>.delayed(Duration.zero);
    }

    // 3. Item instances → SQLite (upsert each row).
    // Yield every 50 rows so the UI can render on iOS.
    for (var i = 0; i < itemRows.length; i++) {
      final row = itemRows[i];
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
        iconUrl: row['icon_url'] as String?,
        artUrl: row['art_url'] as String?,
        status: ItemInstanceStatus.fromString(
          row['status'] as String? ?? 'active',
        ),
        // Species enrichment denorm
        animalClassName: row['animal_class_name'] as String?,
        animalClassNameEnrichver: row['animal_class_name_enrichver'] as String?,
        foodPreferenceName: row['food_preference_name'] as String?,
        foodPreferenceNameEnrichver:
            row['food_preference_name_enrichver'] as String?,
        climateName: row['climate_name'] as String?,
        climateNameEnrichver: row['climate_name_enrichver'] as String?,
        brawn: row['brawn'] as int?,
        brawnEnrichver: row['brawn_enrichver'] as String?,
        wit: row['wit'] as int?,
        witEnrichver: row['wit_enrichver'] as String?,
        speed: row['speed'] as int?,
        speedEnrichver: row['speed_enrichver'] as String?,
        sizeName: row['size_name'] as String?,
        sizeNameEnrichver: row['size_name_enrichver'] as String?,
        iconUrlEnrichver: row['icon_url_enrichver'] as String?,
        artUrlEnrichver: row['art_url_enrichver'] as String?,
        // Cell properties denorm
        cellHabitatName: row['cell_habitat_name'] as String?,
        cellHabitatNameEnrichver: row['cell_habitat_name_enrichver'] as String?,
        cellClimateName: row['cell_climate_name'] as String?,
        cellClimateNameEnrichver: row['cell_climate_name_enrichver'] as String?,
        cellContinentName: row['cell_continent_name'] as String?,
        cellContinentNameEnrichver:
            row['cell_continent_name_enrichver'] as String?,
        // Location hierarchy denorm
        locationDistrict: row['location_district'] as String?,
        locationDistrictEnrichver:
            row['location_district_enrichver'] as String?,
        locationCity: row['location_city'] as String?,
        locationCityEnrichver: row['location_city_enrichver'] as String?,
        locationState: row['location_state'] as String?,
        locationStateEnrichver: row['location_state_enrichver'] as String?,
        locationCountry: row['location_country'] as String?,
        locationCountryEnrichver: row['location_country_enrichver'] as String?,
        locationCountryCode: row['location_country_code'] as String?,
        locationCountryCodeEnrichver:
            row['location_country_code_enrichver'] as String?,
      );

      try {
        // Upsert so that server-side updates (new badges, status changes)
        // are applied to items that already exist locally.
        await itemRepo.upsertItem(instance, userId);
        if (i % 50 == 49) await Future<void>.delayed(Duration.zero);
      } catch (e) {
        debugPrint('[GameCoordinator] failed to upsert hydrated item: $e');
      }
    }

    // 4. Species enrichment delta-sync → LocalSpeciesTable.
    // Pulls classification + art URLs from the server `species` table
    // for any species enriched since our last sync.
    int speciesSynced = 0;
    if (db == null) {
      debugPrint('[GameCoordinator] no AppDatabase — skipping species sync');
    } else
      try {
        // Always do a full sync — the enriched species set is small (~500)
        // and art URLs can be added after classification. A delta watermark
        // would miss art URL updates that arrive after the initial sync.
        final sw = Stopwatch()..start();
        final speciesUpdates =
            await persistence.fetchSpeciesUpdates(since: DateTime(2020));
        sw.stop();

        int withArt = 0;
        for (final row in speciesUpdates) {
          final hasIcon = row['icon_url'] != null;
          final hasArt = row['art_url'] != null;
          if (hasIcon || hasArt) withArt++;
          await db.updateSpeciesEnrichment(
            definitionId: row['definition_id'] as String,
            animalClass: row['animal_class'] as String?,
            foodPreference: row['food_preference'] as String?,
            climate: row['climate'] as String?,
            brawn: row['brawn'] as int?,
            wit: row['wit'] as int?,
            speed: row['speed'] as int?,
            size: row['size'] as String?,
            iconUrl: row['icon_url'] as String?,
            artUrl: row['art_url'] as String?,
            iconPrompt: row['icon_prompt'] as String?,
            artPrompt: row['art_prompt'] as String?,
            enrichedAt: row['enriched_at'] != null
                ? DateTime.parse(row['enriched_at'] as String)
                : null,
            animalClassEnrichver: row['animal_class_enrichver'] as String?,
            foodPreferenceEnrichver:
                row['food_preference_enrichver'] as String?,
            climateEnrichver: row['climate_enrichver'] as String?,
            brawnEnrichver: row['brawn_enrichver'] as String?,
            witEnrichver: row['wit_enrichver'] as String?,
            speedEnrichver: row['speed_enrichver'] as String?,
            sizeEnrichver: row['size_enrichver'] as String?,
            iconPromptEnrichver: row['icon_prompt_enrichver'] as String?,
            artPromptEnrichver: row['art_prompt_enrichver'] as String?,
            iconUrlEnrichver: row['icon_url_enrichver'] as String?,
            artUrlEnrichver: row['art_url_enrichver'] as String?,
          );
          speciesSynced++;
        }
        // ignore: avoid_print
        print(
          '[GameCoordinator] species sync: $speciesSynced enriched, '
          '$withArt with art URLs',
        );

        // Refresh species cache — re-queries all previously cached
        // habitat/continent combos so art URLs are picked up without
        // losing coverage for species in different areas.
        if (speciesSynced > 0 && speciesCache != null) {
          await speciesCache.refresh();
          debugPrint(
            '[GameCoordinator] species cache refreshed after syncing $speciesSynced species',
          );
        }

        obs?.event('species_delta_sync', {
          'count': speciesSynced,
          'duration_ms': sw.elapsedMilliseconds,
          'since': 'full',
        });
      } catch (e) {
        debugPrint('[GameCoordinator] species delta-sync failed: $e');
        obs?.event('species_delta_sync_error', {
          'error': e.toString(),
        });
      }

    // 5. Cell properties → SQLite (upsert globally shared cell data).
    // Yield to the event loop every 50 rows to prevent blocking the UI.
    // On iOS IndexedDB-backed SQLite, each upsert takes ~10-15ms — without
    // yielding, 700 upserts would freeze the UI for 7-10 seconds.
    var cellPropsHydrated = 0;
    for (final row in cellPropertyRows) {
      try {
        final cellId = row['cell_id'] as String;
        final habitatsList = row['habitats'];
        final climate = row['climate'] as String?;
        final continent = row['continent'] as String?;
        final locationId = row['location_id'] as String?;

        if (climate != null && continent != null && habitatsList != null) {
          final habitats = (habitatsList as List)
              .map((h) => Habitat.fromString(h.toString()))
              .toSet();
          final props = CellProperties(
            cellId: cellId,
            habitats: habitats,
            climate: Climate.fromString(climate),
            continent: Continent.fromString(continent),
            locationId: locationId,
            createdAt: DateTime.now(),
          );
          await cellPropertyRepo.upsert(props);
          cellPropsHydrated++;

          // Yield every 50 rows so the UI can render frames.
          if (cellPropsHydrated % 50 == 0) {
            await Future<void>.delayed(Duration.zero);
          }
        }
      } catch (e) {
        // Skip invalid rows silently.
      }
    }
    if (cellPropsHydrated > 0) {
      debugPrint(
        '[GameCoordinator] hydrated $cellPropsHydrated cell properties '
        'from Supabase',
      );
    }

    // 7. Hierarchy tables → SQLite (globally shared location hierarchy)
    if (hierarchyRepo != null) {
      try {
        final hierarchyResults = await Future.wait([
          persistence.fetchCountries(),
          persistence.fetchStates(),
          persistence.fetchCities(),
          persistence.fetchDistricts(),
        ]);

        final countryRows = hierarchyResults[0];
        final stateRows = hierarchyResults[1];
        final cityRows = hierarchyResults[2];
        final districtRows = hierarchyResults[3];

        for (final row in countryRows) {
          await hierarchyRepo.upsertCountry(HCountry(
            id: row['id'] as String,
            name: row['name'] as String? ?? '',
            centroidLat: (row['centroid_lat'] as num?)?.toDouble() ?? 0.0,
            centroidLon: (row['centroid_lon'] as num?)?.toDouble() ?? 0.0,
            continent: row['continent'] as String? ?? '',
            boundaryJson: row['boundary_json'] as String?,
          ));
        }
        for (final row in stateRows) {
          await hierarchyRepo.upsertState(HState(
            id: row['id'] as String,
            name: row['name'] as String? ?? '',
            centroidLat: (row['centroid_lat'] as num?)?.toDouble() ?? 0.0,
            centroidLon: (row['centroid_lon'] as num?)?.toDouble() ?? 0.0,
            countryId: row['country_id'] as String? ?? '',
            boundaryJson: row['boundary_json'] as String?,
          ));
        }
        for (final row in cityRows) {
          await hierarchyRepo.upsertCity(HCity(
            id: row['id'] as String,
            name: row['name'] as String? ?? '',
            centroidLat: (row['centroid_lat'] as num?)?.toDouble() ?? 0.0,
            centroidLon: (row['centroid_lon'] as num?)?.toDouble() ?? 0.0,
            stateId: row['state_id'] as String? ?? '',
            boundaryJson: row['boundary_json'] as String?,
          ));
        }
        for (final row in districtRows) {
          await hierarchyRepo.upsertDistrict(HDistrict(
            id: row['id'] as String,
            name: row['name'] as String? ?? '',
            centroidLat: (row['centroid_lat'] as num?)?.toDouble() ?? 0.0,
            centroidLon: (row['centroid_lon'] as num?)?.toDouble() ?? 0.0,
            cityId: row['city_id'] as String? ?? '',
            boundaryJson: row['boundary_json'] as String?,
          ));
        }

        debugPrint(
          '[GameCoordinator] hydrated hierarchy: '
          '${countryRows.length} countries, ${stateRows.length} states, '
          '${cityRows.length} cities, ${districtRows.length} districts',
        );
        obs?.event('hierarchy_hydrated', {
          'countries': countryRows.length,
          'states': stateRows.length,
          'cities': cityRows.length,
          'districts': districtRows.length,
        });
      } catch (e) {
        debugPrint('[GameCoordinator] hierarchy hydration failed: $e');
        obs?.event('hierarchy_hydration_failed', {
          'error': e.toString().substring(0, e.toString().length.clamp(0, 300)),
        });
      }
    }

    debugPrint(
      '[GameCoordinator] Supabase hydration complete: '
      'profile=${profileMap != null}, '
      'cells=${cellRows.length}, '
      'items=${itemRows.length}, '
      'speciesSynced=$speciesSynced',
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
