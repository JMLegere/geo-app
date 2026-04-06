import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/taxonomic_group.dart';
import 'package:earth_nova/core/domain/entities/habitat.dart';
import 'package:earth_nova/core/domain/entities/game_region.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/shared/extensions/iconography.dart';

void main() {
  group('TaxonomicGroup icon extension', () {
    test('every TaxonomicGroup has a non-empty icon', () {
      for (final group in TaxonomicGroup.values) {
        expect(group.icon, isNotEmpty, reason: '${group.name} has empty icon');
      }
    });

    test('mammals icon is lion', () {
      expect(TaxonomicGroup.mammals.icon, '🦁');
    });

    test('birds icon is eagle', () {
      expect(TaxonomicGroup.birds.icon, '🦅');
    });
  });

  group('Habitat icon extension', () {
    test('every Habitat has a non-empty icon', () {
      for (final habitat in Habitat.values) {
        expect(habitat.icon, isNotEmpty,
            reason: '${habitat.name} has empty icon');
      }
    });

    test('forest icon is tree', () {
      expect(Habitat.forest.icon, '🌲');
    });
  });

  group('GameRegion icon extension', () {
    test('every GameRegion has a non-empty icon', () {
      for (final region in GameRegion.values) {
        expect(region.icon, isNotEmpty,
            reason: '${region.name} has empty icon');
      }
    });

    test('africa icon is globe', () {
      expect(GameRegion.africa.icon, '🌍');
    });
  });

  group('ItemCategory emoji extension', () {
    test('fauna emoji is fox', () {
      expect(ItemCategory.fauna.emoji, '🦊');
    });

    test('every ItemCategory has a non-empty emoji', () {
      for (final cat in ItemCategory.values) {
        expect(cat.emoji, isNotEmpty, reason: '${cat.name} has empty emoji');
      }
    });
  });

  group('PackSortMode', () {
    test('has icon and label', () {
      expect(PackSortMode.recent.icon, isNotEmpty);
      expect(PackSortMode.rarity.icon, isNotEmpty);
      expect(PackSortMode.name.icon, isNotEmpty);
      expect(PackSortMode.recent.label, 'Recent');
      expect(PackSortMode.rarity.label, 'Rarity');
      expect(PackSortMode.name.label, 'A→Z');
    });
  });
}
