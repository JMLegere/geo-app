import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/identification/data/dtos/item_dto.dart';
import 'package:earth_nova/core/domain/entities/item.dart';

void main() {
  final acquiredAt = DateTime.utc(2026, 1, 1);

  final fullJson = {
    'id': 'i1',
    'definition_id': 'def1',
    'display_name': 'Lion',
    'scientific_name': 'Panthera leo',
    'category': 'fauna',
    'rarity': 'EN',
    'icon_url': 'https://example.com/lion.png',
    'icon_url_frame2': 'https://example.com/lion2.png',
    'art_url': 'https://example.com/lion_art.png',
    'acquired_at': acquiredAt.toIso8601String(),
    'acquired_in_cell_id': 'cell1',
    'status': 'active',
    'taxonomic_class': 'MAMMALIA',
    'habitats_json': '["Forest","Mountain"]',
    'continents_json': '["Africa","Asia"]',
  };

  group('ItemDto.fromJson → toDomain', () {
    test('round-trip with all fields', () {
      final dto = ItemDto.fromJson(fullJson);
      final domain = dto.toDomain();
      expect(domain.id, 'i1');
      expect(domain.definitionId, 'def1');
      expect(domain.displayName, 'Lion');
      expect(domain.scientificName, 'Panthera leo');
      expect(domain.category, ItemCategory.fauna);
      expect(domain.rarity, 'EN');
      expect(domain.iconUrl, 'https://example.com/lion.png');
      expect(domain.iconUrlFrame2, 'https://example.com/lion2.png');
      expect(domain.artUrl, 'https://example.com/lion_art.png');
      expect(domain.acquiredAt, acquiredAt);
      expect(domain.acquiredInCellId, 'cell1');
      expect(domain.status, ItemStatus.active);
      expect(domain.taxonomicClass, 'MAMMALIA');
      expect(domain.habitats, ['Forest', 'Mountain']);
      expect(domain.continents, ['Africa', 'Asia']);
    });

    test('null optional fields', () {
      final json = {
        'id': 'i2',
        'definition_id': 'def2',
        'acquired_at': acquiredAt.toIso8601String(),
      };
      final dto = ItemDto.fromJson(json);
      final domain = dto.toDomain();
      expect(domain.scientificName, isNull);
      expect(domain.rarity, isNull);
      expect(domain.iconUrl, isNull);
      expect(domain.habitats, isEmpty);
      expect(domain.continents, isEmpty);
    });
  });

  group('_parseJsonArray edge cases', () {
    test('null input returns empty list', () {
      final json = {
        'id': 'i3',
        'definition_id': 'def3',
        'acquired_at': acquiredAt.toIso8601String(),
        'habitats_json': null,
      };
      final domain = ItemDto.fromJson(json).toDomain();
      expect(domain.habitats, isEmpty);
    });

    test('empty string returns empty list', () {
      final json = {
        'id': 'i3',
        'definition_id': 'def3',
        'acquired_at': acquiredAt.toIso8601String(),
        'habitats_json': '',
      };
      final domain = ItemDto.fromJson(json).toDomain();
      expect(domain.habitats, isEmpty);
    });

    test('"[]" returns empty list', () {
      final json = {
        'id': 'i3',
        'definition_id': 'def3',
        'acquired_at': acquiredAt.toIso8601String(),
        'habitats_json': '[]',
      };
      final domain = ItemDto.fromJson(json).toDomain();
      expect(domain.habitats, isEmpty);
    });

    test('valid JSON array parsed', () {
      final json = {
        'id': 'i3',
        'definition_id': 'def3',
        'acquired_at': acquiredAt.toIso8601String(),
        'habitats_json': '["Forest","Mountain"]',
      };
      final domain = ItemDto.fromJson(json).toDomain();
      expect(domain.habitats, ['Forest', 'Mountain']);
    });

    test('malformed JSON returns empty list', () {
      final json = {
        'id': 'i3',
        'definition_id': 'def3',
        'acquired_at': acquiredAt.toIso8601String(),
        'habitats_json': 'not-json',
      };
      final domain = ItemDto.fromJson(json).toDomain();
      expect(domain.habitats, isEmpty);
    });
  });

  group('ItemDto.fromDomain → toJson', () {
    test('round-trip', () {
      final item = Item(
        id: 'i1',
        definitionId: 'def1',
        displayName: 'Lion',
        category: ItemCategory.fauna,
        acquiredAt: acquiredAt,
        status: ItemStatus.active,
        habitats: ['Forest'],
        continents: ['Africa'],
      );
      final dto = ItemDto.fromDomain(item);
      final json = dto.toJson();
      expect(json['id'], 'i1');
      expect(json['category'], 'fauna');
      expect(json['status'], 'active');
      expect(json['habitats_json'], '["Forest"]');
      expect(json['continents_json'], '["Africa"]');
    });
  });
}
