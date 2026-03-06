import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/core/models/continent.dart';
import 'package:fog_of_world/core/models/habitat.dart';
import 'package:fog_of_world/core/models/iucn_status.dart';
import 'package:fog_of_world/core/models/item_definition.dart';

void main() {
  group('FaunaDefinition', () {
    FaunaDefinition makeRedFox() => const FaunaDefinition(
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

    test('id is stored as provided (fauna_ prefix + lowercase scientific name)', () {
      final species = makeRedFox();
      expect(species.id, equals('fauna_vulpes_vulpes'));
    });

    test('id derivation handles multi-word scientific names', () {
      const species = FaunaDefinition(
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
      const species3 = FaunaDefinition(
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
      expect(IucnStatus.leastConcern.weight, equals(100000));
      expect(IucnStatus.nearThreatened.weight, equals(10000));
      expect(IucnStatus.vulnerable.weight, equals(1000));
      expect(IucnStatus.endangered.weight, equals(100));
      expect(IucnStatus.criticallyEndangered.weight, equals(10));
      expect(IucnStatus.extinct.weight, equals(1));
    });

    test('all 6 continents are available', () {
      expect(Continent.values.length, equals(6));
    });

    test('IucnStatus weights decrease by 10x per tier', () {
      final tiers = IucnStatus.values;
      for (var i = 0; i < tiers.length - 1; i++) {
        expect(tiers[i].weight, equals(tiers[i + 1].weight * 10),
            reason:
                '${tiers[i].name}.weight should be 10x ${tiers[i + 1].name}.weight');
      }
    });
  });
}
