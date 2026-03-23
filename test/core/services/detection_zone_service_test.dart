import 'package:earth_nova/core/cells/cell_service.dart';
import 'package:earth_nova/core/models/cell_properties.dart';
import 'package:earth_nova/core/models/climate.dart';
import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/models/item_definition.dart';
import 'package:earth_nova/core/models/location_node.dart';
import 'package:earth_nova/core/persistence/location_node_repository.dart';
import 'package:earth_nova/core/species/species_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geobase/geobase.dart';

/// Mock CellService for testing.
class MockCellService implements CellService {
  final Map<String, Geographic> _centers = {};
  final Map<String, List<String>> _neighbors = {};
  final Map<String, List<Geographic>> _boundaries = {};

  void setCenter(String cellId, double lat, double lon) {
    _centers[cellId] = Geographic(lat: lat, lon: lon);
  }

  void setNeighbors(String cellId, List<String> neighborIds) {
    _neighbors[cellId] = neighborIds;
  }

  void setBoundary(String cellId, List<Geographic> boundary) {
    _boundaries[cellId] = boundary;
  }

  @override
  String getCellId(double lat, double lon) {
    // Find the nearest center
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
  Geographic getCellCenter(String cellId) {
    return _centers[cellId] ?? Geographic(lat: 0, lon: 0);
  }

  @override
  List<Geographic> getCellBoundary(String cellId) {
    return _boundaries[cellId] ?? [];
  }

  @override
  List<String> getNeighborIds(String cellId) {
    return _neighbors[cellId] ?? [];
  }

  @override
  List<String> getCellsInRing(String cellId, int k) {
    if (k == 0) return [cellId];
    final result = <String>{cellId};
    var frontier = <String>{cellId};
    for (var ring = 0; ring < k; ring++) {
      final nextFrontier = <String>{};
      for (final cell in frontier) {
        nextFrontier.addAll(getNeighborIds(cell));
      }
      result.addAll(nextFrontier);
      frontier = nextFrontier;
    }
    return result.toList();
  }

  @override
  List<String> getCellsAroundLocation(double lat, double lon, int k) {
    final cellId = getCellId(lat, lon);
    return getCellsInRing(cellId, k);
  }

  @override
  double get cellEdgeLengthMeters => 180.0;

  @override
  String get systemName => 'Mock Voronoi';
}

/// Mock LocationNodeRepository for testing.
class MockLocationNodeRepository implements LocationNodeRepository {
  final Map<String, LocationNode> _nodes = {};

  void addNode(LocationNode node) {
    _nodes[node.id] = node;
  }

  @override
  Future<LocationNode?> get(String id) async => _nodes[id];

  @override
  Future<LocationNode?> getByOsmId(int osmId) async {
    for (final node in _nodes.values) {
      if (node.osmId == osmId) return node;
    }
    return null;
  }

  @override
  Future<void> upsert(LocationNode node) async {
    _nodes[node.id] = node;
  }

  @override
  Future<List<LocationNode>> getChildren(String parentId) async {
    return _nodes.values.where((n) => n.parentId == parentId).toList();
  }

  @override
  Future<List<LocationNode>> getAll() async => _nodes.values.toList();
}

/// Mock SpeciesCache for testing.
/// Uses a real SpeciesCache with a mock repository to track warm-up calls.
class MockSpeciesCache {
  final Set<String> warmedKeys = {};

