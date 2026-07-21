import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/habitat.dart';

void main() {
  group('Habitat.fromString', () {
    test('parses Forest', () {
      expect(Habitat.fromString('Forest'), Habitat.forest);
    });

    test('parses case-insensitive', () {
      expect(Habitat.fromString('forest'), Habitat.forest);
      expect(Habitat.fromString('MOUNTAIN'), Habitat.mountain);
    });

    test('returns null for null', () {
      expect(Habitat.fromString(null), isNull);
    });

    test('returns null for empty string', () {
      expect(Habitat.fromString(''), isNull);
    });

    test('returns null for unknown', () {
      expect(Habitat.fromString('Jungle'), isNull);
    });

    test('parses all known habitats', () {
      expect(Habitat.fromString('Plains'), Habitat.plains);
      expect(Habitat.fromString('Freshwater'), Habitat.freshwater);
      expect(Habitat.fromString('Ocean'), Habitat.ocean);
      expect(Habitat.fromString('Swamp'), Habitat.swamp);
      expect(Habitat.fromString('Desert'), Habitat.desert);
      expect(Habitat.fromString('Urban'), Habitat.urban);
    });

    test('parses normalized habitat aliases', () {
      expect(Habitat.fromString('grassland'), Habitat.plains);
      expect(Habitat.fromString('wetland'), Habitat.swamp);
      expect(Habitat.fromString('coastal'), Habitat.ocean);
      expect(Habitat.fromString('urban'), Habitat.urban);
      expect(Habitat.fromString('built-up'), Habitat.urban);
    });
  });

  group('Habitat enum', () {
    test('has label', () {
      expect(Habitat.forest.label, 'Forest');
      expect(Habitat.ocean.label, 'Ocean');
    });

    test('ocean exists (renamed from saltwater)', () {
      expect(Habitat.ocean, isNotNull);
    });

    test('saltwater no longer exists', () {
      expect(
        Habitat.values.any((h) => h.name == 'saltwater'),
        isFalse,
      );
    });

    test('unknown no longer exists', () {
      expect(
        Habitat.values.any((h) => h.name == 'unknown'),
        isFalse,
      );
    });

    test('has 8 habitat types', () {
      expect(Habitat.values.length, 8);
    });

    test('each habitat has a color', () {
      for (final h in Habitat.values) {
        expect(h.colorValue, isA<int>());
      }
    });

    test('forest is green', () {
      final c = Color(Habitat.forest.colorValue);
      expect(c.g, greaterThan(c.r));
      expect(c.g, greaterThan(c.b));
    });

    test('ocean is purple', () {
      final c = Color(Habitat.ocean.colorValue);
      expect(c.r, greaterThan(0));
      expect(c.b, greaterThan(0));
      expect(c.g, lessThan(c.r));
    });

    test('freshwater is blue', () {
      final c = Color(Habitat.freshwater.colorValue);
      expect(c.b, greaterThan(c.r));
      expect(c.b, greaterThan(c.g));
    });

    test('desert is orange', () {
      final c = Color(Habitat.desert.colorValue);
      expect(c.r, greaterThan(c.g));
      expect(c.r, greaterThan(c.b));
      expect(c.g, greaterThan(c.b));
    });

    test('plains is yellow', () {
      final c = Color(Habitat.plains.colorValue);
      expect(c.r, greaterThan(0));
      expect(c.g, greaterThan(0));
      expect(c.b, lessThan(c.r));
    });

    test('mountain is red', () {
      final c = Color(Habitat.mountain.colorValue);
      expect(c.r, greaterThan(c.g));
      expect(c.r, greaterThan(c.b));
    });

    test('swamp is grey', () {
      final c = Color(Habitat.swamp.colorValue);
      final avg = (c.r + c.g + c.b) / 3;
      expect((c.r - avg).abs(), lessThan(0.1));
      expect((c.g - avg).abs(), lessThan(0.1));
      expect((c.b - avg).abs(), lessThan(0.1));
    });

    test('urban is slate-toned', () {
      final c = Color(Habitat.urban.colorValue);
      expect(c.b, greaterThan(c.r * 0.8));
      expect(c.g, greaterThan(c.r * 0.8));
    });
  });

  group('Habitat.blendColorValues', () {
    test('single habitat returns its own color', () {
      expect(
        Habitat.blendColorValues([Habitat.forest]),
        Habitat.forest.colorValue,
      );
    });

    test('blend of forest and freshwater is teal-ish', () {
      final blended = Color(
        Habitat.blendColorValues([Habitat.forest, Habitat.freshwater]),
      );
      expect(blended.g, greaterThan(blended.r));
      expect(blended.b, greaterThan(blended.r));
    });

    test('blend is weighted RGB average', () {
      final forest = Color(Habitat.forest.colorValue);
      final ocean = Color(Habitat.ocean.colorValue);
      final blended = Color(
        Habitat.blendColorValues([Habitat.forest, Habitat.ocean]),
      );
      expect(blended.r, closeTo((forest.r + ocean.r) / 2, 0.01));
      expect(blended.g, closeTo((forest.g + ocean.g) / 2, 0.01));
      expect(blended.b, closeTo((forest.b + ocean.b) / 2, 0.01));
    });

    test('empty list returns transparent ARGB', () {
      expect(Habitat.blendColorValues([]), 0x00000000);
    });
  });
}
