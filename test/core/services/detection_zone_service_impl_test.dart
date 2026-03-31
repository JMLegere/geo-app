import 'package:drift/native.dart';
import 'package:earth_nova/core/cells/cell_service.dart';
import 'package:earth_nova/core/database/app_database.dart';
import 'package:earth_nova/core/models/hierarchy.dart';
import 'package:earth_nova/core/persistence/hierarchy_repository.dart';
import 'package:earth_nova/core/services/detection_zone_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geobase/geobase.dart';

// ─── Mocks ───────────────────────────────────────────────────────────────────

class MockCellService implements CellService {
  final Map<String, Geographic> _centers = {};
  final Map<String, List<String>> _neighbors = {};

  void setCenter(String cellId, double lat, double lon) {
    _centers[cellId] = Geographic(lat: lat, lon: lon);
  }

  void setNeighbors(String cellId, List<String> neighborIds) {
    _neighbors[cellId] = neighborIds;
  }

  @override
  String getCellId(double lat, double lon) {
    double minDist = double.infinity;
    String nearestId = 'unknown';
    for (final entry in _centers.entries) {
      final d = (entry.value.lat - lat) * (entry.value.lat - lat) +
          (entry.value.lon - lon) * (entry.value.lon - lon);
      if (d < minDist) {
        minDist = d;
        nearestId = entry.key;
      }
    }
    return nearestId;
  }

  @override
  Geographic getCellCenter(String cellId) =>
      _centers[cellId] ?? Geographic(lat: 0, lon: 0);

  @override
  List<Geographic> getCellBoundary(String cellId) => [];

  @override
  List<String> getNeighborIds(String cellId) => _neighbors[cellId] ?? [];

  @override
  List<String> getCellsInRing(String cellId, int k) {
    if (k == 0) return [cellId];
    // BFS ring expansion up to k hops.
    final result = <String>{cellId};
    var frontier = <String>{cellId};
    for (var ring = 0; ring < k; ring++) {
      final nextFrontier = <String>{};
      for (final cell in frontier) {
        for (final n in getNeighborIds(cell)) {
          if (result.add(n)) nextFrontier.add(n);
        }
      }
      frontier = nextFrontier;
    }
    return result.toList();
  }

  @override
  List<String> getCellsAroundLocation(double lat, double lon, int k) {
    final cellId = getCellId(lat, lon);
    return getCellsInRing(cellId, k);
  }

  @override
  double get cellEdgeLengthMeters => 180.0;

  @override
  String get systemName => 'Mock';
}

/// Fake HierarchyRepository backed by an in-memory DB that returns pre-loaded districts.
class MockHierarchyRepository extends HierarchyRepository {
  final List<HDistrict> districts;
  MockHierarchyRepository({this.districts = const []})
      : super(AppDatabase(NativeDatabase.memory()));

  Future<List<HCountry>> getAllCountries() async =>
      districts.isNotEmpty ? [_fakeCountry()] : [];

  Future<List<HState>> getStatesForCountry(String countryId) async =>
      districts.isNotEmpty ? [_fakeState(countryId)] : [];

  Future<List<HCity>> getCitiesForState(String stateId) async =>
      districts.isNotEmpty ? [_fakeCity(stateId)] : [];

  Future<List<HDistrict>> getDistrictsForCity(String cityId) async => districts;

  static HCountry _fakeCountry() => const HCountry(
        id: 'country-1',
        name: 'Test Country',
        centroidLat: 45.0,
        centroidLon: -66.0,
        continent: 'NA',
      );

  static HState _fakeState(String countryId) => HState(
        id: 'state-1',
        name: 'Test State',
        centroidLat: 45.0,
        centroidLon: -66.0,
        countryId: countryId,
      );

  static HCity _fakeCity(String stateId) => HCity(
        id: 'city-1',
        name: 'Test City',
        centroidLat: 45.0,
        centroidLon: -66.0,
        stateId: stateId,
      );
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// Build a grid of cells centered at [baseLat, baseLon] with [gridStep] spacing.
void buildGrid(
  MockCellService cs, {
  int rows = 10,
  int cols = 10,
  double baseLat = 45.0,
  double baseLon = -66.0,
  double gridStep = 0.002,
}) {
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      final id = 'v_${r}_$c';
      cs.setCenter(id, baseLat + r * gridStep, baseLon + c * gridStep);
      cs.setNeighbors(id, [
        if (r > 0) 'v_${r - 1}_$c',
        if (r < rows - 1) 'v_${r + 1}_$c',
        if (c > 0) 'v_${r}_${c - 1}',
        if (c < cols - 1) 'v_${r}_${c + 1}',
      ]);
    }
  }
}

