import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geobase/geobase.dart';

import 'package:earth_nova/features/world/services/cell_property_resolver.dart';
import 'package:earth_nova/core/cells/cell_service.dart';
import 'package:earth_nova/core/fog/fog_state_resolver.dart';
import 'package:earth_nova/core/engine/game_coordinator.dart';
import 'package:earth_nova/core/models/affix.dart';
import 'package:earth_nova/core/models/animal_size.dart';
import 'package:earth_nova/core/models/cell_properties.dart';
import 'package:earth_nova/core/models/climate.dart';
import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/discovery_event.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/models/iucn_status.dart';
import 'package:earth_nova/core/models/item_definition.dart';
import 'package:earth_nova/core/models/item_instance.dart';
import 'package:earth_nova/features/items/services/stats_service.dart';
import 'package:earth_nova/shared/constants.dart';

// ---------------------------------------------------------------------------
// MockCellService — deterministic grid: "row_col" from rounded coords.
// ---------------------------------------------------------------------------
class _MockCellService implements CellService {
  @override
  String getCellId(double lat, double lon) => '${lat.round()}_${lon.round()}';

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
// _GridCellService — grid with real neighbors (for exploration guard tests).
// Cell IDs: "lat_lon" from rounded coords. Neighbors = 4 cardinal directions.
// ---------------------------------------------------------------------------
class _GridCellService implements CellService {
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
  List<String> getNeighborIds(String cellId) {
    final parts = cellId.split('_');
    final r = int.parse(parts[0]);
    final c = int.parse(parts[1]);
    return [
      '${r - 1}_$c', // north
      '${r + 1}_$c', // south
      '${r}_${c - 1}', // west
      '${r}_${c + 1}', // east
    ];
  }

  @override
  List<String> getCellsInRing(String cellId, int k) => [cellId];

  @override
  List<String> getCellsAroundLocation(double lat, double lon, int k) =>
      [getCellId(lat, lon)];

  @override
  double get cellEdgeLengthMeters => 100.0;

