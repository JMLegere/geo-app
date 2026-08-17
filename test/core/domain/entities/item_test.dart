import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/domain/entities/taxonomic_group.dart';

void main() {
  final baseItem = Item(
    id: 'i1',
    definitionId: 'def1',
    displayName: 'Lion',
    category: ItemCategory.fauna,
    acquiredAt: DateTime(2026),
    status: ItemStatus.active,
  );

  group('Item construction', () {
    test('constructs with required fields', () {
      expect(baseItem.id, 'i1');
      expect(baseItem.definitionId, 'def1');
      expect(baseItem.displayName, 'Lion');
      expect(baseItem.category, ItemCategory.fauna);
      expect(baseItem.status, ItemStatus.active);
      expect(baseItem.scientificName, isNull);
      expect(baseItem.baseItemId, isNull);
      expect(baseItem.baseItemVersionId, isNull);
      expect(baseItem.habitats, isEmpty);
      expect(baseItem.continents, isEmpty);
    });

    test('copyWith returns new instance with overridden fields', () {
      final copied =
          baseItem.copyWith(displayName: 'Tiger', status: ItemStatus.donated);
      expect(copied.displayName, 'Tiger');
      expect(copied.status, ItemStatus.donated);
      expect(copied.id, 'i1');
    });

    test('preserves exact Base Item binding through copyWith', () {
      const baseItemId = 'fauna:lion';
      const baseItemVersionId = '123e4567-e89b-12d3-a456-426614174000';
      final bound = baseItem.copyWith(
        baseItemId: baseItemId,
        baseItemVersionId: baseItemVersionId,
      );

      final copied = bound.copyWith(displayName: 'Tiger');

      expect(copied.baseItemId, baseItemId);
      expect(copied.baseItemVersionId, baseItemVersionId);
      expect(copied.displayName, 'Tiger');
    });
  });

  group('Item identification', () {
    test('reveals identified values without changing exact Base Item binding',
        () {
      final item = baseItem.copyWith(
        baseItemId: 'fauna:lion',
        baseItemVersionId: '123e4567-e89b-12d3-a456-426614174000',
        identificationState: ItemIdentificationState.unidentified,
        identifiedDisplayName: 'African Lion',
        identifiedScientificName: 'Panthera leo',
      );

      final identified = item.identify(at: DateTime.utc(2026, 1, 2));

      expect(
          identified.identificationState, ItemIdentificationState.identified);
      expect(identified.visibleDisplayName, 'African Lion');
      expect(identified.visibleScientificName, 'Panthera leo');
      expect(identified.baseItemId, 'fauna:lion');
      expect(
        identified.baseItemVersionId,
        '123e4567-e89b-12d3-a456-426614174000',
      );
    });
  });

  group('Item examination', () {
    test('keeps three-level Item knowledge distinct', () {
      final unexamined = baseItem.copyWith(
        scientificName: 'Panthera leo',
        identificationState: ItemIdentificationState.unidentified,
        examinationState: ItemExaminationState.unexamined,
      );
      final examined = unexamined.copyWith(
        examinationState: ItemExaminationState.examined,
        examinedAt: DateTime.utc(2026, 1, 2),
      );
      final identified = unexamined.identify(at: DateTime.utc(2026, 1, 3));

      expect(unexamined.isExamined, isFalse);
      expect(unexamined.visibleDisplayName, 'Unidentified fauna specimen');
      expect(unexamined.visibleScientificName, isNull);
      expect(examined.isExamined, isTrue);
      expect(
          examined.identificationState, ItemIdentificationState.unidentified);
      expect(examined.examinedAt, DateTime.utc(2026, 1, 2));
      expect(examined.visibleDisplayName, 'Lion');
      expect(examined.visibleScientificName, 'Panthera leo');
      expect(identified.isExamined, isTrue);
      expect(
          identified.identificationState, ItemIdentificationState.identified);
    });
  });

  group('Item value equality', () {
    test('equal items', () {
      final a = Item(
        id: 'i1',
        definitionId: 'def1',
        displayName: 'Lion',
        category: ItemCategory.fauna,
        acquiredAt: DateTime(2026),
        status: ItemStatus.active,
      );
      final b = Item(
        id: 'i1',
        definitionId: 'def1',
        displayName: 'Lion',
        category: ItemCategory.fauna,
        acquiredAt: DateTime(2026),
        status: ItemStatus.active,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('Base Item bindings participate in equality', () {
      final a = baseItem.copyWith(
        baseItemId: 'fauna:lion',
        baseItemVersionId: '123e4567-e89b-12d3-a456-426614174000',
      );
      final b = baseItem.copyWith(
        baseItemId: 'fauna:lion',
        baseItemVersionId: '123e4567-e89b-12d3-a456-426614174000',
      );
      final differentVersion = b.copyWith(
        baseItemVersionId: '123e4567-e89b-12d3-a456-426614174001',
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(differentVersion)));
    });
  });

  group('Item.taxonomicGroup getter', () {
    test('returns mammals for MAMMALIA', () {
      final item = baseItem.copyWith(taxonomicClass: 'MAMMALIA');
      expect(item.taxonomicGroup, TaxonomicGroup.mammals);
    });

    test('returns birds for AVES', () {
      final item = baseItem.copyWith(taxonomicClass: 'AVES');
      expect(item.taxonomicGroup, TaxonomicGroup.birds);
    });

    test('returns other for null taxonomicClass', () {
      expect(baseItem.taxonomicGroup, TaxonomicGroup.other);
    });
  });

  group('ItemCategory', () {
    test('has label', () {
      expect(ItemCategory.fauna.label, 'Fauna');
      expect(ItemCategory.flora.label, 'Flora');
    });

    test('fromString parses known values', () {
      expect(ItemCategory.fromString('fauna'), ItemCategory.fauna);
      expect(ItemCategory.fromString('FLORA'), ItemCategory.flora);
    });

    test('fromString returns fauna for null', () {
      expect(ItemCategory.fromString(null), ItemCategory.fauna);
    });

    test('fromString returns fauna for unknown', () {
      expect(ItemCategory.fromString('unknown_cat'), ItemCategory.fauna);
    });
  });

  group('ItemStatus', () {
    test('fromString parses known values', () {
      expect(ItemStatus.fromString('active'), ItemStatus.active);
      expect(ItemStatus.fromString('DONATED'), ItemStatus.donated);
    });

    test('fromString returns active for null', () {
      expect(ItemStatus.fromString(null), ItemStatus.active);
    });
  });
}
