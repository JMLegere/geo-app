import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/features/map/domain/services/cell_geometry_diagnostics_service.dart';

void main() {
  group('CellGeometryDiagnosticsService', () {
    const service = CellGeometryDiagnosticsService();

    test('summarizes blocky rectangular geometry for telemetry', () {
      final diagnostics = service.summarizeFetchedCells([
        _rectangularCell('rect-1'),
        _organicCell('organic-1'),
      ]);

      expect(diagnostics['geometry_total_cells'], 2);
      expect(diagnostics['geometry_renderable_cells'], 2);
      expect(diagnostics['geometry_exterior_ring_count'], 2);
      expect(diagnostics['geometry_total_points'], greaterThan(8));
      expect(diagnostics['geometry_min_exterior_points'], 4);
      expect(diagnostics['geometry_max_exterior_points'], greaterThan(4));
      expect(diagnostics['geometry_four_point_exterior_count'], 1);
      expect(diagnostics['geometry_rectangular_cell_count'], 1);
      expect(diagnostics['geometry_rectangular_cell_ratio'], 0.5);
      expect(diagnostics['geometry_axis_aligned_edge_ratio'],
          greaterThanOrEqualTo(0.4));
      expect(
        diagnostics['geometry_shape_warnings'],
        contains('rectangular_cells_present'),
      );
    });

    test('summarizes render relationship counts for overlay telemetry', () {
      final diagnostics = service.summarizeRenderedCells([
        (
          cell: _rectangularCell('present'),
          state: const CellState(
            relationship: CellRelationship.present,
            contents: CellContents.empty,
          ),
        ),
        (
          cell: _organicCell('frontier'),
          state: const CellState(
            relationship: CellRelationship.frontier,
            contents: CellContents.empty,
          ),
        ),
      ]);

      expect(diagnostics['render_cell_count'], 2);
      expect(diagnostics['render_present_cell_count'], 1);
      expect(diagnostics['render_frontier_cell_count'], 1);
      expect(diagnostics['render_rectangular_cell_count'], 1);
      expect(diagnostics['render_axis_aligned_edge_ratio'],
          greaterThanOrEqualTo(0.4));
    });
  });
}

Cell _rectangularCell(String id) => Cell(
      id: id,
      habitats: const [],
      polygons: const [
        [
          [
            (lat: 45.0, lng: -66.0),
            (lat: 45.0, lng: -65.99),
            (lat: 45.01, lng: -65.99),
            (lat: 45.01, lng: -66.0),
            (lat: 45.0, lng: -66.0),
          ],
        ],
      ],
      districtId: 'd1',
      cityId: 'c1',
      stateId: 's1',
      countryId: 'co1',
    );

Cell _organicCell(String id) => Cell(
      id: id,
      habitats: const [],
      polygons: const [
        [
          [
            (lat: 45.0, lng: -66.0),
            (lat: 45.003, lng: -65.996),
            (lat: 45.008, lng: -65.997),
            (lat: 45.011, lng: -66.002),
            (lat: 45.006, lng: -66.008),
            (lat: 45.001, lng: -66.006),
            (lat: 45.0, lng: -66.0),
          ],
        ],
      ],
      districtId: 'd1',
      cityId: 'c1',
      stateId: 's1',
      countryId: 'co1',
    );
