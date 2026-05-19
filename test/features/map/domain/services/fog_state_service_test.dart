import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/features/map/domain/services/fog_state_service.dart';

Cell _cell(String id) => _squareCell(id, minLat: 0, minLng: 0);

Cell _squareCell(
  String id, {
  required double minLat,
  required double minLng,
}) =>
    Cell(
      id: id,
      habitats: const [],
      polygons: [
        [
          [
            (lat: minLat, lng: minLng),
            (lat: minLat + 1.0, lng: minLng),
            (lat: minLat + 1.0, lng: minLng + 1.0),
            (lat: minLat, lng: minLng + 1.0),
            (lat: minLat, lng: minLng),
          ],
        ],
      ],
      districtId: 'district',
      cityId: 'city',
      stateId: 'state',
      countryId: 'country',
    );

void main() {
  group('FogStateService', () {
    test('marks current marker cell as present', () {
      final service = FogStateService();

      final states = service.compute(
        cells: [_cell('cell-a'), _cell('cell-b')],
        currentCellId: 'cell-a',
        exploredCellIds: const {},
      );

      final state =
          states.firstWhere((entry) => entry.cell.id == 'cell-a').state;
      expect(state.relationship, CellRelationship.present);
    });

    test('marks explored footprint cells as explored when not present', () {
      final service = FogStateService();

      final states = service.compute(
        cells: [_cell('cell-a')],
        currentCellId: null,
        exploredCellIds: {'cell-a'},
      );

      expect(states.single.state.relationship, CellRelationship.explored);
    });

    test('marks unvisited border neighbors as frontier', () {
      final service = FogStateService();

      final states = service.compute(
        cells: [
          _squareCell('visited', minLat: 0, minLng: 0),
          _squareCell('edge-neighbor', minLat: 1, minLng: 0),
          _squareCell('corner-touch', minLat: 1, minLng: 1),
          _squareCell('distant', minLat: 3, minLng: 0),
        ],
        currentCellId: null,
        exploredCellIds: {'visited'},
      );

      CellRelationship relationshipOf(String cellId) => states
          .firstWhere((entry) => entry.cell.id == cellId)
          .state
          .relationship;

      expect(relationshipOf('edge-neighbor'), CellRelationship.frontier);
      expect(relationshipOf('corner-touch'), CellRelationship.unknown);
      expect(relationshipOf('distant'), CellRelationship.unknown);
    });

    test('treats present cell borders as revealed frontier anchors', () {
      final service = FogStateService();

      final states = service.compute(
        cells: [
          _squareCell('current', minLat: 0, minLng: 0),
          _squareCell('edge-neighbor', minLat: 0, minLng: 1),
          _squareCell('distant', minLat: 0, minLng: 3),
        ],
        currentCellId: 'current',
        exploredCellIds: const {},
      );

      CellRelationship relationshipOf(String cellId) => states
          .firstWhere((entry) => entry.cell.id == cellId)
          .state
          .relationship;

      expect(relationshipOf('current'), CellRelationship.present);
      expect(relationshipOf('edge-neighbor'), CellRelationship.frontier);
      expect(relationshipOf('distant'), CellRelationship.unknown);
    });

    test('present wins over visited state', () {
      final service = FogStateService();

      final states = service.compute(
        cells: [_cell('cell-a')],
        currentCellId: 'cell-a',
        exploredCellIds: {'cell-a'},
      );

      expect(states.single.state.relationship, CellRelationship.present);
    });
  });
}
