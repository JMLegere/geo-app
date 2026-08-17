import 'dart:math';

import 'package:flutter/rendering.dart' show SemanticsProperties;

import 'package:flutter/material.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/features/map/presentation/painters/fog_renderer.dart';
import 'package:earth_nova/features/map/presentation/rendering/cell_tessellation_render_model.dart';
import 'package:earth_nova/shared/extensions/iconography.dart';
import 'package:earth_nova/shared/theme/app_theme.dart';

/// CustomPainter that renders cell polygons with fog-of-war styling.
///
/// Converts cell lat/lng coordinates to screen pixels using the same Web
/// Mercator world scale MapLibre uses for screen projection fallback.
class CellOverlayPainter extends CustomPainter {
  CellOverlayPainter({
    required this.cellsWithStates,
    this.cameraPosition,
    this.zoom = 0.0,
    this.cameraPixelOffset = Offset.zero,
    this.project,
    this.projectionRevision = 0,
  }) : assert(
          project != null || cameraPosition != null,
          'Provide either exact project or cameraPosition fallback.',
        );

  final List<({Cell cell, CellState state})> cellsWithStates;
  final GeoCoord? cameraPosition;
  final double zoom;
  final Offset cameraPixelOffset;
  final GeoProjector? project;
  final int projectionRevision;

  static const double _tileSize = 512.0;

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
      cellsWithStates: [
        for (final entry in renderableEntries)
          (cell: entry.cell, state: _canonicalRenderState(entry.state)),
      ],
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
            ..color = strokeColor
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
            ..color = strokeColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = seamStrokeWidth,
        );
      }
    }

    for (final entry in renderableEntries) {
      if (entry.state.knowledgeState != CellKnowledgeState.informed) continue;
      final cue = _categoryCue(entry.state.category);
      final geometry = _screenGeometry(entry.cell);
      if (cue == null || geometry == null) continue;

      final cuePainter = TextPainter(
        text: TextSpan(
          text: cue,
          style: const TextStyle(
            color: AppTheme.onSurface,
            fontSize: 18,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      cuePainter.paint(
        canvas,
        geometry.center - Offset(cuePainter.width / 2, cuePainter.height / 2),
      );
    }
  }

  Offset _geoCoordToScreen(GeoCoord coord) {
    final exactProject = project;
    if (exactProject != null) return exactProject(coord);
    return projectGeoCoord(
      coord: coord,
      cameraPosition: cameraPosition!,
      zoom: zoom,
      cameraPixelOffset: cameraPixelOffset,
    );
  }

  CellState _canonicalRenderState(CellState state) {
    final relationship = switch (state.knowledgeState) {
      CellKnowledgeState.present => CellRelationship.present,
      CellKnowledgeState.informed ||
      CellKnowledgeState.explored =>
        CellRelationship.explored,
      CellKnowledgeState.shrouded => CellRelationship.unknown,
    };
    return CellState(
      knowledgeState: state.knowledgeState,
      category: state.category,
      relationship: relationship,
      contents: CellContents.empty,
    );
  }

  ({Rect bounds, Offset center})? _screenGeometry(Cell cell) {
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    var xSum = 0.0;
    var ySum = 0.0;
    var pointCount = 0;

    for (final polygon in cell.polygons) {
      if (polygon.isEmpty) continue;
      for (final coord in polygon.first) {
        final point = _geoCoordToScreen(coord);
        minX = min(minX, point.dx);
        minY = min(minY, point.dy);
        maxX = max(maxX, point.dx);
        maxY = max(maxY, point.dy);
        xSum += point.dx;
        ySum += point.dy;
        pointCount++;
      }
    }

    if (pointCount == 0) return null;
    return (
      bounds: Rect.fromLTRB(minX, minY, maxX, maxY),
      center: Offset(xSum / pointCount, ySum / pointCount),
    );
  }

  String? _categoryCue(String? value) {
    if (value == null) return null;
    for (final category in ItemCategory.values) {
      if (category.name == value) return category.emoji;
    }
    return null;
  }

  String _semanticLabel(CellState state) {
    return switch (state.knowledgeState) {
      CellKnowledgeState.present => 'Present',
      CellKnowledgeState.explored => 'Explored',
      CellKnowledgeState.shrouded => 'Shrouded',
      CellKnowledgeState.informed => 'Informed: ${state.category}',
    };
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder => (_) {
        return [
          for (final entry in cellsWithStates)
            if (entry.cell.hasRenderableGeometry)
              if (_screenGeometry(entry.cell) case final geometry?)
                CustomPainterSemantics(
                  rect: geometry.bounds,
                  properties: SemanticsProperties(
                    label: _semanticLabel(entry.state),
                    textDirection: TextDirection.ltr,
                  ),
                ),
        ];
      };

  @override
  bool shouldRebuildSemantics(covariant CellOverlayPainter oldDelegate) {
    return shouldRepaint(oldDelegate);
  }

  @override
  bool shouldRepaint(covariant CellOverlayPainter oldDelegate) {
    return oldDelegate.cellsWithStates != cellsWithStates ||
        oldDelegate.cameraPosition != cameraPosition ||
        oldDelegate.zoom != zoom ||
        oldDelegate.cameraPixelOffset != cameraPixelOffset ||
        oldDelegate.projectionRevision != projectionRevision;
  }
}
