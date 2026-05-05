import 'dart:math';

import 'package:flutter/material.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/features/map/presentation/painters/fog_renderer.dart';
import 'package:earth_nova/features/map/presentation/rendering/cell_tessellation_render_model.dart';

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

  static Offset projectGeoCoord({
    required GeoCoord coord,
    required GeoCoord cameraPosition,
    required double zoom,
    required Offset cameraPixelOffset,
  }) {
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

  @override
  void paint(Canvas canvas, Size size) {
    final renderableEntries = [
      for (final entry in cellsWithStates)
        if (FogRenderer.shouldRender(entry.state) &&
            entry.cell.hasRenderableGeometry)
          entry,
    ];

    final renderModel = CellTessellationRenderModel.build(
      cellsWithStates: renderableEntries,
      project: _geoCoordToScreen,
    );

    final overlayBounds = Offset.zero & size;
    canvas.saveLayer(overlayBounds, Paint());
    canvas.drawRect(
      overlayBounds,
      Paint()
        ..color = FogRenderer.fillColor(
          const CellState(
            relationship: CellRelationship.unknown,
            contents: CellContents.empty,
          ),
        )
        ..style = PaintingStyle.fill
        ..isAntiAlias = FogRenderer.overlayAntiAlias,
    );

    for (final fill in renderModel.fillPaths) {
      final fillState = CellState(
        relationship: fill.relationship,
        contents: CellContents.empty,
      );
      canvas.drawPath(
        fill.path,
        Paint()
          ..color = FogRenderer.fillColor(fillState)
          ..style = PaintingStyle.fill
          ..blendMode = BlendMode.src
          ..isAntiAlias = FogRenderer.overlayAntiAlias,
      );
    }
    canvas.restore();

    for (final edge in renderModel.boundaryEdges) {
      final strokeColor = FogRenderer.strokeColor(edge.state);
      final habitatStrokeColor = FogRenderer.getHabitatStrokeColor(edge.cell);
      final seamAlpha = strokeColor.a;
      final glowStrokeWidth = FogRenderer.seamGlowStrokeWidth(edge.state);
      final seamStrokeWidth = FogRenderer.seamStrokeWidth(edge.state);
      final glowBlurSigma = FogRenderer.seamGlowBlurSigma(edge.state);
      final edgePath = Path()
        ..moveTo(edge.start.dx, edge.start.dy)
        ..lineTo(edge.end.dx, edge.end.dy);

      if (seamAlpha > 0.0 && glowStrokeWidth > 0.0 && glowBlurSigma > 0.0) {
        canvas.drawPath(
          edgePath,
          Paint()
            ..color = habitatStrokeColor.withValues(alpha: seamAlpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = glowStrokeWidth
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              glowBlurSigma,
            ),
        );
      }

      if (seamAlpha > 0.0 && seamStrokeWidth > 0.0) {
        canvas.drawPath(
          edgePath,
          Paint()
            ..color = habitatStrokeColor.withValues(alpha: seamAlpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = seamStrokeWidth,
        );
      }
    }

    for (final entry in renderableEntries) {
      if (entry.state.contents != CellContents.hasLoot) continue;
      final centroidPoints = [
        for (final polygon in entry.cell.polygons)
          if (polygon.isNotEmpty)
            for (final coord in polygon.first) _geoCoordToScreen(coord),
      ];
      if (centroidPoints.isEmpty) continue;
      final centroid = _calculateCentroid(centroidPoints);
      _drawLootIcon(canvas, centroid);
    }
  }

  Offset _geoCoordToScreen(GeoCoord coord) {
    return projectGeoCoord(
      coord: coord,
      cameraPosition: cameraPosition,
      zoom: zoom,
      cameraPixelOffset: cameraPixelOffset,
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