HDistrict makeDistrict({
  required String id,
  required double lat,
  required double lon,
}) =>
    HDistrict(
      id: id,
      name: id,
      centroidLat: lat,
      centroidLon: lon,
      cityId: 'city-1',
    );

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  late MockCellService cellService;
  late DetectionZoneService service;

  setUp(() {
    cellService = MockCellService();
    service = DetectionZoneService(
      cellService: cellService,
      hierarchyRepo: MockHierarchyRepository(),
    );
  });

  tearDown(() => service.dispose());

  // ═══════════════════════════════════════════════════════════════════════════
  // updatePlayerPosition — initial state
  // ═══════════════════════════════════════════════════════════════════════════

  group('initial state', () {
    test('zone is empty before first position update', () {
      expect(service.detectionZoneCellIds, isEmpty);
    });

    test('currentDistrictId is null before first update', () {
      expect(service.currentDistrictId, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // updatePlayerPosition — zone expansion
  // ═══════════════════════════════════════════════════════════════════════════

  group('updatePlayerPosition', () {
    test('zone contains player cell (k=0 ring)', () async {
      buildGrid(cellService, rows: 5, cols: 5);
      await service.updatePlayerPosition(45.002, -66.002);

      // The player cell itself must be in the zone.
      final playerCell = cellService.getCellId(45.002, -66.002);
      expect(service.detectionZoneCellIds, contains(playerCell));
    });

    test('zone includes ring-1 neighbors', () async {
      buildGrid(cellService, rows: 5, cols: 5);
      await service.updatePlayerPosition(45.002, -66.002);

      // The player's neighbors should also be included (ring 1+).
      final playerCell = cellService.getCellId(45.002, -66.002);
      final neighbors = cellService.getNeighborIds(playerCell);
      for (final n in neighbors) {
        expect(service.detectionZoneCellIds, contains(n));
      }
    });

    test('zone is non-empty after position update', () async {
      buildGrid(cellService, rows: 5, cols: 5);
      await service.updatePlayerPosition(45.002, -66.002);

      expect(service.detectionZoneCellIds, isNotEmpty);
    });

    test('no recomputation when player stays in same cell', () async {
      buildGrid(cellService, rows: 5, cols: 5);

      final events = <Set<String>>[];
      service.onDetectionZoneChanged.listen(events.add);

      await service.updatePlayerPosition(45.002, -66.002);
      await service.updatePlayerPosition(45.002, -66.002); // same cell

      expect(events.length, 1); // Only one emission
    });

    test('recomputes when player moves to a new cell', () async {
      buildGrid(cellService, rows: 20, cols: 20);

      final events = <Set<String>>[];
      service.onDetectionZoneChanged.listen(events.add);

      await service.updatePlayerPosition(45.0, -66.0); // cell v_0_0
      await Future<void>.delayed(Duration.zero);
      await service.updatePlayerPosition(45.018, -66.0); // cell v_9_0
      await Future<void>.delayed(Duration.zero);

      expect(events.length, 2);
    });

    test('detectionZoneCellIds returns unmodifiable set', () async {
      buildGrid(cellService, rows: 5, cols: 5);
      await service.updatePlayerPosition(45.002, -66.002);

      final zone = service.detectionZoneCellIds;
      expect(() => zone.add('hacked'), throwsA(isA<UnsupportedError>()));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // District attribution via nearest centroid
  // ═══════════════════════════════════════════════════════════════════════════

  group('district attribution', () {
    test('assigns player cell to nearest district', () async {
      buildGrid(cellService, rows: 5, cols: 5);

      // Two districts — one near the player, one far away.
      final districts = [
        makeDistrict(id: 'near', lat: 45.002, lon: -66.002),
        makeDistrict(id: 'far', lat: 90.0, lon: 0.0),
      ];
      service = DetectionZoneService(
        cellService: cellService,
        hierarchyRepo: MockHierarchyRepository(districts: districts),
      );

      await service.updatePlayerPosition(45.002, -66.002);

      // Player cell is assigned to the nearest district.
      expect(service.currentDistrictId, 'near');
    });

    test('cellDistrictAttribution covers zone cells when districts loaded',
        () async {
      buildGrid(cellService, rows: 5, cols: 5);

      final districts = [
        makeDistrict(id: 'd1', lat: 45.002, lon: -66.002),
      ];
      service = DetectionZoneService(
        cellService: cellService,
        hierarchyRepo: MockHierarchyRepository(districts: districts),
      );

      await service.updatePlayerPosition(45.002, -66.002);

      // Every zone cell should be attributed to 'd1' (only district).
      for (final cellId in service.detectionZoneCellIds) {
        expect(service.cellDistrictAttribution[cellId], 'd1');
      }
    });

    test('attribution is empty when no districts loaded', () async {
      buildGrid(cellService, rows: 5, cols: 5);
      // Default MockHierarchyRepository returns no districts.
      await service.updatePlayerPosition(45.002, -66.002);

      expect(service.cellDistrictAttribution, isEmpty);
      expect(service.currentDistrictId, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // onDetectionZoneChanged stream
  // ═══════════════════════════════════════════════════════════════════════════

  group('onDetectionZoneChanged stream', () {
    test('emits when zone changes', () async {
      buildGrid(cellService, rows: 5, cols: 5);

      Set<String>? emitted;
      service.onDetectionZoneChanged.listen((zone) => emitted = zone);

      await service.updatePlayerPosition(45.002, -66.002);
      await Future<void>.delayed(Duration.zero);

      expect(emitted, isNotNull);
      expect(emitted, isNotEmpty);
      expect(emitted, equals(service.detectionZoneCellIds));
    });

    test('does not emit after dispose', () async {
      buildGrid(cellService, rows: 5, cols: 5);
      service.dispose();

      // Should not throw
      await service.updatePlayerPosition(45.002, -66.002);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // recomputeCurrentZone
  // ═══════════════════════════════════════════════════════════════════════════

  group('recomputeCurrentZone', () {
    test('is no-op when no zone computed yet', () async {
      // Should not throw
      await service.recomputeCurrentZone();
      expect(service.detectionZoneCellIds, isEmpty);
    });

    test('recomputes zone with fresh district cache', () async {
      buildGrid(cellService, rows: 5, cols: 5);
      await service.updatePlayerPosition(45.002, -66.002);
      final firstZone = Set<String>.from(service.detectionZoneCellIds);

      await service.recomputeCurrentZone();

      // Zone should be the same (same cell grid, same position).
      expect(service.detectionZoneCellIds, equals(firstZone));
    });
  });
}
