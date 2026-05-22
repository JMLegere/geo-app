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
    final coord = _cellCenter(cell);
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
