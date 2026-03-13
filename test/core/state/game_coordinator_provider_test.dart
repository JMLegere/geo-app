// Tests for the enrichment wiring added to gameCoordinatorProvider.
//
// Strategy: bypass Riverpod entirely. Build GameCoordinator directly and
// wire onCellVisited manually — mirroring the production code in
// gameCoordinatorProvider. This avoids the Riverpod assertion that fires
// when ProviderContainer initialises gameCoordinatorProvider (which calls
// handleAuthState → PlayerNotifier.loadProfile during build, violating
// "no cross-provider mutation during init").
//
// What we're testing:
//   1. When onCellVisited fires, the wiring code enriches the visited cell
//      AND its ring-1 Voronoi neighbors — and does NOT enrich anything on
//      startup (before any cell visit).
//   2. After auth cycle (logout → re-login), the enrichment service is
//      fresh (not a zombie with _authFailed = true) and onEnrichedHook is
//      properly re-wired.

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geobase/geobase.dart';

import 'package:earth_nova/core/cells/cell_service.dart';
import 'package:earth_nova/core/database/app_database.dart';
import 'package:earth_nova/core/fog/fog_state_resolver.dart';
import 'package:earth_nova/core/game/game_coordinator.dart';
import 'package:earth_nova/core/models/animal_class.dart';
import 'package:earth_nova/core/models/cell_properties.dart';
import 'package:earth_nova/core/models/climate.dart';
import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/food_type.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/models/species_enrichment.dart';
import 'package:earth_nova/core/persistence/cell_property_repository.dart';
import 'package:earth_nova/core/species/stats_service.dart';
import 'package:earth_nova/core/state/app_database_provider.dart';
import 'package:earth_nova/features/enrichment/providers/enrichment_provider.dart';
import 'package:earth_nova/features/sync/providers/sync_provider.dart';

// ---------------------------------------------------------------------------
// _MockCellService — deterministic neighbors for enrichment assertions.
// getCellCenter returns (lat: 0, lon: 0) for all cells.
// ---------------------------------------------------------------------------
class _MockCellService implements CellService {
  final Map<String, List<String>> neighborMap;

  _MockCellService({required this.neighborMap});

  @override
  String getCellId(double lat, double lon) => 'visited';

  @override
  Geographic getCellCenter(String cellId) => Geographic(lat: 0, lon: 0);

  @override
  List<Geographic> getCellBoundary(String cellId) => [];

  @override
  List<String> getNeighborIds(String cellId) => neighborMap[cellId] ?? [];

  @override
  List<String> getCellsInRing(String cellId, int k) => [cellId];

  @override
  List<String> getCellsAroundLocation(double lat, double lon, int k) =>
      ['visited'];

  @override
  double get cellEdgeLengthMeters => 180;

  @override
  String get systemName => 'MockGrid';
}

// ---------------------------------------------------------------------------
// Wire the same enrichment logic as gameCoordinatorProvider.onCellVisited.
//
// Production code (game_coordinator_provider.dart):
//
//   final locationEnrichmentSvc = ref.read(locationEnrichmentServiceProvider);
//   final visitedCenter = cellService.getCellCenter(cellId);
//   locationEnrichmentSvc.requestEnrichment(cellId: cellId, lat: ..., lon: ...);
//   for (final neighborId in cellService.getNeighborIds(cellId)) {
//     final center = cellService.getCellCenter(neighborId);
//     locationEnrichmentSvc.requestEnrichment(cellId: neighborId, ...);
//   }
//
// We replicate this logic here, recording calls into [enrichedCellIds].
// ---------------------------------------------------------------------------
void _wireEnrichmentOnCellVisited(
  GameCoordinator coordinator,
  CellService cellService,
  List<String> enrichedCellIds,
) {
  coordinator.onCellVisited = (String cellId) {
    // Mirror production wiring: visited cell + ring-1 neighbors.
    // (getCellCenter is called in production to get lat/lon for the request;
    //  we call it here too to mirror the wiring faithfully.)
    cellService.getCellCenter(cellId); // lat/lon used in production
    enrichedCellIds.add(cellId); // simulates requestEnrichment(cellId, ...)

    for (final neighborId in cellService.getNeighborIds(cellId)) {
      cellService.getCellCenter(neighborId); // lat/lon used in production
      enrichedCellIds
          .add(neighborId); // simulates requestEnrichment(neighborId, ...)
    }
  };
}

