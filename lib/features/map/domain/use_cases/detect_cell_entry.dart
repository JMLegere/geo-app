import 'package:earth_nova/features/map/domain/entities/cell.dart';

class DetectCellEntry {
  const DetectCellEntry();

  /// Ray-casting algorithm for point-in-polygon test
  bool pointInPolygon({
    required GeoCoord point,
    required List<GeoCoord> polygon,
  }) {
    if (polygon.length < 3) return false;

    bool inside = false;
    int j = polygon.length - 1;

    for (int i = 0; i < polygon.length; i++) {
      final xi = polygon[i].lat;
      final yi = polygon[i].lng;
      final xj = polygon[j].lat;
      final yj = polygon[j].lng;

      // Check if ray crosses edge
      final intersect = ((yi > point.lng) != (yj > point.lng)) &&
          (point.lat < (xj - xi) * (point.lng - yi) / (yj - yi) + xi);

      if (intersect) inside = !inside;
      j = i;
    }

    return inside;
  }

  /// Find which cell contains the given point
  Cell? detectCell({
    required List<Cell> cells,
    required GeoCoord point,
  }) {
    for (final cell in cells) {
      if (pointInPolygon(point: point, polygon: cell.polygon)) {
        return cell;
      }
    }
    return null;
  }

  /// Detect cell entry: returns the new cell ID if marker entered a different cell
  String? call({
    required List<Cell> cells,
    required String? previousCellId,
    required GeoCoord currentPoint,
  }) {
    final currentCell = detectCell(cells: cells, point: currentPoint);

    if (currentCell == null) {
      return null;
    }

    // If no previous cell, this is the first cell entry
    if (previousCellId == null) {
      return currentCell.id;
    }

    // If previous cell is different, this is a cell entry event
    if (currentCell.id != previousCellId) {
      return currentCell.id;
    }

    // Marker is in the same cell as before - no entry event
    return null;
  }
}
