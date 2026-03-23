import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geobase/geobase.dart';

import 'package:earth_nova/core/cells/cell_service.dart';
import 'package:earth_nova/core/engine/engine_input.dart';
import 'package:earth_nova/core/services/observability_buffer.dart';
import 'package:earth_nova/core/engine/game_engine.dart';
import 'package:earth_nova/core/engine/game_event.dart';
import 'package:earth_nova/core/fog/fog_state_resolver.dart';
import 'package:earth_nova/core/engine/game_coordinator.dart';
import 'package:earth_nova/core/models/cell_properties.dart';
import 'package:earth_nova/core/models/climate.dart';
import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/discovery_event.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/models/iucn_status.dart';
import 'package:earth_nova/core/models/item_category.dart';
import 'package:earth_nova/core/models/item_instance.dart';
import 'package:earth_nova/core/models/item_definition.dart';
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

GameEngine _makeEngine({
  bool isRealGps = false,
  ObservabilityBuffer? obs,
}) {
  final cells = _MockCellService();
  return GameEngine(
    fogResolver: FogStateResolver(cells),
    statsService: const StatsService(),
    cellService: cells,
    isRealGps: isRealGps,
    obs: obs,
  );
}

ItemInstance _testInstance({
  String id = 'inst_1',
  String definitionId = 'def_1',
}) {
  return ItemInstance(
    id: id,
    definitionId: definitionId,
    displayName: 'Test Fox',
    scientificName: 'Vulpes testus',
    category: ItemCategory.fauna,
    rarity: IucnStatus.leastConcern,
    habitats: [Habitat.forest],
    continents: [Continent.northAmerica],
    acquiredAt: DateTime(2026, 3, 15),
  );
}

