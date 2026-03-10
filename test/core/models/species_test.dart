import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/models/animal_class.dart';
import 'package:earth_nova/core/models/animal_type.dart';
import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/food_type.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/models/iucn_status.dart';
import 'package:earth_nova/core/models/item_definition.dart';

void main() {
  group('FaunaDefinition', () {
    FaunaDefinition makeRedFox() => FaunaDefinition(
          id: 'fauna_vulpes_vulpes',
          displayName: 'Red Fox',
          scientificName: 'Vulpes vulpes',
          taxonomicClass: 'Mammalia',
          continents: [Continent.europe, Continent.asia],
          habitats: [Habitat.forest, Habitat.plains],
          rarity: IucnStatus.leastConcern,
        );

    test('construction with all fields', () {
      final species = makeRedFox();

      expect(species.displayName, equals('Red Fox'));
      expect(species.scientificName, equals('Vulpes vulpes'));
      expect(species.taxonomicClass, equals('Mammalia'));
      expect(species.continents, contains(Continent.europe));
      expect(species.habitats, contains(Habitat.forest));
      expect(species.rarity, equals(IucnStatus.leastConcern));
    });

    test('id is stored as provided (fauna_ prefix + lowercase scientific name)',
        () {
      final species = makeRedFox();
      expect(species.id, equals('fauna_vulpes_vulpes'));
    });

    test('id derivation handles multi-word scientific names', () {
      final species = FaunaDefinition(
        id: 'fauna_panthera_uncia',
        displayName: 'Snow Leopard',
        scientificName: 'Panthera uncia',
        taxonomicClass: 'Mammalia',
        continents: [Continent.asia],
        habitats: [Habitat.mountain],
        rarity: IucnStatus.vulnerable,
      );
      expect(species.id, equals('fauna_panthera_uncia'));
    });

    test('fromJson / toJson round-trip preserves all data', () {
      final original = makeRedFox();
      final json = original.toJson();
      final restored = FaunaDefinition.fromJson({
        'commonName': json['commonName'],
        'scientificName': json['scientificName'],
        'taxonomicClass': json['taxonomicClass'],
        'continents': json['continents'],
        'habitats': json['habitats'],
        'iucnStatus': json['iucnStatus'],
      });

      expect(restored.displayName, equals(original.displayName));
      expect(restored.scientificName, equals(original.scientificName));
      expect(restored.taxonomicClass, equals(original.taxonomicClass));
      expect(restored.continents, equals(original.continents));
      expect(restored.habitats, equals(original.habitats));
      expect(restored.rarity, equals(original.rarity));
    });

    test('fromJson parses JSON with capitalized habitat values', () {
      final record = FaunaDefinition.fromJson({
        'commonName': 'Wolf',
        'scientificName': 'Canis lupus',
        'taxonomicClass': 'Mammalia',
        'continents': ['Europe', 'Asia'],
        'habitats': ['Forest', 'Plains'],
        'iucnStatus': 'Least Concern',
      });

      expect(record.habitats, contains(Habitat.forest));
      expect(record.habitats, contains(Habitat.plains));
    });

    test('fromJson parses all IUCN status strings', () {
      final statuses = {
        'Least Concern': IucnStatus.leastConcern,
        'Near Threatened': IucnStatus.nearThreatened,
        'Vulnerable': IucnStatus.vulnerable,
        'Endangered': IucnStatus.endangered,
        'Critically Endangered': IucnStatus.criticallyEndangered,
        'Extinct': IucnStatus.extinct,
        'Extinct in the Wild': IucnStatus.extinct,
      };

      for (final entry in statuses.entries) {
        final record = FaunaDefinition.fromJson({
          'commonName': 'Test',
          'scientificName': 'Test species',
          'taxonomicClass': 'Mammalia',
          'continents': ['Europe'],
          'habitats': ['Forest'],
          'iucnStatus': entry.key,
        });
        expect(record.rarity, equals(entry.value),
            reason: '${entry.key} should map to ${entry.value}');
      }
    });

    test('equality is based on id', () {
      final species1 = makeRedFox();
      final species2 = makeRedFox();
      final species3 = FaunaDefinition(
        id: 'fauna_canis_lupus',
        displayName: 'Wolf',
        scientificName: 'Canis lupus',
        taxonomicClass: 'Mammalia',
        continents: [Continent.europe],
        habitats: [Habitat.forest],
        rarity: IucnStatus.leastConcern,
      );

      expect(species1, equals(species2));
      expect(species1, isNot(equals(species3)));
    });

    test('all 7 habitats are available', () {
      expect(Habitat.values.length, equals(7));
      expect(Habitat.forest, isNotNull);
      expect(Habitat.plains, isNotNull);
      expect(Habitat.freshwater, isNotNull);
      expect(Habitat.saltwater, isNotNull);
      expect(Habitat.swamp, isNotNull);
      expect(Habitat.mountain, isNotNull);
      expect(Habitat.desert, isNotNull);
    });

    test('all 6 IUCN statuses are available', () {
      expect(IucnStatus.values.length, equals(6));
      expect(IucnStatus.leastConcern.weight, equals(243));
      expect(IucnStatus.nearThreatened.weight, equals(81));
      expect(IucnStatus.vulnerable.weight, equals(27));
      expect(IucnStatus.endangered.weight, equals(9));
      expect(IucnStatus.criticallyEndangered.weight, equals(3));
      expect(IucnStatus.extinct.weight, equals(1));
    });

    test('all 6 continents are available', () {
      expect(Continent.values.length, equals(6));
    });

    test('IucnStatus weights decrease by 3x per tier', () {
      final tiers = IucnStatus.values;
      for (var i = 0; i < tiers.length - 1; i++) {
        expect(tiers[i].weight, equals(tiers[i + 1].weight * 3),
            reason:
                '${tiers[i].name}.weight should be 3x ${tiers[i + 1].name}.weight');
      }
    });

    test('FaunaDefinition auto-computes animalType from taxonomicClass', () {
      final mammal = FaunaDefinition(
        id: 'fauna_vulpes_vulpes',
        displayName: 'Red Fox',
        scientificName: 'Vulpes vulpes',
        taxonomicClass: 'Mammalia',
        continents: [Continent.europe],
        habitats: [Habitat.forest],
        rarity: IucnStatus.leastConcern,
      );
      expect(mammal.animalType, equals(AnimalType.mammal));

      final bird = FaunaDefinition(
        id: 'fauna_test_bird',
        displayName: 'Test Bird',
        scientificName: 'Testus birdus',
        taxonomicClass: 'Aves',
        continents: [Continent.europe],
        habitats: [Habitat.forest],
        rarity: IucnStatus.leastConcern,
      );
      expect(bird.animalType, equals(AnimalType.bird));

      final reptile = FaunaDefinition(
        id: 'fauna_test_reptile',
        displayName: 'Test Reptile',
        scientificName: 'Testus reptilis',
        taxonomicClass: 'Reptilia',
        continents: [Continent.africa],
        habitats: [Habitat.desert],
        rarity: IucnStatus.leastConcern,
      );
      expect(reptile.animalType, equals(AnimalType.reptile));
    });

    test('animalType is null for unrecognized taxonomicClass', () {
      final unknown = FaunaDefinition(
        id: 'fauna_test_unknown',
        displayName: 'Unknown',
        scientificName: 'Testus unknownus',
        taxonomicClass: 'UNKNOWN_CLASS',
        continents: [Continent.europe],
        habitats: [Habitat.forest],
        rarity: IucnStatus.leastConcern,
      );
      expect(unknown.animalType, isNull);
    });

    test('animalClass, foodPreference, climate default to null', () {
      final species = FaunaDefinition(
        id: 'fauna_vulpes_vulpes',
        displayName: 'Red Fox',
        scientificName: 'Vulpes vulpes',
        taxonomicClass: 'Mammalia',
        continents: [Continent.europe],
        habitats: [Habitat.forest],
        rarity: IucnStatus.leastConcern,
      );
      expect(species.animalClass, isNull);
      expect(species.foodPreference, isNull);
      expect(species.climate, isNull);
    });

    test('FaunaDefinition.fromJson computes animalType', () {
      final record = FaunaDefinition.fromJson({
        'commonName': 'Wolf',
        'scientificName': 'Canis lupus',
        'taxonomicClass': 'Mammalia',
        'continents': ['Europe'],
        'habitats': ['Forest'],
        'iucnStatus': 'Least Concern',
      });
      expect(record.animalType, equals(AnimalType.mammal));
    });

    test('FaunaDefinition.fromJson parses optional enrichment fields', () {
      final record = FaunaDefinition.fromJson({
        'commonName': 'Red Fox',
        'scientificName': 'Vulpes vulpes',
        'taxonomicClass': 'Mammalia',
        'continents': ['Europe'],
        'habitats': ['Forest'],
        'iucnStatus': 'Least Concern',
        'animalClass': 'carnivore',
        'foodPreference': 'critter',
        'climate': 'temperate',
      });
      expect(record.animalClass, equals(AnimalClass.carnivore));
      expect(record.foodPreference, equals(FoodType.critter));
      expect(record.climate?.name, equals('temperate'));
    });
  });
}
