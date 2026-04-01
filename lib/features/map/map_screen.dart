import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:earth_nova/shared/mixins/observable_lifecycle.dart';
import 'package:flutter/material.dart' hide Durations;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre/maplibre.dart';

import 'package:geobase/geobase.dart' show Geographic;

import 'package:earth_nova/core/engine/engine_input.dart';
import 'package:earth_nova/core/engine/engine_runner.dart';
import 'package:earth_nova/core/engine/game_coordinator.dart';
import 'package:earth_nova/core/models/cell_event.dart';

import 'package:earth_nova/core/state/cell_service_provider.dart';
import 'package:earth_nova/core/state/daily_seed_provider.dart';
import 'package:earth_nova/core/state/fog_resolver_provider.dart';
import 'package:earth_nova/core/services/observability_buffer.dart';
import 'package:earth_nova/core/services/startup_beacon.dart';
import 'package:earth_nova/core/state/fog_provider.dart';
import 'package:earth_nova/core/state/game_coordinator_provider.dart';
import 'package:earth_nova/core/state/location_provider.dart';
import 'package:earth_nova/core/state/player_located_provider.dart';
import 'package:earth_nova/core/state/hierarchy_repository_provider.dart';
import 'package:earth_nova/core/models/hierarchy.dart';
import 'package:earth_nova/features/discovery/widgets/discovery_notification.dart';
import 'package:earth_nova/features/steps/widgets/step_recap.dart';
import 'package:earth_nova/features/location/widgets/location_permission_banner.dart';
import 'package:earth_nova/features/map/controllers/camera_controller.dart';
import 'package:earth_nova/features/map/controllers/rubber_band_controller.dart';
import 'package:earth_nova/features/map/providers/fog_overlay_controller_provider.dart';
import 'package:earth_nova/features/map/providers/map_state_provider.dart';
import 'package:earth_nova/features/map/utils/cell_property_geojson_builder.dart';
import 'package:earth_nova/features/map/utils/fog_geojson_builder.dart';
import 'package:earth_nova/features/map/utils/habitat_fill_geojson_builder.dart';
import 'package:earth_nova/features/map/utils/map_icon_renderer.dart';
import 'package:earth_nova/features/map/utils/mercator_projection.dart';
import 'package:earth_nova/features/map/utils/territory_border_geojson_builder.dart';
import 'package:earth_nova/features/map/utils/debug_bridge.dart';
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
import 'package:earth_nova/features/sync/providers/location_enrichment_provider.dart';
import 'package:earth_nova/features/sync/services/location_enrichment_service.dart';
import 'package:earth_nova/features/sync/widgets/sync_toast_overlay.dart';
import 'package:earth_nova/shared/constants.dart';
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/shared/widgets/error_boundary.dart';
import 'package:earth_nova/core/state/detection_zone_provider.dart';
import 'package:earth_nova/features/map/models/hierarchy_level.dart';
import 'package:earth_nova/features/map/widgets/district_infographic_overlay.dart';
import 'package:earth_nova/features/map/widgets/hierarchy_stub_overlay.dart';

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
    with TickerProviderStateMixin, ObservableLifecycle<MapScreen> {
  @override
  String get observabilityName => 'MapScreen';

  MapController? _mapController;

  /// The central game logic coordinator. Saved in initState for safe access.
  late final GameCoordinator _gameCoordinator;

  /// Engine runner for sending inputs (PositionUpdate) to the game engine.
  late final EngineRunner _engineRunner;

  /// Location enrichment service. Saved in initState for safe access in dispose()
  /// (calling ref.read() in dispose() triggers "Bad state: Using ref" error).
  late final LocationEnrichmentService _locationEnrichmentService;
  StreamSubscription<({String cellId, String locationId})>?
      _enrichmentSubscription;

  /// Rubber-band interpolation controller. Decouples the visible marker
  /// position from raw GPS coordinates and drives 60fps camera + marker
  /// updates via a Ticker.
  late final RubberBandController _rubberBand;
  late final AnimationController _infographicTransitionCtrl;
  late final Animation<double> _infographicFade;
  late final Animation<double> _infographicScale;

  /// Interpolated display position for the player marker (updated at 60fps).
  ///
  /// Updated via [ValueNotifier] so only [PlayerMarkerLayer] rebuilds on each
  /// 60fps frame — the rest of [MapScreen] stays stable.
  late final ValueNotifier<({double lat, double lon})?> _markerPosition;

  /// Camera mode controller — manages following/free/overview transitions.
  late final CameraController _cameraController;

  /// Subscription to raw GPS updates from GameCoordinator.
  StreamSubscription<({Geographic position, double accuracy})>?
      _rawGpsSubscription;

  bool _showDebugHud = false;
  HierarchyLevel? _activeHierarchyLevel;

  /// Whether the map is in "zooming toward infographic" mode.
  /// When true, minZoom is temporarily lowered to kInfographicTriggerZoom.
  bool _infographicZoomArmed = false;

  /// Whether zoom gestures are frozen (during overlay animation or while open).
  bool _zoomFrozen = false;

  /// Pointer count for multitouch detection.
  int _pointerCount = 0;

  /// Raw pointer positions for computing gesture scale during Phase 2.
  final Map<int, Offset> _activePointers = {};

  /// Distance between the two fingers at the moment Phase 2 triggered.
  double? _triggerPointerDistance;

  /// Whether a gesture is actively driving the overlay animation.
  bool _infographicGestureActive = false;

  /// Last pointer-move timestamp for velocity computation (ms since epoch).
  // ignore: unused_field
  int _lastPointerMoveTimeMs = 0;

  /// Last inter-pointer distance for velocity computation.
  // ignore: unused_field
  double _lastPointerDistance = 0;

  /// JavaScript debug bridge for Playwright E2E tests.
  /// Exposes `window.__earthNovaDebug` on web; no-op on native.
  late final DebugBridge _debugBridge;

  /// Screen position of an in-progress long press, for the visual ring indicator.
  /// Null when no long press is active.
  Offset? _longPressPoint;

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

  /// Last raw GPS position received. Used to compute convergence distance
  /// for the playerLocatedProvider gate.
  ({double lat, double lon})? _lastRawGps;
  bool _playerLocatedFired = false;

  /// Render logic runs every Nth display-update frame.
  /// Desktop: every 6th frame (~10 Hz at 60 fps).
  /// Mobile web: every 30th frame (~2 Hz at 60 fps) — iOS WebKit builds
  /// take ~100ms per frame, so 10Hz = 100% CPU. 2Hz gives headroom.
  static final _kRenderInterval = kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.android)
      ? 30
      : 6;

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

  // -- MapLibre source/layer IDs for habitat fill --
  static const _habitatFillSrcId = 'habitat-fill-src';
  static const _habitatFillLayerId = 'habitat-fill';

  // -- MapLibre source/layer IDs for territory borders --
  static const _borderFillSrcId = 'territory-border-fill-src';
  static const _borderFillLayerId = 'territory-border-fill';
  static const _borderLinesSrcId = 'territory-border-lines-src';
  static const _borderLinesLayerId = 'territory-border-lines';

  /// Whether the cell property icon images have been registered with MapLibre.
  bool _iconImagesRegistered = false;

  /// District ancestry cache — loaded once, refreshed when enrichment completes.
  Map<String, ({String? cityId, String? stateId, String? countryId})>
      _districtAncestryMap = {};
  bool _districtAncestryLoaded = false;

  /// District data cache for infographic overlay.
  Map<String, HDistrict> _districtDataMap = {};

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

    _infographicTransitionCtrl = AnimationController(
      vsync: this,
      duration: Durations.infographicTransition,
    );
    _infographicFade = CurvedAnimation(
      parent: _infographicTransitionCtrl,
      curve: AppCurves.fadeIn,
    );
    _infographicScale = Tween<double>(
      begin: kInfographicEntryScale,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _infographicTransitionCtrl,
      curve: AppCurves.standard,
    ));

    // Read GameCoordinator — it's already started by the provider.
    _gameCoordinator = ref.read(gameCoordinatorProvider);
    _engineRunner = ref.read(engineRunnerProvider);

    // Do NOT seed the rubber-band from the restored position here.
    //
    // The restored position (from SQLite profile.lastLat/lastLon) may be from
    // a different city or even country (e.g. a Michigan test session when the
    // player is in Fredericton). Pre-seeding the rubber-band with a stale
    // position means the first real GPS fix is treated as a subsequent call
    // (not the first), so the rubber-band interpolates across thousands of km
    // instead of snapping. During that multi-second crawl, the exploration
    // guard fires continuously ("MOVING TOO FAST") and fog never updates at
    // the player's real location → white screen.
    //
    // Instead: let the rubber-band stay uninitialized. The first real GPS fix
    // from _rawGpsSubscription (line below) triggers the first setTarget call,
    // which snaps the rubber-band to the correct position. The playerLocated
    // gate on the loading screen covers the gap until GPS arrives.

    // When the detection zone resolves, trigger one fog rebuild cycle.
    // The zone cells arrive AFTER the rubber-band pauses (player is
    // stationary), so _onDisplayPositionUpdate stops firing and the fog
    // never rebuilds with the new 6K cells. This listener catches that.
    // When the detection zone changes (cells added/removed), trigger a fog
    // rebuild. This is needed because _updateFogRendering only runs during
    // rubber-band ticks, and zone cells often arrive AFTER the rubber-band
    // pauses (player is stationary). The zoneReadyProvider listener was
    // insufficient — it only fires on false→true transition, but the 15s
    // timeout can set it to true before the real zone resolves.
    ref.read(detectionZoneServiceProvider).onDetectionZoneChanged.listen((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final pos = _markerPosition.value;
        if (pos != null) _updateFogRendering(pos.lat, pos.lon);
      });
    });

    // Wire exploration-disabled banner.
    _gameCoordinator.onExplorationDisabledChanged = (disabled) {
      if (mounted) setState(() => _showExplorationBanner = disabled);
    };

    // Subscribe to raw GPS updates to feed the rubber-band.
    _rawGpsSubscription =
        _gameCoordinator.onRawGpsUpdate.listen(_onRawGpsUpdate);

    // When enrichment completes, reload district ancestry so territory borders
    // update without an app restart.
    // Save reference to field — ref.read() in dispose() is unsafe (Bad state: Using ref).
    _locationEnrichmentService = ref.read(locationEnrichmentServiceProvider);
    _enrichmentSubscription =
        _locationEnrichmentService.onLocationEnriched.listen((event) {
      if (!mounted) return;
      debugPrint('[MAP] enrichment resolved: cell=${event.cellId} '
          'location=${event.locationId}');
      // Reload district ancestry when enrichment resolves a new locationId.
      _loadDistrictAncestry().then((_) {
        if (!mounted) return;
        final fogCtrl = ref.read(fogOverlayControllerProvider);
        final detectionZone = ref.read(detectionZoneServiceProvider);
        fogCtrl.cellDistrictIds = detectionZone.cellDistrictAttribution;
        fogCtrl.districtAncestry = _districtAncestryMap;
        _updateFogSources();
      });
    });

    // Keyboard shortcut: 'I' toggles district infographic.
    HardwareKeyboard.instance.addHandler(_onKeyEvent);

    // JavaScript debug bridge for Playwright E2E tests.
    _debugBridge = DebugBridge(
      getInfographicState: () => _activeHierarchyLevel != null,
      setInfographicState: (value) {
        if (mounted) {
          setState(() {
            _activeHierarchyLevel = value ? HierarchyLevel.district : null;
          });
        }
      },
    );
    _debugBridge.install();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    _debugBridge.dispose();
    _gameCoordinator.onExplorationDisabledChanged = null;
    _enrichmentSubscription?.cancel();
    _rubberBand.dispose();
    _markerPosition.dispose();
    _cameraController.dispose();
    _rawGpsSubscription?.cancel();
    _infographicTransitionCtrl.dispose();
    super.dispose();
  }

  /// Handles keyboard events for debug shortcuts.
  /// Returns true if the event was handled (consumed).
  bool _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    if (event.logicalKey == LogicalKeyboardKey.keyI) {
      if (_activeHierarchyLevel == null) {
        _triggerInfographicOpen();
      } else {
        _dismissInfographic();
      }
      debugPrint('[MAP] keyboard shortcut: hierarchy=$_activeHierarchyLevel');
      return true;
    }
    return false;
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
      // Habitat fill: subtle radial gradient tint per revealed cell.
      await controller.addSource(
        GeoJsonSource(
            id: _habitatFillSrcId,
            data: HabitatFillGeoJsonBuilder.emptyFeatureCollection),
      );
      await controller.addLayer(FillLayer(
        id: _habitatFillLayerId,
        sourceId: _habitatFillSrcId,
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
          'line-color': [
            'coalesce',
            ['get', 'border_color'],
            '#888888'
          ],
          'line-width': [
            'coalesce',
            ['get', 'line_weight'],
            1.0
          ],
          'line-opacity': 0.7,
          // Each feature has side=1 or side=-1. Offset pushes each half-line
          // to its own side so both colors sit flush against the boundary.
          'line-offset': [
            '*',
            ['get', 'side'],
            [
              '/',
              ['get', 'line_weight'],
              2
            ]
          ],
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
  /// references these by ID (e.g., "event-migration", "event-unknown").
  /// Habitat/climate icons removed — habitat fills handle communication now.
  Future<void> _registerIconImages(MapController controller) async {
    if (_iconImagesRegistered) return;

    final totalIcons = CellEventType.values.length + 1; // +1 for unknown
    MapLogger.iconRegistrationStarted(totalIcons);

    var succeeded = 0;
    var failed = 0;

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

  /// Updates MapLibre GeoJSON sources that have changed since the last call.
  ///
  /// Fog layers (base + mid + border outlines) update ATOMICALLY to avoid a
  /// single-frame flash where the base fog has holes punched but the mid fog
  /// fill hasn't been applied yet.
  ///
  /// Non-fog sources (admin, habitat, territory borders, icons) update ONE
  /// group per call — staggered across frames. Each group stays dirty until
  /// consumed, so nothing is lost.
  Future<void> _updateFogSources() async {
    final controller = _mapController;
    if (controller == null || !_fogLayersInitialized) return;

    final fogCtrl = ref.read(fogOverlayControllerProvider);

    // Consume all dirty flags independently — the old exclusive stagger
    // starved border/icon updates because habitat was dirty every frame.
    final fogDirty = fogCtrl.consumeFogDirty();
    final habitatDirty = fogCtrl.consumeHabitatDirty();
    final borderDirty = fogCtrl.consumeBorderDirty();
    final iconsDirty = fogCtrl.consumeIconsDirty();

    // Nothing changed — skip entirely.
    if (!fogDirty && !habitatDirty && !borderDirty && !iconsDirty) {
      return;
    }

    final sw = Stopwatch()..start();
    MapLogger.fogUpdateStarted();

    try {
      // Fog layers update atomically (avoid flash from base holes without
      // mid fill).
      if (fogDirty) {
        await Future.wait([
          controller.updateGeoJsonSource(
            id: _fogBaseSrcId,
            data: fogCtrl.baseFogGeoJson,
          ),
          controller.updateGeoJsonSource(
            id: _fogMidSrcId,
            data: fogCtrl.midFogGeoJson,
          ),
          controller.updateGeoJsonSource(
            id: _fogBorderSrcId,
            data: fogCtrl.cellBorderGeoJson,
          ),
        ]);
      }

      // Push all dirty non-fog groups in parallel.
      final updates = <Future<void>>[];

      if (habitatDirty) {
        updates.add(controller.updateGeoJsonSource(
          id: _habitatFillSrcId,
          data: fogCtrl.habitatFillGeoJson,
        ));
      }
      if (borderDirty) {
        updates.add(controller.updateGeoJsonSource(
          id: _borderFillSrcId,
          data: fogCtrl.borderFillGeoJson,
        ));
        updates.add(controller.updateGeoJsonSource(
          id: _borderLinesSrcId,
          data: fogCtrl.borderLinesGeoJson,
        ));
      }
      if (iconsDirty && _iconImagesRegistered) {
        updates.add(controller.updateGeoJsonSource(
          id: _cellIconsSrcId,
          data: fogCtrl.cellIconsGeoJson,
        ));
      }

      if (updates.isNotEmpty) await Future.wait(updates);

      sw.stop();
      MapLogger.fogUpdateCompleted();

      // Log slow frames for performance debugging.
      if (sw.elapsedMilliseconds > 10) {
        debugPrint('[FOG-PERF] source update took ${sw.elapsedMilliseconds}ms '
            '(fog=$fogDirty, habitat=$habitatDirty, '
            'border=$borderDirty, icons=$iconsDirty)');
      }
      ObservabilityBuffer.instance?.event('fog_sources_updated', {
        'duration_ms': sw.elapsedMilliseconds,
        'fog': fogDirty,
        'habitat': habitatDirty,
        'border': borderDirty,
        'icons': iconsDirty,
      });
    } catch (e, stack) {
      MapLogger.fogUpdateError(e, stack);
    }
  }

  // ---------------------------------------------------------------------------
  // Infographic open/dismiss
  // ---------------------------------------------------------------------------

  /// Triggers the district infographic overlay with scale+fade animation.
  /// Used for keyboard shortcut and debug only — gesture path is via
  /// [_onInfographicGestureEnd].
  void _triggerInfographicOpen() {
    HapticFeedback.mediumImpact();
    setState(() {
      _zoomFrozen = true;
      _activeHierarchyLevel = HierarchyLevel.district;
    });
    _infographicTransitionCtrl.value = 0.0;
    _infographicTransitionCtrl.animateTo(
      1.0,
      duration: Durations.infographicTransition,
      curve: AppCurves.standard,
    );
  }

  /// Dismisses the district infographic with forward animation.
  void _dismissInfographic() {
    _infographicTransitionCtrl
        .animateTo(
      0.0,
      duration: Durations.infographicTransition,
      curve: AppCurves.standard,
    )
        .then((_) {
      if (!mounted) return;
      setState(() {
        _activeHierarchyLevel = null;
        _zoomFrozen = false;
        _infographicZoomArmed = false;
      });
      // Restore zoom to player level. Cannot use animateCamera here —
      // the 60 Hz rubber-band moveCamera (instant/jumpTo) cancels it every
      // frame, leaving zoom stuck at kInfographicTriggerZoom. Instead, update
      // _currentZoom directly so the next rubber-band tick uses the right level
      // and snaps the camera back to the player marker.
      if (_currentZoom < kMinZoom) {
        _currentZoom = kMinZoom;
      }
    });
  }

  /// Called when fingers release during a gesture-driven overlay transition.
  /// Snaps to open or closed based on threshold and velocity.
  void _onInfographicGestureEnd() {
    _infographicGestureActive = false;
    final currentValue = _infographicTransitionCtrl.value;

    // Determine intent: snap open or snap back.
    final shouldOpen = currentValue >= kInfographicSnapThreshold;

    if (shouldOpen) {
      _infographicTransitionCtrl.animateTo(
        1.0,
        duration: Durations.infographicSnap,
        curve: AppCurves.standard,
      );
    } else {
      _infographicTransitionCtrl
          .animateTo(
        0.0,
        duration: Durations.infographicSnap,
        curve: AppCurves.standard,
      )
          .then((_) {
        if (!mounted) return;
        setState(() {
          _activeHierarchyLevel = null;
          _zoomFrozen = false;
        });
        // Same fix as _dismissInfographic: update _currentZoom directly so
        // the rubber-band picks it up on the next tick instead of using
        // animateCamera which it would immediately cancel.
        if (_currentZoom < kMinZoom) {
          _currentZoom = kMinZoom;
        }
      });
    }

    _triggerPointerDistance = null;
  }

  /// Called by overlay when user pinch-spreads (closing gesture).
  void _onOverlayCloseGestureUpdate(double scale) {
    // scale > 1.0 = spreading = closing. Map 1.0→∞ to progress 1.0→0.0.
    final progress = 1.0 - ((scale - 1.0) * kInfographicGestureSensitivity);
    _infographicTransitionCtrl.value = progress.clamp(0.0, 1.0);
  }

  /// Called by overlay when close gesture ends.
  void _onOverlayCloseGestureEnd(double scaleVelocity) {
    final currentValue = _infographicTransitionCtrl.value;

    // Positive velocity = spreading = closing intent.
    bool shouldStayOpen;
    if (scaleVelocity.abs() > kInfographicVelocityCommitThreshold) {
      shouldStayOpen = scaleVelocity < 0; // squeezing back = stay open
    } else {
      shouldStayOpen = currentValue >= kInfographicSnapThreshold;
    }

    if (shouldStayOpen) {
      _infographicTransitionCtrl.animateTo(
        1.0,
        duration: Durations.infographicSnap,
        curve: AppCurves.standard,
      );
    } else {
      _dismissInfographic();
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

    _lastRawGps = (lat: update.position.lat, lon: update.position.lon);

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

    // 1b. Feed updated position to camera controller (follows in following mode).
    _cameraController.onPlayerPositionUpdate(Geographic(lat: lat, lon: lon));

    // 1c. Check rubber-band convergence for loading gate (once only).
    if (!_playerLocatedFired && _lastRawGps != null) {
      final dist =
          _haversineMeters(lat, lon, _lastRawGps!.lat, _lastRawGps!.lon);
      if (dist < kPlayerLocatedThresholdMeters) {
        _playerLocatedFired = true;
        ref.read(playerLocatedProvider.notifier).markLocated();
      }
    }

    // 2. Feed player position to engine via EngineRunner (60 fps — coordinator
    //    throttles internally to ~10 Hz for game logic).
    _engineRunner.send(PositionUpdate(lat, lon, 0));

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
      final sw = Stopwatch()..start();

      final MapCamera camera;
      try {
        camera = _mapController!.getCamera();
      } catch (e) {
        MapLogger.getCameraError('_updateFogRendering', e);
        return;
      }

      final fogOverlayController = ref.read(fogOverlayControllerProvider);

      // Feed cell properties + daily seed for icon rendering.
      // Only set when the cache size changes — the setter triggers a
      // territory border rebuild (48-57ms BFS). The coordinator's getter
      // returns Map.unmodifiable() which creates a NEW object each call,
      // so identical() always fails. Length comparison catches new cells.
      final currentProps = _gameCoordinator.cellPropertiesCache;
      if (currentProps.length !=
          fogOverlayController.cellPropertiesCacheRef.length) {
        fogOverlayController.cellPropertiesCache = currentProps;
      }
      final seedState = ref.read(dailySeedServiceProvider).currentSeed;
      fogOverlayController.dailySeed = seedState?.seed ?? '';

      // Feed cell district attribution for territory border rendering.
      // Only set when the map size changes — the setter triggers BFS rebuild.
      final detectionZone = ref.read(detectionZoneServiceProvider);
      final currentAttribution = detectionZone.cellDistrictAttribution;
      if (currentAttribution.length !=
          fogOverlayController.cellDistrictIdsCount) {
        fogOverlayController.cellDistrictIds = currentAttribution;
      }

      // Lazy-load district ancestry for territory border rendering.
      // Set once when loaded — not every frame (setter triggers BFS rebuild).
      if (!_districtAncestryLoaded) {
        _districtAncestryLoaded = true;
        _loadDistrictAncestry().then((_) {
          if (mounted) {
            fogOverlayController.districtAncestry = _districtAncestryMap;
            _updateFogSources();
          }
        });
      }

      fogOverlayController.update(
        cameraLat: camera.center.lat.toDouble(),
        cameraLon: camera.center.lng.toDouble(),
        zoom: camera.zoom,
        viewportSize: MediaQuery.of(context).size,
      );
      ref.read(mapStateProvider.notifier).updateCameraPosition(lat, lon);
      _updateFogSources();

      sw.stop();
      if (sw.elapsedMilliseconds > 10) {
        debugPrint('[FOG-PERF] render took ${sw.elapsedMilliseconds}ms');
      }
    }
  }

  /// Loads district ancestry from the hierarchy repository.
  ///
  /// Called lazily on the first fog render frame (and on enrichment events).
  /// Loads each district in [cellDistrictAttribution], then walks up to city,
  /// state, and country — building the ancestry map for territory borders.
  /// Also populates [_districtDataMap] for the infographic overlay.
  Future<void> _loadDistrictAncestry() async {
    if (!mounted) return;

    try {
      final detectionZone = ref.read(detectionZoneServiceProvider);
      final districtIds = detectionZone.cellDistrictAttribution.values.toSet();
      if (districtIds.isEmpty) return;

      final repo = ref.read(hierarchyRepositoryProvider);

      // Step 1: districts → cityIds + cache district data
      final districtCity = <String, String>{}; // districtId → cityId
      final districtData = <String, HDistrict>{};
      for (final id in districtIds) {
        final d = await repo.getDistrict(id);
        if (!mounted) return;
        if (d != null) {
          districtCity[id] = d.cityId;
          districtData[id] = d;
        }
      }

      // Step 2: cities → stateIds
      final cityState = <String, String>{}; // cityId → stateId
      for (final cityId in districtCity.values.toSet()) {
        final c = await repo.getCity(cityId);
        if (!mounted) return;
        if (c != null) cityState[cityId] = c.stateId;
      }

      // Step 3: states → countryIds
      final stateCountry = <String, String>{}; // stateId → countryId
      for (final stateId in cityState.values.toSet()) {
        final s = await repo.getState(stateId);
        if (!mounted) return;
        if (s != null) stateCountry[stateId] = s.countryId;
      }

      // Step 4: assemble ancestry map
      final ancestry =
          <String, ({String? cityId, String? stateId, String? countryId})>{};
      for (final districtId in districtIds) {
        final cityId = districtCity[districtId];
        final stateId = cityId != null ? cityState[cityId] : null;
        final countryId = stateId != null ? stateCountry[stateId] : null;
        ancestry[districtId] =
            (cityId: cityId, stateId: stateId, countryId: countryId);
      }

      _districtAncestryMap = ancestry;
      _districtDataMap = districtData;
      debugPrint('[MAP] loaded ancestry: ${ancestry.length} districts, '
          '${districtData.length} district data');
    } catch (e) {
      debugPrint('[MapScreen] _loadDistrictAncestry failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // MapLibre callbacks
  // ---------------------------------------------------------------------------

  /// Returns the initial map center — player's last known position if
  /// available, otherwise the Fredericton default. Prevents the map from
  /// flashing Fredericton before the camera follow moves to the player.
  Position _initialCenter() {
    final loc = ref.read(locationProvider);
    if (loc.currentPosition != null) {
      return Position(loc.currentPosition!.lon, loc.currentPosition!.lat);
    }
    return Position(kDefaultMapLon, kDefaultMapLat);
  }

  void _onMapCreated(MapController controller) {
    MapLogger.mapCreated();
    _mapController = controller;

    // Position camera at player's last known location.
    final loc = ref.read(locationProvider);
    if (loc.currentPosition != null) {
      try {
        controller.moveCamera(
          center: Position(loc.currentPosition!.lon, loc.currentPosition!.lat),
          zoom: kDefaultZoom,
        );
      } catch (e) {
        debugPrint('[MAP] initial camera move failed: $e');
      }
    }
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
    StartupBeacon.emit('map_interactive');
    debugPrint('[BOOT] map interactive — fog layers ready');

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
    if (event is MapEventMoveCamera) {
      final zoom = event.camera.zoom;
      _currentZoom = zoom;

      // If zoom is frozen (overlay open), snap back to frozen zoom.
      // This prevents the user from zooming while the overlay is visible.
      if (_zoomFrozen && _currentZoom != kInfographicTriggerZoom) {
        _mapController?.moveCamera(
          zoom: kInfographicTriggerZoom,
        );
        _currentZoom = kInfographicTriggerZoom;
        return; // Skip further processing
      }

      // If armed and zoom hit the trigger floor, switch to gesture-driven mode.
      if (_infographicZoomArmed &&
          _currentZoom <= kInfographicTriggerZoom + 0.05) {
        _infographicZoomArmed = false;

        // Compute trigger pointer distance for gesture tracking.
        if (_activePointers.length >= 2) {
          final pointers = _activePointers.values.toList();
          _triggerPointerDistance = (pointers[0] - pointers[1]).distance;
          _lastPointerDistance = _triggerPointerDistance!;
          _lastPointerMoveTimeMs = DateTime.now().millisecondsSinceEpoch;
        }

        HapticFeedback.mediumImpact();
        setState(() {
          _zoomFrozen = true;
          _infographicGestureActive = true;
          _activeHierarchyLevel = HierarchyLevel.district;
        });
        _infographicTransitionCtrl.value = 0.0;
      }
    }

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

    final fogState = ref.read(fogProvider)[cellId];
    ObservabilityBuffer.instance?.event('cell_tapped', {
      'cell_id': cellId,
      if (fogState != null) 'fog_state': fogState.name,
    });

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
    final fogOverlayController = ref.read(fogOverlayControllerProvider);
    final fogResolver = ref.read(fogResolverProvider);

    return ErrorBoundary(
      onError: (_, __) => _MapErrorFallback(),
      child: Scaffold(
        body: Stack(
          children: [
            // ── Layer 0: Fog-colored backdrop ─────────────────────────────────
            // Provides the dark background color while the map tiles load.
            Container(color: const Color(0xFF161620)),

            // ── Layer 1: MapLibre base map + native fog fill layers ────────────
            // Wrapped in GestureDetector so long-press works on all platforms.
            // MapLibre's MapEventLongClick is unreliable on web (no native
            // "long click" concept in browsers). The Flutter GestureDetector
            // fires onLongPressDown immediately (0 ms) for instant haptic
            // feedback, and onLongPressStart when the hold completes (~500 ms).
            // MercatorProjection converts screen coords → geo for cell lookup.
            Listener(
              onPointerDown: (event) {
                _activePointers[event.pointer] = event.position;
                _pointerCount++;
                if (_pointerCount >= 2 &&
                    _activeHierarchyLevel == null &&
                    !_zoomFrozen) {
                  _infographicZoomArmed = true;
                }
              },
              onPointerMove: (event) {
                _activePointers[event.pointer] = event.position;
                if (_infographicGestureActive &&
                    _activePointers.length >= 2 &&
                    _triggerPointerDistance != null &&
                    _triggerPointerDistance! > 0) {
                  final pointers = _activePointers.values.toList();
                  final currentDist = (pointers[0] - pointers[1]).distance;
                  final progress = ((_triggerPointerDistance! - currentDist) /
                          _triggerPointerDistance!) *
                      kInfographicGestureSensitivity;
                  _infographicTransitionCtrl.value = progress.clamp(0.0, 1.0);

                  // Track for velocity computation.
                  final now = DateTime.now().millisecondsSinceEpoch;
                  _lastPointerMoveTimeMs = now;
                  _lastPointerDistance = currentDist;
                }
              },
              onPointerUp: (event) {
                _activePointers.remove(event.pointer);
                _pointerCount = (_pointerCount - 1).clamp(0, 99);
                if (_infographicGestureActive && _activePointers.length < 2) {
                  _onInfographicGestureEnd();
                } else if (_pointerCount < 2 &&
                    _infographicZoomArmed &&
                    !_infographicGestureActive) {
                  setState(() => _infographicZoomArmed = false);
                  // Smooth zoom reset instead of snap.
                  if (_currentZoom < kMinZoom) {
                    _mapController?.animateCamera(
                      zoom: kMinZoom,
                      nativeDuration: Durations.infographicSnap,
                    );
                  }
                }
              },
              onPointerCancel: (event) {
                _activePointers.remove(event.pointer);
                _pointerCount = (_pointerCount - 1).clamp(0, 99);
                if (_infographicGestureActive && _activePointers.length < 2) {
                  _onInfographicGestureEnd();
                } else if (_pointerCount < 2 &&
                    _infographicZoomArmed &&
                    !_infographicGestureActive) {
                  setState(() => _infographicZoomArmed = false);
                  // Smooth zoom reset instead of snap.
                  if (_currentZoom < kMinZoom) {
                    _mapController?.animateCamera(
                      zoom: kMinZoom,
                      nativeDuration: Durations.infographicSnap,
                    );
                  }
                }
              },
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onLongPressDown: (details) {
                  HapticFeedback.selectionClick();
                  setState(() => _longPressPoint = details.localPosition);
                },
                onLongPressStart: (details) {
                  HapticFeedback.mediumImpact();
                  setState(() => _longPressPoint = null);
                  final mapState = ref.read(mapStateProvider);
                  final cameraLat = mapState.cameraLat ?? kDefaultMapLat;
                  final cameraLon = mapState.cameraLon ?? kDefaultMapLon;
                  final size = MediaQuery.sizeOf(context);
                  final geo = MercatorProjection.screenToGeo(
                    screenPoint: details.localPosition,
                    cameraLat: cameraLat,
                    cameraLon: cameraLon,
                    zoom: _currentZoom,
                    viewportSize: size,
                  );
                  final cellService = ref.read(cellServiceProvider);
                  final cellId = cellService.getCellId(geo.lat, geo.lon);
                  _onCellTapped(cellId);
                },
                onLongPressCancel: () {
                  setState(() => _longPressPoint = null);
                },
                child: MapLibreMap(
                  options: MapOptions(
                    // Minimal inline style — black canvas only.
                    // The fog overlay renders on top; this prevents the white
                    // positron tile flash and gives a dark base. Replace with
                    // a real tile provider URL when map tiles are added.
                    initStyle:
                        '{"version":8,"sources":{},"layers":[{"id":"background","type":"background","paint":{"background-color":"#050C15"}}]}',
                    initZoom: kDefaultZoom,
                    initCenter: _initialCenter(),
                    // Allow zooming down to infographic trigger level so the user
                    // can smoothly pinch into the overlay. Zoom freeze is handled
                    // in _onMapEvent by snapping back to frozen zoom.
                    minZoom: kInfographicTriggerZoom,
                    maxZoom: kMaxZoom,
                    attribution: false,
                    nativeLogo: false,
                    // Disable pitch (tilt) — we never use it, and it's a 2D game.
                    // This also disables MapLibre's built-in KeyboardHandler (which
                    // requires allEnabled=true). Without this, arrow keys are
                    // processed by BOTH our KeyboardLocationService AND MapLibre's
                    // native pan handler, causing rapid oscillation when opposing
                    // keys are held or jitter during normal movement.
                    gestures: MapGestures.all(
                      pitch: false,
                      pan: false,
                    ),
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
              ),
            ), // close outer Listener

            // ── Layer 1.5: Long press ring indicator ──────────────────────────
            // Appears immediately on finger-down, grows over kLongPressTimeout.
            // IgnorePointer so it never captures map touches.
            if (_longPressPoint != null)
              Positioned(
                left: _longPressPoint!.dx - 32,
                top: _longPressPoint!.dy - 32,
                child: IgnorePointer(
                  child: _LongPressRing(key: ValueKey(_longPressPoint)),
                ),
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

            // ── Layer 3.9: Hierarchy overlays ──────────────────────────
            if (_activeHierarchyLevel == HierarchyLevel.district)
              Positioned.fill(
                child: FadeTransition(
                  opacity: _infographicFade,
                  child: ScaleTransition(
                    scale: _infographicScale,
                    child: DistrictInfographicOverlay(
                      onDismiss: _dismissInfographic,
                      onNavigateUp: () => setState(
                          () => _activeHierarchyLevel = HierarchyLevel.city),
                      onCloseGestureUpdate: _onOverlayCloseGestureUpdate,
                      onCloseGestureEnd: _onOverlayCloseGestureEnd,
                      districtDataMap: _districtDataMap,
                      cellService: ref.read(cellServiceProvider),
                    ),
                  ),
                ),
              ),
            if (_activeHierarchyLevel != null &&
                _activeHierarchyLevel != HierarchyLevel.district)
              Positioned.fill(
                child: HierarchyStubOverlay(
                  level: _activeHierarchyLevel!,
                  onNavigate: (level) =>
                      setState(() => _activeHierarchyLevel = level),
                  onDismiss: () => setState(() => _activeHierarchyLevel = null),
                ),
              ),

            // ── Layer 4: Debug HUD (toggle-able) ──────────────────────────────
            if (_showDebugHud)
              Positioned(
                left: 8,
                bottom: 80,
                child: DebugHud(
                  mapState: mapState,
                  visibleCells: fogOverlayController.visibleCellCount,
                  visitedCells: fogResolver.visitedCellIds.length,
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

            // ── Layer 5: Map controls (zoom toggle + debug) ──────────────────
            Positioned(
              right: 16,
              bottom: 16,
              child: MapControls(
                isWorldZoom: _zoomLevel == ZoomLevel.world,
                onRecenter: () {
                  final pos = _cameraController.playerPosition;
                  if (pos != null) {
                    _mapController?.moveCamera(
                      center: Position(pos.lon, pos.lat),
                      zoom: _currentZoom,
                    );
                  }
                },
                onToggleZoom: () {
                  final goingToWorld = _zoomLevel == ZoomLevel.player;
                  setState(() {
                    _zoomLevel =
                        goingToWorld ? ZoomLevel.world : ZoomLevel.player;
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

  /// Haversine distance in meters between two geographic points.
  static double _haversineMeters(
      double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000.0;
    final dLat = (lat2 - lat1) * (math.pi / 180.0);
    final dLon = (lon2 - lon1) * (math.pi / 180.0);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
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

/// Expanding ring shown when the user begins a long press on the map.
///
/// Provides immediate visual confirmation (< 10 ms after first touch) that the
/// hold gesture was registered. Animates from a tiny dot to a full 64-px ring
/// over [kLongPressTimeout] (500 ms) — matching the long press confirm threshold
/// so the ring fills just as the bottom sheet opens.
///
/// The widget is placed under [IgnorePointer] so it never captures touches.
class _LongPressRing extends StatefulWidget {
  const _LongPressRing({super.key});

  @override
  State<_LongPressRing> createState() => _LongPressRingState();
}

class _LongPressRingState extends State<_LongPressRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    // 500 ms matches Flutter's default kLongPressTimeout.
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = Curves.easeOut.transform(_ctrl.value);
        return Opacity(
          opacity: (0.9 - 0.3 * _ctrl.value).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: t,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3.0),
              ),
            ),
          ),
        );
      },
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
