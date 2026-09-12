import 'dart:convert';

import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/map_level.dart';

final class DistrictBoundary {
  const DistrictBoundary({required this.polygons});

  final GeoMultiPolygon polygons;

  static DistrictBoundary? tryParseGeoJson(String? source) {
    if (source == null) return null;
    try {
      final json = jsonDecode(source);
      if (json is! Map) return null;
      return switch (json['type']) {
        'Polygon' => _fromPolygons([json['coordinates']]),
        'MultiPolygon' => _fromPolygons(json['coordinates']),
        _ => null,
      };
    } on FormatException {
      return null;
    }
  }

  static DistrictBoundary? _fromPolygons(Object? rawPolygons) {
    if (rawPolygons is! List || rawPolygons.isEmpty) return null;
    final polygons = <GeoPolygon>[];
    for (final rawPolygon in rawPolygons) {
      if (rawPolygon is! List || rawPolygon.isEmpty) return null;
      final polygon = <GeoRing>[];
      for (final rawRing in rawPolygon) {
        if (rawRing is! List || rawRing.length < 4) return null;
        final ring = <GeoCoord>[];
        for (final rawPoint in rawRing) {
          if (rawPoint is! List || rawPoint.length < 2) return null;
          final lng = rawPoint[0];
          final lat = rawPoint[1];
          if (lng is! num ||
              lat is! num ||
              !lng.isFinite ||
              !lat.isFinite ||
              lng < -180 ||
              lng > 180 ||
              lat < -85.05112878 ||
              lat > 85.05112878) {
            return null;
          }
          ring.add((lat: lat.toDouble(), lng: lng.toDouble()));
        }
        if (ring.first != ring.last) return null;
        polygon.add(ring);
      }
      polygons.add(polygon);
    }
    return DistrictBoundary(polygons: polygons);
  }
}

class HierarchyProgressSummary {
  const HierarchyProgressSummary({
    required this.id,
    required this.name,
    required this.level,
    required this.cellsVisited,
    required this.cellsTotal,
    required this.progressPercent,
    required this.rank,
    this.cellsTotalKnown = true,
    this.districtBoundary,
  });

  final String id;
  final String name;
  final MapLevel level;
  final int cellsVisited;
  final int cellsTotal;
  final double progressPercent;
  final int rank;
  final bool cellsTotalKnown;
  final DistrictBoundary? districtBoundary;

  HierarchyProgressSummary copyWith({
    int? cellsTotal,
    bool? cellsTotalKnown,
    DistrictBoundary? districtBoundary,
  }) {
    return HierarchyProgressSummary(
      id: id,
      name: name,
      level: level,
      cellsVisited: cellsVisited,
      cellsTotal: cellsTotal ?? this.cellsTotal,
      progressPercent: progressPercent,
      rank: rank,
      cellsTotalKnown: cellsTotalKnown ?? this.cellsTotalKnown,
      districtBoundary: districtBoundary ?? this.districtBoundary,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HierarchyProgressSummary &&
        other.id == id &&
        other.name == name &&
        other.level == level &&
        other.cellsVisited == cellsVisited &&
        other.cellsTotal == cellsTotal &&
        other.progressPercent == progressPercent &&
        other.rank == rank &&
        other.cellsTotalKnown == cellsTotalKnown &&
        other.districtBoundary == districtBoundary;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    level,
    cellsVisited,
    cellsTotal,
    progressPercent,
    rank,
    cellsTotalKnown,
    districtBoundary,
  );
}

abstract class HierarchyRepository {
  Future<HierarchyProgressSummary> getScopeSummary({
    required String userId,
    required MapLevel level,
    String? scopeId,
  });

  Future<List<HierarchyProgressSummary>> getChildSummaries({
    required String userId,
    required MapLevel level,
    String? scopeId,
  });
}

/// Safe failure emitted by hierarchy repository boundaries.
///
/// It excludes backend diagnostics so hierarchy callers and telemetry may
/// safely surface it.
final class HierarchyRepositoryFailure implements Exception {
  const HierarchyRepositoryFailure._(this.kind);

  const HierarchyRepositoryFailure.unavailable()
    : this._(HierarchyRepositoryFailureKind.unavailable);
  const HierarchyRepositoryFailure.malformedPayload()
    : this._(HierarchyRepositoryFailureKind.malformedPayload);

  final HierarchyRepositoryFailureKind kind;

  @override
  String toString() => 'Hierarchy request failed (${kind.name}).';
}

enum HierarchyRepositoryFailureKind { unavailable, malformedPayload }
