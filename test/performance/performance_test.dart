// Performance benchmark tests for critical game-loop paths.
//
// These tests load the REAL production assets (33k species, 509KB biome
// features) and the full 40×40 Voronoi grid to verify acceptable latency
// on commodity hardware. Each test asserts a generous time budget that
// should pass even on low-end devices (3× the typical desktop time).
//
// Run:
//   LD_LIBRARY_PATH=. flutter test test/performance/performance_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:earth_nova/core/cells/lazy_voronoi_cell_service.dart';
import 'package:earth_nova/core/fog/fog_state_resolver.dart';
import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/species/species_repository.dart';
import 'package:earth_nova/core/species/species_repository_native.dart';
import 'package:earth_nova/core/species/species_service.dart';
import 'package:earth_nova/features/world/services/biome_feature_index.dart';
import 'package:earth_nova/features/world/services/biome_service.dart';
import 'package:earth_nova/shared/constants.dart';

/// Helper: times a synchronous [fn] and returns the elapsed Duration.
Duration timeSync(void Function() fn) {
  final sw = Stopwatch()..start();
  fn();
  sw.stop();
  return sw.elapsed;
}

/// Helper: opens the species SQLite DB directly from the assets directory.
SpeciesRepository _openSpeciesDb() {
  final db = sqlite3.open('assets/species.db', mode: OpenMode.readOnly);
  return NativeSpeciesRepository(db);
}

