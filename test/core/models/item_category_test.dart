import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/core/models/item_category.dart';

void main() {
  group('ItemCategory', () {
    test('all 7 values exist', () {
      expect(ItemCategory.values.length, equals(7));
      expect(ItemCategory.values, contains(ItemCategory.fauna));
      expect(ItemCategory.values, contains(ItemCategory.flora));
      expect(ItemCategory.values, contains(ItemCategory.mineral));
      expect(ItemCategory.values, contains(ItemCategory.fossil));
      expect(ItemCategory.values, contains(ItemCategory.artifact));
      expect(ItemCategory.values, contains(ItemCategory.food));
      expect(ItemCategory.values, contains(ItemCategory.orb));
    });

    test('displayName returns correct human-readable names', () {
      expect(ItemCategory.fauna.displayName, equals('Fauna'));
      expect(ItemCategory.flora.displayName, equals('Flora'));
      expect(ItemCategory.mineral.displayName, equals('Mineral'));
      expect(ItemCategory.fossil.displayName, equals('Fossil'));
      expect(ItemCategory.artifact.displayName, equals('Artifact'));
      expect(ItemCategory.food.displayName, equals('Food'));
      expect(ItemCategory.orb.displayName, equals('Orb'));
    });

    group('fromString', () {
      test('parses each enum name', () {
        for (final cat in ItemCategory.values) {
          expect(ItemCategory.fromString(cat.name), equals(cat));
        }
      });

      test('food is parseable', () {
        expect(ItemCategory.fromString('food'), equals(ItemCategory.food));
      });

      test('orb is parseable', () {
        expect(ItemCategory.fromString('orb'), equals(ItemCategory.orb));
      });

      test('throws on unknown value', () {
        expect(() => ItemCategory.fromString('gem'), throwsArgumentError);
      });
    });

    test('toString returns name', () {
      expect(ItemCategory.food.toString(), equals('food'));
      expect(ItemCategory.orb.toString(), equals('orb'));
    });
  });
}
