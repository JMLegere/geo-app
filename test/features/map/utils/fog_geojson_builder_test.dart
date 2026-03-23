import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:geobase/geobase.dart';

import 'package:earth_nova/core/models/fog_state.dart';
import 'package:earth_nova/features/map/utils/fog_geojson_builder.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Returns a simple square cell boundary for testing.
List<Geographic> _squareBoundary(double lat, double lon) {
  return [
    Geographic(lat: lat, lon: lon),
    Geographic(lat: lat, lon: lon + 1),
    Geographic(lat: lat + 1, lon: lon + 1),
    Geographic(lat: lat + 1, lon: lon),
  ];
}

/// Boundary lookup function for tests — 1°×1° squares based on cell ID.
List<Geographic> _getBoundary(String cellId) {
  final parts = cellId.split('_');
  final lat = double.parse(parts[1]);
  final lon = double.parse(parts[2]);
  return _squareBoundary(lat, lon);
}

Map<String, dynamic> _parse(String geoJson) {
  return jsonDecode(geoJson) as Map<String, dynamic>;
}

List<dynamic> _features(String geoJson) {
  return (_parse(geoJson)['features'] as List<dynamic>);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // Static getters
  // -------------------------------------------------------------------------

  group('FogGeoJsonBuilder static getters', () {
    test('emptyFeatureCollection is valid GeoJSON with no features', () {
      final parsed = _parse(FogGeoJsonBuilder.emptyFeatureCollection);
      expect(parsed['type'], equals('FeatureCollection'));
      expect(parsed['features'], isEmpty);
    });

    test('fullWorldFog is valid GeoJSON with one feature', () {
      final parsed = _parse(FogGeoJsonBuilder.fullWorldFog);
      expect(parsed['type'], equals('FeatureCollection'));

      final features = parsed['features'] as List<dynamic>;
      expect(features.length, equals(1));

      final geometry = features[0]['geometry'] as Map<String, dynamic>;
      expect(geometry['type'], equals('Polygon'));

      final coordinates = geometry['coordinates'] as List<dynamic>;
      // Only the world exterior ring — no holes.
      expect(coordinates.length, equals(1));
    });

    test('fullWorldFog exterior ring covers the world', () {
      final features = _features(FogGeoJsonBuilder.fullWorldFog);
      final coordinates =
          features[0]['geometry']['coordinates'] as List<dynamic>;
      final ring = coordinates[0] as List<dynamic>;

      // Should have 5 points (4 corners + close).
      expect(ring.length, equals(5));

      // First and last should match (closed ring).
      expect(ring.first[0], equals(ring.last[0]));
      expect(ring.first[1], equals(ring.last[1]));

      // Should span ±180 lon and ±85.06 lat.
      final lons = ring.map((p) => (p as List<dynamic>)[0] as num).toList();
      final lats = ring.map((p) => (p as List<dynamic>)[1] as num).toList();
      expect(lons.reduce((a, b) => a < b ? a : b), equals(-180));
      expect(lons.reduce((a, b) => a > b ? a : b), equals(180));
      expect(lats.reduce((a, b) => a < b ? a : b), equals(-85.06));
      expect(lats.reduce((a, b) => a > b ? a : b), equals(85.06));
    });
  });

  // -------------------------------------------------------------------------
  // buildBaseFog
  // -------------------------------------------------------------------------

  group('FogGeoJsonBuilder.buildBaseFog', () {
    test('with empty cellStates returns world polygon with no holes', () {
      final result = FogGeoJsonBuilder.buildBaseFog(
        cellStates: {},
        getBoundary: _getBoundary,
      );

      final features = _features(result);
      expect(features.length, equals(1));

      final coordinates =
          features[0]['geometry']['coordinates'] as List<dynamic>;
      expect(coordinates.length, equals(1),
          reason: 'No holes when no cells provided');
    });

    test('with observed cell punches a hole', () {
      final result = FogGeoJsonBuilder.buildBaseFog(
        cellStates: {'cell_37_-122': FogState.active},
        getBoundary: _getBoundary,
      );

      final coordinates = _features(result)[0]['geometry']['coordinates']
          as List<dynamic>;
      // Exterior ring + 1 hole.
      expect(coordinates.length, equals(2));
    });

    test('with hidden cell punches a hole', () {
      final result = FogGeoJsonBuilder.buildBaseFog(
        cellStates: {'cell_37_-122': FogState.visited},
        getBoundary: _getBoundary,
      );

      final coordinates = _features(result)[0]['geometry']['coordinates']
          as List<dynamic>;
      expect(coordinates.length, equals(2));
    });

    test('with concealed cell punches a hole', () {
      final result = FogGeoJsonBuilder.buildBaseFog(
        cellStates: {'cell_37_-122': FogState.nearby},
        getBoundary: _getBoundary,
      );

      final coordinates = _features(result)[0]['geometry']['coordinates']
          as List<dynamic>;
      expect(coordinates.length, equals(2),
          reason: 'Concealed cells get holes for pre-rendered mid-fog');
    });

    test('with undetected cell does NOT punch a hole', () {
      final result = FogGeoJsonBuilder.buildBaseFog(
        cellStates: {'cell_37_-122': FogState.unknown},
        getBoundary: _getBoundary,
      );

      final coordinates = _features(result)[0]['geometry']['coordinates']
          as List<dynamic>;
      expect(coordinates.length, equals(1),
          reason: 'Undetected cells stay under opaque fog');
    });

    test('with unexplored cell does NOT punch a hole', () {
      final result = FogGeoJsonBuilder.buildBaseFog(
        cellStates: {'cell_37_-122': FogState.detected},
        getBoundary: _getBoundary,
      );

      final coordinates = _features(result)[0]['geometry']['coordinates']
          as List<dynamic>;
      expect(coordinates.length, equals(1),
          reason: 'Unexplored cells stay under opaque fog');
    });

    test('multiple cells produce multiple holes', () {
      final result = FogGeoJsonBuilder.buildBaseFog(
        cellStates: {
          'cell_37_-122': FogState.active,
          'cell_38_-122': FogState.visited,
          'cell_37_-121': FogState.nearby,
        },
        getBoundary: _getBoundary,
      );

      final coordinates = _features(result)[0]['geometry']['coordinates']
          as List<dynamic>;
      // Exterior ring + 3 holes (observed, hidden, concealed).
      expect(coordinates.length, equals(4));
    });

    test('hole rings are closed (first == last vertex)', () {
      final result = FogGeoJsonBuilder.buildBaseFog(
        cellStates: {'cell_37_-122': FogState.active},
        getBoundary: _getBoundary,
      );

      final coordinates = _features(result)[0]['geometry']['coordinates']
          as List<dynamic>;
      final hole = coordinates[1] as List<dynamic>;

      // Closed ring: first point == last point.
      final first = hole.first as List<dynamic>;
      final last = hole.last as List<dynamic>;
      expect(first[0], equals(last[0]));
      expect(first[1], equals(last[1]));
    });

    test('hole coordinates use [lon, lat] order', () {
      final result = FogGeoJsonBuilder.buildBaseFog(
        cellStates: {'cell_37_-122': FogState.active},
        getBoundary: _getBoundary,
      );

      final coordinates = _features(result)[0]['geometry']['coordinates']
          as List<dynamic>;
      final hole = coordinates[1] as List<dynamic>;
      final firstPoint = hole[0] as List<dynamic>;

      // The boundary for cell_37_-122 starts at (lat=37, lon=-122).
      // GeoJSON uses [lon, lat], so first point should be [-122, 37].
      expect(firstPoint[0], equals(-122.0),
          reason: 'GeoJSON uses longitude first');
      expect(firstPoint[1], equals(37.0),
          reason: 'GeoJSON uses latitude second');
    });
  });

  // -------------------------------------------------------------------------
  // buildMidFog
  // -------------------------------------------------------------------------

  group('FogGeoJsonBuilder.buildMidFog', () {
    test('with empty cellStates returns empty features', () {
      final result = FogGeoJsonBuilder.buildMidFog(
        cellStates: {},
        getBoundary: _getBoundary,
      );

      expect(_features(result), isEmpty);
    });

    test('includes hidden cells with density 0.5', () {
      final result = FogGeoJsonBuilder.buildMidFog(
        cellStates: {'cell_37_-122': FogState.visited},
        getBoundary: _getBoundary,
      );

      final features = _features(result);
      expect(features.length, equals(1));

      final props = features[0]['properties'] as Map<String, dynamic>;
      expect(props['density'], equals(0.5));
    });

    test('includes concealed cells with density 0.95', () {
      final result = FogGeoJsonBuilder.buildMidFog(
        cellStates: {'cell_37_-122': FogState.nearby},
        getBoundary: _getBoundary,
      );

      final features = _features(result);
      expect(features.length, equals(1));

      final props = features[0]['properties'] as Map<String, dynamic>;
      expect(props['density'], equals(0.95));
    });

    test('excludes observed cells', () {
      final result = FogGeoJsonBuilder.buildMidFog(
        cellStates: {'cell_37_-122': FogState.active},
        getBoundary: _getBoundary,
      );

      expect(_features(result), isEmpty);
    });

    test('excludes undetected cells', () {
      final result = FogGeoJsonBuilder.buildMidFog(
        cellStates: {'cell_37_-122': FogState.unknown},
        getBoundary: _getBoundary,
      );

      expect(_features(result), isEmpty);
    });

    test('includes unexplored cells with pre-rendered concealed density 0.95', () {
      final result = FogGeoJsonBuilder.buildMidFog(
        cellStates: {'cell_37_-122': FogState.detected},
        getBoundary: _getBoundary,
      );

      final features = _features(result);
      expect(features.length, equals(1));

      final props = features[0]['properties'] as Map<String, dynamic>;
      expect(props['density'], equals(0.95),
          reason: 'Unexplored cells use concealed density for pre-rendering');
    });

    test('multiple cells produce multiple features', () {
      final result = FogGeoJsonBuilder.buildMidFog(
        cellStates: {
          'cell_37_-122': FogState.visited,
          'cell_38_-122': FogState.nearby,
        },
        getBoundary: _getBoundary,
      );

      final features = _features(result);
      expect(features.length, equals(2),
          reason: 'Both hidden and concealed cells included');
    });

    test('feature polygons are closed rings', () {
      final result = FogGeoJsonBuilder.buildMidFog(
        cellStates: {'cell_37_-122': FogState.visited},
        getBoundary: _getBoundary,
      );

      final ring = _features(result)[0]['geometry']['coordinates'][0]
          as List<dynamic>;
      final first = ring.first as List<dynamic>;
      final last = ring.last as List<dynamic>;
      expect(first[0], equals(last[0]));
      expect(first[1], equals(last[1]));
    });

    test('unexplored cells use concealed density not their own', () {
      final result = FogGeoJsonBuilder.buildMidFog(
        cellStates: {'cell_37_-122': FogState.detected},
        getBoundary: _getBoundary,
      );

      final features = _features(result);
      expect(features.length, equals(1));

      final props = features[0]['properties'] as Map<String, dynamic>;
      // Unexplored.density is 1.0, but should use concealed.density (0.95)
      expect(props['density'], equals(0.95),
          reason: 'Unexplored cells pre-rendered at concealed density');
      expect(props['density'], isNot(equals(FogState.detected.density)),
          reason: 'Should not use unexplored density (1.0)');
    });

    test('unexplored cell pre-rendered: base-fog no hole, mid-fog has polygon', () {
      // Base fog should NOT punch a hole for unexplored
      final baseFog = FogGeoJsonBuilder.buildBaseFog(
        cellStates: {'cell_37_-122': FogState.detected},
        getBoundary: _getBoundary,
      );
      final baseCoordinates = _features(baseFog)[0]['geometry']['coordinates']
          as List<dynamic>;
      expect(baseCoordinates.length, equals(1),
          reason: 'Unexplored cells do not get holes in base fog');

      // Mid fog SHOULD include the unexplored cell
      final midFog = FogGeoJsonBuilder.buildMidFog(
        cellStates: {'cell_37_-122': FogState.detected},
        getBoundary: _getBoundary,
      );
      final midFeatures = _features(midFog);
      expect(midFeatures.length, equals(1),
          reason: 'Unexplored cell is pre-rendered in mid fog');

      final props = midFeatures[0]['properties'] as Map<String, dynamic>;
      expect(props['density'], equals(0.95),
          reason: 'Pre-rendered at concealed density');
    });

    test('mixed states includes unexplored, concealed, and hidden', () {
      final result = FogGeoJsonBuilder.buildMidFog(
        cellStates: {
          'cell_37_-122': FogState.active, // excluded
          'cell_38_-122': FogState.visited, // included (0.5)
          'cell_37_-121': FogState.unknown, // excluded
          'cell_38_-121': FogState.nearby, // included (0.95)
          'cell_39_-122': FogState.detected, // included (0.95)
        },
        getBoundary: _getBoundary,
      );

      final features = _features(result);
      expect(features.length, equals(3),
          reason: 'Hidden, concealed, and unexplored cells included');

      final densities = features
          .map((f) => (f['properties'] as Map<String, dynamic>)['density'])
          .toSet();
      expect(densities, containsAll([0.5, 0.95]));
    });
  });

  // -------------------------------------------------------------------------
  // buildRestorationOverlay
  // -------------------------------------------------------------------------

  group('FogGeoJsonBuilder.buildRestorationOverlay', () {
    test('with empty inputs returns empty features', () {
      final result = FogGeoJsonBuilder.buildRestorationOverlay(
        cellStates: {},
        restorationLevels: {},
        getBoundary: _getBoundary,
      );

      expect(_features(result), isEmpty);
    });

    test('includes observed cells with restoration level > 0', () {
      final result = FogGeoJsonBuilder.buildRestorationOverlay(
        cellStates: {'cell_37_-122': FogState.active},
        restorationLevels: {'cell_37_-122': 0.67},
        getBoundary: _getBoundary,
      );

      final features = _features(result);
      expect(features.length, equals(1));

      final props = features[0]['properties'] as Map<String, dynamic>;
      expect(props['level'], equals(0.67));
    });

    test('excludes non-observed cells even with restoration level', () {
      final result = FogGeoJsonBuilder.buildRestorationOverlay(
        cellStates: {'cell_37_-122': FogState.visited},
        restorationLevels: {'cell_37_-122': 0.5},
        getBoundary: _getBoundary,
      );

      expect(_features(result), isEmpty);
    });

    test('excludes cells with restoration level 0', () {
      final result = FogGeoJsonBuilder.buildRestorationOverlay(
        cellStates: {'cell_37_-122': FogState.active},
        restorationLevels: {'cell_37_-122': 0.0},
        getBoundary: _getBoundary,
      );

      expect(_features(result), isEmpty);
    });

    test('excludes cells with no restoration entry', () {
      final result = FogGeoJsonBuilder.buildRestorationOverlay(
        cellStates: {'cell_37_-122': FogState.active},
        restorationLevels: {},
        getBoundary: _getBoundary,
      );

      expect(_features(result), isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // buildCellBorders
  // -------------------------------------------------------------------------

  group('FogGeoJsonBuilder.buildCellBorders', () {
    test('with empty cell states returns empty features', () {
      final result = FogGeoJsonBuilder.buildCellBorders(
        cellStates: {},
        getBoundary: _getBoundary,
      );

      expect(_features(result), isEmpty);
    });

    test('includes unexplored cells with opacity 0.4', () {
      final result = FogGeoJsonBuilder.buildCellBorders(
        cellStates: {'cell_37_-122': FogState.detected},
        getBoundary: _getBoundary,
      );

      final features = _features(result);
      expect(features.length, equals(1));

      final props = features[0]['properties'] as Map<String, dynamic>;
      expect(props['opacity'], equals(0.4));
    });

    test('includes concealed cells with opacity 0.25', () {
      final result = FogGeoJsonBuilder.buildCellBorders(
        cellStates: {'cell_37_-122': FogState.nearby},
        getBoundary: _getBoundary,
      );

      final features = _features(result);
      expect(features.length, equals(1));

      final props = features[0]['properties'] as Map<String, dynamic>;
      expect(props['opacity'], equals(0.25));
    });

    test('excludes undetected cells', () {
      final result = FogGeoJsonBuilder.buildCellBorders(
        cellStates: {'cell_37_-122': FogState.unknown},
        getBoundary: _getBoundary,
      );

      expect(_features(result), isEmpty);
    });

    test('excludes observed and hidden cells', () {
      final result = FogGeoJsonBuilder.buildCellBorders(
        cellStates: {
          'cell_37_-122': FogState.active,
          'cell_38_-122': FogState.visited,
        },
        getBoundary: _getBoundary,
      );

      expect(_features(result), isEmpty);
    });

    test('mixed states only includes unexplored and concealed', () {
      final result = FogGeoJsonBuilder.buildCellBorders(
        cellStates: {
          'cell_37_-122': FogState.active,
          'cell_38_-122': FogState.detected,
          'cell_37_-121': FogState.unknown,
          'cell_38_-121': FogState.nearby,
          'cell_39_-122': FogState.visited,
        },
        getBoundary: _getBoundary,
      );

      final features = _features(result);
      expect(features.length, equals(2));

      final opacities = features
          .map((f) => (f['properties'] as Map<String, dynamic>)['opacity'])
          .toSet();
      expect(opacities, containsAll([0.4, 0.25]));
    });

    test('polygon rings are closed', () {
      final result = FogGeoJsonBuilder.buildCellBorders(
        cellStates: {'cell_37_-122': FogState.detected},
        getBoundary: _getBoundary,
      );

      final ring = _features(result)[0]['geometry']['coordinates'][0]
          as List<dynamic>;
      final first = ring.first as List<dynamic>;
      final last = ring.last as List<dynamic>;
      expect(first[0], equals(last[0]));
      expect(first[1], equals(last[1]));
    });
  });

  // -------------------------------------------------------------------------
  // GeoJSON validity
  // -------------------------------------------------------------------------

  group('GeoJSON validity', () {
    test('all builder outputs are valid JSON', () {
      // buildBaseFog
      final base = FogGeoJsonBuilder.buildBaseFog(
        cellStates: {'cell_37_-122': FogState.active},
        getBoundary: _getBoundary,
      );
      expect(() => jsonDecode(base), returnsNormally);

      // buildMidFog
      final mid = FogGeoJsonBuilder.buildMidFog(
        cellStates: {'cell_37_-122': FogState.visited},
        getBoundary: _getBoundary,
      );
      expect(() => jsonDecode(mid), returnsNormally);

      // buildRestorationOverlay
      final rest = FogGeoJsonBuilder.buildRestorationOverlay(
        cellStates: {'cell_37_-122': FogState.active},
        restorationLevels: {'cell_37_-122': 1.0},
        getBoundary: _getBoundary,
      );
      expect(() => jsonDecode(rest), returnsNormally);

      // buildCellBorders
      final border = FogGeoJsonBuilder.buildCellBorders(
        cellStates: {'cell_37_-122': FogState.detected},
        getBoundary: _getBoundary,
      );
      expect(() => jsonDecode(border), returnsNormally);

      // Static getters
      expect(() => jsonDecode(FogGeoJsonBuilder.emptyFeatureCollection),
          returnsNormally);
      expect(
          () => jsonDecode(FogGeoJsonBuilder.fullWorldFog), returnsNormally);
    });

    test('all builder outputs have type FeatureCollection', () {
      final base = FogGeoJsonBuilder.buildBaseFog(
        cellStates: {},
        getBoundary: _getBoundary,
      );
      expect(_parse(base)['type'], equals('FeatureCollection'));

      final mid = FogGeoJsonBuilder.buildMidFog(
        cellStates: {},
        getBoundary: _getBoundary,
      );
      expect(_parse(mid)['type'], equals('FeatureCollection'));

      final rest = FogGeoJsonBuilder.buildRestorationOverlay(
        cellStates: {},
        restorationLevels: {},
        getBoundary: _getBoundary,
      );
      expect(_parse(rest)['type'], equals('FeatureCollection'));

      final border = FogGeoJsonBuilder.buildCellBorders(
        cellStates: {},
        getBoundary: _getBoundary,
      );
      expect(_parse(border)['type'], equals('FeatureCollection'));
    });
  });
}
