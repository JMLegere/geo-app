import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/data/database.dart';
import 'package:earth_nova/data/repos/cell_property_repo.dart';
import 'package:earth_nova/data/repos/cell_visit_repo.dart';
import 'package:earth_nova/data/repos/item_repo.dart';
import 'package:earth_nova/data/repos/player_repo.dart';
import 'package:earth_nova/data/repos/write_queue_repo.dart';
import 'package:earth_nova/domain/items/stats_service.dart';
import 'package:earth_nova/domain/species/encounter_roller.dart';
import 'package:earth_nova/domain/species/species_cache.dart';
import 'package:earth_nova/engine/engine_input.dart';
import 'package:earth_nova/engine/game_engine.dart';
import 'package:earth_nova/engine/game_event.dart';
import 'package:earth_nova/engine/main_thread_engine_runner.dart';
import 'package:earth_nova/models/animal_size.dart';
import 'package:earth_nova/models/auth_state.dart';
import 'package:earth_nova/models/cell_properties.dart';
import 'package:earth_nova/models/climate.dart';
import 'package:earth_nova/models/continent.dart';
import 'package:earth_nova/models/fog_state.dart';
import 'package:earth_nova/models/habitat.dart';
import 'package:earth_nova/models/item_category.dart';
import 'package:earth_nova/models/item_instance.dart';
import 'package:earth_nova/models/iucn_status.dart';
import 'package:earth_nova/providers/achievement_provider.dart';
import 'package:earth_nova/providers/auth_provider.dart';
import 'package:earth_nova/providers/cell_provider.dart';
import 'package:earth_nova/providers/daily_seed_provider.dart';
import 'package:earth_nova/providers/database_provider.dart';
import 'package:earth_nova/providers/discovery_provider.dart';
import 'package:earth_nova/providers/fog_provider.dart';
import 'package:earth_nova/providers/inventory_provider.dart';
import 'package:earth_nova/providers/location_provider.dart';
import 'package:earth_nova/providers/player_provider.dart';
import 'package:earth_nova/providers/species_provider.dart';
import 'package:earth_nova/providers/step_provider.dart';
import 'package:earth_nova/providers/sync_provider.dart';
import 'package:earth_nova/providers/world_provider.dart';

// ---------------------------------------------------------------------------
// Repo convenience providers
// ---------------------------------------------------------------------------

final itemRepoProvider = Provider<ItemRepo>(
  (ref) => ItemRepo(ref.watch(databaseProvider)),
);

final cellVisitRepoProvider = Provider<CellVisitRepo>(
  (ref) => CellVisitRepo(ref.watch(databaseProvider)),
);

final playerRepoProvider = Provider<PlayerRepo>(
  (ref) => PlayerRepo(ref.watch(databaseProvider)),
);

final cellPropertyRepoProvider2 = Provider<CellPropertyRepo>(
  (ref) => CellPropertyRepo(ref.watch(databaseProvider)),
);

// ---------------------------------------------------------------------------
// Engine provider — THE BIG ONE
// ---------------------------------------------------------------------------