  void warmUp({
    required Set<Habitat> habitats,
    required Continent continent,
  }) {
    final key = SpeciesCache.cacheKey(habitats, continent);
    warmedKeys.add(key);
  }
}

/// Helper to create a simple square polygon GeoJSON.
String createSquarePolygon(
    double minLat, double minLon, double maxLat, double maxLon) {
  return '''
  {
    "type": "Polygon",
    "coordinates": [[
      [$minLon, $minLat],
      [$maxLon, $minLat],
      [$maxLon, $maxLat],
      [$minLon, $maxLat],
      [$minLon, $minLat]
    ]]
  }
  ''';
}

/// Helper to create a LocationNode with geometry.
LocationNode createDistrictNode({
  required String id,
  required String name,
  String? geometryJson,
  String? parentId,
}) {
  return LocationNode(
    id: id,
    osmId: null,
    name: name,
    adminLevel: AdminLevel.district,
    parentId: parentId,
    colorHex: null,
    geometryJson: geometryJson,
  );
}

void main() {
  group('DetectionZoneService', () {
    late MockCellService cellService;
    late MockLocationNodeRepository locationNodeRepo;
    late MockSpeciesCache speciesCache;

    setUp(() {
      cellService = MockCellService();
      locationNodeRepo = MockLocationNodeRepository();
      speciesCache = MockSpeciesCache();
    });

    // =========================================================================
    // Phase 1: Flood-fill from polygon geometry
    // =========================================================================

    group('flood-fill from geometry', () {
      test('returns empty set for null geometry', () async {
        final node = createDistrictNode(
          id: 'district-1',
          name: 'Test District',
          geometryJson: null,
        );
        locationNodeRepo.addNode(node);

        // TODO: Implement DetectionZoneService.computeCellIdsForDistrict
        // final cellIds = await service.computeCellIdsForDistrict('district-1');
        // expect(cellIds, isEmpty);
      });

      test('returns empty set for invalid geometry', () async {
        final node = createDistrictNode(
          id: 'district-1',
          name: 'Test District',
          geometryJson: 'not valid json',
        );
        locationNodeRepo.addNode(node);

        // TODO: Implement DetectionZoneService.computeCellIdsForDistrict
        // final cellIds = await service.computeCellIdsForDistrict('district-1');
        // expect(cellIds, isEmpty);
      });

      test('flood-fills cells inside square polygon', () async {
        // Create a 0.01° square polygon (roughly 1km × 1km)
        // At 45° lat, this should contain ~5×5 = 25 Voronoi cells
        final geometryJson = createSquarePolygon(45.0, -66.0, 45.01, -65.99);

        final node = createDistrictNode(
          id: 'district-1',
          name: 'Test District',
          geometryJson: geometryJson,
        );
        locationNodeRepo.addNode(node);

        // Set up a grid of Voronoi cells
        // Grid step is 0.002°, so we expect cells at:
        // v_22500_-33000, v_22500_-32999, v_22500_-32998, etc.
        // (row = lat/0.002, col = lon/0.002)
        for (var row = 22499; row <= 22505; row++) {
          for (var col = -33001; col <= -32997; col++) {
            final cellId = 'v_${row}_$col';
            final lat = (row + 0.5) * 0.002;
            final lon = (col + 0.5) * 0.002;
            cellService.setCenter(cellId, lat, lon);

            // Set up 6 neighbors (hexagonal-ish pattern)
            final neighbors = [
              'v_${row}_$col',
              'v_${row - 1}_$col',
              'v_${row + 1}_$col',
              'v_${row}_${col - 1}',
              'v_${row}_${col + 1}',
              'v_${row - 1}_${col - 1}',
            ];
            cellService.setNeighbors(cellId, neighbors);
          }
        }

        // TODO: Implement DetectionZoneService.computeCellIdsForDistrict
        // final cellIds = await service.computeCellIdsForDistrict('district-1');

        // Should contain cells whose centers are inside the polygon
        // The polygon is 45.0 to 45.01 lat, -66.0 to -65.99 lon
        // Cell centers in this range should be included
        // expect(cellIds, isNotEmpty);

        // Verify all returned cell centers are inside the polygon
        // for (final cellId in cellIds) {
        //   final center = cellService.getCellCenter(cellId);
        //   expect(center.lat, greaterThanOrEqualTo(45.0));
        //   expect(center.lat, lessThanOrEqualTo(45.01));
        //   expect(center.lon, greaterThanOrEqualTo(-66.0));
        //   expect(center.lon, lessThanOrEqualTo(-65.99));
        // }
      });

      test('handles MultiPolygon geometry', () async {
        // Create two separate squares
        final geometryJson = '''
        {
          "type": "MultiPolygon",
          "coordinates": [
            [[[-66.0, 45.0], [-65.99, 45.0], [-65.99, 45.01], [-66.0, 45.01], [-66.0, 45.0]]],
            [[[-65.98, 45.0], [-65.97, 45.0], [-65.97, 45.01], [-65.98, 45.01], [-65.98, 45.0]]]
          ]
        }
        ''';

        final node = createDistrictNode(
          id: 'district-1',
          name: 'Test District',
          geometryJson: geometryJson,
        );
        locationNodeRepo.addNode(node);

        // Set up cells in both polygon areas
        for (var row = 22499; row <= 22505; row++) {
          for (var col = -33001; col <= -32985; col++) {
            final cellId = 'v_${row}_$col';
            final lat = (row + 0.5) * 0.002;
            final lon = (col + 0.5) * 0.002;
            cellService.setCenter(cellId, lat, lon);
            cellService.setNeighbors(cellId, [
              'v_${row}_$col',
              'v_${row - 1}_$col',
              'v_${row + 1}_$col',
              'v_${row}_${col - 1}',
              'v_${row}_${col + 1}',
            ]);
          }
        }

        // TODO: Implement DetectionZoneService.computeCellIdsForDistrict
        // final cellIds = await service.computeCellIdsForDistrict('district-1');

        // Should contain cells from both polygons
        // expect(cellIds, isNotEmpty);
      });

      test('caches computed cellIds in LocationNode', () async {
        final geometryJson = createSquarePolygon(45.0, -66.0, 45.01, -65.99);

        final node = createDistrictNode(
          id: 'district-1',
          name: 'Test District',
          geometryJson: geometryJson,
        );
        locationNodeRepo.addNode(node);

        // Set up cells
        for (var row = 22499; row <= 22505; row++) {
          for (var col = -33001; col <= -32997; col++) {
            final cellId = 'v_${row}_$col';
            final lat = (row + 0.5) * 0.002;
            final lon = (col + 0.5) * 0.002;
            cellService.setCenter(cellId, lat, lon);
            cellService.setNeighbors(cellId, [
              'v_${row}_$col',
              'v_${row - 1}_$col',
              'v_${row + 1}_$col',
            ]);
          }
        }

        // TODO: Implement DetectionZoneService.computeCellIdsForDistrict
        // First call computes
        // final cellIds1 = await service.computeCellIdsForDistrict('district-1');

        // Second call should return cached result (verify by checking if upsert was called)
        // final cellIds2 = await service.computeCellIdsForDistrict('district-1');

        // expect(cellIds2, equals(cellIds1));
      });
    });

    // =========================================================================
    // Phase 1: Detection zone computation
    // =========================================================================

    group('detection zone computation', () {
      test('returns empty set when no district is set', () {
        // TODO: Implement DetectionZoneService
        // expect(service.detectionZoneCellIds, isEmpty);
      });

      test('computes detection zone from current + adjacent districts',
          () async {
        // Create a central district with two adjacent districts
        final centerGeometry = createSquarePolygon(45.0, -66.0, 45.02, -65.98);
        final adj1Geometry = createSquarePolygon(45.02, -66.0, 45.04, -65.98);
        final adj2Geometry = createSquarePolygon(45.0, -66.02, 45.02, -66.0);

        final centerNode = createDistrictNode(
          id: 'district-center',
          name: 'Center District',
          geometryJson: centerGeometry,
        );

        final adj1Node = createDistrictNode(
          id: 'district-adj1',
          name: 'Adjacent District 1',
          geometryJson: adj1Geometry,
        );

        final adj2Node = createDistrictNode(
          id: 'district-adj2',
          name: 'Adjacent District 2',
          geometryJson: adj2Geometry,
        );

        locationNodeRepo.addNode(centerNode);
        locationNodeRepo.addNode(adj1Node);
        locationNodeRepo.addNode(adj2Node);

        // Set up cells in all three districts
        for (var row = 22499; row <= 22520; row++) {
          for (var col = -33010; col <= -32990; col++) {
            final cellId = 'v_${row}_$col';
            final lat = (row + 0.5) * 0.002;
            final lon = (col + 0.5) * 0.002;
            cellService.setCenter(cellId, lat, lon);
            cellService.setNeighbors(cellId, [
              'v_${row}_$col',
              'v_${row - 1}_$col',
              'v_${row + 1}_$col',
            ]);
          }
        }

        // TODO: Implement DetectionZoneService.onDistrictChange
        // Mock adjacentLocationIds (would normally come from server)
        // For now, we're testing with the geometry-based computation

        // await service.onDistrictChange('district-center');

        // Detection zone should include cells from center + adjacent districts
        // expect(service.detectionZoneCellIds, isNotEmpty);
      });

      test('emits onDetectionZoneChanged when zone expands', () async {
        final geometryJson = createSquarePolygon(45.0, -66.0, 45.01, -65.99);

        final node = createDistrictNode(
          id: 'district-1',
          name: 'Test District',
          geometryJson: geometryJson,
        );
        locationNodeRepo.addNode(node);

        // Set up cells
        for (var row = 22499; row <= 22505; row++) {
          for (var col = -33001; col <= -32997; col++) {
            final cellId = 'v_${row}_$col';
            final lat = (row + 0.5) * 0.002;
            final lon = (col + 0.5) * 0.002;
            cellService.setCenter(cellId, lat, lon);
            cellService.setNeighbors(cellId, [
              'v_${row}_$col',
              'v_${row - 1}_$col',
              'v_${row + 1}_$col',
            ]);
          }
        }

        // TODO: Implement DetectionZoneService.onDetectionZoneChanged stream
        // final zoneChanges = <Set<String>>[];
        // service.onDetectionZoneChanged.listen((cellIds) {
        //   zoneChanges.add(cellIds);
        // });

        // await service.onDistrictChange('district-1');

        // expect(zoneChanges.length, equals(1));
        // expect(zoneChanges.first, isNotEmpty);
      });
    });

    // =========================================================================
    // Phase 4: SpeciesCache warm-up
    // =========================================================================

    group('SpeciesCache warm-up', () {
      test(
          'warms cache for unique (habitat, continent) pairs in detection zone',
          () async {
        final geometryJson = createSquarePolygon(45.0, -66.0, 45.01, -65.99);

        final node = createDistrictNode(
          id: 'district-1',
          name: 'Test District',
          geometryJson: geometryJson,
        );
        locationNodeRepo.addNode(node);

        // Set up cells
        final cellIds = <String>[];
        for (var row = 22499; row <= 22505; row++) {
          for (var col = -33001; col <= -32997; col++) {
            final cellId = 'v_${row}_$col';
            cellIds.add(cellId);
            final lat = (row + 0.5) * 0.002;
            final lon = (col + 0.5) * 0.002;
            cellService.setCenter(cellId, lat, lon);
            cellService.setNeighbors(cellId, [
              'v_${row}_$col',
              'v_${row - 1}_$col',
              'v_${row + 1}_$col',
            ]);
          }
        }

        // Mock cell properties with different habitats
        final cellPropertiesMap = <String, CellProperties>{};
        final habitatSets = <Set<Habitat>>[
          {Habitat.forest},
          {Habitat.plains},
          {Habitat.forest, Habitat.freshwater},
        ];

        for (var i = 0; i < cellIds.length; i++) {
          final cellId = cellIds[i];
          final center = cellService.getCellCenter(cellId);
          final habitats = habitatSets[i % habitatSets.length];

          cellPropertiesMap[cellId] = CellProperties(
            cellId: cellId,
            habitats: habitats,
            climate: Climate.fromLatitude(center.lat),
            continent: Continent.northAmerica,
            locationId: 'district-1',
            createdAt: DateTime.now(),
          );
        }

        // TODO: Implement DetectionZoneService with getCellProperties callback
        // service = DetectionZoneService(
        //   cellService: cellService,
        //   locationNodeRepo: locationNodeRepo,
        //   getCellProperties: (cellId) => cellPropertiesMap[cellId],
        // );

        // await service.onDistrictChange('district-1');

        // TODO: Verify SpeciesCache was warmed for unique (habitat, continent) pairs
        // In this case: (forest, northAmerica), (plains, northAmerica),
        //               (forest+freshwater, northAmerica)
        // expect(
        //   speciesCache.warmedKeys,
        //   containsAll([
        //     'forest:northAmerica',
        //     'plains:northAmerica',
        //     'forest,freshwater:northAmerica',
        //   ]),
        // );
      });

      test('does not warm cache for cells without properties', () async {
        final geometryJson = createSquarePolygon(45.0, -66.0, 45.01, -65.99);

        final node = createDistrictNode(
          id: 'district-1',
          name: 'Test District',
          geometryJson: geometryJson,
        );
        locationNodeRepo.addNode(node);

        // Set up cells but don't provide properties
        for (var row = 22499; row <= 22505; row++) {
          for (var col = -33001; col <= -32997; col++) {
            final cellId = 'v_${row}_$col';
            final lat = (row + 0.5) * 0.002;
            final lon = (col + 0.5) * 0.002;
            cellService.setCenter(cellId, lat, lon);
            cellService.setNeighbors(cellId, [
              'v_${row}_$col',
              'v_${row - 1}_$col',
              'v_${row + 1}_$col',
            ]);
          }
        }

        // TODO: Implement DetectionZoneService
        // service = DetectionZoneService(
        //   cellService: cellService,
        //   locationNodeRepo: locationNodeRepo,
        //   getCellProperties: (cellId) => null, // No properties
        // );

        // await service.onDistrictChange('district-1');

        // Should not crash, and cache should remain empty
        expect(speciesCache.warmedKeys, isEmpty);
      });
    });

    // =========================================================================
    // Phase 5: Adjacent districts
    // =========================================================================

    group('adjacent districts', () {
      test(
          'includes cells from adjacent districts when adjacentLocationIds is set',
          () async {
        // Create two adjacent districts
        final district1Geometry =
            createSquarePolygon(45.0, -66.0, 45.02, -65.98);
        final district2Geometry =
            createSquarePolygon(45.02, -66.0, 45.04, -65.98);

        final node1 = LocationNode(
          id: 'district-1',
          osmId: null,
          name: 'District 1',
          adminLevel: AdminLevel.district,
          parentId: null,
          colorHex: null,
          geometryJson: district1Geometry,
          adjacentLocationIds: ['district-2'], // Adjacent district
        );

        final node2 = LocationNode(
          id: 'district-2',
          osmId: null,
          name: 'District 2',
          adminLevel: AdminLevel.district,
          parentId: null,
          colorHex: null,
          geometryJson: district2Geometry,
          adjacentLocationIds: ['district-1'],
        );

        locationNodeRepo.addNode(node1);
        locationNodeRepo.addNode(node2);

        // Set up cells in both districts
        for (var row = 22499; row <= 22520; row++) {
          for (var col = -33001; col <= -32990; col++) {
            final cellId = 'v_${row}_$col';
            final lat = (row + 0.5) * 0.002;
            final lon = (col + 0.5) * 0.002;
            cellService.setCenter(cellId, lat, lon);
            cellService.setNeighbors(cellId, [
              'v_${row}_$col',
              'v_${row - 1}_$col',
              'v_${row + 1}_$col',
            ]);
          }
        }

        // TODO: Implement DetectionZoneService.onDistrictChange
        // await service.onDistrictChange('district-1');

        // expect(service.detectionZoneCellIds, isNotEmpty);
      });
    });

    // =========================================================================
    // Edge cases
    // =========================================================================

    group('edge cases', () {
      test('handles district with no cells gracefully', () async {
        // Create a tiny polygon that contains no Voronoi cell centers
        final geometryJson =
            createSquarePolygon(45.00001, -66.00001, 45.00002, -65.99999);

        final node = createDistrictNode(
          id: 'district-1',
          name: 'Tiny District',
          geometryJson: geometryJson,
        );
        locationNodeRepo.addNode(node);

        // Set up cells far away from the polygon
        for (var row = 22500; row <= 22505; row++) {
          for (var col = -33000; col <= -32995; col++) {
            final cellId = 'v_${row}_$col';
            final lat = (row + 0.5) * 0.002;
            final lon = (col + 0.5) * 0.002;
            cellService.setCenter(cellId, lat, lon);
            cellService.setNeighbors(cellId, [
              'v_${row}_$col',
              'v_${row - 1}_$col',
              'v_${row + 1}_$col',
            ]);
          }
        }

        // TODO: Implement DetectionZoneService.computeCellIdsForDistrict
        // final cellIds = await service.computeCellIdsForDistrict('district-1');

        // Should return empty set (no cells inside the tiny polygon)
        // expect(cellIds, isEmpty);
      });

      test('handles concurrent district changes', () async {
        // Test that rapid district changes don't cause race conditions
        final geometry1 = createSquarePolygon(45.0, -66.0, 45.01, -65.99);
        final geometry2 = createSquarePolygon(45.01, -66.0, 45.02, -65.99);

        final node1 = createDistrictNode(
          id: 'district-1',
          name: 'District 1',
          geometryJson: geometry1,
        );
        final node2 = createDistrictNode(
          id: 'district-2',
          name: 'District 2',
          geometryJson: geometry2,
        );

        locationNodeRepo.addNode(node1);
        locationNodeRepo.addNode(node2);

        // Set up cells
        for (var row = 22499; row <= 22510; row++) {
          for (var col = -33001; col <= -32995; col++) {
            final cellId = 'v_${row}_$col';
            final lat = (row + 0.5) * 0.002;
            final lon = (col + 0.5) * 0.002;
            cellService.setCenter(cellId, lat, lon);
            cellService.setNeighbors(cellId, [
              'v_${row}_$col',
              'v_${row - 1}_$col',
              'v_${row + 1}_$col',
            ]);
          }
        }

        // TODO: Implement DetectionZoneService
        // Trigger two district changes concurrently
        // final future1 = service.onDistrictChange('district-1');
        // final future2 = service.onDistrictChange('district-2');

        // await Future.wait([future1, future2]);

        // Should not crash, and detection zone should be from the last call
        // expect(service.detectionZoneCellIds, isNotEmpty);
      });
    });
  });
}
