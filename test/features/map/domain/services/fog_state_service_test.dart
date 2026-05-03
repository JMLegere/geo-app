import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/features/map/domain/services/fog_state_service.dart';

Cell _cell(String id) => Cell(
      id: id,
      habitats: const [],
      polygons: const [[[
        (lat: 0.0, lng: 0.0),
        (lat: 1.0, lng: 0.0),
        (lat: 1.0, lng: 1.0),
      ]]],
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



    test('marks fetched unvisited non-present cells as frontier', () {
      final service = FogStateService();

      final states = service.compute(
        cells: [_cell('cell-a')],
        currentCellId: null,
        exploredCellIds: const {},
      );

      expect(states.single.state.relationship, CellRelationship.frontier);
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
