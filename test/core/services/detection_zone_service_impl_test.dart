import 'package:earth_nova/core/cells/cell_service.dart';
import 'package:earth_nova/core/models/location_node.dart';
import 'package:earth_nova/core/persistence/location_node_repository.dart';
import 'package:earth_nova/core/services/detection_zone_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geobase/geobase.dart';

// ─── Mocks ───────────────────────────────────────────────────────────────────

class MockCellService implements CellService {
  final Map<String, Geographic> _centers = {};
  final Map<String, List<String>> _neighbors = {};

  void setCenter(String cellId, double lat, double lon) {
    _centers[cellId] = Geographic(lat: lat, lon: lon);
  }

  void setNeighbors(String cellId, List<String> neighborIds) {
    _neighbors[cellId] = neighborIds;
  }

  @override
  String getCellId(double lat, double lon) {
    double minDist = double.infinity;
    String nearestId = '';
    for (final entry in _centers.entries) {
      final d = (entry.value.lat - lat) * (entry.value.lat - lat) +
          (entry.value.lon - lon) * (entry.value.lon - lon);
      if (d < minDist) {
        minDist = d;
        nearestId = entry.key;
      }
    }
    return nearestId;
  }

  @override
  Geographic getCellCenter(String cellId) =>
      _centers[cellId] ?? Geographic(lat: 0, lon: 0);

  @override
  List<Geographic> getCellBoundary(String cellId) => [];

  @override
  List<String> getNeighborIds(String cellId) => _neighbors[cellId] ?? [];

  @override
  List<String> getCellsInRing(String cellId, int k) => [cellId];

  @override
  List<String> getCellsAroundLocation(double lat, double lon, int k) =>
      [getCellId(lat, lon)];

  @override
  double get cellEdgeLengthMeters => 180.0;

  @override
  String get systemName => 'Mock';
}

class MockLocationNodeRepository implements LocationNodeRepository {
  final Map<String, LocationNode> _nodes = {};
  int upsertCount = 0;

  void addNode(LocationNode node) => _nodes[node.id] = node;

  @override
  Future<LocationNode?> get(String id) async => _nodes[id];

  @override
  Future<LocationNode?> getByOsmId(int osmId) async =>
      _nodes.values.where((n) => n.osmId == osmId).firstOrNull;

  @override
  Future<void> upsert(LocationNode node) async {
    _nodes[node.id] = node;
    upsertCount++;
  }

  @override
  Future<List<LocationNode>> getChildren(String parentId) async =>
      _nodes.values.where((n) => n.parentId == parentId).toList();

