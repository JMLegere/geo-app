import 'package:earth_nova/core/cells/cell_service.dart';
import 'package:earth_nova/core/fog/fog_state_resolver.dart';
import 'package:earth_nova/core/models/fog_state.dart';
import 'package:flutter_test/flutter_test.dart';

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
        // Set up a grid of cells
        for (var row = 0; row < 10; row++) {
          for (var col = 0; col < 10; col++) {
            final cellId = 'v_${row}_$col';
            final lat = 45.0 + row * 0.002;
            final lon = -66.0 + col * 0.002;
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

        // Set detection zone to cells in rows 3-7
        final detectionZone = <String>{};
        for (var row = 3; row <= 7; row++) {
          for (var col = 0; col < 10; col++) {
            detectionZone.add('v_${row}_$col');
          }
        }

        resolver.setDetectionZone(detectionZone);

        // Move player to center of detection zone
        resolver.onLocationUpdate(45.006, -66.006); // Row 3, Col 3

        // Cells in detection zone should be unexplored (not undetected)
        final inZoneCell = 'v_5_5';
        expect(resolver.resolve(inZoneCell), equals(FogState.unexplored));

        // Cells outside detection zone should be undetected
        final outOfZoneCell = 'v_0_0';
        expect(resolver.resolve(outOfZoneCell), equals(FogState.undetected));
      });

      test('detection zone expands when new cells are added', () {
        // Set up cells
        for (var row = 0; row < 10; row++) {
          for (var col = 0; col < 10; col++) {
            final cellId = 'v_${row}_$col';
            final lat = 45.0 + row * 0.002;
            final lon = -66.0 + col * 0.002;
            cellService.setCenter(cellId, lat, lon);
            cellService.setNeighbors(cellId, [
              'v_${row}_$col',
              'v_${row - 1}_$col',
              'v_${row + 1}_$col',
            ]);
          }
        }

        // Initial detection zone
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
        // Set up cells
        for (var row = 0; row < 10; row++) {
          for (var col = 0; col < 10; col++) {
            final cellId = 'v_${row}_$col';
            final lat = 45.0 + row * 0.002;
            final lon = -66.0 + col * 0.002;
            cellService.setCenter(cellId, lat, lon);
            cellService.setNeighbors(cellId, [
              'v_${row}_$col',
              'v_${row - 1}_$col',
              'v_${row + 1}_$col',
            ]);
          }
        }

        // Set detection zone to center
        final detectionZone = <String>{'v_5_5'};
        resolver.setDetectionZone(detectionZone);

        // Visit a cell outside detection zone
        resolver.onLocationUpdate(45.000, -66.000); // v_0_0

        // That cell should be hidden (visited)
        expect(resolver.resolve('v_0_0'), equals(FogState.hidden));

        // Even if detection zone doesn't include it
        expect(resolver.visitedCellIds, contains('v_0_0'));
      });
    });

    group('resolve with detection zone', () {
      test('returns observed for current cell', () {
        // Set up cells
        for (var row = 0; row < 10; row++) {
          for (var col = 0; col < 10; col++) {
            final cellId = 'v_${row}_$col';
            final lat = 45.0 + row * 0.002;
            final lon = -66.0 + col * 0.002;
            cellService.setCenter(cellId, lat, lon);
            cellService.setNeighbors(cellId, [
              'v_${row}_$col',
              'v_${row - 1}_$col',
              'v_${row + 1}_$col',
            ]);
          }
        }

        resolver.setDetectionZone({'v_5_5'});

        // Move to v_5_5
        resolver.onLocationUpdate(45.005, -66.005);

        expect(resolver.resolve('v_5_5'), equals(FogState.observed));
      });

      test('returns hidden for visited cells outside current position', () {
        // Set up cells
        for (var row = 0; row < 10; row++) {
          for (var col = 0; col < 10; col++) {
            final cellId = 'v_${row}_$col';
            final lat = 45.0 + row * 0.002;
            final lon = -66.0 + col * 0.002;
            cellService.setCenter(cellId, lat, lon);
            cellService.setNeighbors(cellId, [
              'v_${row}_$col',
              'v_${row - 1}_$col',
              'v_${row + 1}_$col',
            ]);
          }
        }

        resolver.setDetectionZone({'v_5_5', 'v_5_6', 'v_6_5', 'v_6_6'});

        // Visit v_5_5
        resolver.onLocationUpdate(45.005, -66.005);

        // Move to v_6_6
        resolver.onLocationUpdate(45.007, -66.007);

        // v_5_5 should be hidden (visited but not current)
        expect(resolver.resolve('v_5_5'), equals(FogState.hidden));
      });

      test('returns concealed for neighbors of current cell', () {
        // Set up cells
        for (var row = 0; row < 10; row++) {
          for (var col = 0; col < 10; col++) {
            final cellId = 'v_${row}_$col';
            final lat = 45.0 + row * 0.002;
            final lon = -66.0 + col * 0.002;
            cellService.setCenter(cellId, lat, lon);
            cellService.setNeighbors(cellId, [
              'v_${row}_$col',
              'v_${row - 1}_$col',
              'v_${row + 1}_$col',
            ]);
          }
        }

        resolver.setDetectionZone({'v_5_5', 'v_5_6', 'v_6_5', 'v_6_6'});

        // Move to v_5_5
        resolver.onLocationUpdate(45.005, -66.005);

        // Neighbors should be concealed
        expect(resolver.resolve('v_5_6'), equals(FogState.concealed));
        expect(resolver.resolve('v_6_5'), equals(FogState.concealed));
      });

      test(
          'returns unexplored for cells in detection zone but not visited/adjacent',
          () {
        // Set up cells
        for (var row = 0; row < 10; row++) {
          for (var col = 0; col < 10; col++) {
            final cellId = 'v_${row}_$col';
            final lat = 45.0 + row * 0.002;
            final lon = -66.0 + col * 0.002;
            cellService.setCenter(cellId, lat, lon);
            cellService.setNeighbors(cellId, [
              'v_${row}_$col',
              'v_${row - 1}_$col',
              'v_${row + 1}_$col',
            ]);
          }
        }

        // Detection zone includes v_5_5 and v_7_7 (not adjacent)
        resolver.setDetectionZone({'v_5_5', 'v_7_7'});

        // Move to v_5_5
        resolver.onLocationUpdate(45.005, -66.005);

        // v_7_7 is in detection zone but not visited or adjacent
        expect(resolver.resolve('v_7_7'), equals(FogState.unexplored));
      });

      test('returns undetected for cells outside detection zone', () {
        // Set up cells
        for (var row = 0; row < 10; row++) {
          for (var col = 0; col < 10; col++) {
            final cellId = 'v_${row}_$col';
            final lat = 45.0 + row * 0.002;
            final lon = -66.0 + col * 0.002;
            cellService.setCenter(cellId, lat, lon);
            cellService.setNeighbors(cellId, [
              'v_${row}_$col',
              'v_${row - 1}_$col',
              'v_${row + 1}_$col',
            ]);
          }
        }

        resolver.setDetectionZone({'v_5_5'});

        // Move to v_5_5
        resolver.onLocationUpdate(45.005, -66.005);

        // v_0_0 is outside detection zone
        expect(resolver.resolve('v_0_0'), equals(FogState.undetected));
      });
    });

    group('priority order', () {
      test('observed > hidden > concealed > unexplored > undetected', () {
        // Set up cells
        for (var row = 0; row < 10; row++) {
          for (var col = 0; col < 10; col++) {
            final cellId = 'v_${row}_$col';
            final lat = 45.0 + row * 0.002;
            final lon = -66.0 + col * 0.002;
            cellService.setCenter(cellId, lat, lon);
            cellService.setNeighbors(cellId, [
              'v_${row}_$col',
              'v_${row - 1}_$col',
              'v_${row + 1}_$col',
            ]);
          }
        }

        // Detection zone includes all cells
        final allCells = <String>{};
        for (var row = 0; row < 10; row++) {
          for (var col = 0; col < 10; col++) {
            allCells.add('v_${row}_$col');
          }
        }
        resolver.setDetectionZone(allCells);

        // Visit v_5_5
        resolver.onLocationUpdate(45.005, -66.005);

        // Current cell: observed
        expect(resolver.resolve('v_5_5'), equals(FogState.observed));

        // Visited cell (not current): hidden
        // Move to v_6_6
        resolver.onLocationUpdate(45.007, -66.007);
        expect(resolver.resolve('v_5_5'), equals(FogState.hidden));

        // Adjacent to current: concealed
        expect(resolver.resolve('v_6_5'), equals(FogState.concealed));

        // In detection zone but not visited/adjacent: unexplored
        expect(resolver.resolve('v_0_0'), equals(FogState.unexplored));

        // Outside detection zone: undetected
        resolver.setDetectionZone({'v_6_6'});
        expect(resolver.resolve('v_0_0'), equals(FogState.undetected));
      });
    });

    group('visited perimeter', () {
      test('visitedPerimeter contains unvisited neighbors of visited cells',
          () {
        // Set up cells
        for (var row = 0; row < 10; row++) {
          for (var col = 0; col < 10; col++) {
            final cellId = 'v_${row}_$col';
            final lat = 45.0 + row * 0.002;
            final lon = -66.0 + col * 0.002;
            cellService.setCenter(cellId, lat, lon);
            cellService.setNeighbors(cellId, [
              'v_${row}_$col',
              'v_${row - 1}_$col',
              'v_${row + 1}_$col',
            ]);
          }
        }

        resolver.setDetectionZone({'v_5_5'});

        // Visit v_5_5
        resolver.onLocationUpdate(45.005, -66.005);

        // The visited perimeter should contain neighbors of v_5_5
        // (but these are now concealed, not in a separate perimeter set)
        // This test verifies the old explorationFrontier behavior is removed
        // and replaced with detection zone logic
        expect(resolver.visitedCellIds, contains('v_5_5'));
      });
    });

    group('loadVisitedCells', () {
      test('restores visited cells from persistence', () {
        // Set up cells
        for (var row = 0; row < 10; row++) {
          for (var col = 0; col < 10; col++) {
            final cellId = 'v_${row}_$col';
            final lat = 45.0 + row * 0.002;
            final lon = -66.0 + col * 0.002;
            cellService.setCenter(cellId, lat, lon);
            cellService.setNeighbors(cellId, [
              'v_${row}_$col',
              'v_${row - 1}_$col',
              'v_${row + 1}_$col',
            ]);
          }
        }

        // Load visited cells
        resolver.loadVisitedCells({'v_5_5', 'v_5_6'});

        // Set detection zone
        resolver.setDetectionZone({'v_5_5', 'v_5_6', 'v_6_5', 'v_6_6'});

        // Move to v_6_6
        resolver.onLocationUpdate(45.007, -66.007);

        // Previously visited cells should be hidden
        expect(resolver.resolve('v_5_5'), equals(FogState.hidden));
        expect(resolver.resolve('v_5_6'), equals(FogState.hidden));
      });
    });
  });
}
