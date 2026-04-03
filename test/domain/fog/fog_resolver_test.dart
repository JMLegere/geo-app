import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/domain/fog/fog_event.dart';
import 'package:earth_nova/domain/fog/fog_resolver.dart';
import 'package:earth_nova/models/fog_state.dart';

import '../../fixtures/test_helpers.dart';

void main() {
  late MockCellService cellService;
  late FogStateResolver resolver;

  setUp(() {
    cellService = buildStarGrid();
    resolver = FogStateResolver(cellService);
  });

  tearDown(() {
    resolver.dispose();
  });

  // ─── resolve() priority ───────────────────────────────────────────────────

  group('resolve() priority', () {
    test('returns present when cellId is the current cell', () {
      resolver.onLocationUpdate(kTestLat, kTestLon); // lands on kTestCellA
      expect(resolver.resolve(kTestCellA), FogState.present);
    });

    test('returns explored when cell was previously visited and player left',
        () {
      resolver.onLocationUpdate(kTestLat, kTestLon); // visits A
      // Move player to B — A becomes explored, B becomes present.
      resolver.onLocationUpdate(kTestLat + 0.01, kTestLon); // visits B
      expect(resolver.resolve(kTestCellA), FogState.explored);
    });

    test('returns nearby for a cell adjacent to the current cell', () {
      // Move to B so A is not "current" and B is current.
      resolver.onLocationUpdate(kTestLat + 0.01, kTestLon); // visits B
      // A is a neighbor of B — should be nearby.
      expect(resolver.resolve(kTestCellA), FogState.nearby);
    });

    test('returns detected for cells on the exploration frontier', () {
      // Visit A → frontier {B,C,D}. Then move to B → B is present, A is explored.
      // C and D are still on the frontier but are NOT neighbors of B (in the star
      // topology B only knows A). So C/D resolve as detected via frontier.
      resolver.onLocationUpdate(kTestLat, kTestLon); // visits A
      resolver.onLocationUpdate(
          kTestLat + 0.01, kTestLon); // visits B (B's neighbors: [A])
      expect(resolver.resolve(kTestCellC), FogState.detected);
      expect(resolver.resolve(kTestCellD), FogState.detected);
    });

    test('returns unknown for a far unvisited cell with no prior detection',
        () {
      // Player visits A. 'cell_far' was never mentioned.
      resolver.onLocationUpdate(kTestLat, kTestLon);
      expect(resolver.resolve('cell_far'), FogState.unknown);
    });

    test('present takes priority over explored for the current cell', () {
      // Visit A, then move away (A → explored), then come back (A → present).
      resolver.onLocationUpdate(kTestLat, kTestLon);
      resolver.onLocationUpdate(kTestLat + 0.01, kTestLon);
      resolver.onLocationUpdate(kTestLat, kTestLon); // back to A
      expect(resolver.resolve(kTestCellA), FogState.present);
    });

    test('explored takes priority over nearby for a visited adjacent cell', () {
      // Visit A, move to B. A is visited AND is a neighbor of B.
      // explored beats nearby — priority table: 2 > 3.
      resolver.onLocationUpdate(kTestLat, kTestLon); // A visited
      resolver.onLocationUpdate(kTestLat + 0.01, kTestLon); // B visited
      // A: visited (explored=priority2) AND neighbor of B (nearby=priority3)
      // → must resolve as explored.
      expect(resolver.resolve(kTestCellA), FogState.explored);
    });

    test('returns detected for cells explicitly set in the detection zone', () {
      resolver.setDetectionZone({'cell_zone_1', 'cell_zone_2'});
      expect(resolver.resolve('cell_zone_1'), FogState.detected);
      expect(resolver.resolve('cell_zone_2'), FogState.detected);
    });

    test(
        'once detected a cell never reverts to unknown even after detection zone cleared',
        () {
      resolver.setDetectionZone({'cell_zone_x'});
      // Resolve to register it.
      final first = resolver.resolve('cell_zone_x');
      expect(first, FogState.detected);
      // Replace zone with a new set that excludes it.
      resolver.setDetectionZone({'cell_other'});
      // everDetectedCellIds should still cover it.
      expect(resolver.resolve('cell_zone_x'), FogState.detected);
    });
  });

  // ─── onLocationUpdate() stream ───────────────────────────────────────────

  group('onLocationUpdate() stream', () {
    test('emits fog change event when player moves to a new cell', () {
      final events = <FogStateChangedEvent>[];
      resolver.onVisitedCellAdded.listen(events.add);

      resolver.onLocationUpdate(kTestLat, kTestLon); // first visit to A

      expect(events, hasLength(1));
      expect(events.first.cellId, kTestCellA);
    });

    test('stream is synchronous — events received during the same call', () {
      // sync: true means the listener fires inline with the add() call.
      FogStateChangedEvent? received;
      resolver.onVisitedCellAdded.listen((e) => received = e);

      // Before update: nothing yet.
      expect(received, isNull);
      resolver.onLocationUpdate(kTestLat, kTestLon);
      // After: should already be populated (no await needed).
      expect(received, isNotNull);
      expect(received!.cellId, kTestCellA);
    });

    test('marks the current cell as present', () {
      final events = <FogStateChangedEvent>[];
      resolver.onVisitedCellAdded.listen(events.add);

      resolver.onLocationUpdate(kTestLat, kTestLon);

      expect(events.first.newState, FogState.present);
    });

    test('marks previously visited cell as explored after player moves away',
        () {
      resolver.onLocationUpdate(kTestLat, kTestLon); // visits A
      resolver.onLocationUpdate(kTestLat + 0.01, kTestLon); // visits B

      // After moving to B, A is still visited — resolve must return explored.
      expect(resolver.resolve(kTestCellA), FogState.explored);
      expect(resolver.resolve(kTestCellB), FogState.present);
    });

    test('does not emit event when revisiting a cell', () {
      final events = <FogStateChangedEvent>[];
      resolver.onVisitedCellAdded.listen(events.add);

      resolver.onLocationUpdate(kTestLat, kTestLon); // first visit
      resolver.onLocationUpdate(kTestLat, kTestLon); // same cell again

      expect(events, hasLength(1)); // only one emit
    });

    test('adds unvisited neighbors of new cell to exploration frontier', () {
      resolver.onLocationUpdate(kTestLat, kTestLon); // visits A
      // A's neighbors are B, C, D → all should be on frontier.
      expect(resolver.explorationFrontier,
          containsAll([kTestCellB, kTestCellC, kTestCellD]));
    });
  });

  // ─── visitedCellIds tracking ──────────────────────────────────────────────

  group('visitedCellIds tracking', () {
    test('loadVisitedCells seeds the initial visited set', () {
      resolver.loadVisitedCells({kTestCellA, kTestCellB});
      expect(resolver.visitedCellIds, containsAll([kTestCellA, kTestCellB]));
    });

    test('visiting a cell physically adds it to visitedCellIds', () {
      resolver.onLocationUpdate(kTestLat, kTestLon); // visits A
      expect(resolver.visitedCellIds, contains(kTestCellA));
    });

    test('visitCellRemotely adds frontier cell to visitedCellIds', () {
      resolver.onLocationUpdate(
          kTestLat, kTestLon); // visits A → frontier {B,C,D}
      resolver.visitCellRemotely(kTestCellB);
      expect(resolver.visitedCellIds, contains(kTestCellB));
    });

    test('visitCellRemotely does not change currentCellId', () {
      resolver.onLocationUpdate(kTestLat, kTestLon); // A is current
      resolver.visitCellRemotely(kTestCellB);
      expect(resolver.currentCellId, kTestCellA); // unchanged
    });

    test('visitCellRemotely emits explored (not present) state', () {
      resolver.onLocationUpdate(kTestLat, kTestLon); // visits A
      final events = <FogStateChangedEvent>[];
      resolver.onVisitedCellAdded.listen(events.add);

      resolver.visitCellRemotely(kTestCellB);

      expect(events, hasLength(1));
      expect(events.first.newState, FogState.explored);
    });

    test('visitCellRemotely throws for cells not on the frontier', () {
      resolver.onLocationUpdate(kTestLat, kTestLon);
      expect(
        () => resolver.visitCellRemotely('cell_far'),
        throwsArgumentError,
      );
    });

    test('visitCellRemotely is a no-op for already-visited cells', () {
      resolver.onLocationUpdate(kTestLat, kTestLon); // visits A
      final events = <FogStateChangedEvent>[];
      resolver.onVisitedCellAdded.listen(events.add);

      resolver.visitCellRemotely(kTestCellA); // already visited

      expect(events, isEmpty); // no duplicate emit
    });
  });

  // ─── frontier management ─────────────────────────────────────────────────

  group('frontier management', () {
    test('newly visited cell neighbors become detected via frontier', () {
      // Visit A, then move to B. B is present, A is explored.
      // C and D are on A's frontier and are NOT neighbors of B → detected.
      resolver.onLocationUpdate(kTestLat, kTestLon); // visits A
      resolver.onLocationUpdate(kTestLat + 0.01, kTestLon); // visits B
      expect(resolver.resolve(kTestCellC), FogState.detected);
      expect(resolver.resolve(kTestCellD), FogState.detected);
    });

    test('frontier shrinks when a frontier cell is visited', () {
      resolver.onLocationUpdate(
          kTestLat, kTestLon); // visits A → frontier {B,C,D}
      resolver.onLocationUpdate(kTestLat + 0.01, kTestLon); // visits B
      // B should no longer be on the frontier.
      expect(resolver.explorationFrontier, isNot(contains(kTestCellB)));
    });

    test('loadVisitedCells reconstructs frontier correctly from scratch', () {
      // Simulate loading saved visited cells: just A.
      resolver.loadVisitedCells({kTestCellA});
      // B, C, D should be on the frontier.
      expect(resolver.explorationFrontier,
          containsAll([kTestCellB, kTestCellC, kTestCellD]));
    });

    test('frontier does not include cells already in visitedCellIds', () {
      // Visit A and B. Their common neighbors should not include A or B.
      resolver.onLocationUpdate(kTestLat, kTestLon); // visits A
      resolver.onLocationUpdate(kTestLat + 0.01, kTestLon); // visits B
      expect(resolver.explorationFrontier, isNot(contains(kTestCellA)));
      expect(resolver.explorationFrontier, isNot(contains(kTestCellB)));
    });
  });
}
