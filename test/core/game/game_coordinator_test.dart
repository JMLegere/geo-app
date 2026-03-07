import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geobase/geobase.dart';

import 'package:fog_of_world/core/cells/cell_service.dart';
import 'package:fog_of_world/core/fog/fog_state_resolver.dart';
import 'package:fog_of_world/core/game/game_coordinator.dart';
import 'package:fog_of_world/core/models/affix.dart';
import 'package:fog_of_world/core/models/continent.dart';
import 'package:fog_of_world/core/models/discovery_event.dart';
import 'package:fog_of_world/core/models/habitat.dart';
import 'package:fog_of_world/core/models/iucn_status.dart';
import 'package:fog_of_world/core/models/item_definition.dart';
import 'package:fog_of_world/core/models/item_instance.dart';
import 'package:fog_of_world/core/species/stats_service.dart';
import 'package:fog_of_world/shared/constants.dart';

// ---------------------------------------------------------------------------
// MockCellService — deterministic grid: "row_col" from rounded coords.
// ---------------------------------------------------------------------------
class _MockCellService implements CellService {
  @override
  String getCellId(double lat, double lon) =>
      '${lat.round()}_${lon.round()}';

  @override
  Geographic getCellCenter(String cellId) {
    final parts = cellId.split('_');
    final dLat = double.parse(parts[0]) * 0.01;
    final dLon = double.parse(parts[1]) * 0.01;
    return Geographic(lat: 40.0 + dLat, lon: -100.0 + dLon);
  }

