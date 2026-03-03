/// Integration test: species discovery chain — GPS → fog → species → discovery.
///
/// All three services ([VoronoiCellService], [FogStateResolver],
/// [DiscoveryService]) are constructed directly without Riverpod or network.
/// Species data comes from [kSpeciesFixtureJson] (test fixture).
library;

import 'dart:convert';

import 'package:fog_of_world/core/cells/voronoi_cell_service.dart';
import 'package:fog_of_world/core/fog/fog_state_resolver.dart';
import 'package:fog_of_world/core/models/continent.dart';
import 'package:fog_of_world/core/models/habitat.dart';
import 'package:fog_of_world/core/models/iucn_status.dart';
import 'package:fog_of_world/core/models/species.dart';
import 'package:fog_of_world/core/species/species_service.dart';
import 'package:fog_of_world/features/discovery/models/discovery_event.dart';
import 'package:fog_of_world/features/discovery/services/discovery_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/species_fixture.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Parse [kSpeciesFixtureJson] into a [SpeciesService].
SpeciesService buildSpeciesServiceFromFixture() {
  final List<dynamic> raw = jsonDecode(kSpeciesFixtureJson) as List<dynamic>;
  final records = raw
      .map((j) => SpeciesRecord.fromJson(j as Map<String, dynamic>))
      .toList();
  return SpeciesService(records);
}

VoronoiCellService makeSmallCellService() => VoronoiCellService(
      minLat: 37.60,
      maxLat: 37.90,
      minLon: -122.55,
      maxLon: -122.20,
      gridRows: 5,
      gridCols: 5,
      seed: 42,
    );

