import 'package:geobase/geobase.dart';

import 'package:earth_nova/core/models/cell_properties.dart';
import 'package:earth_nova/core/models/fog_state.dart';
import 'package:earth_nova/core/models/habitat.dart';

/// Builds GeoJSON strings for a radial gradient habitat fill overlay.
///
/// Each eligible cell (observed, hidden, or concealed) gets 3 concentric ring
/// polygons that simulate a radial gradient fill using the averaged colour of
/// the cell's habitats:
///
/// | Ring | Scale | Opacity |
/// |------|-------|---------|
/// |  0   |  1.00 |  0.07   |
/// |  1   |  0.75 |  0.04   |
/// |  2   |  0.50 |  0.02   |
///
/// Ring 3 (scale 0.25, opacity 0.00) is skipped — invisible.
///
/// All coordinates use GeoJSON convention: **[longitude, latitude]**.
class HabitatFillGeoJsonBuilder {
  const HabitatFillGeoJsonBuilder._();

  static const String emptyFeatureCollection =
      '{"type":"FeatureCollection","features":[]}';

  /// Builds the habitat fill GeoJSON FeatureCollection.
  ///
  /// [cellProperties] maps cell IDs to their resolved [CellProperties].
  /// [cellStates] maps cell IDs to their current [FogState].
  /// [getCellBoundary] resolves a cell ID to its geographic boundary vertices.
  ///
  /// Only cells in [FogState.present], [FogState.explored], or
  /// [FogState.nearby] that also have an entry in [cellProperties] are
  /// rendered. Undetected and unexplored cells are skipped.
  ///
  /// Returns a GeoJSON FeatureCollection string. Each eligible cell contributes
  /// 3 Polygon Features (one per ring) with `color` and `opacity` properties.
  static String buildHabitatFills({
    required Map<String, CellProperties> cellProperties,
    required Map<String, FogState> cellStates,
    required List<Geographic> Function(String cellId) getCellBoundary,
  }) {
    final features = StringBuffer();
    var first = true;

    for (final entry in cellStates.entries) {
      final state = entry.value;

      // Only render for cells the player has some awareness of.
      if (state == FogState.unknown || state == FogState.detected) {
        continue;
      }

      final cell = cellProperties[entry.key];
      if (cell == null) continue;

      final boundary = getCellBoundary(entry.key);
      if (boundary.length < 3) continue;

      // Average the habitat colours into a single fill colour.
      final color = _averageHabitatColor(cell.habitats);

      // Compute the polygon centroid as the average of all vertex positions.
      var latSum = 0.0;
      var lonSum = 0.0;
      for (final v in boundary) {
        latSum += v.lat;
        lonSum += v.lon;
      }
      final centroidLat = latSum / boundary.length;
      final centroidLon = lonSum / boundary.length;

      // Emit 3 rings: outer (most opaque) → inner (least opaque).
      const ringDefs = [
        (scale: 1.00, opacity: 0.07),
        (scale: 0.75, opacity: 0.04),
        (scale: 0.50, opacity: 0.02),
      ];

      for (final ring in ringDefs) {
        if (!first) features.write(',');
        first = false;

        features.write('{"type":"Feature","geometry":{"type":"Polygon",'
            '"coordinates":[[');

        for (var i = 0; i < boundary.length; i++) {
          if (i > 0) features.write(',');
          final v = boundary[i];
          final lat = centroidLat + ring.scale * (v.lat - centroidLat);
          final lon = centroidLon + ring.scale * (v.lon - centroidLon);
          features.write('[$lon,$lat]');
        }

        // Close the ring — GeoJSON requires first vertex repeated as last.
        final v0 = boundary[0];
        final closeLat = centroidLat + ring.scale * (v0.lat - centroidLat);
        final closeLon = centroidLon + ring.scale * (v0.lon - centroidLon);
        features.write(',[$closeLon,$closeLat]');

        features.write(']]},');
        features.write(
            '"properties":{"color":"$color","opacity":${ring.opacity}}}');
      }
    }

    return '{"type":"FeatureCollection","features":[$features]}';
  }

  /// Parses each habitat's `#RRGGBB` hex colour, averages the R/G/B channels
  /// across all habitats, and returns the result as a `#RRGGBB` string.
  static String _averageHabitatColor(Set<Habitat> habitats) {
    var rSum = 0;
    var gSum = 0;
    var bSum = 0;

    for (final habitat in habitats) {
      final hex = habitat.colorHex; // always '#RRGGBB'
      rSum += int.parse(hex.substring(1, 3), radix: 16);
      gSum += int.parse(hex.substring(3, 5), radix: 16);
      bSum += int.parse(hex.substring(5, 7), radix: 16);
    }

    final count = habitats.length;
    final r = (rSum / count).round();
    final g = (gSum / count).round();
    final b = (bSum / count).round();

    return '#'
        '${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}';
  }
}
