import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre/maplibre.dart';

import 'package:geobase/geobase.dart' show Geographic;

import 'package:earth_nova/core/game/game_coordinator.dart';
import 'package:earth_nova/core/models/cell_event.dart';
import 'package:earth_nova/core/models/climate.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/models/location_node.dart';
import 'package:earth_nova/core/state/cell_service_provider.dart';
import 'package:earth_nova/core/state/daily_seed_provider.dart';
import 'package:earth_nova/core/state/fog_resolver_provider.dart';
import 'package:earth_nova/core/state/game_coordinator_provider.dart';
import 'package:earth_nova/core/state/location_provider.dart';
import 'package:earth_nova/core/state/location_node_repository_provider.dart';
import 'package:earth_nova/features/discovery/widgets/discovery_notification.dart';
import 'package:earth_nova/features/steps/widgets/step_recap.dart';
import 'package:earth_nova/features/location/widgets/location_permission_banner.dart';
import 'package:earth_nova/features/map/controllers/rubber_band_controller.dart';
import 'package:earth_nova/features/map/providers/camera_controller_provider.dart';
import 'package:earth_nova/features/map/providers/camera_mode_provider.dart';
import 'package:earth_nova/features/map/providers/fog_overlay_controller_provider.dart';
import 'package:earth_nova/features/map/providers/map_state_provider.dart';
import 'package:earth_nova/features/map/utils/cell_property_geojson_builder.dart';
import 'package:earth_nova/features/map/utils/fog_geojson_builder.dart';
import 'package:earth_nova/features/map/utils/map_icon_renderer.dart';
import 'package:earth_nova/features/map/utils/territory_border_geojson_builder.dart';
import 'package:earth_nova/features/map/utils/map_logger.dart';
import 'package:earth_nova/shared/game_icons.dart';
import 'package:earth_nova/features/map/widgets/debug_hud.dart';
import 'package:earth_nova/features/map/widgets/player_marker_layer.dart';
import 'package:earth_nova/features/map/widgets/dpad_controls.dart';
import 'package:earth_nova/features/map/widgets/map_controls.dart';
import 'package:earth_nova/features/map/widgets/status_bar.dart';
import 'package:earth_nova/features/location/services/location_service.dart';
import 'package:earth_nova/features/map/providers/cell_selection_provider.dart';
import 'package:earth_nova/features/map/providers/location_service_provider.dart';
import 'package:earth_nova/features/map/widgets/cell_info_sheet.dart';
import 'package:earth_nova/features/sync/providers/admin_boundary_provider.dart';
import 'package:earth_nova/features/sync/providers/location_enrichment_provider.dart';
import 'package:earth_nova/features/sync/services/admin_boundary_service.dart';
import 'package:earth_nova/features/sync/services/location_enrichment_service.dart';
import 'package:earth_nova/features/sync/widgets/sync_toast_overlay.dart';
import 'package:earth_nova/features/map/utils/admin_boundary_geojson_builder.dart';
import 'package:earth_nova/shared/constants.dart';
import 'package:earth_nova/shared/widgets/error_boundary.dart';

/// Fixed zoom presets for the map camera.
enum ZoomLevel {
  /// Fits the current cell + all adjacent cells into the viewport.
  player,

  /// Fits all explored (visited) cells into the viewport.
  world,
}

