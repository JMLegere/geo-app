import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geobase/geobase.dart' show Geographic;

import 'package:earth_nova/core/models/admin_level.dart';
import 'package:earth_nova/core/models/cell_properties.dart';

/// Builds GeoJSON FeatureCollections for Stellaris-style territory borders.
///
/// Territory borders visualize administrative boundaries (country, state, city,
/// district) as colored lines on Voronoi cell edges and gradient fills that
/// fade inward from border cells.
///
/// ## Two outputs:
///
/// 1. **Border lines** — LineString features on shared Voronoi edges where
///    adjacent cells belong to different admin regions. Line weight and zoom
///    gate vary by admin level (country=thickest, district=thinnest).
///
/// 2. **Border fill** — Polygon features for cells near borders, with
///    `border_distance_<level>` and `region_color_<level>` properties for
///    MapLibre data-driven opacity (quadratic falloff: 0.15 → 0.04 → 0.01 → 0).
///
/// ## Stacking rules:
///
/// Only the **lowest-level differing border** renders between two adjacent
/// cells. Two cells in the same country + same state + different districts →
/// district border only. Two cells in different countries → country border.
///
/// All coordinates use GeoJSON convention: **[longitude, latitude]**.
class TerritoryBorderGeoJsonBuilder {
  const TerritoryBorderGeoJsonBuilder._();

  /// Builds a GeoJSON FeatureCollection of Polygon features for border
  /// gradient fill.
  ///
  /// Each cell polygon gets properties like:
  /// ```json
  /// {
  ///   "cell_id": "v_123_456",
  ///   "border_distance_country": 2,
  ///   "border_distance_state": 0,
  ///   "region_color_country": "#3B7DD8",
  ///   "region_color_state": "#2E8B57"
  /// }
  /// ```
  ///
  /// Cells with `border_distance >= 3` at all levels get no border properties
  /// (clean map — 95% of surface).
  ///
  /// [cellProperties] maps cell IDs to their resolved properties.
  /// [cellDistrictIds] maps cell ID to district ID (lowest-level location).
  /// [districtAncestry] maps district ID to its parent chain (city, state, country).
  /// [visibleCellIds] are cell IDs currently in the viewport.
  /// [getNeighborIds] resolves a cell ID to its neighbor cell IDs.
  /// [getBoundary] resolves a cell ID to its boundary polygon vertices.
  static String buildBorderFill({
    required Map<String, CellProperties> cellProperties,
    required Map<String, String> cellDistrictIds,
    required Map<String, ({String? cityId, String? stateId, String? countryId})>
        districtAncestry,
    required Set<String> visibleCellIds,
    required List<String> Function(String cellId) getNeighborIds,
    required List<Geographic> Function(String cellId) getBoundary,
  }) {
    // Step 1: Build ancestor chains for all cells with location data.
    final cellAncestors = _buildCellAncestors(
      cellDistrictIds: cellDistrictIds,
      districtAncestry: districtAncestry,
      cellIds: visibleCellIds,
    );

    // Step 2: Identify border cells at each admin level via neighbor comparison.
    final borderCells = _findBorderCells(
      cellAncestors: cellAncestors,
      getNeighborIds: getNeighborIds,
    );

    // Step 3: BFS from border cells inward to compute distances.
    final distances = <AdminLevel, Map<String, int>>{};
    for (final level in _renderableLevels) {
      final seeds = borderCells[level] ?? {};
      if (seeds.isEmpty) continue;
      distances[level] = _bfsDistances(
        seeds: seeds,
        allCellIds: visibleCellIds,
        getNeighborIds: getNeighborIds,
        maxDistance: 3,
      );
    }

    // Step 4: Resolve colors per cell per admin level.
    final cellColors = _resolveCellColors(cellAncestors: cellAncestors);

    // Step 5: Emit polygon features.
    final features = StringBuffer();
    var first = true;
    var featureCount = 0;

    for (final cellId in visibleCellIds) {
      final boundary = getBoundary(cellId);
      if (boundary.length < 3) continue;

      // Collect border properties for this cell.
      final props = <String, dynamic>{'cell_id': cellId};
      var hasBorderProp = false;

      for (final level in _renderableLevels) {
        final dist = distances[level]?[cellId];
        if (dist != null && dist < 3) {
          props['border_distance_${level.name}'] = dist;
          final color = cellColors[cellId]?[level];
          if (color != null) {
            props['region_color_${level.name}'] = color;
          }
          hasBorderProp = true;
        }
      }

      // Skip cells with no border proximity (clean map).
      if (!hasBorderProp) continue;

      if (!first) features.write(',');
      first = false;
      featureCount++;

      features.write('{"type":"Feature","geometry":{"type":"Polygon",'
          '"coordinates":[[');
      for (var i = 0; i < boundary.length; i++) {
        if (i > 0) features.write(',');
        features.write('[${boundary[i].lon},${boundary[i].lat}]');
      }
      // Close ring.
      features.write(',[${boundary[0].lon},${boundary[0].lat}]');
      features.write(']]},');
      features.write('"properties":${jsonEncode(props)}}');
    }

    debugPrint(
        '[BORDERS] fill: $featureCount features from ${visibleCellIds.length} cells');
    return '{"type":"FeatureCollection","features":[$features]}';
  }

