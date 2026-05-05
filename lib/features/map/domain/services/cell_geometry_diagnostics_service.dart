import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';

class CellGeometryDiagnosticsService {
  const CellGeometryDiagnosticsService();

  static const double _coordinateTolerance = 1e-9;

  Map<String, dynamic> summarizeFetchedCells(List<Cell> cells) {
    final summary = _summarizeCells(cells);
    return {
      'geometry_total_cells': cells.length,
      'geometry_renderable_cells': summary.renderableCellCount,
      ...summary.toTelemetry(prefix: 'geometry'),
    };
  }

  Map<String, dynamic> summarizeRenderedCells(
    List<({Cell cell, CellState state})> cellsWithStates,
  ) {
    final cells = [for (final entry in cellsWithStates) entry.cell];
    final summary = _summarizeCells(cells);
    final relationshipCounts = <CellRelationship, int>{
      for (final relationship in CellRelationship.values) relationship: 0,
    };

    for (final entry in cellsWithStates) {
      relationshipCounts.update(entry.state.relationship, (value) => value + 1);
    }

    return {
      'render_cell_count': cellsWithStates.length,
      'render_present_cell_count':
          relationshipCounts[CellRelationship.present] ?? 0,
      'render_explored_cell_count':
          relationshipCounts[CellRelationship.explored] ?? 0,
      'render_frontier_cell_count':
          relationshipCounts[CellRelationship.frontier] ?? 0,
      'render_unknown_cell_count':
          relationshipCounts[CellRelationship.unknown] ?? 0,
      ...summary.toTelemetry(prefix: 'render'),
    };
  }

  _GeometryDiagnosticsSummary _summarizeCells(List<Cell> cells) {
    var renderableCellCount = 0;
    var totalPolygonCount = 0;
    var totalRingCount = 0;
    var totalPointCount = 0;
    var exteriorRingCount = 0;
    var fourPointExteriorCount = 0;
    var rectangularCellCount = 0;
    var axisAlignedEdgeCount = 0;
    var totalEdgeCount = 0;
    final exteriorPointCounts = <int>[];

    for (final cell in cells) {
      if (cell.hasRenderableGeometry) renderableCellCount++;
      var cellHasRectangularExterior = false;

      for (final polygon in cell.polygons) {
        if (polygon.isEmpty) continue;
        totalPolygonCount++;

        for (var ringIndex = 0; ringIndex < polygon.length; ringIndex++) {
          final ring = _normalizedRing(polygon[ringIndex]);
          if (ring.length < 3) continue;

          totalRingCount++;
          totalPointCount += ring.length;
          _countAxisAlignedEdges(
            ring,
            onEdge: ({required bool axisAligned}) {
              totalEdgeCount++;
              if (axisAligned) axisAlignedEdgeCount++;
            },
          );

          if (ringIndex != 0) continue;
          exteriorRingCount++;
          exteriorPointCounts.add(ring.length);
          if (ring.length == 4) fourPointExteriorCount++;
          if (_isAxisAlignedRectangle(ring)) {
            cellHasRectangularExterior = true;
          }
        }
      }

      if (cellHasRectangularExterior) rectangularCellCount++;
    }

    exteriorPointCounts.sort();
    final rectangularCellRatio = renderableCellCount == 0
        ? 0.0
        : rectangularCellCount / renderableCellCount;
    final axisAlignedEdgeRatio =
        totalEdgeCount == 0 ? 0.0 : axisAlignedEdgeCount / totalEdgeCount;
    final warnings = <String>[
      if (rectangularCellCount > 0) 'rectangular_cells_present',
      if (axisAlignedEdgeRatio >= 0.8 && totalEdgeCount > 0)
        'mostly_axis_aligned_edges',
    ];

    return _GeometryDiagnosticsSummary(
      renderableCellCount: renderableCellCount,
      totalPolygonCount: totalPolygonCount,
      totalRingCount: totalRingCount,
      totalPointCount: totalPointCount,
      exteriorRingCount: exteriorRingCount,
      minExteriorPointCount:
          exteriorPointCounts.isEmpty ? 0 : exteriorPointCounts.first,
      medianExteriorPointCount: _medianInt(exteriorPointCounts),
      maxExteriorPointCount:
          exteriorPointCounts.isEmpty ? 0 : exteriorPointCounts.last,
      fourPointExteriorCount: fourPointExteriorCount,
      rectangularCellCount: rectangularCellCount,
      rectangularCellRatio: _roundRatio(rectangularCellRatio),
      axisAlignedEdgeRatio: _roundRatio(axisAlignedEdgeRatio),
      shapeWarnings: warnings,
    );
  }

