import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'package:earth_nova/core/cells/cell_service.dart';
import 'package:earth_nova/core/fog/fog_state_resolver.dart';
import 'package:earth_nova/core/services/observability_buffer.dart';
import 'package:earth_nova/core/models/cell_properties.dart';
import 'package:earth_nova/core/models/fog_state.dart';
import 'package:earth_nova/core/models/location_node.dart';
import 'package:earth_nova/features/map/utils/cell_property_geojson_builder.dart';
import 'package:earth_nova/features/map/utils/fog_geojson_builder.dart';
import 'package:earth_nova/features/map/utils/mercator_projection.dart';
import 'package:earth_nova/features/map/utils/admin_boundary_geojson_builder.dart';
import 'package:earth_nova/features/map/utils/habitat_fill_geojson_builder.dart';
import 'package:earth_nova/features/map/utils/territory_border_geojson_builder.dart';

/// Computes fog GeoJSON for MapLibre native fill layers.
///
/// On each [update] call, visible cells are discovered via grid sampling,
/// their fog states resolved, and GeoJSON strings built for 3 layers:
/// - [baseFogGeoJson]: opaque world polygon with holes for revealed cells
/// - [midFogGeoJson]: semi-transparent polygons for hidden/concealed cells
/// - [restorationGeoJson]: green tint for restored observed cells
///
/// ## Usage
///
/// Call `update` whenever the camera moves or fog state changes. The
/// `renderVersion` increments on every call so callers can detect changes.
///
/// ```dart
/// controller.update(cameraLat: lat, cameraLon: lon, zoom: zoom, viewportSize: size);
/// await mapController.updateGeoJsonSource(id: 'fog-base-src', data: controller.baseFogGeoJson);
/// ```
class FogOverlayController {
  /// Cell geometry provider.
  final CellService cellService;

  /// Fog state computer.
  final FogStateResolver fogResolver;

  /// Sampling step in logical pixels. Lower = more samples, more CPU.
  final double sampleStepPx;

  int _renderVersion = 0;

  /// Persistent set of all cell IDs ever discovered via viewport sampling.
  ///
  /// Once a cell is found, it stays in this set permanently. This eliminates
  /// the flickering caused by viewport sampling aliasing — at certain zoom
  /// levels, cells near the edge of the viewport can fall between sample
  /// points on one frame and be hit on the next, causing them to pop in/out
  /// of the GeoJSON. MapLibre clips off-screen polygons natively, so
  /// including out-of-viewport cells has negligible rendering cost.
  final Set<String> _discoveredCellIds = {};
  int _fogComputeCounter = 0;

  /// Number of cells at time of last GeoJSON build.
  int _lastBuildCellCount = 0;

  /// Visited set size at time of last GeoJSON build.
  int _lastBuildVisitedCount = 0;

  /// Callback fired the first time a cell is added to [_discoveredCellIds].
  ///
  /// Provides the cell ID and the geographic center of the cell so the caller
  /// can trigger async work (e.g. location enrichment) without knowing the
  /// cell service.
  void Function(String cellId, double lat, double lon)? onCellBecameVisible;

  /// Adds detection zone cells to the discovered set so they are included
  /// in GeoJSON builds. Called when the detection zone changes.
  ///
  /// Also accepts the latest [cellProperties] snapshot so territory borders
  /// can be rebuilt with locationId data for the zone cells.
  void addDetectionZoneCells(
    Set<String> zoneCellIds,
    Map<String, CellProperties> cellProperties,
  ) {
    final sw = Stopwatch()..start();
    var added = 0;
    for (final cellId in zoneCellIds) {
      if (_discoveredCellIds.add(cellId)) added++;
    }
    if (added > 0 || cellProperties.length != _cellPropertiesCache.length) {
      _cellPropertiesCache = cellProperties;
      // Do NOT call _buildGeoJson() here — it would process all 6000+
      // discovered cells synchronously, causing a 114ms+ JANK frame that
      // triggers iOS page kills. Instead, reset the dirty tracking so the
      // next throttled update() call rebuilds with the viewport filter.
      _lastBuildCellCount = 0; // Force needsRebuild=true on next update()
      _fogDirty = true;
      try {
        _rebuildTerritoryBorders();
      } catch (e) {
        debugPrint('[FOG] _rebuildTerritoryBorders failed after zone add: $e');
      }
      _renderVersion++;
      sw.stop();
      debugPrint('[FOG] added $added detection zone cells '
          '(total: ${_discoveredCellIds.length}, '
          'props: ${_cellPropertiesCache.length}, '
          '${sw.elapsedMilliseconds}ms)');
    }
  }