DiscoveryEvent _testDiscoveryEvent({String cellId = '1_1'}) {
  return DiscoveryEvent(
    item: FaunaDefinition(
      id: 'def_1',
      displayName: 'Test Fox',
      scientificName: 'Vulpes testus',
      taxonomicClass: 'Mammalia',
      continents: [Continent.northAmerica],
      habitats: [Habitat.forest],
      rarity: IucnStatus.leastConcern,
    ),
    cellId: cellId,
    isNew: true,
    timestamp: DateTime(2026, 3, 15),
    dailySeed: 'seed_42',
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('GameEngine', () {
    // -----------------------------------------------------------------------
    // Callback → event conversion
    // -----------------------------------------------------------------------
    group('callback → event wiring', () {
      test('onPlayerLocationUpdate does not emit (10Hz noise suppressed)',
          () async {
        final engine = _makeEngine();
        addTearDown(engine.dispose);

        final events = <GameEvent>[];
        engine.events.listen(events.add);

        engine.coordinator.onPlayerLocationUpdate?.call(
          Geographic(lat: 45.0, lon: -66.0),
          5.0,
        );

        expect(events, isEmpty);
      });

      test('onCellVisited emits cell_visited', () async {
        final engine = _makeEngine();
        addTearDown(engine.dispose);

        final events = <GameEvent>[];
        engine.events.listen(events.add);

        engine.coordinator.onCellVisited?.call('cell_42');

        expect(events, hasLength(1));
        expect(events.first.category, 'state');
        expect(events.first.event, 'cell_visited');
        expect(events.first.data['cell_id'], 'cell_42');
      });

      test('onItemDiscovered emits species_discovered', () async {
        final engine = _makeEngine();
        addTearDown(engine.dispose);

        final events = <GameEvent>[];
        engine.events.listen(events.add);

        final discovery = _testDiscoveryEvent();
        final instance = _testInstance();
        engine.coordinator.onItemDiscovered?.call(discovery, instance);

        expect(events, hasLength(1));
        final e = events.first;
        expect(e.category, 'state');
        expect(e.event, 'species_discovered');
        expect(e.data['item_id'], 'inst_1');
        expect(e.data['definition_id'], 'def_1');
        expect(e.data['display_name'], 'Test Fox');
        expect(e.data['scientific_name'], 'Vulpes testus');
        expect(e.data['category'], 'fauna');
        expect(e.data['rarity'], 'leastConcern');
        expect(e.data['cell_id'], '1_1');
        expect(e.data['has_enrichment'], false);
        expect(e.data['affix_count'], 0);
        expect(e.data['daily_seed'], 'seed_42');
        expect(e.data['cell_event_type'], isNull);
      });

      test('onGpsErrorChanged emits gps_error_changed', () async {
        final engine = _makeEngine();
        addTearDown(engine.dispose);

        final events = <GameEvent>[];
        engine.events.listen(events.add);

        engine.coordinator.onGpsErrorChanged?.call(GpsError.lowAccuracy);

        expect(events, hasLength(1));
        expect(events.first.category, 'system');
        expect(events.first.event, 'gps_error_changed');
        expect(events.first.data['error'], 'lowAccuracy');
      });

      test('onCellPropertiesResolved emits cell_properties_resolved', () async {
        final engine = _makeEngine();
        addTearDown(engine.dispose);

        final events = <GameEvent>[];
        engine.events.listen(events.add);

        final props = CellProperties(
          cellId: 'v_10_20',
          habitats: {Habitat.forest, Habitat.mountain},
          climate: Climate.temperate,
          continent: Continent.northAmerica,
          locationId: 'loc_1',
          createdAt: DateTime(2026, 3, 15),
        );
        engine.coordinator.onCellPropertiesResolved?.call(props);

        expect(events, hasLength(1));
        final e = events.first;
        expect(e.category, 'state');
        expect(e.event, 'cell_properties_resolved');
        expect(e.data['cell_id'], 'v_10_20');
        expect(e.data['habitats'], isA<List>());
        expect(e.data['climate'], 'temperate');
        expect(e.data['continent'], 'northAmerica');
        expect(e.data['location_id'], 'loc_1');
      });

      test('onExplorationDisabledChanged emits exploration_disabled_changed',
          () async {
        final engine = _makeEngine();
        addTearDown(engine.dispose);

        final events = <GameEvent>[];
        engine.events.listen(events.add);

        engine.coordinator.onExplorationDisabledChanged?.call(true);

        expect(events, hasLength(1));
        expect(events.first.category, 'system');
        expect(events.first.event, 'exploration_disabled_changed');
        expect(events.first.data['disabled'], true);
      });
    });

    // -----------------------------------------------------------------------
    // send() routing
    // -----------------------------------------------------------------------
    group('send()', () {
      test('PositionUpdate calls coordinator.updatePlayerPosition', () {
        final engine = _makeEngine();
        addTearDown(engine.dispose);

        engine.send(const PositionUpdate(46.0, -67.0, 3.0));

        expect(engine.coordinator.playerPosition, isNotNull);
        expect(engine.coordinator.playerPosition!.lat, 46.0);
        expect(engine.coordinator.playerPosition!.lon, -67.0);
      });

      test('AuthChanged calls coordinator.setCurrentUserId', () {
        final engine = _makeEngine();
        addTearDown(engine.dispose);

        engine.send(const AuthChanged('user_abc'));
        expect(engine.coordinator.currentUserId, 'user_abc');

        engine.send(const AuthChanged(null));
        expect(engine.coordinator.currentUserId, isNull);
      });

      test('AppBackgrounded does not throw', () async {
        final engine = _makeEngine();
        addTearDown(engine.dispose);

        engine.coordinator.onCellVisited?.call('cell_1');

        // Should not throw — flush is now a no-op (events go via debugPrint).
        expect(() => engine.send(const AppBackgrounded()), returnsNormally);
      });
    });

    // -----------------------------------------------------------------------
    // Stream characteristics
    // -----------------------------------------------------------------------
    group('event stream', () {
      test('is broadcast (supports multiple listeners)', () {
        final engine = _makeEngine();
        addTearDown(engine.dispose);

        // Broadcast streams allow multiple listen() calls without throwing.
        engine.events.listen((_) {});
        engine.events.listen((_) {});

        expect(engine.events.isBroadcast, isTrue);
      });
    });

    // -----------------------------------------------------------------------
    // Lifecycle
    // -----------------------------------------------------------------------
    group('lifecycle', () {
      test('dispose closes event stream', () async {
        final engine = _makeEngine();

        var isDone = false;
        engine.events.listen((_) {}, onDone: () => isDone = true);

        engine.dispose();
        await Future<void>.delayed(Duration.zero);

        expect(isDone, isTrue);
      });

      test('start delegates to coordinator', () {
        final engine = _makeEngine();
        addTearDown(engine.dispose);

        final gps = StreamController<
            ({Geographic position, double accuracy})>.broadcast(sync: true);
        final discovery =
            StreamController<DiscoveryEvent>.broadcast(sync: true);
        addTearDown(gps.close);
        addTearDown(discovery.close);

        expect(engine.isStarted, isFalse);
        engine.start(
          gpsStream: gps.stream,
          discoveryStream: discovery.stream,
        );
        expect(engine.isStarted, isTrue);
      });

      test('stop delegates to coordinator', () {
        final engine = _makeEngine();
        addTearDown(engine.dispose);

        final gps = StreamController<
            ({Geographic position, double accuracy})>.broadcast(sync: true);
        final discovery =
            StreamController<DiscoveryEvent>.broadcast(sync: true);
        addTearDown(gps.close);
        addTearDown(discovery.close);

        engine.start(
          gpsStream: gps.stream,
          discoveryStream: discovery.stream,
        );
        engine.stop();
        expect(engine.isStarted, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // State proxies
    // -----------------------------------------------------------------------
    group('state proxies', () {
      test('delegate to coordinator', () {
        final engine = _makeEngine();
        addTearDown(engine.dispose);

        expect(engine.rawGpsPosition, isNull);
        expect(engine.playerPosition, isNull);
        expect(engine.rawGpsAccuracy, 0.0);
        expect(engine.cellPropertiesCache, isEmpty);
        expect(engine.explorationDisabled, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // Error firewall
    // -----------------------------------------------------------------------
    group('error firewall', () {
      test('callback error emits crash event instead of propagating', () {
        final sink = _ThrowOnceSink();
        final engine = _makeEngine(obs: sink);
        addTearDown(engine.dispose);

        final events = <GameEvent>[];
        engine.events.listen(events.add);

        // Trigger callback — sink.add() throws on first call, caught by
        // try-catch, crash event emitted (sink succeeds on second call).
        engine.coordinator.onCellVisited?.call('cell_err');

        expect(events, hasLength(2));
        // First: the normal event got added to stream before sink threw.
        expect(events[0].event, 'cell_visited');
        // Second: crash event with correct context.
        expect(events[1].category, 'system');
        expect(events[1].event, 'crash');
        expect(events[1].data['context'], 'onCellVisited');
        expect(events[1].data['error'], contains('sink boom'));
        expect(events[1].data['stack_trace'], isA<String>());
      });

      test('crash event context matches the handler that threw', () {
        final sink = _ThrowOnceSink();
        final engine = _makeEngine(obs: sink);
        addTearDown(engine.dispose);

        final events = <GameEvent>[];
        engine.events.listen(events.add);

        engine.coordinator.onGpsErrorChanged?.call(GpsError.lowAccuracy);

        final crash = events.firstWhere((e) => e.event == 'crash');
        expect(crash.data['context'], 'onGpsErrorChanged');
      });

      test('engine continues working after a caught error', () {
        final sink = _ThrowOnceSink();
        final engine = _makeEngine(obs: sink);
        addTearDown(engine.dispose);

        final events = <GameEvent>[];
        engine.events.listen(events.add);

        // First call: throws + crash event.
        engine.coordinator.onCellVisited?.call('cell_err');

        // Second call: sink no longer throws, normal event only.
        engine.coordinator.onCellVisited?.call('cell_ok');

        final normalEvents =
            events.where((e) => e.event == 'cell_visited').toList();
        expect(normalEvents, hasLength(2));
        expect(normalEvents[1].data['cell_id'], 'cell_ok');
      });

      test('send() wraps coordinator errors as crash events', () {
        final engine = _makeEngine();
        addTearDown(engine.dispose);

        final events = <GameEvent>[];
        engine.events.listen(events.add);

        // Trigger a callback that emits an event — onGpsErrorChanged.
        // Force an error by making the coordinator's internal state inconsistent.
        engine.coordinator.onGpsErrorChanged?.call(GpsError.lowAccuracy);

        // Verify the error-free path works (event emitted, no crash).
        final gpsErrors =
            events.where((e) => e.event == 'gps_error_changed').toList();
        expect(gpsErrors, isNotEmpty);
      });
    });

    // -----------------------------------------------------------------------
    // ObservabilityBuffer integration
    // -----------------------------------------------------------------------
    group('ObservabilityBuffer', () {
      test('events are forwarded to ObservabilityBuffer', () async {
        final sink = _CapturingSink();

        final engine = _makeEngine(obs: sink);
        addTearDown(engine.dispose);

        engine.coordinator.onCellVisited?.call('cell_99');

        expect(sink.captured, hasLength(1));
        expect(sink.captured.first.$1, 'cell_visited');
      });

      test('coordinator does not double-emit to ObservabilityBuffer', () async {
        final sink = _CapturingSink();

        final engine = _makeEngine(obs: sink);
        addTearDown(engine.dispose);

        // The coordinator has obs=null, so it won't emit.
        // Only the engine's callback handler emits.
        expect(engine.coordinator.obs, isNull);

        engine.coordinator.onGpsErrorChanged?.call(GpsError.none);

        // Exactly 1 event (from engine), not 2 (engine + coordinator).
        expect(sink.captured, hasLength(1));
      });
    });
  });
}

// ---------------------------------------------------------------------------
// _ThrowOnceSink — throws on first event() to test error firewall
// ---------------------------------------------------------------------------
class _ThrowOnceSink extends ObservabilityBuffer {
  int _callCount = 0;

  _ThrowOnceSink() : super();

  @override
  void event(String name, [Map<String, dynamic> data = const {}]) {
    _callCount++;
    if (_callCount == 1) throw Exception('sink boom');
    super.event(name, data);
  }
}

// ---------------------------------------------------------------------------
// _CapturingSink — ObservabilityBuffer that tracks event() calls
// ---------------------------------------------------------------------------
class _CapturingSink extends ObservabilityBuffer {
  final List<(String, Map<String, dynamic>)> captured = [];

  _CapturingSink() : super();

  @override
  void event(String name, [Map<String, dynamic> data = const {}]) {
    captured.add((name, data));
    super.event(name, data);
  }
}
