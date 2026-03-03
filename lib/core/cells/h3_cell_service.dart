import 'package:geobase/geobase.dart';
import 'package:h3_flutter_plus/h3_flutter_plus.dart';

import 'cell_service.dart';

/// H3 hexagonal cell grid implementation of [CellService].
///
/// Uses H3 resolution 9 (~174m edge length, ~0.1 km² area per cell).
/// Cell IDs are hex strings of the BigInt H3 index
/// (e.g. "8928308280fffff").
class H3CellService implements CellService {
  final int resolution;
  final H3 _h3;

  H3CellService({this.resolution = 9}) : _h3 = H3Factory().load();

  @override
  String getCellId(double lat, double lon) {
    final cellId = _h3.latLngToCell(LatLng(lat: lat, lng: lon), resolution);
    return cellId.toRadixString(16);
  }

  @override
  Geographic getCellCenter(String cellId) {
    final center = _h3.cellToLatLng(_parseCellId(cellId));
    return Geographic(lat: center.lat, lon: center.lng);
  }

  @override
  List<Geographic> getCellBoundary(String cellId) {
    final boundary = _h3.cellToBoundary(_parseCellId(cellId));
    return boundary.map((v) => Geographic(lat: v.lat, lon: v.lng)).toList();
  }

  @override
  List<String> getNeighborIds(String cellId) {
    final disk = _h3.gridDisk(_parseCellId(cellId), 1);
    final centerBigInt = _parseCellId(cellId);
    return disk
        .where((id) => id != centerBigInt)
        .map((id) => id.toRadixString(16))
        .toList();
  }

  @override
  List<String> getCellsInRing(String cellId, int k) {
    final disk = _h3.gridDisk(_parseCellId(cellId), k);
    return disk.map((id) => id.toRadixString(16)).toList();
  }

  @override
  List<String> getCellsAroundLocation(double lat, double lon, int k) {
    final cellId = getCellId(lat, lon);
    return getCellsInRing(cellId, k);
  }

  @override
  double get cellEdgeLengthMeters => 174.0;

  @override
  String get systemName => 'H3 (res 9)';

  BigInt _parseCellId(String cellId) => BigInt.parse(cellId, radix: 16);
}