  /// GeoJSON string for the base fog layer (world polygon with holes).
  String _baseFogGeoJson = FogGeoJsonBuilder.fullWorldFog;

  /// GeoJSON string for the mid fog layer (hidden/concealed cells).
  String _midFogGeoJson = FogGeoJsonBuilder.emptyFeatureCollection;

  /// GeoJSON string for the cell border outlines (unexplored + concealed).
  String _cellBorderGeoJson = FogGeoJsonBuilder.emptyFeatureCollection;

  /// GeoJSON string for the restoration overlay layer.
  final String _restorationGeoJson = FogGeoJsonBuilder.emptyFeatureCollection;

  /// GeoJSON string for cell property icon Point features.
  String _cellIconsGeoJson = CellPropertyGeoJsonBuilder.emptyFeatureCollection;

  /// GeoJSON string for habitat fill gradient rings per revealed cell.
  String _habitatFillGeoJson = HabitatFillGeoJsonBuilder.emptyFeatureCollection;

  /// Cell properties cache — set externally from GameCoordinator.
  Map<String, CellProperties> _cellPropertiesCache = const {};

  /// Location nodes cache — set externally when enrichment data is loaded.
  Map<String, LocationNode> _locationNodesCache = {};

  /// GeoJSON string for territory border fill (gradient polygons).
  String _borderFillGeoJson =
      TerritoryBorderGeoJsonBuilder.emptyFeatureCollection;

  /// GeoJSON string for territory border lines (admin boundary edges).
  String _borderLinesGeoJson =
      TerritoryBorderGeoJsonBuilder.emptyFeatureCollection;

  /// GeoJSON string for admin boundary polygon fills (event-driven, NOT 10Hz).
  String _adminBoundaryFillGeoJson =
      AdminBoundaryGeoJsonBuilder.emptyFeatureCollection;

  /// GeoJSON string for admin boundary polygon outlines (event-driven, NOT 10Hz).
  String _adminBoundaryLinesGeoJson =
      AdminBoundaryGeoJsonBuilder.emptyFeatureCollection;

  /// Current daily seed for event resolution.
  String _dailySeed = '';

  // -- Dirty flags: track which source groups changed since last consume. --
  bool _fogDirty = false;
  bool _iconsDirty = false;
  bool _borderDirty = false;
  bool _adminDirty = false;
  bool _habitatDirty = false;

  /// Cached visible cell IDs from the last [_buildGeoJson] call.
  /// Used by [_rebuildTerritoryBorders] so it doesn't need fog resolution.
  Set<String> _lastVisibleCellIds = const {};

  /// Cached fog states from the last [_buildGeoJson] call.
  /// Used for observability (state distribution counts).
  Map<String, FogState> _lastCellStates = const {};

  /// Monotonically incremented on every `update` call.
  int get renderVersion => _renderVersion;

  /// Number of cells currently discovered via viewport sampling.
  int get visibleCellCount => _discoveredCellIds.length;

  /// GeoJSON for the opaque base fog (world polygon with holes).
  String get baseFogGeoJson => _baseFogGeoJson;

  /// GeoJSON for the semi-transparent mid fog (hidden/concealed cells).
  String get midFogGeoJson => _midFogGeoJson;

  /// GeoJSON for cell border outlines (unexplored + concealed).
  String get cellBorderGeoJson => _cellBorderGeoJson;

  /// GeoJSON for the green restoration overlay.
  String get restorationGeoJson => _restorationGeoJson;

  /// GeoJSON for cell property icon Points (habitat, climate, event icons).
  String get cellIconsGeoJson => _cellIconsGeoJson;

  /// GeoJSON for habitat fill gradient rings per revealed cell.
  String get habitatFillGeoJson => _habitatFillGeoJson;

  /// GeoJSON for territory border gradient fill (Stellaris-style).
  String get borderFillGeoJson => _borderFillGeoJson;

  /// GeoJSON for territory border lines (admin boundary edges).
  String get borderLinesGeoJson => _borderLinesGeoJson;

