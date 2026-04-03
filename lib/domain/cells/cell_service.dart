import 'package:geobase/geobase.dart';

/// Abstract interface for spatial cell systems.
///
/// Implementations may use H3 hexagons, Voronoi tessellation, or any other
/// spatial indexing scheme. All game logic depends on this interface — never
/// on a specific implementation.
abstract interface class CellService {
  /// Returns the cell ID containing the given geographic coordinate.
  String getCellId(double lat, double lon);

  /// Returns the center geographic coordinate of the given cell.
  Geographic getCellCenter(String cellId);

  /// Returns the polygon boundary vertices of the cell (for rendering).
  /// The list is ordered (e.g. clockwise) and does NOT repeat the first vertex.
  List<Geographic> getCellBoundary(String cellId);

  /// Returns the IDs of cells adjacent to the given cell.
  /// For H3: 6 neighbors (hex ring k=1, excluding center).
  /// For Voronoi: variable count.
  List<String> getNeighborIds(String cellId);

  /// Returns all cell IDs within [k] rings of the given cell.
  /// k=0 returns just the cell itself.
  /// k=1 returns the cell + immediate neighbors.
  List<String> getCellsInRing(String cellId, int k);

  /// Returns all cell IDs within [k] rings of the given coordinate.
  /// Convenience method: resolves coordinate to cell, then calls getCellsInRing.
  List<String> getCellsAroundLocation(double lat, double lon, int k);

  /// Returns the approximate edge length of a cell in meters.
  /// Used for UI display and distance calculations.
  double get cellEdgeLengthMeters;

  /// Returns a human-readable name for the cell system (e.g. "H3 (res 9)").
  String get systemName;
}
