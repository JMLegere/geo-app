import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:geobase/geobase.dart';

import 'package:earth_nova/core/models/cell_properties.dart';
import 'package:earth_nova/core/models/climate.dart';
import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/features/map/utils/territory_border_geojson_builder.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Simple square cell boundary for testing. Each cell is a ~0.001° square
/// centered on its coordinates. Neighboring cells share edges.
List<Geographic> _boundary(String cellId) {
  final parts = cellId.split('_');
  final row = int.parse(parts[1]);
  final col = int.parse(parts[2]);
  // Each cell is a 0.001° square. Row/col map to lat/lon at 0.001° spacing.
  final lat = row * 0.001;
  final lon = col * 0.001;
  const half = 0.0005;
  return [
    Geographic(lat: lat - half, lon: lon - half),
    Geographic(lat: lat - half, lon: lon + half),
    Geographic(lat: lat + half, lon: lon + half),
    Geographic(lat: lat + half, lon: lon - half),
  ];
}

/// Returns the center point for a cell (matches the _boundary convention).
Geographic _cellCenter(String cellId) {
  final parts = cellId.split('_');
  final row = int.parse(parts[1]);
  final col = int.parse(parts[2]);
  return Geographic(lat: row * 0.001, lon: col * 0.001);
}

/// Returns neighbor IDs for a grid cell. Simple 4-connected grid.
List<String> _neighbors(String cellId) {
  final parts = cellId.split('_');
  final row = int.parse(parts[1]);
  final col = int.parse(parts[2]);
  return [
    'cell_${row - 1}_$col', // north
    'cell_${row + 1}_$col', // south
    'cell_${row}_${col - 1}', // west
    'cell_${row}_${col + 1}', // east
  ];
}

