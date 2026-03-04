import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre/maplibre.dart';

import 'package:fog_of_world/core/state/fog_resolver_provider.dart';
import 'package:fog_of_world/core/state/location_provider.dart';
import 'package:fog_of_world/features/discovery/providers/discovery_provider.dart';
import 'package:fog_of_world/features/discovery/widgets/discovery_notification.dart';
import 'package:fog_of_world/features/location/services/location_service.dart';
import 'package:fog_of_world/features/location/services/location_simulator.dart';
import 'package:fog_of_world/features/location/services/real_gps_service.dart';
import 'package:fog_of_world/features/location/widgets/location_permission_banner.dart';
import 'package:fog_of_world/features/map/layers/fog_canvas_overlay.dart';
import 'package:fog_of_world/features/map/layers/player_marker_widget.dart';
import 'package:fog_of_world/features/map/providers/camera_controller_provider.dart';
import 'package:fog_of_world/features/map/providers/camera_mode_provider.dart';
import 'package:fog_of_world/features/map/providers/discovery_service_provider.dart';
import 'package:fog_of_world/features/map/providers/fog_overlay_controller_provider.dart';
import 'package:fog_of_world/features/map/providers/location_service_provider.dart';
import 'package:fog_of_world/features/map/providers/map_state_provider.dart';
import 'package:fog_of_world/features/map/widgets/debug_hud.dart';
import 'package:fog_of_world/features/map/widgets/map_controls.dart';
import 'package:fog_of_world/features/map/widgets/status_bar.dart';
import 'package:fog_of_world/shared/constants.dart';
import 'package:fog_of_world/shared/widgets/error_boundary.dart';