  /// Builds a GeoJSON FeatureCollection of LineString features for border
  /// edges between adjacent cells in different admin regions.
  ///
  /// Each shared edge emits **two** features — one per side — so each half
  /// can be colored with its respective district's color and offset to its
  /// own side via MapLibre's `line-offset` paint property.
  ///
  /// Feature properties:
  /// ```json
  /// {
  ///   "admin_level": "country",
  ///   "border_color": "#3B7DD8",
  ///   "line_weight": 3.0,
  ///   "side": 1
  /// }
  /// ```
  ///
  /// `side` is `1` (cell's own side) or `-1` (neighbor's side). Combine
  /// with `line-offset: ['*', ['get', 'side'], ['/', ['get', 'line_weight'], 2]]`
  /// to push each half to its respective side.
  ///
  /// Only the lowest-level differing border is emitted per cell pair.
  static String buildBorderLines({
    required Map<String, CellProperties> cellProperties,
    required Map<String, String> cellDistrictIds,
    required Map<String, ({String? cityId, String? stateId, String? countryId})>
        districtAncestry,
    required Set<String> visibleCellIds,
    required List<String> Function(String cellId) getNeighborIds,
    required List<Geographic> Function(String cellId) getBoundary,
    required Geographic Function(String cellId) getCellCenter,
  }) {
    final cellAncestors = _buildCellAncestors(
      cellDistrictIds: cellDistrictIds,
      districtAncestry: districtAncestry,
      cellIds: visibleCellIds,
    );

    final features = StringBuffer();
    var first = true;
    var edgesProcessed = 0;
    var dualLinesEmitted = 0;

    // Track processed pairs to avoid duplicate edges.
    final processedPairs = <String>{};

    for (final cellId in visibleCellIds) {
      final cellAnc = cellAncestors[cellId];
      if (cellAnc == null) continue;

      final neighbors = getNeighborIds(cellId);
      for (final neighborId in neighbors) {
        // Skip if neighbor not in viewport or already processed.
        if (!visibleCellIds.contains(neighborId)) continue;

        final pairKey = _pairKey(cellId, neighborId);
        if (processedPairs.contains(pairKey)) continue;
        processedPairs.add(pairKey);

        final neighborAnc = cellAncestors[neighborId];
        if (neighborAnc == null) continue;

        // Find the lowest-level differing admin level.
        final differingLevel = _lowestDifferingLevel(cellAnc, neighborAnc);
        if (differingLevel == null) continue;

        // Find shared edge between the two cells.
        final edge = _findSharedEdge(
          getBoundary(cellId),
          getBoundary(neighborId),
        );
        if (edge == null) continue;
        edgesProcessed++;

        // Resolve colors for both sides via FNV-1a hash of the region ID.
        final cellNodeId = cellAnc[differingLevel];
        final neighborNodeId = neighborAnc[differingLevel];
        final cellColor =
            cellNodeId != null ? _fnvColor(cellNodeId) : '#888888';
        final neighborColor =
            neighborNodeId != null ? _fnvColor(neighborNodeId) : '#888888';
        final weight = _lineWeight(differingLevel);

        // Determine which side of the edge the cell center is on using the
        // cross product of (edge direction) × (edge midpoint → cell center).
        // Positive cross → cell is on the left (positive offset side).
        final edgeMidLon = (edge.$1.lon + edge.$2.lon) / 2;
        final edgeMidLat = (edge.$1.lat + edge.$2.lat) / 2;
        final edgeDx = edge.$2.lon - edge.$1.lon;
        final edgeDy = edge.$2.lat - edge.$1.lat;
        final cellCenter = getCellCenter(cellId);
        final toCellDx = cellCenter.lon - edgeMidLon;
        final toCellDy = cellCenter.lat - edgeMidLat;
        final cross = edgeDx * toCellDy - edgeDy * toCellDx;
        final cellSide = cross >= 0 ? 1 : -1;

        // Emit two features — one per side.
        final lineCoords =
            '[[${edge.$1.lon},${edge.$1.lat}],[${edge.$2.lon},${edge.$2.lat}]]';

        // Cell's side.
        if (!first) features.write(',');
        first = false;
        features.write('{"type":"Feature","geometry":{"type":"LineString",'
            '"coordinates":$lineCoords},'
            '"properties":{"admin_level":"${differingLevel.name}",'
            '"border_color":"$cellColor","line_weight":$weight,"side":$cellSide}}');

        // Neighbor's side.
        features.write(',');
        features.write('{"type":"Feature","geometry":{"type":"LineString",'
            '"coordinates":$lineCoords},'
            '"properties":{"admin_level":"${differingLevel.name}",'
            '"border_color":"$neighborColor","line_weight":$weight,"side":${-cellSide}}}');
        dualLinesEmitted += 2;
      }
    }

    debugPrint(
        '[BORDERS] lines: $dualLinesEmitted features from $edgesProcessed edges, ${visibleCellIds.length} cells');
    return '{"type":"FeatureCollection","features":[$features]}';
  }