  /// GeoJSON for admin boundary polygon fills (event-driven).
  String get adminBoundaryFillGeoJson => _adminBoundaryFillGeoJson;

  /// GeoJSON for admin boundary polygon outlines (event-driven).
  String get adminBoundaryLinesGeoJson => _adminBoundaryLinesGeoJson;

  // -- Per-group dirty flag consumers. Each returns the current flag and
  //    clears it atomically. Non-fog groups stay dirty until consumed,
  //    enabling staggered updates across frames. --

  /// Returns `true` if fog layers (base + mid + border outlines) changed.
  bool consumeFogDirty() {
    final v = _fogDirty;
    _fogDirty = false;
    return v;
  }

  /// Returns `true` if cell property icons changed.
  bool consumeIconsDirty() {
    final v = _iconsDirty;
    _iconsDirty = false;
    return v;
  }

  /// Returns `true` if territory border fill/lines changed.
  bool consumeBorderDirty() {
    final v = _borderDirty;
    _borderDirty = false;
    return v;
  }

  /// Returns `true` if admin boundary fill/lines changed.
  bool consumeAdminDirty() {
    final v = _adminDirty;
    _adminDirty = false;
    return v;
  }

  /// Returns `true` if habitat fill gradient rings changed.
  bool consumeHabitatDirty() {
    final v = _habitatDirty;
    _habitatDirty = false;
    return v;
  }

  /// Updates the cell properties cache snapshot from GameCoordinator.
  ///
  /// Triggers a territory border rebuild when cell properties change
  /// (new cells enriched → border geometry may change).
  set cellPropertiesCache(Map<String, CellProperties> cache) {
    _cellPropertiesCache = cache;
    _rebuildTerritoryBorders();
  }

  /// Updates the location nodes cache from the database.
  ///
  /// Triggers a territory border rebuild when location nodes change.
  set locationNodesCache(Map<String, LocationNode> cache) {
    _locationNodesCache = cache;
    _rebuildTerritoryBorders();
  }

  /// Adds a single [LocationNode] to the location nodes cache.
  ///
  /// Called when new enrichment data arrives mid-session so newly enriched
  /// territory borders appear without requiring an app restart.
  void addLocationNode(LocationNode node) {
    _locationNodesCache[node.id] = node;
  }

  /// Rebuilds admin boundary GeoJSON from the given location nodes.
  ///
  /// Called EVENT-DRIVEN when [AdminBoundaryService.onBoundariesResolved]
  /// fires — NOT from the 10Hz [_buildGeoJson] loop.
  void updateAdminBoundaries(Map<String, LocationNode> nodes) {
    _adminBoundaryFillGeoJson =
        AdminBoundaryGeoJsonBuilder.buildBoundaryFills(nodes);
    _adminBoundaryLinesGeoJson =
        AdminBoundaryGeoJsonBuilder.buildBoundaryLines(nodes);
    _adminDirty = true;
  }

  /// Updates the daily seed used for event resolution.
  set dailySeed(String seed) => _dailySeed = seed;

  FogOverlayController({
    required this.cellService,
    required this.fogResolver,
    this.sampleStepPx = 25.0,
  });

