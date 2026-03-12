import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:geobase/geobase.dart';

import 'package:earth_nova/core/models/cell_properties.dart';
import 'package:earth_nova/core/models/climate.dart';
import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/models/location_node.dart';
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

CellProperties _makeProps(String cellId, {String? locationId}) {
  return CellProperties(
    cellId: cellId,
    habitats: {Habitat.forest},
    climate: Climate.temperate,
    continent: Continent.northAmerica,
    locationId: locationId,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

LocationNode _makeNode({
  required String id,
  required String name,
  required AdminLevel adminLevel,
  String? parentId,
  int? osmId,
  String? colorHex,
}) {
  return LocationNode(
    id: id,
    osmId: osmId,
    name: name,
    adminLevel: adminLevel,
    parentId: parentId,
    colorHex: colorHex,
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
Map<String, LocationNode> _twoCountryNodes() {
  return {
    'world': _makeNode(
      id: 'world',
      name: 'World',
      adminLevel: AdminLevel.world,
    ),
    'country_a': _makeNode(
      id: 'country_a',
      name: 'Country A',
      adminLevel: AdminLevel.country,
      parentId: 'world',
      osmId: 100,
      colorHex: '#FF0000',
    ),
    'country_b': _makeNode(
      id: 'country_b',
      name: 'Country B',
      adminLevel: AdminLevel.country,
      parentId: 'world',
      osmId: 200,
      colorHex: '#0000FF',
    ),
  };
}

Map<String, CellProperties> _twoCountryProps() {
  return {
    'cell_0_0': _makeProps('cell_0_0', locationId: 'country_a'),
    'cell_0_1': _makeProps('cell_0_1', locationId: 'country_a'),
    'cell_1_0': _makeProps('cell_1_0', locationId: 'country_b'),
    'cell_1_1': _makeProps('cell_1_1', locationId: 'country_b'),
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
      test('returns empty features when no cells have location data', () {
        final json = TerritoryBorderGeoJsonBuilder.buildBorderFill(
          cellProperties: {
            'cell_0_0': _makeProps('cell_0_0'), // no locationId
          },
          locationNodes: {},
          visibleCellIds: {'cell_0_0'},
          getNeighborIds: _neighbors,
          getBoundary: _boundary,
        );

        expect(_features(json), isEmpty);
      });

      test('returns empty features when all cells are in same region', () {
        final nodes = _twoCountryNodes();
        final json = TerritoryBorderGeoJsonBuilder.buildBorderFill(
          cellProperties: {
            'cell_0_0': _makeProps('cell_0_0', locationId: 'country_a'),
            'cell_0_1': _makeProps('cell_0_1', locationId: 'country_a'),
          },
          locationNodes: nodes,
          visibleCellIds: {'cell_0_0', 'cell_0_1'},
          getNeighborIds: _neighbors,
          getBoundary: _boundary,
        );

        expect(_features(json), isEmpty);
      });

      test('produces border features for cells at country boundary', () {
        final nodes = _twoCountryNodes();
        final props = _twoCountryProps();
        final allCells = props.keys.toSet();

        final json = TerritoryBorderGeoJsonBuilder.buildBorderFill(
          cellProperties: props,
          locationNodes: nodes,
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
        final nodes = _twoCountryNodes();
        final props = {
          'cell_0_0': _makeProps('cell_0_0', locationId: 'country_a'),
          'cell_1_0': _makeProps('cell_1_0', locationId: 'country_a'),
          'cell_2_0': _makeProps('cell_2_0', locationId: 'country_b'),
        };
        final allCells = props.keys.toSet();

        final json = TerritoryBorderGeoJsonBuilder.buildBorderFill(
          cellProperties: props,
          locationNodes: nodes,
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
        // 6-row column: rows 0-2 = A, rows 3-5 = B.
        // Border is between row 2 and row 3.
        // Row 0 is 2 cells from border. Row 5 is 2 cells from border.
        // With max distance 3, all should be included in this case.
        // But let's test with a longer chain.
        final nodes = _twoCountryNodes();
        final props = <String, CellProperties>{};
        for (var r = 0; r < 8; r++) {
          final locId = r < 4 ? 'country_a' : 'country_b';
          props['cell_${r}_0'] = _makeProps('cell_${r}_0', locationId: locId);
        }
        final allCells = props.keys.toSet();

        final json = TerritoryBorderGeoJsonBuilder.buildBorderFill(
          cellProperties: props,
          locationNodes: nodes,
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

        // Border at row 3/4: row 3 = dist 0, row 4 = dist 0
        expect(byId['cell_3_0']?['border_distance_country'], 0);
        expect(byId['cell_4_0']?['border_distance_country'], 0);

        // row 0 = 3 cells from border → NOT included (distance 3 is excluded).
        expect(byId.containsKey('cell_0_0'), isFalse);

        // row 7 = 3 cells from border → NOT included.
        expect(byId.containsKey('cell_7_0'), isFalse);
      });

      test('border fill features include region color from node', () {
        final nodes = _twoCountryNodes();
        final props = _twoCountryProps();
        final allCells = props.keys.toSet();

        final json = TerritoryBorderGeoJsonBuilder.buildBorderFill(
          cellProperties: props,
          locationNodes: nodes,
          visibleCellIds: allCells,
          getNeighborIds: _neighbors,
          getBoundary: _boundary,
        );

        final features = _features(json);
        for (final f in features) {
          final fProps = (f as Map)['properties'] as Map;
          final cellId = fProps['cell_id'] as String;
          final color = fProps['region_color_country'] as String;
          if (cellId == 'cell_0_0' || cellId == 'cell_0_1') {
            expect(color, '#FF0000'); // Country A
          } else {
            expect(color, '#0000FF'); // Country B
          }
        }
      });

      test('border fill polygons have valid GeoJSON geometry', () {
        final nodes = _twoCountryNodes();
        final props = _twoCountryProps();
        final allCells = props.keys.toSet();

        final json = TerritoryBorderGeoJsonBuilder.buildBorderFill(
          cellProperties: props,
          locationNodes: nodes,
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

      test('deterministic color generated when node has no colorHex', () {
        final nodes = {
          'world': _makeNode(
            id: 'world',
            name: 'World',
            adminLevel: AdminLevel.world,
          ),
          'country_a': _makeNode(
            id: 'country_a',
            name: 'Country A',
            adminLevel: AdminLevel.country,
            parentId: 'world',
            osmId: 12345,
            // No colorHex — should generate deterministic color.
          ),
          'country_b': _makeNode(
            id: 'country_b',
            name: 'Country B',
            adminLevel: AdminLevel.country,
            parentId: 'world',
            osmId: 67890,
          ),
        };
        final props = {
          'cell_0_0': _makeProps('cell_0_0', locationId: 'country_a'),
          'cell_1_0': _makeProps('cell_1_0', locationId: 'country_b'),
        };

        final json = TerritoryBorderGeoJsonBuilder.buildBorderFill(
          cellProperties: props,
          locationNodes: nodes,
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
      test('returns empty features when no cells have location data', () {
        final json = TerritoryBorderGeoJsonBuilder.buildBorderLines(
          cellProperties: {
            'cell_0_0': _makeProps('cell_0_0'),
          },
          locationNodes: {},
          visibleCellIds: {'cell_0_0'},
          getNeighborIds: _neighbors,
          getBoundary: _boundary,
        );

        expect(_features(json), isEmpty);
      });

      test('returns empty features when all cells in same region', () {
        final nodes = _twoCountryNodes();
        final json = TerritoryBorderGeoJsonBuilder.buildBorderLines(
          cellProperties: {
            'cell_0_0': _makeProps('cell_0_0', locationId: 'country_a'),
            'cell_0_1': _makeProps('cell_0_1', locationId: 'country_a'),
          },
          locationNodes: nodes,
          visibleCellIds: {'cell_0_0', 'cell_0_1'},
          getNeighborIds: _neighbors,
          getBoundary: _boundary,
        );

        expect(_features(json), isEmpty);
      });

      test('produces border lines at country boundary', () {
        final nodes = _twoCountryNodes();
        final props = _twoCountryProps();
        final allCells = props.keys.toSet();

        final json = TerritoryBorderGeoJsonBuilder.buildBorderLines(
          cellProperties: props,
          locationNodes: nodes,
          visibleCellIds: allCells,
          getNeighborIds: _neighbors,
          getBoundary: _boundary,
        );

        final features = _features(json);
        expect(features, isNotEmpty);

        for (final f in features) {
          final fMap = f as Map;
          final fProps = fMap['properties'] as Map;
          expect(fProps['admin_level'], 'country');
          expect(fProps['line_weight'], 12.0);
          expect(fProps.containsKey('border_color'), isTrue);

          final geometry = fMap['geometry'] as Map;
          expect(geometry['type'], 'LineString');
          final coords = geometry['coordinates'] as List;
          expect(coords.length, 2); // Shared edge = 2 points.
        }
      });

      test('no duplicate edges for same cell pair', () {
        final nodes = _twoCountryNodes();
        final props = {
          'cell_0_0': _makeProps('cell_0_0', locationId: 'country_a'),
          'cell_1_0': _makeProps('cell_1_0', locationId: 'country_b'),
        };

        final json = TerritoryBorderGeoJsonBuilder.buildBorderLines(
          cellProperties: props,
          locationNodes: nodes,
          visibleCellIds: props.keys.toSet(),
          getNeighborIds: _neighbors,
          getBoundary: _boundary,
        );

        final features = _features(json);
        // Only 1 shared edge between cell_0_0 and cell_1_0.
        expect(features.length, 1);
      });

      test('lowest differing level renders (stacking rules)', () {
        // Two cells in same country, different states.
        final nodes = {
          'world': _makeNode(
            id: 'world',
            name: 'World',
            adminLevel: AdminLevel.world,
          ),
          'country': _makeNode(
            id: 'country',
            name: 'Country',
            adminLevel: AdminLevel.country,
            parentId: 'world',
            osmId: 100,
            colorHex: '#FF0000',
          ),
          'state_a': _makeNode(
            id: 'state_a',
            name: 'State A',
            adminLevel: AdminLevel.state,
            parentId: 'country',
            osmId: 110,
            colorHex: '#00FF00',
          ),
          'state_b': _makeNode(
            id: 'state_b',
            name: 'State B',
            adminLevel: AdminLevel.state,
            parentId: 'country',
            osmId: 120,
            colorHex: '#0000FF',
          ),
        };

        final props = {
          'cell_0_0': _makeProps('cell_0_0', locationId: 'state_a'),
          'cell_1_0': _makeProps('cell_1_0', locationId: 'state_b'),
        };

        final json = TerritoryBorderGeoJsonBuilder.buildBorderLines(
          cellProperties: props,
          locationNodes: nodes,
          visibleCellIds: props.keys.toSet(),
          getNeighborIds: _neighbors,
          getBoundary: _boundary,
        );

        final features = _features(json);
        expect(features.length, 1);

        final fProps = (features.first as Map)['properties'] as Map;
        // Should render as state border (lowest differing), not country.
        expect(fProps['admin_level'], 'state');
        expect(fProps['line_weight'], 8.0);
      });

      test('line weight varies by admin level', () {
        // Create district-level difference.
        final nodes = {
          'world': _makeNode(
            id: 'world',
            name: 'World',
            adminLevel: AdminLevel.world,
          ),
          'country': _makeNode(
            id: 'country',
            name: 'Country',
            adminLevel: AdminLevel.country,
            parentId: 'world',
            osmId: 100,
          ),
          'state': _makeNode(
            id: 'state',
            name: 'State',
            adminLevel: AdminLevel.state,
            parentId: 'country',
            osmId: 110,
          ),
          'city': _makeNode(
            id: 'city',
            name: 'City',
            adminLevel: AdminLevel.city,
            parentId: 'state',
            osmId: 1000,
          ),
          'district_a': _makeNode(
            id: 'district_a',
            name: 'District A',
            adminLevel: AdminLevel.district,
            parentId: 'city',
            osmId: 2000,
            colorHex: '#AABB00',
          ),
          'district_b': _makeNode(
            id: 'district_b',
            name: 'District B',
            adminLevel: AdminLevel.district,
            parentId: 'city',
            osmId: 3000,
            colorHex: '#00BBAA',
          ),
        };

        final props = {
          'cell_0_0': _makeProps('cell_0_0', locationId: 'district_a'),
          'cell_1_0': _makeProps('cell_1_0', locationId: 'district_b'),
        };

        final json = TerritoryBorderGeoJsonBuilder.buildBorderLines(
          cellProperties: props,
          locationNodes: nodes,
          visibleCellIds: props.keys.toSet(),
          getNeighborIds: _neighbors,
          getBoundary: _boundary,
        );

        final features = _features(json);
        expect(features.length, 1);

        final fProps = (features.first as Map)['properties'] as Map;
        expect(fProps['admin_level'], 'district');
        expect(fProps['line_weight'], 4.0);
      });

      test('border line coordinates use lon,lat GeoJSON convention', () {
        final nodes = _twoCountryNodes();
        final props = {
          'cell_0_0': _makeProps('cell_0_0', locationId: 'country_a'),
          'cell_1_0': _makeProps('cell_1_0', locationId: 'country_b'),
        };

        final json = TerritoryBorderGeoJsonBuilder.buildBorderLines(
          cellProperties: props,
          locationNodes: nodes,
          visibleCellIds: props.keys.toSet(),
          getNeighborIds: _neighbors,
          getBoundary: _boundary,
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
      test('cells with missing location node are skipped gracefully', () {
        final props = {
          'cell_0_0': _makeProps('cell_0_0', locationId: 'nonexistent_node'),
          'cell_1_0': _makeProps('cell_1_0', locationId: 'also_nonexistent'),
        };

        final fillJson = TerritoryBorderGeoJsonBuilder.buildBorderFill(
          cellProperties: props,
          locationNodes: {}, // Empty — nodes don't exist.
          visibleCellIds: props.keys.toSet(),
          getNeighborIds: _neighbors,
          getBoundary: _boundary,
        );
        expect(_features(fillJson), isEmpty);

        final lineJson = TerritoryBorderGeoJsonBuilder.buildBorderLines(
          cellProperties: props,
          locationNodes: {},
          visibleCellIds: props.keys.toSet(),
          getNeighborIds: _neighbors,
          getBoundary: _boundary,
        );
        expect(_features(lineJson), isEmpty);
      });

      test('single cell with location data but no neighbors in viewport', () {
        final nodes = _twoCountryNodes();
        final props = {
          'cell_0_0': _makeProps('cell_0_0', locationId: 'country_a'),
        };

        final json = TerritoryBorderGeoJsonBuilder.buildBorderFill(
          cellProperties: props,
          locationNodes: nodes,
          visibleCellIds: {'cell_0_0'},
          getNeighborIds: _neighbors,
          getBoundary: _boundary,
        );

        // No border because neighbors have no location data — they're
        // outside mapped territory, not an actual admin boundary.
        // _findBorderCells skips neighbors with no ancestor data.
        final features = _features(json);
        expect(features.length, 0);
      });

      test('empty visible cell set returns empty features', () {
        final fillJson = TerritoryBorderGeoJsonBuilder.buildBorderFill(
          cellProperties: {},
          locationNodes: {},
          visibleCellIds: {},
          getNeighborIds: _neighbors,
          getBoundary: _boundary,
        );
        expect(_features(fillJson), isEmpty);

        final lineJson = TerritoryBorderGeoJsonBuilder.buildBorderLines(
          cellProperties: {},
          locationNodes: {},
          visibleCellIds: {},
          getNeighborIds: _neighbors,
          getBoundary: _boundary,
        );
        expect(_features(lineJson), isEmpty);
      });
    });
  });
}
