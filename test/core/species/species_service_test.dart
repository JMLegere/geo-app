import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/core/models/continent.dart';
import 'package:fog_of_world/core/models/habitat.dart';
import 'package:fog_of_world/core/models/iucn_status.dart';
import 'package:fog_of_world/core/species/species_data_loader.dart';
import 'package:fog_of_world/core/species/species_service.dart';

import '../../fixtures/species_fixture.dart';

void main() {
  late List records;
  late SpeciesService service;

  setUp(() {
    records = SpeciesDataLoader.fromJsonString(kSpeciesFixtureJson);
    service = SpeciesService(records.cast());
  });

  // ---------------------------------------------------------------------------
  // SpeciesDataLoader.fromJsonString (preserved from original)
  // ---------------------------------------------------------------------------

  group('SpeciesDataLoader.fromJsonString', () {
    test('parses valid JSON and returns non-empty list', () {
      expect(records.isNotEmpty, isTrue);
    });

    test('parses exactly 50 valid species from fixture (excludes unknowns)', () {
      expect(records.length, equals(50));
    });

    test('silently skips records with unknown habitat', () {
      const jsonWithUnknown = '''[
        {
          "commonName": "Mystery Beast",
          "scientificName": "Unknownus maximus",
          "taxonomicClass": "Mammalia",
          "continents": ["Europe"],
          "habitats": ["Unknown"],
          "iucnStatus": "Least Concern"
        },
        {
          "commonName": "Red Fox",
          "scientificName": "Vulpes vulpes",
          "taxonomicClass": "Mammalia",
          "continents": ["Europe"],
          "habitats": ["Forest"],
          "iucnStatus": "Least Concern"
        }
      ]''';

      final result = SpeciesDataLoader.fromJsonString(jsonWithUnknown);
      expect(result.length, equals(1));
      expect(result.first.scientificName, equals('Vulpes vulpes'));
    });

    test('silently skips records with unknown continent', () {
      const jsonWithUnknown = '''[
        {
          "commonName": "Mystery Beast",
          "scientificName": "Unknownus continentus",
          "taxonomicClass": "Mammalia",
          "continents": ["Unknown"],
          "habitats": ["Forest"],
          "iucnStatus": "Least Concern"
        },
        {
          "commonName": "Wolf",
          "scientificName": "Canis lupus",
          "taxonomicClass": "Mammalia",
          "continents": ["Europe"],
          "habitats": ["Forest"],
          "iucnStatus": "Least Concern"
        }
      ]''';

      final result = SpeciesDataLoader.fromJsonString(jsonWithUnknown);
      expect(result.length, equals(1));
      expect(result.first.scientificName, equals('Canis lupus'));
    });

    test('silently skips records with unknown IUCN status', () {
      const jsonWithUnknown = '''[
        {
          "commonName": "Mystery Beast",
          "scientificName": "Unknownus status",
          "taxonomicClass": "Mammalia",
          "continents": ["Europe"],
          "habitats": ["Forest"],
          "iucnStatus": "Data Deficient"
        },
        {
          "commonName": "Wolf",
          "scientificName": "Canis lupus",
          "taxonomicClass": "Mammalia",
          "continents": ["Europe"],
          "habitats": ["Forest"],
          "iucnStatus": "Least Concern"
        }
      ]''';

      final result = SpeciesDataLoader.fromJsonString(jsonWithUnknown);
      expect(result.length, equals(1));
    });

    test('returns empty list for empty JSON array', () {
      final result = SpeciesDataLoader.fromJsonString('[]');
      expect(result, isEmpty);
    });

    test('parsed records cover all 7 habitats', () {
      final allHabitats = <Habitat>{};
      for (final r in records) {
        allHabitats.addAll(r.habitats as List<Habitat>);
      }
      expect(allHabitats.length, equals(7),
          reason: 'Fixture should cover all 7 habitat types');
    });

    test('parsed records cover all 6 continents', () {
      final allContinents = <Continent>{};
      for (final r in records) {
        allContinents.addAll(r.continents as List<Continent>);
      }
      expect(allContinents.length, equals(6),
          reason: 'Fixture should cover all 6 continents');
    });

    test('parsed records cover all 6 IUCN statuses', () {
      final allStatuses = <IucnStatus>{};
      for (final r in records) {
        allStatuses.add(r.rarity as IucnStatus);
      }
      expect(allStatuses.length, equals(6),
          reason: 'Fixture should cover all 6 IUCN statuses');
    });
  });

  // ---------------------------------------------------------------------------
  // SpeciesDataLoader filters (preserved from original)
  // ---------------------------------------------------------------------------

  group('SpeciesDataLoader.forHabitat', () {
    test('filters to only species with the given habitat', () {
      final forestSpecies =
          SpeciesDataLoader.forHabitat(records.cast(), Habitat.forest);

      expect(forestSpecies.isNotEmpty, isTrue);
      for (final s in forestSpecies) {
        expect(s.habitats, contains(Habitat.forest),
            reason: '${s.scientificName} lacks forest habitat');
      }
    });

    test('returns non-empty lists for all 7 habitats', () {
      for (final habitat in Habitat.values) {
        final result =
            SpeciesDataLoader.forHabitat(records.cast(), habitat);
        expect(result.isNotEmpty, isTrue,
            reason: 'No species found for habitat ${habitat.name}');
      }
    });

    test('returns empty list for non-matching habitat when all excluded', () {
      const smallJson = '''[
        {
          "commonName": "Shark",
          "scientificName": "Carcharodon carcharias",
          "taxonomicClass": "Chondrichthyes",
          "continents": ["Oceania"],
          "habitats": ["Saltwater"],
          "iucnStatus": "Vulnerable"
        }
      ]''';
      final result = SpeciesDataLoader.fromJsonString(smallJson);
      final desertSpecies =
          SpeciesDataLoader.forHabitat(result, Habitat.desert);
      expect(desertSpecies, isEmpty);
    });
  });

  group('SpeciesDataLoader.forContinent', () {
    test('filters to only species with the given continent', () {
      final africaSpecies =
          SpeciesDataLoader.forContinent(records.cast(), Continent.africa);

      expect(africaSpecies.isNotEmpty, isTrue);
      for (final s in africaSpecies) {
        expect(s.continents, contains(Continent.africa),
            reason: '${s.scientificName} lacks Africa continent');
      }
    });

    test('returns non-empty lists for all 6 continents', () {
      for (final continent in Continent.values) {
        final result =
            SpeciesDataLoader.forContinent(records.cast(), continent);
        expect(result.isNotEmpty, isTrue,
            reason: 'No species found for continent ${continent.name}');
      }
    });
  });

  group('SpeciesDataLoader.forHabitatAndContinent', () {
    test('filters correctly by both habitat and continent', () {
      final result = SpeciesDataLoader.forHabitatAndContinent(
        records.cast(),
        Habitat.forest,
        Continent.europe,
      );

      expect(result.isNotEmpty, isTrue);
      for (final s in result) {
        expect(s.habitats, contains(Habitat.forest),
            reason: '${s.scientificName} lacks forest habitat');
        expect(s.continents, contains(Continent.europe),
            reason: '${s.scientificName} lacks Europe continent');
      }
    });

    test('returns empty list for non-matching combination', () {
      final result = SpeciesDataLoader.forHabitatAndContinent(
        records.cast(),
        Habitat.desert,
        Continent.oceania,
      );
      expect(result, isEmpty);
    });

    test('result is subset of forHabitat result', () {
      final habitatOnly =
          SpeciesDataLoader.forHabitat(records.cast(), Habitat.forest);
      final both = SpeciesDataLoader.forHabitatAndContinent(
        records.cast(),
        Habitat.forest,
        Continent.asia,
      );

      for (final s in both) {
        expect(habitatOnly, contains(s),
            reason:
                '${s.scientificName} in forHabitatAndContinent but not forHabitat');
      }
    });

    test('result is subset of forContinent result', () {
      final continentOnly =
          SpeciesDataLoader.forContinent(records.cast(), Continent.asia);
      final both = SpeciesDataLoader.forHabitatAndContinent(
        records.cast(),
        Habitat.forest,
        Continent.asia,
      );

      for (final s in both) {
        expect(continentOnly, contains(s),
            reason:
                '${s.scientificName} in forHabitatAndContinent but not forContinent');
      }
    });
  });

  // ---------------------------------------------------------------------------
  // SpeciesService — core encounter logic
  // ---------------------------------------------------------------------------

  group('SpeciesService.totalSpecies', () {
    test('returns correct count matching loaded records', () {
      expect(service.totalSpecies, equals(50));
    });
  });

  group('SpeciesService.getSpeciesForCell', () {
    test('is deterministic — same cellId+habitats+continent always returns same species',
        () {
      const cellId = 'cell_42_forest_europe';
      const habitats = {Habitat.forest};
      const continent = Continent.europe;

      final first = service.getSpeciesForCell(
        cellId: cellId,
        habitats: habitats,
        continent: continent,
      );
      for (var i = 0; i < 20; i++) {
        final repeated = service.getSpeciesForCell(
          cellId: cellId,
          habitats: habitats,
          continent: continent,
        );
        expect(repeated.map((s) => s.scientificName).toList(),
            equals(first.map((s) => s.scientificName).toList()),
            reason: 'Iteration $i: same cellId should produce same species');
      }
    });

    test('different cellIds produce different species (statistically)', () {
      const habitats = {Habitat.forest};
      const continent = Continent.europe;

      final results = <String>{};
      // Collect the first species from many different cells.
      for (var i = 0; i < 30; i++) {
        final found = service.getSpeciesForCell(
          cellId: 'cell_$i',
          habitats: habitats,
          continent: continent,
        );
        if (found.isNotEmpty) results.add(found.first.scientificName!);
      }
      // With 30 different cells, we expect at least some variety.
      expect(results.length, greaterThan(1),
          reason: 'Different cells should encounter different species');
    });

    test('returns at most encounterSlots species', () {
      final found = service.getSpeciesForCell(
        cellId: 'cell_test',
        habitats: const {Habitat.forest},
        continent: Continent.europe,
        encounterSlots: 2,
      );
      expect(found.length, lessThanOrEqualTo(2));
    });

    test('returns empty list when no species match habitat+continent', () {
      // Desert/Oceania — no desert species in Oceania in the fixture.
      final found = service.getSpeciesForCell(
        cellId: 'cell_999',
        habitats: const {Habitat.desert},
        continent: Continent.oceania,
      );
      expect(found, isEmpty);
    });

    test('returned species all belong to at least one requested habitat and to the continent',
        () {
      final found = service.getSpeciesForCell(
        cellId: 'cell_validate',
        habitats: const {Habitat.forest},
        continent: Continent.asia,
        encounterSlots: 5,
      );

      for (final s in found) {
        expect(s.habitats, contains(Habitat.forest),
            reason: '${s.scientificName} lacks forest habitat');
        expect(s.continents, contains(Continent.asia),
            reason: '${s.scientificName} lacks Asia continent');
      }
    });

    test('returned species are unique (no duplicates)', () {
      final found = service.getSpeciesForCell(
        cellId: 'cell_dedup',
        habitats: const {Habitat.forest},
        continent: Continent.europe,
        encounterSlots: 10,
      );

      final unique = found.map((s) => s.scientificName).toSet();
      expect(unique.length, equals(found.length),
          reason: 'getSpeciesForCell should not return duplicate species');
    });

    test('multi-habitat union: result may include species from any habitat', () {
      // forest + freshwater union for Asia
      final found = service.getSpeciesForCell(
        cellId: 'cell_multi_habitat',
        habitats: const {Habitat.forest, Habitat.freshwater},
        continent: Continent.asia,
        encounterSlots: 10,
      );
      // Pool is at least as large as forest-only for Asia.
      final forestOnly = service.getSpeciesForCell(
        cellId: 'cell_multi_habitat',
        habitats: const {Habitat.forest},
        continent: Continent.asia,
        encounterSlots: 10,
      );
      // Multi-habitat pool >= single-habitat pool (union is non-shrinking).
      final multiPool = service.getPoolForArea(
        habitats: const {Habitat.forest, Habitat.freshwater},
        continent: Continent.asia,
      );
      final forestPool = service.getPoolForArea(
        habitats: const {Habitat.forest},
        continent: Continent.asia,
      );
      expect(multiPool.length, greaterThanOrEqualTo(forestPool.length));
      // All found species must belong to the correct continent.
      for (final s in found) {
        expect(s.continents, contains(Continent.asia),
            reason: '${s.scientificName} lacks Asia continent');
      }
      // Suppress unused-variable warning.
      expect(forestOnly, isA<List>());
    });
  });

  group('SpeciesService.getPoolForArea', () {
    test('returns all species matching habitat+continent', () {
      final pool = service.getPoolForArea(
        habitats: const {Habitat.forest},
        continent: Continent.europe,
      );

      expect(pool.isNotEmpty, isTrue);
      for (final s in pool) {
        expect(s.habitats, contains(Habitat.forest));
        expect(s.continents, contains(Continent.europe));
      }
    });

    test('returns empty for non-matching combination', () {
      final pool = service.getPoolForArea(
        habitats: const {Habitat.desert},
        continent: Continent.oceania,
      );
      expect(pool, isEmpty);
    });

    test('pool size >= encounter results size', () {
      const habitats = {Habitat.forest};
      const continent = Continent.europe;

      final pool = service.getPoolForArea(
          habitats: habitats, continent: continent);
      final found = service.getSpeciesForCell(
        cellId: 'cell_pool_check',
        habitats: habitats,
        continent: continent,
        encounterSlots: 10,
      );

      expect(pool.length, greaterThanOrEqualTo(found.length));
    });

    test('multi-habitat pool is union of single-habitat pools', () {
      final forestPool = service.getPoolForArea(
        habitats: const {Habitat.forest},
        continent: Continent.europe,
      );
      final freshwaterPool = service.getPoolForArea(
        habitats: const {Habitat.freshwater},
        continent: Continent.europe,
      );
      final unionPool = service.getPoolForArea(
        habitats: const {Habitat.forest, Habitat.freshwater},
        continent: Continent.europe,
      );
      // Union must be at least as large as either individual pool.
      expect(unionPool.length,
          greaterThanOrEqualTo(forestPool.length),
          reason: 'Union pool must include all forest species');
      expect(unionPool.length,
          greaterThanOrEqualTo(freshwaterPool.length),
          reason: 'Union pool must include all freshwater species');
    });
  });

  group('SpeciesService.forHabitat and forContinent', () {
    test('forHabitat returns only species with that habitat', () {
      final result = service.forHabitat(Habitat.forest);
      expect(result.isNotEmpty, isTrue);
      for (final s in result) {
        expect(s.habitats, contains(Habitat.forest));
      }
    });

    test('forContinent returns only species with that continent', () {
      final result = service.forContinent(Continent.africa);
      expect(result.isNotEmpty, isTrue);
      for (final s in result) {
        expect(s.continents, contains(Continent.africa));
      }
    });

    test('forContinent has no duplicates', () {
      // A species with 2 habitats should appear only once per continent.
      for (final continent in Continent.values) {
        final result = service.forContinent(continent);
        final ids = result.map((s) => s.id).toList();
        final uniqueIds = ids.toSet();
        expect(ids.length, equals(uniqueIds.length),
            reason: 'forContinent(${continent.name}) contains duplicates');
      }
    });
  });

  group('SpeciesService index correctness', () {
    test('indices are built on construction — getPoolForArea works immediately',
        () {
      // Construct a fresh service and call immediately.
      final freshService = SpeciesService(records.cast());
      final pool = freshService.getPoolForArea(
        habitats: {Habitat.mountain},
        continent: Continent.asia,
      );
      expect(pool.isNotEmpty, isTrue);
    });

    test('all() returns all 50 records unchanged', () {
      expect(service.all.length, equals(50));
    });
  });

  // ---------------------------------------------------------------------------
  // Rarity distribution — 10^x weight pattern
  // ---------------------------------------------------------------------------

  group('SpeciesService rarity distribution', () {
    test(
        'leastConcern appears far more often than endangered over many cells (forest/europe)',
        () {
      // Forest/Europe fixture pool:
      //   LC: Red Fox, European Badger, Eurasian Lynx, Gray Wolf (4 × 100,000)
      //   NT: European Bison (1 × 10,000)
      //   EN: Iberian Lynx (1 × 100)
      // Over many single rolls, LC should dominate EN by >100x.

      final lcSpecies = {
        'fauna_vulpes_vulpes',
        'fauna_meles_meles',
        'fauna_lynx_lynx',
        'fauna_canis_lupus',
      };
      final enSpecies = {'fauna_lynx_pardinus'};

      var lcCount = 0;
      var enCount = 0;
      const cellCount = 500;

      for (var i = 0; i < cellCount; i++) {
        // Roll one slot per cell to get clean individual rolls.
        final found = service.getSpeciesForCell(
          cellId: 'rarity_test_$i',
          habitats: const {Habitat.forest},
          continent: Continent.europe,
          encounterSlots: 1,
        );
        if (found.isNotEmpty) {
          final id = found.first.id;
          if (lcSpecies.contains(id)) lcCount++;
          if (enSpecies.contains(id)) enCount++;
        }
      }

      // With weights 400000 vs 100, LC should appear ~4000x more often.
      // Even over 500 rolls, LC >> EN.
      expect(lcCount, greaterThan(enCount * 10),
          reason:
              'LC species (weight 100000) should appear far more than EN (weight 100). '
              'Got LC=$lcCount, EN=$enCount over $cellCount cells');
    });
  });
}
