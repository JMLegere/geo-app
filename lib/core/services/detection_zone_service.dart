import 'dart:async';
import 'dart:convert';

import 'package:earth_nova/core/cells/cell_service.dart';
import 'package:earth_nova/core/models/cell_properties.dart';
import 'package:earth_nova/core/persistence/location_node_repository.dart';
import 'package:earth_nova/core/services/observability_buffer.dart';
import 'package:flutter/foundation.dart';

/// Computes detection zones from district GeoJSON boundaries.
///
/// The detection zone = current district + adjacent districts. All cells
/// in this zone become "known" (resolved, SpeciesCache warmed, fog rendered).
///
/// Adjacent districts are discovered automatically: after computing cells
/// for the current district, border cells' Voronoi neighbors are checked
/// for different `locationId`s via [cellPropertiesLookup].
///
/// Pure Dart service — no Flutter widgets, no Riverpod dependency.
class DetectionZoneService {
  final CellService _cellService;
  final LocationNodeRepository _locationNodeRepo;

  /// Current detection zone cell IDs (current district + adjacent districts).
  Set<String> _detectionZoneCellIds = {};

  /// Maps cell ID → district location ID for all cells in the current zone.
  /// Used to set locationId on cell properties without async enrichment.
  Map<String, String> _cellDistrictAttribution = {};

  /// Current district location ID, or null if not set.
  String? _currentDistrictId;

  /// Stream that fires when the detection zone changes.
  final StreamController<Set<String>> _zoneChangedController =
      StreamController<Set<String>>.broadcast();

  /// Lookup callback for cell properties (wired by gameCoordinatorProvider).
  /// Returns the CellProperties for a given cellId, or null if not cached.
  CellProperties? Function(String cellId)? cellPropertiesLookup;

  DetectionZoneService({
    required CellService cellService,
    required LocationNodeRepository locationNodeRepo,
  })  : _cellService = cellService,
        _locationNodeRepo = locationNodeRepo;

  // ── Public API ──────────────────────────────────────────────────────────

  /// Current detection zone cell IDs. Empty before any district is set.
  Set<String> get detectionZoneCellIds =>
      Set.unmodifiable(_detectionZoneCellIds);

  /// Current district location ID, or null if not set.
  String? get currentDistrictId => _currentDistrictId;

  /// District attribution for all zone cells (cellId → districtId).
  Map<String, String> get cellDistrictAttribution =>
      Map.unmodifiable(_cellDistrictAttribution);

  /// Stream that fires when the detection zone changes.
  Stream<Set<String>> get onDetectionZoneChanged =>
      _zoneChangedController.stream;

  /// Recomputes the detection zone for the current district.
  ///
  /// Use when geometry arrives after the initial (empty) computation.
  /// Skips the dedup check in [onDistrictChange].
  Future<void> recomputeCurrentZone() async {
    final districtId = _currentDistrictId;
    if (districtId == null) return;
    _currentDistrictId = null; // Clear to bypass dedup
    await onDistrictChange(districtId);
  }

