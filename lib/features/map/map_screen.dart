import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre/maplibre.dart';

import 'package:fog_of_world/core/state/cell_service_provider.dart';
import 'package:fog_of_world/core/state/fog_resolver_provider.dart';
import 'package:fog_of_world/core/state/location_provider.dart';
import 'package:fog_of_world/core/state/player_provider.dart';
import 'package:fog_of_world/features/discovery/providers/discovery_provider.dart';
import 'package:fog_of_world/features/discovery/widgets/discovery_notification.dart';
import 'package:fog_of_world/features/location/services/location_service.dart';
import 'package:fog_of_world/features/location/services/location_simulator.dart';
import 'package:fog_of_world/features/location/services/real_gps_service.dart';
import 'package:fog_of_world/features/location/widgets/location_permission_banner.dart';
import 'package:fog_of_world/features/map/controllers/rubber_band_controller.dart';
import 'package:fog_of_world/features/map/layers/player_marker_widget.dart';
import 'package:fog_of_world/features/map/providers/camera_controller_provider.dart';
import 'package:fog_of_world/features/map/providers/camera_mode_provider.dart';
import 'package:fog_of_world/features/map/providers/discovery_service_provider.dart';
import 'package:fog_of_world/features/map/providers/fog_overlay_controller_provider.dart';
import 'package:fog_of_world/features/map/providers/location_service_provider.dart';
import 'package:fog_of_world/features/map/providers/map_state_provider.dart';
import 'package:fog_of_world/features/map/utils/fog_geojson_builder.dart';
import 'package:fog_of_world/features/map/utils/map_logger.dart';
import 'package:fog_of_world/features/map/widgets/debug_hud.dart';
import 'package:fog_of_world/features/map/widgets/dpad_controls.dart';
import 'package:fog_of_world/features/map/widgets/map_controls.dart';
import 'package:fog_of_world/features/map/widgets/status_bar.dart';
import 'package:fog_of_world/shared/constants.dart';
import 'package:fog_of_world/shared/widgets/error_boundary.dart';

/// Fixed zoom presets for the map camera.
enum ZoomLevel {
  /// Fits the current cell + all adjacent cells into the viewport.
  player,

  /// Fits all explored (visited) cells into the viewport.
  world,
}

