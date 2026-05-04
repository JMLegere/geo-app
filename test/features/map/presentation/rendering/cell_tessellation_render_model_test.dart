import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/features/map/presentation/rendering/cell_tessellation_render_model.dart';

void main() {
  group('CellTessellationRenderModel', () {
    test('dissolves fills by relationship into one path per reveal state', () {
      final model = CellTessellationRenderModel.build(
        cellsWithStates: [
          (cell: _cell('a', 0, 0, 1, 1), state: _explored),
          (cell: _cell('b', 1, 0, 2, 1), state: _explored),
          (cell: _cell('c', 2, 0, 3, 1), state: _frontier),
        ],
        project: _project,
      );

      expect(
        model.fillPaths.map((path) => path.relationship),
        [CellRelationship.explored, CellRelationship.frontier],
      );
    });

    test('suppresses shared edges between cells with the same visible state',
        () {
      final model = CellTessellationRenderModel.build(
        cellsWithStates: [
          (cell: _cell('a', 0, 0, 1, 1), state: _explored),
          (cell: _cell('b', 1, 0, 2, 1), state: _explored),
        ],
        project: _project,
      );

      expect(
        model.boundaryEdges.where(_isVerticalSharedEdge),
        isEmpty,
        reason: 'Explored/explored internal borders must not double-paint.',
      );
    });

    test('emits one shared boundary when reveal states differ', () {
      final model = CellTessellationRenderModel.build(
        cellsWithStates: [
          (cell: _cell('a', 0, 0, 1, 1), state: _explored),
          (cell: _cell('b', 1, 0, 2, 1), state: _frontier),
        ],
        project: _project,
      );

      expect(model.boundaryEdges.where(_isVerticalSharedEdge), hasLength(1));
      expect(
        model.boundaryEdges
            .where(_isVerticalSharedEdge)
            .single
            .state
            .relationship,
        CellRelationship.explored,
      );
    });

    test('snaps nearly identical shared vertices into one boundary edge', () {
      final model = CellTessellationRenderModel.build(
        cellsWithStates: [
          (cell: _cell('a', 0, 0, 1, 1), state: _explored),
          (cell: _cell('b', 1.0001, 0, 2, 1), state: _frontier),
        ],
        project: _project,
        edgeSnapTolerancePx: 0.5,
      );

      expect(model.boundaryEdges.where(_isVerticalSharedEdge), hasLength(1));
    });
  });
}

const _explored = CellState(
  relationship: CellRelationship.explored,
  contents: CellContents.empty,
);

const _frontier = CellState(
  relationship: CellRelationship.frontier,
  contents: CellContents.empty,
);

Cell _cell(String id, double minX, double minY, double maxX, double maxY) {
  return Cell(
    id: id,
    habitats: const [],
    polygons: [
      [
        [
          (lat: minY, lng: minX),
          (lat: minY, lng: maxX),
          (lat: maxY, lng: maxX),
          (lat: maxY, lng: minX),
          (lat: minY, lng: minX),
        ],
      ],
    ],
    districtId: '',
    cityId: '',
    stateId: '',
    countryId: '',
  );
}

Offset _project(GeoCoord coord) => Offset(coord.lng, coord.lat);

bool _isVerticalSharedEdge(TessellationBoundaryEdge edge) {
  final xMatches =
      (edge.start.dx - 1.0).abs() < 0.01 && (edge.end.dx - 1.0).abs() < 0.01;
  final yMatches = {edge.start.dy, edge.end.dy}.containsAll({0.0, 1.0});
  return xMatches && yMatches;
}