  /// Called when the player enters a new district.
  ///
  /// Computes cell IDs for the district + adjacent districts, updates
  /// [detectionZoneCellIds], and emits on [onDetectionZoneChanged].
  Future<void> onDistrictChange(String districtId) async {
    if (districtId == _currentDistrictId) return;
    _currentDistrictId = districtId;

    final sw = Stopwatch()..start();
    final zone = <String>{};

    // Compute cells for current district.
    final currentCells = await computeCellIdsForDistrict(districtId);
    zone.addAll(currentCells);

    final attribution = <String, String>{};
    for (final cellId in currentCells) {
      attribution[cellId] = districtId;
    }

    // Discover adjacent districts from border cell Voronoi neighbors.
    // A neighbor cell with a different locationId → that's an adjacent district.
    final adjacentDistrictIds = <String>{};

    // Check explicitly stored adjacency first.
    final node = await _locationNodeRepo.get(districtId);
    if (node?.adjacentLocationIds != null) {
      adjacentDistrictIds.addAll(node!.adjacentLocationIds!);
    }

    // Auto-discover from cached cell properties: scan border cells for
    // neighbors with a different locationId.
    if (cellPropertiesLookup != null && currentCells.isNotEmpty) {
      for (final cellId in currentCells) {
        for (final neighborId in _cellService.getNeighborIds(cellId)) {
          if (currentCells.contains(neighborId)) continue;
          final props = cellPropertiesLookup!(neighborId);
          if (props?.locationId != null && props!.locationId != districtId) {
            adjacentDistrictIds.add(props.locationId!);
          }
        }
      }
    }

    // Expand zone with cells from adjacent districts.
    for (final adjId in adjacentDistrictIds) {
      final adjCells = await computeCellIdsForDistrict(adjId);
      zone.addAll(adjCells);
      for (final cellId in adjCells) {
        attribution[cellId] = adjId;
      }
    }

    // Persist discovered adjacency for future sessions.
    if (adjacentDistrictIds.isNotEmpty && node != null) {
      final merged = <String>{
        ...?node.adjacentLocationIds,
        ...adjacentDistrictIds,
      };
      if (merged.length != (node.adjacentLocationIds?.length ?? 0)) {
        final updated = node.copyWith(adjacentLocationIds: merged.toList());
        await _locationNodeRepo.upsert(updated);
      }
    }

    sw.stop();
    debugPrint(
        '[DetectionZone] district=$districtId zone=${zone.length} cells, '
        'current=${currentCells.length}, adjacent=${adjacentDistrictIds.length} districts '
        '(${sw.elapsedMilliseconds}ms)');
    ObservabilityBuffer.instance?.event('detection_zone_changed', {
      'district_id': districtId,
      'zone_size': zone.length,
      'current_cells': currentCells.length,
      'adjacent_districts': adjacentDistrictIds.length,
      'duration_ms': sw.elapsedMilliseconds,
    });

    _cellDistrictAttribution = attribution;
    _detectionZoneCellIds = zone;
    if (!_zoneChangedController.isClosed) {
      _zoneChangedController.add(Set.unmodifiable(zone));
    }
  }

  /// Computes cell IDs whose centers fall within a district's GeoJSON boundary.
  ///
  /// Returns cached cellIds from the LocationNode if available. Otherwise,
  /// scans the bounding box at grid resolution, tests each cell center
  /// against the polygon via ray-casting, caches the result on the
  /// LocationNode, and returns it.
  Future<Set<String>> computeCellIdsForDistrict(String districtId) async {
    final node = await _locationNodeRepo.get(districtId);
    if (node == null) {
      debugPrint('[DetectionZone] node not found: $districtId');
      ObservabilityBuffer.instance?.event('detection_zone_failure', {
        'district_id': districtId,
        'reason': 'node_not_found',
      });
      return {};
    }

    debugPrint('[DetectionZone] compute $districtId: '
        'cellIds=${node.cellIds?.length ?? "null"}, '
        'geom=${node.geometryJson?.length ?? "null"} bytes');

    // Return cached cellIds if available
    if (node.cellIds != null && node.cellIds!.isNotEmpty) {
      debugPrint(
          '[DetectionZone] using cached ${node.cellIds!.length} cellIds');
      return node.cellIds!.toSet();
    }

    // Parse GeoJSON geometry
    if (node.geometryJson == null) {
      debugPrint('[DetectionZone] no geometry for $districtId');
      ObservabilityBuffer.instance?.event('detection_zone_failure', {
        'district_id': districtId,
        'reason': 'no_geometry',
        'has_cached_cellIds': node.cellIds?.isNotEmpty ?? false,
      });
      return {};
    }

    final polygons = _parsePolygons(node.geometryJson!);
    if (polygons.isEmpty) {
      debugPrint('[DetectionZone] failed to parse polygons for $districtId '
          '(geom ${node.geometryJson!.length} bytes)');
      ObservabilityBuffer.instance?.event('detection_zone_failure', {
        'district_id': districtId,
        'reason': 'polygon_parse_failed',
        'geom_bytes': node.geometryJson!.length,
      });
      return {};
    }

    // Find all cell centers inside any polygon
    final cellIds = <String>{};
    for (final polygon in polygons) {
      final bbox = _boundingBox(polygon);
      debugPrint('[DetectionZone] scanning $districtId: '
          '${polygon.length} vertices, '
          'bbox lat [${bbox.minLat.toStringAsFixed(4)}, ${bbox.maxLat.toStringAsFixed(4)}], '
          'lon [${bbox.minLon.toStringAsFixed(4)}, ${bbox.maxLon.toStringAsFixed(4)}]');
      // Scan at grid resolution (0.002° ≈ 180m, matching Voronoi grid step)
      const gridStep = 0.002;
      for (var lat = bbox.minLat; lat <= bbox.maxLat; lat += gridStep) {
        for (var lon = bbox.minLon; lon <= bbox.maxLon; lon += gridStep) {
          final cellId = _cellService.getCellId(lat, lon);
          if (cellIds.contains(cellId)) continue;
          final center = _cellService.getCellCenter(cellId);
          if (_pointInPolygon(center.lat, center.lon, polygon)) {
            cellIds.add(cellId);
          }
        }
      }
    }

    debugPrint(
        '[DetectionZone] scan result for $districtId: ${cellIds.length} cells');

    if (cellIds.isEmpty) {
      ObservabilityBuffer.instance?.event('detection_zone_failure', {
        'district_id': districtId,
        'reason': 'scan_found_zero_cells',
        'polygon_count': polygons.length,
        'geom_bytes': node.geometryJson!.length,
      });
      return {};
    }

    // Cache the result on the LocationNode
    final updated = node.copyWith(cellIds: cellIds.toList());
    await _locationNodeRepo.upsert(updated);

    return cellIds;
  }

