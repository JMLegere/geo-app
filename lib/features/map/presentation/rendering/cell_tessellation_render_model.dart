import 'dart:ui';

import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';

typedef CellStateEntry = ({Cell cell, CellState state});
typedef GeoProjector = Offset Function(GeoCoord coord);

class TessellationFillPath {
  const TessellationFillPath({
    required this.relationship,
    required this.path,
  });

  final CellRelationship relationship;
  final Path path;
}

class TessellationBoundaryEdge {
  const TessellationBoundaryEdge({
    required this.start,
    required this.end,
    required this.cell,
    required this.state,
  });

  final Offset start;
  final Offset end;
  final Cell cell;
  final CellState state;
}

class CellTessellationRenderModel {
  const CellTessellationRenderModel({
    required this.fillPaths,
    required this.boundaryEdges,
  });

  final List<TessellationFillPath> fillPaths;
  final List<TessellationBoundaryEdge> boundaryEdges;

  static CellTessellationRenderModel build({
    required List<CellStateEntry> cellsWithStates,
    required GeoProjector project,
    double edgeSnapTolerancePx = 0.5,
  }) {
    final fillPaths = <CellRelationship, Path>{};
    final edges = <_EdgeKey, _EdgeAccumulator>{};

    for (final entry in cellsWithStates) {
      final cell = entry.cell;
      if (!cell.hasRenderableGeometry) continue;

      final fillPath = fillPaths.putIfAbsent(
        entry.state.relationship,
        () => Path()..fillType = PathFillType.evenOdd,
      );

      for (final polygon in cell.polygons) {
        for (final ring in polygon) {
          final points = _projectRing(ring, project);
          if (points.length < 3) continue;

          final path = _pathForRing(points);
          fillPath.addPath(path, Offset.zero);
          _collectEdges(
            edges: edges,
            points: points,
            cell: cell,
            state: entry.state,
            snapTolerancePx: edgeSnapTolerancePx,
          );
        }
      }
    }

    return CellTessellationRenderModel(
      fillPaths: [
        for (final relationship in CellRelationship.values)
          if (fillPaths[relationship] != null)
            TessellationFillPath(
              relationship: relationship,
              path: fillPaths[relationship]!,
            ),
      ],
      boundaryEdges: _visibleBoundaryEdges(edges.values),
    );
  }

  static List<Offset> _projectRing(GeoRing ring, GeoProjector project) {
    final points = [for (final coord in ring) project(coord)];
    if (points.length > 1 && _samePoint(points.first, points.last)) {
      return points.sublist(0, points.length - 1);
    }
    return points;
  }

  static Path _pathForRing(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    path.close();
    return path;
  }

  static void _collectEdges({
    required Map<_EdgeKey, _EdgeAccumulator> edges,
    required List<Offset> points,
    required Cell cell,
    required CellState state,
    required double snapTolerancePx,
  }) {
    for (var i = 0; i < points.length; i++) {
      final start = points[i];
      final end = points[(i + 1) % points.length];
      if (_samePoint(start, end)) continue;

      final key = _EdgeKey.fromOffsets(start, end, snapTolerancePx);
      final accumulator = edges.putIfAbsent(key, _EdgeAccumulator.new);
      accumulator.sides.add(
        _EdgeSide(
          start: start,
          end: end,
          cell: cell,
          state: state,
        ),
      );
    }
  }

  static List<TessellationBoundaryEdge> _visibleBoundaryEdges(
    Iterable<_EdgeAccumulator> accumulators,
  ) {
    final edges = <TessellationBoundaryEdge>[];

    for (final accumulator in accumulators) {
      final side = _strongestVisibleSide(accumulator.sides);
      if (side == null) continue;
      edges.add(
        TessellationBoundaryEdge(
          start: side.start,
          end: side.end,
          cell: side.cell,
          state: side.state,
        ),
      );
    }

    return edges;
  }

  static _EdgeSide? _strongestVisibleSide(List<_EdgeSide> sides) {
    final visibleSides = sides.where(_isVisibleBoundarySide).toList();
    if (visibleSides.isEmpty) return null;

    visibleSides.sort((a, b) => _relationshipPriority(b.state.relationship)
        .compareTo(_relationshipPriority(a.state.relationship)));
    final strongest = visibleSides.first;

    if (sides.length > 1 &&
        sides.every((side) =>
            side.state.relationship == strongest.state.relationship)) {
      return null;
    }

    return strongest;
  }

  static bool _isVisibleBoundarySide(_EdgeSide side) {
    return switch (side.state.relationship) {
      CellRelationship.present || CellRelationship.explored => true,
      CellRelationship.frontier || CellRelationship.unknown => false,
    };
  }

  static int _relationshipPriority(CellRelationship relationship) {
    return switch (relationship) {
      CellRelationship.present => 4,
      CellRelationship.explored => 3,
      CellRelationship.frontier => 2,
      CellRelationship.unknown => 1,
    };
  }

  static bool _samePoint(Offset a, Offset b) {
    return a.dx == b.dx && a.dy == b.dy;
  }
}

class _EdgeSide {
  const _EdgeSide({
    required this.start,
    required this.end,
    required this.cell,
    required this.state,
  });

  final Offset start;
  final Offset end;
  final Cell cell;
  final CellState state;
}

class _EdgeAccumulator {
  final sides = <_EdgeSide>[];
}

class _EdgeKey {
  const _EdgeKey(this.ax, this.ay, this.bx, this.by);

  factory _EdgeKey.fromOffsets(Offset start, Offset end, double tolerance) {
    final a = _SnappedPoint.fromOffset(start, tolerance);
    final b = _SnappedPoint.fromOffset(end, tolerance);
    final ordered = a.compareTo(b) <= 0 ? (a: a, b: b) : (a: b, b: a);
    return _EdgeKey(ordered.a.x, ordered.a.y, ordered.b.x, ordered.b.y);
  }

  final int ax;
  final int ay;
  final int bx;
  final int by;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _EdgeKey &&
          ax == other.ax &&
          ay == other.ay &&
          bx == other.bx &&
          by == other.by;

  @override
  int get hashCode => Object.hash(ax, ay, bx, by);
}

class _SnappedPoint implements Comparable<_SnappedPoint> {
  const _SnappedPoint(this.x, this.y);

  factory _SnappedPoint.fromOffset(Offset offset, double tolerance) {
    return _SnappedPoint(
      (offset.dx / tolerance).round(),
      (offset.dy / tolerance).round(),
    );
  }

  final int x;
  final int y;

  @override
  int compareTo(_SnappedPoint other) {
    final xCompare = x.compareTo(other.x);
    if (xCompare != 0) return xCompare;
    return y.compareTo(other.y);
  }
}