/// Central wiring provider.
///
/// Creates [GameEngine] → [MainThreadEngineRunner], hydrates all providers
/// from SQLite, then starts the game loop.
///
/// ## Hydration order
///
/// 1. Parallel SQLite reads (items, cell_visits, profile, cell_properties)
/// 2. loadCellProperties → engine
/// 3. loadVisitedCells → fogResolver
/// 4. loadItems → inventoryProvider
/// 5. markHydrated → playerProvider
/// 6. Warm species cache
/// 7. Fetch daily seed
/// 8. Start engine with GPS stream
///
/// ## Event routing
///
/// engine.events:
/// - cell_visited    → fogProvider.update + persistCellVisit
/// - species_discovered → inventoryProvider.addItem + persistItem
/// - cell_properties_resolved → persistCellProperties
/// - fog_changed     → fogProvider.update
final engineProvider = Provider<MainThreadEngineRunner>((ref) {
  final fogResolver = ref.watch(fogResolverProvider);
  final cellService = ref.watch(cellServiceProvider);
  final cellPropertyResolver = ref.read(cellPropertyResolverProvider);
  final dailySeedService = ref.read(dailySeedServiceProvider);
  final speciesCache = ref.read(speciesCacheProvider);

  // Repos
  final itemRepo = ref.read(itemRepoProvider);
  final cellVisitRepo = ref.read(cellVisitRepoProvider);
  final playerRepo = ref.read(playerRepoProvider);
  final cellPropertyRepo = ref.read(cellPropertyRepoProvider2);
  final writeQueueRepo = ref.read(writeQueueRepoProvider);

  // Guard: prevent callbacks from firing on dead ref after disposal.
  var disposed = false;

  // ---------------------------------------------------------------------------
  // Create engine
  // ---------------------------------------------------------------------------

  final engine = GameEngine(
    fogResolver: fogResolver,
    cellService: cellService,
  );

  // Wire optional lazy services.
  engine.statsService = const StatsService();
  engine.dailySeedService = dailySeedService;
  engine.cellPropertyResolver = cellPropertyResolver;

  // Wire species service getter — always non-null; empty cache produces
  // no species until warmed up by the hydration sequence.
  engine.speciesServiceGetter =
      () => SpeciesService.fromCache(cache: speciesCache);

  // Wire enriched stats lookup from species cache.
  engine.enrichedStatsLookup = (definitionId) {
    final def = speciesCache.getByIdSync(definitionId);
    if (def == null || def.brawn == null) return null;
    final size = def.size != null ? AnimalSize.fromString(def.size!) : null;
    return (
      speed: def.speed!,
      brawn: def.brawn!,
      wit: def.wit!,
      size: size,
    );
  };

  final runner = MainThreadEngineRunner(engine);

  ref.onDispose(() {
    disposed = true;
    runner.dispose();
  });

  // ---------------------------------------------------------------------------
  // Track last hydrated user to detect identity changes.
  // ---------------------------------------------------------------------------

  String? lastHydratedUserId;

  // ---------------------------------------------------------------------------
  // Listen to auth changes → update engine + hydrate/reset on user change
  // ---------------------------------------------------------------------------

  ref.listen<AuthState>(authProvider, (prev, next) {
    final userId = next.user?.id;
    engine.send(AuthChanged(userId));
    ref.read(playerProvider.notifier).setUserId(userId);

    if (userId != null && userId != lastHydratedUserId) {
      lastHydratedUserId = userId;
      _hydrateAndStart(
        ref: ref,
        runner: runner,
        engine: engine,
        userId: userId,
        fogResolver: fogResolver,
        itemRepo: itemRepo,
        cellVisitRepo: cellVisitRepo,
        playerRepo: playerRepo,
        cellPropertyRepo: cellPropertyRepo,
        writeQueueRepo: writeQueueRepo,
        speciesCache: speciesCache,
        dailySeedService: dailySeedService,
        disposed: () => disposed,
      );
    }
  });

  // ---------------------------------------------------------------------------
  // Subscribe to engine event stream
  // ---------------------------------------------------------------------------

  final eventSub = runner.events.listen((event) {
    if (disposed) return;
    _routeEvent(
      ref: ref,
      event: event,
      userId: engine.currentUserId,
      cellVisitRepo: cellVisitRepo,
      cellPropertyRepo: cellPropertyRepo,
      writeQueueRepo: writeQueueRepo,
      itemRepo: itemRepo,
    );
  });

  ref.onDispose(eventSub.cancel);

  // Trigger hydration if already authenticated at construction time.
  final currentUser = ref.read(authProvider).user;
  if (currentUser != null) {
    final userId = currentUser.id;
    engine.send(AuthChanged(userId));
    ref.read(playerProvider.notifier).setUserId(userId);
    lastHydratedUserId = userId;
    _hydrateAndStart(
      ref: ref,
      runner: runner,
      engine: engine,
      userId: userId,
      fogResolver: fogResolver,
      itemRepo: itemRepo,
      cellVisitRepo: cellVisitRepo,
      playerRepo: playerRepo,
      cellPropertyRepo: cellPropertyRepo,
      writeQueueRepo: writeQueueRepo,
      speciesCache: speciesCache,
      dailySeedService: dailySeedService,
      disposed: () => disposed,
    );
  }

  return runner;
});

// ---------------------------------------------------------------------------
// Hydration
// ---------------------------------------------------------------------------

