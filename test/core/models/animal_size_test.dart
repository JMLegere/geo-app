import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/models/animal_size.dart';

void main() {
  group('AnimalSize', () {
    // -------------------------------------------------------------------------
    // All 9 enum values exist
    // -------------------------------------------------------------------------

    test('has exactly 9 values', () {
      expect(AnimalSize.values, hasLength(9));
    });

    test('all expected values are present', () {
      const expected = {
        'fine',
        'diminutive',
        'tiny',
        'small',
        'medium',
        'large',
        'huge',
        'gargantuan',
        'colossal',
      };
      final names = AnimalSize.values.map((s) => s.name).toSet();
      expect(names, equals(expected));
    });

    // -------------------------------------------------------------------------
    // minGrams / maxGrams / rangeSpan correctness
    // -------------------------------------------------------------------------

    test('fine has correct gram range', () {
      expect(AnimalSize.fine.minGrams, 1);
      expect(AnimalSize.fine.maxGrams, 49);
    });

    test('diminutive has correct gram range', () {
      expect(AnimalSize.diminutive.minGrams, 50);
      expect(AnimalSize.diminutive.maxGrams, 499);
    });

    test('tiny has correct gram range', () {
      expect(AnimalSize.tiny.minGrams, 500);
      expect(AnimalSize.tiny.maxGrams, 3999);
    });

    test('small has correct gram range', () {
      expect(AnimalSize.small.minGrams, 4000);
      expect(AnimalSize.small.maxGrams, 24999);
    });

    test('medium has correct gram range', () {
      expect(AnimalSize.medium.minGrams, 25000);
      expect(AnimalSize.medium.maxGrams, 149999);
    });

    test('large has correct gram range', () {
      expect(AnimalSize.large.minGrams, 150000);
      expect(AnimalSize.large.maxGrams, 499999);
    });

    test('huge has correct gram range', () {
      expect(AnimalSize.huge.minGrams, 500000);
      expect(AnimalSize.huge.maxGrams, 1999999);
    });

    test('gargantuan has correct gram range', () {
      expect(AnimalSize.gargantuan.minGrams, 2000000);
      expect(AnimalSize.gargantuan.maxGrams, 14999999);
    });

    test('colossal has correct gram range', () {
      expect(AnimalSize.colossal.minGrams, 15000000);
      expect(AnimalSize.colossal.maxGrams, 247000000);
    });

    test('rangeSpan equals maxGrams - minGrams + 1 for all values', () {
      for (final size in AnimalSize.values) {
        expect(
          size.rangeSpan,
          size.maxGrams - size.minGrams + 1,
          reason: '${size.name}.rangeSpan is incorrect',
        );
      }
    });

    test('ranges are non-overlapping and contiguous', () {
      // Each maxGrams + 1 should equal the next minGrams.
      final sorted = [...AnimalSize.values]
        ..sort((a, b) => a.minGrams.compareTo(b.minGrams));
      for (var i = 0; i < sorted.length - 1; i++) {
        expect(
          sorted[i + 1].minGrams,
          sorted[i].maxGrams + 1,
          reason: '${sorted[i].name} maxGrams=${sorted[i].maxGrams} and '
              '${sorted[i + 1].name} minGrams=${sorted[i + 1].minGrams} are not contiguous',
        );
      }
    });

    test('minGrams < maxGrams for every value', () {
      for (final size in AnimalSize.values) {
        expect(size.minGrams, lessThan(size.maxGrams),
            reason: '${size.name}: minGrams must be less than maxGrams');
      }
    });

    test('rangeSpan is positive for every value', () {
      for (final size in AnimalSize.values) {
        expect(size.rangeSpan, greaterThan(0),
            reason: '${size.name}.rangeSpan must be positive');
      }
    });

    // -------------------------------------------------------------------------
    // fromString round-trip
    // -------------------------------------------------------------------------

    test('fromString returns correct value for each name', () {
      for (final size in AnimalSize.values) {
        expect(AnimalSize.fromString(size.name), equals(size),
            reason: 'fromString("${size.name}") should return ${size.name}');
      }
    });

    test('fromString round-trips via toString', () {
      for (final size in AnimalSize.values) {
        final name = size.toString();
        expect(AnimalSize.fromString(name), equals(size));
      }
    });

    test('toString returns the enum name', () {
      for (final size in AnimalSize.values) {
        expect(size.toString(), equals(size.name));
      }
    });

    // -------------------------------------------------------------------------
    // fromString — unknown value throws
    // -------------------------------------------------------------------------

    test('fromString throws ArgumentError for unknown value', () {
      expect(
        () => AnimalSize.fromString('enormous'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('fromString throws ArgumentError for empty string', () {
      expect(
        () => AnimalSize.fromString(''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('fromString is case-sensitive (uppercase throws)', () {
      expect(
        () => AnimalSize.fromString('Medium'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
