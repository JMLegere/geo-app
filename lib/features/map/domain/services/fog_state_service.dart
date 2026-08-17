import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_knowledge_projection.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';

class FogStateService {
  const FogStateService();

  List<({Cell cell, CellState state})> compute({
    required List<Cell> cells,
    required String? currentCellId,
    required Set<String> exploredCellIds,
    bool currentPositionIsTrusted = true,
    Map<String, CellKnowledgeProjection> knowledgeByCellId = const {},
  }) {
    final presentCellId = currentPositionIsTrusted ? currentCellId : null;
    final revealedCellIds = {
      ...exploredCellIds,
      ...knowledgeByCellId.entries
          .where((entry) => entry.value.state == CellKnowledgeState.informed)
          .map((entry) => entry.key),
      if (presentCellId != null) presentCellId,
    };
    final frontierCellIds = _frontierCellIds(
      cells: cells,
      revealedCellIds: revealedCellIds,
    );

    return cells.map((cell) {
      final projection = knowledgeByCellId[cell.id];
      final knowledgeState = _knowledgeStateFor(
        cellId: cell.id,
        presentCellId: presentCellId,
        exploredCellIds: exploredCellIds,
        projection: projection,
      );
      return (
        cell: cell,
        state: CellState(
          knowledgeState: knowledgeState,
          category: knowledgeState == CellKnowledgeState.informed
              ? projection?.category
              : null,
          relationship: _relationshipFor(
            knowledgeState: knowledgeState,
            isFrontier: frontierCellIds.contains(cell.id),
          ),
          contents: CellContents.empty,
        ),
      );
    }).toList(growable: false);
  }

  Set<String> _frontierCellIds({
    required List<Cell> cells,
    required Set<String> revealedCellIds,
  }) {
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

  CellKnowledgeState _knowledgeStateFor({
    required String cellId,
    required String? presentCellId,
    required Set<String> exploredCellIds,
    required CellKnowledgeProjection? projection,
  }) {
    if (cellId == presentCellId) return CellKnowledgeState.present;
    if (projection?.state == CellKnowledgeState.informed) {
      return CellKnowledgeState.informed;
    }
    if (exploredCellIds.contains(cellId) ||
        projection?.state == CellKnowledgeState.explored) {
      return CellKnowledgeState.explored;
    }
    return CellKnowledgeState.shrouded;
  }

  CellRelationship _relationshipFor({
    required CellKnowledgeState knowledgeState,
    required bool isFrontier,
  }) =>
      switch (knowledgeState) {
        CellKnowledgeState.present => CellRelationship.present,
        CellKnowledgeState.informed ||
        CellKnowledgeState.explored =>
          CellRelationship.explored,
        CellKnowledgeState.shrouded =>
          isFrontier ? CellRelationship.frontier : CellRelationship.unknown,
      };
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
