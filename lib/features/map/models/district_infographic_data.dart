import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geobase/geobase.dart';

/// Immutable snapshot of all data needed to render the district infographic.
///
/// Built once when the infographic opens from provider state — no ongoing
/// computation while visible (GBA rule compliance). The painter reads
/// this data and never calls services or providers directly.
@immutable
class DistrictInfographicData {
  const DistrictInfographicData({
    required this.districtName,
    required this.districtId,
    required this.boundaryRings,
    required this.allCellIds,
    required this.exploredCellIds,
    required this.exploredCellBoundaries,
    required this.playerLat,
    required this.playerLon,
    required this.totalSpeciesFound,
    required this.minLat,
    required this.maxLat,
    required this.minLon,
    required this.maxLon,
  });

  final String districtName;
  final String districtId;

  /// Outer boundary rings of the district polygon (parsed from geometryJson).
  /// Empty if no geometry available.
  final List<List<Geographic>> boundaryRings;

  /// All cell IDs in this district (from detection zone attribution).
  final List<String> allCellIds;

  /// Cell IDs the player has physically visited (explored).
  final Set<String> exploredCellIds;

  /// Pre-computed polygon vertices for each explored cell.
  /// Keyed by cell ID. The painter renders these as light fills.
  final Map<String, List<Geographic>> exploredCellBoundaries;

  final double playerLat;
  final double playerLon;
  final int totalSpeciesFound;

  // Bounding box of the district (for projection fitting).
  final double minLat;
  final double maxLat;
  final double minLon;
  final double maxLon;

  /// Exploration progress as a fraction (0.0–1.0).
  double get explorationPercent =>
      allCellIds.isEmpty ? 0.0 : exploredCellIds.length / allCellIds.length;

  /// Whether we have boundary geometry to render.
  bool get hasBoundary => boundaryRings.isNotEmpty;

  /// Parses GeoJSON geometry string into a list of coordinate rings.
  /// Handles both Polygon and MultiPolygon types.
  /// Returns empty list if parsing fails or geometry is null.
  static List<List<Geographic>> parseBoundaryRings(String? geometryJson) {
    if (geometryJson == null || geometryJson.isEmpty) return const [];

    try {
      final geo = jsonDecode(geometryJson) as Map<String, dynamic>;
      final type = geo['type'] as String?;
      final coordinates = geo['coordinates'];

      if (coordinates == null) return const [];

      if (type == 'Polygon') {
        return _parsePolygonCoords(coordinates as List);
      } else if (type == 'MultiPolygon') {
        final rings = <List<Geographic>>[];
        for (final polygon in coordinates as List) {
          rings.addAll(_parsePolygonCoords(polygon as List));
        }
        return rings;
      }
    } catch (e) {
      debugPrint('[DistrictInfographic] failed to parse geometry: $e');
    }
    return const [];
  }

  static List<List<Geographic>> _parsePolygonCoords(List polygonCoords) {
    final rings = <List<Geographic>>[];
    for (final ring in polygonCoords) {
      final coords = <Geographic>[];
      for (final point in ring as List) {
        final p = point as List;
        coords.add(Geographic(
          lat: (p[1] as num).toDouble(),
          lon: (p[0] as num).toDouble(),
        ));
      }
      if (coords.length >= 3) rings.add(coords);
    }
    return rings;
  }
}
