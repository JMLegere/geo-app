import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geobase/geobase.dart' show Geographic;
import 'package:maplibre/maplibre.dart';

import 'package:earth_nova/data/location/keyboard_location_service.dart';
import 'package:earth_nova/data/location/location_service.dart';
import 'package:earth_nova/engine/engine_input.dart';
import 'package:earth_nova/providers/cell_provider.dart';
import 'package:earth_nova/providers/detection_zone_provider.dart';
import 'package:earth_nova/providers/engine_provider.dart';
import 'package:earth_nova/providers/fog_provider.dart';
import 'package:earth_nova/providers/territory_provider.dart';
import 'package:earth_nova/shared/constants.dart';
import 'package:earth_nova/widgets/camera_controller.dart';
import 'package:earth_nova/widgets/discovery_toast.dart';
import 'package:earth_nova/widgets/dpad_controls.dart';
import 'package:earth_nova/widgets/fog_geojson_builder.dart';
import 'package:earth_nova/widgets/fog_overlay_controller.dart';
import 'package:earth_nova/widgets/map_controls.dart';
import 'package:earth_nova/widgets/player_marker_layer.dart';
import 'package:earth_nova/widgets/rubber_band_controller.dart';
import 'package:earth_nova/widgets/status_bar.dart';

/// Main map screen — a pure renderer.
///
/// All game logic (GPS, discovery, fog tracking, encounters) lives in
/// [GameEngine]. This widget only handles:
/// - Rubber-band interpolation (60 fps visual)
/// - Camera movement (always-follow)
/// - Fog GeoJSON layer management (MapLibre rendering)
/// - Widget tree + UI overlays
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with TickerProviderStateMixin {
  MapController? _mapController;

  late final RubberBandController _rubberBand;
  late final CameraController _cameraController;
  late final FogOverlayController _fogController;
  late final ValueNotifier<({double lat, double lon})?> _markerPosition;

  StreamSubscription<({Geographic position, double accuracy})>?
      _rawGpsSubscription;
  StreamSubscription<dynamic>? _engineEventsSubscription;
  StreamSubscription<Set<String>>? _detectionZoneSubscription;

  // Web keyboard movement service (web only).
  KeyboardLocationService? _keyboardService;

  bool _showExplorationBanner = false;
  bool _fogLayersInitialized = false;
  bool _showDebug = false;
  bool _isWorldZoom = false;

  int _renderFrame = 0;
  int _engineFrame = 0;
  double _lastFogLat = 0.0;
  double _lastFogLon = 0.0;
  double _currentZoom = kDefaultZoom;

  // MapLibre source/layer IDs
  static const _territoryFillSrcId = 'territory-fill-src';
  static const _territoryFillLayerId = 'territory-fill';
  static const _territoryLinesSrcId = 'territory-lines-src';
  static const _territoryLinesLayerId = 'territory-lines';
  static const _fogBaseSrcId = 'fog-base-src';
  static const _fogBaseLayerId = 'fog-base';
  static const _fogMidSrcId = 'fog-mid-src';
  static const _fogMidLayerId = 'fog-mid';
  static const _fogBorderSrcId = 'fog-border-src';
  static const _fogBorderLayerId = 'fog-border';
  static const _exploredBorderSrcId = 'explored-border-src';
  static const _exploredBorderLayerId = 'explored-border';

  /// Render logic runs every Nth display-update frame.
  /// Desktop: every 6th frame (~10 Hz at 60 fps).
  /// Mobile web: every 30th frame (~2 Hz) — iOS WebKit perf.
  static final _kRenderInterval = kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.android)
      ? 30
      : 6;

  @override
  void initState() {
    super.initState();

    _markerPosition = ValueNotifier(null);

    _rubberBand = RubberBandController(
      vsync: this,
      onDisplayUpdate: _onDisplayPositionUpdate,
    );

    _cameraController = CameraController(
      onMoveToPlayer: (center) {
        _mapController?.moveCamera(
          center: Position(center.lon, center.lat),
          zoom: _currentZoom,
        );
      },
    );

    // Fog overlay controller computes GeoJSON for the 3 fog layers.
    final cellService = ref.read(cellServiceProvider);
    final fogResolver = ref.read(fogResolverProvider);
    _fogController = FogOverlayController(
      cellService: cellService,
      fogResolver: fogResolver,
    );

    // Subscribe to raw GPS updates from the engine → feed rubber-band.
    final runner = ref.read(engineProvider);
    _rawGpsSubscription = runner.onRawGpsUpdate.listen(_onRawGpsUpdate);

    // Subscribe to engine events for exploration-disabled banner.
    _engineEventsSubscription = runner.events.listen(_onEngineEvent);

    // Subscribe to detection zone changes → feed cells to fog controller.
    _detectionZoneSubscription =
        ref.read(detectionZoneProvider).onZoneChanged.listen((cells) {
      if (!mounted) return;
      _fogController.addDetectionZoneCells(cells, {});
      final territory = ref.read(territoryProvider);
      _fogController.cellDistrictIds = territory.cellDistrictIds;
      _fogController.districtAncestry = territory.ancestry;
      final pos = _markerPosition.value;
      if (pos != null) _updateFogRendering(pos.lat, pos.lon);
    });

    // Update fog controller when territory state changes.
    ref.listen(territoryProvider, (_, next) {
      _fogController.cellDistrictIds = next.cellDistrictIds;
      _fogController.districtAncestry = next.ancestry;
      final pos = _markerPosition.value;
      if (pos != null) _updateFogRendering(pos.lat, pos.lon);
    });

    // Web keyboard movement.
    if (kIsWeb) {
      _keyboardService = KeyboardLocationService()..start();
    }
  }

  @override
  void dispose() {
    _rawGpsSubscription?.cancel();
    _engineEventsSubscription?.cancel();
    _detectionZoneSubscription?.cancel();
    _keyboardService?.dispose();
    _rubberBand.dispose();
    _markerPosition.dispose();
    _cameraController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Engine event handler
  // ---------------------------------------------------------------------------

  void _onEngineEvent(dynamic event) {
    // event is a GameEvent — use duck-typing via .event field.
    try {
      // ignore: avoid_dynamic_calls
      final name = event.event as String;
      if (name == 'exploration_disabled_changed') {
        // ignore: avoid_dynamic_calls
        final data = event.data as Map<String, dynamic>;
        final disabled = data['disabled'] as bool? ?? false;
        if (mounted) setState(() => _showExplorationBanner = disabled);
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // GPS → rubber-band → display position pipeline
  // ---------------------------------------------------------------------------

  void _onRawGpsUpdate(({Geographic position, double accuracy}) update) {
    _rubberBand.setTarget(update.position.lat, update.position.lon);
  }

  /// Called at ~60 fps by the rubber-band controller.
  void _onDisplayPositionUpdate(double lat, double lon) {
    // 1. Update marker position → PlayerMarkerLayer rebuilds via ValueNotifier.
    _markerPosition.value = (lat: lat, lon: lon);

    // 2. Camera follow — always tracks player.
    _cameraController.onPlayerPositionUpdate(Geographic(lat: lat, lon: lon));

    // 3. Throttle engine position sends to ~10 Hz.
    _engineFrame++;
    if (_engineFrame % _kRenderInterval == 0) {
      ref.read(engineProvider).send(PositionUpdate(lat, lon));
    }

    // 4. Throttle fog rendering to ~10 Hz.
    _renderFrame++;
    if (_renderFrame % _kRenderInterval == 0) {
      _updateFogRendering(lat, lon);
    }
  }

  // ---------------------------------------------------------------------------
  // Fog layer management
  // ---------------------------------------------------------------------------

  /// Adds the fog GeoJSON sources and fill layers to the map (called once).
  Future<void> _initFogLayers() async {
    final controller = _mapController;
    if (controller == null || _fogLayersInitialized) return;

    try {
      // Territory border fill: gradient at admin boundaries (rendered below fog).
      await controller.addSource(
        GeoJsonSource(
            id: _territoryFillSrcId,
            data: FogGeoJsonBuilder.emptyFeatureCollection),
      );
      await controller.addLayer(FillLayer(
        id: _territoryFillLayerId,
        sourceId: _territoryFillSrcId,
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
            0.5,
            1,
            0.04,
            2,
            0.01,
            3,
            0.0,
          ],
        },
      ));

      // Territory border lines (rendered below fog).
      await controller.addSource(
        GeoJsonSource(
            id: _territoryLinesSrcId,
            data: FogGeoJsonBuilder.emptyFeatureCollection),
      );
      await controller.addLayer(LineLayer(
        id: _territoryLinesLayerId,
        sourceId: _territoryLinesSrcId,
        paint: {
          'line-color': '#FFFFFF',
          'line-width': 2.0,
          'line-opacity': 0.8,
        },
      ));

      // Base fog: opaque world polygon with holes punched for revealed cells.
      await controller.addSource(
        GeoJsonSource(id: _fogBaseSrcId, data: FogGeoJsonBuilder.fullWorldFog),
      );
      await controller.addLayer(FillLayer(
        id: _fogBaseLayerId,
        sourceId: _fogBaseSrcId,
        paint: {'fill-color': '#161620', 'fill-opacity': 1.0},
      ));

      // Mid fog: semi-transparent polygons for explored/nearby cells.
      await controller.addSource(
        GeoJsonSource(
            id: _fogMidSrcId, data: FogGeoJsonBuilder.emptyFeatureCollection),
      );
      await controller.addLayer(FillLayer(
        id: _fogMidLayerId,
        sourceId: _fogMidSrcId,
        paint: {
          'fill-color': '#161620',
          'fill-opacity': ['get', 'density'],
        },
      ));

      // Cell borders: line outlines for frontier cells.
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

      // Explored cell borders: bright white outlines on explored cells.
      await controller.addSource(
        GeoJsonSource(
            id: _exploredBorderSrcId,
            data: FogGeoJsonBuilder.emptyFeatureCollection),
      );
      await controller.addLayer(LineLayer(
        id: _exploredBorderLayerId,
        sourceId: _exploredBorderSrcId,
        paint: {
          'line-color': '#FFFFFF',
          'line-width': 1.5,
          'line-opacity': 0.7,
        },
      ));

      _fogLayersInitialized = true;
    } catch (e) {
      debugPrint('[MAP] Failed to init fog layers: $e');
    }
  }

  /// Updates the fog GeoJSON sources from the fog overlay controller.
  void _updateFogRendering(double lat, double lon) {
    if (!_fogLayersInitialized) return;

    // Skip if player hasn't moved enough (~1m threshold).
    final dLat = (lat - _lastFogLat).abs();
    final dLon = (lon - _lastFogLon).abs();
    if (dLat < kFogMovementThreshold && dLon < kFogMovementThreshold) return;

    _lastFogLat = lat;
    _lastFogLon = lon;

    final size = MediaQuery.of(context).size;
    _fogController.update(
      cameraLat: lat,
      cameraLon: lon,
      zoom: _currentZoom,
      viewportSize: size,
    );

    _updateFogSources();
  }

  /// Pushes the latest GeoJSON strings to MapLibre.
  Future<void> _updateFogSources() async {
    final controller = _mapController;
    if (controller == null || !_fogLayersInitialized) return;

    try {
      await controller.updateGeoJsonSource(
          id: _fogBaseSrcId, data: _fogController.baseFogGeoJson);
      await controller.updateGeoJsonSource(
          id: _fogMidSrcId, data: _fogController.midFogGeoJson);
      await controller.updateGeoJsonSource(
          id: _fogBorderSrcId, data: _fogController.cellBorderGeoJson);
      await controller.updateGeoJsonSource(
          id: _exploredBorderSrcId,
          data: _fogController.exploredBordersGeoJson);
      if (_fogController.consumeBorderDirty()) {
        await controller.updateGeoJsonSource(
            id: _territoryFillSrcId, data: _fogController.borderFillGeoJson);
        await controller.updateGeoJsonSource(
            id: _territoryLinesSrcId, data: _fogController.borderLinesGeoJson);
      }
    } catch (e) {
      debugPrint('[MAP] Failed to update fog sources: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Map lifecycle
  // ---------------------------------------------------------------------------

  void _onMapCreated(MapController controller) {
    _mapController = controller;
  }

  void _onStyleLoaded() {
    _initFogLayers();
    // If we already have a position, trigger initial fog render.
    final pos = _markerPosition.value;
    if (pos != null) _updateFogRendering(pos.lat, pos.lon);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final keyboardSvc = _keyboardService;

    return Scaffold(
      body: Stack(
        children: [
          // MapLibre map with player marker
          MapLibreMap(
            options: MapOptions(
              initCenter: Position(0, 0),
              initZoom: _currentZoom,
              minZoom: 2,
              maxZoom: 20,
              gestures: MapGestures.all(),
            ),
            onMapCreated: _onMapCreated,
            onStyleLoaded: _onStyleLoaded,
            children: [
              PlayerMarkerLayer(position: _markerPosition),
            ],
          ),

          // Status bar (top)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(child: StatusBar()),
          ),

          // Map controls (right side)
          Positioned(
            right: 16,
            bottom: 100,
            child: MapControls(
              onRecenter: () {
                final pos = _markerPosition.value;
                if (pos != null) {
                  _mapController?.moveCamera(
                    center: Position(pos.lon, pos.lat),
                    zoom: _currentZoom,
                  );
                }
              },
              onToggleDebug: () {
                setState(() => _showDebug = !_showDebug);
              },
              onToggleZoom: () {
                setState(() {
                  _isWorldZoom = !_isWorldZoom;
                  _currentZoom = _isWorldZoom ? 3.0 : kDefaultZoom;
                });
                _mapController?.moveCamera(zoom: _currentZoom);
              },
              isWorldZoom: _isWorldZoom,
              locationMode:
                  kIsWeb ? LocationMode.keyboard : LocationMode.simulation,
            ),
          ),

          // DPad controls (bottom-left, web only)
          if (kIsWeb && keyboardSvc != null)
            Positioned(
              left: 16,
              bottom: 24,
              child: DPadControls(keyboardService: keyboardSvc),
            ),

          // Discovery toast overlay
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(child: DiscoveryNotificationOverlay()),
          ),

          // Exploration disabled banner
          if (_showExplorationBanner)
            Positioned(
              bottom: 80,
              left: 40,
              right: 40,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade800.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Moving too fast — exploration paused',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
