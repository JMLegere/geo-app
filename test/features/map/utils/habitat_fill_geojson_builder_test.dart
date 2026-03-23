import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:geobase/geobase.dart';

import 'package:earth_nova/core/models/cell_properties.dart';
import 'package:earth_nova/core/models/climate.dart';
import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/fog_state.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/features/map/utils/habitat_fill_geojson_builder.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

CellProperties _makeCell(
  String cellId, {
  Set<Habitat> habitats = const {Habitat.forest},
}) {
  return CellProperties(
    cellId: cellId,
    habitats: habitats,
    climate: Climate.temperate,
    continent: Continent.northAmerica,
    locationId: null,
    createdAt: DateTime(2026),
  );
}

/// A square boundary centred at (lat=0, lon=1).
/// Vertices: (1,0), (1,2), (-1,2), (-1,0) → centroid (0,1).
List<Geographic> _squareBoundary() => [
      Geographic(lat: 1.0, lon: 0.0),
      Geographic(lat: 1.0, lon: 2.0),
      Geographic(lat: -1.0, lon: 2.0),
      Geographic(lat: -1.0, lon: 0.0),
    ];

List<Geographic> _getBoundary(String _) => _squareBoundary();

Map<String, dynamic> _parse(String json) =>
    jsonDecode(json) as Map<String, dynamic>;

