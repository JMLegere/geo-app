import 'dart:async';
import 'package:earth_nova/domain/cells/cell_service.dart';

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
  String? _centeredOnCellId;

  final StreamController<Set<String>> _zoneChangedController =
      StreamController<Set<String>>.broadcast();

  DetectionZoneService({required CellService cellService})
      : _cellService = cellService;

  /// Current detection zone cell IDs. Empty before first position update.
  Set<String> get zoneCellIds => Set.unmodifiable(_zoneCellIds);

  /// Stream that fires when the detection zone changes.
  Stream<Set<String>> get onZoneChanged => _zoneChangedController.stream;

  /// The cell ID the zone is currently centered on.
  String? get centeredOnCellId => _centeredOnCellId;

  /// Updates the detection zone for the player's current position.
  /// Only recomputes if the player moved to a different cell.
  void updatePlayerPosition(double lat, double lon) {
    final cellId = _cellService.getCellId(lat, lon);
    if (cellId == _centeredOnCellId) return;
    _centeredOnCellId = cellId;

    final zoneCells = <String>{};
    for (var k = 0; k <= ringCount; k++) {
      zoneCells.addAll(_cellService.getCellsInRing(cellId, k));
    }

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
    final center = _cellService.getCellCenter(cellId);
    updatePlayerPosition(center.lat, center.lon);
  }

  void dispose() {
    _zoneChangedController.close();
  }
}
