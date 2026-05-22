import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/habitat.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/presentation/debug/debug_unvisited_cell_target.dart';

Cell _cell(String id, double centerLat, double centerLng) {
  const half = 0.0001;
  return Cell(
    id: id,
    habitats: const [Habitat.forest],
    polygons: [
      [
        [
          (lat: centerLat - half, lng: centerLng - half),
          (lat: centerLat - half, lng: centerLng + half),
          (lat: centerLat + half, lng: centerLng + half),
          (lat: centerLat + half, lng: centerLng - half),
        ],
      ],
    ],
    districtId: 'district',
    cityId: 'city',
    stateId: 'state',
    countryId: 'country',
  );
}

void main() {
  group('selectDebugUnvisitedCellTarget', () {
    test('chooses nearest renderable cell not visited by backend or session',
        () {
      final target = selectDebugUnvisitedCellTarget(
        cells: [
          _cell('current', 0, 0),
          _cell('backend-visited', 0, 0.001),
          _cell('session-visited', 0, 0.002),
          _cell('nearest-unvisited', 0, 0.003),
          _cell('far-unvisited', 0, 0.010),
        ],
        backendVisitedCellIds: const {'backend-visited'},
        sessionVisitedCellIds: const {'session-visited'},
        currentCellId: 'current',
        currentPosition: (lat: 0, lng: 0),
      );

      expect(target, isNotNull);
      expect(target!.cellId, 'nearest-unvisited');
      expect(target.coord.lat, closeTo(0, 0.0000001));
      expect(target.coord.lng, closeTo(0.00292, 0.0000001));
    });

    test('targets just inside the nearest edge instead of the cell centroid',
        () {
      final target = selectDebugUnvisitedCellTarget(
        cells: [
          _cell('current', 0, 0),
          _cell('adjacent', 0, 0.0002),
        ],
        backendVisitedCellIds: const {},
        sessionVisitedCellIds: const {},
        currentCellId: 'current',
        currentPosition: (lat: 0, lng: 0.00009),
      );

      expect(target, isNotNull);
      expect(target!.cellId, 'adjacent');
      expect(target.coord.lng, greaterThan(0.0001));
      expect(target.coord.lng, lessThan(0.0002));
    });

    test('returns null when no unvisited renderable candidate exists', () {
      final target = selectDebugUnvisitedCellTarget(
        cells: [
          _cell('current', 0, 0),
          _cell('backend-visited', 0, 0.001),
          const Cell(
            id: 'unrenderable',
            habitats: [Habitat.forest],
            polygons: [],
            districtId: 'district',
            cityId: 'city',
            stateId: 'state',
            countryId: 'country',
          ),
        ],
        backendVisitedCellIds: const {'backend-visited'},
        sessionVisitedCellIds: const {},
        currentCellId: 'current',
        currentPosition: (lat: 0, lng: 0),
      );

      expect(target, isNull);
    });
  });
}