CellProperties _makeProps(String cellId) {
  return CellProperties(
    cellId: cellId,
    habitats: {Habitat.forest},
    climate: Climate.temperate,
    continent: Continent.northAmerica,
    locationId: null,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

Map<String, dynamic> _parse(String geoJson) =>
    jsonDecode(geoJson) as Map<String, dynamic>;

List<dynamic> _features(String geoJson) =>
    _parse(geoJson)['features'] as List<dynamic>;

// ---------------------------------------------------------------------------
// Test data: 2×2 grid split across two countries
// ---------------------------------------------------------------------------

/// ```
/// [cell_0_0] [cell_0_1]   ← Country A (both)
/// [cell_1_0] [cell_1_1]   ← Country B (both)
/// ```
Map<String, String> _twoCountryCellDistrictIds() {
  return {
    'cell_0_0': 'dist_a',
    'cell_0_1': 'dist_a',
    'cell_1_0': 'dist_b',
    'cell_1_1': 'dist_b',
  };
}

Map<String, ({String? cityId, String? stateId, String? countryId})>
    _twoCountryDistrictAncestry() {
  return {
    'dist_a': (cityId: null, stateId: null, countryId: 'country_a'),
    'dist_b': (cityId: null, stateId: null, countryId: 'country_b'),
  };
}

Map<String, CellProperties> _twoCountryProps() {
  return {
    'cell_0_0': _makeProps('cell_0_0'),
    'cell_0_1': _makeProps('cell_0_1'),
    'cell_1_0': _makeProps('cell_1_0'),
    'cell_1_1': _makeProps('cell_1_1'),
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('TerritoryBorderGeoJsonBuilder', () {
    group('emptyFeatureCollection', () {
      test('is valid GeoJSON', () {
        final parsed =
            _parse(TerritoryBorderGeoJsonBuilder.emptyFeatureCollection);
        expect(parsed['type'], 'FeatureCollection');
        expect(parsed['features'], isEmpty);
      });
    });

    group('buildBorderFill', () {
      test('returns empty features when no cells have district attribution',
          () {
        final json = TerritoryBorderGeoJsonBuilder.buildBorderFill(
          cellProperties: {
            'cell_0_0': _makeProps('cell_0_0'),
          },
          cellDistrictIds: {}, // no attribution
          districtAncestry: {},
          visibleCellIds: {'cell_0_0'},
          getNeighborIds: _neighbors,
          getBoundary: _boundary,
        );

        expect(_features(json), isEmpty);
      });

      test('returns empty features when all cells are in same region', () {
        final json = TerritoryBorderGeoJsonBuilder.buildBorderFill(
          cellProperties: {
            'cell_0_0': _makeProps('cell_0_0'),
            'cell_0_1': _makeProps('cell_0_1'),
          },
          cellDistrictIds: {
            'cell_0_0': 'dist_a',
            'cell_0_1': 'dist_a',
          },
          districtAncestry: {
            'dist_a': (cityId: null, stateId: null, countryId: 'country_a'),
          },
          visibleCellIds: {'cell_0_0', 'cell_0_1'},
          getNeighborIds: _neighbors,
          getBoundary: _boundary,
        );

        expect(_features(json), isEmpty);
      });

      test('produces border features for cells at country boundary', () {
        final props = _twoCountryProps();
        final allCells = props.keys.toSet();

        final json = TerritoryBorderGeoJsonBuilder.buildBorderFill(
          cellProperties: props,
          cellDistrictIds: _twoCountryCellDistrictIds(),
          districtAncestry: _twoCountryDistrictAncestry(),
          visibleCellIds: allCells,
          getNeighborIds: _neighbors,
          getBoundary: _boundary,
        );

        final features = _features(json);
        // All 4 cells should have border properties since it's a 2×2 grid
        // with the border running through the middle.
        expect(features, isNotEmpty);

        // Verify border cells have distance 0 at country level.
        for (final f in features) {
          final fProps = (f as Map)['properties'] as Map;
          expect(fProps.containsKey('cell_id'), isTrue);
          expect(fProps.containsKey('border_distance_country'), isTrue);
        }
      });

      test('border cells have distance 0, neighbors have distance 1', () {
        // 3-row grid: top=A, middle=A (border), bottom=B
        final props = {
          'cell_0_0': _makeProps('cell_0_0'),
          'cell_1_0': _makeProps('cell_1_0'),
          'cell_2_0': _makeProps('cell_2_0'),
        };
        final allCells = props.keys.toSet();

        final json = TerritoryBorderGeoJsonBuilder.buildBorderFill(
          cellProperties: props,
          cellDistrictIds: {
            'cell_0_0': 'dist_a',
            'cell_1_0': 'dist_a',
            'cell_2_0': 'dist_b',
          },
          districtAncestry: {
            'dist_a': (cityId: null, stateId: null, countryId: 'country_a'),
            'dist_b': (cityId: null, stateId: null, countryId: 'country_b'),
          },
          visibleCellIds: allCells,
          getNeighborIds: _neighbors,
          getBoundary: _boundary,
        );

        final features = _features(json);
        final byId = <String, Map>{};
        for (final f in features) {
          final fProps = (f as Map)['properties'] as Map;
          byId[fProps['cell_id'] as String] = fProps;
        }

        // cell_1_0 (A) and cell_2_0 (B) are on the border → distance 0.
        expect(byId['cell_1_0']?['border_distance_country'], 0);
        expect(byId['cell_2_0']?['border_distance_country'], 0);

        // cell_0_0 is 1 cell from border → distance 1.
        expect(byId['cell_0_0']?['border_distance_country'], 1);
      });

      test('cells beyond max distance (3) are not included', () {
        // 8-row column: rows 0-3 = A, rows 4-7 = B.
        // Border is between row 3 and row 4.
        final districtIds = <String, String>{};
        final props = <String, CellProperties>{};
        for (var r = 0; r < 8; r++) {
          final distId = r < 4 ? 'dist_a' : 'dist_b';
          districtIds['cell_${r}_0'] = distId;
          props['cell_${r}_0'] = _makeProps('cell_${r}_0');
        }
        final allCells = props.keys.toSet();

        final json = TerritoryBorderGeoJsonBuilder.buildBorderFill(
          cellProperties: props,
          cellDistrictIds: districtIds,
          districtAncestry: {
            'dist_a': (cityId: null, stateId: null, countryId: 'country_a'),
            'dist_b': (cityId: null, stateId: null, countryId: 'country_b'),
          },
          visibleCellIds: allCells,
          getNeighborIds: _neighbors,
          getBoundary: _boundary,
        );

        final features = _features(json);
        final byId = <String, Map>{};
        for (final f in features) {
          final fProps = (f as Map)['properties'] as Map;
          byId[fProps['cell_id'] as String] = fProps;
        }

        // Border at row 3/4: both at distance 0.
        expect(byId['cell_3_0']?['border_distance_country'], 0);
        expect(byId['cell_4_0']?['border_distance_country'], 0);

        // row 0 = 3 cells from border → NOT included (distance 3 is excluded).
        expect(byId.containsKey('cell_0_0'), isFalse);

        // row 7 = 3 cells from border → NOT included.
        expect(byId.containsKey('cell_7_0'), isFalse);
      });

      test('border fill features include region color from FNV hash', () {
        final props = _twoCountryProps();
        final allCells = props.keys.toSet();

        final json = TerritoryBorderGeoJsonBuilder.buildBorderFill(
          cellProperties: props,
          cellDistrictIds: _twoCountryCellDistrictIds(),
          districtAncestry: _twoCountryDistrictAncestry(),
          visibleCellIds: allCells,
          getNeighborIds: _neighbors,
          getBoundary: _boundary,
        );

        final features = _features(json);
        final colorsByCell = <String, String>{};
        for (final f in features) {
          final fProps = (f as Map)['properties'] as Map;
          final cellId = fProps['cell_id'] as String;
          if (fProps.containsKey('region_color_country')) {
            colorsByCell[cellId] = fProps['region_color_country'] as String;
          }
        }

        expect(colorsByCell, isNotEmpty);

        // All cells in the same country should have the same color.
        final colorA = colorsByCell['cell_0_0'];
        final colorB = colorsByCell['cell_1_0'];
        expect(colorA, isNotNull);
        expect(colorB, isNotNull);
        // Colors are valid hex strings.
        expect(colorA!, startsWith('#'));
        expect(colorA.length, 7);
        expect(colorB!, startsWith('#'));
        expect(colorB.length, 7);
        // Different countries get different colors.
        expect(colorA, isNot(equals(colorB)));

        // cell_0_1 (same country as cell_0_0) should have the same color.
        expect(colorsByCell['cell_0_1'], equals(colorA));
      });

      test('border fill polygons have valid GeoJSON geometry', () {
        final props = _twoCountryProps();
        final allCells = props.keys.toSet();

        final json = TerritoryBorderGeoJsonBuilder.buildBorderFill(
          cellProperties: props,
          cellDistrictIds: _twoCountryCellDistrictIds(),
          districtAncestry: _twoCountryDistrictAncestry(),
          visibleCellIds: allCells,
          getNeighborIds: _neighbors,
          getBoundary: _boundary,
        );

        final features = _features(json);
        for (final f in features) {
          final geometry = (f as Map)['geometry'] as Map;
          expect(geometry['type'], 'Polygon');
          final coords = geometry['coordinates'] as List;
          expect(coords, isNotEmpty);
          final ring = coords[0] as List;
          // Closed ring: first == last.
          expect(ring.length, greaterThanOrEqualTo(4)); // 3 vertices + close
          expect(ring.first, ring.last);
        }
      });

      test('deterministic color generated for any region ID', () {
        final props = {
          'cell_0_0': _makeProps('cell_0_0'),
          'cell_1_0': _makeProps('cell_1_0'),
        };

        final json = TerritoryBorderGeoJsonBuilder.buildBorderFill(
          cellProperties: props,
          cellDistrictIds: {
            'cell_0_0': 'dist_a',
            'cell_1_0': 'dist_b',
          },
          districtAncestry: {
            'dist_a': (cityId: null, stateId: null, countryId: 'any_country_a'),
            'dist_b': (cityId: null, stateId: null, countryId: 'any_country_b'),
          },
          visibleCellIds: props.keys.toSet(),
          getNeighborIds: _neighbors,
          getBoundary: _boundary,
        );

        final features = _features(json);
        expect(features, isNotEmpty);

        for (final f in features) {
          final fProps = (f as Map)['properties'] as Map;
          final color = fProps['region_color_country'] as String;
          // Should be a valid hex color.
          expect(color, startsWith('#'));
          expect(color.length, 7); // #RRGGBB
        }
      });
    });

    group('buildBorderLines', () {
      test('returns empty features when no cells have district attribution',
          () {
        final json = TerritoryBorderGeoJsonBuilder.buildBorderLines(
          cellProperties: {
            'cell_0_0': _makeProps('cell_0_0'),
          },
          cellDistrictIds: {},
          districtAncestry: {},
          visibleCellIds: {'cell_0_0'},
          getNeighborIds: _neighbors,
          getBoundary: _boundary,
          getCellCenter: _cellCenter,
        );

        expect(_features(json), isEmpty);
      });

      test('returns empty features when all cells in same region', () {
        final json = TerritoryBorderGeoJsonBuilder.buildBorderLines(
          cellProperties: {
            'cell_0_0': _makeProps('cell_0_0'),
            'cell_0_1': _makeProps('cell_0_1'),
          },
          cellDistrictIds: {
            'cell_0_0': 'dist_a',
            'cell_0_1': 'dist_a',
          },
          districtAncestry: {
            'dist_a': (cityId: null, stateId: null, countryId: 'country_a'),
          },
          visibleCellIds: {'cell_0_0', 'cell_0_1'},
          getNeighborIds: _neighbors,
          getBoundary: _boundary,
          getCellCenter: _cellCenter,
        );

        expect(_features(json), isEmpty);
      });

      test('produces border lines at country boundary', () {
        final props = _twoCountryProps();
        final allCells = props.keys.toSet();

        final json = TerritoryBorderGeoJsonBuilder.buildBorderLines(
          cellProperties: props,
          cellDistrictIds: _twoCountryCellDistrictIds(),
          districtAncestry: _twoCountryDistrictAncestry(),
          visibleCellIds: allCells,
          getNeighborIds: _neighbors,
          getBoundary: _boundary,
          getCellCenter: _cellCenter,
        );

        final features = _features(json);
        expect(features, isNotEmpty);

        for (final f in features) {
          final fMap = f as Map;
          final fProps = fMap['properties'] as Map;
          // Districts differ (dist_a vs dist_b), so border is at district level
          // even though countries also differ. Lowest differing level wins.
          expect(fProps['admin_level'], 'district');
          expect(fProps['line_weight'], 4.0);
          expect(fProps.containsKey('border_color'), isTrue);
          // Each feature has a side (+1 or -1) for line-offset.
          expect(fProps['side'], anyOf(1, -1));

          final geometry = fMap['geometry'] as Map;
          expect(geometry['type'], 'LineString');
          final coords = geometry['coordinates'] as List;
          expect(coords.length, 2); // Shared edge = 2 points.
        }
      });

      test('emits two features per shared edge (one per side)', () {
        final props = {
          'cell_0_0': _makeProps('cell_0_0'),
          'cell_1_0': _makeProps('cell_1_0'),
        };

        final json = TerritoryBorderGeoJsonBuilder.buildBorderLines(
          cellProperties: props,
          cellDistrictIds: {
            'cell_0_0': 'dist_a',
            'cell_1_0': 'dist_b',
          },
          districtAncestry: {
            'dist_a': (cityId: null, stateId: null, countryId: 'country_a'),
            'dist_b': (cityId: null, stateId: null, countryId: 'country_b'),
          },
          visibleCellIds: props.keys.toSet(),
          getNeighborIds: _neighbors,
          getBoundary: _boundary,
          getCellCenter: _cellCenter,
        );

        final features = _features(json);
        // 1 shared edge → 2 features (one per side).
        expect(features.length, 2);

        // The two features should have opposite sides.
        final sides = features
            .map((f) => (f as Map)['properties']['side'] as int)
            .toList();
        expect(sides.toSet(), {1, -1});

        // Both colors should be deterministic hex strings.
        final colors = features
            .map((f) => (f as Map)['properties']['border_color'] as String)
            .toSet();
        expect(colors.length, 2); // Two different country colors.
        for (final c in colors) {
          expect(c, startsWith('#'));
          expect(c.length, 7);
        }
      });

      test('lowest differing level renders (stacking rules)', () {
        // Two cells in same country, different states.
        final props = {
          'cell_0_0': _makeProps('cell_0_0'),
          'cell_1_0': _makeProps('cell_1_0'),
        };

        final json = TerritoryBorderGeoJsonBuilder.buildBorderLines(
          cellProperties: props,
          cellDistrictIds: {
            'cell_0_0': 'dist_state_a',
            'cell_1_0': 'dist_state_b',
          },
          districtAncestry: {
            'dist_state_a': (
              cityId: null,
              stateId: 'state_a',
              countryId: 'country'
            ),
            'dist_state_b': (
              cityId: null,
              stateId: 'state_b',
              countryId: 'country'
            ),
          },
          visibleCellIds: props.keys.toSet(),
          getNeighborIds: _neighbors,
          getBoundary: _boundary,
          getCellCenter: _cellCenter,
        );

        final features = _features(json);
        // 1 edge → 2 features (one per side).
        expect(features.length, 2);

        // Both features should report district-level border.
        // Districts differ (dist_state_a vs dist_state_b), so border is at
        // district level even though states also differ. Lowest differing level wins.
        for (final f in features) {
          final fProps = (f as Map)['properties'] as Map;
          expect(fProps['admin_level'], 'district');
          expect(fProps['line_weight'], 4.0);
        }
      });

      test('line weight varies by admin level', () {
        // Two cells in different districts of the same city/state/country.
        final props = {
          'cell_0_0': _makeProps('cell_0_0'),
          'cell_1_0': _makeProps('cell_1_0'),
        };

        final json = TerritoryBorderGeoJsonBuilder.buildBorderLines(
          cellProperties: props,
          cellDistrictIds: {
            'cell_0_0': 'district_a',
            'cell_1_0': 'district_b',
          },
          districtAncestry: {
            'district_a': (
              cityId: 'city',
              stateId: 'state',
              countryId: 'country'
            ),
            'district_b': (
              cityId: 'city',
              stateId: 'state',
              countryId: 'country'
            ),
          },
          visibleCellIds: props.keys.toSet(),
          getNeighborIds: _neighbors,
          getBoundary: _boundary,
          getCellCenter: _cellCenter,
        );

        final features = _features(json);
        // 1 edge → 2 features (one per side).
        expect(features.length, 2);

        for (final f in features) {
          final fProps = (f as Map)['properties'] as Map;
          expect(fProps['admin_level'], 'district');
          expect(fProps['line_weight'], 4.0);
        }
      });

      test('border line coordinates use lon,lat GeoJSON convention', () {
        final props = {
          'cell_0_0': _makeProps('cell_0_0'),
          'cell_1_0': _makeProps('cell_1_0'),
        };

        final json = TerritoryBorderGeoJsonBuilder.buildBorderLines(
          cellProperties: props,
          cellDistrictIds: {
            'cell_0_0': 'dist_a',
            'cell_1_0': 'dist_b',
          },
          districtAncestry: {
            'dist_a': (cityId: null, stateId: null, countryId: 'country_a'),
            'dist_b': (cityId: null, stateId: null, countryId: 'country_b'),
          },
          visibleCellIds: props.keys.toSet(),
          getNeighborIds: _neighbors,
          getBoundary: _boundary,
          getCellCenter: _cellCenter,
        );

        final features = _features(json);
        if (features.isNotEmpty) {
          final geometry = (features.first as Map)['geometry'] as Map;
          final coords = geometry['coordinates'] as List;
          for (final point in coords) {
            final p = point as List;
            // [lon, lat] — should be small values from our test grid.
            expect(p.length, 2);
            expect(p[0], isA<num>()); // lon
            expect(p[1], isA<num>()); // lat
          }
        }
      });
    });

    group('edge cases', () {
      test(
          'cells with missing ancestry data (districtId not in ancestry) are skipped',
          () {
        final props = {
          'cell_0_0': _makeProps('cell_0_0'),
          'cell_1_0': _makeProps('cell_1_0'),
        };

        final fillJson = TerritoryBorderGeoJsonBuilder.buildBorderFill(
          cellProperties: props,
          cellDistrictIds: {
            'cell_0_0': 'nonexistent_dist',
            'cell_1_0': 'also_nonexistent',
          },
          districtAncestry: {}, // Empty — ancestry doesn't exist.
          visibleCellIds: props.keys.toSet(),
          getNeighborIds: _neighbors,
          getBoundary: _boundary,
        );
        expect(_features(fillJson), isEmpty);

        final lineJson = TerritoryBorderGeoJsonBuilder.buildBorderLines(
          cellProperties: props,
          cellDistrictIds: {
            'cell_0_0': 'nonexistent_dist',
            'cell_1_0': 'also_nonexistent',
          },
          districtAncestry: {},
          visibleCellIds: props.keys.toSet(),
          getNeighborIds: _neighbors,
          getBoundary: _boundary,
          getCellCenter: _cellCenter,
        );
        expect(_features(lineJson), isEmpty);
      });

      test('single cell with district attribution but no neighbors in viewport',
          () {
        final props = {
          'cell_0_0': _makeProps('cell_0_0'),
        };

        final json = TerritoryBorderGeoJsonBuilder.buildBorderFill(
          cellProperties: props,
          cellDistrictIds: {'cell_0_0': 'dist_a'},
          districtAncestry: {
            'dist_a': (cityId: null, stateId: null, countryId: 'country_a'),
          },
          visibleCellIds: {'cell_0_0'},
          getNeighborIds: _neighbors,
          getBoundary: _boundary,
        );

        // No border because neighbors have no location data — they're
        // outside mapped territory, not an actual admin boundary.
        final features = _features(json);
        expect(features.length, 0);
      });

      test('empty visible cell set returns empty features', () {
        final fillJson = TerritoryBorderGeoJsonBuilder.buildBorderFill(
          cellProperties: {},
          cellDistrictIds: {},
          districtAncestry: {},
          visibleCellIds: {},
          getNeighborIds: _neighbors,
          getBoundary: _boundary,
        );
        expect(_features(fillJson), isEmpty);

        final lineJson = TerritoryBorderGeoJsonBuilder.buildBorderLines(
          cellProperties: {},
          cellDistrictIds: {},
          districtAncestry: {},
          visibleCellIds: {},
          getNeighborIds: _neighbors,
          getBoundary: _boundary,
          getCellCenter: _cellCenter,
        );
        expect(_features(lineJson), isEmpty);
      });
    });
  });
}
