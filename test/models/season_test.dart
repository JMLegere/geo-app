import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/models/season.dart';

void main() {
  group('Season', () {
    test('fromDate returns summer for May through October', () {
      for (final month in [5, 6, 7, 8, 9, 10]) {
        expect(Season.fromDate(DateTime(2026, month, 15)), Season.summer,
            reason: 'month $month should be summer');
      }
    });

    test('fromDate returns winter for November through April', () {
      for (final month in [1, 2, 3, 4, 11, 12]) {
        expect(Season.fromDate(DateTime(2026, month, 15)), Season.winter,
            reason: 'month $month should be winter');
      }
    });

    test('fromString round-trips for all values', () {
      for (final season in Season.values) {
        expect(Season.fromString(season.name), season);
      }
    });

    test('fromString throws on unknown value', () {
      expect(() => Season.fromString('spring'), throwsArgumentError);
    });

    test('displayName returns capitalized names', () {
      expect(Season.summer.displayName, 'Summer');
      expect(Season.winter.displayName, 'Winter');
    });

    test('opposite returns the other season', () {
      expect(Season.summer.opposite, Season.winter);
      expect(Season.winter.opposite, Season.summer);
    });

    test('isSummer and isWinter are exclusive', () {
      expect(Season.summer.isSummer, true);
      expect(Season.summer.isWinter, false);
      expect(Season.winter.isSummer, false);
      expect(Season.winter.isWinter, true);
    });

    test('toString returns enum name', () {
      expect(Season.summer.toString(), 'summer');
      expect(Season.winter.toString(), 'winter');
    });
  });
}
