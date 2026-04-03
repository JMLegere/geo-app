import 'dart:async';
import 'package:earth_nova/domain/cells/cell_service.dart';
import 'package:earth_nova/models/hierarchy.dart';

/// Radius-based detection zone centered on the player position.
///
/// The detection zone is the set of cells within [ringCount] Voronoi rings
/// of the player's current cell. All cells in this zone have fog computed
/// by the FogOverlayController.
///
/// ~180m per ring. 15 rings ≈ 2.7km radius — covers a good walking area.
class DetectionZoneService {
  final CellService _cellService;

  /// Number of Voronoi rings. 15 rings ≈ 2.7km.
  static const int ringCount = 15;

  Set<String> _zoneCellIds = {};
  Map<String, String> _cellDistrictAttribution = {};
  String? _currentDistrictId;
  String? _centeredOnCellId;
  List<HDistrict>? _districtCache;

  final StreamController<Set<String>> _zoneChangedController =
      StreamController<Set<String>>.broadcast();

  /// Callback to load districts from the repository (injected to keep service pure).
  Future<List<HDistrict>> Function()? districtLoader;

  DetectionZoneService({required CellService cellService})
      : _cellService = cellService;

  /// Current detection zone cell IDs. Empty before first position update.
  Set<String> get zoneCellIds => Set.unmodifiable(_zoneCellIds);

  /// Maps cell ID → district ID for all cells in the current zone.
  Map<String, String> get cellDistrictAttribution =>
      Map.unmodifiable(_cellDistrictAttribution);

  /// The district ID the player's current cell belongs to, if any.
  String? get currentDistrictId => _currentDistrictId;

  /// Stream that fires when the detection zone changes.
  Stream<Set<String>> get onZoneChanged => _zoneChangedController.stream;

  /// The cell ID the zone is currently centered on.
  String? get centeredOnCellId => _centeredOnCellId;

  /// Updates the detection zone for the player's current position.
  /// Only recomputes if the player moved to a different cell.
  /// May load districts from [districtLoader] on first call (cached thereafter).
  Future<void> updatePlayerPosition(double lat, double lon) async {
    final cellId = _cellService.getCellId(lat, lon);
    if (cellId == _centeredOnCellId) return;
    _centeredOnCellId = cellId;

    // Expand zone from player cell
    final zoneCells = <String>{};
    for (var k = 0; k <= ringCount; k++) {
      zoneCells.addAll(_cellService.getCellsInRing(cellId, k));
    }

    // District attribution via nearest-centroid
    if (_districtCache == null && districtLoader != null) {
      try {
        _districtCache = await districtLoader!();
      } catch (_) {
        _districtCache = [];
      }
    }

    final attribution = <String, String>{};
    if (_districtCache != null && _districtCache!.isNotEmpty) {
      for (final zCellId in zoneCells) {
        final center = _cellService.getCellCenter(zCellId);
        String? nearestId;
        double nearestDist = double.infinity;
        for (final district in _districtCache!) {
          final dLat = center.lat - district.centroidLat;
          final dLon = center.lon - district.centroidLon;
          final dist = dLat * dLat + dLon * dLon;
          if (dist < nearestDist) {
            nearestDist = dist;
            nearestId = district.id;
          }
        }
        if (nearestId != null) {
          attribution[zCellId] = nearestId;
        }
      }
    }

    _currentDistrictId = attribution[cellId];
    _cellDistrictAttribution = attribution;
    _zoneCellIds = zoneCells;
    if (!_zoneChangedController.isClosed) {
      _zoneChangedController.add(Set.unmodifiable(zoneCells));
    }
  }

  /// Forces a zone recomputation even if the player hasn't moved cells.
  void recompute() {
    final cellId = _centeredOnCellId;
    if (cellId == null) return;
    _centeredOnCellId = null; // Clear to bypass dedup
    _districtCache = null; // Force district reload
    final center = _cellService.getCellCenter(cellId);
    updatePlayerPosition(center.lat, center.lon);
  }

  void dispose() {
    _zoneChangedController.close();
  }
}
