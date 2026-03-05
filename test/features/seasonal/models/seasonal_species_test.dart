import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/core/models/season.dart';
import 'package:fog_of_world/features/seasonal/models/seasonal_species.dart';

void main() {
  group('SeasonAvailability', () {
    test('enum has exactly three values', () {
      expect(SeasonAvailability.values.length, equals(3));
      expect(SeasonAvailability.values, contains(SeasonAvailability.yearRound));
      expect(SeasonAvailability.values, contains(SeasonAvailability.summerOnly));
      expect(SeasonAvailability.values, contains(SeasonAvailability.winterOnly));
    });

    group('yearRound', () {
      test('is available in summer', () {
        expect(
          SeasonAvailability.yearRound.isAvailableIn(Season.summer),
          isTrue,
        );
      });

      test('is available in winter', () {
        expect(
          SeasonAvailability.yearRound.isAvailableIn(Season.winter),
          isTrue,
        );
      });
    });

    group('summerOnly', () {
      test('is available in summer', () {
        expect(
          SeasonAvailability.summerOnly.isAvailableIn(Season.summer),
          isTrue,
        );
      });

      test('is NOT available in winter', () {
        expect(
          SeasonAvailability.summerOnly.isAvailableIn(Season.winter),
          isFalse,
        );
      });
    });

    group('winterOnly', () {
      test('is available in winter', () {
        expect(
          SeasonAvailability.winterOnly.isAvailableIn(Season.winter),
          isTrue,
        );
      });

      test('is NOT available in summer', () {
        expect(
          SeasonAvailability.winterOnly.isAvailableIn(Season.summer),
          isFalse,
        );
      });
    });
  });
}