  /// Recomputes visible cells and builds GeoJSON for all fog layers.
  ///
  /// Call on every camera move or when fog state changes. The viewport
  /// sampling discovers cells, resolves their fog states, then builds
  /// GeoJSON strings that MapLibre renders as native fill layers.
  void update({
    required double cameraLat,
    required double cameraLon,
    required double zoom,
    required Size viewportSize,
  }) {
    final sw = Stopwatch()..start();

    final visibleCellIds = _findVisibleCells(
      cameraLat: cameraLat,
      cameraLon: cameraLon,
      zoom: zoom,
      viewportSize: viewportSize,
    );

    // Accumulate — never remove cells from the discovered set.
    // This prevents flickering caused by viewport sampling aliasing.
    // Fire onCellBecameVisible for each cell added for the first time.
    for (final cellId in visibleCellIds) {
      if (_discoveredCellIds.add(cellId)) {
        final center = cellService.getCellCenter(cellId);
        onCellBecameVisible?.call(cellId, center.lat, center.lon);
      }
    }

    // Skip expensive GeoJSON rebuild if nothing changed: no new cells
    // discovered and no new cells visited (fog state transitions).
    // The 2Hz throttle (every 30th frame on iOS) is the primary cost
    // control — building all discovered cells at 2Hz is ~23% CPU.
    final currentVisitedCount = fogResolver.visitedCellIds.length;
    final needsRebuild = _discoveredCellIds.length != _lastBuildCellCount ||
        currentVisitedCount != _lastBuildVisitedCount;

    if (needsRebuild) {
      _buildGeoJson(_discoveredCellIds);
      _lastBuildCellCount = _discoveredCellIds.length;
      _lastBuildVisitedCount = currentVisitedCount;
    }
    _renderVersion++;

    sw.stop();
    // Emit fog_computed every 50th frame OR when slow (>8ms).
    // Previous bug: >8ms gate meant fast frames never logged state counts,
    // hiding whether detection zone cells were included.
    _fogComputeCounter++;
    if (sw.elapsedMilliseconds > 8 || _fogComputeCounter % 50 == 1) {
      final stateCounts = <String, int>{};
      for (final state in _lastCellStates.values) {
        stateCounts[state.name] = (stateCounts[state.name] ?? 0) + 1;
      }
      ObservabilityBuffer.instance?.event('fog_computed', {
        'duration_ms': sw.elapsedMilliseconds,
        'cell_count': _discoveredCellIds.length,
        'dirty': _fogDirty,
        'skipped_rebuild': !needsRebuild,
        'states': stateCounts,
      });
    }
  }

