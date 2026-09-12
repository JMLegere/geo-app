import 'dart:math' as math;

import 'package:flutter/rendering.dart' show SemanticsProperties;

import 'package:flutter/material.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/repositories/hierarchy_repository.dart';
import 'package:earth_nova/shared/design.dart';

typedef DistrictFootprintCellStyle = ({
  Color fill,
  Color stroke,
  double strokeWidth,
});

const DistrictFootprintCellStyle districtFootprintContextStyle = (
  fill: Color(0xFF181818),
  stroke: Color(0xFF383838),
  strokeWidth: 1,
);

DistrictFootprintCellStyle districtFootprintCellStyle({
  required bool isVisited,
  required bool isCurrent,
}) {
  return (
    fill: isVisited ? const Color(0xFF606060) : const Color(0xFF282828),
    stroke: isCurrent
        ? const Color(0xFFF2F2F2)
        : isVisited
        ? const Color(0xFFB0B0B0)
        : const Color(0xFF606060),
    strokeWidth: isCurrent ? 2.8 : (isVisited ? 1.6 : 1.2),
  );
}

class DistrictFootprintMap extends StatelessWidget {
  const DistrictFootprintMap({
    super.key,
    required this.cells,
    required this.currentDistrictId,
    required this.visitedCellIds,
    this.districtBoundary,
    this.currentCellId,
  });

  final List<Cell> cells;
  final String currentDistrictId;
  final Set<String> visitedCellIds;
  final DistrictBoundary? districtBoundary;
  final String? currentCellId;

