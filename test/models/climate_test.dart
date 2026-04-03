import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/models/climate.dart';

void main() {
  group('Climate', () {
    test('fromLatitude returns tropic for 0°–23.5°', () {
      expect(Climate.fromLatitude(0), Climate.tropic);
      expect(Climate.fromLatitude(10), Climate.tropic);
      expect(Climate.fromLatitude(23.5), Climate.tropic);
    });

    test('fromLatitude returns temperate for 23.5°–55°', () {
      expect(Climate.fromLatitude(23.6), Climate.temperate);
      expect(Climate.fromLatitude(40), Climate.temperate);
      expect(Climate.fromLatitude(55.0), Climate.temperate);
    });

    test('fromLatitude returns boreal for 55°–66.5°', () {
      expect(Climate.fromLatitude(55.1), Climate.boreal);
      expect(Climate.fromLatitude(60), Climate.boreal);
      expect(Climate.fromLatitude(66.5), Climate.boreal);
    });

    test('fromLatitude returns frigid for >66.5°', () {
      expect(Climate.fromLatitude(66.6), Climate.frigid);
      expect(Climate.fromLatitude(80), Climate.frigid);
      expect(Climate.fromLatitude(90), Climate.frigid);
    });

    test('fromLatitude handles southern hemisphere (negative latitude)', () {
      expect(Climate.fromLatitude(-10), Climate.tropic);
      expect(Climate.fromLatitude(-45), Climate.temperate);
      expect(Climate.fromLatitude(-60), Climate.boreal);
      expect(Climate.fromLatitude(-80), Climate.frigid);
    });

    test('fromString round-trips for all values', () {
      for (final c in Climate.values) {
        expect(Climate.fromString(c.name), c);
      }
    });

    test('fromString throws on unknown value', () {
      expect(() => Climate.fromString('arctic'), throwsArgumentError);
    });

    test('displayName returns capitalized names', () {
      expect(Climate.tropic.displayName, 'Tropic');
      expect(Climate.temperate.displayName, 'Temperate');
      expect(Climate.boreal.displayName, 'Boreal');
      expect(Climate.frigid.displayName, 'Frigid');
    });

    test('toString returns enum name', () {
      expect(Climate.tropic.toString(), 'tropic');
    });
  });
}
