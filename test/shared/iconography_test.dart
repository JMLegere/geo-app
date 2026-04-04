import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/shared/iconography.dart';

void main() {
  group('AppIcons', () {
    test('all category icons are non-empty and unique', () {
      final icons = [
        AppIcons.fauna,
        AppIcons.flora,
        AppIcons.mineral,
        AppIcons.fossil,
        AppIcons.artifact,
        AppIcons.food,
        AppIcons.orb,
      ];
      expect(icons.every((i) => i.isNotEmpty), isTrue);
      expect(icons.toSet().length, icons.length, reason: 'duplicate icon');
    });

    test('all taxonomic icons are non-empty and unique', () {
      final icons = [
        AppIcons.mammals,
        AppIcons.birds,
        AppIcons.reptiles,
        AppIcons.amphibians,
        AppIcons.fish,
        AppIcons.invertebrates,
      ];
      expect(icons.every((i) => i.isNotEmpty), isTrue);
      expect(icons.toSet().length, icons.length, reason: 'duplicate icon');
    });

    test('all habitat icons are non-empty and unique', () {
      final icons = [
        AppIcons.forest,
        AppIcons.plains,
        AppIcons.freshwater,
        AppIcons.saltwater,
        AppIcons.swamp,
        AppIcons.mountain,
        AppIcons.desert,
      ];
      expect(icons.every((i) => i.isNotEmpty), isTrue);
      expect(icons.toSet().length, icons.length, reason: 'duplicate icon');
    });

    test('all region icons are non-empty and unique', () {
      final icons = [
        AppIcons.africa,
        AppIcons.asia,
        AppIcons.europe,
        AppIcons.northAmerica,
        AppIcons.southAmerica,
        AppIcons.oceania,
      ];
      expect(icons.every((i) => i.isNotEmpty), isTrue);
      expect(icons.toSet().length, icons.length, reason: 'duplicate icon');
    });

    test('no icon collisions across all groups', () {
      final all = [
        // Categories
        AppIcons.fauna, AppIcons.flora, AppIcons.mineral,
        AppIcons.fossil, AppIcons.artifact, AppIcons.food, AppIcons.orb,
        // Taxonomic
        AppIcons.mammals, AppIcons.birds, AppIcons.reptiles,
        AppIcons.amphibians, AppIcons.fish, AppIcons.invertebrates,
        // Habitats
        AppIcons.forest, AppIcons.plains, AppIcons.freshwater,
        AppIcons.saltwater, AppIcons.swamp, AppIcons.mountain, AppIcons.desert,
        // Regions
        AppIcons.africa, AppIcons.asia, AppIcons.europe,
        AppIcons.northAmerica, AppIcons.southAmerica, AppIcons.oceania,
        // Sort
        AppIcons.sortRecent, AppIcons.sortRarity, AppIcons.sortName,
        // System
        AppIcons.search,
      ];
      expect(all.toSet().length, all.length, reason: 'cross-group collision');
    });
  });

  group('TaxonomicGroup', () {
    test('fromTaxonomicClass maps major IUCN classes', () {
      expect(TaxonomicGroup.fromTaxonomicClass('MAMMALIA'),
          TaxonomicGroup.mammals);
      expect(TaxonomicGroup.fromTaxonomicClass('AVES'), TaxonomicGroup.birds);
      expect(TaxonomicGroup.fromTaxonomicClass('REPTILIA'),
          TaxonomicGroup.reptiles);
      expect(TaxonomicGroup.fromTaxonomicClass('AMPHIBIA'),
          TaxonomicGroup.amphibians);
      expect(TaxonomicGroup.fromTaxonomicClass('ACTINOPTERYGII'),
          TaxonomicGroup.fish);
      expect(TaxonomicGroup.fromTaxonomicClass('CHONDRICHTHYES'),
          TaxonomicGroup.fish);
      expect(TaxonomicGroup.fromTaxonomicClass('INSECTA'),
          TaxonomicGroup.invertebrates);
      expect(TaxonomicGroup.fromTaxonomicClass('GASTROPODA'),
          TaxonomicGroup.invertebrates);
      expect(TaxonomicGroup.fromTaxonomicClass('ARACHNIDA'),
          TaxonomicGroup.invertebrates);
    });

    test('fromTaxonomicClass is case-insensitive', () {
      expect(TaxonomicGroup.fromTaxonomicClass('mammalia'),
          TaxonomicGroup.mammals);
      expect(TaxonomicGroup.fromTaxonomicClass('Aves'), TaxonomicGroup.birds);
    });

    test('fromTaxonomicClass returns other for null/empty/unknown', () {
      expect(TaxonomicGroup.fromTaxonomicClass(null), TaxonomicGroup.other);
      expect(TaxonomicGroup.fromTaxonomicClass(''), TaxonomicGroup.other);
      expect(
          TaxonomicGroup.fromTaxonomicClass('PLANTAE'), TaxonomicGroup.other);
    });

    test('all values have icon and label', () {
      for (final group in TaxonomicGroup.values) {
        expect(group.icon, isNotEmpty, reason: '${group.name} has no icon');
        expect(group.label, isNotEmpty, reason: '${group.name} has no label');
      }
    });
  });

  group('Habitat', () {
    test('fromString matches DB values', () {
      expect(Habitat.fromString('Forest'), Habitat.forest);
      expect(Habitat.fromString('Plains'), Habitat.plains);
      expect(Habitat.fromString('Freshwater'), Habitat.freshwater);
      expect(Habitat.fromString('Saltwater'), Habitat.saltwater);
      expect(Habitat.fromString('Swamp'), Habitat.swamp);
      expect(Habitat.fromString('Mountain'), Habitat.mountain);
      expect(Habitat.fromString('Desert'), Habitat.desert);
      expect(Habitat.fromString('Unknown'), Habitat.unknown);
    });

    test('fromString is case-insensitive', () {
      expect(Habitat.fromString('forest'), Habitat.forest);
      expect(Habitat.fromString('DESERT'), Habitat.desert);
    });

    test('fromString returns null for unrecognized/null', () {
      expect(Habitat.fromString(null), isNull);
      expect(Habitat.fromString(''), isNull);
      expect(Habitat.fromString('tundra'), isNull);
    });

    test('all values have icon and label', () {
      for (final h in Habitat.values) {
        expect(h.icon, isNotEmpty, reason: '${h.name} has no icon');
        expect(h.label, isNotEmpty, reason: '${h.name} has no label');
      }
    });
  });

  group('GameRegion', () {
    test('fromString matches DB values', () {
      expect(GameRegion.fromString('Africa'), GameRegion.africa);
      expect(GameRegion.fromString('Asia'), GameRegion.asia);
      expect(GameRegion.fromString('Europe'), GameRegion.europe);
      expect(GameRegion.fromString('North America'), GameRegion.northAmerica);
      expect(GameRegion.fromString('South America'), GameRegion.southAmerica);
      expect(GameRegion.fromString('Oceania'), GameRegion.oceania);
      expect(GameRegion.fromString('Unknown'), GameRegion.unknown);
    });

    test('fromString is case-insensitive', () {
      expect(GameRegion.fromString('africa'), GameRegion.africa);
      expect(GameRegion.fromString('north america'), GameRegion.northAmerica);
    });

    test('fromString returns null for unrecognized/null', () {
      expect(GameRegion.fromString(null), isNull);
      expect(GameRegion.fromString(''), isNull);
      expect(GameRegion.fromString('Antarctica'), isNull);
    });

    test('all values have icon and label', () {
      for (final r in GameRegion.values) {
        expect(r.icon, isNotEmpty, reason: '${r.name} has no icon');
        expect(r.label, isNotEmpty, reason: '${r.name} has no label');
      }
    });
  });

  group('PackSortMode', () {
    test('all values have icon and label', () {
      for (final s in PackSortMode.values) {
        expect(s.icon, isNotEmpty, reason: '${s.name} has no icon');
        expect(s.label, isNotEmpty, reason: '${s.name} has no label');
      }
    });

    test('has exactly 3 modes', () {
      expect(PackSortMode.values.length, 3);
    });
  });
}
