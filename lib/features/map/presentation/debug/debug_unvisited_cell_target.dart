import 'dart:math' as math;

import 'package:earth_nova/features/map/domain/entities/cell.dart';

class DebugUnvisitedCellTarget {
  const DebugUnvisitedCellTarget({
    required this.cellId,
    required this.coord,
  });

  final String cellId;
  final GeoCoord coord;
}

DebugUnvisitedCellTarget? selectDebugUnvisitedCellTarget({
  required List<Cell> cells,
  required Set<String> backendVisitedCellIds,
  required Set<String> sessionVisitedCellIds,
  required String? currentCellId,
  required GeoCoord currentPosition,
}) {
  final visited = {...backendVisitedCellIds, ...sessionVisitedCellIds};
  final candidates = <DebugUnvisitedCellTarget>[];

  for (final cell in cells) {
    if (cell.id == currentCellId) continue;
    if (visited.contains(cell.id)) continue;
    final coord = _debugTargetPoint(cell, currentPosition);
    if (coord == null) continue;
    candidates.add(DebugUnvisitedCellTarget(cellId: cell.id, coord: coord));
  }

  if (candidates.isEmpty) return null;
  candidates.sort((a, b) {
    final distanceCompare = _haversineMeters(
      currentPosition.lat,
      currentPosition.lng,
      a.coord.lat,
      a.coord.lng,
    ).compareTo(
      _haversineMeters(
        currentPosition.lat,
        currentPosition.lng,
        b.coord.lat,
        b.coord.lng,
      ),
    );
    if (distanceCompare != 0) return distanceCompare;
    return a.cellId.compareTo(b.cellId);
  });
  return candidates.first;
}

GeoCoord? _debugTargetPoint(Cell cell, GeoCoord currentPosition) {
  final center = _cellCenter(cell);
  final closest = _closestPointOnExterior(cell, currentPosition);
  if (center == null || closest == null) return null;

  // Target just inside the candidate cell near the closest edge instead of the
  // centroid. This keeps QA moves under the GPS ring threshold for neighboring
  // cells, so the normal cell-entry pipeline records the entry instead of
  // first tracking the target while exploration is paused.
  const inwardFraction = 0.20;
  return (
    lat: closest.lat + (center.lat - closest.lat) * inwardFraction,
    lng: closest.lng + (center.lng - closest.lng) * inwardFraction,
  );
}

GeoCoord? _cellCenter(Cell cell) {
  final ring = cell.primaryExteriorRing;
  if (ring.length < 3) return null;

  var latSum = 0.0;
  var lngSum = 0.0;
  for (final point in ring) {
    latSum += point.lat;
    lngSum += point.lng;
  }
  return (lat: latSum / ring.length, lng: lngSum / ring.length);
}

GeoCoord? _closestPointOnExterior(Cell cell, GeoCoord point) {
  final ring = cell.primaryExteriorRing;
  if (ring.length < 3) return null;

  GeoCoord? closest;
  var closestDistance = double.infinity;
  for (var index = 0; index < ring.length; index += 1) {
    final start = ring[index];
    final end = ring[(index + 1) % ring.length];
    final candidate = _closestPointOnSegment(point, start, end);
    final distance = _distanceSquaredDegrees(point, candidate);
    if (distance < closestDistance) {
      closestDistance = distance;
      closest = candidate;
    }
  }
  return closest;
}

GeoCoord _closestPointOnSegment(
  GeoCoord point,
  GeoCoord start,
  GeoCoord end,
) {
  final segmentLat = end.lat - start.lat;
  final segmentLng = end.lng - start.lng;
  final lengthSquared = segmentLat * segmentLat + segmentLng * segmentLng;
  if (lengthSquared == 0.0) return start;

  final rawT = ((point.lat - start.lat) * segmentLat +
          (point.lng - start.lng) * segmentLng) /
      lengthSquared;
  final t = rawT.clamp(0.0, 1.0).toDouble();
  return (
    lat: start.lat + segmentLat * t,
    lng: start.lng + segmentLng * t,
  );
}

double _distanceSquaredDegrees(GeoCoord a, GeoCoord b) {
  final dLat = a.lat - b.lat;
  final dLng = a.lng - b.lng;
  return dLat * dLat + dLng * dLng;
}

double _haversineMeters(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  const earthRadiusM = 6371000.0;
  final dLat = _toRad(lat2 - lat1);
  final dLng = _toRad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRad(lat1)) *
          math.cos(_toRad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusM * c;
}

double _toRad(double deg) => deg * math.pi / 180.0;
