import 'package:flutter_test/flutter_test.dart';
import 'package:geobase/geobase.dart';
import 'package:fog_of_world/core/cells/cell_service.dart';
import 'package:fog_of_world/core/fog/fog_event.dart';
import 'package:fog_of_world/core/fog/fog_state_resolver.dart';
import 'package:fog_of_world/core/models/fog_state.dart';

// ---------------------------------------------------------------------------
// MockCellService — deterministic grid-based cell service.
//
// Cell ID format: "cell_{latInt}_{lonInt}" where latInt = lat.round(),
// lonInt = lon.round().
//
// getNeighborIds returns all cells in a (2k+1)×(2k+1) Chebyshev square
// around the cell, excluding the cell itself (k=1 → 8 neighbors).
//
// getCellCenter parses the cell ID to get lat/lon, supporting decimal values
// in the ID (e.g. "cell_0.3_0.0") for distance-based tests.
// ---------------------------------------------------------------------------
class MockCellService implements CellService {
  @override
  String getCellId(double lat, double lon) =>
      'cell_${lat.round()}_${lon.round()}';

  @override
  List<String> getCellsAroundLocation(double lat, double lon, int k) {
    final centerLat = lat.round();
    final centerLon = lon.round();
    final cells = <String>[];
    for (var dlat = -k; dlat <= k; dlat++) {
      for (var dlon = -k; dlon <= k; dlon++) {
        cells.add('cell_${centerLat + dlat}_${centerLon + dlon}');
      }
    }
    return cells;
  }

  @override
  List<String> getCellsInRing(String cellId, int k) {
    final parts = cellId.split('_');
    final centerLat = int.parse(parts[1]);
    final centerLon = int.parse(parts[2]);
    final cells = <String>[];
    for (var dlat = -k; dlat <= k; dlat++) {
      for (var dlon = -k; dlon <= k; dlon++) {
        cells.add('cell_${centerLat + dlat}_${centerLon + dlon}');
      }
    }
    return cells;
  }

  @override
  List<String> getNeighborIds(String cellId) =>
      getCellsInRing(cellId, 1)..remove(cellId);

  @override
  Geographic getCellCenter(String cellId) {
    final parts = cellId.split('_');
    // Support decimal cell IDs for distance tests (e.g. "cell_0.3_0.0").
    return Geographic(lat: double.parse(parts[1]), lon: double.parse(parts[2]));
  }

  @override
  List<Geographic> getCellBoundary(String cellId) {
    final center = getCellCenter(cellId);
    const h = 0.5;
    return [
      Geographic(lat: center.lat - h, lon: center.lon - h),
      Geographic(lat: center.lat - h, lon: center.lon + h),
      Geographic(lat: center.lat + h, lon: center.lon + h),
      Geographic(lat: center.lat + h, lon: center.lon - h),
    ];
  }

  @override
  double get cellEdgeLengthMeters => 100.0;

