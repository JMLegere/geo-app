// ignore_for_file: avoid_redundant_argument_values

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/data/database.dart';
import 'package:earth_nova/data/repos/item_repo.dart';
import 'package:earth_nova/data/repos/write_queue_repo.dart';
import 'package:earth_nova/domain/fog/fog_resolver.dart';
import 'package:earth_nova/domain/species/encounter_roller.dart';
import 'package:earth_nova/domain/species/loot_table.dart';
import 'package:earth_nova/domain/species/species_cache.dart';
import 'package:earth_nova/domain/species/species_repository.dart';
import 'package:earth_nova/engine/engine_input.dart';
import 'package:earth_nova/engine/game_engine.dart';
import 'package:earth_nova/models/cell_properties.dart';
import 'package:earth_nova/models/climate.dart';
import 'package:earth_nova/models/continent.dart';
import 'package:earth_nova/models/habitat.dart';
import 'package:earth_nova/models/item_definition.dart';
import 'package:earth_nova/models/iucn_status.dart';

import '../fixtures/test_helpers.dart';

// ---------------------------------------------------------------------------
// Mock species repository for cache tests
// ---------------------------------------------------------------------------

class _MockSpeciesRepo implements SpeciesRepository {
  final List<FaunaDefinition> _all;
  _MockSpeciesRepo(this._all);

  @override
  Future<List<FaunaDefinition>> getCandidates({
    required Set<Habitat> habitats,
    required Continent continent,
  }) async {
    return _all
        .where((s) =>
            s.habitats.any(habitats.contains) &&
            s.continents.contains(continent))
        .toList();
  }

  @override
  Future<List<FaunaDefinition>> getByIds(List<String> ids) async {
    final idSet = ids.toSet();
    return _all.where((s) => idSet.contains(s.id)).toList();
  }

