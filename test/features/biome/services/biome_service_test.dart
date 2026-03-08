import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/features/biome/models/esa_land_cover.dart';
import 'package:earth_nova/features/biome/services/biome_feature_index.dart';
import 'package:earth_nova/features/biome/services/biome_service.dart';

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
        expect(service.classifyLocation(-33.8, 151.2), equals({Habitat.plains}));
      });

      test('returns correct single-element set with pre-loaded region data', () {
        final lookup = CoordinateHabitatLookup();
        lookup.loadRegionData({
          CoordinateHabitatLookup.gridKey(51.5, -0.1): 10,  // tree cover → forest
          CoordinateHabitatLookup.gridKey(51.5, 0.0): 60,   // bare sparse → desert
          CoordinateHabitatLookup.gridKey(51.5, -0.2): 90,  // wetland    → swamp
          CoordinateHabitatLookup.gridKey(51.5, -0.3): 80,  // perm.water → freshwater
          CoordinateHabitatLookup.gridKey(51.5, -0.4): 95,  // mangroves  → swamp
          CoordinateHabitatLookup.gridKey(51.5, -0.5): 70,  // snow/ice   → mountain
        });
        final service = HabitatService(lookup: lookup);

        expect(service.classifyLocation(51.5, -0.1), equals({Habitat.forest}));
        expect(service.classifyLocation(51.5, 0.0), equals({Habitat.desert}));
        expect(service.classifyLocation(51.5, -0.2), equals({Habitat.swamp}));
        expect(service.classifyLocation(51.5, -0.3), equals({Habitat.freshwater}));
        expect(service.classifyLocation(51.5, -0.4), equals({Habitat.swamp}));
        expect(service.classifyLocation(51.5, -0.5), equals({Habitat.mountain}));
      });

      test('falls back to {plains} for coordinate absent from pre-loaded data',
          () {
        final lookup = CoordinateHabitatLookup();
        lookup.loadRegionData({
          CoordinateHabitatLookup.gridKey(51.5, -0.1): 10,
        });
        final service = HabitatService(lookup: lookup);

        expect(service.classifyLocation(51.5, -0.1), equals({Habitat.forest})); // known
        expect(service.classifyLocation(48.8, 2.3), equals({Habitat.plains}));  // absent
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
        // Coastline + forest region both cover (0.0, 0.0).
        const json = '''
{
  "coastline": [[0.001, 0.001]],
  "rivers": [],
  "lakes": [],
  "mountains": [],
  "deserts": [],
  "wetlands": [],
  "forests": [[0.0, 0.0, 100]]
}
''';
        final index = BiomeFeatureIndex.load(json);
        final service = HabitatService.withFeatureIndex(index);
        final result = service.classifyLocation(0.0, 0.0);
        expect(result, containsAll([Habitat.saltwater, Habitat.forest]));
      });

      test('classifyLocation result is a Set — never empty (always has plains fallback)', () {
        final index = BiomeFeatureIndex.load(kMinimalJson);
        final service = HabitatService.withFeatureIndex(index);
        final result = service.classifyLocation(50.0, 50.0);
        expect(result, isNotEmpty);
      });
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
