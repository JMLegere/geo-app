import 'package:flutter/foundation.dart';
import 'package:geobase/geobase.dart';

import 'package:earth_nova/core/models/fog_state.dart';

/// Builds GeoJSON strings for the MapLibre native fog overlay layers.
///
/// The fog system uses 3 GeoJSON sources rendered as MapLibre fill layers:
///
/// 1. **fog-base**: A world-covering polygon with holes cut for nearby/explored/
///    current cells. Everything not cut remains fully opaque — this covers
///    unknown and detected cells (detected is pre-rendered under the base).
///
/// 2. **fog-mid**: Individual polygons for cells at [FogState.explored] and
///    [FogState.nearby] density. Rendered with partial opacity on top of
///    the transparent holes, creating a semi-transparent fog effect.
///
/// 3. **fog-border**: Polygon outlines for unexplored and concealed cells.
///
/// All coordinates use GeoJSON convention: **[longitude, latitude]**.
class FogGeoJsonBuilder {
  const FogGeoJsonBuilder._();

  static int _baseFogLogCounter = 0;
  static int _midFogLogCounter = 0;
  static int _cellBordersLogCounter = 0;

  /// Builds the "fog-base" GeoJSON: a world polygon with holes punched for
  /// every cell that is NOT fully opaque (i.e., explored, nearby, current).
  ///
  /// [cellStates] maps cell IDs to their current [FogState].
  /// [getBoundary] resolves a cell ID to its geographic boundary vertices.
  ///
  /// Returns a GeoJSON FeatureCollection string. The single Feature is a
  /// Polygon whose first ring is the world exterior and subsequent rings
  /// are holes for revealed cells.
  ///
  /// Only [FogState.unknown] cells are NOT punched — they remain under the
  /// opaque base layer. All other states (detected, nearby, explored, present)
  /// get holes so the mid-fog polygon or base map shows through.
  static String buildBaseFog({
    required Map<String, FogState> cellStates,
    required List<Geographic> Function(String cellId) getBoundary,
    String Function(String cellId)? getFragment,
  }) {
    // World exterior ring (must be counter-clockwise for GeoJSON exterior).
    // Using ±180 lon, ±85.06 lat (Web Mercator limits).
    const worldRing =
        '[-180,-85.06],[180,-85.06],[180,85.06],[-180,85.06],[-180,-85.06]';

    final holes = StringBuffer();
    var holeCount = 0;

    for (final entry in cellStates.entries) {
      final state = entry.value;
      // Punch holes for ALL non-unknown cells so they show through base fog.
      // Detected (district zone), nearby, explored, and present all get holes.
      if (state == FogState.unknown) {
        continue;
      }

      holeCount++;
      if (getFragment != null) {
        holes.write(',');
        holes.write(getFragment(entry.key));
      } else {
        final boundary = getBoundary(entry.key);
        if (boundary.length < 3) {
          holeCount--;
          continue;
        }
        holes.write(',[');
        for (var i = 0; i < boundary.length; i++) {
          if (i > 0) holes.write(',');
          holes.write('[${boundary[i].lon},${boundary[i].lat}]');
        }
        // Close the ring (GeoJSON requires first == last).
        holes.write(',[${boundary[0].lon},${boundary[0].lat}]');
        holes.write(']');
      }
    }

    if (++_baseFogLogCounter % 100 == 1) {
      debugPrint(
          '[FOG-GEO] base: $holeCount holes from ${cellStates.length} cells');
    }

    return '{"type":"FeatureCollection","features":[{"type":"Feature",'
        '"geometry":{"type":"Polygon","coordinates":[[$worldRing]$holes]},'
        '"properties":{}}]}';
  }

