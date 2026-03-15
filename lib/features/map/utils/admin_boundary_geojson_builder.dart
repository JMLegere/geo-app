import 'dart:convert';

import 'package:earth_nova/core/models/location_node.dart';
import 'package:earth_nova/shared/constants.dart';

/// Builds GeoJSON FeatureCollections for admin boundary fills and lines.
///
/// Converts [LocationNode]s with Nominatim-sourced polygon geometry into
/// MapLibre-compatible GeoJSON for rendering admin boundary fills and outlines.
///
/// ## Two outputs:
///
/// 1. **Boundary fills** — Polygon/MultiPolygon features per node, with
///    data-driven `opacity` and `color` properties for MapLibre fill layers.
///
/// 2. **Boundary lines** — LineString features extracted from exterior rings,
///    with `line_weight` and `color` properties for MapLibre line layers.
///
/// World and continent level nodes are excluded (too coarse to be useful).
///
/// All coordinates use GeoJSON convention: **[longitude, latitude]**.
class AdminBoundaryGeoJsonBuilder {
  const AdminBoundaryGeoJsonBuilder._();

  /// Empty GeoJSON FeatureCollection constant.
  static const String emptyFeatureCollection =
      '{"type":"FeatureCollection","features":[]}';

  /// Admin levels that produce visible boundaries.
  /// World and continent are excluded — too coarse for per-boundary rendering.
  static const _renderableLevels = {
    AdminLevel.country,
    AdminLevel.state,
    AdminLevel.city,
    AdminLevel.district,
  };

  /// Builds a GeoJSON FeatureCollection of Polygon/MultiPolygon fill features
  /// for admin boundaries.
  ///
  /// Each [LocationNode] with a non-null [LocationNode.geometryJson] emits one
  /// Feature with the geometry passed through directly (Polygon or
  /// MultiPolygon). World and continent level nodes are skipped. Nodes without
  /// geometry are silently skipped — no crash, no empty feature.
  ///
  /// Feature properties:
  /// - `admin_level` (String): e.g., `"country"`, `"state"`
  /// - `color` (String): hex from [LocationNode.colorHex] or FNV-1a hash
  /// - `name` (String): node display name
  /// - `opacity` (double): fill opacity by level
  ///   (country → 0.04, state → 0.06, city → 0.08, district → 0.10)
  static String buildBoundaryFills(Map<String, LocationNode> nodes) {
    if (nodes.isEmpty) return emptyFeatureCollection;

    final features = StringBuffer();
    var first = true;

    for (final node in nodes.values) {
      if (!_renderableLevels.contains(node.adminLevel)) continue;
      final rawGeom = node.geometryJson;
      if (rawGeom == null) continue;
      // Unwrap double-encoded geometry (legacy data stored as JSON-of-JSON).
      final geomJson =
          rawGeom.startsWith('"') ? jsonDecode(rawGeom) as String : rawGeom;

      if (!first) features.write(',');
      first = false;

      final color = _nodeColor(node);
      final opacity = _fillOpacity(node.adminLevel);

      features
        ..write('{"type":"Feature","geometry":')
        ..write(geomJson)
        ..write(',"properties":{')
        ..write('"admin_level":"${node.adminLevel.name}",')
        ..write('"color":"$color",')
        ..write('"name":"${_escapeName(node.name)}",')
        ..write('"opacity":$opacity')
        ..write('}}');
    }

    return '{"type":"FeatureCollection","features":[$features]}';
  }