Future<void> _hydrateAndStart({
  required Ref ref,
  required MainThreadEngineRunner runner,
  required GameEngine engine,
  required String userId,
  required dynamic fogResolver,
  required ItemRepo itemRepo,
  required CellVisitRepo cellVisitRepo,
  required PlayerRepo playerRepo,
  required CellPropertyRepo cellPropertyRepo,
  required WriteQueueRepo writeQueueRepo,
  required SpeciesCache speciesCache,
  required dynamic dailySeedService,
  required bool Function() disposed,
}) async {
  if (disposed()) return;

  try {
    // 1. Parallel SQLite reads.
    final results = await Future.wait<Object?>([
      itemRepo.getAll(userId),
      cellVisitRepo.getAllVisited(userId),
      playerRepo.get(userId),
      cellPropertyRepo.getAll(),
    ]);

    if (disposed()) return;

    final dbItems = results[0]! as List<Item>;
    final dbVisits = results[1]! as List<CellVisit>;
    final dbProfile = results[2] as Player?;
    final dbCellProps = results[3]! as List<CellProperty>;

    // 2. Load cell properties into engine.
    if (dbCellProps.isNotEmpty) {
      final propsMap = <String, CellProperties>{};
      for (final cp in dbCellProps) {
        List<Habitat> habitatList;
        try {
          habitatList = (jsonDecode(cp.habitatsJson) as List)
              .whereType<String>()
              .map((n) => Habitat.values.firstWhere(
                    (h) => h.name == n,
                    orElse: () => Habitat.plains,
                  ))
              .toList();
        } catch (_) {
          habitatList = [Habitat.plains];
        }
        final climate = Climate.values.firstWhere(
          (c) => c.name == cp.climate,
          orElse: () => Climate.temperate,
        );
        final continent = Continent.values.firstWhere(
          (c) => c.name == cp.continent,
          orElse: () => Continent.northAmerica,
        );

        propsMap[cp.cellId] = CellProperties(
          cellId: cp.cellId,
          habitats: habitatList.toSet(),
          climate: climate,
          continent: continent,
          locationId: cp.locationId,
          createdAt: cp.createdAt,
        );
      }
      engine.loadCellProperties(propsMap);
    }

    // 3. Load visited cells into fog resolver.
    final visitedCellIds = dbVisits.map((v) => v.cellId).toSet();
    if (visitedCellIds.isNotEmpty) {
      engine.loadVisitedCells(visitedCellIds);
    }

    // 4. Convert DB items → domain ItemInstance and load into inventoryProvider.
    final items = dbItems.map(_itemFromRow).whereType<ItemInstance>().toList();
    if (items.isNotEmpty && !disposed()) {
      ref.read(inventoryProvider.notifier).loadItems(items);
    }

    // 5. Mark player hydrated.
    if (!disposed()) {
      final cellsObserved = visitedCellIds.length;
      if (dbProfile != null) {
        ref.read(playerProvider.notifier).loadProfile(
              cellsObserved: cellsObserved,
              totalDistanceKm: dbProfile.totalDistanceKm,
              currentStreak: dbProfile.currentStreak,
              longestStreak: dbProfile.longestStreak,
              hasCompletedOnboarding: dbProfile.hasCompletedOnboarding,
            );
      } else if (cellsObserved > 0) {
        ref.read(playerProvider.notifier).loadProfile(
              cellsObserved: cellsObserved,
              totalDistanceKm: 0.0,
              currentStreak: 0,
              longestStreak: 0,
            );
      }
      ref.read(playerProvider.notifier).markHydrated();
    }

    // Hydrate step counter.
    if (!disposed()) {
      try {
        await ref.read(stepProvider.notifier).hydrate(
              lastKnownStepCount: 0,
              totalSteps: ref.read(playerProvider).totalSteps,
              lastSessionDate: dbProfile?.updatedAt,
            );
      } catch (e) {
        debugPrint('[EngineProvider] step hydration failed: $e');
      }
    }

    if (disposed()) return;

    // 6. Warm species cache for all (habitat, continent) combos in cell props.
    if (!speciesCache.isEmpty) {
      final cachedProps = engine.cellPropertiesCache.values
          .whereType<CellProperties>()
          .toList();
      if (cachedProps.isNotEmpty) {
        final seen = <String>{};
        final futures = <Future<void>>[];
        for (final props in cachedProps) {
          final key = SpeciesCache.cacheKey(props.habitats, props.continent);
          if (seen.add(key)) {
            futures.add(speciesCache.warmUp(
              habitats: props.habitats,
              continent: props.continent,
            ));
          }
        }
        await Future.wait(futures);
      } else {
        await speciesCache.warmUp(
          habitats: {Habitat.forest, Habitat.plains},
          continent: Continent.northAmerica,
        );
      }

      // Warm owned species by ID so pack grid can resolve all definitions.
      if (items.isNotEmpty) {
        await speciesCache
            .warmUpByIds(items.map((i) => i.definitionId).toList());
      }
    }

    if (disposed()) return;

    // 7. Fetch daily seed.
    try {
      await (dailySeedService as dynamic).fetchSeed();
    } catch (e) {
      debugPrint('[EngineProvider] daily seed fetch failed: $e');
    }

    if (disposed()) return;

    // 8. Start engine with GPS stream.
    final gpsStream = ref.read(gpsStreamProvider);
    runner.startEngine(gpsStream: gpsStream);

    debugPrint('[EngineProvider] hydration complete, engine started');
  } catch (e, stack) {
    debugPrint('[EngineProvider] hydration failed: $e\n$stack');
    // Always mark hydrated to prevent loading screen from blocking indefinitely.
    if (!disposed()) {
      ref.read(playerProvider.notifier).markHydrated();
    }
  }
}

