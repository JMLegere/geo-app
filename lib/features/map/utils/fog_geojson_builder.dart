import 'package:geobase/geobase.dart';

import 'package:fog_of_world/core/models/fog_state.dart';

/// Builds GeoJSON strings for the MapLibre native fog overlay layers.
///
/// The fog system uses 3 GeoJSON sources rendered as MapLibre fill layers:
///
/// 1. **fog-base**: A world-covering polygon with holes cut for all non-opaque
///    cells (hidden, concealed, observed). Everything not cut remains fully
///    opaque — this covers undetected and unexplored cells.
///
/// 2. **fog-mid**: Individual polygons for cells at [FogState.hidden] and
///    [FogState.concealed] density. Rendered with partial opacity on top of
///    the transparent holes, creating a semi-transparent fog effect.
///
/// 3. **fog-restoration**: Individual polygons for observed cells with
///    restoration progress. Rendered as a green tint.
///
/// All coordinates use GeoJSON convention: **[longitude, latitude]**.
class FogGeoJsonBuilder {
  const FogGeoJsonBuilder._();

  /// Builds the "fog-base" GeoJSON: a world polygon with holes punched for
  /// every cell that is NOT fully opaque (i.e., hidden, concealed, observed).
  ///
  /// [cellStates] maps cell IDs to their current [FogState].
  /// [getBoundary] resolves a cell ID to its geographic boundary vertices.
  ///
  /// Returns a GeoJSON FeatureCollection string. The single Feature is a
  /// Polygon whose first ring is the world exterior and subsequent rings
  /// are holes for revealed cells.
  ///
  /// Cells with [FogState.undetected] or [FogState.unexplored] are NOT
  /// punched — they remain under the opaque base layer. Concealed cells
  /// get holes punched so the pre-rendered mid-fog polygon can show through.
  static String buildBaseFog({
    required Map<String, FogState> cellStates,
    required List<Geographic> Function(String cellId) getBoundary,
  }) {
    // World exterior ring (must be counter-clockwise for GeoJSON exterior).
    // Using ±180 lon, ±85.06 lat (Web Mercator limits).
    const worldRing =
        '[-180,-85.06],[180,-85.06],[180,85.06],[-180,85.06],[-180,-85.06]';

    final holes = StringBuffer();

    for (final entry in cellStates.entries) {
      final state = entry.value;
      // Only punch holes for cells that should show through the base fog.
      // Hidden (0.5), concealed (0.95), and observed (0.0) get holes.
      // Undetected and unexplored stay under opaque fog.
      if (state == FogState.undetected || state == FogState.unexplored) {
        continue;
      }

      final boundary = getBoundary(entry.key);
      if (boundary.length < 3) continue;

      holes.write(',[');
      for (var i = 0; i < boundary.length; i++) {
        if (i > 0) holes.write(',');
        holes.write('[${boundary[i].lon},${boundary[i].lat}]');
      }
      // Close the ring (GeoJSON requires first == last).
      holes.write(',[${boundary[0].lon},${boundary[0].lat}]');
      holes.write(']');
    }

    return '{"type":"FeatureCollection","features":[{"type":"Feature",'
        '"geometry":{"type":"Polygon","coordinates":[[$worldRing]$holes]},'
        '"properties":{}}]}';
  }

  /// Builds the "fog-mid" GeoJSON: individual polygons for cells at partial
  /// fog density ([FogState.hidden], [FogState.concealed], and [FogState.unexplored]).
  ///
  /// Each cell becomes a separate Feature with a `density` property so the
  /// MapLibre style can use data-driven opacity:
  /// `{'fill-opacity': ['get', 'density']}`.
  ///
  /// Unexplored cells are pre-rendered at concealed density (0.95) and hidden
  /// behind the opaque base fog. When a cell transitions to concealed, the
  /// base-fog hole is punched, revealing the already-rendered polygon.
  ///
  /// [FogState.observed] cells are excluded — they are fully clear.
  /// [FogState.undetected] is excluded — it remains under the opaque base.
  static String buildMidFog({
    required Map<String, FogState> cellStates,
    required List<Geographic> Function(String cellId) getBoundary,
  }) {
    final features = StringBuffer();
    var first = true;

    for (final entry in cellStates.entries) {
      final state = entry.value;
      // Include unexplored (pre-rendered behind base fog), concealed, and hidden.
      // Undetected and observed are excluded.
      if (state == FogState.undetected || state == FogState.observed) continue;

      final boundary = getBoundary(entry.key);
      if (boundary.length < 3) continue;

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
      // Unexplored cells use concealed density (0.95) for pre-rendering.
      final density = state == FogState.unexplored
          ? FogState.concealed.density
          : state.density;
      features.write(']]},"properties":{"density":$density}}');
    }

    return '{"type":"FeatureCollection","features":[$features]}';
  }

  /// Builds the "fog-restoration" GeoJSON: individual polygons for observed
  /// cells that have restoration progress > 0.
  ///
  /// Each Feature has a `level` property (0.0–1.0) for data-driven opacity.
  ///
  /// [restorationLevels] maps cell IDs to their restoration level.
  /// Only cells that are [FogState.observed] in [cellStates] are included.
  static String buildRestorationOverlay({
    required Map<String, FogState> cellStates,
    required Map<String, double> restorationLevels,
    required List<Geographic> Function(String cellId) getBoundary,
  }) {
    final features = StringBuffer();
    var first = true;

    for (final entry in restorationLevels.entries) {
      if (entry.value <= 0.0) continue;

      final state = cellStates[entry.key];
      if (state != FogState.observed) continue;

      final boundary = getBoundary(entry.key);
      if (boundary.length < 3) continue;

      if (!first) features.write(',');
      first = false;

      features.write('{"type":"Feature","geometry":{"type":"Polygon",'
          '"coordinates":[[');
      for (var i = 0; i < boundary.length; i++) {
        if (i > 0) features.write(',');
        features.write('[${boundary[i].lon},${boundary[i].lat}]');
      }
      features.write(',[${boundary[0].lon},${boundary[0].lat}]');
      features.write(']]},"properties":{"level":${entry.value}}}');
    }

    return '{"type":"FeatureCollection","features":[$features]}';
  }

  /// Builds the "fog-border" GeoJSON: polygon outlines for [FogState.unexplored]
  /// and [FogState.concealed] cells rendered as a [LineLayer] on top of the fog.
  ///
  /// Both states get borders with different opacity values:
  /// - **Unexplored** (0.4): within detection radius, never visited.
  /// - **Concealed** (0.25): adjacent to an observed cell, barely visible.
  ///
  /// Each Feature has an `opacity` property for data-driven `line-opacity`.
  /// Undetected, hidden, and observed cells are excluded.
  static String buildCellBorders({
    required Map<String, FogState> cellStates,
    required List<Geographic> Function(String cellId) getBoundary,
  }) {
    final features = StringBuffer();
    var first = true;

    for (final entry in cellStates.entries) {
      final double opacity;
      switch (entry.value) {
        case FogState.unexplored:
          opacity = 0.4;
        case FogState.concealed:
          opacity = 0.25;
        default:
          continue;
      }

      final boundary = getBoundary(entry.key);
      if (boundary.length < 3) continue;

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
      features.write(']]},"properties":{"opacity":$opacity}}');
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
