import 'package:h3_flutter_plus/h3_flutter_plus.dart';

/// Spike implementation wrapping h3_flutter_plus for hexagonal cell grids.
///
/// Uses H3 resolution 9 (~174m edge length, ~0.1 km² area per cell).
/// Cell IDs are BigInt hex strings (e.g. "8928308280fffff").
///
/// Mapping to CellData: cell ID → CellData.id, center lat/lon → Geographic(lat, lon).
class H3CellService {
  final int resolution;
  final H3 _h3;

  H3CellService({this.resolution = 9}) : _h3 = H3Factory().load();

  /// Converts a lat/lon to an H3 cell ID (hex string of BigInt).
  String getCellId(double lat, double lon) {
    final cellId =
        _h3.latLngToCell(LatLng(lat: lat, lng: lon), resolution);
    return cellId.toRadixString(16);
  }

  /// Returns the center lat/lon of the cell with the given hex ID.
  (double lat, double lon) getCellCenter(String cellId) {
    final center = _h3.cellToLatLng(_parseCellId(cellId));
    return (center.lat, center.lng);
  }

  /// Returns the polygon boundary vertices of the cell as (lat, lon) pairs.
  List<(double lat, double lon)> getCellBoundary(String cellId) {
    final boundary = _h3.cellToBoundary(_parseCellId(cellId));
    return boundary.map((v) => (v.lat, v.lng)).toList();
  }

  /// Returns all cell IDs in a k-ring around the given cell.
  /// k=1 returns 7 cells (center + 6 hex neighbors).
  List<String> getNeighbors(String cellId, {int k = 1}) {
    final neighbors = _h3.gridDisk(_parseCellId(cellId), k);
    return neighbors.map((id) => id.toRadixString(16)).toList();
  }

  /// Returns all cell IDs within a k-ring radius of a lat/lon point.
  List<String> getCellsInRadius(double lat, double lon, int k) {
    final originId = getCellId(lat, lon);
    return getNeighbors(originId, k: k);
  }

  /// Returns the resolution of a cell ID.
  int getResolution(String cellId) {
    return _h3.getResolution(_parseCellId(cellId));
  }

  BigInt _parseCellId(String cellId) => BigInt.parse(cellId, radix: 16);
}
