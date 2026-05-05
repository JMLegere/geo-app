import 'dart:ui';

import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/features/map/domain/services/cell_geometry_diagnostics_service.dart';
import 'package:earth_nova/features/map/presentation/painters/fog_renderer.dart';
import 'package:earth_nova/features/map/presentation/rendering/cell_tessellation_render_model.dart';

class MapRenderDiagnosticsService {
  const MapRenderDiagnosticsService();

  static const double _edgeSnapTolerancePx = 0.5;
  static const double _axisTolerancePx = 0.5;

  Map<String, dynamic> summarize({
    required List<CellStateEntry> cellsWithStates,
    required Size viewportSize,
    required GeoProjector project,
    required Offset markerScreenPosition,
    required String? currentCellId,
    required int visitedCellCount,
    required bool markerIsRing,
    required double markerGapDistanceMeters,
    double markerRadiusPx = 10.0,
    double markerRingRadiusPx = 22.0,
    int sampleLimit = 8,
  }) {
    final renderableEntries = [
      for (final entry in cellsWithStates)
        if (FogRenderer.shouldRender(entry.state) &&
            entry.cell.hasRenderableGeometry)
          entry,
    ];
    final renderModel = CellTessellationRenderModel.build(
      cellsWithStates: renderableEntries,
      project: project,
    );
    final boundaryCounts = _boundaryCountsByRelationship(
      renderModel.boundaryEdges,
    );
    final projectionSummary = _summarizeProjection(
      renderableEntries,
      viewportSize,
      project,
    );

    return {
      ...const CellGeometryDiagnosticsService().summarizeRenderedCells(
        cellsWithStates,
      ),
      'state_current_cell_id': currentCellId ?? '',
      'state_visited_cell_count': visitedCellCount,
      'state_present_cell_ids_sample': _sampleIds(
        cellsWithStates,
        CellRelationship.present,
        sampleLimit,
      ),
      'state_explored_cell_ids_sample': _sampleIds(
        cellsWithStates,
        CellRelationship.explored,
        sampleLimit,
      ),
      'state_frontier_cell_ids_sample': _sampleIds(
        cellsWithStates,
        CellRelationship.frontier,
        sampleLimit,
      ),
      ..._styleSnapshot(),
      'render_model_fill_path_count': renderModel.fillPaths.length,
      'render_model_fill_relationships': [
        for (final fill in renderModel.fillPaths) fill.relationship.name,
      ],
      'render_model_boundary_edge_count': renderModel.boundaryEdges.length,
      'render_model_present_boundary_edge_count':
          boundaryCounts[CellRelationship.present] ?? 0,
      'render_model_explored_boundary_edge_count':
          boundaryCounts[CellRelationship.explored] ?? 0,
      'render_model_hidden_same_state_boundary_count':
          _hiddenSameStateBoundaryCount(renderableEntries, project),
      ...projectionSummary,
      'marker_screen_x': _roundPx(markerScreenPosition.dx),
      'marker_screen_y': _roundPx(markerScreenPosition.dy),
      'marker_radius_px': markerRadiusPx,
      'marker_ring_radius_px': markerRingRadiusPx,
      'marker_is_ring': markerIsRing,
      'marker_gap_distance_m': _roundPx(markerGapDistanceMeters),
      'marker_visual_mode': markerIsRing ? 'accuracy_ring' : 'solid_marker',
      'marker_overlaps_present_cell': _markerOverlapsRelationship(
        markerScreenPosition,
        renderableEntries,
        CellRelationship.present,
        project,
      ),
    };
  }

  Map<String, dynamic> _styleSnapshot() => {
        'style_present_fill_alpha': _alpha(
          FogRenderer.fillColor(_state(CellRelationship.present)),
        ),
        'style_explored_fill_alpha': _alpha(
          FogRenderer.fillColor(_state(CellRelationship.explored)),
        ),
        'style_frontier_fill_alpha': _alpha(
          FogRenderer.fillColor(_state(CellRelationship.frontier)),
        ),
        'style_unknown_fill_alpha': _alpha(
          FogRenderer.fillColor(_state(CellRelationship.unknown)),
        ),
        'style_present_stroke_alpha': _alpha(
          FogRenderer.strokeColor(_state(CellRelationship.present)),
        ),
        'style_explored_stroke_alpha': _alpha(
          FogRenderer.strokeColor(_state(CellRelationship.explored)),
        ),
        'style_frontier_stroke_alpha': _alpha(
          FogRenderer.strokeColor(_state(CellRelationship.frontier)),
        ),
        'style_overlay_antialias': FogRenderer.overlayAntiAlias,
        'style_fill_grouping_mode': 'single_path_per_relationship_even_odd',
        'style_uses_unknown_backdrop': FogRenderer.usesUnknownBackdrop,
        'style_fill_compositing_mode': FogRenderer.fillCompositingMode,
      };

