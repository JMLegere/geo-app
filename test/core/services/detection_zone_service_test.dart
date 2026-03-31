import 'package:drift/native.dart';
import 'package:earth_nova/core/cells/cell_service.dart';
import 'package:earth_nova/core/database/app_database.dart';
import 'package:earth_nova/core/models/hierarchy.dart';
import 'package:earth_nova/core/persistence/hierarchy_repository.dart';
import 'package:earth_nova/core/services/detection_zone_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geobase/geobase.dart';

/// Mock CellService for testing.
class MockCellService implements CellService {
  final Map<String, Geographic> _centers = {};
  final Map<String, List<String>> _neighbors = {};
  final Map<String, List<Geographic>> _boundaries = {};

  void setCenter(String cellId, double lat, double lon) {
    _centers[cellId] = Geographic(lat: lat, lon: lon);
  }

  void setNeighbors(String cellId, List<String> neighborIds) {
    _neighbors[cellId] = neighborIds;
  }

  void setBoundary(String cellId, List<Geographic> boundary) {
    _boundaries[cellId] = boundary;
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
  Geographic getCellCenter(String cellId) {
    return _centers[cellId] ?? Geographic(lat: 0, lon: 0);
  }

  @override
  List<Geographic> getCellBoundary(String cellId) {
    return _boundaries[cellId] ?? [];
  }

  @override
  List<String> getNeighborIds(String cellId) {
    return _neighbors[cellId] ?? [];
  }

  @override
  List<String> getCellsInRing(String cellId, int k) {
    if (k == 0) return [cellId];
    final result = <String>{cellId};
    var frontier = <String>{cellId};
    for (var ring = 0; ring < k; ring++) {
      final nextFrontier = <String>{};
      for (final cell in frontier) {
        nextFrontier.addAll(getNeighborIds(cell));
      }
      result.addAll(nextFrontier);
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
  String get systemName => 'Mock Voronoi';
}

/// Empty HierarchyRepository for tests that don't need districts.
class EmptyHierarchyRepository extends HierarchyRepository {
  EmptyHierarchyRepository() : super(AppDatabase(NativeDatabase.memory()));

  @override
  Future<List<HCountry>> getAllCountries() async => [];

  @override
  Future<List<HState>> getStatesForCountry(String countryId) async => [];

  @override
  Future<List<HCity>> getCitiesForState(String stateId) async => [];

  @override
  Future<List<HDistrict>> getDistrictsForCity(String cityId) async => [];
}

void main() {
  group('DetectionZoneService', () {
    late MockCellService cellService;
    late EmptyHierarchyRepository hierarchyRepo;

    setUp(() {
      cellService = MockCellService();
      hierarchyRepo = EmptyHierarchyRepository();
    });

    group('initial state', () {
      test('zone is empty before first position update', () {
        final service = DetectionZoneService(
          cellService: cellService,
          hierarchyRepo: hierarchyRepo,
        );
        expect(service.detectionZoneCellIds, isEmpty);
        service.dispose();
      });

      test('currentDistrictId is null before first update', () {
        final service = DetectionZoneService(
          cellService: cellService,
          hierarchyRepo: hierarchyRepo,
        );
        expect(service.currentDistrictId, isNull);
        service.dispose();
      });
    });

    group('updatePlayerPosition', () {
      test('zone is non-empty after GPS update', () async {
        // Set up a small grid
        for (var r = 0; r < 5; r++) {
          for (var c = 0; c < 5; c++) {
            final id = 'v_${r}_$c';
            cellService.setCenter(id, 45.0 + r * 0.002, -66.0 + c * 0.002);
            cellService.setNeighbors(id, [
              if (r > 0) 'v_${r - 1}_$c',
              if (r < 4) 'v_${r + 1}_$c',
              if (c > 0) 'v_${r}_${c - 1}',
              if (c < 4) 'v_${r}_${c + 1}',
            ]);
          }
        }

        final service = DetectionZoneService(
          cellService: cellService,
          hierarchyRepo: hierarchyRepo,
        );

        await service.updatePlayerPosition(45.002, -66.002);

        expect(service.detectionZoneCellIds, isNotEmpty);
        service.dispose();
      });

      test('detectionZoneCellIds is unmodifiable', () async {
        cellService.setCenter('v_0_0', 45.0, -66.0);

        final service = DetectionZoneService(
          cellService: cellService,
          hierarchyRepo: hierarchyRepo,
        );
        await service.updatePlayerPosition(45.0, -66.0);

        final zone = service.detectionZoneCellIds;
        expect(() => zone.add('x'), throwsA(isA<UnsupportedError>()));
        service.dispose();
      });

      test('no-op for same cell position', () async {
        cellService.setCenter('v_0_0', 45.0, -66.0);

        final service = DetectionZoneService(
          cellService: cellService,
          hierarchyRepo: hierarchyRepo,
        );

        final events = <Set<String>>[];
        service.onDetectionZoneChanged.listen(events.add);

        await service.updatePlayerPosition(45.0, -66.0);
        await service.updatePlayerPosition(45.0, -66.0);

        expect(events.length, 1);
        service.dispose();
      });
    });

    group('dispose safety', () {
      test('does not crash if updatePlayerPosition called after dispose',
          () async {
        cellService.setCenter('v_0_0', 45.0, -66.0);
        final service = DetectionZoneService(
          cellService: cellService,
          hierarchyRepo: hierarchyRepo,
        );
        service.dispose();

        // Should not throw
        await service.updatePlayerPosition(45.0, -66.0);
      });
    });
  });
}
