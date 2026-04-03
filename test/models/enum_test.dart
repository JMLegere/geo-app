import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/models/animal_class.dart';
import 'package:earth_nova/models/animal_size.dart';
import 'package:earth_nova/models/animal_type.dart';
import 'package:earth_nova/models/cell_event.dart';
import 'package:earth_nova/models/climate.dart';
import 'package:earth_nova/models/continent.dart';
import 'package:earth_nova/models/fog_state.dart';
import 'package:earth_nova/models/food_type.dart';
import 'package:earth_nova/models/habitat.dart';
import 'package:earth_nova/models/item_category.dart';
import 'package:earth_nova/models/iucn_status.dart';
import 'package:earth_nova/models/season.dart';

void main() {
  group('FogState', () {
    test('density values are correct', () {
      expect(FogState.unknown.density, 1.0);
      expect(FogState.detected.density, 1.0);
      expect(FogState.nearby.density, 0.95);
      expect(FogState.explored.density, 0.5);
      expect(FogState.present.density, 0.0);
    });

    test('fromString handles legacy name undetected → unknown', () {
      expect(FogState.fromString('undetected'), FogState.unknown);
    });

    test('fromString handles legacy name unexplored → detected', () {
      expect(FogState.fromString('unexplored'), FogState.detected);
    });

    test('fromString handles legacy name concealed → nearby', () {
      expect(FogState.fromString('concealed'), FogState.nearby);
    });

    test('fromString handles legacy name hidden → explored', () {
      expect(FogState.fromString('hidden'), FogState.explored);
    });

    test('fromString handles legacy name observed → present', () {
      expect(FogState.fromString('observed'), FogState.present);
    });

    test('fromString handles current names', () {
      for (final state in FogState.values) {
        expect(FogState.fromString(state.name), state);
      }
    });

    test('isPresent is true only for present', () {
      expect(FogState.present.isPresent, isTrue);
      expect(FogState.explored.isPresent, isFalse);
      expect(FogState.nearby.isPresent, isFalse);
    });

    test('isVisited is true for explored and present', () {
      expect(FogState.explored.isVisited, isTrue);
      expect(FogState.present.isVisited, isTrue);
      expect(FogState.unknown.isVisited, isFalse);
      expect(FogState.detected.isVisited, isFalse);
      expect(FogState.nearby.isVisited, isFalse);
    });
  });

  group('IucnStatus', () {
    test('weights follow 3^x progression', () {
      expect(IucnStatus.leastConcern.weight, 243); // 3^5
      expect(IucnStatus.nearThreatened.weight, 81); // 3^4
      expect(IucnStatus.vulnerable.weight, 27); // 3^3
      expect(IucnStatus.endangered.weight, 9); // 3^2
      expect(IucnStatus.criticallyEndangered.weight, 3); // 3^1
      expect(IucnStatus.extinct.weight, 1); // 3^0
    });

    test('fromString round-trips for all values', () {
      for (final status in IucnStatus.values) {
        expect(IucnStatus.fromString(status.name), status);
      }
    });

    test('fromString throws for unknown value', () {
      expect(() => IucnStatus.fromString('superRare'), throwsArgumentError);
    });

    test('fromIucnString parses Least Concern', () {
      expect(
          IucnStatus.fromIucnString('Least Concern'), IucnStatus.leastConcern);
    });

    test('fromIucnString parses Critically Endangered', () {
      expect(IucnStatus.fromIucnString('Critically Endangered'),
          IucnStatus.criticallyEndangered);
    });

    test('fromIucnString parses Extinct in the Wild as extinct', () {
      expect(
          IucnStatus.fromIucnString('Extinct in the Wild'), IucnStatus.extinct);
    });

    test('fromIucnString throws for unknown string', () {
      expect(() => IucnStatus.fromIucnString('Data Deficient'),
          throwsArgumentError);
    });
  });

  group('Habitat', () {
    test('has exactly 7 values', () {
      expect(Habitat.values.length, 7);
    });

    test('fromString round-trips for all values', () {
      for (final h in Habitat.values) {
        expect(Habitat.fromString(h.name), h);
      }
    });

    test('fromString throws for unknown value', () {
      expect(() => Habitat.fromString('tundra'), throwsArgumentError);
    });
  });

  group('Continent', () {
    test('has exactly 6 values', () {
      expect(Continent.values.length, 6);
    });

    test('fromString round-trips for all values', () {
      for (final c in Continent.values) {
        expect(Continent.fromString(c.name), c);
      }
    });

    test('fromDataString handles enum names', () {
      expect(Continent.fromDataString('northAmerica'), Continent.northAmerica);
    });

    test('fromDataString handles display names', () {
      expect(Continent.fromDataString('North America'), Continent.northAmerica);
      expect(Continent.fromDataString('South America'), Continent.southAmerica);
      expect(Continent.fromDataString('Asia'), Continent.asia);
      expect(Continent.fromDataString('Africa'), Continent.africa);
      expect(Continent.fromDataString('Europe'), Continent.europe);
      expect(Continent.fromDataString('Oceania'), Continent.oceania);
    });

    test('fromDataString throws for unknown value', () {
      expect(() => Continent.fromDataString('Antarctica'), throwsArgumentError);
    });
  });

  group('Season', () {
    test('fromDate returns summer for May through October', () {
      for (final month in [5, 6, 7, 8, 9, 10]) {
        expect(Season.fromDate(DateTime(2026, month, 15)), Season.summer,
            reason: 'month $month should be summer');
      }
    });

    test('fromDate returns winter for November through April', () {
      for (final month in [11, 12, 1, 2, 3, 4]) {
        expect(Season.fromDate(DateTime(2026, month, 15)), Season.winter,
            reason: 'month $month should be winter');
      }
    });

    test('opposite returns the other season', () {
      expect(Season.summer.opposite, Season.winter);
      expect(Season.winter.opposite, Season.summer);
    });
  });

  group('Climate', () {
    test('fromLatitude returns tropic at 0°', () {
      expect(Climate.fromLatitude(0.0), Climate.tropic);
    });

    test('fromLatitude returns tropic at boundary 23.5°', () {
      expect(Climate.fromLatitude(23.5), Climate.tropic);
    });

    test('fromLatitude returns temperate just above 23.5°', () {
      expect(Climate.fromLatitude(23.6), Climate.temperate);
    });

    test('fromLatitude returns temperate at 55°', () {
      expect(Climate.fromLatitude(55.0), Climate.temperate);
    });

    test('fromLatitude returns boreal just above 55°', () {
      expect(Climate.fromLatitude(55.1), Climate.boreal);
    });

    test('fromLatitude returns boreal at 66.5°', () {
      expect(Climate.fromLatitude(66.5), Climate.boreal);
    });

    test('fromLatitude returns frigid above 66.5°', () {
      expect(Climate.fromLatitude(66.6), Climate.frigid);
      expect(Climate.fromLatitude(90.0), Climate.frigid);
    });

    test('fromLatitude handles southern hemisphere (absolute value)', () {
      expect(Climate.fromLatitude(-33.9), Climate.temperate);
      expect(Climate.fromLatitude(-70.0), Climate.frigid);
    });
  });

  group('AnimalType', () {
    test('fromTaxonomicClass maps Mammalia to mammal', () {
      expect(AnimalType.fromTaxonomicClass('Mammalia'), AnimalType.mammal);
      expect(AnimalType.fromTaxonomicClass('MAMMALIA'), AnimalType.mammal);
    });

    test('fromTaxonomicClass maps Aves to bird', () {
      expect(AnimalType.fromTaxonomicClass('Aves'), AnimalType.bird);
      expect(AnimalType.fromTaxonomicClass('AVES'), AnimalType.bird);
    });

    test('fromTaxonomicClass maps Actinopterygii to fish', () {
      expect(AnimalType.fromTaxonomicClass('Actinopterygii'), AnimalType.fish);
    });

    test('fromTaxonomicClass maps Cephalopoda to fish', () {
      expect(AnimalType.fromTaxonomicClass('Cephalopoda'), AnimalType.fish);
    });

    test('fromTaxonomicClass maps Reptilia to reptile', () {
      expect(AnimalType.fromTaxonomicClass('Reptilia'), AnimalType.reptile);
    });

    test('fromTaxonomicClass maps Amphibia to reptile', () {
      expect(AnimalType.fromTaxonomicClass('Amphibia'), AnimalType.reptile);
    });

    test('fromTaxonomicClass maps Insecta to bug', () {
      expect(AnimalType.fromTaxonomicClass('Insecta'), AnimalType.bug);
    });

    test('fromTaxonomicClass returns null for unknown class', () {
      expect(AnimalType.fromTaxonomicClass('Plantae'), isNull);
      expect(AnimalType.fromTaxonomicClass(''), isNull);
    });
  });

  group('AnimalClass', () {
    test('has exactly 35 values', () {
      expect(AnimalClass.values.length, 35);
    });

    test('bird classes have parentType bird', () {
      final birdClasses = [
        AnimalClass.birdOfPrey,
        AnimalClass.gameBird,
        AnimalClass.nightbird,
        AnimalClass.parrot,
        AnimalClass.songbird,
        AnimalClass.waterfowl,
        AnimalClass.woodpecker,
      ];
      expect(birdClasses.length, 7);
      for (final c in birdClasses) {
        expect(c.parentType, AnimalType.bird, reason: '$c should be bird');
      }
    });

    test('bug classes have parentType bug', () {
      final bugClasses = [
        AnimalClass.bee,
        AnimalClass.beetle,
        AnimalClass.butterfly,
        AnimalClass.cicada,
        AnimalClass.dragonfly,
        AnimalClass.landMollusk,
        AnimalClass.locust,
        AnimalClass.scorpion,
        AnimalClass.spider,
      ];
      expect(bugClasses.length, 9);
      for (final c in bugClasses) {
        expect(c.parentType, AnimalType.bug, reason: '$c should be bug');
      }
    });

    test('fish classes have parentType fish', () {
      final fishClasses = [
        AnimalClass.cartilaginousFish,
        AnimalClass.cephalopod,
        AnimalClass.clamsUrchinsAndCrustaceans,
        AnimalClass.jawlessFish,
        AnimalClass.lobeFinnedFish,
        AnimalClass.rayFinnedFish,
      ];
      expect(fishClasses.length, 6);
      for (final c in fishClasses) {
        expect(c.parentType, AnimalType.fish, reason: '$c should be fish');
      }
    });

    test('mammal classes have parentType mammal', () {
      final mammalClasses = [
        AnimalClass.bat,
        AnimalClass.carnivore,
        AnimalClass.hare,
        AnimalClass.herbivore,
        AnimalClass.primate,
        AnimalClass.rodent,
        AnimalClass.seaMammal,
        AnimalClass.shrew,
      ];
      expect(mammalClasses.length, 8);
      for (final c in mammalClasses) {
        expect(c.parentType, AnimalType.mammal, reason: '$c should be mammal');
      }
    });

    test('reptile classes have parentType reptile', () {
      final reptileClasses = [
        AnimalClass.amphibian,
        AnimalClass.crocodile,
        AnimalClass.lizard,
        AnimalClass.snake,
        AnimalClass.turtle,
      ];
      expect(reptileClasses.length, 5);
      for (final c in reptileClasses) {
        expect(c.parentType, AnimalType.reptile,
            reason: '$c should be reptile');
      }
    });
  });

  group('AnimalSize', () {
    test('has exactly 9 values', () {
      expect(AnimalSize.values.length, 9);
    });

    test('weight ranges are contiguous — no gaps between tiers', () {
      final sorted = AnimalSize.values.toList()
        ..sort((a, b) => a.minGrams.compareTo(b.minGrams));
      for (var i = 0; i < sorted.length - 1; i++) {
        expect(
          sorted[i + 1].minGrams,
          sorted[i].maxGrams + 1,
          reason: '${sorted[i]} max + 1 should equal ${sorted[i + 1]} min',
        );
      }
    });

    test('rangeSpan is maxGrams - minGrams + 1', () {
      for (final size in AnimalSize.values) {
        expect(size.rangeSpan, size.maxGrams - size.minGrams + 1);
      }
    });

    test('fine starts at 1 gram', () {
      expect(AnimalSize.fine.minGrams, 1);
    });

    test('colossal ends at 247 tonnes', () {
      expect(AnimalSize.colossal.maxGrams, 247000000);
    });
  });

  group('ItemCategory', () {
    test('has exactly 7 values', () {
      expect(ItemCategory.values.length, 7);
    });

    test('fromString round-trips', () {
      for (final cat in ItemCategory.values) {
        expect(ItemCategory.fromString(cat.name), cat);
      }
    });
  });

  group('FoodType', () {
    test('has exactly 7 values', () {
      expect(FoodType.values.length, 7);
    });

    test('id getter returns food-{name}', () {
      expect(FoodType.critter.id, 'food-critter');
      expect(FoodType.fish.id, 'food-fish');
      expect(FoodType.fruit.id, 'food-fruit');
      expect(FoodType.grub.id, 'food-grub');
      expect(FoodType.nectar.id, 'food-nectar');
      expect(FoodType.seed.id, 'food-seed');
      expect(FoodType.veg.id, 'food-veg');
    });
  });

  group('CellEvent', () {
    test('same cellId and dailySeed produce equal events', () {
      const e1 = CellEvent(
        type: CellEventType.migration,
        cellId: 'cell-X',
        dailySeed: 'seed-2026-04-01',
      );
      const e2 = CellEvent(
        type: CellEventType.migration,
        cellId: 'cell-X',
        dailySeed: 'seed-2026-04-01',
      );
      expect(e1, equals(e2));
      expect(e1.hashCode, e2.hashCode);
    });

    test('different cellId produces different event', () {
      const e1 = CellEvent(
        type: CellEventType.migration,
        cellId: 'cell-A',
        dailySeed: 'seed-abc',
      );
      const e2 = CellEvent(
        type: CellEventType.migration,
        cellId: 'cell-B',
        dailySeed: 'seed-abc',
      );
      expect(e1, isNot(equals(e2)));
    });

    test('different dailySeed produces different event', () {
      const e1 = CellEvent(
        type: CellEventType.nestingSite,
        cellId: 'cell-Z',
        dailySeed: 'seed-day1',
      );
      const e2 = CellEvent(
        type: CellEventType.nestingSite,
        cellId: 'cell-Z',
        dailySeed: 'seed-day2',
      );
      expect(e1, isNot(equals(e2)));
    });

    test('toJson/fromJson round-trips', () {
      const original = CellEvent(
        type: CellEventType.nestingSite,
        cellId: 'cell-Q',
        dailySeed: 'seed-xyz',
      );
      final json = original.toJson();
      final restored = CellEvent.fromJson(json);
      expect(restored, equals(original));
    });
  });
}