  @override
  Widget build(BuildContext context) {
    final districtCells = cells
        .where((cell) => cell.districtId == currentDistrictId)
        .where((cell) => cell.hasRenderableGeometry)
        .toList(growable: false);
    final contextCells = cells
        .where((cell) => cell.districtId != currentDistrictId)
        .where((cell) => cell.hasRenderableGeometry)
        .toList(growable: false);

    if (districtBoundary == null) {
      return const ColoredBox(
        color: Color(0xFF0A0A0A),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'District boundary unavailable.',
              style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: const Color(0xFF0A0A0A),
      child: CustomPaint(
        painter: DistrictFootprintMapPainter(
          districtBoundary: districtBoundary!,
          districtCells: districtCells,
          contextCells: contextCells,
          visitedCellIds: visitedCellIds,
          currentCellId: currentCellId,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class DistrictFootprintMapPainter extends CustomPainter {
  const DistrictFootprintMapPainter({
    required this.districtBoundary,
    required this.districtCells,
    required this.contextCells,
    required this.visitedCellIds,
    this.currentCellId,
  });

  final DistrictBoundary districtBoundary;
  final List<Cell> districtCells;
  final List<Cell> contextCells;
  final Set<String> visitedCellIds;
  final String? currentCellId;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final allRenderableCells = [
      ...contextCells,
      ...districtCells,
    ].where((cell) => cell.hasRenderableGeometry).toList(growable: false);
    final projection = _DistrictProjection.fit(
      boundary: districtBoundary,
      cells: allRenderableCells,
      size: size,
      padding: 20,
    );
    if (projection == null) return;

    const contextStyle = districtFootprintContextStyle;
    for (final cell in contextCells) {
      _drawCell(
        canvas,
        cell,
        projection,
        fill: contextStyle.fill,
        stroke: contextStyle.stroke,
        strokeWidth: contextStyle.strokeWidth,
      );
    }

    for (final cell in districtCells) {
      final isVisited = visitedCellIds.contains(cell.id);
      final isCurrent = currentCellId == cell.id;
      final style = districtFootprintCellStyle(
        isVisited: isVisited,
        isCurrent: isCurrent,
      );
      _drawCell(
        canvas,
        cell,
        projection,
        fill: style.fill,
        stroke: style.stroke,
        strokeWidth: style.strokeWidth,
      );
    }

    canvas.drawPath(
      _boundaryPath(projection),
      Paint()
        ..color = DesignPalette.text
        ..style = PaintingStyle.stroke
        ..strokeWidth = DesignMetrics.outline * 3
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  void _drawCell(
    Canvas canvas,
    Cell cell,
    _DistrictProjection projection, {
    required Color fill,
    required Color stroke,
    required double strokeWidth,
  }) {
    for (final polygon in cell.polygons) {
      if (polygon.isEmpty || polygon.first.length < 3) continue;
      final path = Path();
      final exterior = polygon.first;
      for (var i = 0; i < exterior.length; i++) {
        final point = projection.project(exterior[i]);
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();

      canvas.drawPath(
        path,
        Paint()
          ..color = fill
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true,
      );
    }
  }

  Path _boundaryPath(_DistrictProjection projection) {
    final path = Path();
    for (final polygon in districtBoundary.polygons) {
      for (final ring in polygon) {
        for (var i = 0; i < ring.length; i++) {
          final point = projection.project(ring[i]);
          if (i == 0) {
            path.moveTo(point.dx, point.dy);
          } else {
            path.lineTo(point.dx, point.dy);
          }
        }
        path.close();
      }
    }
    return path;
  }

  Rect? _semanticBounds(Cell cell, _DistrictProjection projection) {
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;

    for (final polygon in cell.polygons) {
      if (polygon.isEmpty) continue;
      for (final coord in polygon.first) {
        final point = projection.project(coord);
        minX = math.min(minX, point.dx);
        minY = math.min(minY, point.dy);
        maxX = math.max(maxX, point.dx);
        maxY = math.max(maxY, point.dy);
      }
    }

    if (!minX.isFinite || !minY.isFinite || !maxX.isFinite || !maxY.isFinite) {
      return null;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) {
    final allRenderableCells = [
      ...contextCells,
      ...districtCells,
    ].where((cell) => cell.hasRenderableGeometry).toList(growable: false);
    if (size.isEmpty) return const [];

    final projection = _DistrictProjection.fit(
      boundary: districtBoundary,
      cells: allRenderableCells,
      size: size,
      padding: 20,
    );
    if (projection == null) return const [];

    return [
      for (final cell in contextCells)
        if (cell.hasRenderableGeometry)
          if (_semanticBounds(cell, projection) case final bounds?)
            CustomPainterSemantics(
              rect: bounds,
              properties: const SemanticsProperties(
                label: 'Context cell',
                textDirection: TextDirection.ltr,
              ),
            ),
      for (final cell in districtCells)
        if (cell.hasRenderableGeometry)
          if (_semanticBounds(cell, projection) case final bounds?)
            CustomPainterSemantics(
              rect: bounds,
              properties: SemanticsProperties(
                label: currentCellId == cell.id
                    ? 'Current cell'
                    : visitedCellIds.contains(cell.id)
                    ? 'Visited cell'
                    : 'Unvisited cell',
                textDirection: TextDirection.ltr,
              ),
            ),
    ];
  };

  @override
  bool shouldRebuildSemantics(
    covariant DistrictFootprintMapPainter oldDelegate,
  ) {
    return shouldRepaint(oldDelegate);
  }

  @override
  bool shouldRepaint(covariant DistrictFootprintMapPainter oldDelegate) {
    return oldDelegate.districtBoundary != districtBoundary ||
        oldDelegate.districtCells != districtCells ||
        oldDelegate.contextCells != contextCells ||
        oldDelegate.visitedCellIds != visitedCellIds ||
        oldDelegate.currentCellId != currentCellId;
  }
}

class _DistrictProjection {
  const _DistrictProjection({
    required this.minX,
    required this.minY,
    required this.scale,
    required this.offset,
  });

  final double minX;
  final double minY;
  final double scale;
  final Offset offset;

  static _DistrictProjection? fit({
    required DistrictBoundary boundary,
    required List<Cell> cells,
    required Size size,
    required double padding,
  }) {
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;

    for (final polygon in boundary.polygons) {
      for (final ring in polygon) {
        for (final coord in ring) {
          final projected = _projectMercatorUnit(coord);
          minX = math.min(minX, projected.dx);
          minY = math.min(minY, projected.dy);
          maxX = math.max(maxX, projected.dx);
          maxY = math.max(maxY, projected.dy);
        }
      }
    }
    for (final cell in cells) {
      for (final coord in cell.exteriorPoints) {
        final projected = _projectMercatorUnit(coord);
        minX = math.min(minX, projected.dx);
        minY = math.min(minY, projected.dy);
        maxX = math.max(maxX, projected.dx);
        maxY = math.max(maxY, projected.dy);
      }
    }

    if (!minX.isFinite || !minY.isFinite || !maxX.isFinite || !maxY.isFinite) {
      return null;
    }

    final boundsWidth = math.max(maxX - minX, 0.0000001);
    final boundsHeight = math.max(maxY - minY, 0.0000001);
    final availableWidth = math.max(size.width - padding * 2, 1.0);
    final availableHeight = math.max(size.height - padding * 2, 1.0);
    final scale = math.min(
      availableWidth / boundsWidth,
      availableHeight / boundsHeight,
    );
    final drawnWidth = boundsWidth * scale;
    final drawnHeight = boundsHeight * scale;
    final offset = Offset(
      (size.width - drawnWidth) / 2,
      (size.height - drawnHeight) / 2,
    );

    return _DistrictProjection(
      minX: minX,
      minY: minY,
      scale: scale,
      offset: offset,
    );
  }

  Offset project(GeoCoord coord) {
    final projected = _projectMercatorUnit(coord);
    return Offset(
      (projected.dx - minX) * scale + offset.dx,
      (projected.dy - minY) * scale + offset.dy,
    );
  }

  static Offset _projectMercatorUnit(GeoCoord coord) {
    final x = (coord.lng + 180.0) / 360.0;
    final latRad = coord.lat * math.pi / 180.0;
    final y =
        (1.0 -
            math.log(math.tan(latRad) + (1.0 / math.cos(latRad))) / math.pi) /
        2.0;
    return Offset(x, y);
  }
}
