import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geobase/geobase.dart';

import 'package:earth_nova/features/map/models/district_infographic_data.dart';

/// CustomPainter that renders a district infographic — dark background with
/// light explored cell polygons, district boundary outline with teal glow,
/// and player marker with amber pulse.
///
/// Uses a simple equirectangular projection (sufficient at district scale)
/// to fit the district bounding box into the available canvas with padding.
///
/// Performance: Only renders explored cells (~300 out of ~6000). Dark
/// background IS the unexplored area — no per-cell painting needed.
class DistrictInfographicPainter extends CustomPainter {
  DistrictInfographicPainter({
    required this.data,
    this.pulseProgress = 0.0,
  });

  final DistrictInfographicData data;

  /// 0.0–1.0 animation progress for player marker pulse ring.
  final double pulseProgress;

  // ── Designer-specified colors ──────────────────────────────────────
  static const _screenBg = Color(0xFF050C15);
  static const _districtFill = Color(0xFF08111D);
  static const _exploredFill = Color(0xFF1A3A54);
  static const _exploredStroke = Color(0x802C5B80); // 0.5 opacity
  static const _boundaryStroke = Color(0xFF3D5060);
  static const _boundaryGlow = Color(0x1F006D77); // 0.12 opacity
  static const _cellBloom = Color(0x14006D77); // 0.08 opacity
  static const _playerCore = Color(0xFFE29578); // amber/secondary
  static const _playerBorder = Color(0xFFE0E1DD);

  /// Padding fraction (15% on each side).
  static const _padding = 0.15;

  // ── Path cache — rebuilt only when data or canvas size changes ──────
  static DistrictInfographicData? _cachedData;
  static Size? _cachedSize;
  static Path? _boundaryPath;
  static Path? _bloomPath;
  static List<Path> _cellPaths = const [];

  /// Release cached paths when the infographic overlay is disposed.
  static void clearCache() {
    _cachedData = null;
    _cachedSize = null;
    _boundaryPath = null;
    _bloomPath = null;
    _cellPaths = const [];
  }

  void _ensurePathCache(Size size) {
    if (identical(_cachedData, data) && _cachedSize == size) return;
    _cachedData = data;
    _cachedSize = size;

    _boundaryPath = _buildPolygonPath(data.boundaryRings, size);

    final cellPaths = <Path>[];
    Path? bloom;
    for (final entry in data.exploredCellBoundaries.entries) {
      final p = _buildSinglePolygonPath(entry.value, size);
      if (p != null) {
        cellPaths.add(p);
        if (data.exploredCellBoundaries.length < 500) {
          bloom ??= Path();
          bloom.addPath(p, Offset.zero);
        }
      }
    }
    _cellPaths = cellPaths;
    _bloomPath = bloom;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Screen background.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = _screenBg,
    );

    if (data.allCellIds.isEmpty) return;

    // Build/cache all paths — only recomputes when data or size changes.
    _ensurePathCache(size);

    // 2. District boundary fill (slightly lighter than background).
    if (_boundaryPath != null) {
      canvas.drawPath(
        _boundaryPath!,
        Paint()
          ..color = _districtFill
          ..style = PaintingStyle.fill,
      );
      // Clip to district boundary — cells outside won't render.
      canvas.save();
      canvas.clipPath(_boundaryPath!);
    }

    // 3. Explored cells — ambient bloom (teal glow behind explored area).
    if (_bloomPath != null) {
      canvas.drawPath(
        _bloomPath!,
        Paint()
          ..color = _cellBloom
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
          ..style = PaintingStyle.fill,
      );
    }

    // 4. Explored cells — fill.
    final exploredPaint = Paint()
      ..color = _exploredFill
      ..style = PaintingStyle.fill;
    for (final path in _cellPaths) {
      canvas.drawPath(path, exploredPaint);
    }