/// Main map screen — the primary game view.
///
/// Composes all map-phase layers in a [Stack]:
/// 1. MapLibre base map (tiles)
/// 2. [FogCanvasOverlay] full-screen fog of war
/// 3. [PlayerMarkerWidget] geo-anchored via [WidgetLayer]
/// 4. [StatusBar] translucent top panel
/// 5. [DebugHud] toggle-able diagnostics overlay
/// 6. [MapControls] recenter + debug FABs (bottom-right)
///
/// All services are injected via Riverpod providers. The map screen
/// orchestrates the location → fog → camera → overlay pipeline by
/// subscribing to the location service stream and coordinating updates.
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

  bool _showDebugHud = false;

  /// Throttle fog overlay updates during camera movement to ~10 fps.
  /// Camera move events fire at 60 fps during gestures; recomputing 1700+
  /// cells each frame is prohibitive on web.
  DateTime _lastFogUpdateTime = DateTime(0);
  Timer? _fogUpdateTimer;

  @override
  void initState() {
    super.initState();

    // Start location tracking and subscribe to position updates.
    _locationService = ref.read(locationServiceProvider);
    _locationService.start();
    _locationSubscription =
        _locationService.filteredLocationStream.listen(_onLocationUpdate);

    // Check GPS permission asynchronously and surface any denial to the UI.
    _checkLocationPermission();

    // Forward discovery events to the DiscoveryNotifier for UI display.
    final discoveryService = ref.read(discoveryServiceProvider);
    _discoverySubscription = discoveryService.onDiscovery.listen((event) {
      ref.read(discoveryProvider.notifier).showDiscovery(event);
    });
  }

  /// Checks GPS permission and updates [locationProvider] with any error.
  ///
  /// Called once after [initState]. For non-GPS modes (simulation, keyboard)
  /// this is a no-op. Never throws — errors are surfaced via provider state.
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
    _locationService.stop();
    super.dispose();
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
    //    Also update the GPS accuracy error flag based on threshold.
    final locationNotifier = ref.read(locationProvider.notifier);
    locationNotifier.updateLocation(loc.position, loc.accuracy);

    // Only flag low accuracy for real GPS (not simulation / keyboard).
    if (_locationService.mode == LocationMode.realGps) {
      final currentError = ref.read(locationProvider).locationError;
      final isLowAccuracy = loc.accuracy > kGpsAccuracyThreshold;
      // Only update when the flag changes to avoid spurious rebuilds.
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
      setState(() {});
    }
  }

  // ---------------------------------------------------------------------------
  // MapLibre callbacks
  // ---------------------------------------------------------------------------

  void _onMapCreated(MapController controller) {
    _mapController = controller;
    final cameraController = ref.read(cameraControllerProvider);

    // Wire camera follow mode: CameraController delegates movement to MapLibre.
    cameraController.onCameraMove = (lat, lon) {
      // Position(lng, lat) — longitude first!
      controller.animateCamera(
        center: Position(lon, lat),
        nativeDuration: const Duration(milliseconds: 500),
      );
    };
  }

  void _onStyleLoaded() {
    _removeTextLabels();
    ref.read(mapStateProvider.notifier).markReady();

    // Trigger initial fog overlay render with the default map center.
    // On web, the keyboard location service may not have emitted yet when
    // the style finishes loading, leaving the fog overlay empty.
    final fogOverlayController = ref.read(fogOverlayControllerProvider);
    if (fogOverlayController.renderData.isEmpty && _mapController != null) {
      final camera = _mapController!.getCamera();
      fogOverlayController.update(
        cameraLat: camera.center.lat.toDouble(),
        cameraLon: camera.center.lng.toDouble(),
        zoom: camera.zoom,
        viewportSize: MediaQuery.of(context).size,
      );
      setState(() {});
    }
  }

  /// Strips all symbol (text/icon) layers from the map style.
  /// The fog overlay covers the map, making labels useless clutter.
  void _removeTextLabels() {
    final controller = _mapController;
    if (controller == null) return;

    const symbolLayerIds = [
      'water_name',
      'road_oneway',
      'road_oneway_opposite',
      'highway_name_other',
      'highway_name_motorway',
      'place_other',
      'place_suburb',
      'place_village',
      'place_town',
      'place_city',
      'place_city_large',
      'place_state',
      'place_country_other',
      'place_country_minor',
      'place_country_major',
    ];

    for (final id in symbolLayerIds) {
      controller.removeLayer(id);
    }
  }

  void _onMapEvent(MapEvent event) {
    final cameraController = ref.read(cameraControllerProvider);
    final fogOverlayController = ref.read(fogOverlayControllerProvider);

    if (event is MapEventStartMoveCamera) {
      // User gesture → release follow mode.
      if (event.reason == CameraChangeReason.apiGesture) {
        cameraController.onUserGesture();
        ref.read(cameraModeProvider.notifier).setFree();
      }
    }

    if (event is MapEventMoveCamera) {
      // Keep zoom in sync (cheap — just a provider write).
      final camera = event.camera;
      ref.read(mapStateProvider.notifier).updateZoom(camera.zoom);

      // Throttle fog overlay recomputation to avoid recomputing ~1700 cells
      // on every frame during pan/zoom gestures.
      if (mounted) {
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
          setState(() {});
          _lastFogUpdateTime = now;
          _fogUpdateTimer?.cancel();
        } else {
          // Schedule trailing update so the final camera position renders.
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
                setState(() {});
                _lastFogUpdateTime = DateTime.now();
              }
            },
          );
        }
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
          // ── Layer 1: MapLibre base map ─────────────────────────────────────
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
              // ── Layer 3: Player marker (geo-anchored) ───────────────────
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

          // ── Layer 2: Fog canvas overlay (full-screen) ──────────────────────
          FogCanvasOverlay(
            cells: fogOverlayController.renderData,
            renderVersion: fogOverlayController.renderVersion,
          ),

          // ── Layer 4: Status bar ────────────────────────────────────────────
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: StatusBar(),
          ),

          // ── Layer 4.5: Discovery notification overlay ──────────────────────
          // Positioned below the StatusBar (safe area + status bar height).
          Positioned(
            top: MediaQuery.of(context).padding.top + 64,
            left: 16,
            right: 16,
            child: const DiscoveryNotificationOverlay(),
          ),

          // ── Layer 4.6: Location permission banner ─────────────────────────
          // Dismissable banner shown when GPS is denied or services are off.
          Positioned(
            top: MediaQuery.of(context).padding.top + 56,
            left: 0,
            right: 0,
            child: const LocationPermissionBanner(),
          ),

          // ── Layer 4.7: Low accuracy indicator ─────────────────────────────
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

          // ── Layer 5: Debug HUD (toggle-able) ──────────────────────────────
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

          // ── Layer 6: Map controls (recenter + debug) ──────────────────────
          Positioned(
            right: 16,
            bottom: 16,
            child: MapControls(
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
///
/// Keeps the scaffold structure intact and gives users a clear, friendly
/// message — no stack traces, no raw exception details.
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