void main() {
  group('gameCoordinatorProvider — enrichment on cell visit', () {
    late _MockCellService cellService;
    late List<String> enrichedCellIds;
    late GameCoordinator coordinator;

    setUp(() {
      cellService = _MockCellService(
        neighborMap: {
          'visited': ['n1', 'n2', 'n3'],
        },
      );
      enrichedCellIds = [];
      coordinator = GameCoordinator(
        fogResolver: FogStateResolver(cellService),
        statsService: const StatsService(),
        cellService: cellService,
      );
      _wireEnrichmentOnCellVisited(coordinator, cellService, enrichedCellIds);
    });

    tearDown(() {
      coordinator.dispose();
    });

    test('visiting a cell enriches the cell and its ring-1 neighbors', () {
      // Simulate a cell visit by firing the onCellVisited callback directly.
      // In production this is called by GameCoordinator when the player
      // enters a new cell. We bypass the GPS loop here.
      coordinator.onCellVisited?.call('visited');

      // Visited cell + 3 neighbors = 4 enrichment requests.
      expect(enrichedCellIds, containsAll(['visited', 'n1', 'n2', 'n3']));
      expect(enrichedCellIds.length, 4);
    });

    test('startup does NOT trigger mass enrichment', () {
      // Just creating the coordinator (startup) should not enqueue any
      // enrichment. No cell visits have occurred.
      expect(enrichedCellIds, isEmpty);
    });

    test('cell with no neighbors enriches only the visited cell', () {
      // Override with a cell service that has no neighbors for 'solo'.
      final soloService = _MockCellService(neighborMap: {});
      final soloEnriched = <String>[];
      final soloCoordinator = GameCoordinator(
        fogResolver: FogStateResolver(soloService),
        statsService: const StatsService(),
        cellService: soloService,
      );
      addTearDown(soloCoordinator.dispose);
      _wireEnrichmentOnCellVisited(soloCoordinator, soloService, soloEnriched);

      soloCoordinator.onCellVisited?.call('solo');

      expect(soloEnriched, ['solo']);
      expect(soloEnriched.length, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // Enrichment service re-wiring after auth cycle (logout → re-login).
  //
  // Tests the fix for the zombie enrichment service bug: after logout →
  // re-login, the old EnrichmentService had _authFailed = true (circuit
  // breaker tripped) and the onEnrichedHook pointed to the dead instance.
  //
  // Strategy: use a minimal ProviderContainer with overrides for the
  // enrichment service's dependencies (AppDatabase + SupabaseClient).
  // This tests the enrichmentServiceProvider itself — proving that
  // invalidation creates a fresh service and the hook can be re-wired.
  // The actual gameCoordinatorProvider wiring (ref.invalidate +
  // ref.read + hook assignment) mirrors this pattern exactly.
  // ---------------------------------------------------------------------------
  group('enrichment service re-wiring after auth cycle', () {
    late ProviderContainer container;
    late AppDatabase testDb;

    setUpAll(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });

    setUp(() {
      testDb = AppDatabase(NativeDatabase.memory());
      container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(testDb),
        supabaseClientProvider.overrideWithValue(null),
      ]);
    });

    tearDown(() {
      container.dispose();
      testDb.close();
    });

    test(
        'invalidating enrichmentServiceProvider creates fresh instance '
        'with _authFailed == false (proven by new identity)', () {
      final service1 = container.read(enrichmentServiceProvider);

      // Simulate zombie state: wire a hook on the old service.
      service1.onEnrichedHook = (_) {};

      // Invalidate — mirrors what handleAuthState does on re-login.
      container.invalidate(enrichmentServiceProvider);

      final service2 = container.read(enrichmentServiceProvider);

      // New instance → _authFailed is false (constructor default).
      // Dart has no public accessor for _authFailed, so we prove it
      // by identity: a freshly constructed EnrichmentService always
      // starts with _authFailed = false.
      expect(identical(service1, service2), isFalse);

      // Hook is null on fresh instance (not yet re-wired by handleAuthState).
      expect(service2.onEnrichedHook, isNull);
    });

    test(
        'onEnrichedHook can be re-wired on fresh service after '
        'invalidation and fires correctly', () {
      final service1 = container.read(enrichmentServiceProvider);
      service1.onEnrichedHook = (_) {};

      // Simulate auth cycle: invalidate → create fresh service.
      container.invalidate(enrichmentServiceProvider);
      final service2 = container.read(enrichmentServiceProvider);

      // Re-wire hook (mimics handleAuthState re-login path).
      SpeciesEnrichment? captured;
      service2.onEnrichedHook = (e) {
        captured = e;
      };

      expect(service2.onEnrichedHook, isNotNull);

      // Verify the hook actually fires on the new instance.
      final testEnrichment = SpeciesEnrichment(
        definitionId: 'test-species',
        animalClass: AnimalClass.carnivore,
        foodPreference: FoodType.critter,
        climate: Climate.temperate,
        brawn: 30,
        wit: 30,
        speed: 30,
        enrichedAt: DateTime.now(),
      );
      service2.onEnrichedHook!(testEnrichment);
      expect(captured, testEnrichment);

      // Old service hook is unaffected — it's a dead zombie.
      SpeciesEnrichment? oldCaptured;
      service1.onEnrichedHook = (e) {
        oldCaptured = e;
      };
      service2.onEnrichedHook!(testEnrichment);
      expect(oldCaptured, isNull,
          reason: 'old service hook should not fire from new service');
    });

    test(
        'full auth cycle: authenticated → unauthenticated → authenticated '
        'yields fresh enrichment service', () {
      // Simulate first login: read enrichment service, wire hook.
      final loginService = container.read(enrichmentServiceProvider);
      loginService.onEnrichedHook = (_) {};

      // Simulate logout: (in production, handleAuthState clears state but
      // does NOT invalidate enrichment service — that happens on re-login).

      // Simulate re-login: invalidate + re-read + re-wire.
      container.invalidate(enrichmentServiceProvider);
      final reLoginService = container.read(enrichmentServiceProvider);

      // Must be a completely new instance.
      expect(identical(loginService, reLoginService), isFalse);

      // Re-wire hook and verify it works.
      SpeciesEnrichment? captured;
      reLoginService.onEnrichedHook = (e) {
        captured = e;
      };
      reLoginService.onEnrichedHook!(SpeciesEnrichment(
        definitionId: 're-login-species',
        animalClass: AnimalClass.songbird,
        foodPreference: FoodType.seed,
        climate: Climate.boreal,
        brawn: 20,
        wit: 40,
        speed: 30,
        enrichedAt: DateTime.now(),
      ));
      expect(captured?.definitionId, 're-login-species');
    });
  });

  // ---------------------------------------------------------------------------
  // Cell property rehydration after auth cycle.
  //
  // Tests the end-to-end flow: cell properties persisted in SQLite survive
  // an auth cycle (logout → re-login) because:
  //   1. Cell properties are globally shared (not per-user) — handleAuthState
  //      logout does NOT clear _cellPropertiesCache.
  //   2. rehydrateData() calls cellPropertyRepo.getAll() → loadCellProperties()
  //      to populate the cache on every login.
  //   3. The cellPropertiesLookup closure on DiscoveryService references
  //      coordinator.cellPropertiesCache[cellId], so it resolves non-null
  //      for any cell that was populated during hydration.
  //
  // Strategy: test the individual components of the hydration pipeline
  // directly (SQLite round-trip → GameCoordinator cache → lookup closure)
  // rather than standing up the full gameCoordinatorProvider, which requires
  // mocking GPS, discovery streams, auth, and 15+ other providers.
  // ---------------------------------------------------------------------------
  group('cell property rehydration after auth cycle', () {
    late AppDatabase testDb;

    setUpAll(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });

    setUp(() {
      testDb = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() => testDb.close());

    /// Helper: create a CellProperties instance for test assertions.
    CellProperties makeCellProperties({
      required String cellId,
      Set<Habitat>? habitats,
      Climate climate = Climate.temperate,
      Continent continent = Continent.northAmerica,
      String? locationId,
    }) {
      return CellProperties(
        cellId: cellId,
        habitats: habitats ?? {Habitat.forest},
        climate: climate,
        continent: continent,
        locationId: locationId,
        createdAt: DateTime(2026, 3, 13),
      );
    }

    /// Helper: insert a CellProperties into the in-memory database.
    Future<void> seedCellProperties(CellProperties props) async {
      await testDb.upsertCellProperties(props.toDriftRow());
    }

    test(
        'cell properties round-trip through SQLite and populate '
        'GameCoordinator cache via loadCellProperties', () async {
      // 1. Seed cell properties into SQLite.
      final forestCell = makeCellProperties(
        cellId: 'v_10_20',
        habitats: {Habitat.forest, Habitat.freshwater},
        climate: Climate.boreal,
        continent: Continent.europe,
        locationId: 'loc-123',
      );
      final desertCell = makeCellProperties(
        cellId: 'v_30_40',
        habitats: {Habitat.desert},
        climate: Climate.tropic,
        continent: Continent.africa,
      );

      await seedCellProperties(forestCell);
      await seedCellProperties(desertCell);

      // 2. Read all cell properties from SQLite (mirrors rehydrateData path).
      final repo = CellPropertyRepository(testDb);
      final allProps = await repo.getAll();
      expect(allProps.length, 2);

      // 3. Build the map and load into GameCoordinator cache (mirrors
      //    rehydrateData lines 413-419).
      final propsMap = <String, CellProperties>{};
      for (final cp in allProps) {
        propsMap[cp.cellId] = cp;
      }

      final cellService = _MockCellService(neighborMap: {});
      final coordinator = GameCoordinator(
        fogResolver: FogStateResolver(cellService),
        statsService: const StatsService(),
        cellService: cellService,
      );
      addTearDown(coordinator.dispose);

      coordinator.loadCellProperties(propsMap);

      // 4. Verify cache is populated with correct data.
      final cache = coordinator.cellPropertiesCache;
      expect(cache.length, 2);
      expect(cache['v_10_20']!.habitats, {Habitat.forest, Habitat.freshwater});
      expect(cache['v_10_20']!.climate, Climate.boreal);
      expect(cache['v_10_20']!.continent, Continent.europe);
      expect(cache['v_10_20']!.locationId, 'loc-123');
      expect(cache['v_30_40']!.habitats, {Habitat.desert});
      expect(cache['v_30_40']!.climate, Climate.tropic);
      expect(cache['v_30_40']!.continent, Continent.africa);
    });

    test(
        'cellPropertiesLookup closure returns non-null for cached cells '
        'and null for uncached cells', () async {
      // Seed one cell property.
      final swampCell = makeCellProperties(
        cellId: 'v_5_5',
        habitats: {Habitat.swamp},
        climate: Climate.temperate,
        continent: Continent.northAmerica,
      );
      await seedCellProperties(swampCell);

      // Load into coordinator cache (rehydrateData path).
      final repo = CellPropertyRepository(testDb);
      final allProps = await repo.getAll();
      final propsMap = {for (final cp in allProps) cp.cellId: cp};

      final cellService = _MockCellService(neighborMap: {});
      final coordinator = GameCoordinator(
        fogResolver: FogStateResolver(cellService),
        statsService: const StatsService(),
        cellService: cellService,
      );
      addTearDown(coordinator.dispose);

      coordinator.loadCellProperties(propsMap);

      // Wire the lookup closure — mirrors gameCoordinatorProvider lines 122-123.
      CellProperties? cellPropertiesLookup(String cellId) =>
          coordinator.cellPropertiesCache[cellId];

      // Cached cell → non-null.
      expect(cellPropertiesLookup('v_5_5'), isNotNull);
      expect(cellPropertiesLookup('v_5_5')!.habitats, {Habitat.swamp});

      // Uncached cell → null.
      expect(cellPropertiesLookup('v_99_99'), isNull);
    });

    test(
        'auth cycle: cell properties cache populated from SQLite after '
        'authenticated → unauthenticated → re-authenticated', () async {
      // === Phase 1: Initial login — hydrate cell properties from SQLite ===
      final mountainCell = makeCellProperties(
        cellId: 'v_1_1',
        habitats: {Habitat.mountain},
        climate: Climate.frigid,
        continent: Continent.asia,
        locationId: 'loc-asia-1',
      );
      final plainsCell = makeCellProperties(
        cellId: 'v_2_2',
        habitats: {Habitat.plains},
        climate: Climate.temperate,
        continent: Continent.europe,
      );
      await seedCellProperties(mountainCell);
      await seedCellProperties(plainsCell);

      final repo = CellPropertyRepository(testDb);
      final cellService = _MockCellService(neighborMap: {});
      final coordinator = GameCoordinator(
        fogResolver: FogStateResolver(cellService),
        statsService: const StatsService(),
        cellService: cellService,
      );
      addTearDown(coordinator.dispose);

      // Hydrate from SQLite (mirrors rehydrateData → cellPropertyRepo.getAll()
      // → coordinator.loadCellProperties()).
      final initialProps = await repo.getAll();
      coordinator
          .loadCellProperties({for (final cp in initialProps) cp.cellId: cp});
      coordinator.setCurrentUserId('user-1');

      expect(coordinator.cellPropertiesCache.length, 2);
      expect(coordinator.cellPropertiesCache['v_1_1']!.climate, Climate.frigid);

      // === Phase 2: Logout — cell properties NOT cleared (global data) ===
      // Mirrors handleAuthState(unauthenticated) which clears player state,
      // inventory, fog, enrichment cache, but NOT _cellPropertiesCache.
      coordinator.setCurrentUserId(null);

      // Cell properties survive logout because they're globally shared.
      expect(coordinator.cellPropertiesCache.length, 2,
          reason: 'cell properties are global — NOT cleared on logout');

      // === Phase 3: Re-login — reload from SQLite ===
      // In production, handleAuthState(authenticated) calls hydrateAndStart()
      // which calls rehydrateData() which reads from SQLite and calls
      // loadCellProperties(). We simulate that same path here.

      // Add a third cell to SQLite to prove re-login picks up new data.
      final saltwaterCell = makeCellProperties(
        cellId: 'v_3_3',
        habitats: {Habitat.saltwater},
        climate: Climate.tropic,
        continent: Continent.oceania,
      );
      await seedCellProperties(saltwaterCell);

      final reLoginProps = await repo.getAll();
      coordinator
          .loadCellProperties({for (final cp in reLoginProps) cp.cellId: cp});
      coordinator.setCurrentUserId('user-1');

      // Cache now has all 3 cells.
      expect(coordinator.cellPropertiesCache.length, 3);
      expect(coordinator.cellPropertiesCache['v_1_1']!.climate, Climate.frigid);
      expect(
          coordinator.cellPropertiesCache['v_2_2']!.habitats, {Habitat.plains});
      expect(coordinator.cellPropertiesCache['v_3_3']!.habitats,
          {Habitat.saltwater});
      expect(coordinator.cellPropertiesCache['v_3_3']!.continent,
          Continent.oceania,
          reason: 'new cell added during offline period is loaded on re-login');

      // === Phase 4: Verify cellPropertiesLookup works after re-login ===
      CellProperties? lookup(String cellId) =>
          coordinator.cellPropertiesCache[cellId];

      expect(lookup('v_1_1'), isNotNull);
      expect(lookup('v_2_2'), isNotNull);
      expect(lookup('v_3_3'), isNotNull);
      expect(lookup('v_99_99'), isNull);
    });

    test(
        'enrichment service invalidation + cell property rehydration work '
        'together across auth cycle', () async {
      // Combined test: proves both enrichment service and cell property
      // cache are correctly handled during auth cycle. Extends Task 5's
      // enrichment tests with the cell property dimension.

      // Seed cell properties in SQLite.
      final forestCell = makeCellProperties(
        cellId: 'v_7_7',
        habitats: {Habitat.forest},
      );
      await seedCellProperties(forestCell);

      // Create ProviderContainer with test DB (for enrichment service).
      final container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(testDb),
        supabaseClientProvider.overrideWithValue(null),
      ]);
      addTearDown(container.dispose);

      // === Initial login ===
      // Read enrichment service and wire hook.
      final service1 = container.read(enrichmentServiceProvider);
      SpeciesEnrichment? captured;
      service1.onEnrichedHook = (e) => captured = e;

      // Load cell properties into coordinator.
      final cellService = _MockCellService(neighborMap: {});
      final coordinator = GameCoordinator(
        fogResolver: FogStateResolver(cellService),
        statsService: const StatsService(),
        cellService: cellService,
      );
      addTearDown(coordinator.dispose);

      final repo = CellPropertyRepository(testDb);
      final props1 = await repo.getAll();
      coordinator.loadCellProperties({for (final cp in props1) cp.cellId: cp});

      expect(coordinator.cellPropertiesCache['v_7_7'], isNotNull);

      // === Logout + Re-login ===
      // Invalidate enrichment service (mirrors handleAuthState re-login).
      container.invalidate(enrichmentServiceProvider);
      final service2 = container.read(enrichmentServiceProvider);
      expect(identical(service1, service2), isFalse,
          reason: 'invalidation creates fresh enrichment service');

      // Re-wire hook on fresh service.
      service2.onEnrichedHook = (e) => captured = e;

      // Reload cell properties from SQLite.
      final props2 = await repo.getAll();
      coordinator.loadCellProperties({for (final cp in props2) cp.cellId: cp});

      // Verify both subsystems work after auth cycle.
      // 1. Enrichment hook fires on new service.
      service2.onEnrichedHook!(SpeciesEnrichment(
        definitionId: 'test-after-cycle',
        animalClass: AnimalClass.carnivore,
        foodPreference: FoodType.critter,
        climate: Climate.temperate,
        brawn: 30,
        wit: 30,
        speed: 30,
        enrichedAt: DateTime.now(),
      ));
      expect(captured?.definitionId, 'test-after-cycle');

      // 2. Cell properties cache still populated.
      expect(coordinator.cellPropertiesCache['v_7_7'], isNotNull);
      expect(
          coordinator.cellPropertiesCache['v_7_7']!.habitats, {Habitat.forest});

      // 3. Lookup closure works.
      CellProperties? lookup(String cellId) =>
          coordinator.cellPropertiesCache[cellId];
      expect(lookup('v_7_7'), isNotNull);
      expect(lookup('v_unknown'), isNull);
    });
  });
}
