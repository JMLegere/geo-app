import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/models/animal_type.dart';
import 'package:earth_nova/models/continent.dart';
import 'package:earth_nova/models/food_type.dart';
import 'package:earth_nova/models/habitat.dart';
import 'package:earth_nova/models/item_category.dart';
import 'package:earth_nova/models/item_definition.dart';
import 'package:earth_nova/models/iucn_status.dart';
import 'package:earth_nova/models/orb_dimension.dart';

FaunaDefinition _makeFauna({
  String? id,
  String scientificName = 'Vulpes vulpes',
  String displayName = 'Red Fox',
  String taxonomicClass = 'Mammalia',
  IucnStatus rarity = IucnStatus.leastConcern,
  List<Habitat> habitats = const [Habitat.forest, Habitat.plains],
  List<Continent> continents = const [Continent.europe],
}) {
  return FaunaDefinition(
    id: id ?? 'fauna_${scientificName.toLowerCase().replaceAll(' ', '_')}',
    displayName: displayName,
    scientificName: scientificName,
    taxonomicClass: taxonomicClass,
    rarity: rarity,
    habitats: habitats,
    continents: continents,
  );
}

void main() {
  group('FaunaDefinition', () {
    test('creates with correct fields', () {
      final def = _makeFauna();
      expect(def.displayName, 'Red Fox');
      expect(def.scientificName, 'Vulpes vulpes');
      expect(def.taxonomicClass, 'Mammalia');
      expect(def.rarity, IucnStatus.leastConcern);
      expect(def.category, ItemCategory.fauna);
      expect(def.habitats, [Habitat.forest, Habitat.plains]);
      expect(def.continents, [Continent.europe]);
    });

    test('animalType auto-computed from taxonomicClass Mammalia', () {
      final def = _makeFauna(taxonomicClass: 'Mammalia');
      expect(def.animalType, AnimalType.mammal);
    });

    test('animalType auto-computed from taxonomicClass Aves', () {
      final def = _makeFauna(
        scientificName: 'Passer domesticus',
        taxonomicClass: 'Aves',
      );
      expect(def.animalType, AnimalType.bird);
    });

    test('animalType is null for unrecognized taxonomicClass', () {
      final def = _makeFauna(taxonomicClass: 'Plantae');
      expect(def.animalType, isNull);
    });

    test('equality is by id only', () {
      final a = _makeFauna(id: 'fauna_vulpes_vulpes', displayName: 'Red Fox');
      final b =
          _makeFauna(id: 'fauna_vulpes_vulpes', displayName: 'Arctic Fox');
      expect(a, equals(b));
    });

    test('different ids are not equal', () {
      final a = _makeFauna(id: 'fauna_vulpes_vulpes');
      final b = _makeFauna(
        id: 'fauna_canis_lupus',
        scientificName: 'Canis lupus',
        displayName: 'Wolf',
      );
      expect(a, isNot(equals(b)));
    });

    test('id format is fauna_{scientificName with underscores}', () {
      final def = _makeFauna(
        scientificName: 'Panthera leo',
        displayName: 'Lion',
      );
      expect(def.id, 'fauna_panthera_leo');
    });

    test('toJson/fromJson round-trip preserves all fields', () {
      final original = _makeFauna(
        scientificName: 'Ursus arctos',
        displayName: 'Brown Bear',
        taxonomicClass: 'Mammalia',
        rarity: IucnStatus.leastConcern,
        habitats: [Habitat.forest, Habitat.mountain],
        continents: [Continent.europe, Continent.northAmerica],
      );
      final json = original.toJson();
      final restored = FaunaDefinition.fromJson(json);
      expect(restored.scientificName, original.scientificName);
      expect(restored.displayName, original.displayName);
      expect(restored.taxonomicClass, original.taxonomicClass);
      expect(restored.rarity, original.rarity);
      expect(restored.habitats, original.habitats);
      expect(restored.continents, original.continents);
    });
  });

  group('ItemDefinition sealed class', () {
    test('FaunaDefinition is constructible', () {
      expect(_makeFauna().category, ItemCategory.fauna);
    });

    test('FloraDefinition is constructible', () {
      const flora = FloraDefinition(
        id: 'flora_quercus_robur',
        displayName: 'English Oak',
      );
      expect(flora.category, ItemCategory.flora);
    });

    test('MineralDefinition is constructible', () {
      const mineral = MineralDefinition(
        id: 'mineral_quartz',
        displayName: 'Quartz',
      );
      expect(mineral.category, ItemCategory.mineral);
    });

    test('FossilDefinition is constructible', () {
      const fossil = FossilDefinition(
        id: 'fossil_ammonite',
        displayName: 'Ammonite',
      );
      expect(fossil.category, ItemCategory.fossil);
    });

    test('ArtifactDefinition is constructible', () {
      const artifact = ArtifactDefinition(
        id: 'artifact_arrowhead',
        displayName: 'Arrowhead',
      );
      expect(artifact.category, ItemCategory.artifact);
    });

    test('FoodDefinition is constructible', () {
      const food = FoodDefinition(
        id: 'food-critter',
        displayName: 'Critter',
        foodType: FoodType.critter,
      );
      expect(food.category, ItemCategory.food);
      expect(food.foodType, FoodType.critter);
    });

    test('OrbDefinition is constructible', () {
      const orb = OrbDefinition(
        id: 'orb-forest',
        displayName: 'Forest Orb',
        dimension: OrbDimension.habitat,
        variant: 'forest',
      );
      expect(orb.category, ItemCategory.orb);
      expect(orb.dimension, OrbDimension.habitat);
    });
  });
}
