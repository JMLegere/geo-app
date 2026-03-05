import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/core/models/continent.dart';
import 'package:fog_of_world/core/species/continent_resolver.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Known city coordinates
  // ---------------------------------------------------------------------------

  group('ContinentResolver known cities', () {
    test('New York (40.7, -74.0) resolves to North America', () {
      expect(
        ContinentResolver.resolve(40.7, -74.0),
        equals(Continent.northAmerica),
      );
    });

    test('London (51.5, -0.1) resolves to Europe', () {
      expect(
        ContinentResolver.resolve(51.5, -0.1),
        equals(Continent.europe),
      );
    });

    test('Tokyo (35.7, 139.7) resolves to Asia', () {
      expect(
        ContinentResolver.resolve(35.7, 139.7),
        equals(Continent.asia),
      );
    });

    test('Sydney (-33.9, 151.2) resolves to Oceania', () {
      expect(
        ContinentResolver.resolve(-33.9, 151.2),
        equals(Continent.oceania),
      );
    });

    test('São Paulo (-23.5, -46.6) resolves to South America', () {
      expect(
        ContinentResolver.resolve(-23.5, -46.6),
        equals(Continent.southAmerica),
      );
    });

    test('Nairobi (-1.3, 36.8) resolves to Africa', () {
      expect(
        ContinentResolver.resolve(-1.3, 36.8),
        equals(Continent.africa),
      );
    });

    test('Mumbai (19.1, 72.9) resolves to Asia', () {
      expect(
        ContinentResolver.resolve(19.1, 72.9),
        equals(Continent.asia),
      );
    });

    test('Buenos Aires (-34.6, -58.4) resolves to South America', () {
      expect(
        ContinentResolver.resolve(-34.6, -58.4),
        equals(Continent.southAmerica),
      );
    });

    test('Cairo (30.0, 31.2) resolves to Africa', () {
      expect(
        ContinentResolver.resolve(30.0, 31.2),
        equals(Continent.africa),
      );
    });

    test('Auckland (-36.9, 174.8) resolves to Oceania', () {
      expect(
        ContinentResolver.resolve(-36.9, 174.8),
        equals(Continent.oceania),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Ocean coordinates — should not crash
  // ---------------------------------------------------------------------------

  group('ContinentResolver ocean coordinates', () {
    test('mid-Atlantic (20.0, -35.0) resolves to a continent without crash',
        () {
      expect(
        () => ContinentResolver.resolve(20.0, -35.0),
        returnsNormally,
      );
    });

    test('mid-Pacific (0.0, -150.0) resolves to a continent without crash', () {
      expect(
        () => ContinentResolver.resolve(0.0, -150.0),
        returnsNormally,
      );
    });

    test('southern ocean (-60.0, 0.0) resolves to a continent without crash',
        () {
      expect(
        () => ContinentResolver.resolve(-60.0, 0.0),
        returnsNormally,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Edge cases
  // ---------------------------------------------------------------------------

  group('ContinentResolver edge cases', () {
    test('equator / prime meridian (0.0, 0.0) resolves without crash', () {
      expect(
        () => ContinentResolver.resolve(0.0, 0.0),
        returnsNormally,
      );
    });

    test('north pole (90.0, 0.0) resolves without crash', () {
      expect(
        () => ContinentResolver.resolve(90.0, 0.0),
        returnsNormally,
      );
    });

    test('south pole (-90.0, 0.0) resolves without crash', () {
      expect(
        () => ContinentResolver.resolve(-90.0, 0.0),
        returnsNormally,
      );
    });

    test('international date line east (0.0, 179.9) resolves without crash',
        () {
      expect(
        () => ContinentResolver.resolve(0.0, 179.9),
        returnsNormally,
      );
    });

    test('international date line west (0.0, -179.9) resolves without crash',
        () {
      expect(
        () => ContinentResolver.resolve(0.0, -179.9),
        returnsNormally,
      );
    });

    test('resolve always returns a valid Continent value', () {
      // Exhaustive spot check across the globe.
      const latSteps = [-80.0, -45.0, 0.0, 20.0, 45.0, 70.0];
      const lonSteps = [-170.0, -90.0, 0.0, 45.0, 90.0, 135.0, 170.0];

      for (final lat in latSteps) {
        for (final lon in lonSteps) {
          final result = ContinentResolver.resolve(lat, lon);
          expect(Continent.values, contains(result),
              reason: 'resolve($lat, $lon) returned invalid value');
        }
      }
    });
  });
}
