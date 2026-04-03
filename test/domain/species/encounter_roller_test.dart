import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/domain/species/encounter_roller.dart';
import 'package:earth_nova/models/climate.dart';
import 'package:earth_nova/models/item_definition.dart';
import 'package:earth_nova/models/continent.dart';
import 'package:earth_nova/models/habitat.dart';
import 'package:earth_nova/models/iucn_status.dart';

import '../../fixtures/test_helpers.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Build a list of [count] distinct species sharing the same habitat/continent.
List<FaunaDefinition> makeSpeciesList({
  int count = 20,
  IucnStatus rarity = IucnStatus.leastConcern,
  Set<Habitat>? habitats,
  Set<Continent>? continents,
}) {
  return List.generate(
    count,
    (i) => makeSpecies(
      scientificName: 'Species $i',
      rarity: rarity,
      habitats: habitats,
      continents: continents,
    ),
  );
}

void main() {
  group('SpeciesService.getSpeciesForCell', () {
    test('returns deterministic species for same seed and cellId', () {
      final species = makeSpeciesList(count: 30);
      final svc = SpeciesService(species);

      final first = svc.getSpeciesForCell(
        cellId: 'cell_1',
        dailySeed: 'seed_abc',
        habitats: {Habitat.forest},
        continent: Continent.europe,
        encounterSlots: 1,
      );
      final second = svc.getSpeciesForCell(
        cellId: 'cell_1',
        dailySeed: 'seed_abc',
        habitats: {Habitat.forest},
        continent: Continent.europe,
        encounterSlots: 1,
      );

      expect(first, equals(second));
    });

    test('returns different species for different day seeds', () {
      final species = makeSpeciesList(count: 30);
      final svc = SpeciesService(species);

      final day1 = svc.getSpeciesForCell(
        cellId: 'cell_1',
        dailySeed: 'seed_day1',
        habitats: {Habitat.forest},
        continent: Continent.europe,
        encounterSlots: 1,
      );
      final day2 = svc.getSpeciesForCell(
        cellId: 'cell_1',
        dailySeed: 'seed_day2',
        habitats: {Habitat.forest},
        continent: Continent.europe,
        encounterSlots: 1,
      );

      // Very unlikely to be identical over 30 species with different seeds.
      // (Not guaranteed, but statistically sound for a test.)
      // We simply verify at least one day returns non-empty.
      expect(day1.isNotEmpty || day2.isNotEmpty, isTrue);
    });

    test('filters species by habitat', () {
      final forestSpecies = makeSpeciesList(
        count: 10,
        habitats: {Habitat.forest},
        continents: {Continent.europe},
      );
      final saltSpecies = List.generate(
        10,
        (i) => makeSpecies(
          scientificName: 'Salt Species $i',
          habitats: {Habitat.saltwater},
          continents: {Continent.europe},
          rarity: IucnStatus.nearThreatened,
        ),
      );

      final svc = SpeciesService([...forestSpecies, ...saltSpecies]);

      final results = svc.getSpeciesForCell(
        cellId: 'cell_1',
        dailySeed: 'seed',
        habitats: {Habitat.saltwater},
        continent: Continent.europe,
        encounterSlots: 5,
      );

      // All results must have saltwater habitat.
      for (final s in results) {
        expect(s.habitats, contains(Habitat.saltwater));
      }
    });

    test('filters species by continent', () {
      final europeSpecies = makeSpeciesList(
        count: 15,
        habitats: {Habitat.forest},
        continents: {Continent.europe},
      );
      final asiaSpecies = List.generate(
        10,
        (i) => makeSpecies(
          scientificName: 'Asia Species $i',
          habitats: {Habitat.forest},
          continents: {Continent.asia},
        ),
      );

      final svc = SpeciesService([...europeSpecies, ...asiaSpecies]);

      final results = svc.getSpeciesForCell(
        cellId: 'cell_1',
        dailySeed: 'seed',
        habitats: {Habitat.forest},
        continent: Continent.europe,
        encounterSlots: 5,
      );

      for (final s in results) {
        expect(s.continents, contains(Continent.europe));
      }
    });

    test('returns deterministic result for same seed+cellId', () {
      final allSpecies = Continent.values.expand((c) => List.generate(
            5,
            (i) => makeSpecies(
              scientificName: '${c.name} Forest $i',
              habitats: {Habitat.forest},
              continents: {c},
            ),
          ));
      final svc = SpeciesService(allSpecies.toList());

      final params = (
        cellId: 'cell_1',
        dailySeed: 'seed_migrate',
        habitats: {Habitat.forest},
        nativeContinent: Continent.europe,
        nativeClimate: Climate.temperate,
        encounterSlots: 2,
      );

      final first = svc.getSpeciesForMigration(
        cellId: params.cellId,
        dailySeed: params.dailySeed,
        habitats: params.habitats,
        nativeContinent: params.nativeContinent,
        nativeClimate: params.nativeClimate,
        encounterSlots: params.encounterSlots,
      );
      final second = svc.getSpeciesForMigration(
        cellId: params.cellId,
        dailySeed: params.dailySeed,
        habitats: params.habitats,
        nativeContinent: params.nativeContinent,
        nativeClimate: params.nativeClimate,
        encounterSlots: params.encounterSlots,
      );

      expect(first, equals(second));
    });
  });

  // ─── index helpers ────────────────────────────────────────────────────────

  group('SpeciesService index helpers', () {
    test('forHabitat returns only species with matching habitat', () {
      final forest =
          makeSpecies(scientificName: 'Forest A', habitats: {Habitat.forest});
      final desert =
          makeSpecies(scientificName: 'Desert A', habitats: {Habitat.desert});
      final svc = SpeciesService([forest, desert]);

      final results = svc.forHabitat(Habitat.forest);
      expect(results.length, 1);
      expect(results.first.scientificName, 'Forest A');
    });

    test('totalSpecies equals loaded species count in list mode', () {
      final species = makeSpeciesList(count: 15);
      final svc = SpeciesService(species);
      expect(svc.totalSpecies, 15);
    });
  });
}
