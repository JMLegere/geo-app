import 'package:flutter_test/flutter_test.dart';
import 'package:geobase/geobase.dart';

import 'package:earth_nova/core/cells/cell_service.dart';
import 'package:earth_nova/core/engine/engine_input.dart';
import 'package:earth_nova/core/engine/engine_runner.dart';
import 'package:earth_nova/core/engine/game_coordinator.dart';
import 'package:earth_nova/core/engine/game_engine.dart';
import 'package:earth_nova/core/engine/game_event.dart';
import 'package:earth_nova/core/engine/main_thread_engine_runner.dart';
import 'package:earth_nova/core/fog/fog_state_resolver.dart';
import 'package:earth_nova/features/items/services/stats_service.dart';

// ---------------------------------------------------------------------------
// MockCellService — minimal deterministic grid
// ---------------------------------------------------------------------------
class _MockCellService implements CellService {
  @override
  String getCellId(double lat, double lon) => '${lat.round()}_${lon.round()}';

  @override
  Geographic getCellCenter(String cellId) {
    final parts = cellId.split('_');
    return Geographic(
      lat: double.parse(parts[0]),
      lon: double.parse(parts[1]),
    );
  }

  @override
  List<Geographic> getCellBoundary(String cellId) => [];

  @override
  List<String> getNeighborIds(String cellId) => [];

  @override
  List<String> getCellsInRing(String cellId, int k) => [cellId];

  @override
  List<String> getCellsAroundLocation(double lat, double lon, int k) =>
      [getCellId(lat, lon)];

  @override
  double get cellEdgeLengthMeters => 100.0;

  @override
  String get systemName => 'MockGrid';
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

GameEngine _makeEngine() {
  final cells = _MockCellService();
  return GameEngine(
    fogResolver: FogStateResolver(cells),
    statsService: const StatsService(),
    cellService: cells,
  );
}

MainThreadEngineRunner _makeRunner() => MainThreadEngineRunner(_makeEngine());

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('EngineRunner', () {
    test('MainThreadEngineRunner implements EngineRunner', () {
      final runner = _makeRunner();
      addTearDown(runner.dispose);

      expect(runner, isA<EngineRunner>());
    });
  });

  group('MainThreadEngineRunner', () {
    group('events', () {
      test('forwards events from the underlying engine', () {
        final runner = _makeRunner();
        addTearDown(runner.dispose);

        final runnerEvents = <GameEvent>[];
        final engineEvents = <GameEvent>[];
        runner.events.listen(runnerEvents.add);
        runner.engine.events.listen(engineEvents.add);

        // Trigger an event through the engine's coordinator.
        runner.engine.coordinator.onCellEntered?.call('cell_99');

        // Both streams see the same event.
        expect(runnerEvents, hasLength(1));
        expect(engineEvents, hasLength(1));
        expect(runnerEvents.first.event, engineEvents.first.event);
        expect(runnerEvents.first.data, engineEvents.first.data);
      });

      test('stream is broadcast', () {
        final runner = _makeRunner();
        addTearDown(runner.dispose);

        expect(runner.events.isBroadcast, isTrue);
      });

      test('receives events from engine callbacks', () {
        final runner = _makeRunner();
        addTearDown(runner.dispose);

        final events = <GameEvent>[];
        runner.events.listen(events.add);

        runner.engine.coordinator.onCellEntered?.call('cell_42');

        expect(events, hasLength(1));
        expect(events.first.event, 'cell_visited');
        expect(events.first.data['cell_id'], 'cell_42');
      });
    });

    group('send()', () {
      test('delegates PositionUpdate to engine', () {
        final runner = _makeRunner();
        addTearDown(runner.dispose);

        runner.send(const PositionUpdate(45.0, -66.0, 5.0));

        expect(runner.engine.playerPosition, isNotNull);
        expect(runner.engine.playerPosition!.lat, 45.0);
        expect(runner.engine.playerPosition!.lon, -66.0);
      });

      test('delegates AuthChanged to engine', () {
        final runner = _makeRunner();
        addTearDown(runner.dispose);

        runner.send(const AuthChanged('user_abc'));
        expect(runner.engine.coordinator.currentUserId, 'user_abc');

        runner.send(const AuthChanged(null));
        expect(runner.engine.coordinator.currentUserId, isNull);
      });

      test('emits events for routed inputs', () {
        final runner = _makeRunner();
        addTearDown(runner.dispose);

        final events = <GameEvent>[];
        runner.events.listen(events.add);

        // Trigger GPS error callback which emits an event (unlike
        // PositionUpdate which is suppressed as 10Hz noise).
        runner.engine.coordinator.onGpsErrorChanged?.call(GpsError.lowAccuracy);

        expect(events, isNotEmpty);
        expect(events.first.event, 'gps_error_changed');
      });
    });

    group('dispose()', () {
      test('closes the event stream', () async {
        final runner = _makeRunner();

        var isDone = false;
        runner.events.listen((_) {}, onDone: () => isDone = true);

        await runner.dispose();
        await Future<void>.delayed(Duration.zero);

        expect(isDone, isTrue);
      });
    });

    group('engine accessor', () {
      test('exposes the wrapped GameEngine', () {
        final engine = _makeEngine();
        final runner = MainThreadEngineRunner(engine);
        addTearDown(runner.dispose);

        expect(runner.engine, same(engine));
      });
    });
  });
}
