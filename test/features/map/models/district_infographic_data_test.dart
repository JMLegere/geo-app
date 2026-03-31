import 'package:flutter_test/flutter_test.dart';
import 'package:geobase/geobase.dart';
import 'package:earth_nova/features/map/models/district_infographic_data.dart';

DistrictInfographicData _makeData({
  String districtName = 'Test District',
  String districtId = 'test_001',
  List<List<Geographic>> boundaryRings = const [],
  List<String> allCellIds = const [],
  Set<String> exploredCellIds = const {},
  Map<String, List<Geographic>> exploredCellBoundaries = const {},
  double playerLat = 45.0,
  double playerLon = -66.0,
  int totalSpeciesFound = 0,
  double minLat = 44.9,
  double maxLat = 45.1,
  double minLon = -66.1,
  double maxLon = -65.9,
}) {
  return DistrictInfographicData(
    districtName: districtName,
    districtId: districtId,
    boundaryRings: boundaryRings,
    allCellIds: allCellIds,
    exploredCellIds: exploredCellIds,
    exploredCellBoundaries: exploredCellBoundaries,
    playerLat: playerLat,
    playerLon: playerLon,
    totalSpeciesFound: totalSpeciesFound,
    minLat: minLat,
    maxLat: maxLat,
    minLon: minLon,
    maxLon: maxLon,
  );
}

void main() {
  group('DistrictInfographicData', () {
    group('explorationPercent', () {
      test('returns 0.0 when allCellIds is empty', () {
        final data = _makeData(allCellIds: [], exploredCellIds: {});
        expect(data.explorationPercent, 0.0);
      });

      test('returns 0.0 when no cells explored', () {
        final data = _makeData(
          allCellIds: ['a', 'b', 'c', 'd', 'e'],
          exploredCellIds: {},
        );
        expect(data.explorationPercent, 0.0);
      });

      test('returns 1.0 when all cells explored', () {
        final data = _makeData(
          allCellIds: ['a', 'b', 'c'],
          exploredCellIds: {'a', 'b', 'c'},
        );
        expect(data.explorationPercent, 1.0);
      });

      test('returns correct fraction for partial exploration', () {
        final data = _makeData(
          allCellIds: ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j'],
          exploredCellIds: {'a', 'b', 'c'},
        );
        expect(data.explorationPercent, closeTo(0.3, 1e-10));
      });
    });

    group('hasBoundary', () {
      test('returns false when boundaryRings is empty', () {
        final data = _makeData(boundaryRings: []);
        expect(data.hasBoundary, isFalse);
      });

      test('returns true when boundaryRings has rings', () {
        final ring = [
          Geographic(lat: 45.0, lon: -66.0),
          Geographic(lat: 45.1, lon: -66.0),
          Geographic(lat: 45.1, lon: -65.9),
          Geographic(lat: 45.0, lon: -66.0),
        ];
        final data = _makeData(boundaryRings: [ring]);
        expect(data.hasBoundary, isTrue);
      });
    });

    group('parseBoundaryRings', () {
      test('returns empty list for null input', () {
        expect(DistrictInfographicData.parseBoundaryRings(null), isEmpty);
      });

      test('returns empty list for empty string', () {
        expect(DistrictInfographicData.parseBoundaryRings(''), isEmpty);
      });

      test('returns empty list for invalid JSON', () {
        expect(
          DistrictInfographicData.parseBoundaryRings('not json'),
          isEmpty,
        );
      });

      test('returns empty list when coordinates is null', () {
        const json = '{"type":"Polygon","coordinates":null}';
        expect(DistrictInfographicData.parseBoundaryRings(json), isEmpty);
      });

      test('parses Polygon with single ring', () {
        // GeoJSON coordinates are [longitude, latitude]
        const json = '''
{
  "type": "Polygon",
  "coordinates": [
    [
      [-66.1, 44.9],
      [-65.9, 44.9],
      [-65.9, 45.1],
      [-66.1, 45.1],
      [-66.1, 44.9]
    ]
  ]
}''';
        final rings = DistrictInfographicData.parseBoundaryRings(json);
        expect(rings, hasLength(1));
        expect(rings[0], hasLength(5));
        // First point: lon=-66.1, lat=44.9
        expect(rings[0][0].lat, closeTo(44.9, 1e-10));
        expect(rings[0][0].lon, closeTo(-66.1, 1e-10));
        // Third point: lon=-65.9, lat=45.1
        expect(rings[0][2].lat, closeTo(45.1, 1e-10));
        expect(rings[0][2].lon, closeTo(-65.9, 1e-10));
      });

      test('parses Polygon with multiple rings', () {
        // Outer ring + hole ring
        const json = '''
{
  "type": "Polygon",
  "coordinates": [
    [
      [-66.1, 44.9],
      [-65.9, 44.9],
      [-65.9, 45.1],
      [-66.1, 44.9]
    ],
    [
      [-66.0, 44.95],
      [-65.95, 44.95],
      [-65.95, 45.0],
      [-66.0, 44.95]
    ]
  ]
}''';
        final rings = DistrictInfographicData.parseBoundaryRings(json);
        expect(rings, hasLength(2));
      });

      test('parses MultiPolygon', () {
        const json = '''
{
  "type": "MultiPolygon",
  "coordinates": [
    [
      [
        [-66.1, 44.9],
        [-65.9, 44.9],
        [-65.9, 45.1],
        [-66.1, 44.9]
      ]
    ],
    [
      [
        [-67.0, 45.0],
        [-66.8, 45.0],
        [-66.8, 45.2],
        [-67.0, 45.0]
      ]
    ]
  ]
}''';
        final rings = DistrictInfographicData.parseBoundaryRings(json);
        expect(rings, hasLength(2));
        // Verify second polygon parsed correctly
        expect(rings[1][0].lon, closeTo(-67.0, 1e-10));
        expect(rings[1][0].lat, closeTo(45.0, 1e-10));
      });

      test('skips rings with fewer than 3 coordinates', () {
        const json = '''
{
  "type": "Polygon",
  "coordinates": [
    [
      [-66.1, 44.9],
      [-65.9, 44.9]
    ],
    [
      [-66.0, 45.0],
      [-65.9, 45.0],
      [-65.9, 45.1],
      [-66.0, 45.0]
    ]
  ]
}''';
        final rings = DistrictInfographicData.parseBoundaryRings(json);
        // Only the second ring (4 points) should be included
        expect(rings, hasLength(1));
        expect(rings[0], hasLength(4));
      });

      test('returns empty list for unknown geometry type', () {
        const json = '{"type":"Point","coordinates":[0,0]}';
        expect(DistrictInfographicData.parseBoundaryRings(json), isEmpty);
      });
    });
  });
}
