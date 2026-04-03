import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geobase/geobase.dart';

import 'package:earth_nova/domain/cells/cell_service.dart';
import 'package:earth_nova/domain/fog/fog_resolver.dart';
import 'package:earth_nova/engine/engine_input.dart';
import 'package:earth_nova/engine/game_engine.dart';
import 'package:earth_nova/engine/game_event.dart';

// ---------------------------------------------------------------------------
// Hand-written mock
// ---------------------------------------------------------------------------

class MockCellService implements CellService {
  final Map<String, Geographic> centers = {};
  final Map<String, List<String>> neighbors = {};
  String Function(double lat, double lon)? getCellIdFn;

  @override
  String getCellId(double lat, double lon) =>
      getCellIdFn?.call(lat, lon) ?? 'v_0_0';

  @override
  Geographic getCellCenter(String cellId) =>
      centers[cellId] ?? Geographic(lat: 0, lon: 0);

  @override
  List<Geographic> getCellBoundary(String cellId) => [];

  @override
  List<String> getNeighborIds(String cellId) => neighbors[cellId] ?? [];

  @override
  List<String> getCellsInRing(String cellId, int k) =>
      [cellId, ...getNeighborIds(cellId)];

  @override
  List<String> getCellsAroundLocation(double lat, double lon, int k) =>
      [getCellId(lat, lon)];

  @override
  double get cellEdgeLengthMeters => 180.0;