  /// Builds the "fog-mid" GeoJSON: individual polygons for cells at partial
  /// fog density ([FogState.explored], [FogState.nearby], and [FogState.detected]).
  ///
  /// Each cell becomes a separate Feature with a `density` property so the
  /// MapLibre style can use data-driven opacity:
  /// `{'fill-opacity': ['get', 'density']}`.
  ///
  /// Detected cells render at their own density (0.97) — nearly opaque but
  /// territory borders and base map peek through, showing the district shape.
  ///
  /// [FogState.present] cells are excluded — they are fully clear.
  /// [FogState.unknown] is excluded — it remains under the opaque base.
  static String buildMidFog({
    required Map<String, FogState> cellStates,
    required List<Geographic> Function(String cellId) getBoundary,
    String Function(String cellId)? getFragment,
  }) {
    final features = StringBuffer();
    var first = true;
    var featureCount = 0;

    for (final entry in cellStates.entries) {
      final state = entry.value;
      // Include detected (pre-rendered behind base fog), nearby, and explored.
      // Unknown and current are excluded.
      if (state == FogState.unknown || state == FogState.present) continue;

      if (getFragment != null) {
        if (!first) features.write(',');
        first = false;
        featureCount++;
        features.write('{"type":"Feature","geometry":{"type":"Polygon",'
            '"coordinates":[');
        features.write(getFragment(entry.key));
        final density = state.density;
        features.write(']},"properties":{"density":$density}}');
      } else {
        final boundary = getBoundary(entry.key);
        if (boundary.length < 3) continue;
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
        final density = state.density;
        features.write(']]},"properties":{"density":$density}}');
      }
    }

    if (++_midFogLogCounter % 100 == 1) {
      debugPrint(
          '[FOG-GEO] mid: $featureCount features from ${cellStates.length} cells');
    }

    return '{"type":"FeatureCollection","features":[$features]}';
  }

  /// Builds the "fog-border" GeoJSON: polygon outlines for [FogState.detected]
  /// and [FogState.nearby] cells rendered as a [LineLayer] on top of the fog.
  ///
  /// Both states get borders with different opacity values:
  /// - **Detected** (0.4): within detection radius, never visited.
  /// - **Nearby** (0.25): adjacent to a current cell, barely visible.
  ///
  /// Each Feature has an `opacity` property for data-driven `line-opacity`.
  /// Unknown, explored, and current cells are excluded.
  static String buildCellBorders({
    required Map<String, FogState> cellStates,
    required List<Geographic> Function(String cellId) getBoundary,
    String Function(String cellId)? getFragment,
  }) {
    final features = StringBuffer();
    var first = true;
    var featureCount = 0;

    for (final entry in cellStates.entries) {
      final double opacity;
      switch (entry.value) {
        case FogState.detected:
          opacity = 0.4;
        case FogState.nearby:
          opacity = 0.25;
        case FogState.unknown:
          // Detection zone cells that haven't been explored yet.
          // Subtle border so the district grid is visible under fog.
          opacity = 0.1;
        default:
          continue;
      }

      if (getFragment != null) {
        if (!first) features.write(',');
        first = false;
        featureCount++;
        features.write('{"type":"Feature","geometry":{"type":"Polygon",'
            '"coordinates":[');
        features.write(getFragment(entry.key));
        features.write(']},"properties":{"opacity":$opacity}}');
      } else {
        final boundary = getBoundary(entry.key);
        if (boundary.length < 3) continue;
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
        features.write(']]},"properties":{"opacity":$opacity}}');
      }
    }

    if (++_cellBordersLogCounter % 100 == 1) {
      debugPrint(
          '[FOG-GEO] borders: $featureCount features from ${cellStates.length} cells');
    }

    return '{"type":"FeatureCollection","features":[$features]}';
  }

  /// Returns an empty GeoJSON FeatureCollection.
  static String get emptyFeatureCollection =>
      '{"type":"FeatureCollection","features":[]}';

  /// Returns the base fog GeoJSON with no holes (full world coverage).
  static String get fullWorldFog {
    const worldRing =
        '[-180,-85.06],[180,-85.06],[180,85.06],[-180,85.06],[-180,-85.06]';
    return '{"type":"FeatureCollection","features":[{"type":"Feature",'
        '"geometry":{"type":"Polygon","coordinates":[[$worldRing]]},'
        '"properties":{}}]}';
  }
}
