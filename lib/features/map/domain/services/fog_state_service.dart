import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';

class FogStateService {
  const FogStateService();

  List<({Cell cell, CellState state})> compute({
    required List<Cell> cells,
    required String? currentCellId,
    required Set<String> exploredCellIds,
  }) {
    final frontierCellIds = _frontierCellIds(
      cells: cells,
      currentCellId: currentCellId,
      exploredCellIds: exploredCellIds,
    );

    return cells.map((cell) {
      final relationship = _relationshipFor(
        cellId: cell.id,
        currentCellId: currentCellId,
        exploredCellIds: exploredCellIds,
        frontierCellIds: frontierCellIds,
      );

      return (
        cell: cell,
        state: CellState(
          relationship: relationship,
          contents: CellContents.empty,
        ),
      );
    }).toList(growable: false);
  }

  Set<String> _frontierCellIds({
    required List<Cell> cells,
    required String? currentCellId,
    required Set<String> exploredCellIds,
  }) {
    final revealedCellIds = {
      ...exploredCellIds,
      if (currentCellId != null) currentCellId,
    };
    final cellEdges = {
      for (final cell in cells) cell.id: _borderEdgesFor(cell).toSet(),
    };
    final revealedEdges = <_GeoEdgeKey>{};

    for (final cellId in revealedCellIds) {
      final edges = cellEdges[cellId];
      if (edges != null) revealedEdges.addAll(edges);
    }

    if (revealedEdges.isEmpty) return const {};

    final frontierCellIds = <String>{};
    for (final cell in cells) {
      if (revealedCellIds.contains(cell.id)) continue;
      final edges = cellEdges[cell.id] ?? const <_GeoEdgeKey>{};
      if (edges.any(revealedEdges.contains)) {
        frontierCellIds.add(cell.id);
      }
    }

    return frontierCellIds;
  }

  Iterable<_GeoEdgeKey> _borderEdgesFor(Cell cell) sync* {
    for (final polygon in cell.polygons) {
      if (polygon.isEmpty) continue;
      final exteriorRing = _withoutClosingPoint(polygon.first);
      if (exteriorRing.length < 3) continue;

      for (var i = 0; i < exteriorRing.length; i++) {
        final start = exteriorRing[i];
        final end = exteriorRing[(i + 1) % exteriorRing.length];
        if (_sameCoord(start, end)) continue;
        yield _GeoEdgeKey.fromCoords(start, end);
      }
    }
  }

  List<GeoCoord> _withoutClosingPoint(GeoRing ring) {
    if (ring.length > 1 && _sameCoord(ring.first, ring.last)) {
      return ring.sublist(0, ring.length - 1);
    }
    return ring;
  }

  bool _sameCoord(GeoCoord a, GeoCoord b) {
    return a.lat == b.lat && a.lng == b.lng;
  }

  CellRelationship _relationshipFor({
    required String cellId,
    required String? currentCellId,
    required Set<String> exploredCellIds,
    required Set<String> frontierCellIds,
  }) {
    if (cellId == currentCellId) return CellRelationship.present;
    if (exploredCellIds.contains(cellId)) return CellRelationship.explored;
    if (frontierCellIds.contains(cellId)) return CellRelationship.frontier;
    return CellRelationship.unknown;
  }
}

class _GeoEdgeKey {
  const _GeoEdgeKey(this.aLat, this.aLng, this.bLat, this.bLng);

  factory _GeoEdgeKey.fromCoords(GeoCoord start, GeoCoord end) {
    final a = _SnappedGeoCoord.fromCoord(start);
    final b = _SnappedGeoCoord.fromCoord(end);
    final ordered = a.compareTo(b) <= 0 ? (a: a, b: b) : (a: b, b: a);
    return _GeoEdgeKey(
      ordered.a.lat,
      ordered.a.lng,
      ordered.b.lat,
      ordered.b.lng,
    );
  }

  final int aLat;
  final int aLng;
  final int bLat;
  final int bLng;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _GeoEdgeKey &&
          aLat == other.aLat &&
          aLng == other.aLng &&
          bLat == other.bLat &&
          bLng == other.bLng;

  @override
  int get hashCode => Object.hash(aLat, aLng, bLat, bLng);
}

class _SnappedGeoCoord implements Comparable<_SnappedGeoCoord> {
  const _SnappedGeoCoord(this.lat, this.lng);

  factory _SnappedGeoCoord.fromCoord(GeoCoord coord) {
    const coordinateScale = 10000000.0;
    return _SnappedGeoCoord(
      (coord.lat * coordinateScale).round(),
      (coord.lng * coordinateScale).round(),
    );
  }

  final int lat;
  final int lng;

  @override
  int compareTo(_SnappedGeoCoord other) {
    final latCompare = lat.compareTo(other.lat);
    if (latCompare != 0) return latCompare;
    return lng.compareTo(other.lng);
  }
}