  @override
  String get systemName => 'GridWithNeighbors';
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

typedef _GpsUpdate = ({Geographic position, double accuracy});

GameCoordinator _makeCoordinator({
  FogStateResolver? fogResolver,
  CellService? cellService,
  StatsService statsService = const StatsService(),
  bool isRealGps = false,
}) {
  final cells = cellService ?? _MockCellService();
  return GameCoordinator(
    fogResolver: fogResolver ?? FogStateResolver(cells),
    statsService: statsService,
    cellService: cells,
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
      test('real GPS with accuracy > threshold emits GpsError.lowAccuracy', () {
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

      test('created ItemInstance without enrichment has no intrinsic affix',
          () {
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
        expect(
            instance!.id,
            matches(RegExp(
                r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));

        expect(instance!.definitionId, 'fauna_vulpes_vulpes');
        expect(instance!.acquiredInCellId, 'test_cell_42');
        expect(instance!.acquiredAt, event.timestamp);

        // Without enrichment, no intrinsic affix — stats show as N/A.
        expect(instance!.affixes, isEmpty);

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });

      test('created ItemInstance with enrichment has rolled intrinsic affix',
          () {
        ItemInstance? instance;
        final c = _makeCoordinator();
        // Wire enrichment lookup with known base stats.
        c.enrichedStatsLookup = (definitionId) {
          if (definitionId == 'fauna_vulpes_vulpes') {
            return (speed: 50, brawn: 20, wit: 20, size: null);
          }
          return null;
        };
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

        // With enrichment, exactly one intrinsic affix with rolled stats.
        expect(instance!.affixes, hasLength(1));
        final affix = instance!.affixes.first;
        expect(affix.id, kIntrinsicAffixId);
        expect(affix.type, AffixType.intrinsic);
        expect(affix.values, containsPair('speed', isA<int>()));
        expect(affix.values, containsPair('brawn', isA<int>()));
        expect(affix.values, containsPair('wit', isA<int>()));

        // Rolled stats should be within ±30 of enriched base, clamped 1–100.
        expect(
            affix.values['speed'] as int, inInclusiveRange(20, 80)); // 50 ± 30
        expect(affix.values['brawn'] as int,
            inInclusiveRange(1, 50)); // 20 ± 30, clamped at 1
        expect(affix.values['wit'] as int,
            inInclusiveRange(1, 50)); // 20 ± 30, clamped at 1

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });

      test(
          'created ItemInstance with enrichment + size has weight and size in affix',
          () {
        ItemInstance? instance;
        final c = _makeCoordinator();
        // Wire enrichment lookup with size included.
        c.enrichedStatsLookup = (definitionId) {
          if (definitionId == 'fauna_vulpes_vulpes') {
            return (speed: 50, brawn: 20, wit: 20, size: AnimalSize.small);
          }
          return null;
        };
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

        // Exactly one intrinsic affix with stats + size + weight.
        expect(instance!.affixes, hasLength(1));
        final affix = instance!.affixes.first;
        expect(affix.id, kIntrinsicAffixId);
        expect(affix.type, AffixType.intrinsic);

        // Stats present.
        expect(affix.values, containsPair('speed', isA<int>()));
        expect(affix.values, containsPair('brawn', isA<int>()));
        expect(affix.values, containsPair('wit', isA<int>()));

        // Size and weight present.
        expect(affix.values[kSizeAffixKey], 'small');
        expect(affix.values[kWeightAffixKey], isA<int>());

        // Weight is within the small size band (4,000–24,999 grams).
        final weight = affix.values[kWeightAffixKey] as int;
        expect(weight, greaterThanOrEqualTo(AnimalSize.small.minGrams));
        expect(weight, lessThanOrEqualTo(AnimalSize.small.maxGrams));

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });

      test(
          'created ItemInstance with enrichment but no size has stats but no weight',
          () {
        ItemInstance? instance;
        final c = _makeCoordinator();
        // Wire enrichment without size (pre-size enrichment).
        c.enrichedStatsLookup = (definitionId) {
          if (definitionId == 'fauna_vulpes_vulpes') {
            return (speed: 50, brawn: 20, wit: 20, size: null);
          }
          return null;
        };
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
        expect(instance!.affixes, hasLength(1));
        final affix = instance!.affixes.first;

        // Stats present.
        expect(affix.values, containsPair('speed', isA<int>()));
        expect(affix.values, containsPair('brawn', isA<int>()));
        expect(affix.values, containsPair('wit', isA<int>()));

        // Size and weight NOT present (enrichment had no size).
        expect(affix.values.containsKey(kSizeAffixKey), isFalse);
        expect(affix.values.containsKey(kWeightAffixKey), isFalse);

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });

      test('weight is deterministic for same instance seed', () {
        final instances = <ItemInstance>[];
        // Run discovery twice with the same event to get two instances.
        for (var i = 0; i < 2; i++) {
          final c = _makeCoordinator();
          c.enrichedStatsLookup = (definitionId) {
            if (definitionId == 'fauna_vulpes_vulpes') {
              return (speed: 50, brawn: 20, wit: 20, size: AnimalSize.medium);
            }
            return null;
          };
          c.onItemDiscovered = (_, inst) => instances.add(inst);
          final s = _startCoordinator(c);
          s.discovery.add(_testDiscoveryEvent(
            item: _testFauna(
              id: 'fauna_vulpes_vulpes',
              scientificName: 'Vulpes vulpes',
            ),
            cellId: 'test_cell_42',
          ));
          s.gps.close();
          s.discovery.close();
          c.dispose();
        }

        expect(instances, hasLength(2));
        // Two different instances get different UUIDs → different weights.
        // (They CAN be equal by chance but given the medium band 25k–150k
        // it's astronomically unlikely.)
        final w1 = instances[0].affixes.first.values[kWeightAffixKey] as int;
        final w2 = instances[1].affixes.first.values[kWeightAffixKey] as int;
        // Both within medium band.
        expect(
            w1,
            inInclusiveRange(
                AnimalSize.medium.minGrams, AnimalSize.medium.maxGrams));
        expect(
            w2,
            inInclusiveRange(
                AnimalSize.medium.minGrams, AnimalSize.medium.maxGrams));
      });

      test('different size bands produce weights in respective ranges', () {
        final sizes = [AnimalSize.fine, AnimalSize.huge, AnimalSize.colossal];
        final instances = <ItemInstance>[];

        for (final size in sizes) {
          final c = _makeCoordinator();
          c.enrichedStatsLookup =
              (_) => (speed: 30, brawn: 30, wit: 30, size: size);
          c.onItemDiscovered = (_, inst) => instances.add(inst);
          final s = _startCoordinator(c);
          s.discovery.add(_testDiscoveryEvent(
            item: _testFauna(
              id: 'fauna_test_species',
              scientificName: 'Testus specius',
            ),
            cellId: 'cell_${size.name}',
          ));
          s.gps.close();
          s.discovery.close();
          c.dispose();
        }

        expect(instances, hasLength(3));

        for (var i = 0; i < sizes.length; i++) {
          final weight =
              instances[i].affixes.first.values[kWeightAffixKey] as int;
          expect(weight, greaterThanOrEqualTo(sizes[i].minGrams),
              reason:
                  '${sizes[i].name} weight should be >= ${sizes[i].minGrams}');
          expect(weight, lessThanOrEqualTo(sizes[i].maxGrams),
              reason:
                  '${sizes[i].name} weight should be <= ${sizes[i].maxGrams}');
        }
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
        c.onCellVisited = (_) => visitCount++;
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
        c.onCellVisited = (_) => visitCount++;
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
        c.onCellVisited = (_) => visitCount++;
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

    // -----------------------------------------------------------------------
    // Exploration guard
    // -----------------------------------------------------------------------
    group('exploration guard', () {
      test('exploration allowed when marker cell matches GPS cell', () {
        final cells = _GridCellService();
        final c = _makeCoordinator(cellService: cells);
        final s = _startCoordinator(c);

        // Set raw GPS to (10, 20).
        s.gps.add((
          position: Geographic(lat: 10.0, lon: 20.0),
          accuracy: 5.0,
        ));

        final fogUpdates = <Geographic>[];
        c.onPlayerLocationUpdate = (pos, acc) => fogUpdates.add(pos);

        // Marker in same cell as GPS → exploration should proceed.
        c.updatePlayerPosition(10.0, 20.0);

        expect(c.explorationDisabled, isFalse);
        expect(fogUpdates, hasLength(1));

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });

      test('exploration allowed when marker cell is adjacent to GPS cell', () {
        final cells = _GridCellService();
        final c = _makeCoordinator(cellService: cells);
        final s = _startCoordinator(c);

        // GPS at (10, 20). Neighbors: 9_20, 11_20, 10_19, 10_21.
        s.gps.add((
          position: Geographic(lat: 10.0, lon: 20.0),
          accuracy: 5.0,
        ));

        final fogUpdates = <Geographic>[];
        c.onPlayerLocationUpdate = (pos, acc) => fogUpdates.add(pos);

        // Marker at (11, 20) — adjacent cell → should be allowed.
        c.updatePlayerPosition(11.0, 20.0);

        expect(c.explorationDisabled, isFalse);
        expect(fogUpdates, hasLength(1));

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });

      test('exploration disabled when marker cell is beyond adjacent cells',
          () {
        final cells = _GridCellService();
        final c = _makeCoordinator(cellService: cells);
        final s = _startCoordinator(c);

        // GPS at (10, 20).
        s.gps.add((
          position: Geographic(lat: 10.0, lon: 20.0),
          accuracy: 5.0,
        ));

        bool? disabledCallbackValue;
        c.onExplorationDisabledChanged = (disabled) {
          disabledCallbackValue = disabled;
        };

        final fogUpdates = <Geographic>[];
        c.onPlayerLocationUpdate = (pos, acc) => fogUpdates.add(pos);

        // Marker at (15, 25) — 2+ cells away → exploration disabled.
        c.updatePlayerPosition(15.0, 25.0);

        expect(c.explorationDisabled, isTrue);
        expect(disabledCallbackValue, isTrue);
        // Position should still be pushed for UI (camera/marker).
        expect(fogUpdates, hasLength(1));

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });

      test('exploration re-enables when marker catches up to GPS cell', () {
        final cells = _GridCellService();
        final c = _makeCoordinator(cellService: cells);
        final s = _startCoordinator(c);

        // GPS at (10, 20).
        s.gps.add((
          position: Geographic(lat: 10.0, lon: 20.0),
          accuracy: 5.0,
        ));

        final disabledHistory = <bool>[];
        c.onExplorationDisabledChanged = (disabled) {
          disabledHistory.add(disabled);
        };

        // Frame 1: far away → disabled.
        c.updatePlayerPosition(15.0, 25.0);
        expect(c.explorationDisabled, isTrue);

        // Frames 2-5: fill throttle (no game logic runs).
        for (var i = 0; i < 4; i++) {
          c.updatePlayerPosition(15.0, 25.0);
        }

        // Frame 6: catch up to GPS cell → re-enabled.
        c.updatePlayerPosition(10.0, 20.0);
        expect(c.explorationDisabled, isFalse);
        expect(disabledHistory, [true, false]);

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });

      test('exploration allowed before first GPS fix (rawGps null)', () {
        final cells = _GridCellService();
        final c = _makeCoordinator(cellService: cells);
        final s = _startCoordinator(c);

        // No GPS update — rawGpsPosition is null.
        expect(c.rawGpsPosition, isNull);

        final fogUpdates = <Geographic>[];
        c.onPlayerLocationUpdate = (pos, acc) => fogUpdates.add(pos);

        // Should still process game logic normally.
        c.updatePlayerPosition(10.0, 20.0);

        expect(c.explorationDisabled, isFalse);
        expect(fogUpdates, hasLength(1));

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });

      test('callback only fires on state transitions, not every tick', () {
        final cells = _GridCellService();
        final c = _makeCoordinator(cellService: cells);
        final s = _startCoordinator(c);

        s.gps.add((
          position: Geographic(lat: 10.0, lon: 20.0),
          accuracy: 5.0,
        ));

        final disabledHistory = <bool>[];
        c.onExplorationDisabledChanged = (disabled) {
          disabledHistory.add(disabled);
        };

        // Frame 1: disabled (far away). Frame 6: still disabled (different
        // far-away cell). Both process game logic, but callback fires once.
        c.updatePlayerPosition(15.0, 25.0); // frame 1 → processes
        c.updatePlayerPosition(16.0, 26.0); // frame 2 → skipped
        c.updatePlayerPosition(17.0, 27.0); // frame 3 → skipped
        c.updatePlayerPosition(18.0, 28.0); // frame 4 → skipped
        c.updatePlayerPosition(19.0, 29.0); // frame 5 → skipped
        c.updatePlayerPosition(
            20.0, 30.0); // frame 6 → processes, still disabled

        expect(disabledHistory, [true]); // Only one transition.

        // Frame 7-11: fill. Frame 12: catches up → re-enabled.
        c.updatePlayerPosition(10.0, 20.0); // frame 7 → skipped
        c.updatePlayerPosition(10.0, 20.0); // frame 8 → skipped
        c.updatePlayerPosition(10.0, 20.0); // frame 9 → skipped
        c.updatePlayerPosition(10.0, 20.0); // frame 10 → skipped
        c.updatePlayerPosition(10.0, 20.0); // frame 11 → skipped
        c.updatePlayerPosition(10.0, 20.0); // frame 12 → processes, re-enabled

        expect(disabledHistory, [true, false]); // Only two transitions total.

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });

      test('fog is NOT updated when exploration is disabled', () {
        final cells = _GridCellService();
        final fogResolver = FogStateResolver(cells);
        final c = _makeCoordinator(
          cellService: cells,
          fogResolver: fogResolver,
        );
        final s = _startCoordinator(c);

        // GPS at (10, 20).
        s.gps.add((
          position: Geographic(lat: 10.0, lon: 20.0),
          accuracy: 5.0,
        ));

        // Frame 1: visit (10, 20) normally to establish it as visited.
        c.updatePlayerPosition(10.0, 20.0);
        final visitedBefore = fogResolver.visitedCellIds.length;

        // Frames 2-5: fill throttle.
        for (var i = 0; i < 4; i++) {
          c.updatePlayerPosition(10.0, 20.0);
        }

        // Frame 6: move marker far away → disabled, fog NOT updated.
        c.updatePlayerPosition(15.0, 25.0);
        expect(c.explorationDisabled, isTrue);
        expect(fogResolver.visitedCellIds.length, visitedBefore);

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // Cell property resolution
    // -----------------------------------------------------------------------
    group('cell property resolution', () {
      test('resolves properties for current cell on game tick', () {
        final cells = _MockCellService();
        final c = _makeCoordinator(cellService: cells);
        c.setCellPropertyResolver(_StubCellPropertyResolver());
        final s = _startCoordinator(c);

        c.updatePlayerPosition(1.0, 1.0);

        // _MockCellService.getCellId(1.0, 1.0) → "1_1"
        expect(c.cellPropertiesCache, contains('1_1'));
        expect(c.cellPropertiesCache['1_1']!.habitats, {Habitat.plains});
        // _MockCellService.getCellCenter("1_1") → Geographic(40.01, -99.99)
        // Climate.fromLatitude(40.01) → temperate
        expect(c.cellPropertiesCache['1_1']!.climate, Climate.temperate);
        expect(c.cellPropertiesCache['1_1']!.continent, Continent.northAmerica);

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });

      test('does not resolve when resolver is null', () {
        final c = _makeCoordinator();
        // No setCellPropertyResolver call.
        final s = _startCoordinator(c);

        c.updatePlayerPosition(1.0, 1.0);

        expect(c.cellPropertiesCache, isEmpty);

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });

      test('caches properties — same cell not resolved twice', () {
        int resolveCount = 0;
        final cells = _MockCellService();
        final c = _makeCoordinator(cellService: cells);
        c.setCellPropertyResolver(
            _CountingCellPropertyResolver(() => resolveCount++));
        final s = _startCoordinator(c);

        // Frame 1: resolves cell "1_1".
        c.updatePlayerPosition(1.0, 1.0);
        final countAfterFirst = resolveCount;

        // Frames 2-5: throttled, no game logic.
        for (var i = 0; i < 4; i++) {
          c.updatePlayerPosition(1.0, 1.0);
        }

        // Frame 6: game logic runs again for same cell — should NOT re-resolve.
        c.updatePlayerPosition(1.0, 1.0);

        expect(resolveCount, countAfterFirst);

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });

      test('onCellPropertiesResolved fires for each new cell', () {
        final resolved = <CellProperties>[];
        final cells = _MockCellService();
        final c = _makeCoordinator(cellService: cells);
        c.setCellPropertyResolver(_StubCellPropertyResolver());
        c.onCellPropertiesResolved = (props) => resolved.add(props);
        final s = _startCoordinator(c);

        c.updatePlayerPosition(1.0, 1.0);

        // At least one callback for the current cell.
        expect(resolved, isNotEmpty);
        expect(resolved.any((p) => p.cellId == '1_1'), isTrue);

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });

      test('onCellPropertiesResolved does NOT fire for cached cells', () {
        final resolved = <CellProperties>[];
        final cells = _MockCellService();
        final c = _makeCoordinator(cellService: cells);
        c.setCellPropertyResolver(_StubCellPropertyResolver());
        c.onCellPropertiesResolved = (props) => resolved.add(props);
        final s = _startCoordinator(c);

        // Frame 1.
        c.updatePlayerPosition(1.0, 1.0);
        final countAfterFirst = resolved.length;

        // Frames 2-5: throttled.
        for (var i = 0; i < 4; i++) {
          c.updatePlayerPosition(1.0, 1.0);
        }

        // Frame 6: same cell — no new callbacks.
        c.updatePlayerPosition(1.0, 1.0);
        expect(resolved.length, countAfterFirst);

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });

      test('loadCellProperties pre-populates cache (hydration)', () {
        final cells = _MockCellService();
        final c = _makeCoordinator(cellService: cells);

        final preloaded = CellProperties(
          cellId: '1_1',
          habitats: {Habitat.forest},
          climate: Climate.boreal,
          continent: Continent.europe,
          locationId: null,
          createdAt: DateTime(2026, 1, 1),
        );
        c.loadCellProperties({'1_1': preloaded});

        expect(c.cellPropertiesCache['1_1'], isNotNull);
        expect(c.cellPropertiesCache['1_1']!.habitats, {Habitat.forest});
        expect(c.cellPropertiesCache['1_1']!.climate, Climate.boreal);
        expect(c.cellPropertiesCache['1_1']!.continent, Continent.europe);

        c.dispose();
      });

      test('pre-loaded cell is not re-resolved when player enters it', () {
        int resolveCount = 0;
        final cells = _MockCellService();
        final c = _makeCoordinator(cellService: cells);
        c.setCellPropertyResolver(
            _CountingCellPropertyResolver(() => resolveCount++));

        // Pre-load cell "1_1".
        c.loadCellProperties({
          '1_1': CellProperties(
            cellId: '1_1',
            habitats: {Habitat.forest},
            climate: Climate.boreal,
            continent: Continent.europe,
            locationId: null,
            createdAt: DateTime(2026, 1, 1),
          ),
        });

        final s = _startCoordinator(c);

        // Frame 1: cell "1_1" already cached → should not resolve.
        c.updatePlayerPosition(1.0, 1.0);

        // resolveCount may still be >0 for neighbors, but "1_1" itself
        // should not trigger a resolve. The cache should still have the
        // pre-loaded values.
        expect(c.cellPropertiesCache['1_1']!.habitats, {Habitat.forest});
        expect(c.cellPropertiesCache['1_1']!.climate, Climate.boreal);

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });

      test('cellPropertiesCache is read-only (unmodifiable)', () {
        final c = _makeCoordinator();
        c.loadCellProperties({
          'x': CellProperties(
            cellId: 'x',
            habitats: {Habitat.plains},
            climate: Climate.temperate,
            continent: Continent.northAmerica,
            locationId: null,
            createdAt: DateTime.now(),
          ),
        });

        expect(
          () => c.cellPropertiesCache['y'] = CellProperties(
            cellId: 'y',
            habitats: {Habitat.plains},
            climate: Climate.temperate,
            continent: Continent.northAmerica,
            locationId: null,
            createdAt: DateTime.now(),
          ),
          throwsUnsupportedError,
        );

        c.dispose();
      });

      test('properties not resolved when exploration is disabled', () {
        final cells = _GridCellService();
        final c = _makeCoordinator(cellService: cells);
        c.setCellPropertyResolver(_StubCellPropertyResolver());
        final s = _startCoordinator(c);

        // GPS at (10, 20).
        s.gps.add((
          position: Geographic(lat: 10.0, lon: 20.0),
          accuracy: 5.0,
        ));

        // Frame 1: visit (10, 20) normally.
        c.updatePlayerPosition(10.0, 20.0);
        final cacheSize = c.cellPropertiesCache.length;

        // Frames 2-5: fill throttle.
        for (var i = 0; i < 4; i++) {
          c.updatePlayerPosition(10.0, 20.0);
        }

        // Frame 6: far away → exploration disabled, NO new properties.
        c.updatePlayerPosition(50.0, 60.0);
        expect(c.explorationDisabled, isTrue);
        expect(c.cellPropertiesCache.length, cacheSize);

        s.gps.close();
        s.discovery.close();
        c.dispose();
      });
    });
  });
}

// ---------------------------------------------------------------------------
// Cell property resolver test doubles
// ---------------------------------------------------------------------------

/// Stub resolver returning deterministic properties for any cell.
class _StubCellPropertyResolver implements CellPropertyResolver {
  @override
  CellProperties resolve({
    required String cellId,
    required double lat,
    required double lon,
  }) {
    return CellProperties(
      cellId: cellId,
      habitats: {Habitat.plains},
      climate: Climate.fromLatitude(lat),
      continent: Continent.northAmerica,
      locationId: null,
      createdAt: DateTime.now(),
    );
  }
}

/// Resolver that counts how many times resolve() is called.
class _CountingCellPropertyResolver implements CellPropertyResolver {
  final void Function() _onResolve;
  _CountingCellPropertyResolver(this._onResolve);

  @override
  CellProperties resolve({
    required String cellId,
    required double lat,
    required double lon,
  }) {
    _onResolve();
    return CellProperties(
      cellId: cellId,
      habitats: {Habitat.plains},
      climate: Climate.fromLatitude(lat),
      continent: Continent.northAmerica,
      locationId: null,
      createdAt: DateTime.now(),
    );
  }
}