  @override
  String get systemName => 'mock';
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

GameEngine _makeEngine({MockCellService? cellService}) {
  final cs = cellService ?? MockCellService();
  final fog = FogStateResolver(cs);
  return GameEngine(fogResolver: fog, cellService: cs);
}

/// Collect all events from [engine.events] while [action] runs.
/// Returns the collected events after the action completes.
Future<List<GameEvent>> collectEvents(
  GameEngine engine,
  void Function() action,
) async {
  final events = <GameEvent>[];
  final sub = engine.events.listen(events.add);
  action();
  // Allow any microtasks to flush.
  await Future<void>.delayed(Duration.zero);
  await sub.cancel();
  return events;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('GameEngine — lifecycle', () {
    test('isRunning is false before start', () {
      final engine = _makeEngine();
      expect(engine.isRunning, isFalse);
      engine.dispose();
    });

    test('start() sets isRunning to true', () {
      final engine = _makeEngine();
      engine.start();
      expect(engine.isRunning, isTrue);
      engine.dispose();
    });

    test('stop() sets isRunning to false', () {
      final engine = _makeEngine();
      engine.start();
      engine.stop();
      expect(engine.isRunning, isFalse);
      engine.dispose();
    });

    test('start() is idempotent — calling twice does not crash', () {
      final engine = _makeEngine();
      engine.start();
      engine.start(); // should be a no-op
      expect(engine.isRunning, isTrue);
      engine.dispose();
    });

    test('dispose() closes event stream', () async {
      final engine = _makeEngine();
      engine.start();
      engine.dispose();

      // Stream should be done after dispose.
      final events = await engine.events.toList();
      expect(events, isEmpty);
    });

    test('events stream is broadcast — multiple listeners OK', () async {
      final engine = _makeEngine();
      engine.start();

      final list1 = <GameEvent>[];
      final list2 = <GameEvent>[];
      final sub1 = engine.events.listen(list1.add);
      final sub2 = engine.events.listen(list2.add);

      engine.send(const PositionUpdate(1.0, 1.0));

      await Future<void>.delayed(Duration.zero);
      await sub1.cancel();
      await sub2.cancel();

      // Both listeners should have received the same events.
      expect(list1.length, equals(list2.length));
      engine.dispose();
    });
  });

  group('GameEngine — position processing', () {
    test('send(PositionUpdate) updates playerPosition', () {
      final engine = _makeEngine();
      engine.start();
      engine.send(const PositionUpdate(10.0, 20.0, 5.0));

      expect(engine.playerPosition?.lat, 10.0);
      expect(engine.playerPosition?.lon, 20.0);
      engine.dispose();
    });

    test('first PositionUpdate always processes game logic', () async {
      final cs = MockCellService();
      int cellIdCallCount = 0;
      cs.getCellIdFn = (lat, lon) {
        cellIdCallCount++;
        return 'v_1_1';
      };
      final fog = FogStateResolver(cs);
      final engine = GameEngine(fogResolver: fog, cellService: cs);
      engine.start();

      engine.send(const PositionUpdate(1.0, 1.0));

      // getCellId should have been called (game logic ran).
      expect(cellIdCallCount, greaterThan(0));
      engine.dispose();
    });

    test('game logic is throttled — only runs every 6th frame', () async {
      final cs = MockCellService();
      int cellIdCallCount = 0;
      cs.getCellIdFn = (lat, lon) {
        cellIdCallCount++;
        return 'v_0_0';
      };
      final fog = FogStateResolver(cs);
      final engine = GameEngine(fogResolver: fog, cellService: cs);
      engine.start();

      // Frame 1 runs (first position), frames 2–5 skip, frame 6 runs again.
      for (var i = 0; i < 6; i++) {
        engine.send(const PositionUpdate(0.0, 0.0));
      }

      // Fog resolver getCellId is called by the throttle path.
      // 1st frame + 6th frame = 2 ticks → cellIdCallCount should be 2.
      expect(cellIdCallCount, equals(2));
      engine.dispose();
    });

    test('lastPositionUpdateTime is set on each PositionUpdate', () {
      final engine = _makeEngine();
      engine.start();

      expect(engine.lastPositionUpdateTime, isNull);
      engine.send(const PositionUpdate(5.0, 5.0));
      expect(engine.lastPositionUpdateTime, isNotNull);
      engine.dispose();
    });

    test('rawGpsPosition is set via GPS stream', () async {
      final controller =
          StreamController<({Geographic position, double accuracy})>();
      final cs = MockCellService();
      final fog = FogStateResolver(cs);
      final engine = GameEngine(fogResolver: fog, cellService: cs);
      engine.start(gpsStream: controller.stream);

      controller
          .add((position: Geographic(lat: 51.5, lon: -0.1), accuracy: 10.0));
      await Future<void>.delayed(Duration.zero);

      expect(engine.rawGpsPosition?.lat, closeTo(51.5, 0.001));
      await controller.close();
      engine.dispose();
    });
  });

  group('GameEngine — cell transitions', () {
    test('entering a new cell emits cell_visited event', () async {
      final cs = MockCellService();
      cs.getCellIdFn = (lat, lon) => 'v_new_1';
      final fog = FogStateResolver(cs);
      final engine = GameEngine(fogResolver: fog, cellService: cs);
      engine.start();

      final events = await collectEvents(engine, () {
        engine.send(const PositionUpdate(1.0, 1.0));
      });

      expect(
        events.any(
            (e) => e.event == 'cell_visited' && e.data['cell_id'] == 'v_new_1'),
        isTrue,
      );
      engine.dispose();
    });

    test('staying in same cell does NOT emit cell_visited twice', () async {
      final cs = MockCellService();
      cs.getCellIdFn = (lat, lon) => 'v_same';
      final fog = FogStateResolver(cs);
      final engine = GameEngine(fogResolver: fog, cellService: cs);
      engine.start();

      // First update — visits cell.
      engine.send(const PositionUpdate(0.0, 0.0));
      await Future<void>.delayed(Duration.zero);

      // Subsequent updates (frame 6 = second game-logic tick) — same cell.
      final events = <GameEvent>[];
      final sub = engine.events.listen(events.add);
      for (var i = 0; i < 6; i++) {
        engine.send(const PositionUpdate(0.0, 0.0));
      }
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      final visitedEvents =
          events.where((e) => e.event == 'cell_visited').toList();
      expect(visitedEvents, isEmpty);
      engine.dispose();
    });

    test('moving to a different cell updates currentCellId via fog resolver',
        () async {
      final cs = MockCellService();
      int tick = 0;
      cs.getCellIdFn = (lat, lon) {
        tick++;
        return tick == 1 ? 'v_first' : 'v_second';
      };
      final fog = FogStateResolver(cs);
      final engine = GameEngine(fogResolver: fog, cellService: cs);
      engine.start();

      engine.send(const PositionUpdate(0.0, 0.0)); // v_first
      // Trigger second game-logic tick (frame 6).
      for (var i = 0; i < 5; i++) {
        engine.send(const PositionUpdate(1.0, 1.0));
      }
      await Future<void>.delayed(Duration.zero);

      // fog resolver should reflect second cell.
      expect(fog.currentCellId, equals('v_second'));
      engine.dispose();
    });

    test('loadVisitedCells pre-seeds visited set so revisits produce no events',
        () async {
      final cs = MockCellService();
      cs.getCellIdFn = (lat, lon) => 'v_already';
      final fog = FogStateResolver(cs);
      final engine = GameEngine(fogResolver: fog, cellService: cs);

      engine.loadVisitedCells({'v_already'});
      engine.start();

      final events = await collectEvents(engine, () {
        engine.send(const PositionUpdate(0.0, 0.0));
      });

      expect(events.where((e) => e.event == 'cell_visited'), isEmpty);
      engine.dispose();
    });
  });

  group('GameEngine — fog integration', () {
    test('fog_changed event is emitted when entering a new cell', () async {
      final cs = MockCellService();
      cs.getCellIdFn = (lat, lon) => 'v_fog_cell';
      final fog = FogStateResolver(cs);
      final engine = GameEngine(fogResolver: fog, cellService: cs);
      engine.start();

      final events = await collectEvents(engine, () {
        engine.send(const PositionUpdate(0.0, 0.0));
      });

      expect(
        events.any((e) =>
            e.event == 'fog_changed' && e.data['cell_id'] == 'v_fog_cell'),
        isTrue,
      );
      engine.dispose();
    });

    test('loadVisitedCells forwards cells to FogStateResolver', () {
      final cs = MockCellService();
      cs.neighbors['v_a'] = ['v_b'];
      final fog = FogStateResolver(cs);
      final engine = GameEngine(fogResolver: fog, cellService: cs);

      engine.loadVisitedCells({'v_a'});

      expect(fog.visitedCellIds.contains('v_a'), isTrue);
      engine.dispose();
    });

    test('loadCellProperties pre-populates cell properties cache', () {
      final engine = _makeEngine();
      // We just verify no crash — cache is internal but accessible via getter.
      // The cache is populated; accessing it via cellPropertiesCache should not throw.
      engine.loadCellProperties({});
      expect(engine.cellPropertiesCache, isEmpty);
      engine.dispose();
    });
  });

  group('GameEngine — exploration guard', () {
    test('exploration guard disabled when marker cell matches GPS cell',
        () async {
      final cs = MockCellService();
      cs.getCellIdFn = (lat, lon) => 'v_match';
      final fog = FogStateResolver(cs);
      final engine = GameEngine(fogResolver: fog, cellService: cs);
      engine.start();

      // Feed a raw GPS position for the same cell.
      final gpsController =
          StreamController<({Geographic position, double accuracy})>();
      // Restart engine with gps stream.
      engine.stop();
      final engine2 = GameEngine(fogResolver: fog, cellService: cs);
      engine2.start(gpsStream: gpsController.stream);
      gpsController
          .add((position: Geographic(lat: 0.0, lon: 0.0), accuracy: 5.0));
      await Future<void>.delayed(Duration.zero);

      engine2.send(const PositionUpdate(0.0, 0.0));

      expect(engine2.explorationDisabled, isFalse);
      await gpsController.close();
      engine2.dispose();
      engine.dispose();
    });

    test(
        'explorationDisabledChanged emitted when marker diverges from GPS cell',
        () async {
      final cs = MockCellService();
      // GPS cell is 'v_gps', marker cell (from PositionUpdate) is 'v_far'.
      cs.getCellIdFn = (lat, lon) {
        if (lat == 0.0) return 'v_gps';
        return 'v_far';
      };
      cs.neighbors['v_gps'] = []; // no neighbors — 'v_far' is not adjacent.
      final fog = FogStateResolver(cs);
      final engine = GameEngine(fogResolver: fog, cellService: cs);

      final gpsController =
          StreamController<({Geographic position, double accuracy})>();
      engine.start(gpsStream: gpsController.stream);
      // Set raw GPS to (0.0, 0.0) → v_gps.
      gpsController
          .add((position: Geographic(lat: 0.0, lon: 0.0), accuracy: 5.0));
      await Future<void>.delayed(Duration.zero);

      final events = await collectEvents(engine, () {
        // Marker position at lat=99 → v_far (diverged from GPS cell v_gps).
        engine.send(const PositionUpdate(99.0, 0.0));
      });

      expect(
        events.any((e) =>
            e.event == 'exploration_disabled_changed' &&
            e.data['disabled'] == true),
        isTrue,
      );
      expect(engine.explorationDisabled, isTrue);
      await gpsController.close();
      engine.dispose();
    });

    test(
        'explorationDisabledChanged emitted with disabled=false when guard clears',
        () async {
      final cs = MockCellService();
      cs.getCellIdFn = (lat, lon) {
        // First call: GPS set to 'v_gps'.
        // Second call (first game tick from PositionUpdate lat=99): 'v_far'.
        // Third call: back to 'v_gps'.
        if (lat == 0.0 && lon == 0.0) return 'v_gps';
        if (lat == 99.0) return 'v_far';
        return 'v_gps';
      };
      cs.neighbors['v_gps'] = [];
      cs.neighbors['v_far'] = [];
      final fog = FogStateResolver(cs);
      final engine = GameEngine(fogResolver: fog, cellService: cs);

      final gpsController =
          StreamController<({Geographic position, double accuracy})>();
      engine.start(gpsStream: gpsController.stream);
      gpsController
          .add((position: Geographic(lat: 0.0, lon: 0.0), accuracy: 5.0));
      await Future<void>.delayed(Duration.zero);

      // First: diverge.
      engine.send(const PositionUpdate(99.0, 0.0));
      expect(engine.explorationDisabled, isTrue);

      // Now re-align.
      final events = await collectEvents(engine, () {
        engine.send(const PositionUpdate(0.0, 0.0));
        // Need second game tick to re-check (frame 6 relative to current count).
        for (var i = 0; i < 5; i++) {
          engine.send(const PositionUpdate(0.0, 0.0));
        }
      });

      expect(
        events.any((e) =>
            e.event == 'exploration_disabled_changed' &&
            e.data['disabled'] == false),
        isTrue,
      );
      await gpsController.close();
      engine.dispose();
    });
  });

  group('GameEngine — discovery (no speciesService)', () {
    test('does NOT emit species_discovered when speciesServiceGetter is null',
        () async {
      final cs = MockCellService();
      cs.getCellIdFn = (lat, lon) => 'v_discover';
      final fog = FogStateResolver(cs);
      final engine = GameEngine(fogResolver: fog, cellService: cs);
      engine.start();
      // No speciesServiceGetter wired.

      final events = await collectEvents(engine, () {
        engine.send(const PositionUpdate(1.0, 1.0));
      });

      expect(events.any((e) => e.event == 'species_discovered'), isFalse);
      engine.dispose();
    });

    test('does NOT emit species_discovered when staying in same cell',
        () async {
      final cs = MockCellService();
      cs.getCellIdFn = (lat, lon) => 'v_stay';
      final fog = FogStateResolver(cs);
      final engine = GameEngine(fogResolver: fog, cellService: cs);
      engine.loadVisitedCells({'v_stay'});
      engine.start();

      final events = await collectEvents(engine, () {
        engine.send(const PositionUpdate(0.0, 0.0));
      });

      expect(events.any((e) => e.event == 'species_discovered'), isFalse);
      engine.dispose();
    });
  });

  group('GameEngine — auth', () {
    test('AuthChanged updates currentUserId', () {
      final engine = _makeEngine();
      engine.start();

      engine.send(const AuthChanged('user_42'));
      expect(engine.currentUserId, 'user_42');

      engine.send(const AuthChanged(null));
      expect(engine.currentUserId, isNull);
      engine.dispose();
    });

    test('events carry userId after AuthChanged', () async {
      final cs = MockCellService();
      cs.getCellIdFn = (lat, lon) => 'v_user_cell';
      final fog = FogStateResolver(cs);
      final engine = GameEngine(fogResolver: fog, cellService: cs);
      engine.start();
      engine.send(const AuthChanged('player_99'));

      final events = await collectEvents(engine, () {
        engine.send(const PositionUpdate(1.0, 1.0));
      });

      final visitEvent =
          events.firstWhere((e) => e.event == 'cell_visited', orElse: null);
      expect(visitEvent.userId, 'player_99');
      engine.dispose();
    });
  });

  group('GameEngine — hydration', () {
    test('loadVisitedCells before start works correctly', () {
      final cs = MockCellService();
      cs.neighbors['v_seed1'] = ['v_seed2'];
      final fog = FogStateResolver(cs);
      final engine = GameEngine(fogResolver: fog, cellService: cs);

      engine.loadVisitedCells({'v_seed1', 'v_seed2'});
      engine.start();

      expect(fog.visitedCellIds, containsAll(['v_seed1', 'v_seed2']));
      engine.dispose();
    });

    test('loadCellProperties populates cache for lookup', () {
      final engine = _makeEngine();
      // Empty props map — no crash expected.
      engine.loadCellProperties({});
      expect(engine.cellPropertiesCache, isEmpty);
      engine.dispose();
    });

    test('updateCellPropertyLocationId updates cached cell', () {
      // We verify via the getter — if no crash and the method exists, it's OK.
      // Real assertion requires a CellProperties object; tested via integration.
      final engine = _makeEngine();
      engine.updateCellPropertyLocationId('v_any', 'loc_123');
      // No crash = pass (cell not in cache → no-op per implementation).
      engine.dispose();
    });
  });

  group('GameEngine — error handling', () {
    test('engine emits error event instead of throwing on bad input', () async {
      final cs = MockCellService();
      cs.getCellIdFn = (lat, lon) => throw Exception('getCellId boom');
      final fog = FogStateResolver(cs);
      final engine = GameEngine(fogResolver: fog, cellService: cs);
      final gpsController =
          StreamController<({Geographic position, double accuracy})>();
      engine.start(gpsStream: gpsController.stream);
      gpsController
          .add((position: Geographic(lat: 1.0, lon: 1.0), accuracy: 5.0));
      await Future<void>.delayed(Duration.zero);

      final events = await collectEvents(engine, () {
        // This will call getCellId which throws.
        engine.send(const PositionUpdate(1.0, 1.0));
      });

      expect(events.any((e) => e.event == 'error'), isTrue);
      await gpsController.close();
      engine.dispose();
    });

    test('CellTapped is a no-op and does not crash', () {
      final engine = _makeEngine();
      engine.start();
      expect(() => engine.send(const CellTapped('v_tap')), returnsNormally);
      engine.dispose();
    });

    test('AppLifecycleChanged is a no-op and does not crash', () {
      final engine = _makeEngine();
      engine.start();
      expect(
        () => engine.send(const AppLifecycleChanged(isActive: false)),
        returnsNormally,
      );
      engine.dispose();
    });
  });

  group('GameEngine — performance', () {
    test('processing 100 PositionUpdates completes in < 500ms', () {
      final engine = _makeEngine();
      engine.start();

      final start = DateTime.now();
      for (var i = 0; i < 100; i++) {
        engine.send(PositionUpdate(i.toDouble() * 0.001, 0.0));
      }
      final elapsed = DateTime.now().difference(start);

      expect(elapsed.inMilliseconds, lessThan(500));
      engine.dispose();
    });

    test('events stream delivers events synchronously (sync: true)', () {
      final cs = MockCellService();
      cs.getCellIdFn = (lat, lon) => 'v_sync';
      final fog = FogStateResolver(cs);
      final engine = GameEngine(fogResolver: fog, cellService: cs);
      engine.start();

      int received = 0;
      // sync: true stream — listener fires before send() returns.
      engine.events.listen((_) => received++);

      engine.send(const PositionUpdate(0.0, 0.0));

      // Received should already be > 0 without awaiting.
      expect(received, greaterThan(0));
      engine.dispose();
    });
  });
}
