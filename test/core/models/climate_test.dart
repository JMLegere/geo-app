import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/models/climate.dart';

void main() {
  group('Climate', () {
    test('all 4 values exist', () {
      expect(Climate.values.length, equals(4));
      expect(Climate.values, contains(Climate.tropic));
      expect(Climate.values, contains(Climate.temperate));
      expect(Climate.values, contains(Climate.boreal));
      expect(Climate.values, contains(Climate.frigid));
    });

    test('displayName returns correct names', () {
      expect(Climate.tropic.displayName, equals('Tropic'));
      expect(Climate.temperate.displayName, equals('Temperate'));
      expect(Climate.boreal.displayName, equals('Boreal'));
      expect(Climate.frigid.displayName, equals('Frigid'));
    });

    group('fromLatitude', () {
      test('equator (0°) → tropic', () {
        expect(Climate.fromLatitude(0.0), equals(Climate.tropic));
      });

      test('23.5° → tropic (boundary inclusive)', () {
        expect(Climate.fromLatitude(23.5), equals(Climate.tropic));
      });

      test('23.51° → temperate (just past boundary)', () {
        expect(Climate.fromLatitude(23.51), equals(Climate.temperate));
      });

      test('45° → temperate (mid-range)', () {
        expect(Climate.fromLatitude(45.0), equals(Climate.temperate));
      });

      test('55.0° → temperate (boundary inclusive)', () {
        expect(Climate.fromLatitude(55.0), equals(Climate.temperate));
      });

      test('55.01° → boreal (just past boundary)', () {
        expect(Climate.fromLatitude(55.01), equals(Climate.boreal));
      });

      test('60° → boreal (mid-range)', () {
        expect(Climate.fromLatitude(60.0), equals(Climate.boreal));
      });

      test('66.5° → boreal (boundary inclusive)', () {
        expect(Climate.fromLatitude(66.5), equals(Climate.boreal));
      });

      test('66.51° → frigid (just past boundary)', () {
        expect(Climate.fromLatitude(66.51), equals(Climate.frigid));
      });

      test('90° → frigid (north pole)', () {
        expect(Climate.fromLatitude(90.0), equals(Climate.frigid));
      });

      test('southern hemisphere: -23.5° → tropic', () {
        expect(Climate.fromLatitude(-23.5), equals(Climate.tropic));
      });

      test('southern hemisphere: -55.0° → temperate', () {
        expect(Climate.fromLatitude(-55.0), equals(Climate.temperate));
      });

      test('southern hemisphere: -66.5° → boreal', () {
        expect(Climate.fromLatitude(-66.5), equals(Climate.boreal));
      });

      test('southern hemisphere: -90.0° → frigid', () {
        expect(Climate.fromLatitude(-90.0), equals(Climate.frigid));
      });
    });

    group('fromString', () {
      test('parses each enum name', () {
        for (final c in Climate.values) {
          expect(Climate.fromString(c.name), equals(c));
        }
      });

      test('throws on unknown value', () {
        expect(() => Climate.fromString('arctic'), throwsArgumentError);
      });
    });

    test('toString returns name', () {
      expect(Climate.tropic.toString(), equals('tropic'));
      expect(Climate.frigid.toString(), equals('frigid'));
    });
  });
}
