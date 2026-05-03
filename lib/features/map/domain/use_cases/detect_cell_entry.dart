import 'package:earth_nova/core/observability/observable_use_case.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';

typedef DetectCellEntryInput = ({
  List<Cell> cells,
  String? previousCellId,
  GeoCoord currentPoint,
});

class DetectCellEntry extends ObservableUseCase<DetectCellEntryInput, String?> {
  DetectCellEntry(this._obs);

  final ObservabilityService _obs;

  @override
  ObservabilityService get obs => _obs;

  @override
  String get operationName => 'detect_cell_entry';

  /// Ray-casting algorithm for point-in-ring test.
  bool pointInRing({
    required GeoCoord point,
    required GeoRing ring,
  }) {
    if (ring.length < 3) return false;

    bool inside = false;
    int j = ring.length - 1;

    for (int i = 0; i < ring.length; i++) {
      final xi = ring[i].lat;
      final yi = ring[i].lng;
      final xj = ring[j].lat;
      final yj = ring[j].lng;

      final intersect = ((yi > point.lng) != (yj > point.lng)) &&
          (point.lat < (xj - xi) * (point.lng - yi) / (yj - yi) + xi);

      if (intersect) inside = !inside;
      j = i;
    }

    return inside;
  }

  bool pointInPolygon({
    required GeoCoord point,
    required GeoPolygon polygon,
  }) {
    if (polygon.isEmpty) return false;
    final exterior = polygon.first;
    if (!pointInRing(point: point, ring: exterior)) return false;

    for (final hole in polygon.skip(1)) {
      if (pointInRing(point: point, ring: hole)) {
        return false;
      }
    }

    return true;
  }

  bool pointInMultiPolygon({
    required GeoCoord point,
    required GeoMultiPolygon polygons,
  }) {
    for (final polygon in polygons) {
      if (pointInPolygon(point: point, polygon: polygon)) {
        return true;
      }
    }
    return false;
  }

  /// Find which cell contains the given point.
  Cell? detectCell({
    required List<Cell> cells,
    required GeoCoord point,
  }) {
    for (final cell in cells) {
      if (pointInMultiPolygon(point: point, polygons: cell.polygons)) {
        return cell;
      }
    }
    return null;
  }

  @override
  Future<String?> execute(DetectCellEntryInput input, String traceId) async {
    final currentCell = detectCell(
      cells: input.cells,
      point: input.currentPoint,
    );

    if (currentCell == null) {
      return null;
    }

    if (input.previousCellId == null) {
      return currentCell.id;
    }

    if (currentCell.id != input.previousCellId) {
      return currentCell.id;
    }

    return null;
  }
}
