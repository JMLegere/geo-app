import 'dart:async';

import 'package:earth_nova/core/cells/cell_service.dart';
import 'package:earth_nova/core/models/hierarchy.dart';
import 'package:earth_nova/core/persistence/hierarchy_repository.dart';
import 'package:earth_nova/core/services/observability_buffer.dart';
import 'package:flutter/foundation.dart';

/// Radius-based detection zone centered on the player position.
///
/// The detection zone is the set of cells within [_ringCount] Voronoi rings
/// of the player's current cell. All cells in this zone have fog computed,
/// species caches warmed, and cell properties resolved.
///
/// District assignment is computed via nearest-centroid matching against
/// the hierarchy tables (not GeoJSON polygon scanning).
class DetectionZoneService {
  final CellService _cellService;
  final HierarchyRepository _hierarchyRepo;

  /// Number of Voronoi rings from the player cell. ~180m per ring.
  /// 15 rings ≈ 2.7km radius — covers a good walking area.
  static const int _ringCount = 15;

  /// Current detection zone cell IDs.
  Set<String> _detectionZoneCellIds = {};

  /// Maps cell ID → district ID for all cells in the current zone.
  Map<String, String> _cellDistrictAttribution = {};

  /// Current district ID (district containing the player).
  String? _currentDistrictId;

  /// The cell ID the zone is currently centered on.
  /// Used to avoid recomputing when the player hasn't moved to a new cell.
  String? _centeredOnCellId;

  /// Cached district centroids for nearest-centroid matching.
  List<HDistrict>? _districtCache;

  /// Stream that fires when the detection zone changes.
  final StreamController<Set<String>> _zoneChangedController =
      StreamController<Set<String>>.broadcast();

  DetectionZoneService({
    required CellService cellService,
    required HierarchyRepository hierarchyRepo,
  })  : _cellService = cellService,
        _hierarchyRepo = hierarchyRepo;

  // ── Public API ──────────────────────────────────────────────────────────

  /// Current detection zone cell IDs. Empty before first position update.
  Set<String> get detectionZoneCellIds =>
      Set.unmodifiable(_detectionZoneCellIds);

  /// Current district location ID, or null if not determined.
  String? get currentDistrictId => _currentDistrictId;

  /// District attribution for all zone cells (cellId → districtId).
  Map<String, String> get cellDistrictAttribution =>
      Map.unmodifiable(_cellDistrictAttribution);

  /// Stream that fires when the detection zone changes.
  Stream<Set<String>> get onDetectionZoneChanged =>
      _zoneChangedController.stream;

  /// Updates the detection zone based on the player's current position.
  ///
  /// Computes cells within [_ringCount] rings of the player cell.
  /// Only recomputes if the player has moved to a different cell.
  /// Also assigns each cell to its nearest district centroid.
  Future<void> updatePlayerPosition(double lat, double lon) async {
    final currentCellId = _cellService.getCellId(lat, lon);

    // Skip if player hasn't moved to a new cell.
    if (currentCellId == _centeredOnCellId) return;
    _centeredOnCellId = currentCellId;

    final sw = Stopwatch()..start();

    // Expand zone from player cell.
    final zoneCells = <String>{};
    for (var k = 0; k <= _ringCount; k++) {
      zoneCells.addAll(_cellService.getCellsInRing(currentCellId, k));
    }

    // Load district centroids (cached after first load).
    _districtCache ??= await _loadAllDistricts();

    // Assign each cell to nearest district centroid.
    final attribution = <String, String>{};
    if (_districtCache!.isNotEmpty) {
      for (final cellId in zoneCells) {
        final center = _cellService.getCellCenter(cellId);
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
          attribution[cellId] = nearestId;
        }
      }
    }

    // Determine player's district.
    final playerDistrict = attribution[currentCellId];

    sw.stop();
    debugPrint(
        '[DetectionZone] radius=$_ringCount zone=${zoneCells.length} cells, '
        'district=$playerDistrict '
        '(${sw.elapsedMilliseconds}ms)');
    ObservabilityBuffer.instance?.event('detection_zone_changed', {
      'zone_size': zoneCells.length,
      'district_id': playerDistrict,
      'ring_count': _ringCount,
      'duration_ms': sw.elapsedMilliseconds,
    });

    _currentDistrictId = playerDistrict;
    _cellDistrictAttribution = attribution;
    _detectionZoneCellIds = zoneCells;
    if (!_zoneChangedController.isClosed) {
      _zoneChangedController.add(Set.unmodifiable(zoneCells));
    }
  }

  /// Forces a zone recomputation even if the player hasn't moved cells.
  /// Used when hierarchy data arrives after the initial computation.
  Future<void> recomputeCurrentZone() async {
    _centeredOnCellId = null; // Clear to bypass dedup
    _districtCache = null; // Reload districts
    // Re-derive position from the existing zone center if available.
    // If no zone yet, this is a no-op.
    if (_detectionZoneCellIds.isNotEmpty) {
      final center = _cellService.getCellCenter(_detectionZoneCellIds.first);
      await updatePlayerPosition(center.lat, center.lon);
    }
  }

  /// Releases the stream controller.
  void dispose() {
    _zoneChangedController.close();
  }

  // ── Private ─────────────────────────────────────────────────────────────

  /// Loads all districts from all cities from all states from all countries.
  Future<List<HDistrict>> _loadAllDistricts() async {
    final allDistricts = <HDistrict>[];
    try {
      final countries = await _hierarchyRepo.getAllCountries();
      for (final country in countries) {
        final states = await _hierarchyRepo.getStatesForCountry(country.id);
        for (final state in states) {
          final cities = await _hierarchyRepo.getCitiesForState(state.id);
          for (final city in cities) {
            final districts = await _hierarchyRepo.getDistrictsForCity(city.id);
            allDistricts.addAll(districts);
          }
        }
      }
      debugPrint('[DetectionZone] loaded ${allDistricts.length} districts');
    } catch (e) {
      debugPrint('[DetectionZone] failed to load districts: $e');
    }
    return allDistricts;
  }
}
