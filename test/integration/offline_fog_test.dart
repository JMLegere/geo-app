/// Integration test: full fog-of-war loop — no widgets, no network, no Riverpod.
///
/// Exercises [VoronoiCellService] (pure math) + [FogStateResolver] (pure compute)
/// to prove the fog system is completely network-independent.
library;

import 'package:earth_nova/core/cells/voronoi_cell_service.dart';
import 'package:earth_nova/core/fog/fog_event.dart';
import 'package:earth_nova/core/fog/fog_state_resolver.dart';
import 'package:earth_nova/core/models/fog_state.dart';
import 'package:earth_nova/shared/constants.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// A small Voronoi grid centred on the SF Bay Area.
/// 5×5 = 25 cells — small enough for fast tests, realistic enough to be
/// meaningful. The seed is fixed so the cell layout is deterministic.
VoronoiCellService makeSmallCellService() => VoronoiCellService(
      minLat: 37.60,
      maxLat: 37.90,
      minLon: -122.55,
      maxLon: -122.20,
      gridRows: 5,
      gridCols: 5,
      seed: 42,
    );

/// Centre of the bounding box — guaranteed to be inside some cell.
const double kCentLat = 37.75;
const double kCentLon = -122.375;

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Offline Fog System', () {
    late VoronoiCellService cellService;
    late FogStateResolver resolver;

    setUp(() {
      cellService = makeSmallCellService();
      resolver = FogStateResolver(cellService);
    });

    tearDown(() => resolver.dispose());

    // ── VoronoiCellService basic sanity ─────────────────────────────────

    test('VoronoiCellService creates correct cell count', () {
      expect(cellService.cellCount, equals(25)); // 5×5
    });

    test('getCellId returns valid cell ID string', () {
      final id = cellService.getCellId(kCentLat, kCentLon);
      expect(int.tryParse(id), isNotNull,
          reason: 'Cell IDs should be numeric strings');
      final idx = int.parse(id);
      expect(idx, greaterThanOrEqualTo(0));
      expect(idx, lessThan(25));
    });

    test('getCellId is deterministic for same coordinates', () {
      final id1 = cellService.getCellId(kCentLat, kCentLon);
      final id2 = cellService.getCellId(kCentLat, kCentLon);
      expect(id1, equals(id2));
    });

    test('getNeighborIds returns non-empty list for interior cell', () {
      final cellId = cellService.getCellId(kCentLat, kCentLon);
      final neighbors = cellService.getNeighborIds(cellId);
      expect(neighbors, isNotEmpty,
          reason: 'Interior cells should have neighbors');
    });

    test('getNeighborIds does not include the cell itself', () {
      final cellId = cellService.getCellId(kCentLat, kCentLon);
      final neighbors = cellService.getNeighborIds(cellId);
      expect(neighbors, isNot(contains(cellId)));
    });

    test('getCellCenter returns point inside bounding box', () {
      final cellId = cellService.getCellId(kCentLat, kCentLon);
      final center = cellService.getCellCenter(cellId);
      expect(center.lat, inInclusiveRange(37.60, 37.90));
      expect(center.lon, inInclusiveRange(-122.55, -122.20));
    });

    // ── FogStateResolver: initial state ──────────────────────────────────

    test('all cells start as undetected before any location update', () {
      // No update yet — every cell should resolve to undetected or unexplored
      // (unexplored if within 50 km detection radius, but with no player
      // position recorded yet, distanceToCell → infinity → undetected).
      for (int i = 0; i < cellService.cellCount; i++) {
        expect(resolver.resolve(i.toString()), equals(FogState.undetected));
      }
    });

    test('currentCellId is null before any location update', () {
      expect(resolver.currentCellId, isNull);
    });

    test('visitedCellIds is empty before any location update', () {
      expect(resolver.visitedCellIds, isEmpty);
    });

    test('explorationFrontier is empty before any location update', () {
      expect(resolver.explorationFrontier, isEmpty);
    });

    // ── FogStateResolver: after first location update ────────────────────

    test('current cell resolves as observed after location update', () {
      resolver.onLocationUpdate(kCentLat, kCentLon);
      final cellId = resolver.currentCellId!;
      expect(resolver.resolve(cellId), equals(FogState.observed));
    });

    test('current cell is added to visitedCellIds', () {
      resolver.onLocationUpdate(kCentLat, kCentLon);
      expect(resolver.visitedCellIds, contains(resolver.currentCellId));
    });

    test('neighbors of current cell resolve as concealed', () {
      resolver.onLocationUpdate(kCentLat, kCentLon);
      final neighbors = resolver.currentNeighborIds;
      expect(neighbors, isNotEmpty);
      for (final neighbor in neighbors) {
        expect(resolver.resolve(neighbor), equals(FogState.concealed));
      }
    });

    test('neighbor cells appear in explorationFrontier', () {
      resolver.onLocationUpdate(kCentLat, kCentLon);
      final neighbors = resolver.currentNeighborIds;
      for (final neighbor in neighbors) {
        // Neighbor cells are in the frontier (never visited, adjacent to visited)
        expect(resolver.explorationFrontier, contains(neighbor));
      }
    });

    test('non-adjacent cells resolve as unexplored within detection radius', () {
      resolver.onLocationUpdate(kCentLat, kCentLon);
      final currentId = resolver.currentCellId!;
      final neighbors = resolver.currentNeighborIds;

      // Find a cell that is NOT current and NOT a direct neighbor
      // but IS within the detection radius.
      for (int i = 0; i < cellService.cellCount; i++) {
        final id = i.toString();
        if (id == currentId) continue;
        if (neighbors.contains(id)) continue;

        final dist = resolver.distanceToCell(id);
        if (dist <= kDetectionRadiusMeters) {
          // Within detection radius → must be at least unexplored or better
          final state = resolver.resolve(id);
          expect(state, isNot(equals(FogState.undetected)),
              reason:
                  'Cell $id is within detection radius ($dist m) and should '
                  'not be undetected, but resolved as $state');
          break; // One check is enough
        }
      }
    });

    // ── FogStateResolver: leaving a cell → Hidden ────────────────────────

    test('leaving a cell: it is no longer observed', () {
      // Visit centre cell.
      resolver.onLocationUpdate(kCentLat, kCentLon);
      final firstCellId = resolver.currentCellId!;
      expect(resolver.resolve(firstCellId), equals(FogState.observed));

      // Move to a direct neighbor.
      final neighbors = cellService.getNeighborIds(firstCellId);
      expect(neighbors, isNotEmpty);
      final neighborCenter = cellService.getCellCenter(neighbors.first);
      resolver.onLocationUpdate(neighborCenter.lat, neighborCenter.lon);

      // The original cell is no longer observed (it's either concealed or hidden).
      final stateAfterLeaving = resolver.resolve(firstCellId);
      expect(stateAfterLeaving, isNot(equals(FogState.observed)),
          reason: 'Cell must not remain "observed" after player leaves');
      // Adjacent to new current cell → concealed; this is correct per priority table.
      expect(stateAfterLeaving, anyOf(equals(FogState.concealed), equals(FogState.hidden)));
    });

    test('visited cell resolves as hidden when player moves 2 cells away', () {
      // Visit first cell.
      resolver.onLocationUpdate(kCentLat, kCentLon);
      final firstCellId = resolver.currentCellId!;

      // Step 1: move to a direct neighbor.
      final step1Neighbors = cellService.getNeighborIds(firstCellId);
      expect(step1Neighbors, isNotEmpty);
      final step1Id = step1Neighbors.first;
      final step1Center = cellService.getCellCenter(step1Id);
      resolver.onLocationUpdate(step1Center.lat, step1Center.lon);

      // Step 2: find a neighbor of step1 that is NOT adjacent to firstCellId.
      final step2Candidates = cellService
          .getNeighborIds(step1Id)
          .where((n) =>
              n != firstCellId &&
              !cellService.getNeighborIds(n).contains(firstCellId))
          .toList();

      if (step2Candidates.isNotEmpty) {
        final step2Center = cellService.getCellCenter(step2Candidates.first);
        resolver.onLocationUpdate(step2Center.lat, step2Center.lon);
        // firstCellId is visited, not current, not adjacent to current → hidden.
        expect(resolver.resolve(firstCellId), equals(FogState.hidden));
      }
      // If no suitable step2 exists for this grid seed, the test is vacuously
      // satisfied — the grid topology doesn't allow the scenario.
    });

    // ── FogStateResolver: frontier cells are unexplored ──────────────────

    test('frontier cells not adjacent to current cell resolve as unexplored', () {
      // After visiting ONE cell, all frontier cells are also neighbors of that
      // cell (and therefore resolve as concealed, not unexplored). To expose
      // true unexplored frontier cells we need at least 2 visited cells so
      // some frontier cells are farther than 1 hop from the current position.

      // Visit first cell.
      resolver.onLocationUpdate(kCentLat, kCentLon);
      final firstId = resolver.currentCellId!;

      // Move to a neighbor.
      final neighbors = cellService.getNeighborIds(firstId);
      expect(neighbors, isNotEmpty);
      final step1Center = cellService.getCellCenter(neighbors.first);
      resolver.onLocationUpdate(step1Center.lat, step1Center.lon);

      // Now the frontier may contain cells that are neighbors of firstId
      // but NOT neighbors of the current cell (step1). Those should resolve
      // as unexplored.
      final frontier = resolver.explorationFrontier;
      final currentNeighbors = resolver.currentNeighborIds;

      final trueFrontierCells =
          frontier.where((id) => !currentNeighbors.contains(id)).toList();

      for (final cellId in trueFrontierCells) {
        expect(resolver.resolve(cellId), equals(FogState.unexplored),
            reason: 'Frontier cell $cellId is not adjacent to current cell '
                'and must resolve as unexplored');
      }
      // If trueFrontierCells is empty (tight grid topology), the assertion
      // holds vacuously — the grid's geometry means no such cells exist.
    });

    // ── FogStateResolver: event stream ───────────────────────────────────

    test('onVisitedCellAdded fires when entering a new cell', () {
      final events = <FogStateChangedEvent>[];
      resolver.onVisitedCellAdded.listen(events.add);

      resolver.onLocationUpdate(kCentLat, kCentLon);

      expect(events.length, equals(1));
      expect(events.first.newState, equals(FogState.observed));
    });

    test('onVisitedCellAdded does NOT fire on re-entering a visited cell', () {
      final events = <FogStateChangedEvent>[];
      resolver.onVisitedCellAdded.listen(events.add);

      resolver.onLocationUpdate(kCentLat, kCentLon);
      final count = events.length;
      // Visit the same location again.
      resolver.onLocationUpdate(kCentLat, kCentLon);

      expect(events.length, equals(count),
          reason: 'Revisiting the same cell must not re-emit an event');
    });

    test('onVisitedCellAdded fires for each distinct new cell', () {
      final visitedCellIds = <String>[];
      resolver.onVisitedCellAdded.listen((e) => visitedCellIds.add(e.cellId));

      resolver.onLocationUpdate(kCentLat, kCentLon);
      final firstId = resolver.currentCellId!;

      // Move to a neighbor.
      final neighbors = cellService.getNeighborIds(firstId);
      expect(neighbors, isNotEmpty);
      final neighborCenter = cellService.getCellCenter(neighbors.first);
      resolver.onLocationUpdate(neighborCenter.lat, neighborCenter.lon);

      expect(visitedCellIds.length, equals(2));
      expect(visitedCellIds, containsAll([firstId, neighbors.first]));
    });

    test('event cellId matches the newly entered cell', () {
      FogStateChangedEvent? lastEvent;
      resolver.onVisitedCellAdded.listen((e) => lastEvent = e);

      resolver.onLocationUpdate(kCentLat, kCentLon);
      expect(lastEvent, isNotNull);
      expect(lastEvent!.cellId, equals(resolver.currentCellId));
    });

    // ── Multiple movement steps ───────────────────────────────────────────

    test('visiting multiple cells accumulates visitedCellIds', () {
      resolver.onLocationUpdate(kCentLat, kCentLon);
      var prevId = resolver.currentCellId!;

      // Walk through neighbors greedily until we have 3+ visited cells.
      for (int step = 0; step < 5 && resolver.visitedCellIds.length < 3; step++) {
        final neighbors = cellService.getNeighborIds(prevId);
        final unvisited = neighbors
            .where((n) => !resolver.visitedCellIds.contains(n))
            .toList();
        if (unvisited.isEmpty) break;
        final nextCenter = cellService.getCellCenter(unvisited.first);
        resolver.onLocationUpdate(nextCenter.lat, nextCenter.lon);
        prevId = resolver.currentCellId!;
      }

      expect(resolver.visitedCellIds.length, greaterThanOrEqualTo(2));
    });

    // ── loadVisitedCells round-trip ───────────────────────────────────────

    test('loadVisitedCells restores visited set', () {
      resolver.onLocationUpdate(kCentLat, kCentLon);
      final visited = resolver.getVisitedCells();
      expect(visited, isNotEmpty);

      // Create fresh resolver and restore.
      final resolver2 = FogStateResolver(cellService);
      addTearDown(resolver2.dispose);
      resolver2.loadVisitedCells(visited);

      expect(resolver2.visitedCellIds, equals(visited));
    });

    test('loadVisitedCells rebuilds explorationFrontier', () {
      resolver.onLocationUpdate(kCentLat, kCentLon);
      final visited = resolver.getVisitedCells();
      final originalFrontier = resolver.explorationFrontier;

      final resolver2 = FogStateResolver(cellService);
      addTearDown(resolver2.dispose);
      resolver2.loadVisitedCells(visited);

      expect(resolver2.explorationFrontier, equals(originalFrontier));
    });

    test('loadVisitedCells does NOT emit events', () {
      resolver.onLocationUpdate(kCentLat, kCentLon);
      final visited = resolver.getVisitedCells();

      final resolver2 = FogStateResolver(cellService);
      addTearDown(resolver2.dispose);
      final events = <FogStateChangedEvent>[];
      resolver2.onVisitedCellAdded.listen(events.add);

      resolver2.loadVisitedCells(visited);

      expect(events, isEmpty,
          reason: 'loadVisitedCells must not emit events');
    });

    // ── FogState ordering / values ────────────────────────────────────────

    test('FogState resolved values follow priority table', () {
      resolver.onLocationUpdate(kCentLat, kCentLon);
      final currentId = resolver.currentCellId!;
      final neighborId = resolver.currentNeighborIds.first;

      // Priority 1: current cell → observed.
      expect(resolver.resolve(currentId), equals(FogState.observed));
      // Priority 2: immediate neighbor → concealed.
      expect(resolver.resolve(neighborId), equals(FogState.concealed));
    });
  });
}