  @override
  String get systemName => 'MockGrid';
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

FogStateResolver _makeResolver() => FogStateResolver(MockCellService());

/// Collects events emitted synchronously during [body].
List<FogStateChangedEvent> collectEvents(
  FogStateResolver resolver,
  void Function() body,
) {
  final events = <FogStateChangedEvent>[];
  final sub = resolver.onVisitedCellAdded.listen(events.add);
  body();
  sub.cancel();
  return events;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('FogStateResolver', () {
    late FogStateResolver resolver;

    setUp(() {
      resolver = _makeResolver();
    });

    tearDown(() {
      resolver.dispose();
    });

    // -------------------------------------------------------------------------
    // Test 1: Undetected for unknown cells with no location update.
    // -------------------------------------------------------------------------
    test(
        '1. resolve() returns undetected for unknown cells with no location update',
        () {
      expect(resolver.resolve('cell_0_0'), equals(FogState.undetected));
      expect(resolver.resolve('cell_5_5'), equals(FogState.undetected));
    });

    // -------------------------------------------------------------------------
    // Test 2: Observed for the current cell after onLocationUpdate.
    // -------------------------------------------------------------------------
    test('2. resolve() returns observed for the current cell after onLocationUpdate',
        () {
      resolver.onLocationUpdate(0.0, 0.0);
      expect(resolver.resolve('cell_0_0'), equals(FogState.observed));
    });

    // -------------------------------------------------------------------------
    // Test 3: Concealed for neighbors of the current cell.
    // -------------------------------------------------------------------------
    test('3. resolve() returns concealed for neighbors of the current cell', () {
      resolver.onLocationUpdate(0.0, 0.0);

      // The 8 immediate integer neighbors of cell_0_0 are all concealed.
      expect(resolver.resolve('cell_1_0'), equals(FogState.concealed));
      expect(resolver.resolve('cell_0_1'), equals(FogState.concealed));
      expect(resolver.resolve('cell_-1_0'), equals(FogState.concealed));
      expect(resolver.resolve('cell_1_1'), equals(FogState.concealed));
    });

    // -------------------------------------------------------------------------
    // Test 4: Hidden for previously visited cells not in current view.
    // -------------------------------------------------------------------------
    test(
        '4. resolve() returns hidden for previously visited cells that are not current or adjacent',
        () {
      // Visit cell_0_0.
      resolver.onLocationUpdate(0.0, 0.0);
      // Move far away — cell_0_0 is now visited but not current or adjacent.
      resolver.onLocationUpdate(10.0, 10.0);

      expect(resolver.resolve('cell_0_0'), equals(FogState.hidden));
    });

    // -------------------------------------------------------------------------
    // Test 5: Unexplored for frontier cells.
    // -------------------------------------------------------------------------
    test(
        '5. resolve() returns unexplored for frontier cells (adjacent to visited but never visited)',
        () {
      // Visit cell_0_0 — its neighbors become the frontier.
      resolver.onLocationUpdate(0.0, 0.0);
      // Move far away so neighbors are no longer concealed.
      resolver.onLocationUpdate(10.0, 10.0);

      // cell_1_0 is a neighbor of visited cell_0_0 but has never been visited.
      expect(resolver.resolve('cell_1_0'), equals(FogState.unexplored));
      expect(resolver.resolve('cell_0_1'), equals(FogState.unexplored));
    });

    // -------------------------------------------------------------------------
    // Test 6: Unexplored for cells within 50km but not frontier/visited.
    // -------------------------------------------------------------------------
    test(
        '6. resolve() returns unexplored for cells within 50km but not visited/frontier',
        () {
      resolver.onLocationUpdate(0.0, 0.0);

      // "cell_0.3_0" has center at (0.3°, 0°) ≈ 33 km from player.
      // It is NOT in the frontier (mock frontier uses integer-coordinate cells).
      expect(resolver.resolve('cell_0.3_0'), equals(FogState.unexplored));
    });

    // -------------------------------------------------------------------------
    // Test 7: Undetected for cells beyond 50km not in frontier.
    // -------------------------------------------------------------------------
    test(
        '7. resolve() returns undetected for cells beyond 50km that are not visited',
        () {
      resolver.onLocationUpdate(0.0, 0.0);

      // cell_3_0 center at (3°, 0°) ≈ 333 km from player.
      // It is NOT in the frontier (only immediate neighbors ±1° are frontier).
      expect(resolver.resolve('cell_3_0'), equals(FogState.undetected));
    });

    // -------------------------------------------------------------------------
    // Test 8: Visiting a new cell adds it to visitedCellIds.
    // -------------------------------------------------------------------------
    test('8. visiting a new cell adds it to visitedCellIds', () {
      expect(resolver.visitedCellIds, isEmpty);

      resolver.onLocationUpdate(0.0, 0.0);
      expect(resolver.visitedCellIds, contains('cell_0_0'));
      expect(resolver.visitedCellIds.length, equals(1));

      resolver.onLocationUpdate(10.0, 10.0);
      expect(resolver.visitedCellIds, contains('cell_10_10'));
      expect(resolver.visitedCellIds.length, equals(2));
    });

    // -------------------------------------------------------------------------
    // Test 9: Exploration frontier grows as more cells are visited.
    // -------------------------------------------------------------------------
    test('9. exploration frontier grows as more cells are visited', () {
      expect(resolver.explorationFrontier, isEmpty);

      // After visiting cell_0_0: 8 immediate neighbors become frontier.
      resolver.onLocationUpdate(0.0, 0.0);
      expect(resolver.explorationFrontier.length, equals(8));

      // After visiting cell_10_10 (far away, no overlap with first frontier):
      // frontier grows by 8 more unique cells.
      resolver.onLocationUpdate(10.0, 10.0);
      expect(resolver.explorationFrontier.length, equals(16));
    });

    // -------------------------------------------------------------------------
    // Test 10: Exploration frontier loses a cell when that frontier cell is visited.
    // -------------------------------------------------------------------------
    test(
        '10. exploration frontier no longer contains a frontier cell after it is visited',
        () {
      resolver.onLocationUpdate(0.0, 0.0);
      expect(resolver.explorationFrontier, contains('cell_1_0'));

      // Visit cell_1_0 (which was a frontier cell).
      resolver.onLocationUpdate(1.0, 0.0);
      expect(resolver.explorationFrontier, isNot(contains('cell_1_0')));
    });

    // -------------------------------------------------------------------------
    // Test 11: Event fires when a new cell is entered (first visit only).
    // -------------------------------------------------------------------------
    test('11. event fires when a new cell is entered (first visit only)', () {
      final events = collectEvents(resolver, () {
        resolver.onLocationUpdate(0.0, 0.0);
      });

      expect(events.length, equals(1));
      expect(events[0].cellId, equals('cell_0_0'));
      expect(events[0].newState, equals(FogState.observed));
    });

    // -------------------------------------------------------------------------
    // Test 12: No event fires when re-entering a previously visited cell.
    // -------------------------------------------------------------------------
    test('12. no event fires when re-entering a previously visited cell', () {
      resolver.onLocationUpdate(0.0, 0.0); // First visit — event fires.

      final events = collectEvents(resolver, () {
        resolver.onLocationUpdate(0.0, 0.0); // Re-entry — no event.
      });

      expect(events, isEmpty);
    });

    // -------------------------------------------------------------------------
    // Test 13: loadVisitedCells restores visited set and recomputes frontier.
    // -------------------------------------------------------------------------
    test('13. loadVisitedCells restores visited set and recomputes frontier',
        () {
      resolver.loadVisitedCells({'cell_0_0', 'cell_10_10'});

      expect(resolver.visitedCellIds, containsAll(['cell_0_0', 'cell_10_10']));
      expect(resolver.visitedCellIds.length, equals(2));

      // Frontier should contain the non-visited neighbors of both cells.
      expect(resolver.explorationFrontier, contains('cell_1_0'));
      expect(resolver.explorationFrontier, contains('cell_11_10'));
      expect(resolver.explorationFrontier, isNot(contains('cell_0_0')));
      expect(resolver.explorationFrontier, isNot(contains('cell_10_10')));
    });

    // -------------------------------------------------------------------------
    // Test 14: getVisitedCells returns an immutable copy.
    // -------------------------------------------------------------------------
    test('14. getVisitedCells returns immutable copy', () {
      resolver.onLocationUpdate(0.0, 0.0);

      final cells = resolver.getVisitedCells();
      expect(cells, contains('cell_0_0'));

      // Mutating the copy must not affect the resolver's internal state.
      expect(() => (cells as dynamic).add('cell_99_99'),
          throwsUnsupportedError);
      expect(resolver.visitedCellIds, isNot(contains('cell_99_99')));
    });

    // -------------------------------------------------------------------------
    // Test 15: State changes dynamically — observed becomes hidden on player move.
    // -------------------------------------------------------------------------
    test(
        '15. state changes dynamically — observed cell becomes hidden when player moves away',
        () {
      resolver.onLocationUpdate(0.0, 0.0);
      expect(resolver.resolve('cell_0_0'), equals(FogState.observed));

      // Move far away.
      resolver.onLocationUpdate(10.0, 10.0);
      // cell_0_0 is now visited but not current or adjacent → hidden.
      expect(resolver.resolve('cell_0_0'), equals(FogState.hidden));
    });

    // -------------------------------------------------------------------------
    // Test 16: Concealed cell becomes unexplored when player moves away.
    // -------------------------------------------------------------------------
    test(
        '16. concealed cell becomes unexplored/hidden when player moves away',
        () {
      resolver.onLocationUpdate(0.0, 0.0);
      // cell_1_0 is adjacent to cell_0_0 → concealed.
      expect(resolver.resolve('cell_1_0'), equals(FogState.concealed));

      // Move far away — cell_1_0 is still in frontier (adjacent to visited
      // cell_0_0 but never visited), so it resolves as unexplored.
      resolver.onLocationUpdate(10.0, 10.0);
      expect(resolver.resolve('cell_1_0'), equals(FogState.unexplored));
    });

    // -------------------------------------------------------------------------
    // Test 17: distanceToCell returns correct Haversine distance.
    // -------------------------------------------------------------------------
    test('17. distanceToCell returns correct Haversine distance', () {
      resolver.onLocationUpdate(0.0, 0.0);

      // Center of "cell_0.3_0" is at (0.3°, 0°).
      // Haversine from (0°, 0°) to (0.3°, 0°) ≈ 33,370 m.
      final dist = resolver.distanceToCell('cell_0.3_0');
      expect(dist, closeTo(33370.0, 500.0)); // within 500 m tolerance
    });

    // -------------------------------------------------------------------------
    // Test 18: isCellWithinDetectionRadius returns true for cells within 50km.
    // -------------------------------------------------------------------------
    test(
        '18. isCellWithinDetectionRadius returns true for cells within 50km',
        () {
      resolver.onLocationUpdate(0.0, 0.0);

      // ~33 km < 50 km.
      expect(resolver.isCellWithinDetectionRadius('cell_0.3_0'), isTrue);
      // ~111 km > 50 km.
      expect(resolver.isCellWithinDetectionRadius('cell_1_0'), isFalse);
    });

    // -------------------------------------------------------------------------
    // Test 19: 50km detection — cells within radius but not frontier/visited
    //          are unexplored.
    // -------------------------------------------------------------------------
    test(
        '19. 50km detection: cells within radius but not frontier/visited are unexplored',
        () {
      resolver.onLocationUpdate(0.0, 0.0);

      // "cell_0.3_0" is ≈33 km away, not in integer-coordinate frontier.
      expect(resolver.resolve('cell_0.3_0'), equals(FogState.unexplored));

      // "cell_0.44_0" is ≈49 km away, also within detection radius.
      final dist = resolver.distanceToCell('cell_0.44_0');
      expect(dist, lessThanOrEqualTo(50000.0));
      expect(resolver.resolve('cell_0.44_0'), equals(FogState.unexplored));
    });

    // -------------------------------------------------------------------------
    // Test 20: 50km detection — cells beyond radius are undetected.
    // -------------------------------------------------------------------------
    test(
        '20. 50km detection: cells beyond radius are undetected',
        () {
      resolver.onLocationUpdate(0.0, 0.0);

      // cell_3_0 center at (3°, 0°) ≈ 333 km — well beyond 50 km.
      // Not visited, not frontier.
      expect(resolver.resolve('cell_3_0'), equals(FogState.undetected));

      // cell_0.6_0 center at (0.6°, 0°) ≈ 67 km — beyond 50 km.
      // Not in integer-coordinate frontier.
      final dist = resolver.distanceToCell('cell_0.6_0');
      expect(dist, greaterThan(50000.0));
      expect(resolver.resolve('cell_0.6_0'), equals(FogState.undetected));
    });

    // -------------------------------------------------------------------------
    // Bonus: currentCellId and currentNeighborIds accessors.
    // -------------------------------------------------------------------------
    test('currentCellId is null before any update and set after', () {
      expect(resolver.currentCellId, isNull);
      resolver.onLocationUpdate(5.0, 5.0);
      expect(resolver.currentCellId, equals('cell_5_5'));
    });

    test('currentNeighborIds contains all 8 immediate neighbors', () {
      resolver.onLocationUpdate(0.0, 0.0);
      expect(resolver.currentNeighborIds.length, equals(8));
      expect(resolver.currentNeighborIds, contains('cell_1_0'));
      expect(resolver.currentNeighborIds, contains('cell_-1_-1'));
      expect(resolver.currentNeighborIds, isNot(contains('cell_0_0')));
    });

    // -------------------------------------------------------------------------
    // Bonus: distanceToCell returns infinity before any location update.
    // -------------------------------------------------------------------------
    test('distanceToCell returns infinity before any location update', () {
      expect(resolver.distanceToCell('cell_0_0'), equals(double.infinity));
    });

    // -------------------------------------------------------------------------
    // Bonus: loadVisitedCells does not emit events.
    // -------------------------------------------------------------------------
    test('loadVisitedCells does not emit events', () {
      final events = collectEvents(resolver, () {
        resolver.loadVisitedCells({'cell_0_0', 'cell_5_5'});
      });

      expect(events, isEmpty);
    });

    // -------------------------------------------------------------------------
    // Bonus: event oldState reflects whether cell was frontier or undetected.
    // -------------------------------------------------------------------------
    test('event oldState is unexplored when entering a frontier cell', () {
      // Visit cell_0_0 — its neighbor cell_1_0 goes into frontier.
      resolver.onLocationUpdate(0.0, 0.0);

      // Now visit cell_1_0 which was in frontier (unexplored).
      final events = collectEvents(resolver, () {
        resolver.onLocationUpdate(1.0, 0.0);
      });

      expect(events.length, equals(1));
      expect(events[0].cellId, equals('cell_1_0'));
      expect(events[0].oldState, equals(FogState.unexplored));
      expect(events[0].newState, equals(FogState.observed));
    });

    test('event oldState is undetected when entering a never-detected cell', () {
      // Jump to a far cell — no prior frontier around cell_20_20.
      final events = collectEvents(resolver, () {
        resolver.onLocationUpdate(20.0, 20.0);
      });

      expect(events.length, equals(1));
      expect(events[0].cellId, equals('cell_20_20'));
      expect(events[0].oldState, equals(FogState.undetected));
      expect(events[0].newState, equals(FogState.observed));
    });
  });
}
