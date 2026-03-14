import 'dart:convert';

import 'package:earth_nova/core/models/location_node.dart';
import 'package:earth_nova/features/map/utils/admin_boundary_geojson_builder.dart';
import 'package:earth_nova/shared/constants.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Test geometry fixtures
// ---------------------------------------------------------------------------

/// Simple 5-point polygon (closed ring): unit square at origin.
const kPolygonGeom =
    '{"type":"Polygon","coordinates":[[[0.0,0.0],[1.0,0.0],[1.0,1.0],[0.0,1.0],[0.0,0.0]]]}';

/// MultiPolygon with two sub-polygons (two distinct squares).
const kMultiPolygonGeom =
    '{"type":"MultiPolygon","coordinates":[[[[0.0,0.0],[1.0,0.0],[1.0,1.0],[0.0,1.0],[0.0,0.0]]],[[[2.0,2.0],[3.0,2.0],[3.0,3.0],[2.0,3.0],[2.0,2.0]]]]}';

// ---------------------------------------------------------------------------
// Factory helper
// ---------------------------------------------------------------------------

LocationNode makeNode({
  String id = 'node-1',
  int? osmId = 12345,
  String name = 'Test Node',
  AdminLevel adminLevel = AdminLevel.country,
  String? parentId,
  String? colorHex,
  String? geometryJson = kPolygonGeom,
}) {
  return LocationNode(
    id: id,
    osmId: osmId,
    name: name,
    adminLevel: adminLevel,
    parentId: parentId,
    colorHex: colorHex,
    geometryJson: geometryJson,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AdminBoundaryGeoJsonBuilder', () {
    // -----------------------------------------------------------------------
    // emptyFeatureCollection
    // -----------------------------------------------------------------------
    group('emptyFeatureCollection', () {
      test('is a valid empty FeatureCollection', () {
        final parsed = jsonDecode(
          AdminBoundaryGeoJsonBuilder.emptyFeatureCollection,
        ) as Map<String, dynamic>;
        expect(parsed['type'], equals('FeatureCollection'));
        expect(parsed['features'], isEmpty);
      });
    });

    // -----------------------------------------------------------------------
    // buildBoundaryFills
    // -----------------------------------------------------------------------
    group('buildBoundaryFills', () {
      test('empty map returns emptyFeatureCollection', () {
        expect(
          AdminBoundaryGeoJsonBuilder.buildBoundaryFills({}),
          equals(AdminBoundaryGeoJsonBuilder.emptyFeatureCollection),
        );
      });

      test(
          'produces valid FeatureCollection with 3 features (country, state, district)',
          () {
        final nodes = {
          'c': makeNode(
            id: 'c',
            adminLevel: AdminLevel.country,
            name: 'Canada',
          ),
          's': makeNode(
            id: 's',
            adminLevel: AdminLevel.state,
            name: 'New Brunswick',
            parentId: 'c',
          ),
          'd': makeNode(
            id: 'd',
            adminLevel: AdminLevel.district,
            name: 'Fredericton North',
            parentId: 's',
          ),
        };

        final result = AdminBoundaryGeoJsonBuilder.buildBoundaryFills(nodes);
        final parsed = jsonDecode(result) as Map<String, dynamic>;

        expect(parsed['type'], equals('FeatureCollection'));
        final features = parsed['features'] as List;
        expect(features.length, equals(3));

        final levels = features
            .map((f) => (f as Map<String, dynamic>)['properties']['admin_level']
                as String)
            .toSet();
        expect(levels, containsAll(['country', 'state', 'district']));
      });

      test(
          'skips nodes with null geometryJson — no crash, returns empty features',
          () {
        final nodes = {
          'n1': makeNode(id: 'n1', geometryJson: null),
          'n2': makeNode(id: 'n2', geometryJson: null),
        };

        final result = AdminBoundaryGeoJsonBuilder.buildBoundaryFills(nodes);
        final parsed = jsonDecode(result) as Map<String, dynamic>;
        expect((parsed['features'] as List), isEmpty);
      });

      test('mixes null and valid geometry — only valid nodes emitted', () {
        final nodes = {
          'n1': makeNode(id: 'n1', geometryJson: null),
          'n2': makeNode(id: 'n2', adminLevel: AdminLevel.state),
        };

        final result = AdminBoundaryGeoJsonBuilder.buildBoundaryFills(nodes);
        final parsed = jsonDecode(result) as Map<String, dynamic>;
        expect((parsed['features'] as List).length, equals(1));
      });

      test('opacity values are correct per admin level', () {
        final nodes = {
          'c': makeNode(id: 'c', adminLevel: AdminLevel.country),
          's': makeNode(id: 's', adminLevel: AdminLevel.state),
          'ci': makeNode(id: 'ci', adminLevel: AdminLevel.city),
          'd': makeNode(id: 'd', adminLevel: AdminLevel.district),
        };

        final result = AdminBoundaryGeoJsonBuilder.buildBoundaryFills(nodes);
        final parsed = jsonDecode(result) as Map<String, dynamic>;
        final features = parsed['features'] as List;

        final opacityByLevel = <String, double>{
          for (final f in features)
            (f as Map<String, dynamic>)['properties']['admin_level'] as String:
                ((f['properties'] as Map<String, dynamic>)['opacity'] as num)
                    .toDouble(),
        };

        expect(opacityByLevel['country'], closeTo(0.04, 0.001));
        expect(opacityByLevel['state'], closeTo(0.06, 0.001));
        expect(opacityByLevel['city'], closeTo(0.08, 0.001));
        expect(opacityByLevel['district'], closeTo(0.10, 0.001));
      });

      test('geometry is passed through as Polygon type', () {
        final nodes = {'n': makeNode(geometryJson: kPolygonGeom)};
        final result = AdminBoundaryGeoJsonBuilder.buildBoundaryFills(nodes);
        final parsed = jsonDecode(result) as Map<String, dynamic>;
        final geom = (parsed['features'] as List).first['geometry'];
        expect(geom['type'], equals('Polygon'));
      });

      test('geometry is passed through as MultiPolygon type', () {
        final nodes = {'n': makeNode(geometryJson: kMultiPolygonGeom)};
        final result = AdminBoundaryGeoJsonBuilder.buildBoundaryFills(nodes);
        final parsed = jsonDecode(result) as Map<String, dynamic>;
        final geom = (parsed['features'] as List).first['geometry'];
        expect(geom['type'], equals('MultiPolygon'));
      });

      test('output is valid JSON', () {
        final nodes = {'n': makeNode()};
        final result = AdminBoundaryGeoJsonBuilder.buildBoundaryFills(nodes);
        expect(() => jsonDecode(result), returnsNormally);
      });

      test('world and continent level nodes are excluded', () {
        final nodes = {
          'w': makeNode(id: 'w', adminLevel: AdminLevel.world),
          'cont': makeNode(id: 'cont', adminLevel: AdminLevel.continent),
          'country': makeNode(id: 'country', adminLevel: AdminLevel.country),
        };
        final result = AdminBoundaryGeoJsonBuilder.buildBoundaryFills(nodes);
        final parsed = jsonDecode(result) as Map<String, dynamic>;
        // Only country survives
        expect((parsed['features'] as List).length, equals(1));
      });

      // ------- Test 6: color fallback -------
      test('uses colorHex when set', () {
        final nodes = {'n': makeNode(colorHex: '#FF0000')};
        final result = AdminBoundaryGeoJsonBuilder.buildBoundaryFills(nodes);
        final parsed = jsonDecode(result) as Map<String, dynamic>;
        final color =
            (parsed['features'] as List).first['properties']['color'] as String;
        expect(color, equals('#FF0000'));
      });

      test('uses FNV hash when colorHex is null', () {
        final nodes = {'n': makeNode(colorHex: null, osmId: 42)};
        final result = AdminBoundaryGeoJsonBuilder.buildBoundaryFills(nodes);
        final parsed = jsonDecode(result) as Map<String, dynamic>;
        final color =
            (parsed['features'] as List).first['properties']['color'] as String;
        expect(color, startsWith('#'));
        expect(color.length, equals(7));
        expect(color, isNot(equals('#FF0000')));
      });
    });

    // -----------------------------------------------------------------------
    // buildBoundaryLines
    // -----------------------------------------------------------------------
    group('buildBoundaryLines', () {
      test('empty map returns emptyFeatureCollection', () {
        expect(
          AdminBoundaryGeoJsonBuilder.buildBoundaryLines({}),
          equals(AdminBoundaryGeoJsonBuilder.emptyFeatureCollection),
        );
      });

      // ------- Test 3: Polygon → single LineString with exterior ring -------
      test('Polygon produces one LineString feature with exterior ring coords',
          () {
        final nodes = {
          'n': makeNode(
            geometryJson: kPolygonGeom,
            adminLevel: AdminLevel.country,
          ),
        };
        final result = AdminBoundaryGeoJsonBuilder.buildBoundaryLines(nodes);
        final parsed = jsonDecode(result) as Map<String, dynamic>;
        final features = parsed['features'] as List;

        expect(features.length, equals(1));
        final geom =
            (features.first as Map<String, dynamic>)['geometry'] as Map;
        expect(geom['type'], equals('LineString'));
        // Exterior ring has 5 points (closed: first == last)
        expect((geom['coordinates'] as List).length, equals(5));
      });

      // ------- Test 4: MultiPolygon → one LineString per sub-polygon -------
      test('MultiPolygon produces one LineString per sub-polygon exterior ring',
          () {
        final nodes = {
          'n': makeNode(
            geometryJson: kMultiPolygonGeom,
            adminLevel: AdminLevel.country,
          ),
        };
        final result = AdminBoundaryGeoJsonBuilder.buildBoundaryLines(nodes);
        final parsed = jsonDecode(result) as Map<String, dynamic>;
        final features = parsed['features'] as List;

        // 2 sub-polygons → 2 LineString features
        expect(features.length, equals(2));
        for (final f in features) {
          expect(
            (f as Map<String, dynamic>)['geometry']['type'],
            equals('LineString'),
          );
        }
      });

      test('skips nodes with null geometryJson', () {
        final nodes = {'n': makeNode(geometryJson: null)};
        final result = AdminBoundaryGeoJsonBuilder.buildBoundaryLines(nodes);
        final parsed = jsonDecode(result) as Map<String, dynamic>;
        expect((parsed['features'] as List), isEmpty);
      });

      test('correct line_weight per admin level', () {
        final nodes = {
          'c': makeNode(id: 'c', adminLevel: AdminLevel.country),
          's': makeNode(id: 's', adminLevel: AdminLevel.state),
          'ci': makeNode(id: 'ci', adminLevel: AdminLevel.city),
          'd': makeNode(id: 'd', adminLevel: AdminLevel.district),
        };

        final result = AdminBoundaryGeoJsonBuilder.buildBoundaryLines(nodes);
        final parsed = jsonDecode(result) as Map<String, dynamic>;
        final features = parsed['features'] as List;

        final weightByLevel = <String, double>{
          for (final f in features)
            (f as Map<String, dynamic>)['properties']['admin_level'] as String:
                ((f['properties'] as Map<String, dynamic>)['line_weight']
                        as num)
                    .toDouble(),
        };

        expect(
            weightByLevel['country'], closeTo(kBorderLineWeightCountry, 0.001));
        expect(weightByLevel['state'], closeTo(kBorderLineWeightState, 0.001));
        expect(weightByLevel['city'], closeTo(kBorderLineWeightCity, 0.001));
        expect(weightByLevel['district'],
            closeTo(kBorderLineWeightDistrict, 0.001));
      });

      test('output is valid JSON', () {
        final nodes = {'n': makeNode(geometryJson: kMultiPolygonGeom)};
        final result = AdminBoundaryGeoJsonBuilder.buildBoundaryLines(nodes);
        expect(() => jsonDecode(result), returnsNormally);
      });
    });

    // -----------------------------------------------------------------------
    // Test 5: empty map → emptyFeatureCollection (both methods)
    // -----------------------------------------------------------------------
    group('empty map input', () {
      test('buildBoundaryFills returns emptyFeatureCollection', () {
        expect(
          AdminBoundaryGeoJsonBuilder.buildBoundaryFills({}),
          equals(AdminBoundaryGeoJsonBuilder.emptyFeatureCollection),
        );
      });

      test('buildBoundaryLines returns emptyFeatureCollection', () {
        expect(
          AdminBoundaryGeoJsonBuilder.buildBoundaryLines({}),
          equals(AdminBoundaryGeoJsonBuilder.emptyFeatureCollection),
        );
      });
    });

    // -----------------------------------------------------------------------
    // Test 6: color resolution
    // -----------------------------------------------------------------------
    group('color resolution', () {
      test('colorHex takes precedence over FNV hash', () {
        final withColor = makeNode(colorHex: '#ABCDEF', osmId: 999);
        final withoutColor = makeNode(colorHex: null, osmId: 999);

        String getColor(LocationNode n) {
          final result =
              AdminBoundaryGeoJsonBuilder.buildBoundaryFills({'n': n});
          return (jsonDecode(result)['features'] as List).first['properties']
              ['color'] as String;
        }

        expect(getColor(withColor), equals('#ABCDEF'));
        expect(getColor(withoutColor), isNot(equals('#ABCDEF')));
        expect(getColor(withoutColor), startsWith('#'));
        expect(getColor(withoutColor).length, equals(7));
      });

      test('FNV hash is deterministic — same osmId yields same color', () {
        final n1 = makeNode(id: 'a', colorHex: null, osmId: 12345);
        final n2 = makeNode(id: 'b', colorHex: null, osmId: 12345);

        String getColor(LocationNode n) {
          final result =
              AdminBoundaryGeoJsonBuilder.buildBoundaryFills({'n': n});
          return (jsonDecode(result)['features'] as List).first['properties']
              ['color'] as String;
        }

        expect(getColor(n1), equals(getColor(n2)));
      });

      test('FNV hash differs for different osmIds', () {
        final n1 = makeNode(id: 'a', colorHex: null, osmId: 111);
        final n2 = makeNode(id: 'b', colorHex: null, osmId: 222);

        String getColor(LocationNode n) {
          final result =
              AdminBoundaryGeoJsonBuilder.buildBoundaryFills({'n': n});
          return (jsonDecode(result)['features'] as List).first['properties']
              ['color'] as String;
        }

        // Very unlikely to collide for different osmIds
        expect(getColor(n1), isNot(equals(getColor(n2))));
      });

      test('color appears in buildBoundaryLines features', () {
        final nodes = {
          'n': makeNode(colorHex: '#123456'),
        };
        final result = AdminBoundaryGeoJsonBuilder.buildBoundaryLines(nodes);
        final parsed = jsonDecode(result) as Map<String, dynamic>;
        final color =
            (parsed['features'] as List).first['properties']['color'] as String;
        expect(color, equals('#123456'));
      });
    });

    // -----------------------------------------------------------------------
    // Edge cases
    // -----------------------------------------------------------------------
    group('edge cases', () {
      test('name with double-quote is escaped in fills', () {
        final nodes = {
          'n': makeNode(name: 'O"Brien County'),
        };
        final result = AdminBoundaryGeoJsonBuilder.buildBoundaryFills(nodes);
        // Must be parseable JSON despite the embedded quote
        expect(() => jsonDecode(result), returnsNormally);
        final parsed = jsonDecode(result) as Map<String, dynamic>;
        final name =
            (parsed['features'] as List).first['properties']['name'] as String;
        expect(name, equals('O"Brien County'));
      });

      test('name with backslash is escaped in lines', () {
        final nodes = {
          'n': makeNode(name: r'North\South'),
        };
        final result = AdminBoundaryGeoJsonBuilder.buildBoundaryLines(nodes);
        expect(() => jsonDecode(result), returnsNormally);
        final parsed = jsonDecode(result) as Map<String, dynamic>;
        final name =
            (parsed['features'] as List).first['properties']['name'] as String;
        expect(name, equals(r'North\South'));
      });
    });
  });
}