  /// Returns an empty GeoJSON FeatureCollection.
  static String get emptyFeatureCollection =>
      '{"type":"FeatureCollection","features":[]}';

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Admin levels that produce visible borders (world/continent are too coarse).
  static const _renderableLevels = [
    AdminLevel.country,
    AdminLevel.state,
    AdminLevel.city,
    AdminLevel.district,
  ];

  /// Line weight by admin level (country=thickest, district=thinnest).
  static double _lineWeight(AdminLevel level) => switch (level) {
        AdminLevel.country => 12.0,
        AdminLevel.state => 8.0,
        AdminLevel.city => 6.0,
        AdminLevel.district => 4.0,
        _ => 4.0,
      };

  /// Builds ancestor chain (nodeId per admin level) for each cell.
  ///
  /// Returns `{cellId: {AdminLevel: regionId}}` — using [cellDistrictIds] to
  /// find each cell's district, then [districtAncestry] to walk up the tree.
  static Map<String, Map<AdminLevel, String>> _buildCellAncestors({
    required Map<String, String> cellDistrictIds,
    required Map<String, ({String? cityId, String? stateId, String? countryId})>
        districtAncestry,
    required Set<String> cellIds,
  }) {
    final result = <String, Map<AdminLevel, String>>{};

    for (final cellId in cellIds) {
      final districtId = cellDistrictIds[cellId];
      if (districtId == null) continue;

      final ancestry = districtAncestry[districtId];
      if (ancestry == null) continue;

      final ancestors = <AdminLevel, String>{
        AdminLevel.district: districtId,
      };
      if (ancestry.cityId != null)
        ancestors[AdminLevel.city] = ancestry.cityId!;
      if (ancestry.stateId != null) {
        ancestors[AdminLevel.state] = ancestry.stateId!;
      }
      if (ancestry.countryId != null) {
        ancestors[AdminLevel.country] = ancestry.countryId!;
      }

      result[cellId] = ancestors;
    }

    return result;
  }

  /// Finds border cells at each admin level.
  ///
  /// A cell is a "border cell" at level X if any of its neighbors has a
  /// different ancestor node ID at that level.
  ///
  /// Returns `{AdminLevel: {cellId, ...}}`.
  static Map<AdminLevel, Set<String>> _findBorderCells({
    required Map<String, Map<AdminLevel, String>> cellAncestors,
    required List<String> Function(String cellId) getNeighborIds,
  }) {
    final result = <AdminLevel, Set<String>>{};

    for (final entry in cellAncestors.entries) {
      final cellId = entry.key;
      final cellAnc = entry.value;
      final neighbors = getNeighborIds(cellId);

      for (final level in _renderableLevels) {
        final cellNodeId = cellAnc[level];
        if (cellNodeId == null) continue;

        for (final neighborId in neighbors) {
          final neighborAnc = cellAncestors[neighborId];
          // Skip neighbors with no location data — they're outside the
          // mapped territory, not an actual admin boundary.
          if (neighborAnc == null) continue;
          final neighborNodeId = neighborAnc[level];
          if (neighborNodeId == null) continue;
          if (neighborNodeId != cellNodeId) {
            result.putIfAbsent(level, () => {}).add(cellId);
            break;
          }
        }
      }
    }

    return result;
  }