void main() {
  // ── Shared state loaded once ──────────────────────────────────────────────

  late String biomeJson;

  setUpAll(() {
    biomeJson = File('assets/biome_features.json').readAsStringSync();
  });

  // =========================================================================
  // 1. Species Data Loading — 33k records from SQLite DB
  // =========================================================================

  group('Species data loading (33k records)', () {
    test('loads 33k species from SQLite in under 5 seconds', () async {
      final repo = _openSpeciesDb();
      late List records;
      final sw = Stopwatch()..start();
      records = await repo.getAll();
      sw.stop();
      repo.dispose();

      expect(records.length, greaterThanOrEqualTo(30000),
          reason: 'Full dataset should have 30k+ records');
      expect(sw.elapsedMilliseconds, lessThan(5000),
          reason: 'Loading 33k species took ${sw.elapsedMilliseconds}ms');
    });

    test('builds SpeciesService indices in under 3 seconds', () async {
      final repo = _openSpeciesDb();
      final records = await repo.getAll();
      repo.dispose();

      late SpeciesService service;
      final elapsed = timeSync(() {
        service = SpeciesService(records);
      });

      expect(service.totalSpecies, greaterThanOrEqualTo(30000));
      expect(elapsed.inMilliseconds, lessThan(3000),
          reason: 'Index building took ${elapsed.inMilliseconds}ms');
    });
  });

  // =========================================================================
  // 2. Species Lookups — per-cell encounter generation
  // =========================================================================

  group('Species lookup performance', () {
    late SpeciesService service;

    setUpAll(() async {
      final repo = _openSpeciesDb();
      final records = await repo.getAll();
      repo.dispose();
      service = SpeciesService(records);
    });

    test('getSpeciesForCell (single habitat) completes in under 5ms', () {
      // Warm up — first call may lazy-init internal structures.
      service.getSpeciesForCell(
        cellId: 'warmup',
        dailySeed: 'test_seed',
        habitats: {Habitat.forest},
        continent: Continent.northAmerica,
      );

      final sw = Stopwatch()..start();
      const iterations = 1000;
      for (var i = 0; i < iterations; i++) {
        service.getSpeciesForCell(
          cellId: 'perf_cell_$i',
          dailySeed: 'test_seed',
          habitats: {Habitat.forest},
          continent: Continent.northAmerica,
        );
      }
      sw.stop();

      final avgUs = sw.elapsedMicroseconds / iterations;
      expect(avgUs, lessThan(5000),
          reason:
              'Single-habitat lookup averaged ${avgUs.toStringAsFixed(1)}µs');
    });

    test('getSpeciesForCell (3 habitats) completes in under 10ms', () {
      final sw = Stopwatch()..start();
      const iterations = 1000;
      for (var i = 0; i < iterations; i++) {
        service.getSpeciesForCell(
          cellId: 'multi_cell_$i',
          dailySeed: 'test_seed',
          habitats: {Habitat.forest, Habitat.freshwater, Habitat.mountain},
          continent: Continent.europe,
        );
      }
      sw.stop();

      final avgUs = sw.elapsedMicroseconds / iterations;
      expect(avgUs, lessThan(10000),
          reason:
              'Multi-habitat lookup averaged ${avgUs.toStringAsFixed(1)}µs');
    });

    test('getPoolForArea unions correctly with full dataset', () {
      final pool = service.getPoolForArea(
        habitats: {Habitat.forest, Habitat.freshwater},
        continent: Continent.northAmerica,
      );

      // The union should include more species than either habitat alone.
      final forestOnly = service.getPoolForArea(
        habitats: {Habitat.forest},
        continent: Continent.northAmerica,
      );
      final freshwaterOnly = service.getPoolForArea(
        habitats: {Habitat.freshwater},
        continent: Continent.northAmerica,
      );

      expect(pool.length, greaterThanOrEqualTo(forestOnly.length),
          reason: 'Union pool should be >= forest-only pool');
      expect(pool.length, greaterThanOrEqualTo(freshwaterOnly.length),
          reason: 'Union pool should be >= freshwater-only pool');
    });
  });

  // =========================================================================
  // 3. BiomeFeatureIndex — spatial grid loading and queries
  // =========================================================================

  group('BiomeFeatureIndex performance', () {
    test('loads and indexes 509KB biome JSON in under 2 seconds', () {
      late BiomeFeatureIndex index;
      final elapsed = timeSync(() {
        index = BiomeFeatureIndex.load(biomeJson);
      });

      // Smoke check: query a known coastal location (San Francisco).
      final sfBiomes = index.getBiomesNear(37.77, -122.42);
      expect(sfBiomes, isNotEmpty);

      expect(elapsed.inMilliseconds, lessThan(2000),
          reason: 'BiomeFeatureIndex load took ${elapsed.inMilliseconds}ms');
    });

    test('getBiomesNear completes in under 1ms per query (cached)', () {
      final index = BiomeFeatureIndex.load(biomeJson);

      // Cold queries to populate cache.
      index.getBiomesNear(37.77, -122.42);
      index.getBiomesNear(51.5, -0.1);

      final sw = Stopwatch()..start();
      const iterations = 10000;
      for (var i = 0; i < iterations; i++) {
        // Vary coords slightly within the same cache bucket.
        index.getBiomesNear(37.77 + (i % 10) * 0.001, -122.42);
      }
      sw.stop();

      final avgUs = sw.elapsedMicroseconds / iterations;
      expect(avgUs, lessThan(1000),
          reason: 'Cached biome query averaged ${avgUs.toStringAsFixed(1)}µs');
    });

    test('getBiomesNear cold queries complete in under 15ms each', () {
      final index = BiomeFeatureIndex.load(biomeJson);

      // Scatter queries across different 1° grid cells to avoid cache hits.
      final coords = <(double, double)>[
        (37.77, -122.42), // SF (coastal)
        (51.51, -0.13), // London
        (35.68, 139.69), // Tokyo
        (-33.87, 151.21), // Sydney
        (48.86, 2.35), // Paris
        (-22.91, -43.17), // Rio
        (55.75, 37.62), // Moscow
        (30.04, 31.24), // Cairo
        (1.35, 103.82), // Singapore
        (40.71, -74.01), // NYC
        (19.43, -99.13), // Mexico City
        (-1.29, 36.82), // Nairobi
        (28.61, 77.21), // Delhi
        (39.90, 116.41), // Beijing
        (-34.60, -58.38), // Buenos Aires
        (59.33, 18.07), // Stockholm
        (64.15, -21.94), // Reykjavik (remote, should be plains)
        (-37.81, 144.96), // Melbourne
        (25.20, 55.27), // Dubai
        (13.76, 100.50), // Bangkok
      ];

      final sw = Stopwatch()..start();
      for (final (lat, lon) in coords) {
        index.getBiomesNear(lat, lon);
      }
      sw.stop();

      final avgMs = sw.elapsedMilliseconds / coords.length;
      expect(avgMs, lessThan(15),
          reason:
              'Cold biome query averaged ${avgMs.toStringAsFixed(2)}ms over ${coords.length} cities');
    });
  });

  // =========================================================================
  // 4. HabitatService with BiomeFeatureIndex — end-to-end biome classification
  // =========================================================================

  group('HabitatService end-to-end', () {
    test('classifyLocation returns sensible habitats for known locations', () {
      final index = BiomeFeatureIndex.load(biomeJson);
      final service = HabitatService.withFeatureIndex(index);

      // Coastal location (Ocean Beach SF, right on the coast) → should include saltwater.
      final sf = service.classifyLocation(37.76, -122.51);
      expect(sf, contains(Habitat.saltwater),
          reason: 'Ocean Beach SF is on the coast — should detect saltwater');

      // Amazon basin → should include forest.
      final amazon = service.classifyLocation(-3.0, -60.0);
      expect(amazon, contains(Habitat.forest),
          reason: 'Amazon should detect forest');

      // Sahara → should include desert.
      final sahara = service.classifyLocation(25.0, 15.0);
      expect(sahara, contains(Habitat.desert),
          reason: 'Sahara should detect desert');

      // Middle of Kansas → should be plains (no features nearby).
      final kansas = service.classifyLocation(38.5, -98.5);
      expect(kansas, contains(Habitat.plains),
          reason: 'Kansas interior should default to plains');

      // Every location should return at least one habitat.
      for (final biomes in [sf, amazon, sahara, kansas]) {
        expect(biomes, isNotEmpty,
            reason: 'classifyLocation should always return at least 1 habitat');
      }
    });
  });

  // =========================================================================
  // 5. LazyVoronoiCellService — cell resolution and neighbor map
  // =========================================================================

  group('LazyVoronoiCellService performance', () {
    late LazyVoronoiCellService cellService;
    // Use a fixed cell count for iteration bounds (1600 cells in a 40×40 grid).
    const cellCount = 1600;

    setUpAll(() {
      cellService = LazyVoronoiCellService();
    });

    test('getCellId resolves in under 1ms per call', () {
      final sw = Stopwatch()..start();
      const iterations = 1000;
      for (var i = 0; i < iterations; i++) {
        final lat = 45.9 + (i % 40) * 0.002;
        final lon = -66.6 + (i ~/ 40 % 40) * 0.002;
        cellService.getCellId(lat, lon);
      }
      sw.stop();

      final avgUs = sw.elapsedMicroseconds / iterations;
      expect(avgUs, lessThan(1000),
          reason: 'getCellId averaged ${avgUs.toStringAsFixed(1)}µs over '
              '$cellCount cells');
    });

    test('neighbor map builds in under 2 seconds', () {
      // Force a fresh service to time the neighbor computation from scratch.
      final freshService = LazyVoronoiCellService();
      final seedCellId = freshService.getCellId(45.9, -66.6);

      final elapsed = timeSync(() {
        // Trigger neighbor computation.
        freshService.getNeighborIds(seedCellId);
      });

      expect(elapsed.inMilliseconds, lessThan(2000),
          reason: 'Neighbor map build took ${elapsed.inMilliseconds}ms');
    });

    test('getNeighborIds is O(1) after initial build', () {
      // Resolve a set of cell IDs to use as lookup targets.
      final cellIds = List.generate(
        cellCount,
        (i) => cellService.getCellId(
            45.9 + (i % 40) * 0.002, -66.6 + (i ~/ 40 % 40) * 0.002),
      );
      // Warm up the cache.
      cellService.getNeighborIds(cellIds.first);

      final sw = Stopwatch()..start();
      const iterations = 10000;
      for (var i = 0; i < iterations; i++) {
        cellService.getNeighborIds(cellIds[i % cellCount]);
      }
      sw.stop();

      final avgUs = sw.elapsedMicroseconds / iterations;
      expect(avgUs, lessThan(100),
          reason:
              'Cached neighbor lookup averaged ${avgUs.toStringAsFixed(1)}µs');
    });

    test('getCellsInRing(k=2) completes in under 1ms', () {
      // Resolve a set of cell IDs to use as lookup targets.
      final cellIds = List.generate(
        cellCount,
        (i) => cellService.getCellId(
            45.9 + (i % 40) * 0.002, -66.6 + (i ~/ 40 % 40) * 0.002),
      );
      // Warm up the cache.
      cellService.getNeighborIds(cellIds.first);

      final sw = Stopwatch()..start();
      const iterations = 100;
      for (var i = 0; i < iterations; i++) {
        cellService.getCellsInRing(cellIds[i % cellCount], 2);
      }
      sw.stop();

      final avgUs = sw.elapsedMicroseconds / iterations;
      expect(avgUs, lessThan(1000),
          reason: 'getCellsInRing(k=2) averaged ${avgUs.toStringAsFixed(1)}µs');
    });
  });

  // =========================================================================
  // 6. FogStateResolver — bulk fog resolution
  // =========================================================================

  group('FogStateResolver performance', () {
    late LazyVoronoiCellService cellService;
    late FogStateResolver resolver;
    const cellCount = 1600;

    setUp(() {
      cellService = LazyVoronoiCellService();
      resolver = FogStateResolver(cellService);
    });

    tearDown(() {
      resolver.dispose();
    });

    test('onLocationUpdate processes in under 5ms', () {
      final sw = Stopwatch()..start();
      const updates = 100;
      for (var i = 0; i < updates; i++) {
        final lat = 45.9 + (i % 10) * 0.002;
        final lon = -66.6 + (i ~/ 10 % 10) * 0.002;
        resolver.onLocationUpdate(lat, lon);
      }
      sw.stop();

      final avgUs = sw.elapsedMicroseconds / updates;
      expect(avgUs, lessThan(5000),
          reason: 'onLocationUpdate averaged ${avgUs.toStringAsFixed(1)}µs');
    });

    test('resolve() is O(1) per cell', () {
      // Seed some visited cells and frontier.
      resolver.onLocationUpdate(kDefaultMapLat, kDefaultMapLon);

      // Resolve a set of cell IDs to use as lookup targets.
      final cellIds = List.generate(
        cellCount,
        (i) => cellService.getCellId(
            45.9 + (i % 40) * 0.002, -66.6 + (i ~/ 40 % 40) * 0.002),
      );

      final sw = Stopwatch()..start();
      const iterations = 10000;
      for (var i = 0; i < iterations; i++) {
        resolver.resolve(cellIds[i % cellCount]);
      }
      sw.stop();

      final avgUs = sw.elapsedMicroseconds / iterations;
      expect(avgUs, lessThan(100),
          reason: 'resolve() averaged ${avgUs.toStringAsFixed(1)}µs');
    });

    test('loadVisitedCells with 500 cells completes in under 2 seconds', () {
      // Simulate a player who has visited 500 cells (heavy user).
      // Build IDs directly using v_{row}_{col} format (25×20 grid around
      // Fredericton) to guarantee exactly 500 unique cell IDs.
      const baseRow = 22950; // (45.9 / 0.002).floor()
      const baseCol = -33300; // (-66.6 / 0.002).floor()
      final visited = Set<String>.from(List.generate(
        500,
        (i) => 'v_${baseRow + i % 25}_${baseCol + i ~/ 25}',
      ));

      final elapsed = timeSync(() {
        resolver.loadVisitedCells(visited);
      });

      expect(resolver.visitedCellIds.length, equals(500));
      expect(elapsed.inMilliseconds, lessThan(2000),
          reason: 'loadVisitedCells(500) took ${elapsed.inMilliseconds}ms');
    });
  });

  // =========================================================================
  // 7. End-to-end discovery pipeline
  // =========================================================================

  group('End-to-end discovery pipeline', () {
    late SpeciesService endToEndSpeciesService;

    setUpAll(() async {
      final repo = _openSpeciesDb();
      final records = await repo.getAll();
      repo.dispose();
      endToEndSpeciesService = SpeciesService(records);
    });

    test(
        'full pipeline (locate → biome → species → loot) completes in under 50ms',
        () {
      final cellService = LazyVoronoiCellService();
      final biomeIndex = BiomeFeatureIndex.load(biomeJson);
      final habitatService = HabitatService.withFeatureIndex(biomeIndex);
      final speciesService = endToEndSpeciesService;

      // Warm up Voronoi neighbor cache.
      final warmupId = cellService.getCellId(45.9, -66.6);
      cellService.getNeighborIds(warmupId);

      // Simulate the exact sequence that fires on each new cell entry.
      final sw = Stopwatch()..start();
      const iterations = 100;
      for (var i = 0; i < iterations; i++) {
        final lat = 45.9 + (i % 10) * 0.002;
        final lon = -66.6 + (i ~/ 10 % 10) * 0.002;

        // 1. Resolve cell ID from GPS coordinates.
        final cellId = cellService.getCellId(lat, lon);

        // 2. Get cell center.
        final center = cellService.getCellCenter(cellId);

        // 3. Classify biomes near cell center.
        final habitats =
            habitatService.classifyLocation(center.lat, center.lon);

        // 4. Roll species encounters.
        speciesService.getSpeciesForCell(
          cellId: cellId,
          dailySeed: 'test_seed',
          habitats: habitats,
          continent: Continent.northAmerica,
        );
      }
      sw.stop();

      final avgMs = sw.elapsedMicroseconds / iterations / 1000;
      expect(avgMs, lessThan(50),
          reason:
              'Full discovery pipeline averaged ${avgMs.toStringAsFixed(2)}ms '
              'per cell entry');
    });
  });
}
