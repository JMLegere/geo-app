import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/ui/product_surfaces/map/rendering/cell_tessellation_render_model.dart';

void main() {
  group('CellTessellationRenderModel', () {
    test('groups fills by all four knowledge states', () {
      final model = CellTessellationRenderModel.build(
        cellsWithStates: [
          (cell: _cell('present', 0, 0, 1, 1), state: _present),
          (cell: _cell('informed', 1, 0, 2, 1), state: _informed),
          (cell: _cell('explored-a', 2, 0, 3, 1), state: _explored),
          (cell: _cell('explored-b', 3, 0, 4, 1), state: _explored),
          (cell: _cell('shrouded', 4, 0, 5, 1), state: _unknown),
        ],
        project: _project,
      );

      expect(
        model.fillPaths.map((path) => path.knowledgeState),
        CellKnowledgeState.values,
      );
      expect(model.fillPaths.map((path) => path.relationship), [
        CellRelationship.present,
        CellRelationship.explored,
        CellRelationship.explored,
        CellRelationship.unknown,
      ]);
      expect(
        model.fillPaths
            .where((path) => path.knowledgeState == CellKnowledgeState.explored)
            .single
            .path
            .getBounds(),
        Rect.fromLTRB(2, 0, 4, 1),
        reason: 'Same-state polygons must still dissolve into one fill path.',
      );
    });

    test('keeps shared edges between explored cells visible and distinct', () {
      final model = CellTessellationRenderModel.build(
        cellsWithStates: [
          (cell: _cell('a', 0, 0, 1, 1), state: _explored),
          (cell: _cell('b', 1, 0, 2, 1), state: _explored),
        ],
        project: _project,
      );

      expect(
        model.boundaryEdges.where(_isVerticalSharedEdge),
        hasLength(1),
        reason: 'Explored/explored internal borders should remain distinct.',
      );
      expect(
        model.boundaryEdges
            .where(_isVerticalSharedEdge)
            .single
            .state
            .relationship,
        CellRelationship.explored,
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

    test('emits a visible frontier outline against unknown territory', () {
      final model = CellTessellationRenderModel.build(
        cellsWithStates: [
          (cell: _cell('a', 0, 0, 1, 1), state: _frontier),
          (cell: _cell('b', 1, 0, 2, 1), state: _unknown),
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
        CellRelationship.frontier,
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

const _present = CellState(
  knowledgeState: CellKnowledgeState.present,
  relationship: CellRelationship.present,
  contents: CellContents.empty,
);

const _informed = CellState(
  knowledgeState: CellKnowledgeState.informed,
  category: 'fauna',
  relationship: CellRelationship.explored,
  contents: CellContents.empty,
);

const _explored = CellState(
  knowledgeState: CellKnowledgeState.explored,
  relationship: CellRelationship.explored,
  contents: CellContents.empty,
);

const _frontier = CellState(
  knowledgeState: CellKnowledgeState.informed,
  category: 'fauna',
  relationship: CellRelationship.frontier,
  contents: CellContents.empty,
);

const _unknown = CellState(
  knowledgeState: CellKnowledgeState.shrouded,
  relationship: CellRelationship.unknown,
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
