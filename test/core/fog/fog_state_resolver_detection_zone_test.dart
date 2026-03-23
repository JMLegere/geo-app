import 'package:earth_nova/core/cells/cell_service.dart';
import 'package:earth_nova/core/fog/fog_state_resolver.dart';
import 'package:earth_nova/core/models/fog_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geobase/geobase.dart';

/// Mock CellService for testing FogStateResolver.
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
  Geographic getCellCenter(String cellId) {
    return _centers[cellId] ?? Geographic(lat: 0, lon: 0);
  }

  @override
  List<Geographic> getCellBoundary(String cellId) => [];

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

/// Helper: set up a 10×10 grid of cells with centers and neighbors.
/// Cell v_{row}_{col} has center at (45.0 + row * 0.002, -66.0 + col * 0.002).
void setupGrid(MockCellService cellService) {
  for (var row = 0; row < 10; row++) {
    for (var col = 0; col < 10; col++) {
      final cellId = 'v_${row}_$col';
      final lat = 45.0 + row * 0.002;
      final lon = -66.0 + col * 0.002;
      cellService.setCenter(cellId, lat, lon);
      final neighbors = <String>[];
      if (row > 0) neighbors.add('v_${row - 1}_$col');
      if (row < 9) neighbors.add('v_${row + 1}_$col');
      if (col > 0) neighbors.add('v_${row}_${col - 1}');
      if (col < 9) neighbors.add('v_${row}_${col + 1}');
      cellService.setNeighbors(cellId, neighbors);
    }
  }
}

/// Helper: get the lat/lon for a cell in the grid.
double gridLat(int row) => 45.0 + row * 0.002;
double gridLon(int col) => -66.0 + col * 0.002;

