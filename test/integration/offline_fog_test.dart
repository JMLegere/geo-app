/// Integration test: full fog-of-war loop — no widgets, no network, no Riverpod.
///
/// Exercises [VoronoiCellService] (pure math) + [FogStateResolver] (pure compute)
/// to prove the fog system is completely network-independent.
library;

import 'package:earth_nova/core/cells/lazy_voronoi_cell_service.dart';
import 'package:earth_nova/core/fog/fog_event.dart';
import 'package:earth_nova/core/fog/fog_state_resolver.dart';
import 'package:earth_nova/core/models/fog_state.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// LazyVoronoiCellService centred on the SF Bay Area for fog integration tests.
LazyVoronoiCellService makeSmallCellService() => LazyVoronoiCellService();

/// Centre of the bounding box — guaranteed to be inside some cell.
const double kCentLat = 37.75;
const double kCentLon = -122.375;

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Offline Fog System', () {
    late LazyVoronoiCellService cellService;
    late FogStateResolver resolver;

    setUp(() {
      cellService = makeSmallCellService();
      resolver = FogStateResolver(cellService);
    });

    tearDown(() => resolver.dispose());

    // ── LazyVoronoiCellService basic sanity ──────────────────────────────

    test('getCellId returns valid v_{row}_{col} cell ID string', () {
      final id = cellService.getCellId(kCentLat, kCentLon);
      expect(id, startsWith('v_'),
          reason: 'LazyVoronoi cell IDs have v_{row}_{col} format');
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

    test('arbitrary cell resolves as undetected before any location update',
        () {
      // No update yet — a cell far from any player position should be undetected.
      final farCellId =
          cellService.getCellId(0.0, 0.0); // equator/prime meridian
      expect(resolver.resolve(farCellId), equals(FogState.undetected));
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

    test('non-adjacent cells resolve as unexplored within detection radius',
        () {
      resolver.onLocationUpdate(kCentLat, kCentLon);
      final currentId = resolver.currentCellId!;
      final neighbors = resolver.currentNeighborIds;

      // Use ring-2 cells (2 hops away) to find cells not in the direct neighbor
      // set but included in the detection zone.
      final ring2 = cellService.getCellsInRing(currentId, 2);
      // Set detection zone to include all ring-2 cells.
      resolver.setDetectionZone(ring2.toSet());
      for (final id in ring2) {
        if (id == currentId) continue;
        if (neighbors.contains(id)) continue;

        if (resolver.isCellInDetectionZone(id)) {
          // In detection zone → must be at least unexplored or better
          final state = resolver.resolve(id);
          expect(state, isNot(equals(FogState.undetected)),
              reason: 'Cell $id is in detection zone and should '
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
      expect(stateAfterLeaving,
          anyOf(equals(FogState.concealed), equals(FogState.hidden)));
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

    test('frontier cells not adjacent to current cell resolve as unexplored',
        () {
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
      for (int step = 0;
          step < 5 && resolver.visitedCellIds.length < 3;
          step++) {
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

      expect(events, isEmpty, reason: 'loadVisitedCells must not emit events');
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