  /// Releases the stream controller.
  void dispose() {
    _zoneChangedController.close();
  }

  // ── GeoJSON Parsing ─────────────────────────────────────────────────────

  /// Parses GeoJSON geometry into a list of polygon rings.
  /// Each polygon is a list of (lat, lon) pairs.
  /// Supports both Polygon and MultiPolygon types.
  List<List<({double lat, double lon})>> _parsePolygons(String geometryJson) {
    try {
      final json = jsonDecode(geometryJson) as Map<String, dynamic>;
      final type = json['type'] as String?;
      final coordinates = json['coordinates'];

      if (type == 'Polygon' && coordinates is List) {
        final ring = _parseRing(coordinates[0] as List);
        return ring != null ? [ring] : [];
      } else if (type == 'MultiPolygon' && coordinates is List) {
        final result = <List<({double lat, double lon})>>[];
        for (final polygon in coordinates) {
          if (polygon is List && polygon.isNotEmpty) {
            final ring = _parseRing(polygon[0] as List);
            if (ring != null) result.add(ring);
          }
        }
        return result;
      }
      return [];
    } catch (e) {
      debugPrint('[DetectionZone] failed to parse geometry: $e');
      return [];
    }
  }

  /// Parses a GeoJSON coordinate ring into (lat, lon) pairs.
  /// GeoJSON uses [lon, lat] order.
  List<({double lat, double lon})>? _parseRing(List<dynamic> coordinates) {
    try {
      return coordinates.map((coord) {
        final c = coord as List;
        return (lat: (c[1] as num).toDouble(), lon: (c[0] as num).toDouble());
      }).toList();
    } catch (e) {
      return null;
    }
  }

  // ── Geometry Helpers ────────────────────────────────────────────────────

  /// Bounding box for a polygon ring.
  ({double minLat, double maxLat, double minLon, double maxLon}) _boundingBox(
      List<({double lat, double lon})> polygon) {
    var minLat = double.infinity;
    var maxLat = double.negativeInfinity;
    var minLon = double.infinity;
    var maxLon = double.negativeInfinity;
    for (final p in polygon) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lon < minLon) minLon = p.lon;
      if (p.lon > maxLon) maxLon = p.lon;
    }
    return (minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon);
  }

  /// Ray-casting point-in-polygon test.
  bool _pointInPolygon(
      double lat, double lon, List<({double lat, double lon})> polygon) {
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final yi = polygon[i].lat;
      final xi = polygon[i].lon;
      final yj = polygon[j].lat;
      final xj = polygon[j].lon;

      if (((yi > lat) != (yj > lat)) &&
          (lon < (xj - xi) * (lat - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
    }
    return inside;
  }
}