// ---------------------------------------------------------------------------
// Event routing
// ---------------------------------------------------------------------------

void _routeEvent({
  required Ref ref,
  required GameEvent event,
  required String? userId,
  required CellVisitRepo cellVisitRepo,
  required CellPropertyRepo cellPropertyRepo,
  required WriteQueueRepo writeQueueRepo,
  required ItemRepo itemRepo,
}) {
  switch (event.event) {
    case 'cell_visited':
      final cellId = event.data['cell_id'] as String?;
      if (cellId == null) return;

      ref.read(playerProvider.notifier).incrementCellsObserved();
      ref.read(achievementProvider.notifier).evaluate();

      if (userId != null) {
        _persistCellVisit(
          cellId: cellId,
          userId: userId,
          cellVisitRepo: cellVisitRepo,
          writeQueueRepo: writeQueueRepo,
        );
      }

    case 'species_discovered':
      final instance = event.data['instance'];
      if (instance is! ItemInstance) return;

      ref.read(inventoryProvider.notifier).addItem(instance);
      ref.read(playerProvider.notifier).incrementSpeciesCollected();
      ref.read(discoveryProvider.notifier).enqueueToast(event);
      ref.read(achievementProvider.notifier).evaluate();

      if (userId != null) {
        _persistItemDiscovery(
          instance: instance,
          userId: userId,
          itemRepo: itemRepo,
          writeQueueRepo: writeQueueRepo,
        );
      }

    case 'cell_properties_resolved':
      final cellId = event.data['cell_id'] as String?;
      final habitatsList =
          (event.data['habitats'] as List?)?.cast<String>() ?? [];
      final climate = event.data['climate'] as String?;
      final continent = event.data['continent'] as String?;
      if (cellId == null || climate == null || continent == null) return;

      _persistCellProperties(
        cellId: cellId,
        habitatsList: habitatsList,
        climate: climate,
        continent: continent,
        locationId: event.data['location_id'] as String?,
        cellPropertyRepo: cellPropertyRepo,
      );

    case 'fog_changed':
      final cellId = event.data['cell_id'] as String?;
      final newStateStr = event.data['new_state'] as String?;
      if (cellId == null || newStateStr == null) return;

      try {
        final fogState = FogState.fromString(newStateStr);
        ref.read(fogProvider.notifier).updateFog({cellId: fogState});
      } catch (_) {}
  }
}

// ---------------------------------------------------------------------------
// Persistence helpers
// ---------------------------------------------------------------------------

void _persistCellVisit({
  required String cellId,
  required String userId,
  required CellVisitRepo cellVisitRepo,
  required WriteQueueRepo writeQueueRepo,
}) {
  cellVisitRepo.incrementVisit(userId, cellId).catchError((Object e) {
    debugPrint('[EngineProvider] persistCellVisit SQLite failed: $e');
  });

  writeQueueRepo
      .enqueue(WriteQueueTableCompanion.insert(
    entityType: 'cellVisit',
    entityId: '$userId:$cellId',
    operation: 'upsert',
    payload: jsonEncode({'userId': userId, 'cellId': cellId}),
    userId: userId,
  ))
      .catchError((Object e) {
    debugPrint('[EngineProvider] enqueue cellVisit failed: $e');
    return 0;
  });
}

