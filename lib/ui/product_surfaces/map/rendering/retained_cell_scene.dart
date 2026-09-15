import 'package:flutter/foundation.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/ui/product_surfaces/map/rendering/cell_tessellation_render_model.dart';

/// Geographic geometry crosses the web bridge only when the working set changes.
/// Knowledge is independent of geometry; the native renderer diffs feature state.
class RetainedCellScene {
  Map<String, GeoMultiPolygon>? _geometry;

  /// A replacement native map has no retained geometry, even for the same Cells.
  void reset() => _geometry = null;

  Map<String, Object?> update(
    List<CellStateEntry> entries, {
    List<Map<String, Object?>> venues = const [],
  }) {
    final cells = [
      for (final entry in entries)
        if (entry.cell.hasRenderableGeometry) entry,
    ];
    final old = _geometry;
    final changed =
        old == null ||
        old.length != cells.length ||
        cells.any((entry) {
          final previous = old[entry.cell.id];
          final next = entry.cell.polygons;
          if (identical(previous, next)) return false;
          if (previous == null || previous.length != next.length) return true;
          for (var p = 0; p < next.length; p++) {
            if (previous[p].length != next[p].length) return true;
            for (var r = 0; r < next[p].length; r++) {
              if (!listEquals(previous[p][r], next[p][r])) return true;
            }
          }
          return false;
        });
    if (changed) {
      _geometry = {
        for (final entry in cells) entry.cell.id: entry.cell.polygons,
      };
    }
    return {
      'geometry': changed
          ? {
              'type': 'FeatureCollection',
              'features': [
                for (final entry in cells)
                  {
                    'type': 'Feature',
                    'id': entry.cell.id,
                    'properties': <String, Object?>{},
                    'geometry': {
                      'type': 'MultiPolygon',
                      'coordinates': [
                        for (final polygon in entry.cell.polygons)
                          if (polygon.isNotEmpty && polygon.first.length >= 3)
                            [
                              for (final ring in polygon)
                                if (ring.length >= 3) _ring(ring),
                            ],
                      ],
                    },
                  },
              ],
            }
          : null,
      'states': [
        for (final entry in cells)
          {
            'id': entry.cell.id,
            'knowledge': entry.state.knowledgeState.name,
            'relationship': entry.state.relationship.name,
            'category': entry.state.category,
            'cue': entry.state.knowledgeState == CellKnowledgeState.informed
                ? entry.state.category
                : null,
          },
      ],
      'venues': venues,
    };
  }

  static List<List<double>> _ring(GeoRing ring) => [
    for (final point in ring) [point.lng, point.lat],
    if (ring.first != ring.last) [ring.first.lng, ring.first.lat],
  ];
}
