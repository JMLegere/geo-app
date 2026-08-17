import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/identification/data/dtos/item_dto.dart';
import 'package:earth_nova/core/domain/entities/item.dart';

void main() {
  final acquiredAt = DateTime.utc(2026, 1, 1);

  final fullJson = {
    'id': 'i1',
    'definition_id': 'def1',
    'base_item_id': 'fauna:lion',
    'base_item_version_id': '123e4567-e89b-12d3-a456-426614174000',
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
      expect(domain.baseItemId, 'fauna:lion');
      expect(
        domain.baseItemVersionId,
        '123e4567-e89b-12d3-a456-426614174000',
      );
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

    test('maps unidentified metadata without exposing species fields', () {
      final json = {
        'id': 'i-unidentified',
        'display_name': 'Unidentified fauna specimen',
        'category': 'fauna',
        'acquired_at': acquiredAt.toIso8601String(),
        'status': 'active',
        'identification_state': 'unidentified',
      };

      final item = ItemDto.fromJson(json).toDomain();

      expect(item.identificationState, ItemIdentificationState.unidentified);
      expect(item.displayName, 'Unidentified fauna specimen');
      expect(item.scientificName, isNull);
      expect(item.definitionId, isNull);
      expect(item.baseItemId, isNull);
      expect(item.baseItemVersionId, isNull);
      expect(item.identifiedDisplayName, isNull);
      expect(item.identifiedScientificName, isNull);
      expect(item.visibleDisplayName, 'Unidentified fauna specimen');
      expect(item.visibleScientificName, isNull);
    });

    test('null optional fields', () {
      final json = {
        'id': 'i2',
        'definition_id': 'def2',
        'acquired_at': acquiredAt.toIso8601String(),
        'base_item_id': 'fauna:unknown',
        'base_item_version_id': '123e4567-e89b-12d3-a456-426614174002',
        'display_name': 'Unknown',
      };
      final dto = ItemDto.fromJson(json);
      final domain = dto.toDomain();
      expect(domain.scientificName, isNull);
      expect(domain.rarity, isNull);
      expect(domain.iconUrl, isNull);
      expect(domain.habitats, isEmpty);
      expect(domain.continents, isEmpty);
    });

    test('rejects canonical identity leaked by an unidentified projection', () {
      final json = {
        'id': 'i-leaked',
        'display_name': 'Unidentified fauna specimen',
        'category': 'fauna',
        'acquired_at': acquiredAt.toIso8601String(),
        'status': 'active',
        'identification_state': 'unidentified',
        'definition_id': 'fauna:red_fox',
      };

      expect(() => ItemDto.fromJson(json), throwsA(isA<FormatException>()));
    });
  });

  group('ItemDto examination visibility and compatibility', () {
    test('masks Base Item identity and content while unexamined', () {
      final item = ItemDto.fromJson({
        'id': 'i-unexamined',
        'display_name': 'Unidentified fauna specimen',
        'category': 'fauna',
        'acquired_at': acquiredAt.toIso8601String(),
        'status': 'active',
        'identification_state': 'unidentified',
        'examination_state': 'unexamined',
      }).toDomain();

      expect(item.examinationState, ItemExaminationState.unexamined);
      expect(item.isExamined, isFalse);
      expect(item.definitionId, isNull);
      expect(item.baseItemId, isNull);
      expect(item.baseItemVersionId, isNull);
      expect(item.scientificName, isNull);
      expect(item.habitats, isEmpty);
      expect(item.identifiedDisplayName, isNull);
    });

    test('reveals Base Item identity and content after examination only', () {
      final item = ItemDto.fromJson({
        ...fullJson,
        'identification_state': 'unidentified',
        'examination_state': 'examined',
        'examined_at': '2026-01-02T03:04:05.000Z',
      }).toDomain();

      expect(item.examinationState, ItemExaminationState.examined);
      expect(item.isExamined, isTrue);
      expect(item.examinedAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
      expect(item.identificationState, ItemIdentificationState.unidentified);
      expect(item.baseItemId, 'fauna:lion');
      expect(
        item.baseItemVersionId,
        '123e4567-e89b-12d3-a456-426614174000',
      );
      expect(item.displayName, 'Lion');
      expect(item.scientificName, 'Panthera leo');
      expect(item.habitats, ['Forest', 'Mountain']);
      expect(item.identifiedAt, isNull);
      expect(item.identifiedDisplayName, isNull);
      expect(item.identifiedScientificName, isNull);
    });

    test('derives legacy examination state from identification state', () {
      final legacyIdentified = ItemDto.fromJson(fullJson).toDomain();
      final legacyUnidentified = ItemDto.fromJson({
        'id': 'legacy-unidentified',
        'display_name': 'Unidentified fauna specimen',
        'category': 'fauna',
        'acquired_at': acquiredAt.toIso8601String(),
        'status': 'active',
        'identification_state': 'unidentified',
      }).toDomain();

      expect(legacyIdentified.examinationState, ItemExaminationState.examined);
      expect(
          legacyUnidentified.examinationState, ItemExaminationState.unexamined);
    });

    test(
        'rejects identification property values leaked by an examined projection',
        () {
      final leaked = {
        ...fullJson,
        'identification_state': 'unidentified',
        'examination_state': 'examined',
        'identified_display_name': 'Northern cardinal',
      };

      expect(() => ItemDto.fromJson(leaked), throwsA(isA<FormatException>()));
    });
  });

  group('_parseJsonArray edge cases', () {
    test('null input returns empty list', () {
      final json = {
        'id': 'i3',
        'definition_id': 'def3',
        'base_item_id': 'fauna:unknown',
        'base_item_version_id': '123e4567-e89b-12d3-a456-426614174003',
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
        'base_item_id': 'fauna:unknown',
        'base_item_version_id': '123e4567-e89b-12d3-a456-426614174004',
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
        'base_item_id': 'fauna:unknown',
        'base_item_version_id': '123e4567-e89b-12d3-a456-426614174005',
      };
      final domain = ItemDto.fromJson(json).toDomain();
      expect(domain.habitats, isEmpty);
    });

    test('valid JSON array parsed', () {
      final json = {
        'id': 'i3',
        'definition_id': 'def3',
        'base_item_id': 'fauna:unknown',
        'base_item_version_id': '123e4567-e89b-12d3-a456-426614174006',
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
        'base_item_id': 'fauna:unknown',
        'base_item_version_id': '123e4567-e89b-12d3-a456-426614174007',
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
        baseItemId: 'fauna:lion',
        baseItemVersionId: '123e4567-e89b-12d3-a456-426614174000',
        continents: ['Africa'],
      );
      final dto = ItemDto.fromDomain(item);
      final json = dto.toJson();
      expect(json['id'], 'i1');
      expect(json['category'], 'fauna');
      expect(json['status'], 'active');
      expect(json['habitats_json'], '["Forest"]');
      expect(json['continents_json'], '["Africa"]');
      expect(json['base_item_id'], 'fauna:lion');
      expect(
        json['base_item_version_id'],
        '123e4567-e89b-12d3-a456-426614174000',
      );
    });
  });

  group('ItemDto unidentified projection boundary', () {
    test(
        'rejects every canonical or identified field leaked by an unknown find',
        () {
      const hiddenFields = [
        'definition_id',
        'base_item_id',
        'base_item_version_id',
        'scientific_name',
        'rarity',
        'icon_url',
        'icon_url_frame2',
        'art_url',
        'taxonomic_class',
        'habitats_json',
        'continents_json',
        'identified_at',
        'identified_display_name',
        'identified_scientific_name',
        'identified_taxonomic_class',
        'identified_habitats_json',
        'identified_continents_json',
      ];
      final unknown = <String, dynamic>{
        'id': 'unknown-1',
        'display_name': 'Unidentified fauna specimen',
        'acquired_at': acquiredAt.toIso8601String(),
        'identification_state': 'unidentified',
      };

      for (final hiddenField in hiddenFields) {
        final leaked = Map<String, dynamic>.from(unknown)
          ..[hiddenField] = 'canonical-value';
        expect(
          () => ItemDto.fromJson(leaked),
          throwsA(isA<FormatException>()),
          reason: '$hiddenField must remain masked before identification',
        );
      }
    });

    test('serializes a masked unknown find without canonical identity values',
        () {
      final unknown = ItemDto.fromJson({
        'id': 'unknown-2',
        'display_name': 'Unidentified flora specimen',
        'acquired_at': acquiredAt.toIso8601String(),
        'identification_state': 'unidentified',
      });

      final wire = unknown.toJson();

      expect(wire['identification_state'], 'unidentified');
      expect(wire['display_name'], 'Unidentified flora specimen');
      expect(wire['definition_id'], isNull);
      expect(wire['base_item_id'], isNull);
      expect(wire['identified_display_name'], isNull);
    });

    test('rejects non-string optional item text rather than coercing it', () {
      final invalidScientificName = Map<String, dynamic>.from(fullJson)
        ..['scientific_name'] = 42;

      expect(
        () => ItemDto.fromJson(invalidScientificName),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('ItemDto.fromJson Base Item binding validation', () {
    test('rejects missing Base Item binding fields', () {
      final missingBaseItemId = Map<String, dynamic>.from(fullJson)
        ..remove('base_item_id');
      final missingBaseItemVersionId = Map<String, dynamic>.from(fullJson)
        ..remove('base_item_version_id');

      expect(
        () => ItemDto.fromJson(missingBaseItemId),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => ItemDto.fromJson(missingBaseItemVersionId),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects blank or malformed Base Item bindings', () {
      final blankBaseItemId = Map<String, dynamic>.from(fullJson)
        ..['base_item_id'] = '  ';
      final blankBaseItemVersionId = Map<String, dynamic>.from(fullJson)
        ..['base_item_version_id'] = '';
      final malformedBaseItemVersionId = Map<String, dynamic>.from(fullJson)
        ..['base_item_version_id'] = 'not-a-uuid';

      expect(
        () => ItemDto.fromJson(blankBaseItemId),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => ItemDto.fromJson(blankBaseItemVersionId),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => ItemDto.fromJson(malformedBaseItemVersionId),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
