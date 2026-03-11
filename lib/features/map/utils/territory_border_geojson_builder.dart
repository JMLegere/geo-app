import 'dart:convert';

import 'package:geobase/geobase.dart' show Geographic;

import 'package:earth_nova/core/models/cell_properties.dart';
import 'package:earth_nova/core/models/location_node.dart';

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
  /// [cellProperties] maps cell IDs to their resolved properties (with locationId).
  /// [locationNodes] maps node IDs to their LocationNode (full hierarchy).
  /// [visibleCellIds] are cell IDs currently in the viewport.
  /// [getNeighborIds] resolves a cell ID to its neighbor cell IDs.
  /// [getBoundary] resolves a cell ID to its boundary polygon vertices.
  static String buildBorderFill({
    required Map<String, CellProperties> cellProperties,
    required Map<String, LocationNode> locationNodes,
    required Set<String> visibleCellIds,
    required List<String> Function(String cellId) getNeighborIds,
    required List<Geographic> Function(String cellId) getBoundary,
  }) {
    // Step 1: Build ancestor chains for all cells with location data.
    final cellAncestors = _buildCellAncestors(
      cellProperties: cellProperties,
      locationNodes: locationNodes,
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
    final cellColors = _resolveCellColors(
      cellAncestors: cellAncestors,
      locationNodes: locationNodes,
    );

    // Step 5: Emit polygon features.
    final features = StringBuffer();
    var first = true;

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

    return '{"type":"FeatureCollection","features":[$features]}';
  }

  /// Builds a GeoJSON FeatureCollection of LineString features for border
  /// edges between adjacent cells in different admin regions.
  ///
  /// Each feature represents a shared Voronoi edge (2-vertex line) with
  /// properties:
  /// ```json
  /// {
  ///   "admin_level": "country",
  ///   "border_color": "#3B7DD8",
  ///   "line_weight": 3.0
  /// }
  /// ```
  ///
  /// Only the lowest-level differing border is emitted per cell pair.
  ///
  /// [cellProperties] maps cell IDs to their resolved properties.
  /// [locationNodes] maps node IDs to their LocationNode (full hierarchy).
  /// [visibleCellIds] are cell IDs currently in the viewport.
  /// [getNeighborIds] resolves a cell ID to its neighbor cell IDs.
  /// [getBoundary] resolves a cell ID to its boundary polygon vertices.
  static String buildBorderLines({
    required Map<String, CellProperties> cellProperties,
    required Map<String, LocationNode> locationNodes,
    required Set<String> visibleCellIds,
    required List<String> Function(String cellId) getNeighborIds,
    required List<Geographic> Function(String cellId) getBoundary,
  }) {
    final cellAncestors = _buildCellAncestors(
      cellProperties: cellProperties,
      locationNodes: locationNodes,
      cellIds: visibleCellIds,
    );

    final features = StringBuffer();
    var first = true;

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

        // Determine border color (from the cell's own region).
        final nodeId = cellAnc[differingLevel];
        final node = nodeId != null ? locationNodes[nodeId] : null;
        final color = node != null ? _nodeColor(node) : '#888888';
        final weight = _lineWeight(differingLevel);

        if (!first) features.write(',');
        first = false;

        features.write('{"type":"Feature","geometry":{"type":"LineString",'
            '"coordinates":['
            '[${edge.$1.lon},${edge.$1.lat}],'
            '[${edge.$2.lon},${edge.$2.lat}]'
            ']},"properties":{'
            '"admin_level":"${differingLevel.name}",'
            '"border_color":"$color",'
            '"line_weight":$weight'
            '}}');
      }
    }

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
        AdminLevel.country => 3.0,
        AdminLevel.state => 2.0,
        AdminLevel.city => 1.5,
        AdminLevel.district => 1.0,
        _ => 1.0,
      };

  /// Builds ancestor chain (nodeId per admin level) for each cell.
  ///
  /// Returns `{cellId: {AdminLevel: nodeId}}` — walking from the cell's
  /// leaf LocationNode up to the root, recording the node ID at each level.
  static Map<String, Map<AdminLevel, String>> _buildCellAncestors({
    required Map<String, CellProperties> cellProperties,
    required Map<String, LocationNode> locationNodes,
    required Set<String> cellIds,
  }) {
    final result = <String, Map<AdminLevel, String>>{};

    for (final cellId in cellIds) {
      final props = cellProperties[cellId];
      if (props == null || props.locationId == null) continue;

      final ancestors = <AdminLevel, String>{};
      var current = locationNodes[props.locationId!];
      while (current != null) {
        ancestors[current.adminLevel] = current.id;
        if (current.parentId == null) break;
        current = locationNodes[current.parentId!];
      }

      if (ancestors.isNotEmpty) {
        result[cellId] = ancestors;
      }
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
  /// Color comes from `LocationNode.colorHex`, or deterministic SHA-256 of
  /// osmId if null.
  ///
  /// Returns `{cellId: {AdminLevel: "#RRGGBB"}}`.
  static Map<String, Map<AdminLevel, String>> _resolveCellColors({
    required Map<String, Map<AdminLevel, String>> cellAncestors,
    required Map<String, LocationNode> locationNodes,
  }) {
    final result = <String, Map<AdminLevel, String>>{};

    for (final entry in cellAncestors.entries) {
      final cellId = entry.key;
      final ancestors = entry.value;
      final colors = <AdminLevel, String>{};

      for (final level in _renderableLevels) {
        final nodeId = ancestors[level];
        if (nodeId == null) continue;

        final node = locationNodes[nodeId];
        if (node == null) continue;

        colors[level] = _nodeColor(node);
      }

      if (colors.isNotEmpty) {
        result[cellId] = colors;
      }
    }

    return result;
  }

  /// Returns the display color for a LocationNode.
  ///
  /// Uses `colorHex` if set, otherwise generates a deterministic color from
  /// the osmId via simple hash-based generation.
  static String _nodeColor(LocationNode node) {
    if (node.colorHex != null) return node.colorHex!;

    // Deterministic color from osmId (or node ID as fallback).
    final source = node.osmId?.toString() ?? node.id;
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
  /// Two cells share an edge if they have exactly 2 vertices in common
  /// (within a small epsilon for floating-point comparison).
  static (Geographic, Geographic)? _findSharedEdge(
    List<Geographic> boundaryA,
    List<Geographic> boundaryB,
  ) {
    const epsilon = 1e-9;
    final shared = <Geographic>[];

    for (final a in boundaryA) {
      for (final b in boundaryB) {
        if ((a.lat - b.lat).abs() < epsilon &&
            (a.lon - b.lon).abs() < epsilon) {
          shared.add(a);
          if (shared.length == 2) return (shared[0], shared[1]);
        }
      }
    }

    return null;
  }
}