/// Main map screen — the primary game view.
///
/// Composes all map-phase layers in a [Stack]:
/// 1. MapLibre base map (tiles) + native fog fill layers
/// 2. [PlayerMarkerWidget] geo-anchored via [WidgetLayer]
/// 3. [StatusBar] translucent top panel
/// 4. [DebugHud] toggle-able diagnostics overlay
/// 5. [MapControls] recenter + debug FABs (bottom-right)
///
/// Fog is rendered as 2 MapLibre native GeoJSON fill layers that are
/// geo-pinned to the map at 60 fps GPU-accelerated. This eliminates the
/// Canvas overlay drift problem entirely.
///
/// ## MapLibre API notes
/// - `Position(lng, lat)` — longitude FIRST, latitude second.
/// - `MapCamera.center.lng` — longitude; `.lat` — latitude.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with TickerProviderStateMixin {
  MapController? _mapController;

  // Saved in initState so dispose() can stop without ref.read() (unsafe after unmount).
  late final LocationService _locationService;

  /// Rubber-band interpolation controller. Decouples the visible marker
  /// position from raw GPS coordinates and drives 60fps camera + marker
  /// updates via a Ticker.
  late final RubberBandController _rubberBand;

  /// Interpolated display position for the player marker (updated at 60fps).
  /// Null until the first GPS fix arrives.
  double? _displayLat;
  double? _displayLon;

  StreamSubscription<SimulatedLocation>? _locationSubscription;
  StreamSubscription<dynamic>? _discoverySubscription;
  StreamSubscription<dynamic>? _fogCellSubscription;

  bool _showDebugHud = false;

  /// Current zoom preset. Defaults to player-level (tight around current cell).
  ZoomLevel _zoomLevel = ZoomLevel.player;

  /// Explicitly tracked zoom level. We ALWAYS pass this to moveCamera() to
  /// prevent MapLibre from resetting zoom when `zoom: null` is passed via
  /// JS interop (null ≠ undefined in Dart-JS interop — MapLibre may interpret
  /// null as "reset to default" instead of "preserve current").
  double _currentZoom = kDefaultZoom;

  /// Whether the MapLibre fog sources/layers have been added to the map.
  bool _fogLayersInitialized = false;

  // (Throttle fields removed — fog updates no longer run from _onMapEvent.)

  // -- MapLibre source/layer IDs for the fog system --
  static const _fogBaseSrcId = 'fog-base-src';
  static const _fogBaseLayerId = 'fog-base';
  static const _fogMidSrcId = 'fog-mid-src';
  static const _fogMidLayerId = 'fog-mid';
  static const _fogBorderSrcId = 'fog-border-src';
  static const _fogBorderLayerId = 'fog-border';

  @override
  void initState() {
    super.initState();

    _rubberBand = RubberBandController(
      vsync: this,
      onDisplayUpdate: _onDisplayPositionUpdate,
    );

    _locationService = ref.read(locationServiceProvider);
    _locationService.start();
    _locationSubscription =
        _locationService.filteredLocationStream.listen(_onLocationUpdate);

    _checkLocationPermission();

    final discoveryService = ref.read(discoveryServiceProvider);
    _discoverySubscription = discoveryService.onDiscovery.listen((event) {
      ref.read(discoveryProvider.notifier).showDiscovery(event);
    });

    // Wire fog resolver → player stats: increment cells observed on each new visit.
    final fogResolver = ref.read(fogResolverProvider);
    _fogCellSubscription = fogResolver.onVisitedCellAdded.listen((_) {
      ref.read(playerProvider.notifier).incrementCellsObserved();
    });
  }

  Future<void> _checkLocationPermission() async {
    final status = await _locationService.checkPermission();
    if (!mounted) return;

    final locationError = switch (status) {
      GpsPermissionStatus.denied => LocationError.permissionDenied,
      GpsPermissionStatus.deniedForever => LocationError.permissionDeniedForever,
      GpsPermissionStatus.serviceDisabled => LocationError.serviceDisabled,
      _ => LocationError.none,
    };

    if (locationError != LocationError.none) {
      ref.read(locationProvider.notifier).setError(locationError);
    }
  }

  @override
  void dispose() {
    _rubberBand.dispose();
    _locationSubscription?.cancel();
    _discoverySubscription?.cancel();
    _fogCellSubscription?.cancel();
    _locationService.stop();
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
            id: _fogMidSrcId,
            data: FogGeoJsonBuilder.emptyFeatureCollection),
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
          'line-opacity': 0.4,
        },
      ));

      _fogLayersInitialized = true;
      MapLogger.fogLayersInitialized();
    } catch (e, stack) {
      MapLogger.fogLayersInitError(e, stack);
    }
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
          id: _fogBaseSrcId,
          data: fogOverlayController.baseFogGeoJson,
        ),
        controller.updateGeoJsonSource(
          id: _fogMidSrcId,
          data: fogOverlayController.midFogGeoJson,
        ),
        controller.updateGeoJsonSource(
          id: _fogBorderSrcId,
          data: fogOverlayController.unexploredBorderGeoJson,
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
    _currentZoom = controller.getCamera().zoom;
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
    final hiddenCells = fogResolver.visitedCellIds
        .where((id) => id != currentCellId)
        .toList();

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
  // Location handling
  // ---------------------------------------------------------------------------

  /// Handles raw GPS / simulator location updates (1 Hz).
  ///
  /// Game logic (fog, discovery, stats) runs on the real GPS position.
  /// The visible marker + camera are driven by the rubber-band controller
  /// which interpolates at 60 fps toward this target.
  void _onLocationUpdate(SimulatedLocation loc) {
    MapLogger.locationUpdate(
      loc.position.lat,
      loc.position.lon,
      source: _locationService.mode.name,
    );
    final fogResolver = ref.read(fogResolverProvider);

    // 1. Update fog-of-war state (uses real GPS position).
    fogResolver.onLocationUpdate(loc.position.lat, loc.position.lon);

    // 2. Push real position into Riverpod location state.
    final locationNotifier = ref.read(locationProvider.notifier);
    locationNotifier.updateLocation(loc.position, loc.accuracy);

    // Only flag low accuracy for real GPS (not simulation / keyboard).
    if (_locationService.mode == LocationMode.realGps) {
      final currentError = ref.read(locationProvider).locationError;
      final isLowAccuracy = loc.accuracy > kGpsAccuracyThreshold;
      if (isLowAccuracy && currentError != LocationError.lowAccuracy) {
        locationNotifier.setError(LocationError.lowAccuracy);
      } else if (!isLowAccuracy && currentError == LocationError.lowAccuracy) {
        locationNotifier.setError(LocationError.none);
      }
    }

    // 3. Feed GPS target to rubber band (drives 60fps marker + camera).
    _rubberBand.setTarget(loc.position.lat, loc.position.lon);

    // 4. Recompute fog overlay if the map is ready.
    if (!mounted) return;
    final mapState = ref.read(mapStateProvider);
    if (mapState.isReady && _mapController != null) {
      final fogOverlayController = ref.read(fogOverlayControllerProvider);
      final camera = _mapController!.getCamera();
      fogOverlayController.update(
        cameraLat: camera.center.lat.toDouble(),
        cameraLon: camera.center.lng.toDouble(),
        zoom: camera.zoom,
        viewportSize: MediaQuery.of(context).size,
      );
      ref.read(mapStateProvider.notifier).updateCameraPosition(
            loc.position.lat,
            loc.position.lon,
          );
      _updateFogSources();

      // NOTE: Do NOT call _applyZoomLevel() here. Zoom is only set on
      // initial load and when the user taps the zoom toggle button.
      // Re-fitting on every cell change caused fitBounds to fight the
      // 60fps rubber-band camera centering, producing severe zoom jitter.
    }
  }

  /// Called at ~60 fps by the rubber-band controller with the interpolated
  /// display position. Moves the camera (instant snap) and triggers a
  /// marker rebuild via setState.
  void _onDisplayPositionUpdate(double lat, double lon) {
    if (!mounted) return;

    MapLogger.displayPositionUpdate(lat, lon);

    // Update display position for the marker widget.
    setState(() {
      _displayLat = lat;
      _displayLon = lon;
    });

    // Move camera instantly to the interpolated position (no animation
    // duration = no fighting between concurrent animateCamera calls).
    final cameraController = ref.read(cameraControllerProvider);
    cameraController.onLocationUpdate(lat, lon);
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
    ref.read(mapStateProvider.notifier).markReady();

    // Initialize fog layers, then compute initial fog and zoom to fit.
    // Capture viewport size synchronously before the async gap.
    final viewportSize = MediaQuery.of(context).size;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _mapController == null) return;

      await _initFogLayers();

      final fogOverlayController = ref.read(fogOverlayControllerProvider);
      final camera = _mapController!.getCamera();

      await fogOverlayController.updateAsync(
        cameraLat: camera.center.lat.toDouble(),
        cameraLon: camera.center.lng.toDouble(),
        zoom: camera.zoom,
        viewportSize: viewportSize,
        onBatchReady: () {
          if (mounted) _updateFogSources();
        },
      );

      if (mounted) {
        await _updateFogSources();
        // Do NOT call _applyZoomLevel() here. The map starts at kDefaultZoom
        // (15.0) which is correct for walking-speed exploration. fitBounds on
        // style load was causing the camera to zoom out to fit cell bounds,
        // which at the Voronoi cell scale (~200m) often overshoots wildly.
        // Zoom presets are only applied when the user presses the toggle.
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
    // (in _onLocationUpdate) need to rebuild fog state. Updating fog
    // sources here on every MapEventMoveCamera caused a feedback loop:
    //   animateCamera → MapEventMoveCamera → updateFogSources → MapLibre
    //   layout → new MapEventMoveCamera → repeat (zoom jitter).
    //
    // We keep the handler for future user gesture detection (free mode)
    // but no longer update fog or provider state from camera events.
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    // Read (not watch) mapState to avoid rebuilds on every camera move.
    // The DebugHud receives mapState as a parameter; no widget needs
    // reactive zoom tracking.
    final mapState = ref.read(mapStateProvider);
    final cameraMode = ref.watch(cameraModeProvider);
    final fogOverlayController = ref.read(fogOverlayControllerProvider);
    final fogResolver = ref.read(fogResolverProvider);
    // Use the interpolated display position for the marker (smooth 60fps).
    // Falls back to raw GPS position if rubber band hasn't started yet.
    final position = locationState.currentPosition;
    final markerLat = _displayLat ?? position?.lat;
    final markerLon = _displayLon ?? position?.lon;

    return ErrorBoundary(
      onError: (_) => const _MapErrorFallback(),
      child: Scaffold(
        body: Stack(
          children: [
          // ── Layer 1: MapLibre base map + native fog fill layers ────────────
          MapLibreMap(
            options: MapOptions(
              initStyle: 'https://tiles.openfreemap.org/styles/positron',
              initZoom: kDefaultZoom,
              initCenter: Position(kDefaultMapLon, kDefaultMapLat),
              minZoom: kMinZoom,
              maxZoom: kMaxZoom,
            ),
            onMapCreated: _onMapCreated,
            onStyleLoaded: _onStyleLoaded,
            onEvent: _onMapEvent,
            children: [
              // ── Layer 2: Player marker (geo-anchored to display position) ─
              if (markerLat != null && markerLon != null)
                WidgetLayer(
                  markers: [
                    Marker(
                      // Position(lng, lat) — longitude FIRST!
                      // Uses the rubber-band interpolated position (60fps smooth).
                      point: Position(markerLon, markerLat),
                      size: const Size(44, 44),
                      child: const PlayerMarkerWidget(size: 20),
                    ),
                  ],
                ),
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
          if (locationState.locationError == LocationError.lowAccuracy)
            Positioned(
              bottom: 72,
              left: 0,
              right: 0,
              child: Center(
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

          // ── Layer 4.5: DPad controls (web only) ──────────────────────────
          if (kIsWeb)
            Positioned(
              left: 16,
              bottom: 16,
              child: DPadControls(
                keyboardService:
                    ref.read(locationServiceProvider).keyboardService!,
              ),
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

/// Fallback shown by [ErrorBoundary] if the map screen's widget tree crashes.
class _MapErrorFallback extends StatelessWidget {
  const _MapErrorFallback();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1A1A2E),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🗺️', style: TextStyle(fontSize: 52)),
              SizedBox(height: 20),
              Text(
                'Map unavailable',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "Something went wrong loading the map.\nYour progress is safe.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9CA3AF),
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