void _persistItemDiscovery({
  required ItemInstance instance,
  required String userId,
  required ItemRepo itemRepo,
  required WriteQueueRepo writeQueueRepo,
}) {
  itemRepo
      .create(ItemsTableCompanion.insert(
    id: instance.id,
    userId: userId,
    definitionId: instance.definitionId,
    acquiredAt: instance.acquiredAt,
    displayName: Value(instance.displayName),
    scientificName: Value(instance.scientificName),
    categoryName: Value(instance.category.name),
    rarityName: Value(instance.rarity?.name),
    habitatsJson:
        Value(jsonEncode(instance.habitats.map((h) => h.name).toList())),
    continentsJson:
        Value(jsonEncode(instance.continents.map((c) => c.name).toList())),
    affixesJson: Value(instance.affixesToJson()),
    badgesJson: Value(instance.badgesToJson()),
    acquiredInCellId: Value(instance.acquiredInCellId),
    dailySeed: Value(instance.dailySeed),
    status: Value(instance.status.name),
    taxonomicClass: Value(instance.taxonomicClass),
    animalClassName: Value(instance.animalClassName),
    foodPreferenceName: Value(instance.foodPreferenceName),
    climateName: Value(instance.climateName),
    brawn: Value(instance.brawn),
    wit: Value(instance.wit),
    speed: Value(instance.speed),
    sizeName: Value(instance.sizeName),
    iconUrl: Value(instance.iconUrl),
    artUrl: Value(instance.artUrl),
    cellHabitatName: Value(instance.cellHabitatName),
    cellClimateName: Value(instance.cellClimateName),
    cellContinentName: Value(instance.cellContinentName),
  ))
      .catchError((Object e) {
    debugPrint('[EngineProvider] persistItemDiscovery SQLite failed: $e');
  });

  writeQueueRepo
      .enqueue(WriteQueueTableCompanion.insert(
    entityType: 'item',
    entityId: instance.id,
    operation: 'upsert',
    payload: jsonEncode({'id': instance.id, 'userId': userId}),
    userId: userId,
  ))
      .catchError((Object e) {
    debugPrint('[EngineProvider] enqueue item failed: $e');
    return 0;
  });
}

void _persistCellProperties({
  required String cellId,
  required List<String> habitatsList,
  required String climate,
  required String continent,
  required String? locationId,
  required CellPropertyRepo cellPropertyRepo,
}) {
  cellPropertyRepo
      .upsert(CellPropertiesTableCompanion.insert(
    cellId: cellId,
    habitatsJson: jsonEncode(habitatsList),
    climate: climate,
    continent: continent,
    locationId: Value(locationId),
  ))
      .catchError((Object e) {
    debugPrint('[EngineProvider] persistCellProperties SQLite failed: $e');
  });
}

// ---------------------------------------------------------------------------
// DB row → domain conversion
// ---------------------------------------------------------------------------

ItemInstance? _itemFromRow(Item row) {
  try {
    final habitats = ItemInstance.habitatsFromJson(row.habitatsJson);
    final continents = ItemInstance.continentsFromJson(row.continentsJson);
    final affixes = ItemInstance.affixesFromJson(row.affixesJson);
    final badges = ItemInstance.badgesFromJson(row.badgesJson);
    final category = ItemCategory.values.firstWhereOrNull(
          (c) => c.name == row.categoryName,
        ) ??
        ItemCategory.fauna;
    final rarity = row.rarityName != null
        ? IucnStatus.values.firstWhereOrNull((r) => r.name == row.rarityName)
        : null;
    final status = ItemInstanceStatus.values.firstWhereOrNull(
          (s) => s.name == row.status,
        ) ??
        ItemInstanceStatus.active;

    return ItemInstance(
      id: row.id,
      definitionId: row.definitionId,
      displayName: row.displayName,
      scientificName: row.scientificName,
      category: category,
      rarity: rarity,
      habitats: habitats,
      continents: continents,
      affixes: affixes,
      badges: badges,
      acquiredAt: row.acquiredAt,
      acquiredInCellId: row.acquiredInCellId,
      dailySeed: row.dailySeed,
      status: status,
      taxonomicClass: row.taxonomicClass,
      animalClassName: row.animalClassName,
      foodPreferenceName: row.foodPreferenceName,
      climateName: row.climateName,
      brawn: row.brawn,
      wit: row.wit,
      speed: row.speed,
      sizeName: row.sizeName,
      iconUrl: row.iconUrl,
      artUrl: row.artUrl,
      cellHabitatName: row.cellHabitatName,
      cellClimateName: row.cellClimateName,
      cellContinentName: row.cellContinentName,
    );
  } catch (e) {
    debugPrint('[EngineProvider] _itemFromRow failed for ${row.id}: $e');
    return null;
  }
}

// ---------------------------------------------------------------------------
// Local extensions
// ---------------------------------------------------------------------------

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
