import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/models/affix.dart';
import 'package:earth_nova/models/continent.dart';
import 'package:earth_nova/models/habitat.dart';
import 'package:earth_nova/models/item_category.dart';
import 'package:earth_nova/models/item_instance.dart';
import 'package:earth_nova/models/iucn_status.dart';

ItemInstance _makeInstance({
  String id = 'instance-1',
  String definitionId = 'fauna_vulpes_vulpes',
  String displayName = 'Red Fox',
  String? scientificName = 'Vulpes vulpes',
  ItemCategory category = ItemCategory.fauna,
  IucnStatus? rarity = IucnStatus.leastConcern,
  List<Habitat> habitats = const [Habitat.forest, Habitat.plains],
  List<Continent> continents = const [Continent.europe, Continent.asia],
  List<Affix> affixes = const [],
  Set<String> badges = const {},
  ItemInstanceStatus status = ItemInstanceStatus.active,
}) {
  return ItemInstance(
    id: id,
    definitionId: definitionId,
    displayName: displayName,
    scientificName: scientificName,
    category: category,
    rarity: rarity,
    habitats: habitats,
    continents: continents,
    affixes: affixes,
    badges: badges,
    acquiredAt: DateTime(2026, 1, 15),
    status: status,
  );
}

void main() {
  group('ItemInstance', () {
    test('constructor creates instance with all fields', () {
      final instance = _makeInstance();
      expect(instance.id, 'instance-1');
      expect(instance.definitionId, 'fauna_vulpes_vulpes');
      expect(instance.displayName, 'Red Fox');
      expect(instance.scientificName, 'Vulpes vulpes');
      expect(instance.category, ItemCategory.fauna);
      expect(instance.rarity, IucnStatus.leastConcern);
      expect(instance.habitats, [Habitat.forest, Habitat.plains]);
      expect(instance.continents, [Continent.europe, Continent.asia]);
      expect(instance.status, ItemInstanceStatus.active);
    });

    test('copyWith preserves unmodified fields', () {
      final original = _makeInstance(displayName: 'Red Fox');
      final copy = original.copyWith(status: ItemInstanceStatus.placed);
      expect(copy.displayName, 'Red Fox');
      expect(copy.id, original.id);
      expect(copy.category, original.category);
      expect(copy.habitats, original.habitats);
    });

    test('copyWith updates specified fields', () {
      final original = _makeInstance(status: ItemInstanceStatus.active);
      final updated = original.copyWith(
        displayName: 'Arctic Fox',
        status: ItemInstanceStatus.donated,
      );
      expect(updated.displayName, 'Arctic Fox');
      expect(updated.status, ItemInstanceStatus.donated);
    });

    test('affixes serialization round-trip', () {
      final affixes = [
        const Affix(
            id: 'swift', type: AffixType.intrinsic, values: {'speed': 30}),
        const Affix(
            id: 'strong', type: AffixType.prefix, values: {'brawn': 45}),
      ];
      final instance = _makeInstance(affixes: affixes);
      final json = instance.affixesToJson();
      final restored = ItemInstance.affixesFromJson(json);
      expect(restored.length, 2);
      expect(restored[0].id, 'swift');
      expect(restored[0].type, AffixType.intrinsic);
      expect(restored[1].id, 'strong');
    });

    test('badges serialization round-trip', () {
      final instance = _makeInstance(
        badges: {'first_discovery', 'beta', 'pioneer'},
      );
      final json = instance.badgesToJson();
      final restored = ItemInstance.badgesFromJson(json);
      expect(restored, {'first_discovery', 'beta', 'pioneer'});
    });

    test('habitats serialization round-trip', () {
      final instance = _makeInstance(
        habitats: [Habitat.forest, Habitat.swamp, Habitat.mountain],
      );
      final json = instance.habitatsToJson();
      final restored = ItemInstance.habitatsFromJson(json);
      expect(restored, [Habitat.forest, Habitat.swamp, Habitat.mountain]);
    });

    test('continents serialization round-trip', () {
      final instance = _makeInstance(
        continents: [Continent.asia, Continent.europe],
      );
      final json = instance.continentsToJson();
      final restored = ItemInstance.continentsFromJson(json);
      expect(restored, [Continent.asia, Continent.europe]);
    });

    test('no enrichver fields exist — enrichedFieldCount uses data fields only',
        () {
      // All enrichable fields null → count = 0
      final bare = _makeInstance();
      expect(bare.enrichedFieldCount, 0);

      // Fill some enrichable fields
      final enriched = bare.copyWith(
        animalClassName: 'Carnivore',
        climateName: 'temperate',
        brawn: 30,
        wit: 20,
        speed: 40,
      );
      expect(enriched.enrichedFieldCount, 5);
    });

    test('totalEnrichableFields constant is 17', () {
      expect(ItemInstance.totalEnrichableFields, 17);
    });

    test('isFirstDiscovery returns true when badge present', () {
      final instance = _makeInstance(badges: {'first_discovery', 'beta'});
      expect(instance.isFirstDiscovery, isTrue);
    });

    test('isFirstDiscovery returns false when badge absent', () {
      final instance = _makeInstance(badges: {'beta', 'pioneer'});
      expect(instance.isFirstDiscovery, isFalse);
    });

    test('equality is based on id only', () {
      final a = _makeInstance(id: 'same-id', displayName: 'Fox');
      final b = _makeInstance(id: 'same-id', displayName: 'Wolf');
      expect(a, equals(b));
    });

    test('instances with different ids are not equal', () {
      final a = _makeInstance(id: 'id-1');
      final b = _makeInstance(id: 'id-2');
      expect(a, isNot(equals(b)));
    });

    test('hashCode is consistent with equality', () {
      final a = _makeInstance(id: 'same-id');
      final b = _makeInstance(id: 'same-id');
      expect(a.hashCode, equals(b.hashCode));
    });

    test('status field accepts all valid values', () {
      for (final status in ItemInstanceStatus.values) {
        final instance = _makeInstance(status: status);
        expect(instance.status, status);
      }
    });
  });
}