/// Main map screen — a pure renderer.
///
/// All game logic (GPS subscription, discovery processing, fog cell tracking,
/// permission checks, game tick) lives in [GameCoordinator]. This widget
/// only handles:
/// - Rubber-band interpolation (60 fps visual)
/// - Camera movement
/// - Fog GeoJSON layer management (MapLibre rendering)
/// - Widget tree + UI overlays
///
/// ## Coordination Flow
///
/// ```
/// GameCoordinator.onRawGpsUpdate (1 Hz)
///   → _rubberBand.setTarget()
///   → _rubberBand._onTick() (60 fps)
///     → _onDisplayPositionUpdate(lat, lon)
///       ├─ _markerPosition.value = (lat, lon)  [PlayerMarkerLayer]
///       ├─ cameraController.onLocationUpdate()  [MapLibre moveCamera]
///       ├─ gameCoordinator.updatePlayerPosition()  [throttled to ~10 Hz]
///       └─ _renderFrame % 6 == 0?
///           └─ _updateFogRendering()  [fog overlay + GeoJSON sources]
/// ```
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with TickerProviderStateMixin {
  MapController? _mapController;

  /// The central game logic coordinator. Saved in initState for safe access.
  late final GameCoordinator _gameCoordinator;

  /// Location enrichment service. Saved in initState for safe access in dispose()
  /// (calling ref.read() in dispose() triggers "Bad state: Using ref" error).
  late final LocationEnrichmentService _locationEnrichmentService;

  /// Rubber-band interpolation controller. Decouples the visible marker
  /// position from raw GPS coordinates and drives 60fps camera + marker
  /// updates via a Ticker.
  late final RubberBandController _rubberBand;

  /// Interpolated display position for the player marker (updated at 60fps).
  ///
  /// Updated via [ValueNotifier] so only [PlayerMarkerLayer] rebuilds on each
  /// 60fps frame — the rest of [MapScreen] stays stable.
  late final ValueNotifier<({double lat, double lon})?> _markerPosition;

  /// Subscription to raw GPS updates from GameCoordinator.
  StreamSubscription<({Geographic position, double accuracy})>?
      _rawGpsSubscription;

  bool _showDebugHud = false;

  /// Whether to show the "moving too fast" exploration-disabled banner.
  /// Set `true` when exploration is blocked (marker cell ≠ GPS cell),
  /// cleared when exploration re-enables (cells match again).
  bool _showExplorationBanner = false;

  /// Current zoom preset. Defaults to player-level (tight around current cell).
  ZoomLevel _zoomLevel = ZoomLevel.player;

  /// Explicitly tracked zoom level. We ALWAYS pass this to moveCamera() to
  /// prevent MapLibre from resetting zoom when `zoom: null` is passed via
  /// JS interop (null ≠ undefined in Dart-JS interop — MapLibre may interpret
  /// null as "reset to default" instead of "preserve current").
  double _currentZoom = kDefaultZoom;

  /// Frame counter for throttling fog rendering in [_onDisplayPositionUpdate].
  /// Fog rendering runs at ~10 Hz, not 60 fps.
  int _renderFrame = 0;

  /// Render logic runs every Nth display-update frame (~10 Hz at 60 fps).
  static const _kRenderInterval = 6;

  /// Whether the MapLibre fog sources/layers have been added to the map.
  bool _fogLayersInitialized = false;

  // -- MapLibre source/layer IDs for the fog system --
  static const _fogBaseSrcId = 'fog-base-src';
  static const _fogBaseLayerId = 'fog-base';
  static const _fogMidSrcId = 'fog-mid-src';
  static const _fogMidLayerId = 'fog-mid';
  static const _fogBorderSrcId = 'fog-border-src';
  static const _fogBorderLayerId = 'fog-border';

  // -- MapLibre source/layer IDs for cell property icons --
  static const _cellIconsSrcId = 'cell-icons-src';
  static const _cellIconsLayerId = 'cell-icons';

  // -- MapLibre source/layer IDs for admin boundary polygons --
  static const _adminBoundaryFillSrcId = 'admin-boundary-fill-src';
  static const _adminBoundaryFillLayerId = 'admin-boundary-fill';
  static const _adminBoundaryLinesSrcId = 'admin-boundary-lines-src';
  static const _adminBoundaryLinesLayerId = 'admin-boundary-lines';

  // -- MapLibre source/layer IDs for territory borders --
  static const _borderFillSrcId = 'territory-border-fill-src';
  static const _borderFillLayerId = 'territory-border-fill';
  static const _borderLinesSrcId = 'territory-border-lines-src';
  static const _borderLinesLayerId = 'territory-border-lines';

  /// Whether the cell property icon images have been registered with MapLibre.
  bool _iconImagesRegistered = false;

  /// Admin boundary service — may be null when Supabase is not configured.
  AdminBoundaryService? _adminBoundaryService;

  /// Cached location nodes — loaded once, refreshed when enrichment completes.
  Map<String, LocationNode> _locationNodesMap = {};
  bool _locationNodesLoaded = false;

  @override
  void initState() {
    super.initState();

    _markerPosition = ValueNotifier(null);

    _rubberBand = RubberBandController(
      vsync: this,
      onDisplayUpdate: _onDisplayPositionUpdate,
    );

    // Read GameCoordinator — it's already started by the provider.
    _gameCoordinator = ref.read(gameCoordinatorProvider);

    // Wire exploration-disabled banner.
    _gameCoordinator.onExplorationDisabledChanged = (disabled) {
      if (mounted) setState(() => _showExplorationBanner = disabled);
    };

    // Subscribe to raw GPS updates to feed the rubber-band.
    _rawGpsSubscription =
        _gameCoordinator.onRawGpsUpdate.listen(_onRawGpsUpdate);

    // When enrichment completes, fetch the saved LocationNode and push it into
    // the fog overlay cache so territory borders update without an app restart.
    // Save reference to field — ref.read() in dispose() is unsafe (Bad state: Using ref).
    _locationEnrichmentService = ref.read(locationEnrichmentServiceProvider);
    _locationEnrichmentService.onLocationEnriched = (cellId, locationId) {
      if (!mounted) return;
      ref.read(locationNodeRepositoryProvider).get(locationId).then((node) {
        if (node != null && mounted) {
          ref.read(fogOverlayControllerProvider).addLocationNode(node);
        }
      }).catchError((Object e) {
        debugPrint('[MapScreen] failed to load location node $locationId: $e');
      });

      // Trigger admin boundary fetch when enrichment resolves — the district
      // locationId may have changed, so requestBoundaries will check and fetch
      // polygon data if needed (deduplicates internally by location).
      final cellService = ref.read(cellServiceProvider);
      final center = cellService.getCellCenter(cellId);
      _adminBoundaryService?.requestBoundaries(center.lat, center.lon);
    };

    // Wire admin boundary service — fetch polygons on district change.
    _adminBoundaryService = ref.read(adminBoundaryServiceProvider);
    _adminBoundaryService?.onBoundariesResolved = (nodeIds) {
      if (!mounted) return;
      _rebuildAdminBoundaryGeoJson();
    };
  }

  @override
  void dispose() {
    _gameCoordinator.onExplorationDisabledChanged = null;
    _locationEnrichmentService.onLocationEnriched = null;
    _adminBoundaryService?.onBoundariesResolved = null;
    _rubberBand.dispose();
    _markerPosition.dispose();
    _rawGpsSubscription?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Fog layer management (MapLibre native GeoJSON layers)
  // ---------------------------------------------------------------------------

  /// Adds the fog GeoJSON sources and fill layers to the map.
  ///
  /// Called once in [_onStyleLoaded]. The layers are:
  /// - `fog-base`: opaque world polygon with holes for revealed cells
  /// - `fog-mid`: semi-transparent fill for hidden/concealed cells
  ///
  /// After initialization, [_updateFogSources] updates the GeoJSON data
  /// on camera moves and location changes.
  Future<void> _initFogLayers() async {
    final controller = _mapController;
    if (controller == null || _fogLayersInitialized) return;

    try {
      // Admin boundary fills: polygon fills for admin regions.
      // Added BEFORE fog layers so they render below the fog.
      await controller.addSource(
        GeoJsonSource(
            id: _adminBoundaryFillSrcId,
            data: AdminBoundaryGeoJsonBuilder.emptyFeatureCollection),
      );
      await controller.addLayer(FillLayer(
        id: _adminBoundaryFillLayerId,
        sourceId: _adminBoundaryFillSrcId,
        paint: {
          'fill-color': [
            'coalesce',
            ['get', 'color'],
            '#888888'
          ],
          'fill-opacity': [
            'coalesce',
            ['get', 'opacity'],
            0.0
          ],
        },
      ));

      // Admin boundary lines: outlines for admin regions.
      await controller.addSource(
        GeoJsonSource(
            id: _adminBoundaryLinesSrcId,
            data: AdminBoundaryGeoJsonBuilder.emptyFeatureCollection),
      );
      await controller.addLayer(LineLayer(
        id: _adminBoundaryLinesLayerId,
        sourceId: _adminBoundaryLinesSrcId,
        paint: {
          'line-color': [
            'coalesce',
            ['get', 'color'],
            '#888888'
          ],
          'line-width': [
            'coalesce',
            ['get', 'line_weight'],
            1.0
          ],
          'line-dasharray': [6.0, 3.0],
          'line-opacity': 0.7,
        },
      ));

      // Base fog: opaque world polygon (holes punched for revealed cells).
      await controller.addSource(
        GeoJsonSource(id: _fogBaseSrcId, data: FogGeoJsonBuilder.fullWorldFog),
      );
      await controller.addLayer(FillLayer(
        id: _fogBaseLayerId,
        sourceId: _fogBaseSrcId,
        paint: {'fill-color': '#161620', 'fill-opacity': 1.0},
      ));

      // Mid fog: semi-transparent polygons for hidden/concealed cells.
      await controller.addSource(
        GeoJsonSource(
            id: _fogMidSrcId, data: FogGeoJsonBuilder.emptyFeatureCollection),
      );
      await controller.addLayer(FillLayer(
        id: _fogMidLayerId,
        sourceId: _fogMidSrcId,
        paint: {
          'fill-color': '#161620',
          // Use data-driven opacity from the 'density' property on each Feature.
          'fill-opacity': ['get', 'density'],
        },
      ));

      // Unexplored cell borders: line outlines on top of the opaque base fog.
      // Gives the player a hint that cells are nearby without revealing content.
      await controller.addSource(
        GeoJsonSource(
            id: _fogBorderSrcId,
            data: FogGeoJsonBuilder.emptyFeatureCollection),
      );
      await controller.addLayer(LineLayer(
        id: _fogBorderLayerId,
        sourceId: _fogBorderSrcId,
        paint: {
          'line-color': '#4a5568',
          'line-width': 1.0,
          'line-opacity': ['get', 'opacity'],
        },
      ));

      // Territory border fill: gradient polygons near admin boundaries.
      await controller.addSource(
        GeoJsonSource(
            id: _borderFillSrcId,
            data: TerritoryBorderGeoJsonBuilder.emptyFeatureCollection),
      );
      await controller.addLayer(FillLayer(
        id: _borderFillLayerId,
        sourceId: _borderFillSrcId,
        paint: {
          'fill-color': ['get', 'region_color_country'],
          'fill-opacity': [
            'interpolate',
            ['linear'],
            [
              'coalesce',
              ['get', 'border_distance_country'],
              3
            ],
            0,
            0.15,
            1,
            0.04,
            2,
            0.01,
            3,
            0.0,
          ],
        },
      ));

      // Territory border lines: colored edges at admin boundaries.
      await controller.addSource(
        GeoJsonSource(
            id: _borderLinesSrcId,
            data: TerritoryBorderGeoJsonBuilder.emptyFeatureCollection),
      );
      await controller.addLayer(LineLayer(
        id: _borderLinesLayerId,
        sourceId: _borderLinesSrcId,
        paint: {
          'line-color': ['get', 'border_color'],
          'line-width': ['get', 'line_weight'],
          'line-opacity': 0.7,
        },
      ));

      // Cell property icons: Point features rendered as symbols.
      await controller.addSource(
        GeoJsonSource(
            id: _cellIconsSrcId,
            data: CellPropertyGeoJsonBuilder.emptyFeatureCollection),
      );
      await controller.addLayer(SymbolLayer(
        id: _cellIconsLayerId,
        sourceId: _cellIconsSrcId,
        layout: {
          'icon-image': ['get', 'icon'],
          'icon-size': 0.4,
          'icon-allow-overlap': true,
          'icon-ignore-placement': true,
          'icon-offset': ['get', 'offset'],
        },
      ));

      // Register emoji images asynchronously (non-blocking).
      _registerIconImages(controller);

      _fogLayersInitialized = true;
      MapLogger.fogLayersInitialized();
    } catch (e, stack) {
      MapLogger.fogLayersInitError(e, stack);
    }
  }

  /// Registers all cell property emoji images with MapLibre.
  ///
  /// Called once during [_initFogLayers]. Each emoji is rendered to PNG via
  /// [MapIconRenderer] and registered with `addImage()`. The SymbolLayer
  /// references these by ID (e.g., "habitat-forest", "climate-tropic").
  Future<void> _registerIconImages(MapController controller) async {
    if (_iconImagesRegistered) return;

    final totalIcons = Habitat.values.length +
        Climate.values.length +
        CellEventType.values.length +
        1; // +1 for unknown
    MapLogger.iconRegistrationStarted(totalIcons);

    var succeeded = 0;
    var failed = 0;

    // Habitat icons (7).
    for (final habitat in Habitat.values) {
      try {
        final bytes =
            await MapIconRenderer.renderEmoji(GameIcons.habitat(habitat));
        await controller.addImage(
          MapIconRenderer.habitatIconId(habitat.name),
          bytes,
        );
        succeeded++;
        MapLogger.iconRegistered(MapIconRenderer.habitatIconId(habitat.name));
      } catch (e) {
        failed++;
        MapLogger.iconRegistrationFailed(
            MapIconRenderer.habitatIconId(habitat.name), e);
      }
    }

    // Climate icons (4).
    for (final climate in Climate.values) {
      try {
        final bytes =
            await MapIconRenderer.renderEmoji(GameIcons.climate(climate));
        await controller.addImage(
          MapIconRenderer.climateIconId(climate.name),
          bytes,
        );
        succeeded++;
        MapLogger.iconRegistered(MapIconRenderer.climateIconId(climate.name));
      } catch (e) {
        failed++;
        MapLogger.iconRegistrationFailed(
            MapIconRenderer.climateIconId(climate.name), e);
      }
    }

    // Event icons (2 + unknown).
    for (final eventType in CellEventType.values) {
      try {
        final bytes =
            await MapIconRenderer.renderEmoji(GameIcons.cellEvent(eventType));
        await controller.addImage(
          MapIconRenderer.eventIconId(eventType.name),
          bytes,
        );
        succeeded++;
        MapLogger.iconRegistered(MapIconRenderer.eventIconId(eventType.name));
      } catch (e) {
        failed++;
        MapLogger.iconRegistrationFailed(
            MapIconRenderer.eventIconId(eventType.name), e);
      }
    }

    // Unknown event icon.
    try {
      final unknownBytes =
          await MapIconRenderer.renderEmoji(GameIcons.eventUnknown);
      await controller.addImage(MapIconRenderer.eventUnknownId, unknownBytes);
      succeeded++;
      MapLogger.iconRegistered(MapIconRenderer.eventUnknownId);
    } catch (e) {
      failed++;
      MapLogger.iconRegistrationFailed(MapIconRenderer.eventUnknownId, e);
    }

    MapLogger.iconRegistrationComplete(succeeded, failed);

    // Set flag even with partial failures — successfully registered icons
    // should render. MapLibre silently skips unregistered image references.
    _iconImagesRegistered = true;
  }

  /// Updates the fog GeoJSON sources with new data from the controller.
  ///
  /// All three sources are dispatched simultaneously via [Future.wait] to
  /// prevent a single-frame flash where the base fog has holes punched but
  /// the mid fog fill hasn't been applied yet.
  Future<void> _updateFogSources() async {
    final controller = _mapController;
    if (controller == null || !_fogLayersInitialized) return;

    final fogOverlayController = ref.read(fogOverlayControllerProvider);

    MapLogger.fogUpdateStarted();
    try {
      await Future.wait([
        controller.updateGeoJsonSource(
          id: _adminBoundaryFillSrcId,
          data: fogOverlayController.adminBoundaryFillGeoJson,
        ),
        controller.updateGeoJsonSource(
          id: _adminBoundaryLinesSrcId,
          data: fogOverlayController.adminBoundaryLinesGeoJson,
        ),
        controller.updateGeoJsonSource(
          id: _fogBaseSrcId,
          data: fogOverlayController.baseFogGeoJson,
        ),
        controller.updateGeoJsonSource(
          id: _fogMidSrcId,
          data: fogOverlayController.midFogGeoJson,
        ),
        controller.updateGeoJsonSource(
          id: _fogBorderSrcId,
          data: fogOverlayController.cellBorderGeoJson,
        ),
        controller.updateGeoJsonSource(
          id: _borderFillSrcId,
          data: fogOverlayController.borderFillGeoJson,
        ),
        controller.updateGeoJsonSource(
          id: _borderLinesSrcId,
          data: fogOverlayController.borderLinesGeoJson,
        ),
        if (_iconImagesRegistered)
          controller.updateGeoJsonSource(
            id: _cellIconsSrcId,
            data: fogOverlayController.cellIconsGeoJson,
          ),
      ]);
      MapLogger.fogUpdateCompleted();
    } catch (e, stack) {
      MapLogger.fogUpdateError(e, stack);
    }
  }

  // ---------------------------------------------------------------------------
  // Zoom-to-fit
  // ---------------------------------------------------------------------------

  /// Applies the current [_zoomLevel] preset to the camera.
  void _applyZoomLevel() {
    switch (_zoomLevel) {
      case ZoomLevel.player:
        _zoomToFitPlayer();
      case ZoomLevel.world:
        _zoomToFitExplored();
    }
  }

  /// Fits the camera to the current cell + all adjacent cells.
  ///
  /// If the fog resolver has no current cell yet, falls back to the default
  /// camera position (no-op).
  void _zoomToFitPlayer() {
    final controller = _mapController;
    if (controller == null) return;

    final fogResolver = ref.read(fogResolverProvider);
    final currentCellId = fogResolver.currentCellId;
    if (currentCellId == null) return;

    final cellService = ref.read(cellServiceProvider);
    final neighborIds = fogResolver.currentNeighborIds;

    var minLat = 90.0;
    var maxLat = -90.0;
    var minLon = 180.0;
    var maxLon = -180.0;

    void expandBounds(String cellId) {
      final center = cellService.getCellCenter(cellId);
      if (center.lat < minLat) minLat = center.lat;
      if (center.lat > maxLat) maxLat = center.lat;
      if (center.lon < minLon) minLon = center.lon;
      if (center.lon > maxLon) maxLon = center.lon;
    }

    expandBounds(currentCellId);
    for (final id in neighborIds) {
      expandBounds(id);
    }

    // Padding around the neighborhood (~200m in lat/lon).
    const pad = 0.002;
    minLat -= pad;
    maxLat += pad;
    minLon -= pad;
    maxLon += pad;

    final oldZoom = _currentZoom;
    controller.fitBounds(
      bounds: LngLatBounds(
        longitudeWest: minLon,
        longitudeEast: maxLon,
        latitudeSouth: minLat,
        latitudeNorth: maxLat,
      ),
      padding: const EdgeInsets.all(50),
      // Instant snap — same as player zoom, prevents rubber-band from
      // cancelling mid-animation and causing zoom drift.
      nativeDuration: Duration.zero,
    );
    // Capture the resulting zoom so subsequent moveCamera calls preserve it.
    try {
      _currentZoom = controller.getCamera().zoom;
    } catch (e) {
      MapLogger.getCameraError('_zoomToFitPlayer', e);
    }
    MapLogger.zoomChanged(oldZoom, _currentZoom, 'fitExplored');
  }

  /// Fits the camera to the bounding box of all hidden cells (previously
  /// visited cells that are not the current cell).
  ///
  /// Falls back to player zoom if no hidden cells exist yet.
  void _zoomToFitExplored() {
    final controller = _mapController;
    if (controller == null) return;

    final fogResolver = ref.read(fogResolverProvider);
    final currentCellId = fogResolver.currentCellId;
    final cellService = ref.read(cellServiceProvider);

    // Only include cells that resolve as hidden (visited but not current).
    final hiddenCells =
        fogResolver.visitedCellIds.where((id) => id != currentCellId).toList();

    // If there are no hidden cells yet, fall back to player view.
    if (hiddenCells.isEmpty) {
      _zoomToFitPlayer();
      return;
    }

    var minLat = 90.0;
    var maxLat = -90.0;
    var minLon = 180.0;
    var maxLon = -180.0;

    // Include hidden cells + current cell so the player is always in frame.
    void expandBounds(String cellId) {
      final center = cellService.getCellCenter(cellId);
      if (center.lat < minLat) minLat = center.lat;
      if (center.lat > maxLat) maxLat = center.lat;
      if (center.lon < minLon) minLon = center.lon;
      if (center.lon > maxLon) maxLon = center.lon;
    }

    for (final cellId in hiddenCells) {
      expandBounds(cellId);
    }
    if (currentCellId != null) expandBounds(currentCellId);

    // Add padding around the bounding box (~500m in lat/lon).
    const pad = 0.005;
    minLat -= pad;
    maxLat += pad;
    minLon -= pad;
    maxLon += pad;

    controller.fitBounds(
      bounds: LngLatBounds(
        longitudeWest: minLon,
        longitudeEast: maxLon,
        latitudeSouth: minLat,
        latitudeNorth: maxLat,
      ),
      padding: const EdgeInsets.all(50),
      // Instant snap — same as player zoom, prevents rubber-band from
      // cancelling mid-animation and causing zoom drift.
      nativeDuration: Duration.zero,
    );
  }

  // ---------------------------------------------------------------------------
  // Location handling — pure rendering, no game logic
  // ---------------------------------------------------------------------------

  /// Handles raw GPS updates from GameCoordinator.
  ///
  /// ONLY feeds the rubber-band controller. All game logic (fog, discovery,
  /// stats) runs inside GameCoordinator, triggered by `updatePlayerPosition`.
  void _onRawGpsUpdate(({Geographic position, double accuracy}) update) {
    if (!mounted) return;

    MapLogger.locationUpdate(
      update.position.lat,
      update.position.lon,
      source: _gameCoordinator.isRealGps ? 'realGps' : 'simulated',
    );

    _rubberBand.setTarget(update.position.lat, update.position.lon);
  }

  /// Called at ~60 fps by the rubber-band controller with the interpolated
  /// display position.
  ///
  /// 1. Marker widget position (60 fps)
  /// 2. Camera position (60 fps)
  /// 3. Game logic via GameCoordinator (throttled to ~10 Hz internally)
  /// 4. Fog rendering (~10 Hz, throttled locally)
  void _onDisplayPositionUpdate(double lat, double lon) {
    if (!mounted) return;

    MapLogger.displayPositionUpdate(lat, lon);

    // 1. Update marker position via ValueNotifier (60 fps smooth, no full rebuild).
    _markerPosition.value = (lat: lat, lon: lon);

    // 2. Move camera to the interpolated position (instant snap).
    final cameraController = ref.read(cameraControllerProvider);
    cameraController.onLocationUpdate(lat, lon);

    // 3. Feed player position to GameCoordinator (60 fps — coordinator
    //    throttles internally to ~10 Hz for game logic).
    _gameCoordinator.updatePlayerPosition(lat, lon);

    // 4. Fog rendering (~10 Hz, throttled locally).
    _renderFrame++;
    if (_renderFrame == 1 || _renderFrame % _kRenderInterval == 0) {
      _updateFogRendering(lat, lon);
    }
  }

  /// Recomputes fog overlay and updates MapLibre GeoJSON sources.
  ///
  /// Called at ~10 Hz from `_onDisplayPositionUpdate`. Separated from game
  /// logic (which runs in GameCoordinator) because fog rendering needs
  /// MapLibre controller access which is widget-layer only.
  void _updateFogRendering(double lat, double lon) {
    if (!mounted) return;

    final mapState = ref.read(mapStateProvider);
    if (mapState.isReady && _mapController != null) {
      final MapCamera camera;
      try {
        camera = _mapController!.getCamera();
      } catch (e) {
        MapLogger.getCameraError('_updateFogRendering', e);
        return;
      }

      final fogOverlayController = ref.read(fogOverlayControllerProvider);

      // Feed cell properties + daily seed for icon rendering.
      fogOverlayController.cellPropertiesCache =
          _gameCoordinator.cellPropertiesCache;
      final seedState = ref.read(dailySeedServiceProvider).currentSeed;
      fogOverlayController.dailySeed = seedState?.seed ?? '';

      // Lazy-load location nodes for territory border rendering.
      if (!_locationNodesLoaded) {
        _locationNodesLoaded = true;
        _loadLocationNodes();
      }
      fogOverlayController.locationNodesCache = _locationNodesMap;

      fogOverlayController.update(
        cameraLat: camera.center.lat.toDouble(),
        cameraLon: camera.center.lng.toDouble(),
        zoom: camera.zoom,
        viewportSize: MediaQuery.of(context).size,
      );
      ref.read(mapStateProvider.notifier).updateCameraPosition(lat, lon);
      _updateFogSources();
    }
  }

  /// Loads all location nodes from the database and caches them.
  ///
  /// Called lazily on the first fog render frame. Runs async but the map
  /// continues rendering without borders until the load completes (same
  /// pattern as cell properties lazy loading).
  Future<void> _loadLocationNodes() async {
    if (!mounted) return;

    try {
      final repo = ref.read(locationNodeRepositoryProvider);
      final nodes = await repo.getAll();
      if (!mounted) return;
      _locationNodesMap = {for (final n in nodes) n.id: n};
      MapLogger.locationNodesLoaded(_locationNodesMap.length);
    } catch (e) {
      MapLogger.locationNodesLoadError(e);
    }
  }

  /// Rebuilds admin boundary GeoJSON from the repository and pushes to map.
  ///
  /// Called EVENT-DRIVEN when [AdminBoundaryService.onBoundariesResolved] fires.
  /// Loads all location nodes from the repository, feeds them to the fog
  /// overlay controller, then schedules a fog source update on the next frame.
  Future<void> _rebuildAdminBoundaryGeoJson() async {
    if (!mounted) return;

    try {
      final repo = ref.read(locationNodeRepositoryProvider);
      final nodes = await repo.getAll();
      if (!mounted) return;

      final nodesMap = <String, LocationNode>{for (final n in nodes) n.id: n};
      ref.read(fogOverlayControllerProvider).updateAdminBoundaries(nodesMap);
      _updateFogSources();
    } catch (e) {
      debugPrint('[MapScreen] _rebuildAdminBoundaryGeoJson failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // MapLibre callbacks
  // ---------------------------------------------------------------------------

  void _onMapCreated(MapController controller) {
    MapLogger.mapCreated();
    _mapController = controller;
    final cameraController = ref.read(cameraControllerProvider);

    cameraController.onCameraMove = (lat, lon) {
      // Position(lng, lat) — longitude first!
      // Use moveCamera (jumpTo on web) instead of animateCamera (flyTo).
      // The rubber-band controller calls this at 60 fps — animateCamera
      // starts a new flyTo animation each frame which causes cascading
      // errors in MapLibre's web runtime. moveCamera is an instant jump
      // with no animation overhead, perfect for high-frequency updates.
      //
      // CRITICAL: Always pass zoom explicitly. When zoom is null in the
      // Dart→JS interop, MapLibre GL JS may receive `zoom: null` (not
      // `undefined`), which can reset zoom to a default. We read the
      // map's ACTUAL current zoom and pass it back — this prevents both
      // the null→blowout AND jitter from forcing a hardcoded value.
      try {
        final actualZoom = controller.getCamera().zoom;
        MapLogger.cameraMove(lat, lon, zoom: actualZoom);
        controller.moveCamera(
          center: Position(lon, lat),
          zoom: actualZoom,
        );
      } catch (e, stack) {
        MapLogger.cameraMoveError(lat, lon, e, stack);
      }
    };
  }

  void _onStyleLoaded() {
    MapLogger.styleLoaded();
    _removeTextLabels();
    // NOTE: markReady() is deliberately NOT called here.
    // It moves to _after_ fog initialization below, so that
    // _updateFogRendering() doesn't try to update fog sources
    // before the layers exist.

    _initFogAndReveal();
  }

  /// Initializes fog layers, computes initial fog state, updates sources,
  /// then marks the map ready.
  ///
  /// Extracted from [_onStyleLoaded] so the async flow is explicit.
  /// The map is only shown after auth + hydration complete (sequential boot),
  /// so no hide/reveal hack or safety timeout is needed.
  Future<void> _initFogAndReveal() async {
    if (!mounted) return;

    MapLogger.fogInitStart();

    try {
      // Capture viewport size synchronously before any async gap.
      final viewportSize = MediaQuery.of(context).size;

      await _initFogLayers();
      if (!mounted || _mapController == null) return;
      MapLogger.fogInitLayersReady();

      final fogOverlayController = ref.read(fogOverlayControllerProvider);

      // getCamera() can throw if the map controller is in a bad state.
      final MapCamera camera;
      try {
        camera = _mapController!.getCamera();
      } catch (e) {
        MapLogger.getCameraError('_initFogAndReveal', e);
        _markMapReady();
        return;
      }

      // Compute initial fog state. Skip onBatchReady callback — we call
      // _updateFogSources() once after updateAsync completes, avoiding the
      // previous double-fire that could flash partial fog data.
      await fogOverlayController.updateAsync(
        cameraLat: camera.center.lat.toDouble(),
        cameraLon: camera.center.lng.toDouble(),
        zoom: camera.zoom,
        viewportSize: viewportSize,
      );
      if (!mounted) return;
      MapLogger.fogInitDataComputed();

      await _updateFogSources();
      if (!mounted) return;
      MapLogger.fogInitSourcesApplied();

      // Mark the map ready — gates _updateFogRendering fog updates.
      _markMapReady();

      MapLogger.fogInitComplete();

      // Trigger an initial admin boundary request for the current player
      // position so borders load even for returning players who won't visit
      // any new cells (onCellVisited alone is insufficient for 145+ cell users).
      final playerPos = ref.read(locationProvider).currentPosition;
      if (playerPos != null && mounted) {
        _adminBoundaryService?.requestBoundaries(
          playerPos.lat.toDouble(),
          playerPos.lon.toDouble(),
        );
      }
    } catch (e, stack) {
      MapLogger.fogInitFailed(e, stack);
      // On error, still mark ready so the base map is usable.
      _markMapReady();
    }
  }

  /// Marks the map ready (gates fog rendering updates) and forces a player
  /// marker repaint so the marker position is correct after the first render.
  void _markMapReady() {
    if (!mounted) return;

    ref.read(mapStateProvider.notifier).markReady();

    // Force player marker repaint after fog initialization.
    // Ensures the marker recalculates its screen position after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final currentPos = _markerPosition.value;
      if (currentPos != null) {
        _markerPosition.value = null;
        _markerPosition.value = currentPos;
      }
    });
  }

  /// Strips all symbol (text/icon) layers from the map style.
  void _removeTextLabels() {
    final controller = _mapController;
    if (controller == null) return;

    const symbolLayerIds = [
      'waterway_line_label',
      'water_name_point_label',
      'water_name_line_label',
      'highway-name-path',
      'highway-name-minor',
      'highway-name-major',
      'highway-shield-non-us',
      'highway-shield-us-interstate',
      'road_shield_us',
      'airport',
      'label_other',
      'label_village',
      'label_town',
      'label_state',
      'label_city',
      'label_city_capital',
      'label_country_3',
      'label_country_2',
      'label_country_1',
    ];

    for (final id in symbolLayerIds) {
      try {
        controller.removeLayer(id);
      } catch (_) {
        // Layer may not exist if style changes — ignore.
      }
    }
  }

  void _onMapEvent(MapEvent event) {
    // Fog GeoJSON layers are geo-pinned — they render correctly at any
    // camera position without being recomputed. Only location changes
    // (in _onDisplayPositionUpdate) need to rebuild fog state. Updating fog
    // sources here on every MapEventMoveCamera caused a feedback loop:
    //   animateCamera → MapEventMoveCamera → updateFogSources → MapLibre
    //   layout → new MapEventMoveCamera → repeat (zoom jitter).
    //
    // Only MapEventLongClick triggers cell selection — tap is reserved for
    // future interactions (e.g. species, markers). Long press shows cell details.
    if (event is MapEventLongClick) {
      // MapLibre Position is (lng, lat) — longitude first.
      // event.point.lat/lng return num, so cast to double for getCellId.
      final lat = event.point.lat.toDouble();
      final lon = event.point.lng.toDouble();
      final cellService = ref.read(cellServiceProvider);
      final cellId = cellService.getCellId(lat, lon);
      _onCellTapped(cellId);
    }
  }

  /// Called when the user long-presses the map and a cell ID has been resolved.
  ///
  /// Stores the selected cell in [cellSelectionProvider] (for external
  /// observers) and shows the exploration bottom sheet.
  void _onCellTapped(String cellId) {
    debugPrint('[TAP] Cell tapped: $cellId');
    ref.read(cellSelectionProvider.notifier).select(cellId);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => CellInfoSheet(cellId: cellId),
    ).whenComplete(() {
      // Clear selection when sheet is dismissed (swipe or pop).
      ref.read(cellSelectionProvider.notifier).clear();
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Read (not watch) mapState to avoid rebuilds on every camera move.
    // The DebugHud receives mapState as a parameter; no widget needs
    // reactive zoom tracking.
    final mapState = ref.read(mapStateProvider);
    final cameraMode = ref.watch(cameraModeProvider);
    final fogOverlayController = ref.read(fogOverlayControllerProvider);
    final fogResolver = ref.read(fogResolverProvider);

    return ErrorBoundary(
      onError: (_) => _MapErrorFallback(),
      child: Scaffold(
        body: Stack(
          children: [
            // ── Layer 0: Fog-colored backdrop ─────────────────────────────────
            // Provides the dark background color while the map tiles load.
            Container(color: const Color(0xFF161620)),

            // ── Layer 1: MapLibre base map + native fog fill layers ────────────
            MapLibreMap(
              options: MapOptions(
                initStyle: 'https://tiles.openfreemap.org/styles/positron',
                initZoom: kDefaultZoom,
                initCenter: Position(kDefaultMapLon, kDefaultMapLat),
                minZoom: kMinZoom,
                maxZoom: kMaxZoom,
                attribution: false,
                nativeLogo: false,
                // Disable pitch (tilt) — we never use it, and it's a 2D game.
                // This also disables MapLibre's built-in KeyboardHandler (which
                // requires allEnabled=true). Without this, arrow keys are
                // processed by BOTH our KeyboardLocationService AND MapLibre's
                // native pan handler, causing rapid oscillation when opposing
                // keys are held or jitter during normal movement.
                gestures: const MapGestures.all(pitch: false),
              ),
              onMapCreated: _onMapCreated,
              onStyleLoaded: _onStyleLoaded,
              onEvent: _onMapEvent,
              children: [
                // ── Layer 2: Player marker (geo-anchored to display position) ─
                // PlayerMarkerLayer uses ValueListenableBuilder internally so
                // only it rebuilds on each 60fps rubber-band update — the rest
                // of MapScreen stays stable.
                PlayerMarkerLayer(position: _markerPosition),
              ],
            ),

            // ── Layer 3: Status bar ────────────────────────────────────────────
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: StatusBar(),
            ),

            // ── Layer 3.5: Discovery notification overlay ─────────────────────
            Positioned(
              top: MediaQuery.of(context).padding.top + 64,
              left: 16,
              right: 16,
              child: const DiscoveryNotificationOverlay(),
            ),

            // ── Layer 3.6: Location permission banner ─────────────────────────
            Positioned(
              top: MediaQuery.of(context).padding.top + 56,
              left: 0,
              right: 0,
              child: const LocationPermissionBanner(),
            ),

            // ── Layer 3.7: Low accuracy indicator ─────────────────────────────
            // Scoped Consumer so locationProvider rebuilds only this indicator,
            // not the full MapScreen tree.
            Positioned(
              bottom: 72,
              left: 0,
              right: 0,
              child: Consumer(
                builder: (context, ref, child) {
                  final locationError = ref.watch(
                    locationProvider.select((s) => s.locationError),
                  );
                  if (locationError != LocationError.lowAccuracy) {
                    return const SizedBox.shrink();
                  }
                  return Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF59E0B)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.gps_not_fixed_rounded,
                            size: 14,
                            color: Color(0xFFB45309),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'GPS accuracy is poor (>${kGpsAccuracyThreshold.toInt()} m)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Layer 3.75: Exploration disabled banner ─────────────────────
            if (_showExplorationBanner)
              const Positioned(
                bottom: 100,
                left: 0,
                right: 0,
                child: _ExplorationDisabledBanner(),
              ),

            // ── Layer 3.76: Sync toast overlay ────────────────────────────────
            const Positioned(
              bottom: 72,
              left: 0,
              right: 0,
              child: Center(
                child: SyncToastOverlay(),
              ),
            ),

            // ── Layer 3.8: Step recap animation overlay ─────────────────────
            // Centered horizontally, positioned in the lower third of the
            // screen. IgnorePointer so it never captures map touches.
            const Align(
              alignment: Alignment(0, 0.45),
              child: IgnorePointer(
                child: StepRecap(),
              ),
            ),

            // ── Layer 4: Debug HUD (toggle-able) ──────────────────────────────
            if (_showDebugHud)
              Positioned(
                left: 8,
                bottom: 80,
                child: DebugHud(
                  mapState: mapState,
                  visibleCells: fogOverlayController.renderData.length,
                  visitedCells: fogResolver.visitedCellIds.length,
                  cameraMode: cameraMode,
                ),
              ),

            // ── Layer 4.5: DPad controls (keyboard mode only) ────────────────
            // Visible on web when using keyboard movement. Hidden when
            // browser GPS is granted (activeModeNotifier switches to realGps).
            ValueListenableBuilder<LocationMode>(
              valueListenable:
                  ref.read(locationServiceProvider).activeModeNotifier,
              builder: (context, activeMode, child) {
                if (activeMode != LocationMode.keyboard) {
                  return const SizedBox.shrink();
                }
                return Positioned(
                  left: 16,
                  bottom: 16,
                  child: DPadControls(
                    keyboardService:
                        ref.read(locationServiceProvider).keyboardService!,
                  ),
                );
              },
            ),

            // ── Layer 5: Map controls (recenter + debug) ──────────────────────
            Positioned(
              right: 16,
              bottom: 16,
              child: MapControls(
                isWorldZoom: _zoomLevel == ZoomLevel.world,
                onRecenter: () {
                  final loc = ref.read(locationProvider);
                  final cameraController = ref.read(cameraControllerProvider);
                  if (loc.currentPosition != null) {
                    cameraController.recenter(
                      loc.currentPosition!.lat,
                      loc.currentPosition!.lon,
                    );
                  }
                  ref.read(cameraModeProvider.notifier).setFollowing();
                },
                onToggleZoom: () {
                  setState(() {
                    _zoomLevel = _zoomLevel == ZoomLevel.player
                        ? ZoomLevel.world
                        : ZoomLevel.player;
                  });
                  _applyZoomLevel();
                },
                onToggleDebug: () =>
                    setState(() => _showDebugHud = !_showDebugHud),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Banner shown when exploration is disabled because the player marker is in a
/// different cell than the real GPS position (moving too fast for exploration).
class _ExplorationDisabledBanner extends StatelessWidget {
  const _ExplorationDisabledBanner();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFEF4444)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.speed_rounded,
              size: 16,
              color: Color(0xFFDC2626),
            ),
            SizedBox(width: 8),
            Text(
              'MOVING TOO FAST, EXPLORATION IS CURRENTLY DISABLED',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF991B1B),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fallback shown by [ErrorBoundary] if the map screen's widget tree crashes.
class _MapErrorFallback extends StatelessWidget {
  const _MapErrorFallback();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🗺️', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 20),
              Text(
                'Map unavailable',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Something went wrong loading the map.\nYour progress is safe.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