  @override
  Future<List<LocationNode>> getAll() async => _nodes.values.toList();
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

String makeSquare(double minLat, double minLon, double maxLat, double maxLon) {
  return '{"type":"Polygon","coordinates":[[[$minLon,$minLat],[$maxLon,$minLat],[$maxLon,$maxLat],[$minLon,$maxLat],[$minLon,$minLat]]]}';
}

LocationNode makeDistrict(
  String id,
  String name, {
  String? geometryJson,
  List<String>? adjacentLocationIds,
  List<String>? cellIds,
}) {
  return LocationNode(
    id: id,
    osmId: null,
    name: name,
    adminLevel: AdminLevel.district,
    parentId: null,
    colorHex: null,
    geometryJson: geometryJson,
    adjacentLocationIds: adjacentLocationIds,
    cellIds: cellIds,
  );
}

/// Create a grid of cells. Each cell v_{row}_{col} has center at
/// (baseLat + row*0.002, baseLon + col*0.002).
void buildGrid(
  MockCellService cs, {
  int rows = 10,
  int cols = 10,
  double baseLat = 45.0,
  double baseLon = -66.0,
}) {
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      final id = 'v_${r}_$c';
      cs.setCenter(id, baseLat + r * 0.002, baseLon + c * 0.002);
      cs.setNeighbors(id, [
        if (r > 0) 'v_${r - 1}_$c',
        if (r < rows - 1) 'v_${r + 1}_$c',
        if (c > 0) 'v_${r}_${c - 1}',
        if (c < cols - 1) 'v_${r}_${c + 1}',
      ]);
    }
  }
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  late MockCellService cellService;
  late MockLocationNodeRepository repo;
  late DetectionZoneService service;

  setUp(() {
    cellService = MockCellService();
    repo = MockLocationNodeRepository();
    service = DetectionZoneService(
      cellService: cellService,
      locationNodeRepo: repo,
    );
  });

  tearDown(() => service.dispose());

  // ═══════════════════════════════════════════════════════════════════════════
  // computeCellIdsForDistrict
  // ═══════════════════════════════════════════════════════════════════════════

  group('computeCellIdsForDistrict', () {
    test('returns empty for unknown district id', () async {
      final result = await service.computeCellIdsForDistrict('nope');
      expect(result, isEmpty);
    });

    test('returns empty for null geometry', () async {
      repo.addNode(makeDistrict('d1', 'D1'));
      final result = await service.computeCellIdsForDistrict('d1');
      expect(result, isEmpty);
    });

    test('returns empty for invalid JSON geometry', () async {
      repo.addNode(makeDistrict('d1', 'D1', geometryJson: '{bad json'));
      final result = await service.computeCellIdsForDistrict('d1');
      expect(result, isEmpty);
    });

    test('returns empty for unsupported geometry type', () async {
      repo.addNode(makeDistrict('d1', 'D1',
          geometryJson: '{"type":"Point","coordinates":[-66,45]}'));
      final result = await service.computeCellIdsForDistrict('d1');
      expect(result, isEmpty);
    });

    test('returns empty for empty coordinates', () async {
      repo.addNode(makeDistrict('d1', 'D1',
          geometryJson: '{"type":"Polygon","coordinates":[[]]}'));
      final result = await service.computeCellIdsForDistrict('d1');
      expect(result, isEmpty);
    });

    test('finds cells inside a simple square polygon', () async {
      buildGrid(cellService, rows: 20, cols: 20);
      // Polygon covers rows 3-7, cols 3-7 (center lat 45.006–45.014, lon -65.994–-65.986)
      final geo = makeSquare(45.005, -65.995, 45.015, -65.985);
      repo.addNode(makeDistrict('d1', 'D1', geometryJson: geo));

      final result = await service.computeCellIdsForDistrict('d1');

      expect(result, isNotEmpty);
      // Every returned cell center must be inside the polygon
      for (final cellId in result) {
        final c = cellService.getCellCenter(cellId);
        expect(c.lat, greaterThanOrEqualTo(45.005));
        expect(c.lat, lessThanOrEqualTo(45.015));
        expect(c.lon, greaterThanOrEqualTo(-65.995));
        expect(c.lon, lessThanOrEqualTo(-65.985));
      }
    });

    test('finds cells inside MultiPolygon (two disjoint squares)', () async {
      buildGrid(cellService, rows: 30, cols: 30);
      // Two disjoint squares
      final geo = '''
      {"type":"MultiPolygon","coordinates":[
        [[[-65.995,45.005],[-65.985,45.005],[-65.985,45.015],[-65.995,45.015],[-65.995,45.005]]],
        [[[-65.975,45.025],[-65.965,45.025],[-65.965,45.035],[-65.975,45.035],[-65.975,45.025]]]
      ]}''';
      repo.addNode(makeDistrict('d1', 'D1', geometryJson: geo));

      final result = await service.computeCellIdsForDistrict('d1');
      expect(result, isNotEmpty);

      // Verify there are cells in both lat ranges
      final lats = result.map((id) => cellService.getCellCenter(id).lat);
      final hasLow = lats.any((lat) => lat < 45.02);
      final hasHigh = lats.any((lat) => lat > 45.02);
      expect(hasLow, isTrue, reason: 'Should have cells in first polygon');
      expect(hasHigh, isTrue, reason: 'Should have cells in second polygon');
    });

    test('caches computed cellIds on LocationNode via upsert', () async {
      buildGrid(cellService, rows: 10, cols: 10);
      final geo = makeSquare(45.005, -65.995, 45.015, -65.985);
      repo.addNode(makeDistrict('d1', 'D1', geometryJson: geo));

      expect(repo.upsertCount, 0);
      final result1 = await service.computeCellIdsForDistrict('d1');
      expect(result1, isNotEmpty);
      expect(repo.upsertCount, 1);

      // Verify the node now has cellIds cached
      final updatedNode = await repo.get('d1');
      expect(updatedNode!.cellIds, isNotEmpty);
      expect(updatedNode.cellIds!.toSet(), equals(result1));
    });

    test('returns cached cellIds without recomputing', () async {
      buildGrid(cellService, rows: 10, cols: 10);
      final cached = ['v_5_5', 'v_5_6', 'v_6_5'];
      repo.addNode(makeDistrict('d1', 'D1',
          geometryJson: makeSquare(45.0, -66.0, 45.02, -65.98),
          cellIds: cached));

      final result = await service.computeCellIdsForDistrict('d1');
      expect(result, equals(cached.toSet()));
      // No upsert because it used cached data
      expect(repo.upsertCount, 0);
    });

    test('does not cache when polygon contains no cells', () async {
      // Tiny polygon, no cell centers inside
      buildGrid(cellService, rows: 5, cols: 5, baseLat: 0, baseLon: 0);
      final geo = makeSquare(99.0, 99.0, 99.001, 99.001);
      repo.addNode(makeDistrict('d1', 'D1', geometryJson: geo));

      final result = await service.computeCellIdsForDistrict('d1');
      expect(result, isEmpty);
      expect(repo.upsertCount, 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // onDistrictChange
  // ═══════════════════════════════════════════════════════════════════════════

  group('onDistrictChange', () {
    test('updates currentDistrictId', () async {
      repo.addNode(makeDistrict('d1', 'D1'));
      await service.onDistrictChange('d1');
      expect(service.currentDistrictId, 'd1');
    });

    test('no-ops for same district', () async {
      buildGrid(cellService, rows: 10, cols: 10);
      final geo = makeSquare(45.005, -65.995, 45.015, -65.985);
      repo.addNode(makeDistrict('d1', 'D1', geometryJson: geo));

      await service.onDistrictChange('d1');
      final zone1 = service.detectionZoneCellIds;

      repo.upsertCount = 0;
      await service.onDistrictChange('d1');
      // Should NOT recompute
      expect(repo.upsertCount, 0);
      expect(service.detectionZoneCellIds, equals(zone1));
    });

    test('includes cells from adjacent districts', () async {
      buildGrid(cellService, rows: 30, cols: 10);
      // District 1: rows 3-7
      final geo1 = makeSquare(45.005, -65.995, 45.015, -65.985);
      // District 2: rows 13-17
      final geo2 = makeSquare(45.025, -65.995, 45.035, -65.985);

      repo.addNode(makeDistrict('d1', 'D1',
          geometryJson: geo1, adjacentLocationIds: ['d2']));
      repo.addNode(makeDistrict('d2', 'D2', geometryJson: geo2));

      await service.onDistrictChange('d1');

      final zone = service.detectionZoneCellIds;
      expect(zone, isNotEmpty);

      // Should contain cells from both districts
      final lats = zone.map((id) => cellService.getCellCenter(id).lat);
      final hasD1 = lats.any((lat) => lat >= 45.005 && lat <= 45.015);
      final hasD2 = lats.any((lat) => lat >= 45.025 && lat <= 45.035);
      expect(hasD1, isTrue, reason: 'Zone should include current district');
      expect(hasD2, isTrue, reason: 'Zone should include adjacent district');
    });

    test('emits on onDetectionZoneChanged stream', () async {
      buildGrid(cellService, rows: 10, cols: 10);
      final geo = makeSquare(45.005, -65.995, 45.015, -65.985);
      repo.addNode(makeDistrict('d1', 'D1', geometryJson: geo));

      Set<String>? emitted;
      service.onDetectionZoneChanged.listen((zone) => emitted = zone);

      await service.onDistrictChange('d1');
      // Allow microtask queue to flush the stream event
      await Future<void>.delayed(Duration.zero);

      expect(emitted, isNotNull);
      expect(emitted, isNotEmpty);
      expect(emitted, equals(service.detectionZoneCellIds));
    });

    test('switching districts replaces zone entirely', () async {
      buildGrid(cellService, rows: 30, cols: 10);
      final geo1 = makeSquare(45.005, -65.995, 45.015, -65.985);
      final geo2 = makeSquare(45.025, -65.995, 45.035, -65.985);

      repo.addNode(makeDistrict('d1', 'D1', geometryJson: geo1));
      repo.addNode(makeDistrict('d2', 'D2', geometryJson: geo2));

      await service.onDistrictChange('d1');
      final zone1 = Set<String>.from(service.detectionZoneCellIds);

      await service.onDistrictChange('d2');
      final zone2 = service.detectionZoneCellIds;

      // Zones should be different — d2 cells, not d1 cells
      expect(zone2, isNot(equals(zone1)));
      expect(service.currentDistrictId, 'd2');
    });

    test('handles adjacent district with no geometry gracefully', () async {
      buildGrid(cellService, rows: 10, cols: 10);
      final geo = makeSquare(45.005, -65.995, 45.015, -65.985);

      repo.addNode(makeDistrict('d1', 'D1',
          geometryJson: geo, adjacentLocationIds: ['d2']));
      repo.addNode(makeDistrict('d2', 'D2')); // No geometry

      await service.onDistrictChange('d1');
      // Should not crash — zone only contains d1 cells
      expect(service.detectionZoneCellIds, isNotEmpty);
    });

    test('handles adjacent district that does not exist', () async {
      buildGrid(cellService, rows: 10, cols: 10);
      final geo = makeSquare(45.005, -65.995, 45.015, -65.985);

      repo.addNode(makeDistrict('d1', 'D1',
          geometryJson: geo, adjacentLocationIds: ['nonexistent']));

      await service.onDistrictChange('d1');
      // Should not crash — zone only contains d1 cells
      expect(service.detectionZoneCellIds, isNotEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GeoJSON parsing edge cases
  // ═══════════════════════════════════════════════════════════════════════════

  group('GeoJSON parsing', () {
    test('handles GeoJSON with integer coordinates', () async {
      buildGrid(cellService, rows: 10, cols: 10);
      // Integer coords (not doubles)
      const geo =
          '{"type":"Polygon","coordinates":[[[-66,45],[-65,45],[-65,46],[-66,46],[-66,45]]]}';
      repo.addNode(makeDistrict('d1', 'D1', geometryJson: geo));

      final result = await service.computeCellIdsForDistrict('d1');
      expect(result, isNotEmpty);
    });

    test('handles polygon with holes (uses outer ring only)', () async {
      buildGrid(cellService, rows: 20, cols: 20);
      // Polygon with a hole — outer ring is large, inner ring is small
      const geo = '''
      {"type":"Polygon","coordinates":[
        [[-66,45],[-65.96,45],[-65.96,45.04],[-66,45.04],[-66,45]],
        [[-65.99,45.01],[-65.98,45.01],[-65.98,45.02],[-65.99,45.02],[-65.99,45.01]]
      ]}''';
      repo.addNode(makeDistrict('d1', 'D1', geometryJson: geo));

      // Should find cells in the outer ring (holes are not subtracted since
      // we only parse coordinates[0])
      final result = await service.computeCellIdsForDistrict('d1');
      expect(result, isNotEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // dispose safety
  // ═══════════════════════════════════════════════════════════════════════════

  group('dispose', () {
    test('does not emit after dispose', () async {
      buildGrid(cellService, rows: 10, cols: 10);
      final geo = makeSquare(45.005, -65.995, 45.015, -65.985);
      repo.addNode(makeDistrict('d1', 'D1', geometryJson: geo));
      repo.addNode(makeDistrict('d2', 'D2', geometryJson: geo));

      service.dispose();

      // Should not crash
      await service.onDistrictChange('d1');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // detectionZoneCellIds immutability
  // ═══════════════════════════════════════════════════════════════════════════

  group('immutability', () {
    test('detectionZoneCellIds returns unmodifiable set', () async {
      buildGrid(cellService, rows: 10, cols: 10);
      final geo = makeSquare(45.005, -65.995, 45.015, -65.985);
      repo.addNode(makeDistrict('d1', 'D1', geometryJson: geo));

      await service.onDistrictChange('d1');
      final zone = service.detectionZoneCellIds;

      expect(
        () => zone.add('hacked'),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
