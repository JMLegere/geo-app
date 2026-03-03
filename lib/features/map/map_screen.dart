import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre/maplibre.dart';

import 'package:fog_of_world/core/cells/cell_cache.dart';
import 'package:fog_of_world/core/cells/cell_service.dart';
import 'package:fog_of_world/core/cells/voronoi_cell_service.dart';
import 'package:fog_of_world/core/fog/fog_state_resolver.dart';
import 'package:fog_of_world/core/state/location_provider.dart';
import 'package:fog_of_world/features/discovery/providers/discovery_provider.dart';
import 'package:fog_of_world/features/discovery/services/discovery_service.dart';
import 'package:fog_of_world/features/discovery/widgets/discovery_notification.dart';
import 'package:fog_of_world/features/location/services/location_service.dart';
import 'package:fog_of_world/features/location/services/location_simulator.dart';
import 'package:fog_of_world/features/map/controllers/camera_controller.dart';
import 'package:fog_of_world/features/map/controllers/fog_overlay_controller.dart';
import 'package:fog_of_world/features/map/layers/fog_canvas_overlay.dart';
import 'package:fog_of_world/features/map/layers/player_marker_widget.dart';
import 'package:fog_of_world/features/map/providers/camera_mode_provider.dart';
import 'package:fog_of_world/features/map/providers/map_state_provider.dart';
import 'package:fog_of_world/features/map/widgets/debug_hud.dart';
import 'package:fog_of_world/features/map/widgets/map_controls.dart';
import 'package:fog_of_world/features/map/widgets/status_bar.dart';

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
/// Location simulation starts automatically on mount. The camera
/// follows the player in following mode until the user pans the map, which
/// switches to free mode. The recenter button restores following mode.
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
  late final CameraController _cameraController;
  late final FogOverlayController _fogOverlayController;
  late final CellService _cellService;
  late final FogStateResolver _fogResolver;
  late final LocationService _locationService;
  late final DiscoveryService _discoveryService;

  StreamSubscription<SimulatedLocation>? _locationSubscription;
  StreamSubscription<dynamic>? _discoverySubscription;

  bool _showDebugHud = false;

  // SF Bay Area default — covers the simulated walk path.
  static const double _defaultLat = 37.7749;
  static const double _defaultLon = -122.4194;

  @override
  void initState() {
    super.initState();

    // Build the Voronoi cell grid covering the SF Bay Area.
    _cellService = CellCache(VoronoiCellService(
      minLat: 37.5,
      maxLat: 38.0,
      minLon: -122.7,
      maxLon: -122.2,
      gridRows: 40,
      gridCols: 40,
      seed: 42,
    ));

    _fogResolver = FogStateResolver(_cellService);
    _cameraController = CameraController();
    _fogOverlayController = FogOverlayController(
      cellService: _cellService,
      fogResolver: _fogResolver,
    );

    // Create DiscoveryService seeded with the dev fixture species dataset.
    _discoveryService = DiscoveryService(
      fogResolver: _fogResolver,
      speciesService: ref.read(speciesServiceProvider),
    );

    // Forward discovery events to the DiscoveryNotifier for UI display.
    _discoverySubscription = _discoveryService.onDiscovery.listen((event) {
      ref.read(discoveryProvider.notifier).showDiscovery(event);
    });

    // Start GPS simulation.
    _locationService = LocationService(mode: LocationMode.simulation);
    _locationService.start();

    // Wire location updates into fog, location provider, and camera.
    _locationSubscription =
        _locationService.filteredLocationStream.listen(_onLocationUpdate);
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _discoverySubscription?.cancel();
    _locationService.stop();
    _discoveryService.dispose();
    _fogResolver.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Location handling
  // ---------------------------------------------------------------------------

  void _onLocationUpdate(SimulatedLocation loc) {
    // 1. Update fog-of-war state.
    _fogResolver.onLocationUpdate(loc.position.lat, loc.position.lon);

    // 2. Push position into Riverpod location state.
    ref.read(locationProvider.notifier).updateLocation(
          loc.position,
          loc.accuracy,
        );

    // 3. Animate camera if in following mode.
    _cameraController.onLocationUpdate(loc.position.lat, loc.position.lon);

    // 4. Recompute fog overlay if the map is ready.
    if (!mounted) return;
    final mapState = ref.read(mapStateProvider);
    if (mapState.isReady && _mapController != null) {
      final camera = _mapController!.getCamera();
      _fogOverlayController.update(
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

    // Wire camera follow mode: CameraController delegates movement to MapLibre.
    _cameraController.onCameraMove = (lat, lon) {
      // Position(lng, lat) — longitude first!
      controller.animateCamera(
        center: Position(lon, lat),
        nativeDuration: const Duration(milliseconds: 500),
      );
    };
  }

  void _onStyleLoaded() {
    ref.read(mapStateProvider.notifier).markReady();
  }

  void _onMapEvent(MapEvent event) {
    if (event is MapEventStartMoveCamera) {
      // User gesture → release follow mode.
      if (event.reason == CameraChangeReason.apiGesture) {
        _cameraController.onUserGesture();
        ref.read(cameraModeProvider.notifier).setFree();
      }
    }

    if (event is MapEventMoveCamera) {
      // Keep zoom in sync and recompute fog cells for the new viewport.
      final camera = event.camera;
      ref.read(mapStateProvider.notifier).updateZoom(camera.zoom);

      if (mounted) {
        _fogOverlayController.update(
          cameraLat: camera.center.lat.toDouble(),
          cameraLon: camera.center.lng.toDouble(),
          zoom: camera.zoom,
          viewportSize: MediaQuery.of(context).size,
        );
        setState(() {});
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
    final position = locationState.currentPosition;

    return Scaffold(
      body: Stack(
        children: [
          // ── Layer 1: MapLibre base map ─────────────────────────────────────
          MapLibreMap(
            options: MapOptions(
              initStyle: 'https://tiles.openfreemap.org/styles/positron',
              initZoom: 15,
              initCenter: Position(_defaultLon, _defaultLat),
              minZoom: 12,
              maxZoom: 18,
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
            cells: _fogOverlayController.renderData,
            renderVersion: _fogOverlayController.renderVersion,
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

          // ── Layer 5: Debug HUD (toggle-able) ──────────────────────────────
          if (_showDebugHud)
            Positioned(
              left: 8,
              bottom: 80,
              child: DebugHud(
                mapState: mapState,
                visibleCells: _fogOverlayController.renderData.length,
                visitedCells: _fogResolver.visitedCellIds.length,
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
                if (loc.currentPosition != null) {
                  _cameraController.recenter(
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
    );
  }
}
