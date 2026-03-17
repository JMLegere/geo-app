import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/features/world/models/esa_land_cover.dart';
import 'package:earth_nova/features/world/services/biome_feature_index.dart';
import 'package:earth_nova/features/world/services/biome_service.dart';

void main() {
  // ─────────────────────────────────────────────────────────────
  // EsaLandCover enum
  // ─────────────────────────────────────────────────────────────
  group('EsaLandCover', () {
    group('fromCode', () {
      test('returns correct enum for all 11 valid codes', () {
        expect(EsaLandCover.fromCode(10), EsaLandCover.treeCover);
        expect(EsaLandCover.fromCode(20), EsaLandCover.shrubland);
        expect(EsaLandCover.fromCode(30), EsaLandCover.grassland);
        expect(EsaLandCover.fromCode(40), EsaLandCover.cropland);
        expect(EsaLandCover.fromCode(50), EsaLandCover.builtUp);
        expect(EsaLandCover.fromCode(60), EsaLandCover.bareSparse);
        expect(EsaLandCover.fromCode(70), EsaLandCover.snowIce);
        expect(EsaLandCover.fromCode(80), EsaLandCover.permanentWater);
        expect(EsaLandCover.fromCode(90), EsaLandCover.herbaceousWetland);
        expect(EsaLandCover.fromCode(95), EsaLandCover.mangroves);
        expect(EsaLandCover.fromCode(100), EsaLandCover.mossLichen);
      });

      test('returns null for invalid / unknown codes', () {
        expect(EsaLandCover.fromCode(0), isNull);
        expect(EsaLandCover.fromCode(15), isNull);
        expect(EsaLandCover.fromCode(99), isNull);
        expect(EsaLandCover.fromCode(-1), isNull);
        expect(EsaLandCover.fromCode(200), isNull);
      });
    });

    group('toHabitat — exhaustive mapping for all 11 values', () {
      // Each row: (EsaLandCover, expected Habitat)
      const cases = <(EsaLandCover, Habitat)>[
        (EsaLandCover.treeCover, Habitat.forest),
        (EsaLandCover.shrubland, Habitat.plains),
        (EsaLandCover.grassland, Habitat.plains),
        (EsaLandCover.cropland, Habitat.plains),
        (EsaLandCover.builtUp, Habitat.plains),
        (EsaLandCover.bareSparse, Habitat.desert),
        (EsaLandCover.snowIce, Habitat.mountain),
        (EsaLandCover.permanentWater, Habitat.freshwater),
        (EsaLandCover.herbaceousWetland, Habitat.swamp),
        (EsaLandCover.mangroves, Habitat.swamp),
        (EsaLandCover.mossLichen, Habitat.mountain),
      ];

      test('all 11 ESA codes map to exactly one of the 7 game habitats', () {
        // Guard: every enum value must be represented in test cases
        expect(cases.length, EsaLandCover.values.length,
            reason: 'Test case count must equal enum value count');

        for (final (landCover, expectedHabitat) in cases) {
          expect(
            landCover.toHabitat(),
            expectedHabitat,
            reason:
                '${landCover.name} (code ${landCover.code}) → ${expectedHabitat.name}',
          );
        }
      });

      test('every result is a valid Habitat enum value', () {
        for (final lc in EsaLandCover.values) {
          expect(
            Habitat.values.contains(lc.toHabitat()),
            isTrue,
            reason: '${lc.name}.toHabitat() must return a valid Habitat',
          );
        }
      });
    });
  });

  // ─────────────────────────────────────────────────────────────
  // CoordinateHabitatLookup (also accessible as CoordinateBiomeLookup)
  // ─────────────────────────────────────────────────────────────
  group('CoordinateHabitatLookup', () {
    test('gridKey is deterministic — same input always produces same output',
        () {
      final key1 = CoordinateHabitatLookup.gridKey(51.5, -0.1);
      final key2 = CoordinateHabitatLookup.gridKey(51.5, -0.1);
      expect(key1, key2);
    });

    test('gridKey format matches expected ~1 km resolution formula', () {
      expect(CoordinateHabitatLookup.gridKey(51.5, -0.1), '515_-1');
      expect(CoordinateHabitatLookup.gridKey(0.0, 0.0), '0_0');
      expect(CoordinateHabitatLookup.gridKey(-33.8, 151.2), '-338_1512');
      expect(CoordinateHabitatLookup.gridKey(51.123, -0.456), '511_-5');
    });

    test('coordinates within ~100 m share the same grid key', () {
      final key1 = CoordinateHabitatLookup.gridKey(51.500, -0.100);
      final key2 = CoordinateHabitatLookup.gridKey(51.504, -0.104);
      expect(key1, key2, reason: 'coordinates <1 km apart share a grid cell');
    });

    test('coordinates in adjacent 0.1° cells map to different grid keys', () {
      final key1 = CoordinateHabitatLookup.gridKey(51.5, -0.1);
      final key2 = CoordinateHabitatLookup.gridKey(51.6, -0.1);
      expect(key1, isNot(key2));
    });

    test('getEsaCode returns null for unknown coordinate', () {
      final lookup = CoordinateHabitatLookup();
      expect(lookup.getEsaCode(51.5, -0.1), isNull);
    });

    test('loadRegionData populates lookup; getEsaCode returns loaded values',
        () {
      final lookup = CoordinateHabitatLookup();
      lookup.loadRegionData({
        CoordinateHabitatLookup.gridKey(51.5, -0.1): 10, // tree cover
        CoordinateHabitatLookup.gridKey(51.5, -0.2): 50, // built-up
      });

      expect(lookup.getEsaCode(51.5, -0.1), 10);
      expect(lookup.getEsaCode(51.5, -0.2), 50);
      expect(lookup.getEsaCode(51.5, -0.9), isNull);
    });

    test('loadRegionData called multiple times merges data', () {
      final lookup = CoordinateHabitatLookup();
      lookup.loadRegionData({CoordinateHabitatLookup.gridKey(51.5, -0.1): 10});
      lookup.loadRegionData({CoordinateHabitatLookup.gridKey(51.5, -0.2): 50});

      expect(lookup.getEsaCode(51.5, -0.1), 10);
      expect(lookup.getEsaCode(51.5, -0.2), 50);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // HabitatService (also accessible as BiomeService)
  // ─────────────────────────────────────────────────────────────
  group('HabitatService', () {
    group('classifyFromEsaCode', () {
      late HabitatService service;
      setUp(() => service = HabitatService());

      test('maps all 11 valid ESA codes to correct habitats', () {
        expect(service.classifyFromEsaCode(10), Habitat.forest);
        expect(service.classifyFromEsaCode(20), Habitat.plains);
        expect(service.classifyFromEsaCode(30), Habitat.plains);
        expect(service.classifyFromEsaCode(40), Habitat.plains);
        expect(service.classifyFromEsaCode(50), Habitat.plains);
        expect(service.classifyFromEsaCode(60), Habitat.desert);
        expect(service.classifyFromEsaCode(70), Habitat.mountain);
        expect(service.classifyFromEsaCode(80), Habitat.freshwater);
        expect(service.classifyFromEsaCode(90), Habitat.swamp);
        expect(service.classifyFromEsaCode(95), Habitat.swamp);
        expect(service.classifyFromEsaCode(100), Habitat.mountain);
      });

      test('returns plains for unknown / invalid ESA code', () {
        expect(service.classifyFromEsaCode(0), Habitat.plains);
        expect(service.classifyFromEsaCode(15), Habitat.plains);
        expect(service.classifyFromEsaCode(999), Habitat.plains);
        expect(service.classifyFromEsaCode(-1), Habitat.plains);
      });
    });

    group('classifyLocation (ESA lookup mode)', () {
      test('returns {plains} when no data available (default lookup)', () {
        final service = HabitatService();
        expect(service.classifyLocation(51.5, -0.1), equals({Habitat.plains}));
        expect(service.classifyLocation(0.0, 0.0), equals({Habitat.plains}));
        expect(
            service.classifyLocation(-33.8, 151.2), equals({Habitat.plains}));
      });

      test('returns correct single-element set with pre-loaded region data',
          () {
        final lookup = CoordinateHabitatLookup();
        lookup.loadRegionData({
          CoordinateHabitatLookup.gridKey(51.5, -0.1):
              10, // tree cover → forest
          CoordinateHabitatLookup.gridKey(51.5, 0.0):
              60, // bare sparse → desert
          CoordinateHabitatLookup.gridKey(51.5, -0.2): 90, // wetland    → swamp
          CoordinateHabitatLookup.gridKey(51.5, -0.3):
              80, // perm.water → freshwater
          CoordinateHabitatLookup.gridKey(51.5, -0.4): 95, // mangroves  → swamp
          CoordinateHabitatLookup.gridKey(51.5, -0.5):
              70, // snow/ice   → mountain
        });
        final service = HabitatService(lookup: lookup);

        expect(service.classifyLocation(51.5, -0.1), equals({Habitat.forest}));
        expect(service.classifyLocation(51.5, 0.0), equals({Habitat.desert}));
        expect(service.classifyLocation(51.5, -0.2), equals({Habitat.swamp}));
        expect(
            service.classifyLocation(51.5, -0.3), equals({Habitat.freshwater}));
        expect(service.classifyLocation(51.5, -0.4), equals({Habitat.swamp}));
        expect(
            service.classifyLocation(51.5, -0.5), equals({Habitat.mountain}));
      });

      test('falls back to {plains} for coordinate absent from pre-loaded data',
          () {
        final lookup = CoordinateHabitatLookup();
        lookup.loadRegionData({
          CoordinateHabitatLookup.gridKey(51.5, -0.1): 10,
        });
        final service = HabitatService(lookup: lookup);

        expect(service.classifyLocation(51.5, -0.1),
            equals({Habitat.forest})); // known
        expect(service.classifyLocation(48.8, 2.3),
            equals({Habitat.plains})); // absent
      });
    });

    test('uses DefaultHabitatLookup when no strategy is provided', () {
      final service = HabitatService();
      expect(service.classifyLocation(0.0, 0.0), equals({Habitat.plains}));
      expect(service.classifyLocation(51.5, -0.1), equals({Habitat.plains}));
    });

    test('accepts custom HabitatLookupStrategy via constructor', () {
      final lookup = CoordinateHabitatLookup();
      lookup.loadRegionData({
        CoordinateHabitatLookup.gridKey(51.5, -0.1): 10, // tree cover → forest
      });
      final service = HabitatService(lookup: lookup);

      expect(service.classifyLocation(51.5, -0.1), equals({Habitat.forest}));
    });

    group('classifyLocation (feature-index mode)', () {
      // Minimal JSON with one coastline point near (0.0, 0.0).
      const kMinimalJson = '''
{
  "coastline": [[0.001, 0.001]],
  "rivers": [],
  "lakes": [],
  "mountains": [],
  "deserts": [],
  "wetlands": [],
  "forests": []
}
''';

      test('returns {saltwater} for coordinate within 5km of a coastline point',
          () {
        final index = BiomeFeatureIndex.load(kMinimalJson);
        final service = HabitatService.withFeatureIndex(index);
        // 0.001° ≈ 110m — well within 5km.
        final result = service.classifyLocation(0.0, 0.0);
        expect(result, contains(Habitat.saltwater));
      });

      test('returns {plains} for coordinate with no nearby features', () {
        final index = BiomeFeatureIndex.load(kMinimalJson);
        final service = HabitatService.withFeatureIndex(index);
        // 10° away — well outside 5km.
        final result = service.classifyLocation(10.0, 10.0);
        expect(result, equals({Habitat.plains}));
      });

      test('returns multiple habitats for multi-feature location', () {
        // Coastline + forest polygon both cover (0.0, 0.0).
        // Forest polygon is a square from (-1,-1) to (1,1) containing the origin.
        const json = '''
{
  "coastline": [[0.001, 0.001]],
  "rivers": [],
  "lakes": [],
  "mountains": [],
  "deserts": [],
  "wetlands": [],
  "forests": [[[-1.0,-1.0],[-1.0,1.0],[1.0,1.0],[1.0,-1.0],[-1.0,-1.0]]]
}
''';
        final index = BiomeFeatureIndex.load(json);
        final service = HabitatService.withFeatureIndex(index);
        final result = service.classifyLocation(0.0, 0.0);
        expect(result, containsAll([Habitat.saltwater, Habitat.forest]));
      });

      test(
          'classifyLocation result is a Set — never empty (always has plains fallback)',
          () {
        final index = BiomeFeatureIndex.load(kMinimalJson);
        final service = HabitatService.withFeatureIndex(index);
        final result = service.classifyLocation(50.0, 50.0);
        expect(result, isNotEmpty);
      });
    });
  });

  group('BiomeFeatureIndex — centroid proximity', () {
    // A small forest polygon patch centred near (9.99, 19.99) (mean of the
    // 5 vertices including the repeated closing vertex).
    // The patch is ~11 km across (0.1° at lat 10°).
    // Query points:
    //   near  = (10.0, 20.026) ≈ 4.1 km from centroid → inside 5 km radius
    //   far   = (10.0, 20.063) ≈ 8.1 km from centroid → outside 5 km radius
    const kForestPatch = '''
{
  "coastline": [],
  "rivers": [],
  "lakes": [],
  "mountains": [],
  "deserts": [],
  "wetlands": [],
  "forests": [[[9.95, 19.95],[9.95, 20.05],[10.05, 20.05],[10.05, 19.95],[9.95, 19.95]]]
}
''';

    const kWetlandPatch = '''
{
  "coastline": [],
  "rivers": [],
  "lakes": [],
  "mountains": [],
  "deserts": [],
  "wetlands": [[[9.95, 19.95],[9.95, 20.05],[10.05, 20.05],[10.05, 19.95],[9.95, 19.95]]],
  "forests": []
}
''';

    test('point strictly inside forest polygon → forest detected (containment)',
        () {
      final index = BiomeFeatureIndex.load(kForestPatch);
      // (10.0, 20.0) is inside the polygon.
      final result = index.getBiomesNear(10.0, 20.0);
      expect(result, contains(Habitat.forest));
    });

    test(
        'point outside forest polygon but within 5 km of centroid → forest detected (proximity)',
        () {
      final index = BiomeFeatureIndex.load(kForestPatch);
      // (10.0, 20.026) is outside the polygon but ~4.1 km from centroid.
      final result = index.getBiomesNear(10.0, 20.026);
      expect(result, contains(Habitat.forest));
    });

    test(
        'point far from forest polygon (>5 km) → no forest detected, falls back to plains',
        () {
      final index = BiomeFeatureIndex.load(kForestPatch);
      // (10.0, 20.063) is ~8.1 km from centroid — outside 5 km radius.
      final result = index.getBiomesNear(10.0, 20.063);
      expect(result, isNot(contains(Habitat.forest)));
      expect(result, contains(Habitat.plains));
    });

    test(
        'point outside wetland polygon but within 5 km of centroid → swamp detected (proximity)',
        () {
      final index = BiomeFeatureIndex.load(kWetlandPatch);
      // Same geometry — (10.0, 20.026) is ~4.1 km from centroid.
      final result = index.getBiomesNear(10.0, 20.026);
      expect(result, contains(Habitat.swamp));
    });

    test(
        'point far from wetland polygon (>5 km) → no swamp detected, falls back to plains',
        () {
      final index = BiomeFeatureIndex.load(kWetlandPatch);
      // (10.0, 20.063) is ~8.1 km away.
      final result = index.getBiomesNear(10.0, 20.063);
      expect(result, isNot(contains(Habitat.swamp)));
      expect(result, contains(Habitat.plains));
    });

    test('empty forest list → no forest, result has plains fallback', () {
      const json = '''
{
  "coastline": [], "rivers": [], "lakes": [],
  "mountains": [], "deserts": [], "wetlands": [], "forests": []
}
''';
      final index = BiomeFeatureIndex.load(json);
      final result = index.getBiomesNear(0.0, 0.0);
      expect(result, equals({Habitat.plains}));
    });

    test('multiple forest patches — nearest within radius triggers detection',
        () {
      // Two patches: one near (−0.01, −0.01) centroid, one near (50, 50).
      // First patch centroid: mean of 5 vertices = (-0.01, -0.01).
      // (0.0, 0.026) is ~4.15 km from that centroid — within 5 km.
      const json = '''
{
  "coastline": [], "rivers": [], "lakes": [],
  "mountains": [], "deserts": [], "wetlands": [],
  "forests": [
    [[-0.05,-0.05],[-0.05,0.05],[0.05,0.05],[0.05,-0.05],[-0.05,-0.05]],
    [[49.95,49.95],[49.95,50.05],[50.05,50.05],[50.05,49.95],[49.95,49.95]]
  ]
}
''';
      final index = BiomeFeatureIndex.load(json);
      // ~4.15 km from first patch centroid, outside polygon.
      final near1 = index.getBiomesNear(0.0, 0.026);
      expect(near1, contains(Habitat.forest));
      // Far from both patches.
      final farAway = index.getBiomesNear(25.0, 25.0);
      expect(farAway, isNot(contains(Habitat.forest)));
    });
  });

  // ─────────────────────────────────────────────────────────────
  // Legacy type alias smoke tests
  // ─────────────────────────────────────────────────────────────
  group('Legacy BiomeService alias', () {
    test('BiomeService is usable as HabitatService', () {
      // BiomeService is a typedef for HabitatService
      final service = BiomeService();
      expect(service.classifyLocation(0.0, 0.0), equals({Habitat.plains}));
    });

    test('CoordinateBiomeLookup is usable as CoordinateHabitatLookup', () {
      final lookup = CoordinateBiomeLookup();
      lookup.loadRegionData({
        CoordinateBiomeLookup.gridKey(51.5, -0.1): 10,
      });
      expect(lookup.getEsaCode(51.5, -0.1), 10);
    });
  });
}