void main() {
  group('FogStateResolver with detection zone', () {
    late MockCellService cellService;
    late FogStateResolver resolver;

    setUp(() {
      cellService = MockCellService();
      resolver = FogStateResolver(cellService);
    });

    group('setDetectionZone', () {
      test('replaces detection radius check with zone membership', () {
        setupGrid(cellService);

        // Set detection zone to cells in rows 3-7
        final detectionZone = <String>{};
        for (var row = 3; row <= 7; row++) {
          for (var col = 0; col < 10; col++) {
            detectionZone.add('v_${row}_$col');
          }
        }

        resolver.setDetectionZone(detectionZone);

        // Move player to v_3_3 (inside detection zone)
        resolver.onLocationUpdate(gridLat(3), gridLon(3));

        // Cells in detection zone should be unexplored (not undetected)
        expect(resolver.resolve('v_5_5'), equals(FogState.unexplored));

        // Cells outside detection zone should be undetected
        expect(resolver.resolve('v_0_0'), equals(FogState.undetected));
      });

      test('detection zone expands when new cells are added', () {
        setupGrid(cellService);

        // Initial detection zone — small
        final initialZone = <String>{'v_5_5', 'v_5_6', 'v_6_5', 'v_6_6'};
        resolver.setDetectionZone(initialZone);

        // Verify initial zone
        expect(resolver.resolve('v_5_5'), equals(FogState.unexplored));
        expect(resolver.resolve('v_0_0'), equals(FogState.undetected));

        // Expand detection zone
        final expandedZone = <String>{};
        for (var row = 4; row <= 7; row++) {
          for (var col = 4; col <= 7; col++) {
            expandedZone.add('v_${row}_$col');
          }
        }
        resolver.setDetectionZone(expandedZone);

        // Verify expanded zone
        expect(resolver.resolve('v_4_4'), equals(FogState.unexplored));
        expect(resolver.resolve('v_0_0'), equals(FogState.undetected));
      });

      test('visited cells remain hidden even outside detection zone', () {
        setupGrid(cellService);

        // Visit v_0_0 first (before setting detection zone)
        resolver.onLocationUpdate(gridLat(0), gridLon(0));
        expect(resolver.resolve('v_0_0'), equals(FogState.observed));

        // Move away from v_0_0
        resolver.onLocationUpdate(gridLat(5), gridLon(5));

        // Set detection zone that does NOT include v_0_0
        resolver.setDetectionZone({'v_5_5'});

        // v_0_0 should be hidden (visited), not undetected
        expect(resolver.resolve('v_0_0'), equals(FogState.hidden));
        expect(resolver.visitedCellIds, contains('v_0_0'));
      });
    });

    group('resolve with detection zone', () {
      test('returns observed for current cell', () {
        setupGrid(cellService);

        resolver.setDetectionZone({'v_5_5'});

        // Move to v_5_5
        resolver.onLocationUpdate(gridLat(5), gridLon(5));

        expect(resolver.resolve('v_5_5'), equals(FogState.observed));
      });

      test('returns hidden for visited cells outside current position', () {
        setupGrid(cellService);

        resolver.setDetectionZone({'v_5_5', 'v_5_6', 'v_6_5', 'v_6_6'});

        // Visit v_5_5
        resolver.onLocationUpdate(gridLat(5), gridLon(5));

        // Move to v_6_6
        resolver.onLocationUpdate(gridLat(6), gridLon(6));

        // v_5_5 should be hidden (visited but not current)
        expect(resolver.resolve('v_5_5'), equals(FogState.hidden));
      });

      test('returns concealed for neighbors of current cell', () {
        setupGrid(cellService);

        resolver.setDetectionZone({'v_5_5', 'v_5_6', 'v_6_5', 'v_6_6'});

        // Move to v_5_5
        resolver.onLocationUpdate(gridLat(5), gridLon(5));

        // Neighbors of v_5_5 are v_4_5, v_6_5, v_5_4, v_5_6
        expect(resolver.resolve('v_5_6'), equals(FogState.concealed));
        expect(resolver.resolve('v_6_5'), equals(FogState.concealed));
      });

      test(
          'returns unexplored for cells in detection zone but not visited/adjacent',
          () {
        setupGrid(cellService);

        // Detection zone includes v_5_5 and v_8_8 (not adjacent)
        resolver.setDetectionZone({'v_5_5', 'v_8_8'});

        // Move to v_5_5
        resolver.onLocationUpdate(gridLat(5), gridLon(5));

        // v_8_8 is in detection zone but not visited or adjacent
        expect(resolver.resolve('v_8_8'), equals(FogState.unexplored));
      });

      test('returns undetected for cells outside detection zone', () {
        setupGrid(cellService);

        resolver.setDetectionZone({'v_5_5'});

        // Move to v_5_5
        resolver.onLocationUpdate(gridLat(5), gridLon(5));

        // v_0_0 is outside detection zone and not visited/adjacent
        expect(resolver.resolve('v_0_0'), equals(FogState.undetected));
      });
    });

    group('priority order', () {
      test('observed > hidden > concealed > unexplored > undetected', () {
        setupGrid(cellService);

        // Detection zone includes all cells
        final allCells = <String>{};
        for (var row = 0; row < 10; row++) {
          for (var col = 0; col < 10; col++) {
            allCells.add('v_${row}_$col');
          }
        }
        resolver.setDetectionZone(allCells);

        // Visit v_5_5
        resolver.onLocationUpdate(gridLat(5), gridLon(5));

        // Current cell: observed
        expect(resolver.resolve('v_5_5'), equals(FogState.observed));

        // Move to v_6_6
        resolver.onLocationUpdate(gridLat(6), gridLon(6));

        // Visited cell (not current): hidden
        expect(resolver.resolve('v_5_5'), equals(FogState.hidden));

        // Adjacent to current: concealed
        // v_6_5 is a neighbor of v_6_6
        expect(resolver.resolve('v_6_5'), equals(FogState.concealed));

        // In detection zone but not visited/adjacent: unexplored
        expect(resolver.resolve('v_0_0'), equals(FogState.unexplored));

        // Shrink detection zone — v_0_0 should become undetected
        resolver.setDetectionZone({'v_6_6'});
        // But v_0_0 was already in _everDetectedCellIds, so it stays unexplored
        // This is correct behavior: once detected, never reverts
        expect(resolver.resolve('v_0_0'), equals(FogState.unexplored));
      });
    });

    group('visited perimeter', () {
      test('visitedPerimeter contains unvisited neighbors of visited cells',
          () {
        setupGrid(cellService);

        resolver.setDetectionZone({'v_5_5', 'v_5_6', 'v_4_5', 'v_6_5'});

        // Visit v_5_5
        resolver.onLocationUpdate(gridLat(5), gridLon(5));

        // The exploration frontier should contain unvisited neighbors
        expect(resolver.visitedCellIds, contains('v_5_5'));
        expect(resolver.explorationFrontier, contains('v_4_5'));
        expect(resolver.explorationFrontier, contains('v_6_5'));
        expect(resolver.explorationFrontier, contains('v_5_6'));
      });
    });

    group('loadVisitedCells', () {
      test('restores visited cells from persistence', () {
        setupGrid(cellService);

        // Load visited cells
        resolver.loadVisitedCells({'v_5_5', 'v_5_6'});

        // Set detection zone
        resolver.setDetectionZone({'v_5_5', 'v_5_6', 'v_6_5', 'v_6_6'});

        // Move to v_6_6
        resolver.onLocationUpdate(gridLat(6), gridLon(6));

        // Previously visited cells should be hidden
        expect(resolver.resolve('v_5_5'), equals(FogState.hidden));
        expect(resolver.resolve('v_5_6'), equals(FogState.hidden));
      });
    });
  });
}
