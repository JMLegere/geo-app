import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/domain/cells/detection_zone_service.dart';
import 'package:earth_nova/models/hierarchy.dart';

import '../../fixtures/test_helpers.dart';

void main() {
  group('DetectionZoneService', () {
    late MockCellService cellService;
    late DetectionZoneService service;
    late List<String> logLines;

    setUp(() {
      cellService = buildStarGrid();
      logLines = <String>[];
      service = DetectionZoneService(
        cellService: cellService,
        onLog: logLines.add,
      );
    });

    tearDown(() {
      service.dispose();
    });

    test('updatePlayerPosition creates zone with cells from ring-0 to ring-15',
        () async {
      await service.updatePlayerPosition(kTestLat, kTestLon);

      // Star grid: center A with neighbors B, C, D — all reachable within ring-1.
      expect(service.zoneCellIds, contains(kTestCellA));
      expect(service.zoneCellIds, contains(kTestCellB));
      expect(service.zoneCellIds, contains(kTestCellC));
      expect(service.zoneCellIds, contains(kTestCellD));
    });

    test('updatePlayerPosition skips recomputation when same cell', () async {
      await service.updatePlayerPosition(kTestLat, kTestLon);
      final firstZone = service.zoneCellIds;

      // Same cell — zone should not change (same contents).
      await service.updatePlayerPosition(kTestLat, kTestLon);
      expect(service.zoneCellIds, equals(firstZone));
    });

    test('updatePlayerPosition recomputes when player moves to different cell',
        () async {
      await service.updatePlayerPosition(kTestLat, kTestLon);
      expect(service.centeredOnCellId, kTestCellA);

      // Move to cell B position.
      await service.updatePlayerPosition(kTestLat + 0.01, kTestLon);
      expect(service.centeredOnCellId, kTestCellB);
      // Zone now centered on B.
      expect(service.zoneCellIds, contains(kTestCellB));
    });

    test('onZoneChanged stream fires when zone changes', () async {
      final events = <Set<String>>[];
      final sub = service.onZoneChanged.listen(events.add);

      await service.updatePlayerPosition(kTestLat, kTestLon);
      await Future<void>.delayed(Duration.zero);

      expect(events.length, 1);
      expect(events.first, contains(kTestCellA));

      sub.cancel();
    });

    test('onZoneChanged does NOT fire when same cell', () async {
      final events = <Set<String>>[];
      final sub = service.onZoneChanged.listen(events.add);

      await service.updatePlayerPosition(kTestLat, kTestLon);
      await service.updatePlayerPosition(kTestLat, kTestLon); // same cell
      await Future<void>.delayed(Duration.zero);

      expect(events.length, 1);

      sub.cancel();
    });

    test('recompute forces zone recomputation even without cell change',
        () async {
      await service.updatePlayerPosition(kTestLat, kTestLon);
      await Future<void>.delayed(Duration.zero);

      final events = <Set<String>>[];
      final sub = service.onZoneChanged.listen(events.add);

      service.recompute();
      await Future<void>.delayed(Duration.zero);

      expect(events.length, 1);
      expect(events.first, contains(kTestCellA));

      sub.cancel();
    });

    test('recompute is a no-op before first position update', () async {
      final events = <Set<String>>[];
      final sub = service.onZoneChanged.listen(events.add);

      service.recompute();
      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty);

      sub.cancel();
    });

    test('zoneCellIds returns unmodifiable copy', () async {
      await service.updatePlayerPosition(kTestLat, kTestLon);

      final zone = service.zoneCellIds;
      expect(() => (zone as dynamic).add('injected'), throwsUnsupportedError);
    });

    test('dispose closes the stream', () async {
      service.dispose();

      expect(
        service.onZoneChanged.listen((_) {}),
        isNotNull, // listen itself doesn't throw
      );
      // After dispose, stream should be closed — new listeners get onDone.
      final done = Completer<void>();
      service.onZoneChanged.listen(null, onDone: done.complete);
      await done.future.timeout(const Duration(seconds: 1));
    });

    test('zone includes ring-0 (player cell) and ring-1 (neighbors)', () async {
      await service.updatePlayerPosition(kTestLat, kTestLon);

      // Ring-0 is the player cell.
      expect(service.zoneCellIds, contains(kTestCellA));
      // Ring-1 neighbors are all present.
      expect(service.zoneCellIds,
          containsAll([kTestCellB, kTestCellC, kTestCellD]));
    });

    test('zone includes all reachable cells in the configured grid', () async {
      await service.updatePlayerPosition(kTestLat, kTestLon);

      // Star grid has 4 cells total — all should be in the detection zone.
      expect(service.zoneCellIds.length, greaterThanOrEqualTo(4));
    });

    // -------------------------------------------------------------------------
    // District attribution tests
    // -------------------------------------------------------------------------

    test('district attribution assigns cells to nearest district centroid',
        () async {
      // Two districts: one near cell A, one near cell B.
      final districtA = HDistrict(
        id: 'district_A',
        name: 'District Alpha',
        centroidLat: kTestLat,
        centroidLon: kTestLon,
        cityId: 'city_1',
      );
      final districtB = HDistrict(
        id: 'district_B',
        name: 'District Beta',
        centroidLat: kTestLat + 0.01,
        centroidLon: kTestLon,
        cityId: 'city_1',
      );

      service.districtLoader = () async => [districtA, districtB];

      await service.updatePlayerPosition(kTestLat, kTestLon);

      // Player cell A is closest to districtA centroid.
      expect(service.currentDistrictId, 'district_A');
      // Cell B is closest to districtB centroid.
      expect(service.cellDistrictAttribution[kTestCellB], 'district_B');
    });

    test('district loader is called once and result is cached', () async {
      var callCount = 0;
      service.districtLoader = () async {
        callCount++;
        return [
          HDistrict(
            id: 'district_A',
            name: 'District Alpha',
            centroidLat: kTestLat,
            centroidLon: kTestLon,
            cityId: 'city_1',
          ),
        ];
      };

      // First call — loads districts.
      await service.updatePlayerPosition(kTestLat, kTestLon);
      expect(callCount, 1);

      // Move to a new cell — should NOT reload districts.
      await service.updatePlayerPosition(kTestLat + 0.01, kTestLon);
      expect(callCount, 1);
    });

    test('emits detection zone log when zone changes', () async {
      await service.updatePlayerPosition(kTestLat, kTestLon);

      expect(logLines, isNotEmpty);
      expect(logLines.last, startsWith('[DETECTION_ZONE]'));
      expect(logLines.last, contains('center=cell_A'));
    });

    test('does not emit detection zone log when player stays in same cell',
        () async {
      await service.updatePlayerPosition(kTestLat, kTestLon);
      final firstLogCount = logLines.length;

      await service.updatePlayerPosition(kTestLat, kTestLon);

      expect(logLines, hasLength(firstLogCount));
    });
  });
}
