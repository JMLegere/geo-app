import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/features/map/presentation/diagnostics/map_render_diagnostics_service.dart';
import 'package:earth_nova/features/map/presentation/painters/fog_renderer.dart';

void main() {
  test('reports canonical informed and frontier diagnostics separately', () {
    final summary = const MapRenderDiagnosticsService().summarize(
      cellsWithStates: [
        (
          cell: _cell('informed'),
          state: CellState(
            knowledgeState: CellKnowledgeState.informed,
            category: 'fauna',
            relationship: CellRelationship.explored,
            contents: CellContents.empty,
          ),
        ),
        (
          cell: _cell('frontier'),
          state: CellState(
            knowledgeState: CellKnowledgeState.shrouded,
            relationship: CellRelationship.frontier,
            contents: CellContents.empty,
          ),
        ),
      ],
      viewportSize: const Size(390, 844),
      project: (_) => Offset.zero,
      markerScreenPosition: Offset.zero,
      currentCellId: null,
      visitedCellCount: 0,
      markerIsRing: false,
      markerShowsRing: false,
      markerGapDistanceMeters: 0,
    );

    expect(
      summary['style_fill_grouping_mode'],
      'single_path_per_knowledge_state_and_relationship_even_odd',
    );
    expect(summary['state_informed_cell_ids_sample'], ['informed']);
    expect(summary['state_frontier_cell_ids_sample'], ['frontier']);

    final informedAlpha = FogRenderer.fillColor(
      const CellState(
        knowledgeState: CellKnowledgeState.informed,
        category: 'fauna',
        relationship: CellRelationship.explored,
        contents: CellContents.empty,
      ),
    ).a;
    expect(summary['style_informed_fill_alpha'], closeTo(informedAlpha, 0.001));
    final informedStrokeAlpha = FogRenderer.strokeColor(
      const CellState(
        knowledgeState: CellKnowledgeState.informed,
        category: 'fauna',
        relationship: CellRelationship.explored,
        contents: CellContents.empty,
      ),
    ).a;
    expect(
      summary['style_informed_stroke_alpha'],
      closeTo(informedStrokeAlpha, 0.001),
    );
    expect(
      summary['style_frontier_fill_alpha'],
      summary['style_unknown_fill_alpha'],
    );
    expect(summary['style_frontier_stroke_alpha'], 0);
  });

  test('reports the effective visual ring independently of provider ring', () {
    final summary = const MapRenderDiagnosticsService().summarize(
      cellsWithStates: const [],
      viewportSize: const Size(390, 844),
      project: (_) => Offset.zero,
      markerScreenPosition: Offset.zero,
      currentCellId: null,
      visitedCellCount: 0,
      markerIsRing: false,
      markerShowsRing: true,
      markerGapDistanceMeters: 80,
    );

    expect(summary['marker_is_ring'], isFalse);
    expect(summary['marker_shows_ring'], isTrue);
    expect(summary['marker_visual_mode'], 'accuracy_ring');
  });
}

Cell _cell(String id) => Cell(
  id: id,
  habitats: const [],
  polygons: const [],
  districtId: '',
  cityId: '',
  stateId: '',
  countryId: '',
);
