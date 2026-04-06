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
