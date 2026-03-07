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
import 'package:fog_of_world/core/cells/voronoi_cell_service.dart';
import 'package:fog_of_world/core/fog/fog_state_resolver.dart';
import 'package:fog_of_world/core/models/continent.dart';
import 'package:fog_of_world/core/models/habitat.dart';
import 'package:fog_of_world/core/species/species_data_loader.dart';
import 'package:fog_of_world/core/species/species_service.dart';
import 'package:fog_of_world/features/biome/services/biome_feature_index.dart';
import 'package:fog_of_world/features/biome/services/biome_service.dart';
import 'package:fog_of_world/shared/constants.dart';

/// Helper: times a synchronous [fn] and returns the elapsed Duration.
Duration timeSync(void Function() fn) {
  final sw = Stopwatch()..start();
  fn();
  sw.stop();
  return sw.elapsed;
}

void main() {
  // ── Shared state loaded once ──────────────────────────────────────────────

  late String speciesJson;
  late String biomeJson;

  setUpAll(() {
    speciesJson = File('assets/species_data.json').readAsStringSync();
    biomeJson = File('assets/biome_features.json').readAsStringSync();
  });

  // =========================================================================
  // 1. Species Data Loading — 33k records from 6 MB JSON
  // =========================================================================

  group('Species data loading (33k records)', () {
    test('parses 33k species JSON in under 5 seconds', () {
      late List records;
      final elapsed = timeSync(() {
        records = SpeciesDataLoader.fromJsonString(speciesJson);
      });

      expect(records.length, greaterThanOrEqualTo(30000),
          reason: 'Full dataset should have 30k+ records');
      expect(elapsed.inMilliseconds, lessThan(5000),
          reason: 'Parsing 33k species took ${elapsed.inMilliseconds}ms');
    });

    test('builds SpeciesService indices in under 3 seconds', () {
      final records = SpeciesDataLoader.fromJsonString(speciesJson);

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

    setUpAll(() {
      final records = SpeciesDataLoader.fromJsonString(speciesJson);
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

      expect(pool.length,
          greaterThanOrEqualTo(forestOnly.length),
          reason: 'Union pool should be >= forest-only pool');
      expect(pool.length,
          greaterThanOrEqualTo(freshwaterOnly.length),
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
          reason:
              'Cached biome query averaged ${avgUs.toStringAsFixed(1)}µs');
    });

    test('getBiomesNear cold queries complete in under 5ms each', () {
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
      expect(avgMs, lessThan(5),
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
  // 5. VoronoiCellService — cell resolution and neighbor map
  // =========================================================================

  group('VoronoiCellService performance (40×40 = 1600 cells)', () {
    late VoronoiCellService cellService;

    setUpAll(() {
      cellService = VoronoiCellService(
        minLat: kVoronoiMinLat,
        maxLat: kVoronoiMaxLat,
        minLon: kVoronoiMinLon,
        maxLon: kVoronoiMaxLon,
        gridRows: kVoronoiGridRows,
        gridCols: kVoronoiGridCols,
        seed: kVoronoiSeed,
      );
    });

    test('getCellId resolves in under 1ms per call', () {
      final sw = Stopwatch()..start();
      const iterations = 1000;
      for (var i = 0; i < iterations; i++) {
        final lat = kVoronoiMinLat +
            (kVoronoiMaxLat - kVoronoiMinLat) * (i % 40) / 40;
        final lon = kVoronoiMinLon +
            (kVoronoiMaxLon - kVoronoiMinLon) * (i ~/ 40 % 40) / 40;
        cellService.getCellId(lat, lon);
      }
      sw.stop();

      final avgUs = sw.elapsedMicroseconds / iterations;
      expect(avgUs, lessThan(1000),
          reason: 'getCellId averaged ${avgUs.toStringAsFixed(1)}µs over '
              '${cellService.cellCount} cells');
    });

    test('neighbor map builds in under 2 seconds', () {
      // Force a fresh service to time the neighbor map build from scratch.
      final freshService = VoronoiCellService(
        minLat: kVoronoiMinLat,
        maxLat: kVoronoiMaxLat,
        minLon: kVoronoiMinLon,
        maxLon: kVoronoiMaxLon,
        gridRows: kVoronoiGridRows,
        gridCols: kVoronoiGridCols,
        seed: kVoronoiSeed,
      );

      final elapsed = timeSync(() {
        // Trigger neighbor map build.
        freshService.getNeighborIds('0');
      });

      expect(elapsed.inMilliseconds, lessThan(2000),
          reason: 'Neighbor map build took ${elapsed.inMilliseconds}ms');
    });

    test('getNeighborIds is O(1) after initial build', () {
      // Ensure neighbor map is built.
      cellService.getNeighborIds('0');

      final sw = Stopwatch()..start();
      const iterations = 10000;
      for (var i = 0; i < iterations; i++) {
        cellService.getNeighborIds((i % cellService.cellCount).toString());
      }
      sw.stop();

      final avgUs = sw.elapsedMicroseconds / iterations;
      expect(avgUs, lessThan(100),
          reason: 'Cached neighbor lookup averaged ${avgUs.toStringAsFixed(1)}µs');
    });

    test('getCellsInRing(k=2) completes in under 1ms', () {
      // Ensure neighbor map is built.
      cellService.getNeighborIds('0');

      final sw = Stopwatch()..start();
      const iterations = 100;
      for (var i = 0; i < iterations; i++) {
        cellService.getCellsInRing(
            (i % cellService.cellCount).toString(), 2);
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
    late VoronoiCellService cellService;
    late FogStateResolver resolver;

    setUp(() {
      cellService = VoronoiCellService(
        minLat: kVoronoiMinLat,
        maxLat: kVoronoiMaxLat,
        minLon: kVoronoiMinLon,
        maxLon: kVoronoiMaxLon,
        gridRows: kVoronoiGridRows,
        gridCols: kVoronoiGridCols,
        seed: kVoronoiSeed,
      );
      resolver = FogStateResolver(cellService);
    });

    tearDown(() {
      resolver.dispose();
    });

    test('onLocationUpdate processes in under 5ms', () {
      final sw = Stopwatch()..start();
      const updates = 100;
      for (var i = 0; i < updates; i++) {
        final lat = kVoronoiMinLat +
            (kVoronoiMaxLat - kVoronoiMinLat) * (i % 10) / 10;
        final lon = kVoronoiMinLon +
            (kVoronoiMaxLon - kVoronoiMinLon) * (i ~/ 10 % 10) / 10;
        resolver.onLocationUpdate(lat, lon);
      }
      sw.stop();

      final avgUs = sw.elapsedMicroseconds / updates;
      expect(avgUs, lessThan(5000),
          reason:
              'onLocationUpdate averaged ${avgUs.toStringAsFixed(1)}µs');
    });

    test('resolve() is O(1) per cell', () {
      // Seed some visited cells and frontier.
      resolver.onLocationUpdate(kDefaultMapLat, kDefaultMapLon);

      final sw = Stopwatch()..start();
      const iterations = 10000;
      for (var i = 0; i < iterations; i++) {
        resolver.resolve((i % cellService.cellCount).toString());
      }
      sw.stop();

      final avgUs = sw.elapsedMicroseconds / iterations;
      expect(avgUs, lessThan(100),
          reason: 'resolve() averaged ${avgUs.toStringAsFixed(1)}µs');
    });

    test('loadVisitedCells with 500 cells completes in under 2 seconds', () {
      // Simulate a player who has visited 500 cells (heavy user).
      final visited =
          Set<String>.from(List.generate(500, (i) => i.toString()));

      final elapsed = timeSync(() {
        resolver.loadVisitedCells(visited);
      });

      expect(resolver.visitedCellIds.length, equals(500));
      expect(elapsed.inMilliseconds, lessThan(2000),
          reason:
              'loadVisitedCells(500) took ${elapsed.inMilliseconds}ms');
    });
  });

  // =========================================================================
  // 7. End-to-end discovery pipeline
  // =========================================================================

  group('End-to-end discovery pipeline', () {
    test(
        'full pipeline (locate → biome → species → loot) completes in under 50ms',
        () {
      final cellService = VoronoiCellService(
        minLat: kVoronoiMinLat,
        maxLat: kVoronoiMaxLat,
        minLon: kVoronoiMinLon,
        maxLon: kVoronoiMaxLon,
        gridRows: kVoronoiGridRows,
        gridCols: kVoronoiGridCols,
        seed: kVoronoiSeed,
      );
      final biomeIndex = BiomeFeatureIndex.load(biomeJson);
      final habitatService = HabitatService.withFeatureIndex(biomeIndex);
      final records = SpeciesDataLoader.fromJsonString(speciesJson);
      final speciesService = SpeciesService(records);

      // Warm up Voronoi neighbor map.
      cellService.getNeighborIds('0');

      // Simulate the exact sequence that fires on each new cell entry.
      final sw = Stopwatch()..start();
      const iterations = 100;
      for (var i = 0; i < iterations; i++) {
        final lat = kVoronoiMinLat +
            (kVoronoiMaxLat - kVoronoiMinLat) * (i % 10) / 10;
        final lon = kVoronoiMinLon +
            (kVoronoiMaxLon - kVoronoiMinLon) * (i ~/ 10 % 10) / 10;

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
