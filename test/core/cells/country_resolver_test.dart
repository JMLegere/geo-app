import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/cells/country_resolver.dart';
import 'package:earth_nova/core/models/continent.dart';

/// Loads the bundled country boundaries asset for tests.
///
/// Tests run from the project root, so `assets/` is directly accessible.
String _loadBoundaries() {
  return File('assets/country_boundaries.json').readAsStringSync();
}

void main() {
  late CountryResolver resolver;

  setUpAll(() {
    resolver = CountryResolver.load(_loadBoundaries());
  });

  // ---------------------------------------------------------------------------
  // Loading & structure
  // ---------------------------------------------------------------------------

  group('CountryResolver loading', () {
    test('loads all 175 countries from bundled asset', () {
      expect(resolver.countryCount, equals(175));
    });

    test('load rejects malformed JSON', () {
      expect(
        () => CountryResolver.load('not json'),
        throwsA(isA<FormatException>()),
      );
    });

    test('load handles empty array', () {
      final empty = CountryResolver.load('[]');
      expect(empty.countryCount, equals(0));
      // Should still resolve via fallback
      expect(empty.resolve(40.7, -74.0), isA<Continent>());
    });
  });

  // ---------------------------------------------------------------------------
  // Country code resolution — known cities
  // ---------------------------------------------------------------------------

  group('CountryResolver resolveCountryCode', () {
    test('New York → US', () {
      // Use slightly inland coordinate — 110m resolution coastline
      // may exclude points right at the waterfront.
      expect(resolver.resolveCountryCode(40.8, -73.9), equals('US'));
    });

    test('London → GB', () {
      expect(resolver.resolveCountryCode(51.5, -0.1), equals('GB'));
    });

    test('Tokyo → JP', () {
      expect(resolver.resolveCountryCode(35.7, 139.7), equals('JP'));
    });

    test('Sydney → AU', () {
      expect(resolver.resolveCountryCode(-33.9, 151.2), equals('AU'));
    });

    test('São Paulo → BR', () {
      expect(resolver.resolveCountryCode(-23.5, -46.6), equals('BR'));
    });

    test('Nairobi → KE', () {
      expect(resolver.resolveCountryCode(-1.3, 36.8), equals('KE'));
    });

    test('Mumbai → IN', () {
      expect(resolver.resolveCountryCode(19.1, 72.9), equals('IN'));
    });

    test('Buenos Aires → AR', () {
      expect(resolver.resolveCountryCode(-34.6, -58.4), equals('AR'));
    });

    test('Cairo → EG', () {
      expect(resolver.resolveCountryCode(30.0, 31.2), equals('EG'));
    });

    test('Berlin → DE', () {
      expect(resolver.resolveCountryCode(52.5, 13.4), equals('DE'));
    });

    test('Ottawa → CA', () {
      expect(resolver.resolveCountryCode(45.4, -75.7), equals('CA'));
    });

    test('Mexico City → MX', () {
      expect(resolver.resolveCountryCode(19.4, -99.1), equals('MX'));
    });

    test('Moscow → RU', () {
      expect(resolver.resolveCountryCode(55.8, 37.6), equals('RU'));
    });

    test('Beijing → CN', () {
      expect(resolver.resolveCountryCode(39.9, 116.4), equals('CN'));
    });

    test('mid-ocean returns null', () {
      // Middle of Pacific Ocean
      expect(resolver.resolveCountryCode(0.0, -150.0), isNull);
    });

    test('mid-Atlantic returns null', () {
      expect(resolver.resolveCountryCode(30.0, -40.0), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Continent resolution — matches ContinentResolver test suite
  // ---------------------------------------------------------------------------

  group('CountryResolver continent resolution', () {
    test('New York → North America', () {
      expect(resolver.resolve(40.8, -73.9), equals(Continent.northAmerica));
    });

    test('London → Europe', () {
      expect(resolver.resolve(51.5, -0.1), equals(Continent.europe));
    });

    test('Tokyo → Asia', () {
      expect(resolver.resolve(35.7, 139.7), equals(Continent.asia));
    });

    test('Sydney → Oceania', () {
      expect(resolver.resolve(-33.9, 151.2), equals(Continent.oceania));
    });

    test('São Paulo → South America', () {
      expect(resolver.resolve(-23.5, -46.6), equals(Continent.southAmerica));
    });

    test('Nairobi → Africa', () {
      expect(resolver.resolve(-1.3, 36.8), equals(Continent.africa));
    });

    test('Mumbai → Asia', () {
      expect(resolver.resolve(19.1, 72.9), equals(Continent.asia));
    });

    test('Buenos Aires → South America', () {
      expect(resolver.resolve(-34.6, -58.4), equals(Continent.southAmerica));
    });

    test('Cairo → Africa', () {
      expect(resolver.resolve(30.0, 31.2), equals(Continent.africa));
    });
  });

  // ---------------------------------------------------------------------------
  // ContinentLookup interface
  // ---------------------------------------------------------------------------

  group('CountryResolver implements ContinentLookup', () {
    test('all 6 continents are reachable', () {
      // One known city per continent
      final results = <Continent>{
        resolver.resolve(40.8, -73.9), // North America
        resolver.resolve(-23.5, -46.6), // South America
        resolver.resolve(51.5, -0.1), // Europe
        resolver.resolve(-1.3, 36.8), // Africa
        resolver.resolve(35.7, 139.7), // Asia
        resolver.resolve(-33.9, 151.2), // Oceania
      };
      expect(results, equals(Continent.values.toSet()));
    });
  });

  // ---------------------------------------------------------------------------
  // Ocean coordinates — fallback to ContinentResolver heuristic
  // ---------------------------------------------------------------------------

  group('CountryResolver ocean fallback', () {
    test('mid-Pacific falls back to heuristic without crash', () {
      final result = resolver.resolve(0.0, -150.0);
      expect(Continent.values, contains(result));
    });

    test('mid-Atlantic falls back without crash', () {
      final result = resolver.resolve(20.0, -35.0);
      expect(Continent.values, contains(result));
    });

    test('southern ocean falls back without crash', () {
      final result = resolver.resolve(-60.0, 0.0);
      expect(Continent.values, contains(result));
    });
  });

  // ---------------------------------------------------------------------------
  // Edge cases
  // ---------------------------------------------------------------------------

  group('CountryResolver edge cases', () {
    test('equator / prime meridian (0, 0) resolves without crash', () {
      expect(() => resolver.resolve(0.0, 0.0), returnsNormally);
    });

    test('north pole (90, 0) resolves without crash', () {
      expect(() => resolver.resolve(90.0, 0.0), returnsNormally);
    });

    test('south pole (-90, 0) resolves without crash', () {
      expect(() => resolver.resolve(-90.0, 0.0), returnsNormally);
    });

    test('date line east (0, 179.9) resolves without crash', () {
      expect(() => resolver.resolve(0.0, 179.9), returnsNormally);
    });

    test('date line west (0, -179.9) resolves without crash', () {
      expect(() => resolver.resolve(0.0, -179.9), returnsNormally);
    });

    test('exhaustive grid resolves without crash', () {
      const latSteps = [-80.0, -45.0, 0.0, 20.0, 45.0, 70.0];
      const lonSteps = [-170.0, -90.0, 0.0, 45.0, 90.0, 135.0, 170.0];

      for (final lat in latSteps) {
        for (final lon in lonSteps) {
          final result = resolver.resolve(lat, lon);
          expect(Continent.values, contains(result),
              reason: 'resolve($lat, $lon) returned invalid value');
        }
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Ray-casting algorithm correctness
  // ---------------------------------------------------------------------------

  group('CountryResolver ray-casting', () {
    test('point clearly inside large country resolves correctly', () {
      // Central US — well inside boundaries
      expect(resolver.resolveCountryCode(39.0, -98.0), equals('US'));
    });

    test('point clearly inside Russia resolves correctly', () {
      // Deep in Siberia
      expect(resolver.resolveCountryCode(60.0, 90.0), equals('RU'));
    });

    test('point clearly inside Brazil resolves correctly', () {
      // Amazon basin
      expect(resolver.resolveCountryCode(-3.0, -60.0), equals('BR'));
    });

    test('point clearly inside Australia resolves correctly', () {
      // Central Australia
      expect(resolver.resolveCountryCode(-25.0, 134.0), equals('AU'));
    });

    test('island nation with MultiPolygon works', () {
      // Indonesia — Jakarta
      expect(resolver.resolveCountryCode(-6.2, 106.8), equals('ID'));
    });

    test('small European country resolves', () {
      // Paris, France (uses A3 fallback code since ISO_A2 = -99)
      final code = resolver.resolveCountryCode(48.9, 2.3);
      expect(code, anyOf(equals('FR'), equals('FRA')));
    });
  });
}