    // 5. Explored cells — stroke.
    final strokePaint = Paint()
      ..color = _exploredStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    for (final path in _cellPaths) {
      canvas.drawPath(path, strokePaint);
    }

    // Restore clip if we saved it.
    if (_boundaryPath != null) {
      canvas.restore();
    }

    // 6. District boundary glow (outer teal halo).
    if (_boundaryPath != null) {
      canvas.drawPath(
        _boundaryPath!,
        Paint()
          ..color = _boundaryGlow
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // 7. District boundary stroke (crisp).
    if (_boundaryPath != null) {
      canvas.drawPath(
        _boundaryPath!,
        Paint()
          ..color = _boundaryStroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }

    // 8–10. Player marker.
    final playerOffset = _geoToScreen(data.playerLat, data.playerLon, size);
    if (playerOffset != null) {
      // Pulse ring (animated).
      final pulseRadius = 14.0 + (pulseProgress * 7.0);
      final pulseOpacity = 0.15 * (1.0 - pulseProgress);
      canvas.drawCircle(
        playerOffset,
        pulseRadius,
        Paint()..color = _playerCore.withValues(alpha: pulseOpacity),
      );

      // Inner halo (static).
      canvas.drawCircle(
        playerOffset,
        10,
        Paint()..color = _playerCore.withValues(alpha: 0.25),
      );

      // Core dot.
      canvas.drawCircle(
        playerOffset,
        5,
        Paint()..color = _playerCore,
      );
      canvas.drawCircle(
        playerOffset,
        5,
        Paint()
          ..color = _playerBorder
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  Path? _buildPolygonPath(List<List<Geographic>> rings, Size size) {
    if (rings.isEmpty) return null;
    final path = Path();
    for (final ring in rings) {
      if (ring.length < 3) continue;
      final first = _geoToScreen(ring[0].lat, ring[0].lon, size);
      if (first == null) continue;
      path.moveTo(first.dx, first.dy);
      for (var i = 1; i < ring.length; i++) {
        final pt = _geoToScreen(ring[i].lat, ring[i].lon, size);
        if (pt != null) path.lineTo(pt.dx, pt.dy);
      }
      path.close();
    }
    return path;
  }

  Path? _buildSinglePolygonPath(List<Geographic> coords, Size size) {
    if (coords.length < 3) return null;
    final first = _geoToScreen(coords[0].lat, coords[0].lon, size);
    if (first == null) return null;
    final path = Path()..moveTo(first.dx, first.dy);
    for (var i = 1; i < coords.length; i++) {
      final pt = _geoToScreen(coords[i].lat, coords[i].lon, size);
      if (pt != null) path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    return path;
  }

  Offset? _geoToScreen(double lat, double lon, Size size) {
    final latRange = data.maxLat - data.minLat;
    final lonRange = data.maxLon - data.minLon;
    if (latRange <= 0 || lonRange <= 0) return null;

    final padX = size.width * _padding;
    final padY = size.height * _padding;
    final drawW = size.width - 2 * padX;
    final drawH = size.height - 2 * padY;

    final midLat = (data.minLat + data.maxLat) / 2;
    final cosLat = math.cos(midLat * math.pi / 180);
    final adjustedLonRange = lonRange * cosLat;

    final scaleX = drawW / adjustedLonRange;
    final scaleY = drawH / latRange;
    final scale = math.min(scaleX, scaleY);

    final projW = adjustedLonRange * scale;
    final projH = latRange * scale;
    final offsetX = padX + (drawW - projW) / 2;
    final offsetY = padY + (drawH - projH) / 2;

    final x = offsetX + (lon - data.minLon) * cosLat * scale;
    final y = offsetY + (data.maxLat - lat) * scale;

    return Offset(x, y);
  }

  @override
  bool shouldRepaint(DistrictInfographicPainter oldDelegate) =>
      pulseProgress != oldDelegate.pulseProgress ||
      !identical(data, oldDelegate.data);
}
