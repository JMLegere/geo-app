import 'dart:async';

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
import 'package:fog_of_world/features/map/layers/player_marker_widget.dart';
import 'package:fog_of_world/features/map/providers/camera_controller_provider.dart';
import 'package:fog_of_world/features/map/providers/camera_mode_provider.dart';
import 'package:fog_of_world/features/map/providers/discovery_service_provider.dart';
import 'package:fog_of_world/features/map/providers/fog_overlay_controller_provider.dart';
import 'package:fog_of_world/features/map/providers/location_service_provider.dart';
import 'package:fog_of_world/features/map/providers/map_state_provider.dart';
import 'package:fog_of_world/features/map/utils/fog_geojson_builder.dart';
import 'package:fog_of_world/features/map/widgets/debug_hud.dart';
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

class _MapScreenState extends ConsumerState<MapScreen> {
  MapController? _mapController;

  // Saved in initState so dispose() can stop without ref.read() (unsafe after unmount).
  late final LocationService _locationService;

  StreamSubscription<SimulatedLocation>? _locationSubscription;
  StreamSubscription<dynamic>? _discoverySubscription;
  StreamSubscription<dynamic>? _fogCellSubscription;

  bool _showDebugHud = false;

  /// Current zoom preset. Defaults to player-level (tight around current cell).
  ZoomLevel _zoomLevel = ZoomLevel.player;

  /// Tracks the last cell ID for which we applied a zoom fit, so we only
  /// re-fit when the player enters a new cell (not every GPS tick).
  String? _lastFitCellId;

  /// Whether the MapLibre fog sources/layers have been added to the map.
  bool _fogLayersInitialized = false;

  /// Throttle fog overlay updates during camera movement to ~10 fps.
  DateTime _lastFogUpdateTime = DateTime(0);
  Timer? _fogUpdateTimer;

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
    _fogUpdateTimer?.cancel();
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
    } catch (e) {
      // If layer initialization fails, fall back gracefully.
      debugPrint('Failed to initialize fog layers: $e');
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
    } catch (e) {
      debugPrint('Failed to update fog sources: $e');
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

    controller.fitBounds(
      bounds: LngLatBounds(
        longitudeWest: minLon,
        longitudeEast: maxLon,
        latitudeSouth: minLat,
        latitudeNorth: maxLat,
      ),
      padding: const EdgeInsets.all(40),
      nativeDuration: const Duration(milliseconds: 500),
    );
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
      nativeDuration: const Duration(seconds: 1),
    );
  }

  // ---------------------------------------------------------------------------
  // Location handling
  // ---------------------------------------------------------------------------

  void _onLocationUpdate(SimulatedLocation loc) {
    final fogResolver = ref.read(fogResolverProvider);
    final cameraController = ref.read(cameraControllerProvider);
    final fogOverlayController = ref.read(fogOverlayControllerProvider);

    // 1. Update fog-of-war state.
    fogResolver.onLocationUpdate(loc.position.lat, loc.position.lon);

    // 2. Push position into Riverpod location state.
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

    // 3. Animate camera if in following mode.
    cameraController.onLocationUpdate(loc.position.lat, loc.position.lon);

    // 4. Recompute fog overlay if the map is ready.
    if (!mounted) return;
    final mapState = ref.read(mapStateProvider);
    if (mapState.isReady && _mapController != null) {
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

      // 5. Re-fit zoom only when the player enters a new cell — not every
      //    GPS tick. This prevents fitBounds from fighting animateCamera.
      final currentCellId = fogResolver.currentCellId;
      if (currentCellId != null && currentCellId != _lastFitCellId) {
        _lastFitCellId = currentCellId;
        _applyZoomLevel();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // MapLibre callbacks
  // ---------------------------------------------------------------------------

  void _onMapCreated(MapController controller) {
    _mapController = controller;
    final cameraController = ref.read(cameraControllerProvider);

    cameraController.onCameraMove = (lat, lon) {
      // Position(lng, lat) — longitude first!
      // Duration matches the GPS tick interval (1s) for smooth continuous glide.
      controller.animateCamera(
        center: Position(lon, lat),
        nativeDuration: const Duration(milliseconds: 1000),
      );
    };
  }

  void _onStyleLoaded() {
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
        _applyZoomLevel();
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
    final cameraController = ref.read(cameraControllerProvider);
    final fogOverlayController = ref.read(fogOverlayControllerProvider);

    // Camera is locked to the player — ignore user pan gestures.

    if (event is MapEventMoveCamera) {
      final camera = event.camera;

      ref.read(mapStateProvider.notifier).updateZoom(camera.zoom);

      // Throttle fog GeoJSON rebuilds to ~10 fps during camera movement.
      // MapLibre renders the existing GeoJSON at 60fps GPU-side — no drift.
      const throttleMs = 100;
      final now = DateTime.now();
      final elapsed = now.difference(_lastFogUpdateTime).inMilliseconds;

      if (elapsed >= throttleMs) {
        fogOverlayController.update(
          cameraLat: camera.center.lat.toDouble(),
          cameraLon: camera.center.lng.toDouble(),
          zoom: camera.zoom,
          viewportSize: MediaQuery.of(context).size,
        );
        _updateFogSources();
        _lastFogUpdateTime = now;
        _fogUpdateTimer?.cancel();
      } else {
        _fogUpdateTimer?.cancel();
        _fogUpdateTimer = Timer(
          Duration(milliseconds: throttleMs - elapsed),
          () {
            if (mounted && _mapController != null) {
              final cam = _mapController!.getCamera();
              fogOverlayController.update(
                cameraLat: cam.center.lat.toDouble(),
                cameraLon: cam.center.lng.toDouble(),
                zoom: cam.zoom,
                viewportSize: MediaQuery.of(context).size,
              );
              _updateFogSources();
              _lastFogUpdateTime = DateTime.now();
            }
          },
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    final mapState = ref.watch(mapStateProvider);
    final cameraMode = ref.watch(cameraModeProvider);
    final fogOverlayController = ref.read(fogOverlayControllerProvider);
    final fogResolver = ref.read(fogResolverProvider);
    final position = locationState.currentPosition;

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
              // ── Layer 2: Player marker (geo-anchored) ───────────────────
              if (position != null)
                WidgetLayer(
                  markers: [
                    Marker(
                      // Position(lng, lat) — longitude FIRST!
                      point: Position(position.lon, position.lat),
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