  /// Non-blocking version of [update] for initial map load.
  ///
  /// Processes visible cells in batches, yielding to the event loop between
  /// each chunk. The [onBatchReady] callback fires after each batch.
  Future<int> updateAsync({
    required double cameraLat,
    required double cameraLon,
    required double zoom,
    required Size viewportSize,
    void Function()? onBatchReady,
    int chunkSize = 20,
  }) async {
    _asyncUpdateGeneration++;
    final myGeneration = _asyncUpdateGeneration;

    final visibleCellIds = _findVisibleCells(
      cameraLat: cameraLat,
      cameraLon: cameraLon,
      zoom: zoom,
      viewportSize: viewportSize,
    ).toList();

    var addedCount = 0;

    for (var i = 0; i < visibleCellIds.length; i += chunkSize) {
      if (_asyncUpdateGeneration != myGeneration) return addedCount;

      final end = min(i + chunkSize, visibleCellIds.length);
      final chunk = visibleCellIds.sublist(i, end);
      // Accumulate into the persistent set — never remove.
      // Fire onCellBecameVisible for each cell added for the first time.
      for (final cellId in chunk) {
        if (_discoveredCellIds.add(cellId)) {
          addedCount++;
          final center = cellService.getCellCenter(cellId);
          onCellBecameVisible?.call(cellId, center.lat, center.lon);
        }
      }

      // Build GeoJSON from all discovered cells so far.
      _buildGeoJson(_discoveredCellIds);
      _renderVersion++;
      onBatchReady?.call();

      if (end < visibleCellIds.length) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    return addedCount;
  }

  int _asyncUpdateGeneration = 0;

  /// Builds all GeoJSON strings from the given set of visible cell IDs.
  ///
  /// Sets dirty flags for each source group that was rebuilt so that
  /// [_updateFogSources] only pushes changed sources to MapLibre.
  /// Territory borders are NOT rebuilt here — they are event-driven
  /// via [_rebuildTerritoryBorders] (triggered by setter changes).
  void _buildGeoJson(Iterable<String> cellIds) {
    final cellStates = <String, FogState>{};
    for (final cellId in cellIds) {
      final state = fogResolver.resolve(cellId);
      if (state == FogState.unknown) continue;
      cellStates[cellId] = state;
    }

    // Cache visible cell IDs for territory border rebuilds.
    _lastVisibleCellIds = cellStates.keys.toSet();
    _lastCellStates = cellStates;

    // Fog layers (base + mid + border outlines).
    _baseFogGeoJson = FogGeoJsonBuilder.buildBaseFog(
      cellStates: cellStates,
      getBoundary: cellService.getCellBoundary,
    );

    _midFogGeoJson = FogGeoJsonBuilder.buildMidFog(
      cellStates: cellStates,
      getBoundary: cellService.getCellBoundary,
    );

    _cellBorderGeoJson = FogGeoJsonBuilder.buildCellBorders(
      cellStates: cellStates,
      getBoundary: cellService.getCellBoundary,
    );
    _fogDirty = true;

    // Build cell property icons (habitat, climate, event).
    if (_cellPropertiesCache.isNotEmpty && _dailySeed.isNotEmpty) {
      _cellIconsGeoJson = CellPropertyGeoJsonBuilder.buildCellIcons(
        cellStates: cellStates,
        cellProperties: _cellPropertiesCache,
        currentCellId: fogResolver.currentCellId,
        adjacentCellIds: fogResolver.currentNeighborIds,
        visitedCellIds: fogResolver.visitedCellIds,
        dailySeed: _dailySeed,
        getCellCenter: cellService.getCellCenter,
      );
    } else {
      _cellIconsGeoJson = CellPropertyGeoJsonBuilder.emptyFeatureCollection;
    }
    _iconsDirty = true;

    // Build habitat fill gradient rings for revealed cells.
    if (_cellPropertiesCache.isNotEmpty) {
      _habitatFillGeoJson = HabitatFillGeoJsonBuilder.buildHabitatFills(
        cellProperties: _cellPropertiesCache,
        cellStates: cellStates,
        getCellBoundary: cellService.getCellBoundary,
      );
    } else {
      _habitatFillGeoJson = HabitatFillGeoJsonBuilder.emptyFeatureCollection;
    }
    _habitatDirty = true;
  }

  /// Rebuilds territory border GeoJSON from cached data.
  ///
  /// Called EVENT-DRIVEN from [locationNodesCache] and [cellPropertiesCache]
  /// setters — NOT from the 10 Hz [_buildGeoJson] loop.
  void _rebuildTerritoryBorders() {
    if (_locationNodesCache.isNotEmpty && _cellPropertiesCache.isNotEmpty) {
      final sw = Stopwatch()..start();
      _borderFillGeoJson = TerritoryBorderGeoJsonBuilder.buildBorderFill(
        cellProperties: _cellPropertiesCache,
        locationNodes: _locationNodesCache,
        visibleCellIds: _lastVisibleCellIds,
        getNeighborIds: cellService.getNeighborIds,
        getBoundary: cellService.getCellBoundary,
      );
      _borderLinesGeoJson = TerritoryBorderGeoJsonBuilder.buildBorderLines(
        cellProperties: _cellPropertiesCache,
        locationNodes: _locationNodesCache,
        visibleCellIds: _lastVisibleCellIds,
        getNeighborIds: cellService.getNeighborIds,
        getBoundary: cellService.getCellBoundary,
        getCellCenter: cellService.getCellCenter,
      );
      sw.stop();
      debugPrint('[BORDERS] rebuilt: ${sw.elapsedMilliseconds}ms, '
          '${_locationNodesCache.length} nodes, '
          '${_cellPropertiesCache.length} cells');
    } else {
      _borderFillGeoJson = TerritoryBorderGeoJsonBuilder.emptyFeatureCollection;
      _borderLinesGeoJson =
          TerritoryBorderGeoJsonBuilder.emptyFeatureCollection;
    }
    _borderDirty = true;
  }

  /// Discovers cell IDs visible in the current viewport via grid sampling.
  Set<String> _findVisibleCells({
    required double cameraLat,
    required double cameraLon,
    required double zoom,
    required Size viewportSize,
  }) {
    final padX = viewportSize.width * 0.2;
    final padY = viewportSize.height * 0.2;

    final sampled = <String>{};

    var y = -padY;
    while (y <= viewportSize.height + padY) {
      var x = -padX;
      while (x <= viewportSize.width + padX) {
        final geo = MercatorProjection.screenToGeo(
          screenPoint: Offset(x, y),
          cameraLat: cameraLat,
          cameraLon: cameraLon,
          zoom: zoom,
          viewportSize: viewportSize,
        );
        final cellId = cellService.getCellId(geo.lat, geo.lon);
        sampled.add(cellId);
        x += sampleStepPx;
      }
      y += sampleStepPx;
    }

    final expanded = <String>{...sampled};
    for (final cellId in sampled) {
      expanded.addAll(cellService.getNeighborIds(cellId));
    }

    return expanded;
  }
}
