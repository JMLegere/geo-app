import 'dart:math';

import 'package:flutter/material.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/features/map/presentation/painters/fog_renderer.dart';

/// CustomPainter that renders cell polygons with fog-of-war styling.
///
/// Converts cell lat/lng coordinates to screen pixels using mercator projection
/// based on the current camera position and zoom level.
class CellOverlayPainter extends CustomPainter {
  CellOverlayPainter({
    required this.cellsWithStates,
    required this.cameraPosition,
    required this.zoom,
    required this.cameraPixelOffset,
  });

  final List<({Cell cell, CellState state})> cellsWithStates;
  final GeoCoord cameraPosition;
  final double zoom;
  final Offset cameraPixelOffset;

  static const double _tileSize = 256.0;

  @override
  void paint(Canvas canvas, Size size) {
    for (final entry in cellsWithStates) {
      final cell = entry.cell;
      final state = entry.state;

      if (!FogRenderer.shouldRender(state)) continue;
      if (!cell.hasRenderableGeometry) continue;

      final fillColor = FogRenderer.fillColor(state);
      final strokeColor = FogRenderer.strokeColor(state);
      final habitatStrokeColor = FogRenderer.getHabitatStrokeColor(cell);

      final fillPath = Path()..fillType = PathFillType.evenOdd;
      final ringPaths = <Path>[];
      final centroidPoints = <Offset>[];

      for (final polygon in cell.polygons) {
        for (final ring in polygon) {
          if (ring.length < 3) continue;
          final path = Path();
          final points = ring.map(_geoCoordToScreen).toList(growable: false);
          if (points.isEmpty) continue;

          path.moveTo(points.first.dx, points.first.dy);
          for (var i = 1; i < points.length; i++) {
            path.lineTo(points[i].dx, points[i].dy);
          }
          path.close();

          fillPath.addPath(path, Offset.zero);
          ringPaths.add(path);

          if (identical(ring, polygon.first)) {
            centroidPoints.addAll(points);
          }
        }
      }

      if (ringPaths.isEmpty) continue;

      canvas.drawPath(
        fillPath,
        Paint()
          ..color = fillColor
          ..style = PaintingStyle.fill,
      );

      for (final ringPath in ringPaths) {
        canvas.drawPath(
          ringPath,
          Paint()
            ..color = habitatStrokeColor.withValues(alpha: strokeColor.a)
            ..style = PaintingStyle.stroke
            ..strokeWidth = FogRenderer.seamGlowStrokeWidth(state)
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              FogRenderer.seamGlowBlurSigma(state),
            ),
        );

        canvas.drawPath(
          ringPath,
          Paint()
            ..color = habitatStrokeColor.withValues(alpha: strokeColor.a)
            ..style = PaintingStyle.stroke
            ..strokeWidth = FogRenderer.seamStrokeWidth(state),
        );
      }

      if (state.contents == CellContents.hasLoot && centroidPoints.isNotEmpty) {
        final centroid = _calculateCentroid(centroidPoints);
        _drawLootIcon(canvas, centroid);
      }
    }
  }

  Offset _geoCoordToScreen(GeoCoord coord) {
    final scale = pow(2.0, zoom) * _tileSize;

    final x = (coord.lng + 180.0) / 360.0 * scale;
    final latRad = coord.lat * pi / 180.0;
    final y = (1.0 - log(tan(latRad) + (1.0 / cos(latRad))) / pi) / 2.0 * scale;

    final cameraX = (cameraPosition.lng + 180.0) / 360.0 * scale;
    final cameraLatRad = cameraPosition.lat * pi / 180.0;
    final cameraY =
        (1.0 - log(tan(cameraLatRad) + (1.0 / cos(cameraLatRad))) / pi) /
            2.0 *
            scale;

    return Offset(
      x - cameraX + cameraPixelOffset.dx,
      y - cameraY + cameraPixelOffset.dy,
    );
  }

  Offset _calculateCentroid(List<Offset> points) {
    if (points.isEmpty) return Offset.zero;

    var xSum = 0.0;
    var ySum = 0.0;
    for (final point in points) {
      xSum += point.dx;
      ySum += point.dy;
    }
    return Offset(xSum / points.length, ySum / points.length);
  }

  void _drawLootIcon(Canvas canvas, Offset center) {
    const size = 12.0;

    final path = Path();
    const points = 5;
    const innerRadius = size * 0.4;
    const outerRadius = size * 0.8;

    for (var i = 0; i < points * 2; i++) {
      final angle = (i * pi / points) - pi / 2;
      final radius = i.isEven ? outerRadius : innerRadius;
      final x = center.dx + cos(angle) * radius;
      final y = center.dy + sin(angle) * radius;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFD700)
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFB8860B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CellOverlayPainter oldDelegate) {
    return oldDelegate.cellsWithStates != cellsWithStates ||
        oldDelegate.cameraPosition != cameraPosition ||
        oldDelegate.zoom != zoom ||
        oldDelegate.cameraPixelOffset != cameraPixelOffset;
  }
}