List<dynamic> _features(Map<String, dynamic> fc) =>
    fc['features'] as List<dynamic>;

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('HabitatFillGeoJsonBuilder', () {
    // -----------------------------------------------------------------------
    // emptyFeatureCollection constant
    // -----------------------------------------------------------------------

    test('emptyFeatureCollection is valid JSON FeatureCollection', () {
      final json = _parse(HabitatFillGeoJsonBuilder.emptyFeatureCollection);
      expect(json['type'], equals('FeatureCollection'));
      expect(_features(json), isEmpty);
    });

    // -----------------------------------------------------------------------
    // Empty input
    // -----------------------------------------------------------------------

    test('returns emptyFeatureCollection when cellStates is empty', () {
      final result = HabitatFillGeoJsonBuilder.buildHabitatFills(
        cellProperties: {},
        cellStates: {},
        getCellBoundary: _getBoundary,
      );
      expect(result, equals(HabitatFillGeoJsonBuilder.emptyFeatureCollection));
    });

    test('returns emptyFeatureCollection when cellProperties is empty', () {
      final result = HabitatFillGeoJsonBuilder.buildHabitatFills(
        cellProperties: {},
        cellStates: {'cell1': FogState.active},
        getCellBoundary: _getBoundary,
      );
      expect(result, equals(HabitatFillGeoJsonBuilder.emptyFeatureCollection));
    });

    // -----------------------------------------------------------------------
    // Fog state filtering
    // -----------------------------------------------------------------------

    test('skips undetected cells', () {
      final result = HabitatFillGeoJsonBuilder.buildHabitatFills(
        cellProperties: {'cell1': _makeCell('cell1')},
        cellStates: {'cell1': FogState.unknown},
        getCellBoundary: _getBoundary,
      );
      final features = _features(_parse(result));
      expect(features, isEmpty);
    });

    test('skips unexplored cells', () {
      final result = HabitatFillGeoJsonBuilder.buildHabitatFills(
        cellProperties: {'cell1': _makeCell('cell1')},
        cellStates: {'cell1': FogState.detected},
        getCellBoundary: _getBoundary,
      );
      final features = _features(_parse(result));
      expect(features, isEmpty);
    });

    test('emits rings for concealed cells', () {
      final result = HabitatFillGeoJsonBuilder.buildHabitatFills(
        cellProperties: {'cell1': _makeCell('cell1')},
        cellStates: {'cell1': FogState.nearby},
        getCellBoundary: _getBoundary,
      );
      final features = _features(_parse(result));
      expect(features, hasLength(3));
    });

    test('emits rings for hidden cells', () {
      final result = HabitatFillGeoJsonBuilder.buildHabitatFills(
        cellProperties: {'cell1': _makeCell('cell1')},
        cellStates: {'cell1': FogState.visited},
        getCellBoundary: _getBoundary,
      );
      final features = _features(_parse(result));
      expect(features, hasLength(3));
    });

    test('emits rings for observed cells', () {
      final result = HabitatFillGeoJsonBuilder.buildHabitatFills(
        cellProperties: {'cell1': _makeCell('cell1')},
        cellStates: {'cell1': FogState.active},
        getCellBoundary: _getBoundary,
      );
      final features = _features(_parse(result));
      expect(features, hasLength(3));
    });

    test('skips cell with no matching cellProperties entry', () {
      final result = HabitatFillGeoJsonBuilder.buildHabitatFills(
        cellProperties: {'other': _makeCell('other')},
        cellStates: {'cell1': FogState.active},
        getCellBoundary: _getBoundary,
      );
      final features = _features(_parse(result));
      expect(features, isEmpty);
    });

    // -----------------------------------------------------------------------
    // Single-habitat cell: Forest → #2d7a2d
    // -----------------------------------------------------------------------

    test('single habitat cell emits 3 rings with correct forest color', () {
      final result = HabitatFillGeoJsonBuilder.buildHabitatFills(
        cellProperties: {
          'cell1': _makeCell('cell1', habitats: {Habitat.forest})
        },
        cellStates: {'cell1': FogState.active},
        getCellBoundary: _getBoundary,
      );
      final features = _features(_parse(result));

      expect(features, hasLength(3));
      for (final f in features) {
        final props =
            (f as Map<String, dynamic>)['properties'] as Map<String, dynamic>;
        // toRadixString(16) produces lowercase
        expect(props['color'], equals('#2d7a2d'));
      }
    });

    test('single habitat cell emits rings with opacities 0.07, 0.04, 0.02', () {
      final result = HabitatFillGeoJsonBuilder.buildHabitatFills(
        cellProperties: {
          'cell1': _makeCell('cell1', habitats: {Habitat.forest})
        },
        cellStates: {'cell1': FogState.active},
        getCellBoundary: _getBoundary,
      );
      final features = _features(_parse(result));

      expect(
        (features[0] as Map)['properties']['opacity'],
        closeTo(0.07, 1e-9),
      );
      expect(
        (features[1] as Map)['properties']['opacity'],
        closeTo(0.04, 1e-9),
      );
      expect(
        (features[2] as Map)['properties']['opacity'],
        closeTo(0.02, 1e-9),
      );
    });

    // -----------------------------------------------------------------------
    // Multi-habitat cell: Forest + Freshwater → averaged colour
    // Forest  #2D7A2D → R=45 G=122 B=45
    // Fresh   #3C7AD4 → R=60 G=122 B=212
    // Average           R=53 G=122 B=129 → #357a81
    // -----------------------------------------------------------------------

    test('multi-habitat cell averages colors across all habitats', () {
      const habitats = {Habitat.forest, Habitat.freshwater};
      final result = HabitatFillGeoJsonBuilder.buildHabitatFills(
        cellProperties: {'cell1': _makeCell('cell1', habitats: habitats)},
        cellStates: {'cell1': FogState.active},
        getCellBoundary: _getBoundary,
      );
      final features = _features(_parse(result));

      expect(features, hasLength(3));
      for (final f in features) {
        final props =
            (f as Map<String, dynamic>)['properties'] as Map<String, dynamic>;
        // R=(45+60)/2=52.5→53=0x35, G=(122+122)/2=122=0x7a, B=(45+212)/2=128.5→129=0x81
        expect(props['color'], equals('#357a81'));
      }
    });

    // -----------------------------------------------------------------------
    // Multiple eligible cells → all rendered
    // -----------------------------------------------------------------------

    test('multiple cells each emit 3 rings', () {
      final cells = {
        'cell1': _makeCell('cell1'),
        'cell2': _makeCell('cell2'),
        'cell3': _makeCell('cell3'),
      };
      final states = {
        'cell1': FogState.active,
        'cell2': FogState.visited,
        'cell3': FogState.nearby,
      };

      final result = HabitatFillGeoJsonBuilder.buildHabitatFills(
        cellProperties: cells,
        cellStates: states,
        getCellBoundary: _getBoundary,
      );
      final features = _features(_parse(result));
      // 3 cells × 3 rings each
      expect(features, hasLength(9));
    });

    test('mix of eligible and ineligible cells — only eligible rendered', () {
      final cells = {
        'vis': _makeCell('vis'),
        'hidden': _makeCell('hidden'),
        'gone': _makeCell('gone'),
      };
      final states = {
        'vis': FogState.active,
        'gone': FogState.unknown,
      };

      final result = HabitatFillGeoJsonBuilder.buildHabitatFills(
        cellProperties: cells,
        cellStates: states,
        getCellBoundary: _getBoundary,
      );
      final features = _features(_parse(result));
      // Only 'vis' (observed) qualifies — 1 cell × 3 rings
      expect(features, hasLength(3));
    });

    // -----------------------------------------------------------------------
    // Ring geometry: vertices inset toward centroid
    // Square boundary: centroid (lat=0, lon=1)
    // Ring 0 v0: lat=1.0, lon=0.0  → GeoJSON [0.0, 1.0]
    // Ring 1 v0: lat=0.75, lon=0.25 → GeoJSON [0.25, 0.75]
    // Ring 2 v0: lat=0.5, lon=0.5  → GeoJSON [0.5, 0.5]
    // -----------------------------------------------------------------------

    test('ring 0 uses original boundary vertices (scale=1.0)', () {
      final result = HabitatFillGeoJsonBuilder.buildHabitatFills(
        cellProperties: {'c': _makeCell('c')},
        cellStates: {'c': FogState.active},
        getCellBoundary: _getBoundary,
      );
      final features = _features(_parse(result));
      final ring0Coords =
          (features[0] as Map)['geometry']['coordinates'][0] as List<dynamic>;

      // First vertex [lon=0.0, lat=1.0]
      final v0 = ring0Coords[0] as List<dynamic>;
      expect((v0[0] as num).toDouble(), closeTo(0.0, 1e-9)); // lon
      expect((v0[1] as num).toDouble(), closeTo(1.0, 1e-9)); // lat
    });

    test('ring 1 vertices are closer to centroid than ring 0 vertices', () {
      final result = HabitatFillGeoJsonBuilder.buildHabitatFills(
        cellProperties: {'c': _makeCell('c')},
        cellStates: {'c': FogState.active},
        getCellBoundary: _getBoundary,
      );
      final features = _features(_parse(result));

      // Centroid is lat=0, lon=1 → GeoJSON [1, 0]
      const centroidLon = 1.0;
      const centroidLat = 0.0;

      final ring0Coords =
          (features[0] as Map)['geometry']['coordinates'][0] as List<dynamic>;
      final ring1Coords =
          (features[1] as Map)['geometry']['coordinates'][0] as List<dynamic>;

      // Compare first vertex distance to centroid (skip closing repeated vertex)
      double dist(List<dynamic> coords, int i) {
        final v = coords[i] as List<dynamic>;
        final dLon = (v[0] as num).toDouble() - centroidLon;
        final dLat = (v[1] as num).toDouble() - centroidLat;
        return dLon * dLon + dLat * dLat;
      }

      for (var i = 0; i < 4; i++) {
        expect(
          dist(ring1Coords, i),
          lessThan(dist(ring0Coords, i)),
          reason: 'Ring 1 vertex $i should be closer to centroid than ring 0',
        );
      }
    });

    test('ring 1 vertices are at 75% distance from centroid', () {
      final result = HabitatFillGeoJsonBuilder.buildHabitatFills(
        cellProperties: {'c': _makeCell('c')},
        cellStates: {'c': FogState.active},
        getCellBoundary: _getBoundary,
      );
      final features = _features(_parse(result));
      final ring1Coords =
          (features[1] as Map)['geometry']['coordinates'][0] as List<dynamic>;

      // First vertex ring 1: lat = 0 + 0.75*(1-0)=0.75, lon = 1 + 0.75*(0-1)=0.25
      final v0 = ring1Coords[0] as List<dynamic>;
      expect((v0[0] as num).toDouble(), closeTo(0.25, 1e-9)); // lon
      expect((v0[1] as num).toDouble(), closeTo(0.75, 1e-9)); // lat
    });

    test('ring 2 vertices are at 50% distance from centroid', () {
      final result = HabitatFillGeoJsonBuilder.buildHabitatFills(
        cellProperties: {'c': _makeCell('c')},
        cellStates: {'c': FogState.active},
        getCellBoundary: _getBoundary,
      );
      final features = _features(_parse(result));
      final ring2Coords =
          (features[2] as Map)['geometry']['coordinates'][0] as List<dynamic>;

      // First vertex ring 2: lat = 0 + 0.50*(1-0)=0.5, lon = 1 + 0.50*(0-1)=0.5
      final v0 = ring2Coords[0] as List<dynamic>;
      expect((v0[0] as num).toDouble(), closeTo(0.5, 1e-9)); // lon
      expect((v0[1] as num).toDouble(), closeTo(0.5, 1e-9)); // lat
    });

    // -----------------------------------------------------------------------
    // Ring polygon is closed (first vertex == last vertex)
    // -----------------------------------------------------------------------

    test('each ring polygon is a closed GeoJSON ring (first==last vertex)', () {
      final result = HabitatFillGeoJsonBuilder.buildHabitatFills(
        cellProperties: {'c': _makeCell('c')},
        cellStates: {'c': FogState.active},
        getCellBoundary: _getBoundary,
      );
      final features = _features(_parse(result));

      for (final f in features) {
        final coords =
            (f as Map)['geometry']['coordinates'][0] as List<dynamic>;
        // 4 boundary vertices + 1 closing vertex = 5 total
        expect(coords, hasLength(5));

        final first = coords.first as List<dynamic>;
        final last = coords.last as List<dynamic>;
        expect((first[0] as num).toDouble(),
            closeTo((last[0] as num).toDouble(), 1e-9));
        expect((first[1] as num).toDouble(),
            closeTo((last[1] as num).toDouble(), 1e-9));
      }
    });

    // -----------------------------------------------------------------------
    // Output is valid JSON
    // -----------------------------------------------------------------------

    test('output is valid JSON parseable by dart:convert jsonDecode', () {
      final result = HabitatFillGeoJsonBuilder.buildHabitatFills(
        cellProperties: {
          'a': _makeCell('a', habitats: {Habitat.forest}),
          'b': _makeCell('b', habitats: {Habitat.saltwater, Habitat.swamp}),
        },
        cellStates: {
          'a': FogState.active,
          'b': FogState.visited,
        },
        getCellBoundary: _getBoundary,
      );

      // Should not throw
      final parsed = _parse(result);
      expect(parsed['type'], equals('FeatureCollection'));
      expect(_features(parsed), hasLength(6)); // 2 cells × 3 rings
    });

    test('each feature has correct GeoJSON structure', () {
      final result = HabitatFillGeoJsonBuilder.buildHabitatFills(
        cellProperties: {'c': _makeCell('c')},
        cellStates: {'c': FogState.active},
        getCellBoundary: _getBoundary,
      );
      final features = _features(_parse(result));

      for (final f in features) {
        final feature = f as Map<String, dynamic>;
        expect(feature['type'], equals('Feature'));
        final geometry = feature['geometry'] as Map<String, dynamic>;
        expect(geometry['type'], equals('Polygon'));
        expect(geometry['coordinates'], isA<List>());
        final props = feature['properties'] as Map<String, dynamic>;
        expect(props['color'], isA<String>());
        expect(props['opacity'], isA<num>());
      }
    });
  });
}
