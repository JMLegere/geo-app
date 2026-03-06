import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/core/models/animal_class.dart';
import 'package:fog_of_world/core/models/animal_type.dart';

void main() {
  group('AnimalClass', () {
    test('all 35 values exist', () {
      expect(AnimalClass.values.length, equals(35));
    });

    group('parentType', () {
      test('bird classes → AnimalType.bird', () {
        const birdClasses = [
          AnimalClass.birdOfPrey,
          AnimalClass.gameBird,
          AnimalClass.nightbird,
          AnimalClass.parrot,
          AnimalClass.songbird,
          AnimalClass.waterfowl,
          AnimalClass.woodpecker,
        ];
        for (final cls in birdClasses) {
          expect(cls.parentType, equals(AnimalType.bird),
              reason: '${cls.name}.parentType should be bird');
        }
      });

      test('bug classes → AnimalType.bug', () {
        const bugClasses = [
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
        for (final cls in bugClasses) {
          expect(cls.parentType, equals(AnimalType.bug),
              reason: '${cls.name}.parentType should be bug');
        }
      });

      test('fish classes → AnimalType.fish', () {
        const fishClasses = [
          AnimalClass.cartilaginousFish,
          AnimalClass.cephalopod,
          AnimalClass.clamsUrchinsAndCrustaceans,
          AnimalClass.jawlessFish,
          AnimalClass.lobeFinnedFish,
          AnimalClass.rayFinnedFish,
        ];
        for (final cls in fishClasses) {
          expect(cls.parentType, equals(AnimalType.fish),
              reason: '${cls.name}.parentType should be fish');
        }
      });

      test('mammal classes → AnimalType.mammal', () {
        const mammalClasses = [
          AnimalClass.bat,
          AnimalClass.carnivore,
          AnimalClass.hare,
          AnimalClass.herbivore,
          AnimalClass.primate,
          AnimalClass.rodent,
          AnimalClass.seaMammal,
          AnimalClass.shrew,
        ];
        for (final cls in mammalClasses) {
          expect(cls.parentType, equals(AnimalType.mammal),
              reason: '${cls.name}.parentType should be mammal');
        }
      });

      test('reptile classes → AnimalType.reptile', () {
        const reptileClasses = [
          AnimalClass.amphibian,
          AnimalClass.crocodile,
          AnimalClass.lizard,
          AnimalClass.snake,
          AnimalClass.turtle,
        ];
        for (final cls in reptileClasses) {
          expect(cls.parentType, equals(AnimalType.reptile),
              reason: '${cls.name}.parentType should be reptile');
        }
      });

      test('class count per type sums to 35', () {
        final byType = <AnimalType, int>{};
        for (final cls in AnimalClass.values) {
          byType[cls.parentType] = (byType[cls.parentType] ?? 0) + 1;
        }
        expect(byType[AnimalType.bird], equals(7));
        expect(byType[AnimalType.bug], equals(9));
        expect(byType[AnimalType.fish], equals(6));
        expect(byType[AnimalType.mammal], equals(8));
        expect(byType[AnimalType.reptile], equals(5));
      });
    });

    group('displayName', () {
      test('birdOfPrey → "Bird of Prey"', () {
        expect(AnimalClass.birdOfPrey.displayName, equals('Bird of Prey'));
      });

      test('clamsUrchinsAndCrustaceans → "Clams, Urchins & Crustaceans"', () {
        expect(
          AnimalClass.clamsUrchinsAndCrustaceans.displayName,
          equals('Clams, Urchins & Crustaceans'),
        );
      });

      test('seaMammal → "Sea Mammal"', () {
        expect(AnimalClass.seaMammal.displayName, equals('Sea Mammal'));
      });

      test('lobeFinnedFish → "Lobe-finned Fish"', () {
        expect(AnimalClass.lobeFinnedFish.displayName, equals('Lobe-finned Fish'));
      });

      test('landMollusk → "Land Mollusk"', () {
        expect(AnimalClass.landMollusk.displayName, equals('Land Mollusk'));
      });

      test('rayFinnedFish → "Ray-finned Fish"', () {
        expect(AnimalClass.rayFinnedFish.displayName, equals('Ray-finned Fish'));
      });
    });

    group('fromString', () {
      test('parses each enum name', () {
        for (final cls in AnimalClass.values) {
          expect(AnimalClass.fromString(cls.name), equals(cls));
        }
      });

      test('throws on unknown value', () {
        expect(() => AnimalClass.fromString('dragon'), throwsArgumentError);
      });
    });

    test('toString returns name', () {
      expect(AnimalClass.carnivore.toString(), equals('carnivore'));
      expect(AnimalClass.birdOfPrey.toString(), equals('birdOfPrey'));
    });
  });
}