  List<GeoCoord> _normalizedRing(GeoRing ring) {
    if (ring.length < 2) return ring;
    final first = ring.first;
    final last = ring.last;
    final closed = (first.lat - last.lat).abs() <= _coordinateTolerance &&
        (first.lng - last.lng).abs() <= _coordinateTolerance;
    return closed ? ring.sublist(0, ring.length - 1) : ring;
  }

  bool _isAxisAlignedRectangle(GeoRing ring) {
    if (ring.length != 4) return false;
    final uniqueLatitudes = _uniqueRounded(ring.map((point) => point.lat));
    final uniqueLongitudes = _uniqueRounded(ring.map((point) => point.lng));
    if (uniqueLatitudes.length != 2 || uniqueLongitudes.length != 2) {
      return false;
    }

    var allEdgesAxisAligned = true;
    _countAxisAlignedEdges(
      ring,
      onEdge: ({required bool axisAligned}) {
        allEdgesAxisAligned = allEdgesAxisAligned && axisAligned;
      },
    );
    return allEdgesAxisAligned;
  }

  Set<int> _uniqueRounded(Iterable<double> values) {
    return values
        .map((value) => (value / _coordinateTolerance).round())
        .toSet();
  }

  void _countAxisAlignedEdges(
    GeoRing ring, {
    required void Function({required bool axisAligned}) onEdge,
  }) {
    for (var i = 0; i < ring.length; i++) {
      final start = ring[i];
      final end = ring[(i + 1) % ring.length];
      final axisAligned = (start.lat - end.lat).abs() <= _coordinateTolerance ||
          (start.lng - end.lng).abs() <= _coordinateTolerance;
      onEdge(axisAligned: axisAligned);
    }
  }

  int _medianInt(List<int> values) {
    if (values.isEmpty) return 0;
    final middle = values.length ~/ 2;
    if (values.length.isOdd) return values[middle];
    return ((values[middle - 1] + values[middle]) / 2).round();
  }

  double _roundRatio(double value) => (value * 1000).round() / 1000;
}

class _GeometryDiagnosticsSummary {
  const _GeometryDiagnosticsSummary({
    required this.renderableCellCount,
    required this.totalPolygonCount,
    required this.totalRingCount,
    required this.totalPointCount,
    required this.exteriorRingCount,
    required this.minExteriorPointCount,
    required this.medianExteriorPointCount,
    required this.maxExteriorPointCount,
    required this.fourPointExteriorCount,
    required this.rectangularCellCount,
    required this.rectangularCellRatio,
    required this.axisAlignedEdgeRatio,
    required this.shapeWarnings,
  });

  final int renderableCellCount;
  final int totalPolygonCount;
  final int totalRingCount;
  final int totalPointCount;
  final int exteriorRingCount;
  final int minExteriorPointCount;
  final int medianExteriorPointCount;
  final int maxExteriorPointCount;
  final int fourPointExteriorCount;
  final int rectangularCellCount;
  final double rectangularCellRatio;
  final double axisAlignedEdgeRatio;
  final List<String> shapeWarnings;

  Map<String, dynamic> toTelemetry({required String prefix}) => {
        '${prefix}_total_polygons': totalPolygonCount,
        '${prefix}_total_rings': totalRingCount,
        '${prefix}_total_points': totalPointCount,
        '${prefix}_exterior_ring_count': exteriorRingCount,
        '${prefix}_min_exterior_points': minExteriorPointCount,
        '${prefix}_median_exterior_points': medianExteriorPointCount,
        '${prefix}_max_exterior_points': maxExteriorPointCount,
        '${prefix}_four_point_exterior_count': fourPointExteriorCount,
        '${prefix}_rectangular_cell_count': rectangularCellCount,
        '${prefix}_rectangular_cell_ratio': rectangularCellRatio,
        '${prefix}_axis_aligned_edge_ratio': axisAlignedEdgeRatio,
        '${prefix}_shape_warnings': shapeWarnings,
      };
}