  @override
  Future<int> count() async => _all.length;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Build a list of [n] FaunaDefinitions with forest/europe.
List<FaunaDefinition> _buildSpeciesList(int n) {
  return List.generate(
    n,
    (i) => FaunaDefinition(
      id: 'fauna_species_$i',
      displayName: 'Species $i',
      scientificName: 'Species scientifica $i',
      taxonomicClass: (i % 2 == 0) ? 'Mammalia' : 'Aves',
      rarity: IucnStatus.values[i % IucnStatus.values.length],
      habitats: [Habitat.forest],
      continents: [Continent.europe],
    ),
  );
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // ---------------------------------------------------------------------------
  // LootTable performance
  // ---------------------------------------------------------------------------

  group('LootTable performance', () {
    test('building table with 1000 entries completes in < 10ms', () {
      final entries = List.generate(1000, (i) => ('item_$i', (i % 243) + 1));
      final sw = Stopwatch()..start();
      final table = LootTable<String>(entries);
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(10),
          reason: 'LootTable build must be < 10ms');
      expect(table.length, 1000);
    });

    test('rolling 100 times from 1000-entry table completes in < 100ms', () {
      final entries = List.generate(1000, (i) => ('item_$i', (i % 243) + 1));
      final table = LootTable<String>(entries);

      final sw = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        table.roll('seed_$i');
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(100),
          reason: '100 rolls must complete in < 100ms');
    });

    test('rollMultiple(10) from 1000-entry table completes in < 10ms', () {
      final entries = List.generate(1000, (i) => ('item_$i', (i % 243) + 1));
      final table = LootTable<String>(entries);

      final sw = Stopwatch()..start();
      final results = table.rollMultiple('base_seed', 10);
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(10));
      expect(results.length, 10);
    });
  });

  // ---------------------------------------------------------------------------
  // SpeciesService (in-memory mode) performance
  // ---------------------------------------------------------------------------

  group('SpeciesService performance', () {
    test('getCandidates (getSpeciesForCell) from 1000-species pool in < 50ms',
        () {
      final species = _buildSpeciesList(1000);
      final svc = SpeciesService(species);

      final sw = Stopwatch()..start();
      final results = svc.getSpeciesForCell(
        cellId: kTestCellA,
        dailySeed: kTestDailySeed,
        habitats: {Habitat.forest},
        continent: Continent.europe,
      );
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(50),
          reason: 'getSpeciesForCell from 1000 species < 50ms');
      expect(results, isNotEmpty);
    });

    test('building SpeciesService with 1000 species (index build) in < 100ms',
        () {
      final species = _buildSpeciesList(1000);

      final sw = Stopwatch()..start();
      final svc = SpeciesService(species);
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(100),
          reason: 'Index build for 1000 species < 100ms');
      expect(svc.totalSpecies, 1000);
    });
  });

  // ---------------------------------------------------------------------------
  // SpeciesCache performance
  // ---------------------------------------------------------------------------

  group('SpeciesCache performance', () {
    test('warmUp with 1000 species completes in < 500ms', () async {
      final species = _buildSpeciesList(1000);
      final repo = _MockSpeciesRepo(species);
      final cache = SpeciesCache(repo);

      final sw = Stopwatch()..start();
      await cache
          .warmUp(habitats: {Habitat.forest}, continent: Continent.europe);
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(500),
          reason: 'Cache warmUp with 1000 species < 500ms');
    });

    test('getCandidatesSync lookup after warmUp completes in < 10ms', () async {
      final species = _buildSpeciesList(1000);
      final repo = _MockSpeciesRepo(species);
      final cache = SpeciesCache(repo);

      await cache
          .warmUp(habitats: {Habitat.forest}, continent: Continent.europe);

      final sw = Stopwatch()..start();
      for (var i = 0; i < 1000; i++) {
        cache.getCandidatesSync(
            habitats: {Habitat.forest}, continent: Continent.europe);
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(10),
          reason: '1000 sync lookups < 10ms after warmUp');
    });

    test('SpeciesCache with 2000 entries does not OOM', () async {
      final species = _buildSpeciesList(2000);
      final repo = _MockSpeciesRepo(species);
      final cache = SpeciesCache(repo);
      await cache
          .warmUp(habitats: {Habitat.forest}, continent: Continent.europe);
      // Verify it loaded correctly — no OOM.
      final results = cache.getCandidatesSync(
          habitats: {Habitat.forest}, continent: Continent.europe);
      expect(results, isNotEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // FogStateResolver performance
  // ---------------------------------------------------------------------------

  group('FogStateResolver performance', () {
    test('resolve() for 100 cells completes in < 50ms', () {
      final svc = MockCellService();
      for (var i = 0; i < 100; i++) {
        svc.addCell(
            id: 'fog_cell_$i', lat: kTestLat + i * 0.001, lon: kTestLon);
      }
      final fogResolver = FogStateResolver(svc);
      fogResolver.onLocationUpdate(kTestLat, kTestLon);

      final sw = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        fogResolver.resolve('fog_cell_$i');
      }
      sw.stop();
      fogResolver.dispose();
      expect(sw.elapsedMilliseconds, lessThan(50));
    });

    test('onLocationUpdate with 500 visited cells completes in < 100ms', () {
      final svc = MockCellService();
      for (var i = 0; i < 500; i++) {
        svc.addCell(
            id: 'visited_$i',
            lat: kTestLat + i * 0.001,
            lon: kTestLon,
            neighbors: i > 0 ? ['visited_${i - 1}'] : []);
      }
      final fogResolver = FogStateResolver(svc);
      final visitedSet = {for (var i = 0; i < 500; i++) 'visited_$i'};
      fogResolver.loadVisitedCells(visitedSet);
      final sw = Stopwatch()..start();
      fogResolver.onLocationUpdate(kTestLat, kTestLon);
      sw.stop();
      fogResolver.dispose();
      expect(sw.elapsedMilliseconds, lessThan(100));
    });

    test('onLocationUpdate with 2000 visited cells completes in < 500ms', () {
      final svc = MockCellService();
      for (var i = 0; i < 2000; i++) {
        svc.addCell(
            id: 'big_$i',
            lat: kTestLat + i * 0.0005,
            lon: kTestLon,
            neighbors: i > 0 ? ['big_${i - 1}'] : []);
      }
      final fogResolver = FogStateResolver(svc);
      fogResolver.loadVisitedCells({for (var i = 0; i < 2000; i++) 'big_$i'});

      final sw = Stopwatch()..start();
      fogResolver.onLocationUpdate(kTestLat, kTestLon);
      sw.stop();
      fogResolver.dispose();
      expect(sw.elapsedMilliseconds, lessThan(500));
    });

    test('FogResolver with 5000 visited cells does not OOM', () {
      final svc = MockCellService();
      for (var i = 0; i < 5000; i++) {
        svc.addCell(id: 'oom_$i', lat: kTestLat + i * 0.0001, lon: kTestLon);
      }
      final fogResolver = FogStateResolver(svc);
      fogResolver.loadVisitedCells({for (var i = 0; i < 5000; i++) 'oom_$i'});
      fogResolver.onLocationUpdate(kTestLat, kTestLon);
      // Verify it resolves without crash.
      final state = fogResolver.resolve('oom_0');
      fogResolver.dispose();
      expect(state, isNotNull);
    });

    test(
        'frontier management: 1000 cells visited sequentially completes in < 1s',
        () {
      final svc = MockCellService();
      for (var i = 0; i < 1000; i++) {
        svc.addCell(
          id: 'frontier_$i',
          lat: kTestLat + i * 0.001,
          lon: kTestLon,
          neighbors: [
            if (i > 0) 'frontier_${i - 1}',
            if (i < 999) 'frontier_${i + 1}',
          ],
        );
      }
      final fogResolver = FogStateResolver(svc);

      final sw = Stopwatch()..start();
      for (var i = 0; i < 1000; i++) {
        fogResolver.onLocationUpdate(kTestLat + i * 0.001, kTestLon);
      }
      sw.stop();
      fogResolver.dispose();
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });
  });

  // ---------------------------------------------------------------------------
  // MockCellService (stand-in for cell service) performance
  // ---------------------------------------------------------------------------

  group('CellService performance (MockCellService with 100 cells)', () {
    late MockCellService svc;

    setUpAll(() {
      svc = MockCellService();
      for (var i = 0; i < 100; i++) {
        svc.addCell(
          id: 'cs_$i',
          lat: kTestLat + i * 0.01,
          lon: kTestLon,
          neighbors: [
            if (i > 0) 'cs_${i - 1}',
            if (i < 99) 'cs_${i + 1}',
          ],
        );
      }
    });

    test('getCellId for 100 different positions completes in < 100ms', () {
      final sw = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        svc.getCellId(kTestLat + i * 0.01, kTestLon);
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(100));
    });

    test('getCellCenter for 100 cells completes in < 50ms', () {
      final sw = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        svc.getCellCenter('cs_$i');
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(50));
    });

    test('getCellBoundary for 100 cells completes in < 200ms', () {
      final sw = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        svc.getCellBoundary('cs_$i');
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(200));
    });

    test('getNeighborIds for 100 cells completes in < 200ms', () {
      final sw = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        svc.getNeighborIds('cs_$i');
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(200));
    });
  });

  // ---------------------------------------------------------------------------
  // GameEngine throughput
  // ---------------------------------------------------------------------------

  group('GameEngine throughput', () {
    test('process 100 PositionUpdate inputs completes in < 200ms', () {
      final svc = buildStarGrid();
      final fog = FogStateResolver(svc);
      final engine = GameEngine(fogResolver: fog, cellService: svc);
      engine.start();

      final sw = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        engine.send(PositionUpdate(kTestLat + i * 0.001, kTestLon));
      }
      sw.stop();
      engine.dispose();
      fog.dispose();
      expect(sw.elapsedMilliseconds, lessThan(200));
    });

    test(
        'engine with 1000 visited cells: single position update completes in < 5ms',
        () {
      final svc = MockCellService();
      for (var i = 0; i < 1001; i++) {
        svc.addCell(id: 'eng_$i', lat: kTestLat + i * 0.001, lon: kTestLon);
      }
      final fog = FogStateResolver(svc);
      fog.loadVisitedCells({for (var i = 0; i < 1000; i++) 'eng_$i'});
      final engine = GameEngine(fogResolver: fog, cellService: svc);
      engine.loadCellProperties({
        'eng_1000': CellProperties(
          cellId: 'eng_1000',
          habitats: {Habitat.forest},
          climate: Climate.temperate,
          continent: Continent.europe,
          locationId: null,
          createdAt: DateTime(2026, 1, 1),
        )
      });
      engine.start();

      // Warm up the engine.
      engine.send(PositionUpdate(kTestLat, kTestLon));

      // Now measure a single update at the end of the visited range.
      final sw = Stopwatch()..start();
      engine.send(PositionUpdate(kTestLat + 1000 * 0.001, kTestLon));
      sw.stop();
      engine.dispose();
      fog.dispose();
      expect(sw.elapsedMilliseconds, lessThan(5));
    });
  });

  // ---------------------------------------------------------------------------
  // Database performance
  // ---------------------------------------------------------------------------

  group('Database performance', () {
    late AppDatabase db;
    late ItemRepo itemRepo;
    late WriteQueueRepo writeQueueRepo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      itemRepo = ItemRepo(db);
      writeQueueRepo = WriteQueueRepo(db);
    });

    tearDown(() async => db.close());

    test('insert 100 items completes in < 500ms', () async {
      final sw = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        await itemRepo.create(ItemsTableCompanion.insert(
          id: 'perf-item-$i',
          userId: 'perf-user',
          definitionId: 'fauna_$i',
          acquiredAt: DateTime(2026, 1, 1),
          displayName: Value('Species $i'),
        ));
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(500),
          reason: '100 inserts < 500ms');
    });

    test('query all items for user with 100 items completes in < 50ms',
        () async {
      for (var i = 0; i < 100; i++) {
        await itemRepo.create(ItemsTableCompanion.insert(
          id: 'qperf-item-$i',
          userId: 'qperf-user',
          definitionId: 'fauna_$i',
          acquiredAt: DateTime(2026, 1, 1),
        ));
      }

      final sw = Stopwatch()..start();
      final items = await itemRepo.getAll('qperf-user');
      sw.stop();
      expect(items.length, 100);
      expect(sw.elapsedMilliseconds, lessThan(50),
          reason: 'getAll for 100 items < 50ms');
    });

    test('bulk write queue: enqueue 50 + countPending completes in < 200ms',
        () async {
      final sw = Stopwatch()..start();
      for (var i = 0; i < 50; i++) {
        await writeQueueRepo.enqueue(WriteQueueTableCompanion.insert(
          entityType: 'itemInstance',
          entityId: 'wq-item-$i',
          operation: 'upsert',
          payload: '{"id":"wq-item-$i"}',
          userId: 'wq-user',
        ));
      }
      final count = await writeQueueRepo.countPending(userId: 'wq-user');
      sw.stop();
      expect(count, 50);
      expect(sw.elapsedMilliseconds, lessThan(200),
          reason: 'Enqueue 50 + count < 200ms');
    });
  });
}