  @override
  List<Geographic> getCellBoundary(String cellId) {
    final c = getCellCenter(cellId);
    const h = 0.5;
    return [
      Geographic(lat: c.lat - h, lon: c.lon - h),
      Geographic(lat: c.lat - h, lon: c.lon + h),
      Geographic(lat: c.lat + h, lon: c.lon + h),
      Geographic(lat: c.lat + h, lon: c.lon - h),
    ];
  }

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

typedef _GpsUpdate = ({Geographic position, double accuracy});

GameCoordinator _makeCoordinator({
  FogStateResolver? fogResolver,
  StatsService statsService = const StatsService(),
  bool isRealGps = false,
}) {
  return GameCoordinator(
    fogResolver: fogResolver ?? FogStateResolver(_MockCellService()),
    statsService: statsService,
    isRealGps: isRealGps,
  );
}

FaunaDefinition _testFauna({
  String id = 'fauna_test_species',
  String displayName = 'Test Species',
  String scientificName = 'Testus specius',
}) {
  return FaunaDefinition(
    id: id,
    displayName: displayName,
    scientificName: scientificName,
    taxonomicClass: 'Mammalia',
    continents: [Continent.northAmerica],
    habitats: [Habitat.forest],
    rarity: IucnStatus.leastConcern,
  );
}

DiscoveryEvent _testDiscoveryEvent({
  FaunaDefinition? item,
  String cellId = '1_1',
  bool isNew = true,
}) {
  return DiscoveryEvent(
    item: item ?? _testFauna(),
    cellId: cellId,
    isNew: isNew,
    timestamp: DateTime(2026, 3, 6),
  );
}

/// Creates sync broadcast stream controllers for GPS + discovery,
/// wires them to the coordinator, and returns everything for test use.
/// Caller is responsible for closing the returned controllers.
({
  StreamController<_GpsUpdate> gps,
  StreamController<DiscoveryEvent> discovery,
}) _startCoordinator(GameCoordinator c) {
  // ignore: close_sinks
  final gps = StreamController<_GpsUpdate>.broadcast(sync: true);
  // ignore: close_sinks
  final discovery = StreamController<DiscoveryEvent>.broadcast(sync: true);
  c.start(gpsStream: gps.stream, discoveryStream: discovery.stream);
  return (gps: gps, discovery: discovery);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('GameCoordinator', () {
    // -----------------------------------------------------------------------
    // Dual-position model
    // -----------------------------------------------------------------------
    group('dual-position model', () {
      test('both positions start null', () {
        final c = _makeCoordinator();
        expect(c.rawGpsPosition, isNull);
        expect(c.playerPosition, isNull);
        c.dispose();
      });

      test('rawGpsPosition updates from GPS stream', () {
        final c = _makeCoordinator();
        final s = _startCoordinator(c);

        s.gps.add((
          position: Geographic(lat: 45.0, lon: -66.0),
          accuracy: 5.0,
        ));

        expect(c.rawGpsPosition, isNotNull);
        expect(c.rawGpsPosition!.lat, 45.0);
        expect(c.rawGpsPosition!.lon, -66.0);
        expect(c.rawGpsAccuracy, 5.0);

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });

      test('playerPosition updates from updatePlayerPosition', () {
        final c = _makeCoordinator();
        final s = _startCoordinator(c);

        c.updatePlayerPosition(46.0, -67.0);

        expect(c.playerPosition, isNotNull);
        expect(c.playerPosition!.lat, 46.0);
        expect(c.playerPosition!.lon, -67.0);

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });

      test('positions are independent — GPS does not change playerPosition',
          () {
        final c = _makeCoordinator();
        final s = _startCoordinator(c);

        s.gps.add((
          position: Geographic(lat: 45.0, lon: -66.0),
          accuracy: 5.0,
        ));

        // rawGps updated, playerPosition still null
        expect(c.rawGpsPosition, isNotNull);
        expect(c.playerPosition, isNull);

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });

      test(
          'positions are independent — updatePlayerPosition does not change rawGpsPosition',
          () {
        final c = _makeCoordinator();
        final s = _startCoordinator(c);

        c.updatePlayerPosition(46.0, -67.0);

        expect(c.playerPosition, isNotNull);
        expect(c.rawGpsPosition, isNull);

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // Game tick throttling
    // -----------------------------------------------------------------------
    group('game tick throttling', () {
      test('first updatePlayerPosition always processes game logic', () {
        int callCount = 0;
        final c = _makeCoordinator();
        c.onPlayerLocationUpdate = (_, __) => callCount++;
        final s = _startCoordinator(c);

        c.updatePlayerPosition(1.0, 1.0);
        expect(callCount, 1);

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });

      test('game logic runs on frame 1, then every 6th frame', () {
        int callCount = 0;
        final c = _makeCoordinator();
        c.onPlayerLocationUpdate = (_, __) => callCount++;
        final s = _startCoordinator(c);

        // Send 12 frames
        for (int i = 0; i < 12; i++) {
          c.updatePlayerPosition(1.0, 1.0);
        }

        // Frame 1: processes (count=1)
        // Frames 2-5: skip
        // Frame 6: processes (count=2)
        // Frames 7-11: skip
        // Frame 12: processes (count=3)
        expect(callCount, 3);

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // GPS accuracy errors
    // -----------------------------------------------------------------------
    group('GPS accuracy errors', () {
      test(
          'real GPS with accuracy > threshold emits GpsError.lowAccuracy', () {
        GpsError? lastError;
        final c = _makeCoordinator(isRealGps: true);
        c.onGpsErrorChanged = (error) => lastError = error;
        final s = _startCoordinator(c);

        s.gps.add((
          position: Geographic(lat: 1.0, lon: 1.0),
          accuracy: kGpsAccuracyThreshold + 1,
        ));

        expect(lastError, GpsError.lowAccuracy);

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });

      test('real GPS with accuracy <= threshold emits GpsError.none', () {
        GpsError? lastError;
        final c = _makeCoordinator(isRealGps: true);
        c.onGpsErrorChanged = (error) => lastError = error;
        final s = _startCoordinator(c);

        s.gps.add((
          position: Geographic(lat: 1.0, lon: 1.0),
          accuracy: kGpsAccuracyThreshold,
        ));

        expect(lastError, GpsError.none);

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });

      test('simulated GPS does not emit accuracy errors', () {
        GpsError? lastError;
        final c = _makeCoordinator(isRealGps: false);
        c.onGpsErrorChanged = (error) => lastError = error;
        final s = _startCoordinator(c);

        // Send terrible accuracy — should be ignored for simulated GPS.
        s.gps.add((
          position: Geographic(lat: 1.0, lon: 1.0),
          accuracy: 999.0,
        ));

        expect(lastError, isNull);

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // Discovery processing
    // -----------------------------------------------------------------------
    group('discovery processing', () {
      test('onItemDiscovered fires when discovery stream emits', () {
        DiscoveryEvent? receivedEvent;
        ItemInstance? receivedInstance;
        final c = _makeCoordinator();
        c.onItemDiscovered = (event, instance) {
          receivedEvent = event;
          receivedInstance = instance;
        };
        final s = _startCoordinator(c);

        final event = _testDiscoveryEvent();
        s.discovery.add(event);

        expect(receivedEvent, isNotNull);
        expect(receivedInstance, isNotNull);

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });

      test('created ItemInstance has correct structure and affix', () {
        ItemInstance? instance;
        final c = _makeCoordinator();
        c.onItemDiscovered = (_, inst) => instance = inst;
        final s = _startCoordinator(c);

        final fauna = _testFauna(
          id: 'fauna_vulpes_vulpes',
          scientificName: 'Vulpes vulpes',
        );
        final event = _testDiscoveryEvent(
          item: fauna,
          cellId: 'test_cell_42',
        );
        s.discovery.add(event);

        expect(instance, isNotNull);

        // UUID v4 format: 8-4-4-4-12 hex chars
        expect(instance!.id, matches(RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));

        expect(instance!.definitionId, 'fauna_vulpes_vulpes');
        expect(instance!.acquiredInCellId, 'test_cell_42');
        expect(instance!.acquiredAt, event.timestamp);

        // Exactly one intrinsic affix with base_stats
        expect(instance!.affixes, hasLength(1));
        final affix = instance!.affixes.first;
        expect(affix.id, kIntrinsicAffixId);
        expect(affix.type, AffixType.intrinsic);
        expect(affix.values, containsPair('speed', isA<int>()));
        expect(affix.values, containsPair('brawn', isA<int>()));
        expect(affix.values, containsPair('wit', isA<int>()));

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // Fog cell visited callback
    // -----------------------------------------------------------------------
    group('fog cell visited', () {
      test('onCellVisited fires when player enters a new cell', () {
        int visitCount = 0;
        final resolver = FogStateResolver(_MockCellService());
        final c = _makeCoordinator(fogResolver: resolver);
        c.onCellVisited = () => visitCount++;
        final s = _startCoordinator(c);

        // updatePlayerPosition → _processGameLogic → fogResolver.onLocationUpdate
        // → new cell → onVisitedCellAdded fires → onCellVisited callback
        c.updatePlayerPosition(1.0, 1.0);
        expect(visitCount, 1);

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });

      test('onCellVisited does NOT fire for re-entering the same cell', () {
        int visitCount = 0;
        final resolver = FogStateResolver(_MockCellService());
        final c = _makeCoordinator(fogResolver: resolver);
        c.onCellVisited = () => visitCount++;
        final s = _startCoordinator(c);

        c.updatePlayerPosition(1.0, 1.0); // first visit → fires
        expect(visitCount, 1);

        // Send enough frames to hit the next game tick (frame 6)
        for (int i = 0; i < 5; i++) {
          c.updatePlayerPosition(1.0, 1.0);
        }
        // Frame 6 processes game logic for same cell — no new visit
        expect(visitCount, 1);

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });

      test('onCellVisited fires for each distinct cell entered', () {
        int visitCount = 0;
        final resolver = FogStateResolver(_MockCellService());
        final c = _makeCoordinator(fogResolver: resolver);
        c.onCellVisited = () => visitCount++;
        final s = _startCoordinator(c);

        c.updatePlayerPosition(1.0, 1.0); // cell '1_1' → fires
        expect(visitCount, 1);

        // Need frame 6 to trigger another game logic tick
        for (int i = 0; i < 5; i++) {
          c.updatePlayerPosition(2.0, 2.0); // frame doesn't process until 6th
        }
        // Frame 6 → new cell '2_2' → fires
        expect(visitCount, 2);

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // onRawGpsUpdate stream
    // -----------------------------------------------------------------------
    group('onRawGpsUpdate stream', () {
      test('broadcasts GPS updates to subscribers', () {
        _GpsUpdate? received;
        final c = _makeCoordinator();
        final sub = c.onRawGpsUpdate.listen((update) => received = update);
        final s = _startCoordinator(c);

        s.gps.add((
          position: Geographic(lat: 45.0, lon: -66.0),
          accuracy: 3.0,
        ));

        expect(received, isNotNull);
        expect(received!.position.lat, 45.0);
        expect(received!.accuracy, 3.0);

        sub.cancel();
        s.gps.close();
        s.discovery.close();
        c.dispose();
      });

      test('multiple subscribers receive the same update', () {
        _GpsUpdate? received1;
        _GpsUpdate? received2;
        final c = _makeCoordinator();
        final sub1 = c.onRawGpsUpdate.listen((u) => received1 = u);
        final sub2 = c.onRawGpsUpdate.listen((u) => received2 = u);
        final s = _startCoordinator(c);

        s.gps.add((
          position: Geographic(lat: 45.0, lon: -66.0),
          accuracy: 3.0,
        ));

        expect(received1, isNotNull);
        expect(received2, isNotNull);
        expect(received1!.position.lat, received2!.position.lat);

        sub1.cancel();
        sub2.cancel();
        s.gps.close();
        s.discovery.close();
        c.dispose();
      });

      test('stream is broadcast', () {
        final c = _makeCoordinator();
        expect(c.onRawGpsUpdate.isBroadcast, isTrue);
        c.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // Permission check
    // -----------------------------------------------------------------------
    group('permission check', () {
      test('denied permission triggers GpsError.permissionDenied', () async {
        GpsError? lastError;
        final c = _makeCoordinator();
        c.onGpsErrorChanged = (error) => lastError = error;
        c.checkPermission = () async => GpsPermissionResult.denied;
        final s = _startCoordinator(c);

        // Let the async permission check complete.
        await Future<void>.delayed(Duration.zero);

        expect(lastError, GpsError.permissionDenied);

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });

      test('deniedForever permission triggers GpsError.permissionDeniedForever',
          () async {
        GpsError? lastError;
        final c = _makeCoordinator();
        c.onGpsErrorChanged = (error) => lastError = error;
        c.checkPermission = () async => GpsPermissionResult.deniedForever;
        final s = _startCoordinator(c);

        await Future<void>.delayed(Duration.zero);

        expect(lastError, GpsError.permissionDeniedForever);

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });

      test('serviceDisabled permission triggers GpsError.serviceDisabled',
          () async {
        GpsError? lastError;
        final c = _makeCoordinator();
        c.onGpsErrorChanged = (error) => lastError = error;
        c.checkPermission = () async => GpsPermissionResult.serviceDisabled;
        final s = _startCoordinator(c);

        await Future<void>.delayed(Duration.zero);

        expect(lastError, GpsError.serviceDisabled);

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });

      test('granted permission does not emit error', () async {
        GpsError? lastError;
        final c = _makeCoordinator();
        c.onGpsErrorChanged = (error) => lastError = error;
        c.checkPermission = () async => GpsPermissionResult.granted;
        final s = _startCoordinator(c);

        await Future<void>.delayed(Duration.zero);

        // granted maps to GpsError.none, but the code only calls
        // onGpsErrorChanged when error != GpsError.none.
        expect(lastError, isNull);

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });

      test('null checkPermission callback does not error', () async {
        GpsError? lastError;
        final c = _makeCoordinator();
        c.onGpsErrorChanged = (error) => lastError = error;
        // checkPermission is null by default
        final s = _startCoordinator(c);

        await Future<void>.delayed(Duration.zero);

        expect(lastError, isNull);

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // Lifecycle (start / stop / dispose)
    // -----------------------------------------------------------------------
    group('lifecycle', () {
      test('isStarted is false initially', () {
        final c = _makeCoordinator();
        expect(c.isStarted, isFalse);
        c.dispose();
      });

      test('start() sets isStarted to true', () {
        final c = _makeCoordinator();
        final s = _startCoordinator(c);

        expect(c.isStarted, isTrue);

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });

      test('stop() sets isStarted to false', () {
        final c = _makeCoordinator();
        final s = _startCoordinator(c);

        c.stop();
        expect(c.isStarted, isFalse);

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });

      test('double start() is idempotent', () {
        int callCount = 0;
        final c = _makeCoordinator();
        c.onPlayerLocationUpdate = (_, __) => callCount++;

        final gps1 = StreamController<_GpsUpdate>.broadcast(sync: true);
        final disc1 = StreamController<DiscoveryEvent>.broadcast(sync: true);
        c.start(gpsStream: gps1.stream, discoveryStream: disc1.stream);

        // Second start with different streams — should be ignored.
        final gps2 = StreamController<_GpsUpdate>.broadcast(sync: true);
        final disc2 = StreamController<DiscoveryEvent>.broadcast(sync: true);
        c.start(gpsStream: gps2.stream, discoveryStream: disc2.stream);

        // Only the first stream is connected.
        gps1.add((
          position: Geographic(lat: 1.0, lon: 1.0),
          accuracy: 5.0,
        ));
        expect(c.rawGpsPosition!.lat, 1.0);

        // Second stream is not connected.
        gps2.add((
          position: Geographic(lat: 99.0, lon: 99.0),
          accuracy: 5.0,
        ));
        expect(c.rawGpsPosition!.lat, 1.0); // unchanged

        gps1.close();
        gps2.close();
        disc1.close();
        disc2.close();
        c.dispose();
      });

      test('after stop(), GPS stream events are ignored', () {
        final c = _makeCoordinator();
        final gps = StreamController<_GpsUpdate>.broadcast(sync: true);
        final disc = StreamController<DiscoveryEvent>.broadcast(sync: true);
        c.start(gpsStream: gps.stream, discoveryStream: disc.stream);

        // Verify GPS works before stop.
        gps.add((
          position: Geographic(lat: 1.0, lon: 1.0),
          accuracy: 5.0,
        ));
        expect(c.rawGpsPosition!.lat, 1.0);

        c.stop();

        // After stop, GPS events do NOT update rawGpsPosition.
        gps.add((
          position: Geographic(lat: 99.0, lon: 99.0),
          accuracy: 5.0,
        ));
        // Position stays at last value before stop.
        expect(c.rawGpsPosition!.lat, 1.0);

        gps.close();
        disc.close();
        c.dispose();
      });

      test('game logic fires immediately after stop+restart', () {
        int callCount = 0;
        final c = _makeCoordinator();
        c.onPlayerLocationUpdate = (_, __) => callCount++;

        // First start — run 12 frames (3 game ticks).
        final gps1 = StreamController<_GpsUpdate>.broadcast(sync: true);
        final disc1 = StreamController<DiscoveryEvent>.broadcast(sync: true);
        c.start(gpsStream: gps1.stream, discoveryStream: disc1.stream);
        for (int i = 0; i < 12; i++) {
          c.updatePlayerPosition(1.0, 1.0);
        }
        expect(callCount, 3);

        // Stop resets frame counter.
        c.stop();

        // Restart with fresh streams.
        callCount = 0;
        final gps2 = StreamController<_GpsUpdate>.broadcast(sync: true);
        final disc2 = StreamController<DiscoveryEvent>.broadcast(sync: true);
        c.start(gpsStream: gps2.stream, discoveryStream: disc2.stream);

        // Very first updatePlayerPosition after restart must process
        // game logic immediately (frame counter was reset to 0).
        c.updatePlayerPosition(2.0, 2.0);
        expect(callCount, 1);

        gps1.close();
        gps2.close();
        disc1.close();
        disc2.close();
        c.dispose();
      });

      test('permission check after stop does not fire callback', () async {
        GpsError? lastError;
        final c = _makeCoordinator();
        c.onGpsErrorChanged = (error) => lastError = error;

        // Permission check will resolve after we stop.
        final completer = Completer<GpsPermissionResult?>();
        c.checkPermission = () => completer.future;

        final s = _startCoordinator(c);

        // Stop before permission resolves.
        c.stop();

        // Now resolve — the callback should NOT fire because _started is false.
        completer.complete(GpsPermissionResult.denied);
        await Future<void>.delayed(Duration.zero);

        expect(lastError, isNull);

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });

      test('can restart after stop()', () {
        final c = _makeCoordinator();

        // First start.
        final gps1 = StreamController<_GpsUpdate>.broadcast(sync: true);
        final disc1 = StreamController<DiscoveryEvent>.broadcast(sync: true);
        c.start(gpsStream: gps1.stream, discoveryStream: disc1.stream);
        expect(c.isStarted, isTrue);

        c.stop();
        expect(c.isStarted, isFalse);

        // Second start with new streams.
        final gps2 = StreamController<_GpsUpdate>.broadcast(sync: true);
        final disc2 = StreamController<DiscoveryEvent>.broadcast(sync: true);
        c.start(gpsStream: gps2.stream, discoveryStream: disc2.stream);
        expect(c.isStarted, isTrue);

        // New stream works.
        gps2.add((
          position: Geographic(lat: 42.0, lon: -71.0),
          accuracy: 3.0,
        ));
        expect(c.rawGpsPosition!.lat, 42.0);

        gps1.close();
        gps2.close();
        disc1.close();
        disc2.close();
        c.dispose();
      });

      test('dispose() stops coordinator and closes stream', () {
        final c = _makeCoordinator();
        final s = _startCoordinator(c);

        c.dispose();

        expect(c.isStarted, isFalse);

        s.gps.close();
        s.discovery.close();
      });
    });
  });
}
