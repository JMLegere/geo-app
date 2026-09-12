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
  final _workingSets = Expando<_CellLookup>();

  @override
  ObservabilityService get obs => _obs;

  @override
  String get operationName => 'detect_cell_entry';

  /// Ray-casting algorithm for point-in-ring test.
  bool pointInRing({required GeoCoord point, required GeoRing ring}) {
    if (ring.length < 3) return false;

    bool inside = false;
    int j = ring.length - 1;

    for (int i = 0; i < ring.length; i++) {
      final xi = ring[i].lat;
      final yi = ring[i].lng;
      final xj = ring[j].lat;
      final yj = ring[j].lng;

      final intersect =
          ((yi > point.lng) != (yj > point.lng)) &&
          (point.lat < (xj - xi) * (point.lng - yi) / (yj - yi) + xi);

      if (intersect) inside = !inside;
      j = i;
    }

    return inside;
  }

  bool pointInPolygon({required GeoCoord point, required GeoPolygon polygon}) {
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

  /// Find the containing cell, checking the current cell and its neighbours first.
  ///
  /// Working sets and their geometry are immutable: replace the list when cells
  /// change. Identity caching avoids hashing or comparing polygons on each tick.
  Cell? detectCell({
    required List<Cell> cells,
    required GeoCoord point,
    String? preferredCellId,
  }) {
    final lookup = _workingSets[cells] ??= _CellLookup(cells);
    final preferred = lookup.byId[preferredCellId];

    if (preferred != null) {
      if (_contains(preferred, point)) return preferred.cell;
      for (final neighbour in preferred.neighbours) {
        if (_contains(neighbour, point)) return neighbour.cell;
      }
    }

    // A GPS teleport or an uncached/missing previous ID can land anywhere.
    // Only bounding-box candidates need the unchanged exact geometry test.
    for (final candidate in lookup.cells) {
      if (identical(candidate, preferred) ||
          (preferred?.neighbours.contains(candidate) ?? false)) {
        continue;
      }
      if (_contains(candidate, point)) return candidate.cell;
    }
    return null;
  }

  bool _contains(_IndexedCell candidate, GeoCoord point) =>
      candidate.containsBounds(point) &&
      pointInMultiPolygon(point: point, polygons: candidate.cell.polygons);

  @override
  Future<String?> execute(DetectCellEntryInput input, String traceId) async {
    final currentCell = detectCell(
      cells: input.cells,
      point: input.currentPoint,
      preferredCellId: input.previousCellId,
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

class _CellLookup {
  _CellLookup(List<Cell> workingSet) {
    final edgeOwners = <(int, int, int, int), List<_IndexedCell>>{};
    for (final cell in workingSet) {
      final indexed = _IndexedCell(cell);
      cells.add(indexed);
      byId.putIfAbsent(cell.id, () => indexed);
      for (final polygon in cell.polygons) {
        if (polygon.isEmpty || polygon.first.length < 3) continue;
        for (final point in polygon.first) {
          indexed.include(point);
        }
        for (final ring in polygon) {
          if (ring.length < 3) continue;
          for (var i = 0; i < ring.length; i++) {
            final start = ring[i];
            final end = ring[(i + 1) % ring.length];
            if (!start.lat.isFinite ||
                !start.lng.isFinite ||
                !end.lat.isFinite ||
                !end.lng.isFinite) {
              continue;
            }
            // Match FogStateService's orientation-independent 1e-7° edge keys.
            const scale = 10000000.0;
            final a = (
              (start.lat * scale).round(),
              (start.lng * scale).round(),
            );
            final b = ((end.lat * scale).round(), (end.lng * scale).round());
            if (a == b) continue;
            final forward = a.$1 < b.$1 || (a.$1 == b.$1 && a.$2 < b.$2);
            final key = forward
                ? (a.$1, a.$2, b.$1, b.$2)
                : (b.$1, b.$2, a.$1, a.$2);
            (edgeOwners[key] ??= []).add(indexed);
          }
        }
      }
    }
    for (final owners in edgeOwners.values) {
      for (final owner in owners) {
        owner.neighbours.addAll(owners);
        owner.neighbours.remove(owner);
      }
    }
  }

  final cells = <_IndexedCell>[];
  final byId = <String, _IndexedCell>{};
}

class _IndexedCell {
  _IndexedCell(this.cell);

  final Cell cell;
  final neighbours = <_IndexedCell>{};
  double _minLat = double.infinity;
  double _minLng = double.infinity;
  double _maxLat = double.negativeInfinity;
  double _maxLng = double.negativeInfinity;

  void include(GeoCoord point) {
    if (point.lat < _minLat) _minLat = point.lat;
    if (point.lng < _minLng) _minLng = point.lng;
    if (point.lat > _maxLat) _maxLat = point.lat;
    if (point.lng > _maxLng) _maxLng = point.lng;
  }

  bool containsBounds(GeoCoord point) =>
      point.lat >= _minLat &&
      point.lat <= _maxLat &&
      point.lng >= _minLng &&
      point.lng <= _maxLng;
}