  CellState _state(CellRelationship relationship) => CellState(
        relationship: relationship,
        contents: CellContents.empty,
      );

  List<String> _sampleIds(
    List<CellStateEntry> cellsWithStates,
    CellRelationship relationship,
    int limit,
  ) {
    return [
      for (final entry in cellsWithStates)
        if (entry.state.relationship == relationship) entry.cell.id,
    ].take(limit).toList(growable: false);
  }

  Map<CellRelationship, int> _boundaryCountsByRelationship(
    List<TessellationBoundaryEdge> edges,
  ) {
    final counts = <CellRelationship, int>{};
    for (final edge in edges) {
      counts.update(edge.state.relationship, (value) => value + 1,
          ifAbsent: () => 1);
    }
    return counts;
  }

  int _hiddenSameStateBoundaryCount(
    List<CellStateEntry> cellsWithStates,
    GeoProjector project,
  ) {
    final edgeRelationships = <_DiagnosticEdgeKey, List<CellRelationship>>{};
    for (final entry in cellsWithStates) {
      for (final polygon in entry.cell.polygons) {
        for (final ring in polygon) {
          final points = _projectRing(ring, project);
          if (points.length < 3) continue;
          for (var i = 0; i < points.length; i++) {
            final key = _DiagnosticEdgeKey.fromOffsets(
              points[i],
              points[(i + 1) % points.length],
              _edgeSnapTolerancePx,
            );
            edgeRelationships
                .putIfAbsent(key, () => <CellRelationship>[])
                .add(entry.state.relationship);
          }
        }
      }
    }

    var count = 0;
    for (final relationships in edgeRelationships.values) {
      if (relationships.length < 2) continue;
      final first = relationships.first;
      if (relationships.every((relationship) => relationship == first)) count++;
    }
    return count;
  }

  Map<String, dynamic> _summarizeProjection(
    List<CellStateEntry> cellsWithStates,
    Size viewportSize,
    GeoProjector project,
  ) {
    var polygonCount = 0;
    var viewportEdgeCrossingCount = 0;
    var totalEdgeCount = 0;
    var axisAlignedScreenEdgeCount = 0;
    var largestAreaRatio = 0.0;
    final relationshipSummaries = {
      for (final relationship in CellRelationship.values)
        relationship: _ProjectionRelationshipSummary(),
    };
    final viewportArea = viewportSize.width * viewportSize.height;

    for (final entry in cellsWithStates) {
      for (final polygon in entry.cell.polygons) {
        if (polygon.isEmpty) continue;
        final exterior = _projectRing(polygon.first, project);
        if (exterior.length < 3) continue;
        polygonCount++;
        final bounds = _boundsFor(exterior);
        final areaRatio = viewportArea == 0
            ? 0.0
            : (bounds.width * bounds.height) / viewportArea;
        if (areaRatio > largestAreaRatio) largestAreaRatio = areaRatio;
        final relationshipSummary =
            relationshipSummaries[entry.state.relationship]!;
        relationshipSummary.polygonCount++;
        if (areaRatio > relationshipSummary.largestAreaRatio) {
          relationshipSummary.largestAreaRatio = areaRatio;
        }
        final crossesViewportEdge = bounds.left < 0 ||
            bounds.top < 0 ||
            bounds.right > viewportSize.width ||
            bounds.bottom > viewportSize.height;
        if (crossesViewportEdge) {
          viewportEdgeCrossingCount++;
          relationshipSummary.viewportEdgeCrossingCount++;
        }
        for (var i = 0; i < exterior.length; i++) {
          final start = exterior[i];
          final end = exterior[(i + 1) % exterior.length];
          totalEdgeCount++;
          if ((start.dx - end.dx).abs() <= _axisTolerancePx ||
              (start.dy - end.dy).abs() <= _axisTolerancePx) {
            axisAlignedScreenEdgeCount++;
          }
        }
      }
    }

    return {
      'projection_viewport_width_px': _roundPx(viewportSize.width),
      'projection_viewport_height_px': _roundPx(viewportSize.height),
      'projection_polygon_count': polygonCount,
      'projection_largest_bbox_area_ratio': _roundRatio(largestAreaRatio),
      'projection_viewport_edge_crossing_count': viewportEdgeCrossingCount,
      'projection_axis_aligned_screen_edge_ratio': _roundRatio(
        totalEdgeCount == 0 ? 0 : axisAlignedScreenEdgeCount / totalEdgeCount,
      ),
      ..._relationshipProjectionTelemetry(
        CellRelationship.present,
        relationshipSummaries[CellRelationship.present]!,
      ),
      ..._relationshipProjectionTelemetry(
        CellRelationship.explored,
        relationshipSummaries[CellRelationship.explored]!,
      ),
      ..._relationshipProjectionTelemetry(
        CellRelationship.frontier,
        relationshipSummaries[CellRelationship.frontier]!,
      ),
    };
  }

