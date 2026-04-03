import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'package:earth_nova/core/cells/cell_service.dart';
import 'package:earth_nova/core/fog/fog_state_resolver.dart';
import 'package:earth_nova/core/services/observability_buffer.dart';
import 'package:earth_nova/core/models/cell_properties.dart';
import 'package:earth_nova/core/models/fog_state.dart';
import 'package:earth_nova/features/map/utils/cell_property_geojson_builder.dart';
import 'package:earth_nova/features/map/utils/fog_geojson_builder.dart';
import 'package:earth_nova/features/map/utils/habitat_fill_geojson_builder.dart';
import 'package:earth_nova/features/map/utils/territory_border_geojson_builder.dart';

/// Computes fog GeoJSON for MapLibre native fill layers.
///
/// On each [update] call, visible cells are discovered via grid sampling,
/// their fog states resolved, and GeoJSON strings built for 3 layers:
/// - [baseFogGeoJson]: opaque world polygon with holes for revealed cells
/// - [midFogGeoJson]: semi-transparent polygons for hidden/concealed cells
/// - cell borders: outline cells at fog boundaries
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

  /// Sampling step in logical pixels.
  ///
  /// @deprecated Viewport sampling has been removed. This field is retained
  /// for API compatibility with existing tests but has no effect.
  // ignore: deprecated_member_use_from_same_package
  @Deprecated('Viewport sampling removed — addDetectionZoneCells() is the '
      'canonical way to populate discovered cells.')
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

  /// Whether the last GeoJSON build included property layers (icons + habitat).
  /// Used to force a property rebuild when props first become available.
  bool _lastBuildIncludedProperties = false;

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
    // Seed from visited cells — belt-and-suspenders for sessions where hydration
    // races with zone computation. Visited cells must always be discoverable.
    for (final cellId in fogResolver.visitedCellIds) {
      _discoveredCellIds.add(cellId);
    }

    final sw = Stopwatch()..start();
    var added = 0;
    for (final cellId in zoneCellIds) {
      if (_discoveredCellIds.add(cellId)) added++;
    }

    // Prune cells that are no longer in the detection zone and have never been
    // visited. Unvisited out-of-range cells have no fog state to preserve and
    // their continued presence causes unbounded GeoJSON build growth.
    // Visited cells are never pruned — they hold permanent fog state.
    final beforePrune = _discoveredCellIds.length;
    _discoveredCellIds.removeWhere((cellId) =>
        !zoneCellIds.contains(cellId) &&
        !fogResolver.visitedCellIds.contains(cellId));
    final pruned = beforePrune - _discoveredCellIds.length;

    if (added > 0 ||
        pruned > 0 ||
        cellProperties.length != _cellPropertiesCache.length) {
      _cellPropertiesCache = cellProperties;
      // Do NOT call _buildGeoJson() here — it would process all 6000+
      // discovered cells synchronously, causing a 114ms+ JANK frame that
      // triggers iOS page kills. Instead, reset the dirty tracking so the
      // next throttled update() call rebuilds with the viewport filter.
      _lastBuildCellCount = 0; // Force needsRebuild=true on next update()
      _fogDirty = true;
      // Sync _lastVisibleCellIds with all discovered cells so that
      // _rebuildTerritoryBorders sees the newly added zone cells.
      // Without this, if location nodes load before the next _buildGeoJson
      // cycle, the territory builder processes stale visible cells (which
      // may have null locationId) and produces 0 border features.
      _lastVisibleCellIds = _discoveredCellIds;
      try {
        _scheduleBorderRebuild();
      } catch (e) {
        debugPrint('[FOG] _rebuildTerritoryBorders failed after zone add: $e');
      }
      _renderVersion++;
      sw.stop();
      debugPrint('[FOG] added $added detection zone cells '
          '(zone: ${zoneCellIds.length}, visited: ${fogResolver.visitedCellIds.length}, '
          'total: ${_discoveredCellIds.length}, pruned: $pruned, '
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

  /// GeoJSON string for cell property icon Point features.
  String _cellIconsGeoJson = CellPropertyGeoJsonBuilder.emptyFeatureCollection;

  /// GeoJSON string for habitat fill gradient rings per revealed cell.
  String _habitatFillGeoJson = HabitatFillGeoJsonBuilder.emptyFeatureCollection;

  /// Cell properties cache — set externally from GameCoordinator.
  Map<String, CellProperties> _cellPropertiesCache = const {};

  /// Identity reference for the current cache — used by map_screen to
  /// avoid calling the setter every frame (setter triggers border rebuild).
  Map<String, CellProperties> get cellPropertiesCacheRef =>
      _cellPropertiesCache;

  /// District attribution map: cellId → districtId.
  Map<String, String> _cellDistrictIds = {};

  /// Number of cells currently in the district attribution map.
  int get cellDistrictIdsCount => _cellDistrictIds.length;

  /// District ancestry map: districtId → {cityId, stateId, countryId}.
  Map<String, ({String? cityId, String? stateId, String? countryId})>
      _districtAncestry = {};

  /// GeoJSON string for territory border fill (gradient polygons).
  String _borderFillGeoJson =
      TerritoryBorderGeoJsonBuilder.emptyFeatureCollection;

  /// GeoJSON string for territory border lines (admin boundary edges).
  String _borderLinesGeoJson =
      TerritoryBorderGeoJsonBuilder.emptyFeatureCollection;

  /// Current daily seed for event resolution.
  String _dailySeed = '';

  // -- Dirty flags: track which source groups changed since last consume. --
  bool _fogDirty = false;
  bool _iconsDirty = false;
  bool _borderDirty = false;
  bool _habitatDirty = false;

  /// Cached visible cell IDs from the last [_buildGeoJson] call.
  /// Used by [_rebuildTerritoryBorders] so it doesn't need fog resolution.
  Set<String> _lastVisibleCellIds = const {};

  /// Cached fog states from the last [_buildGeoJson] call.
  /// Used for observability (state distribution counts).
  Map<String, FogState> _lastCellStates = const {};

  /// Debounce timer for territory border rebuilds.
  ///
  /// Multiple rapid setter updates (e.g. 25+ enrichment results in 1s) are
  /// coalesced into a single rebuild fired 100ms after the last change.
  Timer? _borderRebuildTimer;

  /// Cached GeoJSON coordinate ring strings per cell. Built lazily from
  /// getCellBoundary(). Never invalidated — Voronoi boundaries are immutable.
  /// Eliminates ~250K double.toString() calls per fog rebuild.
  final Map<String, String> _boundaryFragmentCache = {};

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

  /// GeoJSON for cell property icon Points (habitat, climate, event icons).
  String get cellIconsGeoJson => _cellIconsGeoJson;

  /// GeoJSON for habitat fill gradient rings per revealed cell.
  String get habitatFillGeoJson => _habitatFillGeoJson;

  /// GeoJSON for territory border gradient fill (Stellaris-style).
  String get borderFillGeoJson => _borderFillGeoJson;

  /// GeoJSON for territory border lines (admin boundary edges).
  String get borderLinesGeoJson => _borderLinesGeoJson;

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
    _scheduleBorderRebuild();
  }

  /// Updates the district attribution map (cellId → districtId).
  ///
  /// Triggers a territory border rebuild when the attribution changes.
  set cellDistrictIds(Map<String, String> ids) {
    _cellDistrictIds = ids;
    _scheduleBorderRebuild();
  }

  /// Updates the district ancestry map (districtId → {cityId, stateId, countryId}).
  ///
  /// Triggers a territory border rebuild when ancestry data changes.
  set districtAncestry(
      Map<String, ({String? cityId, String? stateId, String? countryId})>
          ancestry) {
    _districtAncestry = ancestry;
    _scheduleBorderRebuild();
  }

  /// Updates the daily seed used for event resolution.
  set dailySeed(String seed) => _dailySeed = seed;

  // ignore: deprecated_member_use_from_same_package
  FogOverlayController({
    required this.cellService,
    required this.fogResolver,
    @Deprecated('Viewport sampling removed — has no effect.')
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

    // No viewport sampling — _discoveredCellIds is populated exclusively
    // by addDetectionZoneCells(). The detection zone provides the canonical
    // cell set; viewport sampling was removed because it caused unbounded
    // cell growth (13K+ cells from wrong camera position).

    // Skip expensive GeoJSON rebuild if nothing changed: no new cells
    // discovered and no new cells visited (fog state transitions).
    // The 2Hz throttle (every 30th frame on iOS) is the primary cost
    // control — building all discovered cells at 2Hz is ~23% CPU.
    final currentVisitedCount = fogResolver.visitedCellIds.length;
    final needsRebuild = _discoveredCellIds.length != _lastBuildCellCount ||
        currentVisitedCount != _lastBuildVisitedCount;

    if (needsRebuild) {
      // Include property layers (icons + habitat) when cell count changed
      // (new cells discovered) or when properties weren't built last time.
      // On fog-only changes (visited count changed), skip icons/habitat —
      // they don't change when a cell transitions fog state.
      final cellCountChanged = _discoveredCellIds.length != _lastBuildCellCount;
      final includeProps = cellCountChanged || !_lastBuildIncludedProperties;
      _buildGeoJson(_discoveredCellIds, includePropertyLayers: includeProps);
      _lastBuildCellCount = _discoveredCellIds.length;
      _lastBuildVisitedCount = currentVisitedCount;
      _lastBuildIncludedProperties = includeProps;
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
  /// Builds GeoJSON from all discovered cells (populated by
  /// [addDetectionZoneCells] during the loading screen). Viewport sampling
  /// has been removed — cell discovery is driven exclusively by the detection
  /// zone.
  Future<int> updateAsync({
    required double cameraLat,
    required double cameraLon,
    required double zoom,
    required Size viewportSize,
    void Function()? onBatchReady,
    int chunkSize = 20,
  }) async {
    // Build GeoJSON from all discovered cells (populated by
    // addDetectionZoneCells during loading screen).
    _buildGeoJson(_discoveredCellIds, includePropertyLayers: true);
    _lastBuildCellCount = _discoveredCellIds.length;
    _lastBuildVisitedCount = fogResolver.visitedCellIds.length;
    _lastBuildIncludedProperties = true;
    _renderVersion++;
    onBatchReady?.call();

    return _discoveredCellIds.length;
  }

  /// Returns a cached GeoJSON coordinate ring string for the given cell.
  /// Format: `[[-66.64,45.96],[-66.63,45.97],...,[-66.64,45.96]]`
  /// (closed ring with first vertex repeated at end).
  String _getFragment(String cellId) {
    return _boundaryFragmentCache[cellId] ??= _buildFragment(cellId);
  }

  String _buildFragment(String cellId) {
    final boundary = cellService.getCellBoundary(cellId);
    if (boundary.length < 3) return '[]';
    final buf = StringBuffer('[');
    for (var i = 0; i < boundary.length; i++) {
      if (i > 0) buf.write(',');
      buf.write('[${boundary[i].lon},${boundary[i].lat}]');
    }
    buf.write(',[${boundary[0].lon},${boundary[0].lat}]');
    buf.write(']');
    return buf.toString();
  }

  /// Builds all GeoJSON strings from the given set of visible cell IDs.
  ///
  /// Sets dirty flags for each source group that was rebuilt so that
  /// [_updateFogSources] only pushes changed sources to MapLibre.
  /// Territory borders are NOT rebuilt here — they are event-driven
  /// via [_rebuildTerritoryBorders] (triggered by setter changes).
  void _buildGeoJson(
    Iterable<String> cellIds, {
    bool includePropertyLayers = true,
  }) {
    final cellStates = <String, FogState>{};
    for (final cellId in cellIds) {
      final state = fogResolver.resolve(cellId);
      // Include ALL cells — even unknown. Detection zone cells need borders
      // and territory rendering even when not yet explored.
      cellStates[cellId] = state;
    }

    // Observability: state distribution for fog pipeline debugging.
    {
      var explored = 0, detected = 0, nearby = 0, unknown = 0;
      for (final s in cellStates.values) {
        switch (s) {
          case FogState.present:
          case FogState.explored:
            explored++;
          case FogState.nearby:
            nearby++;
          case FogState.detected:
            detected++;
          case FogState.unknown:
            unknown++;
        }
      }
      debugPrint('[FOG-BUILD] cells=${cellStates.length} '
          'explored=$explored nearby=$nearby detected=$detected unknown=$unknown '
          'visitedLoaded=${fogResolver.visitedCellIds.length}');
      ObservabilityBuffer.instance?.event('fog_build', {
        'cells': cellStates.length,
        'explored': explored,
        'nearby': nearby,
        'detected': detected,
        'unknown': unknown,
        'visited_loaded': fogResolver.visitedCellIds.length,
      });
    }

    // Cache ALL discovered cell IDs for territory border rebuilds — not just
    // cells with non-unknown fog state. Detection zone cells need borders
    // even when they haven't been explored yet.
    _lastVisibleCellIds = cellIds is Set<String> ? cellIds : cellIds.toSet();
    _lastCellStates = cellStates;

    // Fog layers (base + mid + border outlines).
    _baseFogGeoJson = FogGeoJsonBuilder.buildBaseFog(
      cellStates: cellStates,
      getBoundary: cellService.getCellBoundary,
      getFragment: _getFragment,
    );

    _midFogGeoJson = FogGeoJsonBuilder.buildMidFog(
      cellStates: cellStates,
      getBoundary: cellService.getCellBoundary,
      getFragment: _getFragment,
    );

    _cellBorderGeoJson = FogGeoJsonBuilder.buildCellBorders(
      cellStates: cellStates,
      getBoundary: cellService.getCellBoundary,
      getFragment: _getFragment,
    );
    _fogDirty = true;

    if (includePropertyLayers) {
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
  }

  /// Schedules a territory border rebuild 100ms from now.
  ///
  /// Cancels any pending rebuild — rapid-fire setter changes (e.g. 25+
  /// enrichment results in 1s) coalesce into a single rebuild.
  void _scheduleBorderRebuild() {
    _borderRebuildTimer?.cancel();
    _borderRebuildTimer = Timer(const Duration(milliseconds: 100), () {
      _borderRebuildTimer = null;
      _rebuildTerritoryBorders();
    });
  }

  /// Rebuilds territory border GeoJSON from cached data.
  ///
  /// Called EVENT-DRIVEN from [cellDistrictIds], [districtAncestry], and
  /// [cellPropertiesCache] setters — NOT from the 10 Hz [_buildGeoJson] loop.
  void _rebuildTerritoryBorders() {
    if (_cellDistrictIds.isNotEmpty && _districtAncestry.isNotEmpty) {
      final sw = Stopwatch()..start();
      _borderFillGeoJson = TerritoryBorderGeoJsonBuilder.buildBorderFill(
        cellProperties: _cellPropertiesCache,
        cellDistrictIds: _cellDistrictIds,
        districtAncestry: _districtAncestry,
        visibleCellIds: _lastVisibleCellIds,
        getNeighborIds: cellService.getNeighborIds,
        getBoundary: cellService.getCellBoundary,
      );
      _borderLinesGeoJson = TerritoryBorderGeoJsonBuilder.buildBorderLines(
        cellProperties: _cellPropertiesCache,
        cellDistrictIds: _cellDistrictIds,
        districtAncestry: _districtAncestry,
        visibleCellIds: _lastVisibleCellIds,
        getNeighborIds: cellService.getNeighborIds,
        getBoundary: cellService.getCellBoundary,
        getCellCenter: cellService.getCellCenter,
      );
      sw.stop();
      debugPrint('[BORDERS] rebuilt: ${sw.elapsedMilliseconds}ms, '
          '${_cellDistrictIds.length} district attributions, '
          '${_cellPropertiesCache.length} cells');
    } else {
      _borderFillGeoJson = TerritoryBorderGeoJsonBuilder.emptyFeatureCollection;
      _borderLinesGeoJson =
          TerritoryBorderGeoJsonBuilder.emptyFeatureCollection;
    }
    _borderDirty = true;
  }
}