  /// Builds a GeoJSON FeatureCollection of LineString features for admin
  /// boundary outlines.
  ///
  /// Extracts exterior rings from each node's geometry:
  /// - **Polygon**: one LineString (first ring = exterior)
  /// - **MultiPolygon**: one LineString per sub-polygon exterior ring
  ///
  /// World and continent level nodes are excluded. Nodes without geometry are
  /// silently skipped.
  ///
  /// Feature properties:
  /// - `admin_level` (String): e.g., `"country"`, `"state"`
  /// - `color` (String): hex color
  /// - `line_weight` (double): country → 3.0, state → 2.0, city → 1.5,
  ///   district → 1.0
  /// - `name` (String): node display name
  static String buildBoundaryLines(Map<String, LocationNode> nodes) {
    if (nodes.isEmpty) return emptyFeatureCollection;

    final features = StringBuffer();
    var first = true;

    for (final node in nodes.values) {
      if (!_renderableLevels.contains(node.adminLevel)) continue;
      final geomJson = node.geometryJson;
      if (geomJson == null) continue;

      final decoded = jsonDecode(geomJson);
      // Guard against double-encoded geometry (stored as JSON string of JSON).
      final geom = (decoded is String ? jsonDecode(decoded) : decoded)
          as Map<String, dynamic>;
      final type = geom['type'] as String;
      final coords = geom['coordinates'] as List<dynamic>;

      final color = _nodeColor(node);
      final weight = _lineWeight(node.adminLevel);
      final levelName = node.adminLevel.name;
      final escapedName = _escapeName(node.name);

      if (type == 'Polygon') {
        final ring = coords[0] as List<dynamic>;
        if (!first) features.write(',');
        first = false;
        _writeLineString(features, ring, levelName, color, weight, escapedName);
      } else if (type == 'MultiPolygon') {
        for (final polygon in coords) {
          final ring = (polygon as List<dynamic>)[0] as List<dynamic>;
          if (!first) features.write(',');
          first = false;
          _writeLineString(
              features, ring, levelName, color, weight, escapedName);
        }
      }
    }

    return '{"type":"FeatureCollection","features":[$features]}';
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Writes a single LineString Feature to [buf].
  static void _writeLineString(
    StringBuffer buf,
    List<dynamic> ring,
    String levelName,
    String color,
    double weight,
    String escapedName,
  ) {
    buf
      ..write(
          '{"type":"Feature","geometry":{"type":"LineString","coordinates":[')
      ..write(_coordsToString(ring))
      ..write(']},"properties":{')
      ..write('"admin_level":"$levelName",')
      ..write('"color":"$color",')
      ..write('"line_weight":$weight,')
      ..write('"name":"$escapedName"')
      ..write('}}');
  }

  /// Serialises a list of coordinate pairs as a JSON array of [lon, lat] pairs.
  static String _coordsToString(List<dynamic> coords) {
    final sb = StringBuffer();
    for (var i = 0; i < coords.length; i++) {
      if (i > 0) sb.write(',');
      final coord = coords[i] as List<dynamic>;
      sb.write('[${coord[0]},${coord[1]}]');
    }
    return sb.toString();
  }

  /// Fill opacity by admin level.
  static double _fillOpacity(AdminLevel level) => switch (level) {
        AdminLevel.country => 0.04,
        AdminLevel.state => 0.06,
        AdminLevel.city => 0.08,
        AdminLevel.district => 0.10,
        _ => 0.04,
      };

  /// Line weight by admin level (uses shared constants).
  static double _lineWeight(AdminLevel level) => switch (level) {
        AdminLevel.country => kBorderLineWeightCountry,
        AdminLevel.state => kBorderLineWeightState,
        AdminLevel.city => kBorderLineWeightCity,
        AdminLevel.district => kBorderLineWeightDistrict,
        _ => kBorderLineWeightDistrict,
      };

  /// Returns the display color for a [LocationNode].
  ///
  /// Uses [LocationNode.colorHex] if non-null, otherwise generates a
  /// deterministic hex color from the `osmId` (or `id` fallback) via
  /// FNV-1a 32-bit hash — identical to `TerritoryBorderGeoJsonBuilder`.
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

  /// Escapes special characters for safe embedding in a JSON string value.
  static String _escapeName(String name) => name
      .replaceAll('\\', '\\\\')
      .replaceAll('"', '\\"')
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '\\r')
      .replaceAll('\t', '\\t');
}
