import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/models/item.dart';
import 'package:earth_nova/shared/iconography.dart';

void main() {
  group('ItemCategory', () {
    test('fromString matches by name', () {
      expect(ItemCategory.fromString('fauna'), ItemCategory.fauna);
      expect(ItemCategory.fromString('flora'), ItemCategory.flora);
      expect(ItemCategory.fromString('orb'), ItemCategory.orb);
    });

    test('fromString is case-insensitive', () {
      expect(ItemCategory.fromString('FAUNA'), ItemCategory.fauna);
      expect(ItemCategory.fromString('Fauna'), ItemCategory.fauna);
    });

    test('fromString defaults to fauna for unknown', () {
      expect(ItemCategory.fromString('unknown'), ItemCategory.fauna);
      expect(ItemCategory.fromString(null), ItemCategory.fauna);
    });

    test('emoji is set for all categories', () {
      for (final cat in ItemCategory.values) {
        expect(cat.emoji, isNotEmpty);
      }
    });

    test('label is set for all categories', () {
      for (final cat in ItemCategory.values) {
        expect(cat.label, isNotEmpty);
      }
    });

    test('food emoji is mushroom not apple', () {
      expect(ItemCategory.food.emoji, AppIcons.food);
      expect(ItemCategory.food.emoji, '🍄');
    });
  });

  group('ItemStatus', () {
    test('fromString matches by name', () {
      expect(ItemStatus.fromString('active'), ItemStatus.active);
      expect(ItemStatus.fromString('donated'), ItemStatus.donated);
    });

    test('fromString defaults to active for unknown', () {
      expect(ItemStatus.fromString(null), ItemStatus.active);
    });
  });

  group('Item', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 'item_1',
        'definition_id': 'fauna_vulpes_vulpes',
        'display_name': 'Red Fox',
        'scientific_name': 'Vulpes vulpes',
        'category': 'fauna',
        'rarity': 'leastConcern',
        'icon_url': 'https://example.com/icon.png',
        'icon_url_frame2': 'https://example.com/icon2.png',
        'art_url': 'https://example.com/art.png',
        'acquired_at': '2026-01-15T10:30:00Z',
        'acquired_in_cell_id': 'v_45_67',
        'status': 'active',
      };
      final item = Item.fromJson(json);
      expect(item.id, 'item_1');
      expect(item.definitionId, 'fauna_vulpes_vulpes');
      expect(item.displayName, 'Red Fox');
      expect(item.scientificName, 'Vulpes vulpes');
      expect(item.category, ItemCategory.fauna);
      expect(item.rarity, 'leastConcern');
      expect(item.iconUrl, 'https://example.com/icon.png');
      expect(item.iconUrlFrame2, 'https://example.com/icon2.png');
      expect(item.artUrl, 'https://example.com/art.png');
      expect(item.acquiredAt, DateTime.utc(2026, 1, 15, 10, 30));
      expect(item.acquiredInCellId, 'v_45_67');
      expect(item.status, ItemStatus.active);
    });

    test('fromJson handles null optionals', () {
      final json = {
        'id': 'item_2',
        'definition_id': 'fauna_ursus_arctos',
        'display_name': 'Brown Bear',
        'category': 'fauna',
        'acquired_at': '2026-02-01T00:00:00Z',
        'status': 'active',
      };
      final item = Item.fromJson(json);
      expect(item.scientificName, isNull);
      expect(item.rarity, isNull);
      expect(item.iconUrl, isNull);
      expect(item.iconUrlFrame2, isNull);
      expect(item.artUrl, isNull);
      expect(item.acquiredInCellId, isNull);
    });

    test('fromJson uses definition_id as fallback for display_name', () {
      final json = {
        'id': 'item_3',
        'definition_id': 'fauna_unknown_species',
        'category': 'fauna',
        'acquired_at': '2026-01-01T00:00:00Z',
        'status': 'active',
      };
      final item = Item.fromJson(json);
      expect(item.displayName, 'fauna_unknown_species');
    });

    test('unknown category defaults to fauna', () {
      final json = {
        'id': 'item_4',
        'definition_id': 'test',
        'display_name': 'Test',
        'category': 'unknown_category',
        'acquired_at': '2026-01-01T00:00:00Z',
        'status': 'active',
      };
      final item = Item.fromJson(json);
      expect(item.category, ItemCategory.fauna);
    });

    test('JSON round-trip', () {
      final item = Item(
        id: 'item_1',
        definitionId: 'fauna_vulpes_vulpes',
        displayName: 'Red Fox',
        scientificName: 'Vulpes vulpes',
        category: ItemCategory.fauna,
        rarity: 'leastConcern',
        iconUrl: 'https://example.com/icon.png',
        iconUrlFrame2: 'https://example.com/icon2.png',
        artUrl: 'https://example.com/art.png',
        acquiredAt: DateTime.utc(2026, 1, 15, 10, 30),
        acquiredInCellId: 'v_45_67',
        status: ItemStatus.active,
      );
      final json = item.toJson();
      final restored = Item.fromJson(json);
      expect(restored, item);
    });

    test('copyWith replaces fields', () {
      final item = _testItem();
      final updated = item.copyWith(displayName: 'Arctic Fox');
      expect(updated.displayName, 'Arctic Fox');
      expect(updated.id, item.id); // unchanged
    });

    test('copyWith preserves original when null', () {
      final item = _testItem();
      final updated = item.copyWith();
      expect(updated, item);
    });

    test('equality works', () {
      final a = _testItem();
      final b = _testItem();
      final c = _testItem().copyWith(displayName: 'Different');
      expect(a == b, isTrue);
      expect(a == c, isFalse);
    });

    test('fromJson parses taxonomicClass', () {
      final json = _baseJson()..['taxonomic_class'] = 'MAMMALIA';
      final item = Item.fromJson(json);
      expect(item.taxonomicClass, 'MAMMALIA');
    });

    test('fromJson parses habitats_json array', () {
      final json = _baseJson()..['habitats_json'] = '["Forest","Mountain"]';
      final item = Item.fromJson(json);
      expect(item.habitats, ['Forest', 'Mountain']);
    });

    test('fromJson parses continents_json array', () {
      final json = _baseJson()..['continents_json'] = '["Africa","Asia"]';
      final item = Item.fromJson(json);
      expect(item.continents, ['Africa', 'Asia']);
    });

    test('fromJson handles null habitats_json', () {
      final json = _baseJson();
      final item = Item.fromJson(json);
      expect(item.habitats, isEmpty);
    });

    test('fromJson handles empty habitats_json', () {
      final json = _baseJson()..['habitats_json'] = '[]';
      final item = Item.fromJson(json);
      expect(item.habitats, isEmpty);
    });

    test('fromJson handles malformed habitats_json', () {
      final json = _baseJson()..['habitats_json'] = 'not-json';
      final item = Item.fromJson(json);
      expect(item.habitats, isEmpty);
    });

    test('taxonomicGroup getter maps class to group', () {
      final mammal = _testItem().copyWith(taxonomicClass: 'MAMMALIA');
      expect(mammal.taxonomicGroup, TaxonomicGroup.mammals);

      final bird = _testItem().copyWith(taxonomicClass: 'AVES');
      expect(bird.taxonomicGroup, TaxonomicGroup.birds);

      final noClass = _testItem();
      expect(noClass.taxonomicGroup, TaxonomicGroup.other);
    });

    test('toJson round-trip preserves new fields', () {
      final item = Item(
        id: 'item_1',
        definitionId: 'def',
        displayName: 'Test',
        category: ItemCategory.fauna,
        acquiredAt: DateTime.utc(2026),
        status: ItemStatus.active,
        taxonomicClass: 'MAMMALIA',
        habitats: ['Forest', 'Mountain'],
        continents: ['Africa'],
      );
      final json = item.toJson();
      final restored = Item.fromJson(json);
      expect(restored.taxonomicClass, 'MAMMALIA');
      expect(restored.habitats, ['Forest', 'Mountain']);
      expect(restored.continents, ['Africa']);
      expect(restored, item);
    });

    test('equality includes new fields', () {
      final a = _testItem().copyWith(habitats: ['Forest']);
      final b = _testItem().copyWith(habitats: ['Forest']);
      final c = _testItem().copyWith(habitats: ['Desert']);
      expect(a == b, isTrue);
      expect(a == c, isFalse);
    });

    test('hashCode is consistent with equality', () {
      final a = _testItem();
      final b = _testItem();
      expect(a.hashCode, b.hashCode);

      final c = _testItem().copyWith(displayName: 'Different');
      expect(a.hashCode == c.hashCode, isFalse);
    });

    test('items can be used in Set and Map keys', () {
      final a = _testItem();
      final b = _testItem();
      final set = {a, b};
      expect(set.length, 1, reason: 'equal items should deduplicate');
    });
  });
}

Item _testItem() => Item(
      id: 'item_1',
      definitionId: 'fauna_vulpes_vulpes',
      displayName: 'Red Fox',
      scientificName: 'Vulpes vulpes',
      category: ItemCategory.fauna,
      rarity: 'leastConcern',
      iconUrl: 'https://example.com/icon.png',
      iconUrlFrame2: 'https://example.com/icon2.png',
      artUrl: 'https://example.com/art.png',
      acquiredAt: DateTime.utc(2026, 1, 15, 10, 30),
      acquiredInCellId: 'v_45_67',
      status: ItemStatus.active,
    );

Map<String, dynamic> _baseJson() => {
      'id': 'item_base',
      'definition_id': 'fauna_test',
      'display_name': 'Test Animal',
      'category': 'fauna',
      'acquired_at': '2026-01-01T00:00:00Z',
      'status': 'active',
    };
