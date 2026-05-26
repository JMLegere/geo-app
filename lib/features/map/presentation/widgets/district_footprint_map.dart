import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/shared/theme/app_theme.dart';

class DistrictFootprintMap extends StatelessWidget {
  const DistrictFootprintMap({
    super.key,
    required this.cells,
    required this.currentDistrictId,
    required this.visitedCellIds,
    this.currentCellId,
  });

  final List<Cell> cells;
  final String currentDistrictId;
  final Set<String> visitedCellIds;
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

    if (districtCells.isEmpty) {
      return const ColoredBox(
        color: Color(0xFF060F1A),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'District map unavailable until nearby cell geometry loads.',
              style: TextStyle(
                color: AppTheme.onSurfaceVariant,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: const Color(0xFF060F1A),
      child: CustomPaint(
        painter: DistrictFootprintMapPainter(
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
    required this.districtCells,
    required this.contextCells,
    required this.visitedCellIds,
    this.currentCellId,
  });

  final List<Cell> districtCells;
  final List<Cell> contextCells;
  final Set<String> visitedCellIds;
  final String? currentCellId;

  @override
  void paint(Canvas canvas, Size size) {
    final allRenderableCells = [...contextCells, ...districtCells]
        .where((cell) => cell.hasRenderableGeometry)
        .toList(growable: false);
    if (allRenderableCells.isEmpty || size.isEmpty) return;

    final projection = _DistrictProjection.fit(
      cells: allRenderableCells,
      size: size,
      padding: 20,
    );
    if (projection == null) return;

    for (final cell in contextCells) {
      _drawCell(
        canvas,
        cell,
        projection,
        fill: const Color(0xFF132233).withValues(alpha: 0.24),
        stroke: const Color(0xFF7F93A5).withValues(alpha: 0.12),
        strokeWidth: 1,
      );
    }

    for (final cell in districtCells) {
      final isVisited = visitedCellIds.contains(cell.id);
      final isCurrent = currentCellId == cell.id;
      _drawCell(
        canvas,
        cell,
        projection,
        fill: isVisited
            ? AppTheme.primary.withValues(alpha: 0.34)
            : const Color(0xFF111F2D),
        stroke: isVisited
            ? AppTheme.tertiary.withValues(alpha: 0.62)
            : const Color(0xFF52677A).withValues(alpha: 0.50),
        strokeWidth: isCurrent ? 2.8 : 1.2,
      );
    }
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

  @override
  bool shouldRepaint(covariant DistrictFootprintMapPainter oldDelegate) {
    return oldDelegate.districtCells != districtCells ||
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
    required List<Cell> cells,
    required Size size,
    required double padding,
  }) {
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;

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
    final y = (1.0 -
            math.log(math.tan(latRad) + (1.0 / math.cos(latRad))) / math.pi) /
        2.0;
    return Offset(x, y);
  }
}
