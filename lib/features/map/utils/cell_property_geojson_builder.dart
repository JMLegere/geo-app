import 'package:geobase/geobase.dart' show Geographic;

import 'package:earth_nova/core/cells/event_resolver.dart';
import 'package:earth_nova/core/models/cell_event.dart';
import 'package:earth_nova/core/models/cell_properties.dart';
import 'package:earth_nova/core/models/fog_state.dart';
import 'package:earth_nova/features/map/utils/map_icon_renderer.dart';

/// Builds GeoJSON Point FeatureCollections for cell property icons on the map.
///
/// ## Icon Visibility Rules
///
/// | Cell state                      | Shows                                          |
/// |---------------------------------|------------------------------------------------|
/// | Current cell with event         | Event icon only (centered)                      |
/// | Current cell without event      | No icons                                        |
/// | Visited cell with event         | Event icon only (centered)                      |
/// | Visited cell without event      | No icons                                        |
/// | Adjacent cell with event        | "?" icon (Witcher 3 style)                      |
/// | Adjacent cell without event     | No icons                                        |
/// | Unvisited non-adjacent          | No icons                                        |
///
/// All coordinates are `[longitude, latitude]` (GeoJSON convention).
class CellPropertyGeoJsonBuilder {
  const CellPropertyGeoJsonBuilder._();

  /// Builds a GeoJSON FeatureCollection of Point features for cell property icons.
  ///
  /// [cellStates] maps cell IDs to their current fog state.
  /// [cellProperties] maps cell IDs to their resolved properties.
  /// [currentCellId] is the player's current cell.
  /// [adjacentCellIds] are the neighbors of the current cell.
  /// [visitedCellIds] are all previously visited cells.
  /// [dailySeed] is used to compute cell events.
  /// [getCellCenter] resolves a cell ID to its center coordinate.
  static String buildCellIcons({
    required Map<String, FogState> cellStates,
    required Map<String, CellProperties> cellProperties,
    required String? currentCellId,
    required Set<String> adjacentCellIds,
    required Set<String> visitedCellIds,
    required String dailySeed,
    required Geographic Function(String cellId) getCellCenter,
  }) {
    final features = StringBuffer();
    var first = true;

    for (final entry in cellProperties.entries) {
      final cellId = entry.key;
      final props = entry.value;
      final fogState = cellStates[cellId];

      // Only show icons for cells that are at least concealed.
      if (fogState == null ||
          fogState == FogState.undetected ||
          fogState == FogState.unexplored) {
        continue;
      }

      final isCurrent = cellId == currentCellId;
      final isAdjacent = adjacentCellIds.contains(cellId);
      final isVisited = visitedCellIds.contains(cellId);
      final center = getCellCenter(cellId);

      // Resolve the event for this cell (deterministic, ~12% chance).
      final event = EventResolver.resolve(dailySeed, cellId);

      // Determine which icons to show based on cell state.
      final icons = _resolveIcons(
        props: props,
        event: event,
        isCurrent: isCurrent,
        isAdjacent: isAdjacent,
        isVisited: isVisited,
        fogState: fogState,
      );

      // Emit a Point feature for each icon at the cell center.
      for (final icon in icons) {
        if (!first) features.write(',');
        first = false;

        features.write('{"type":"Feature","geometry":{"type":"Point",'
            '"coordinates":[${center.lon},${center.lat}]},'
            '"properties":{"icon":"${icon.iconId}",'
            '"offset":[${icon.dx},${icon.dy}]}}');
      }
    }

    return '{"type":"FeatureCollection","features":[$features]}';
  }

  /// Determines which icons to display for a cell based on its state.
  static List<_IconPlacement> _resolveIcons({
    required CellProperties props,
    required CellEvent? event,
    required bool isCurrent,
    required bool isAdjacent,
    required bool isVisited,
    required FogState fogState,
  }) {
    final icons = <_IconPlacement>[];

    // Current or visited cell: show event icon only (centered) if present.
    final showFullGrid = isCurrent || isVisited;

    if (showFullGrid) {
      // Event icon (centered) if present.
      if (event != null) {
        icons.add(_IconPlacement(
          iconId: MapIconRenderer.eventIconId(event.type.name),
          offsetX: 0.0,
          offsetY: 0.0,
        ));
      }
    } else if (isAdjacent) {
      // Adjacent but not visited: show "?" icon if event present.
      if (event != null) {
        icons.add(_IconPlacement(
          iconId: MapIconRenderer.eventUnknownId,
          offsetX: 0.0,
          offsetY: 0.0,
        ));
      }
    }
    // Concealed but not adjacent and not visited: show nothing (still fogged).

    return icons;
  }

  /// Returns an empty GeoJSON FeatureCollection.
  static String get emptyFeatureCollection =>
      '{"type":"FeatureCollection","features":[]}';
}

/// Internal placement record for an icon within a cell.
class _IconPlacement {
  /// Registered image ID (e.g., "habitat-forest", "event-migration").
  final String iconId;

  /// Horizontal offset in icon-size units from cell center.
  /// -0.5 = left, 0 = center, 0.5 = right.
  final double offsetX;

  /// Vertical offset in icon-size units from cell center.
  /// -0.5 = top, 0 = center, 0.5 = bottom.
  final double offsetY;

  const _IconPlacement({
    required this.iconId,
    required this.offsetX,
    required this.offsetY,
  });

  /// Pre-multiplied pixel offset for MapLibre `icon-offset` (offsetX * 80).
  double get dx => offsetX * 80;

  /// Pre-multiplied pixel offset for MapLibre `icon-offset` (offsetY * 80).
  double get dy => offsetY * 80;
}