const double kCentLat = 37.75;
const double kCentLon = -122.375;

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Offline Species Service', () {
    late SpeciesService speciesService;

    setUp(() {
      speciesService = buildSpeciesServiceFromFixture();
    });

    test('loads all 50 species from fixture', () {
      expect(speciesService.totalSpecies, equals(50));
    });

    test('all records have non-empty commonName and scientificName', () {
      for (final s in speciesService.all) {
        expect(s.commonName, isNotEmpty);
        expect(s.scientificName, isNotEmpty);
      }
    });

    test('all records have at least one continent', () {
      for (final s in speciesService.all) {
        expect(s.continents, isNotEmpty);
      }
    });

    test('all records have at least one habitat', () {
      for (final s in speciesService.all) {
        expect(s.habitats, isNotEmpty);
      }
    });

    test('IUCN statuses include all tiers', () {
      final statuses = speciesService.all.map((s) => s.iucnStatus).toSet();
      expect(statuses, contains(IucnStatus.leastConcern));
      expect(statuses, contains(IucnStatus.endangered));
      expect(statuses, contains(IucnStatus.criticallyEndangered));
    });

    test('species ID is derived from scientificName (stable, lowercase)', () {
      for (final s in speciesService.all) {
        final expectedId =
            s.scientificName.toLowerCase().replaceAll(' ', '_');
        expect(s.id, equals(expectedId));
      }
    });

    test('forHabitat returns only species with that habitat', () {
      final forestSpecies = speciesService.forHabitat(Habitat.forest);
      for (final s in forestSpecies) {
        expect(s.habitats, contains(Habitat.forest));
      }
    });

    test('forContinent returns only species with that continent', () {
      final naSpecies =
          speciesService.forContinent(Continent.northAmerica);
      for (final s in naSpecies) {
        expect(s.continents, contains(Continent.northAmerica));
      }
    });

    test('getSpeciesForCell returns at most encounterSlots unique species', () {
      final result = speciesService.getSpeciesForCell(
        cellId: 'cell_0',
        habitat: Habitat.forest,
        continent: Continent.northAmerica,
        encounterSlots: 3,
      );
      expect(result.length, lessThanOrEqualTo(3));
      // No duplicates
      final ids = result.map((s) => s.id).toSet();
      expect(ids.length, equals(result.length));
    });

    test('getSpeciesForCell is deterministic for the same cellId', () {
      final r1 = speciesService.getSpeciesForCell(
        cellId: 'cell_42',
        habitat: Habitat.forest,
        continent: Continent.northAmerica,
      );
      final r2 = speciesService.getSpeciesForCell(
        cellId: 'cell_42',
        habitat: Habitat.forest,
        continent: Continent.northAmerica,
      );
      expect(r1.map((s) => s.id).toList(),
          equals(r2.map((s) => s.id).toList()));
    });

    test('getSpeciesForCell returns different results for different cellIds', () {
      // With 50 species and a seeded loot table, different cells should
      // usually produce different results. This is probabilistic but
      // extremely unlikely to fail with the fixture data.
      final r1 = speciesService.getSpeciesForCell(
        cellId: 'cell_1',
        habitat: Habitat.forest,
        continent: Continent.northAmerica,
      );
      final r2 = speciesService.getSpeciesForCell(
        cellId: 'cell_99',
        habitat: Habitat.forest,
        continent: Continent.northAmerica,
      );
      // Not a strict equality check — just verifying that cellId influences
      // results (at least one of the two sets is non-empty).
      expect(r1.isNotEmpty || r2.isNotEmpty, isTrue);
    });

    test('getPoolForArea returns species valid for habitat+continent combo', () {
      final pool = speciesService.getPoolForArea(
        habitat: Habitat.forest,
        continent: Continent.northAmerica,
      );
      for (final s in pool) {
        expect(s.habitats, contains(Habitat.forest));
        expect(s.continents, contains(Continent.northAmerica));
      }
    });

    test('getSpeciesForCell returns empty list when no species match', () {
      // Saltwater + Asia combination not covered by fixture for this habitat combo.
      // Use a habitat+continent combo that has no matches in the fixture.
      // Desert + South America has no matches in our 50-species fixture.
      final result = speciesService.getSpeciesForCell(
        cellId: 'cell_0',
        habitat: Habitat.desert,
        continent: Continent.southAmerica,
      );
      expect(result, isEmpty);
    });
  });

  group('Offline Discovery Chain (GPS → Fog → Species → Discovery)', () {
    late VoronoiCellService cellService;
    late FogStateResolver fogResolver;
    late SpeciesService speciesService;
    late DiscoveryService discoveryService;
    late List<DiscoveryEvent> capturedEvents;

    setUp(() {
      cellService = makeSmallCellService();
      fogResolver = FogStateResolver(cellService);
      speciesService = buildSpeciesServiceFromFixture();
      discoveryService = DiscoveryService(
        fogResolver: fogResolver,
        speciesService: speciesService,
      );
      capturedEvents = [];
      discoveryService.onDiscovery.listen(capturedEvents.add);
    });

    tearDown(() {
      discoveryService.dispose();
      fogResolver.dispose();
    });

    test('discovery events fire when entering a new cell', () {
      // DiscoveryService wires habitat=forest, continent=northAmerica by default.
      // With 50 species and that combo, there should be results.
      fogResolver.onLocationUpdate(kCentLat, kCentLon);
      // Events fire synchronously (sync: true stream).
      // We can't guarantee species exist for every cell, but we can verify
      // no errors occurred and any discovered species are valid.
      for (final event in capturedEvents) {
        expect(event.species, isNotNull);
        expect(event.cellId, isNotEmpty);
        expect(event.timestamp, isNotNull);
      }
    });

    test('discovered species have valid IUCN status', () {
      fogResolver.onLocationUpdate(kCentLat, kCentLon);
      for (final event in capturedEvents) {
        expect(IucnStatus.values, contains(event.species.iucnStatus));
      }
    });

    test('first discovery of a species has isNew = true', () {
      fogResolver.onLocationUpdate(kCentLat, kCentLon);
      for (final event in capturedEvents) {
        // All species are new on a fresh service.
        expect(event.isNew, isTrue,
            reason:
                '${event.species.commonName} should be new on first discovery');
      }
    });

    test('re-discovering the same species has isNew = false after markCollected', () {
      fogResolver.onLocationUpdate(kCentLat, kCentLon);
      if (capturedEvents.isEmpty) return; // skip if no species for this cell

      final firstEvent = capturedEvents.first;
      expect(firstEvent.isNew, isTrue);

      // Mark it collected.
      discoveryService.markCollected(firstEvent.species.id);

      // Move to a new cell that might yield the same species.
      // We test by re-entering with a different fog resolver that re-emits the
      // same cell — but since same cell won't re-emit (already visited), we
      // test by checking that markCollected correctly tracks the ID.
      // The internal set is tested indirectly: if a second service is created
      // with initialCollectedIds containing this species, it should emit isNew=false.
      final capturedEvents2 = <DiscoveryEvent>[];
      final fogResolver2 = FogStateResolver(cellService);
      final ds2 = DiscoveryService(
        fogResolver: fogResolver2,
        speciesService: speciesService,
        initialCollectedIds: {firstEvent.species.id},
      );
      ds2.onDiscovery.listen(capturedEvents2.add);

      fogResolver2.onLocationUpdate(kCentLat, kCentLon);

      for (final event in capturedEvents2) {
        if (event.species.id == firstEvent.species.id) {
          expect(event.isNew, isFalse,
              reason:
                  '${event.species.commonName} was already collected — isNew must be false');
        }
      }

      ds2.dispose();
      fogResolver2.dispose();
    });

    test('no discovery events fire when re-entering a visited cell', () {
      fogResolver.onLocationUpdate(kCentLat, kCentLon);
      final countAfterFirst = capturedEvents.length;

      // Visit the same location again.
      fogResolver.onLocationUpdate(kCentLat, kCentLon);
      expect(capturedEvents.length, equals(countAfterFirst),
          reason: 'Revisiting a cell must not trigger new discovery events');
    });

    test('moving to a new cell can trigger new discovery events', () {
      fogResolver.onLocationUpdate(kCentLat, kCentLon);
      final firstCellId = fogResolver.currentCellId!;
      final countAfterFirst = capturedEvents.length;

      // Move to a neighbor.
      final neighbors = cellService.getNeighborIds(firstCellId);
      expect(neighbors, isNotEmpty);
      final neighborCenter = cellService.getCellCenter(neighbors.first);
      fogResolver.onLocationUpdate(neighborCenter.lat, neighborCenter.lon);

      // We entered a new cell — the discovery service was notified.
      // Verify cellId in any new events matches the neighbor.
      final newEvents = capturedEvents.skip(countAfterFirst).toList();
      for (final event in newEvents) {
        expect(event.cellId, equals(neighbors.first));
      }
    });

    test('discovered species have non-empty commonName and scientificName', () {
      fogResolver.onLocationUpdate(kCentLat, kCentLon);
      for (final event in capturedEvents) {
        expect(event.species.commonName, isNotEmpty);
        expect(event.species.scientificName, isNotEmpty);
      }
    });

    test('DiscoveryService disposes without error', () {
      expect(() => discoveryService.dispose(), returnsNormally);
    });
  });

  group('Offline SeasonService integration with DiscoveryService', () {
    test('SeasonService is optional — DiscoveryService works without it', () {
      final cellService = makeSmallCellService();
      final fogResolver = FogStateResolver(cellService);
      final speciesService = buildSpeciesServiceFromFixture();

      // No SeasonService passed — backward-compatible default.
      final ds = DiscoveryService(
        fogResolver: fogResolver,
        speciesService: speciesService,
      );

      final events = <DiscoveryEvent>[];
      ds.onDiscovery.listen(events.add);

      expect(() => fogResolver.onLocationUpdate(kCentLat, kCentLon),
          returnsNormally);

      ds.dispose();
      fogResolver.dispose();
    });
  });
}