  /// BFS from seed cells outward, returning distance from nearest border.
  ///
  /// Seeds start at distance 0. Each neighbor layer increments by 1.
  /// Stops at [maxDistance] — cells beyond are not included in the map.
  static Map<String, int> _bfsDistances({
    required Set<String> seeds,
    required Set<String> allCellIds,
    required List<String> Function(String cellId) getNeighborIds,
    required int maxDistance,
  }) {
    final distances = <String, int>{};
    var frontier = <String>{};

    // Initialize seeds at distance 0.
    for (final seed in seeds) {
      if (allCellIds.contains(seed)) {
        distances[seed] = 0;
        frontier.add(seed);
      }
    }

    for (var dist = 1; dist <= maxDistance; dist++) {
      final nextFrontier = <String>{};
      for (final cellId in frontier) {
        for (final neighborId in getNeighborIds(cellId)) {
          if (!allCellIds.contains(neighborId)) continue;
          if (distances.containsKey(neighborId)) continue;
          distances[neighborId] = dist;
          nextFrontier.add(neighborId);
        }
      }
      frontier = nextFrontier;
      if (frontier.isEmpty) break;
    }

    return distances;
  }

  /// Resolves the border color for each cell at each admin level.
  ///
  /// Color is a deterministic FNV-1a hash of the region ID string.
  ///
  /// Returns `{cellId: {AdminLevel: "#RRGGBB"}}`.
  static Map<String, Map<AdminLevel, String>> _resolveCellColors({
    required Map<String, Map<AdminLevel, String>> cellAncestors,
  }) {
    final result = <String, Map<AdminLevel, String>>{};

    for (final entry in cellAncestors.entries) {
      final cellId = entry.key;
      final ancestors = entry.value;
      final colors = <AdminLevel, String>{};

      for (final level in _renderableLevels) {
        final nodeId = ancestors[level];
        if (nodeId == null) continue;
        colors[level] = _fnvColor(nodeId);
      }

      if (colors.isNotEmpty) {
        result[cellId] = colors;
      }
    }

    return result;
  }

  /// Generates a deterministic hex color from a string via FNV-1a 32-bit hash.
  static String _fnvColor(String source) {
    var hash = 0x811c9dc5; // FNV-1a 32-bit offset basis.
    for (var i = 0; i < source.length; i++) {
      hash ^= source.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF; // FNV prime, 32-bit.
    }
    final r = (hash >> 16) & 0xFF;
    final g = (hash >> 8) & 0xFF;
    final b = hash & 0xFF;
    return '#${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}';
  }

  /// Finds the lowest (most specific) admin level where two cells differ.
  ///
  /// Walks from district → city → state → country. Returns the first level
  /// where ancestors differ. Returns null if cells are in the same region
  /// at all levels.
  static AdminLevel? _lowestDifferingLevel(
    Map<AdminLevel, String> ancestorsA,
    Map<AdminLevel, String> ancestorsB,
  ) {
    // Check from most specific to least specific.
    for (final level in _renderableLevels.reversed) {
      final a = ancestorsA[level];
      final b = ancestorsB[level];
      // If either has no data at this level, skip — can't determine difference.
      if (a == null || b == null) continue;
      if (a != b) return level;
    }
    return null;
  }

  /// Creates a canonical pair key for two cell IDs (order-independent).
  static String _pairKey(String a, String b) =>
      a.compareTo(b) < 0 ? '$a|$b' : '$b|$a';

  /// Finds the shared edge (2 vertices) between two Voronoi cell boundaries.
  ///
  /// Uses a hash-set lookup (O(P+Q)) instead of brute-force O(P×Q).
  /// Vertex coordinates are quantized to 6 decimal places (~0.11 m) for
  /// stable hashing while tolerating floating-point rounding.
  static (Geographic, Geographic)? _findSharedEdge(
    List<Geographic> boundaryA,
    List<Geographic> boundaryB,
  ) {
    // Build hash set from the shorter boundary.
    final (indexed, probe) = boundaryA.length <= boundaryB.length
        ? (boundaryA, boundaryB)
        : (boundaryB, boundaryA);

    final index = <int, Geographic>{};
    for (final v in indexed) {
      index[_vertexHash(v.lat, v.lon)] = v;
    }

    final shared = <Geographic>[];
    for (final v in probe) {
      final match = index[_vertexHash(v.lat, v.lon)];
      if (match != null) {
        shared.add(match);
        if (shared.length == 2) return (shared[0], shared[1]);
      }
    }
    return null;
  }

  /// Quantizes a coordinate to 6 decimal places and returns a hash.
  static int _vertexHash(double lat, double lon) {
    final qLat = (lat * 1e6).round();
    final qLon = (lon * 1e6).round();
    return qLat * 360000001 +
        qLon; // large prime-ish multiplier avoids collisions
  }
}