  Map<String, dynamic> _relationshipProjectionTelemetry(
    CellRelationship relationship,
    _ProjectionRelationshipSummary summary,
  ) {
    final prefix = 'projection_${relationship.name}';
    return {
      '${prefix}_polygon_count': summary.polygonCount,
      '${prefix}_viewport_edge_crossing_count':
          summary.viewportEdgeCrossingCount,
      '${prefix}_largest_bbox_area_ratio':
          _roundRatio(summary.largestAreaRatio),
    };
  }

  bool _markerOverlapsRelationship(
    Offset marker,
    List<CellStateEntry> cellsWithStates,
    CellRelationship relationship,
    GeoProjector project,
  ) {
    for (final entry in cellsWithStates) {
      if (entry.state.relationship != relationship) continue;
      for (final polygon in entry.cell.polygons) {
        if (polygon.isEmpty) continue;
        final exterior = _projectRing(polygon.first, project);
        if (_pointInPolygon(marker, exterior)) return true;
      }
    }
    return false;
  }

  bool _pointInPolygon(Offset point, List<Offset> polygon) {
    if (polygon.length < 3) return false;
    var inside = false;
    var previousIndex = polygon.length - 1;
    for (var i = 0; i < polygon.length; i++) {
      final current = polygon[i];
      final previous = polygon[previousIndex];
      final crossesY = (current.dy > point.dy) != (previous.dy > point.dy);
      if (crossesY) {
        final slopeX = (previous.dx - current.dx) *
                (point.dy - current.dy) /
                (previous.dy - current.dy) +
            current.dx;
        if (point.dx < slopeX) inside = !inside;
      }
      previousIndex = i;
    }
    return inside;
  }

  List<Offset> _projectRing(GeoRing ring, GeoProjector project) {
    final points = [for (final coord in ring) project(coord)];
    if (points.length > 1 && _samePoint(points.first, points.last)) {
      return points.sublist(0, points.length - 1);
    }
    return points;
  }

  Rect _boundsFor(List<Offset> points) {
    var left = points.first.dx;
    var right = points.first.dx;
    var top = points.first.dy;
    var bottom = points.first.dy;
    for (final point in points.skip(1)) {
      if (point.dx < left) left = point.dx;
      if (point.dx > right) right = point.dx;
      if (point.dy < top) top = point.dy;
      if (point.dy > bottom) bottom = point.dy;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  bool _samePoint(Offset a, Offset b) => a.dx == b.dx && a.dy == b.dy;

  double _alpha(Color color) => _roundRatio(color.a);

  double _roundRatio(num value) => (value * 1000).round() / 1000;

  double _roundPx(double value) => (value * 10).round() / 10;
}

class _DiagnosticEdgeKey {
  const _DiagnosticEdgeKey(this.ax, this.ay, this.bx, this.by);

  factory _DiagnosticEdgeKey.fromOffsets(
    Offset start,
    Offset end,
    double tolerance,
  ) {
    final a = _DiagnosticPoint.fromOffset(start, tolerance);
    final b = _DiagnosticPoint.fromOffset(end, tolerance);
    final ordered = a.compareTo(b) <= 0 ? (a: a, b: b) : (a: b, b: a);
    return _DiagnosticEdgeKey(
      ordered.a.x,
      ordered.a.y,
      ordered.b.x,
      ordered.b.y,
    );
  }

  final int ax;
  final int ay;
  final int bx;
  final int by;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _DiagnosticEdgeKey &&
          ax == other.ax &&
          ay == other.ay &&
          bx == other.bx &&
          by == other.by;

  @override
  int get hashCode => Object.hash(ax, ay, bx, by);
}

class _DiagnosticPoint implements Comparable<_DiagnosticPoint> {
  const _DiagnosticPoint(this.x, this.y);

  factory _DiagnosticPoint.fromOffset(Offset offset, double tolerance) {
    return _DiagnosticPoint(
      (offset.dx / tolerance).round(),
      (offset.dy / tolerance).round(),
    );
  }

  final int x;
  final int y;

  @override
  int compareTo(_DiagnosticPoint other) {
    final xCompare = x.compareTo(other.x);
    if (xCompare != 0) return xCompare;
    return y.compareTo(other.y);
  }
}

class _ProjectionRelationshipSummary {
  int polygonCount = 0;
  int viewportEdgeCrossingCount = 0;
  double largestAreaRatio = 0.0;
}
