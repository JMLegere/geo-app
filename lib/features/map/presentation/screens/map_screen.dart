import 'dart:async';
import 'package:earth_nova/app/readiness/app_readiness.dart';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/encounters/presentation/providers/pending_encounter_provider.dart';
import 'package:earth_nova/features/living_world/domain/entities/town_projection.dart';
import 'package:earth_nova/features/living_world/presentation/providers/town_provider.dart';
import 'package:earth_nova/features/living_world/presentation/widgets/venue_marker.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/features/map/domain/entities/location_state.dart';
import 'package:earth_nova/features/map/domain/entities/encounter.dart';
import 'package:earth_nova/features/map/domain/entities/player_marker_state.dart';
import 'package:earth_nova/features/map/domain/entities/camera_follow_state.dart';
import 'package:earth_nova/features/map/domain/services/fog_state_service.dart';
import 'package:earth_nova/features/map/presentation/diagnostics/map_render_diagnostics_service.dart';
import 'package:earth_nova/features/map/domain/services/explored_footprint_service.dart';
import 'package:earth_nova/features/map/presentation/painters/cell_overlay_painter.dart';
import 'package:earth_nova/features/map/presentation/painters/fog_renderer.dart';
import 'package:earth_nova/features/map/presentation/painters/player_marker.dart';
import 'package:earth_nova/features/map/presentation/providers/camera_follow_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/encounter_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/desktop_controls_provider.dart';
import 'package:earth_nova/features/map/presentation/platform/base_map_settled_signal.dart';
import 'package:earth_nova/features/map/presentation/platform/base_map_style_loaded_signal.dart';
import 'package:earth_nova/features/map/presentation/platform/map_style_label_layers.dart';
import 'package:earth_nova/features/map/presentation/providers/exploration_eligibility_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/exploration_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/location_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/map_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/map_readiness_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/player_marker_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/visit_queue_provider.dart';
import 'package:earth_nova/features/map/presentation/widgets/cell_detail_sheet.dart';
import 'package:earth_nova/features/map/presentation/widgets/discovery_notification.dart';
import 'package:earth_nova/features/map/presentation/widgets/map_status_bar.dart';
import 'package:earth_nova/features/map/presentation/state/map_readiness_state.dart';
import 'package:earth_nova/features/map/presentation/widgets/desktop_traversal_input.dart';
import 'package:earth_nova/features/map/presentation/widgets/shimmer_cells.dart';
import 'package:earth_nova/shared/design.dart';
import 'package:earth_nova/shared/observability/widgets/observable_interaction.dart';
import 'package:earth_nova/shared/product/player_actions.dart';
import 'package:earth_nova/shared/observability/widgets/observable_screen.dart';

const _kWebMapStyleUrl = 'base-map-style.json';
const _kNativeMapStyleUrl = 'https://tiles.openfreemap.org/styles/liberty';
const _kGpsZoom = 15.0;

/// Duration the discovery notification is visible before auto-dismissing.
const _kDiscoveryNotificationDuration = Duration(seconds: 3);

bool _isPendingEncounterVisible(PendingEncounterState state) {
  return state is PendingEncounterReady ||
      state is PendingEncounterResolving ||
      (state is PendingEncounterFailure && state.pendingEncounter != null);
}

const _kExactProjectionCenterTolerancePx = 96.0;

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with WidgetsBindingObserver {
  maplibre.MapLibreMapController? _mapController;

  bool _baseMapTextLabelsHidden = false;
  bool _steadyStateLogged = false;
  bool _readinessWaitingLogged = false;
  BaseMapSettledSignal? _baseMapSettledSignal;
  BaseMapStyleLoadedSignal? _baseMapStyleLoadedSignal;
  ProviderSubscription<MapReadinessState>? _mapReadinessSubscription;
  ProviderSubscription<LocationProviderState>? _locationReadinessSubscription;
  ProviderSubscription<MapState>? _mapReadinessStateSubscription;
  TelemetrySpan? _mapBootstrapSpan;
  String? _lastGeometryDiagnosticsKey;
  GeoCoord? _renderCameraPosition;
  double? _renderCameraZoom;
  _ExactScreenProjectionRequest? _pendingExactScreenProjectionRequest;
  bool _exactScreenProjectionInFlight = false;
  String? _exactScreenProjectionInFlightKey;
  String? _exactScreenProjectionKey;
  Map<String, Offset> _exactScreenProjectionByCoordKey = const {};
  Map<String, Offset> _exactScreenProjectionCellCentersById = const {};
  Offset? _exactScreenProjectionMarkerScreenPosition;
  int _exactScreenProjectionRevision = 0;
  Size? _lastWebMapLayoutSize;
  bool _webMapResizeScheduled = false;
  String? _pendingWebMapResizeReason;
  String? _lastRejectedExactProjectionKey;

  /// Cell ID for the currently-shown discovery notification (null = hidden).
  String? _notificationCellId;
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mapBootstrapSpan = ref
        .read(appObservabilityProvider)
        .startSpan(
          'map.bootstrap',
          attributes: {'flow': 'map.bootstrap', 'screen': 'map_screen'},
        );
    ref
        .read(appObservabilityProvider)
        .logFlowEvent(
          'map.bootstrap',
          TelemetryFlowPhase.started,
          'map',
          span: _mapBootstrapSpan,
          data: {'screen': 'map_screen'},
        );
    _mapReadinessSubscription = ref.listenManual<MapReadinessState>(
      mapReadinessProvider,
      (previous, next) {
        if (!mounted) return;
        if (previous?.baseMapSettled != true && next.baseMapSettled) {
          _logMapFlowEvent(
            TelemetryFlowPhase.dependencyReady,
            eventName: 'map.base_map_settled',
            dependency: 'base_map',
            data: {'source': next.baseMapSettledSource},
          );
        }
        if (previous?.bootstrapTimedOut != true && next.bootstrapTimedOut) {
          _handleMapBootstrapTimeout(next);
        }
      },
    );
    _locationReadinessSubscription = ref.listenManual<LocationProviderState>(
      locationProvider,
      (_, next) {
        ref
            .read(mapReadinessProvider.notifier)
            .reportLocationReady(
              next is LocationProviderActive || next is LocationProviderPaused,
            );
      },
    );
    _mapReadinessStateSubscription = ref.listenManual<MapState>(mapProvider, (
      _,
      next,
    ) {
      ref
          .read(mapReadinessProvider.notifier)
          .reportCellsFetched(_renderableMapState(next) != null);
      if (next is MapStateLoading) _resetOverlayReadinessForRefetch();
    });
    _baseMapSettledSignal = BaseMapSettledSignal(
      onSettled: (source) {
        if (!mounted) return;
        _markBaseMapSettled(source: source);
      },
    );
    _baseMapStyleLoadedSignal = BaseMapStyleLoadedSignal(
      onLoaded: (source) {
        if (!mounted) return;
        _handleStyleLoaded(source: source);
      },
    );
    _scheduleInitialMapReadiness();
  }

  void _scheduleInitialMapReadiness() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final readiness = ref.read(mapReadinessProvider.notifier)..start();
      final location = ref.read(locationProvider);
      readiness.reportLocationReady(
        location is LocationProviderActive ||
            location is LocationProviderPaused,
      );
      readiness.reportCellsFetched(
        _renderableMapState(ref.read(mapProvider)) != null,
      );
    });
  }

  @override
  void dispose() {
    _mapReadinessSubscription?.close();
    _locationReadinessSubscription?.close();
    _mapReadinessStateSubscription?.close();
    _notificationTimer?.cancel();
    _baseMapSettledSignal?.dispose();
    _baseMapStyleLoadedSignal?.dispose();
    final span = _mapBootstrapSpan;
    if (span != null && !_steadyStateLogged) {
      ref
          .read(appObservabilityProvider)
          .logFlowEvent(
            'map.bootstrap',
            TelemetryFlowPhase.cancelled,
            'map',
            eventName: 'map.bootstrap.cancelled',
            span: span,
            reason: 'disposed_before_steady_state',
          );
    }
    _endMapBootstrapSpan(
      statusCode: TelemetrySpanStatus.unset,
      statusMessage: 'disposed_before_steady_state',
    );
    _mapController?.dispose();
    ref.read(mapReadinessProvider.notifier).reset();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _scheduleWebMapResize(reason: 'metrics_changed');
  }

  TelemetrySpan _ensureMapBootstrapSpan() {
    final existing = _mapBootstrapSpan;
    if (existing != null) return existing;
    final span = ref
        .read(appObservabilityProvider)
        .startSpan(
          'map.bootstrap',
          attributes: {'flow': 'map.bootstrap', 'screen': 'map_screen'},
        );
    _mapBootstrapSpan = span;
    return span;
  }

  void _endMapBootstrapSpan({
    required TelemetrySpanStatus statusCode,
    String? statusMessage,
    Map<String, dynamic>? attributes,
  }) {
    final span = _mapBootstrapSpan;
    if (span == null) return;
    final terminalPhase = switch (statusCode) {
      TelemetrySpanStatus.ok => TelemetryFlowPhase.completed,
      TelemetrySpanStatus.error => TelemetryFlowPhase.failed,
      TelemetrySpanStatus.unset => TelemetryFlowPhase.cancelled,
    };
    ref
        .read(appObservabilityProvider)
        .endSpan(
          span,
          statusCode: statusCode,
          statusMessage: statusMessage,
          attributes: {
            ...?attributes,
            'flow': 'map.bootstrap',
            'phase': terminalPhase.wireName,
          },
        );
    _mapBootstrapSpan = null;
  }

  void _logMapEvent(
    String event, {
    String category = 'map',
    Map<String, dynamic>? data,
  }) {
    final span = _ensureMapBootstrapSpan();
    ref
        .read(appObservabilityProvider)
        .log(
          event,
          category,
          data: {
            ...?data,
            'flow': data?['flow'] ?? 'map.bootstrap',
            'trace_id': span.traceId,
            'span_id': span.spanId,
          },
        );
  }

  void _logMapFlowEvent(
    TelemetryFlowPhase phase, {
    String? eventName,
    String? dependency,
    String? reason,
    Map<String, dynamic>? data,
  }) {
    final span = _ensureMapBootstrapSpan();
    ref
        .read(appObservabilityProvider)
        .logFlowEvent(
          'map.bootstrap',
          phase,
          'map',
          eventName: eventName,
          span: span,
          dependency: dependency,
          reason: reason,
          data: data,
        );
  }

  void _showDiscoveryNotification(String cellId) {
    _notificationTimer?.cancel();
    setState(() => _notificationCellId = cellId);
    _notificationTimer = Timer(_kDiscoveryNotificationDuration, () {
      if (mounted) setState(() => _notificationCellId = null);
    });
  }

  void _markMapCreated() {
    ref.read(mapReadinessProvider.notifier).reportMapCreated();
    _scheduleWebMapResize(reason: 'map_created');
  }

  void _updateRenderCamera(maplibre.CameraPosition cameraPosition) {
    final nextPosition = (
      lat: cameraPosition.target.latitude,
      lng: cameraPosition.target.longitude,
    );
    final nextZoom = cameraPosition.zoom;
    final currentPosition = _renderCameraPosition;
    final currentZoom = _renderCameraZoom;
    if (currentPosition != null &&
        currentZoom != null &&
        _sameGeoCoord(currentPosition, nextPosition) &&
        (currentZoom - nextZoom).abs() < 0.0001) {
      return;
    }
    setState(() {
      _renderCameraPosition = nextPosition;
      _renderCameraZoom = nextZoom;
    });
  }

  void _markStyleLoaded() {
    ref.read(mapReadinessProvider.notifier).reportStyleLoaded();
  }

  void _syncWebMapLayoutSize(Size mapSize) {
    if (!kIsWeb || mapSize.isEmpty) return;
    final previous = _lastWebMapLayoutSize;
    final sizeChanged =
        previous == null ||
        (previous.width - mapSize.width).abs() >= 0.5 ||
        (previous.height - mapSize.height).abs() >= 0.5;
    if (!sizeChanged) return;

    _lastWebMapLayoutSize = mapSize;
    _scheduleWebMapResize(reason: 'layout_size_changed');
  }

  void _scheduleWebMapResize({required String reason}) {
    if (!kIsWeb || _mapController == null) return;

    _pendingWebMapResizeReason = reason;
    if (_webMapResizeScheduled) return;
    _webMapResizeScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _webMapResizeScheduled = false;
        return;
      }

      final controller = _mapController;
      if (controller == null) {
        _webMapResizeScheduled = false;
        return;
      }

      final resizeReason = _pendingWebMapResizeReason ?? reason;
      _pendingWebMapResizeReason = null;
      controller.forceResizeWebMap();
      _clearExactScreenProjection();

      _logMapFlowEvent(
        TelemetryFlowPhase.dependencyReady,
        eventName: 'map.web_viewport_resized',
        dependency: 'map_viewport',
        data: {
          'reason': resizeReason,
          'layout_width': _lastWebMapLayoutSize?.width.round(),
          'layout_height': _lastWebMapLayoutSize?.height.round(),
        },
      );

      _webMapResizeScheduled = false;
    });
  }

  void _clearExactScreenProjection() {
    if (!mounted) return;
    setState(() {
      _exactScreenProjectionKey = null;
      _exactScreenProjectionByCoordKey = const {};
      _exactScreenProjectionCellCentersById = const {};
      _exactScreenProjectionMarkerScreenPosition = null;
    });
  }

  void _handleStyleLoaded({required String source}) {
    if (ref.read(mapReadinessProvider).styleLoaded) {
      unawaited(_hideBaseMapTextLabels(source: source));
      return;
    }
    _logMapFlowEvent(
      TelemetryFlowPhase.dependencyReady,
      eventName: 'map.style_loaded',
      dependency: 'map_style',
      data: {'source': source},
    );
    ref.read(mapProvider.notifier).setZoom(_kGpsZoom);
    _markStyleLoaded();
    _scheduleWebMapResize(reason: 'style_loaded');
    unawaited(_hideBaseMapTextLabels(source: source));
  }

  Future<void> _hideBaseMapTextLabels({required String source}) async {
    if (_baseMapTextLabelsHidden) return;
    final controller = _mapController;
    if (controller == null) return;

    try {
      final styleJson = await controller.getStyle();
      if (!mounted || styleJson == null) return;

      final labelLayerIds = baseMapTextLabelLayerIdsFromStyle(styleJson);
      var hiddenLayerCount = 0;
      for (final layerId in labelLayerIds) {
        try {
          await controller.setLayerVisibility(layerId, false);
          hiddenLayerCount++;
        } catch (_) {
          // Styles can change underneath us on web while startup signals race.
          // Continue hiding the remaining label layers instead of failing the
          // whole map bootstrap path for one missing layer id.
        }
      }

      if (!mounted) return;
      setState(() => _baseMapTextLabelsHidden = true);
      _logMapEvent(
        'map.base_map_labels_hidden',
        data: {
          'source': source,
          'label_layer_count': labelLayerIds.length,
          'hidden_layer_count': hiddenLayerCount,
        },
      );
    } catch (error) {
      if (!mounted) return;
      _logMapEvent(
        'map.base_map_labels_hidden_failed',
        data: {'source': source, 'reason': error.toString()},
      );
    }
  }

  void _markBaseMapSettled({required String source}) {
    ref
        .read(mapReadinessProvider.notifier)
        .reportBaseMapSettled(source: source);
  }

  void _resetOverlayReadinessForRefetch() {
    final readiness = ref.read(mapReadinessProvider);
    if (!readiness.overlayFramePainted && !_steadyStateLogged) return;
    ref.read(mapReadinessProvider.notifier).resetOverlayForRefetch();
    _steadyStateLogged = false;
    _readinessWaitingLogged = false;
  }

  MapStateReady? _renderableMapState(MapState mapState) {
    return switch (mapState) {
      MapStateReady ready => ready,
      MapStateRefreshing refreshing => refreshing.previous,
      _ => null,
    };
  }

  void _armOverlayFrameReadiness(
    MapReadinessState readiness, {
    required Map<String, dynamic> renderDiagnostics,
  }) {
    final canPaintSteadyOverlay =
        readiness.locationReady &&
        readiness.mapCreated &&
        readiness.styleLoaded &&
        readiness.baseMapSettled &&
        readiness.cellsFetched;

    if (!canPaintSteadyOverlay || readiness.overlayFramePainted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ref
          .read(mapReadinessProvider.notifier)
          .reportOverlayFramePainted()) {
        return;
      }
      _logMapFlowEvent(
        TelemetryFlowPhase.dependencyReady,
        eventName: 'map.overlay_frame_painted',
        dependency: 'overlay_frame',
        data: renderDiagnostics,
      );
      _logSteadyStateReady();
    });
  }

  void _logReadinessWaiting(MapReadinessState readiness) {
    if (readiness.isSteadyStateReady || _readinessWaitingLogged) return;
    _readinessWaitingLogged = true;
    _logMapFlowEvent(
      TelemetryFlowPhase.waitingOn,
      eventName: 'map.readiness_waiting',
      dependency: readiness.waitingFor.isEmpty
          ? null
          : readiness.waitingFor.first,
      data: readiness.toLogData(),
    );
  }

  void _logGeometryRenderDiagnostics({
    required List<({Cell cell, CellState state})> cellsWithStates,
    required Map<String, dynamic> renderDiagnostics,
  }) {
    if (cellsWithStates.isEmpty) return;
    final key = [
      renderDiagnostics['render_cell_count'],
      renderDiagnostics['render_present_cell_count'],
      renderDiagnostics['render_explored_cell_count'],
      renderDiagnostics['render_frontier_cell_count'],
      renderDiagnostics['render_rectangular_cell_count'],
      renderDiagnostics['render_axis_aligned_edge_ratio'],
      renderDiagnostics['state_current_cell_id'],
      renderDiagnostics['state_visited_cell_count'],
      renderDiagnostics['marker_is_ring'],
      renderDiagnostics['projection_mode'],
      renderDiagnostics['screen_projection_revision'],
    ].join(':');
    if (_lastGeometryDiagnosticsKey == key) return;
    _lastGeometryDiagnosticsKey = key;
    _logMapEvent('map.geometry_rendered', data: renderDiagnostics);
  }

  void _logSteadyStateReady() {
    if (_steadyStateLogged) return;
    _steadyStateLogged = true;
    final readiness = ref.read(mapReadinessProvider);
    _logMapFlowEvent(
      TelemetryFlowPhase.completed,
      eventName: 'map.steady_state_ready',
      data: readiness.toLogData(),
    );
    _endMapBootstrapSpan(
      statusCode: TelemetrySpanStatus.ok,
      attributes: readiness.toLogData(),
    );
  }

  Map<String, dynamic> _locationStateDiagnostics(
    LocationProviderState locationState,
  ) {
    return switch (locationState) {
      LocationProviderLoading() => const {
        'location_state': 'loading',
        'location_error_message': null,
      },
      LocationProviderActive(location: final location) => {
        'location_state': 'active',
        'location_error_message': null,
        'location_accuracy_meters': location.accuracy,
        'location_confident': location.isConfident,
      },
      LocationProviderPermissionDenied() => const {
        'location_state': 'permission_denied',
        'location_error_message': null,
      },
      LocationProviderPaused() => const {
        'location_state': 'paused',
        'location_error_message': null,
      },
      LocationProviderError(message: final message) => {
        'location_state': 'error',
        'location_error_message': message,
      },
    };
  }

  bool _sameGeoCoord(GeoCoord a, GeoCoord b) {
    return (a.lat - b.lat).abs() < 0.0000001 &&
        (a.lng - b.lng).abs() < 0.0000001;
  }

  void _scheduleExactScreenProjection(_ExactScreenProjectionRequest request) {
    final readiness = ref.read(mapReadinessProvider);
    if (!readiness.mapCreated ||
        !readiness.styleLoaded ||
        _mapController == null ||
        request.coordinates.isEmpty) {
      return;
    }
    if (_exactScreenProjectionKey == request.key ||
        _exactScreenProjectionInFlightKey == request.key ||
        _pendingExactScreenProjectionRequest?.key == request.key) {
      return;
    }

    _pendingExactScreenProjectionRequest = request;
    _pumpExactScreenProjectionQueue();
  }

  void _pumpExactScreenProjectionQueue() {
    if (_exactScreenProjectionInFlight) return;
    final controller = _mapController;
    final request = _pendingExactScreenProjectionRequest;
    if (controller == null || request == null) return;

    _pendingExactScreenProjectionRequest = null;
    _exactScreenProjectionInFlight = true;
    _exactScreenProjectionInFlightKey = request.key;
    unawaited(_projectExactScreenCoordinates(controller, request));
  }

  Future<void> _projectExactScreenCoordinates(
    maplibre.MapLibreMapController controller,
    _ExactScreenProjectionRequest request,
  ) async {
    try {
      final screenPoints = await controller.toScreenLocationBatch(
        request.coordinates.map(
          (coord) => maplibre.LatLng(coord.lat, coord.lng),
        ),
      );
      if (!mounted) return;
      if (screenPoints.length != request.coordinateKeys.length) {
        _logMapEvent(
          'map.screen_projection_failed',
          data: {
            'reason': 'coordinate_count_mismatch',
            'coordinate_count': request.coordinateKeys.length,
            'screen_point_count': screenPoints.length,
          },
        );
        return;
      }

      final hasNewerPending =
          _pendingExactScreenProjectionRequest != null &&
          _pendingExactScreenProjectionRequest!.key != request.key;
      if (hasNewerPending) return;

      final projectedByCoordKey = <String, Offset>{};
      for (var i = 0; i < screenPoints.length; i++) {
        final point = screenPoints[i];
        projectedByCoordKey[request.coordinateKeys[i]] = Offset(
          point.x.toDouble(),
          point.y.toDouble(),
        );
      }

      final projectedCellCenters = <String, Offset>{};
      for (final entry in request.cellCenterCoordKeyById.entries) {
        final projected = projectedByCoordKey[entry.value];
        if (projected != null) projectedCellCenters[entry.key] = projected;
      }

      setState(() {
        _exactScreenProjectionKey = request.key;
        _exactScreenProjectionByCoordKey = projectedByCoordKey;
        _exactScreenProjectionCellCentersById = projectedCellCenters;
        _exactScreenProjectionMarkerScreenPosition =
            projectedByCoordKey[request.markerCoordKey];
        _exactScreenProjectionRevision++;
      });
    } catch (error) {
      if (!mounted) return;
      _logMapEvent(
        'map.screen_projection_failed',
        data: {
          'reason': error.toString(),
          'coordinate_count': request.coordinateKeys.length,
        },
      );
    } finally {
      if (mounted) {
        _exactScreenProjectionInFlight = false;
        _exactScreenProjectionInFlightKey = null;
        _pumpExactScreenProjectionQueue();
      }
    }
  }

  Offset? Function(GeoCoord coord)? _exactScreenProjectionProjector(
    String projectionKey,
  ) {
    if (_exactScreenProjectionKey != projectionKey) return null;
    return (coord) =>
        _exactScreenProjectionByCoordKey[_projectionCoordKey(coord)];
  }

  bool _isExactProjectionCenterAligned({
    required Offset? exactProjectedCameraPosition,
    required Offset screenCenter,
  }) {
    if (exactProjectedCameraPosition == null) return false;
    return (exactProjectedCameraPosition - screenCenter).distance <=
        _kExactProjectionCenterTolerancePx;
  }

  void _handleMisalignedExactProjection({
    required String projectionKey,
    required Offset? exactProjectedCameraPosition,
    required Offset screenCenter,
    required Size mapSize,
  }) {
    if (_lastRejectedExactProjectionKey == projectionKey) return;
    _lastRejectedExactProjectionKey = projectionKey;
    _logMapEvent(
      'map.screen_projection_rejected',
      data: {
        'reason': 'misaligned_exact_projection',
        'exact_camera_x': exactProjectedCameraPosition?.dx.round(),
        'exact_camera_y': exactProjectedCameraPosition?.dy.round(),
        'expected_center_x': screenCenter.dx.round(),
        'expected_center_y': screenCenter.dy.round(),
        'delta_px': exactProjectedCameraPosition == null
            ? null
            : (exactProjectedCameraPosition - screenCenter).distance.round(),
        'layout_width': mapSize.width.round(),
        'layout_height': mapSize.height.round(),
        'tolerance_px': _kExactProjectionCenterTolerancePx.round(),
      },
    );
    _scheduleWebMapResize(reason: 'misaligned_exact_projection');
  }

  Offset? _exactProjectedMarkerPosition(String projectionKey) {
    if (_exactScreenProjectionKey != projectionKey) return null;
    return _exactScreenProjectionMarkerScreenPosition;
  }

  Offset? _exactProjectedCellCenter(String projectionKey, String cellId) {
    if (_exactScreenProjectionKey != projectionKey) return null;
    return _exactScreenProjectionCellCentersById[cellId];
  }

  void _handleMapBootstrapTimeout(MapReadinessState readiness) {
    if (!mounted || _steadyStateLogged) return;
    final locationState = ref.read(locationProvider);
    _logMapFlowEvent(
      TelemetryFlowPhase.timedOut,
      eventName: 'map.bootstrap.timed_out',
      dependency: readiness.waitingFor.isEmpty
          ? null
          : readiness.waitingFor.first,
      reason: 'steady_state_not_reached',
      data: {
        ...readiness.toLogData(),
        ..._locationStateDiagnostics(locationState),
        'waiting_for': readiness.waitingFor,
        'timeout_ms': kMapBootstrapTimeout.inMilliseconds,
      },
    );
    _endMapBootstrapSpan(
      statusCode: TelemetrySpanStatus.error,
      statusMessage: 'steady_state_not_reached',
      attributes: {
        ...readiness.toLogData(),
        ..._locationStateDiagnostics(locationState),
        'timeout_ms': kMapBootstrapTimeout.inMilliseconds,
      },
    );
  }

  void _syncTownProjection(AuthState authState, TownState townState) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (authState.status == AuthStatus.authenticated) {
        final playerId = authState.user!.id;
        if (ref.read(townProvider).shouldLoadFor(playerId)) {
          unawaited(ref.read(townProvider.notifier).load(playerId));
        }
        return;
      }
      if (townState.playerId != null || townState.town != null) {
        ref.read(townProvider.notifier).invalidate();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final obs = ref.watch(appObservabilityProvider);
    final authState = ref.watch(authProvider);
    final userId = authState.status == AuthStatus.authenticated
        ? authState.user!.id
        : '';
    final locationState = ref.watch(locationProvider);
    final mapState = ref.watch(mapProvider);
    final readiness = ref.watch(mapReadinessProvider);
    final cameraFollowState = ref.watch(cameraFollowProvider);
    final playerMarkerState = ref.watch(playerMarkerProvider);
    final explorationEligibility = ref.watch(explorationEligibilityProvider);
    final explorationState = ref.watch(explorationProvider);
    final encounterState = ref.watch(encounterProvider);
    final townState = ref.watch(townProvider);
    _syncTownProjection(authState, townState);

    // Move camera from the fast smoothed camera-follow state, not directly from
    // raw GPS. Raw GPS remains the target, but smoothing removes jitter.
    ref.listen(cameraFollowProvider, (_, cameraState) {
      if (cameraState.hasFix && _mapController != null) {
        _mapController!.moveCamera(
          maplibre.CameraUpdate.newLatLng(
            maplibre.LatLng(cameraState.lat, cameraState.lng),
          ),
        );
      }
    });

    ref.listen<PlayerMarkerState>(playerMarkerProvider, (_, markerState) {
      final mapState = ref.read(mapProvider);
      if (mapState case MapStateReady(
        :final cells,
        :final visitedCellIds,
        :final knowledgeByCellId,
      )) {
        final explorationEligibility = ref.read(explorationEligibilityProvider);
        unawaited(
          ref
              .read(explorationProvider.notifier)
              .onPositionUpdate(
                markerState: markerState,
                cells: cells,
                visitedCellIds: visitedCellIds,
                knowledgeByCellId: knowledgeByCellId,
                userId: userId,
                explorationEligibility: explorationEligibility,
              ),
        );
      }
    });

    ref.listen<MapState>(mapProvider, (_, next) {
      if (next case MapStateReady(
        :final cells,
        :final visitedCellIds,
        :final knowledgeByCellId,
      )) {
        final explorationEligibility = ref.read(explorationEligibilityProvider);
        unawaited(
          ref
              .read(explorationProvider.notifier)
              .onPositionUpdate(
                markerState: ref.read(playerMarkerProvider),
                cells: cells,
                visitedCellIds: visitedCellIds,
                knowledgeByCellId: knowledgeByCellId,
                userId: userId,
                explorationEligibility: explorationEligibility,
              ),
        );
      }
    });

    // Listen for gameplay entry events to trigger encounters and discovery
    // notification. Do not key this off currentCellId alone: ring-state marker
    // tracking can update currentCellId before visits are eligible.
    ref.listen<ExplorationStateData>(explorationProvider, (previous, next) {
      final previousMapCellEntryId =
          previous?.lastBorderCrossingEvent?.mapCellEntryId;
      final borderCrossingEvent = next.lastBorderCrossingEvent;
      final isNewGameplayEntry =
          borderCrossingEvent != null &&
          borderCrossingEvent.mapCellEntryId != previousMapCellEntryId;
      if (!isNewGameplayEntry) return;

      final enteredCellId = borderCrossingEvent.enteredCellId;
      final isFirstVisit = borderCrossingEvent.isFirstVisit;
      // Show discovery notification on first visit.
      if (isFirstVisit) {
        _showDiscoveryNotification(enteredCellId);
        _logMapEvent(
          'map.discovery_notification_shown',
          data: {
            'cell_id': enteredCellId,
            'border_crossing_id': borderCrossingEvent.borderCrossingId,
            'map_cell_entry_id': borderCrossingEvent.mapCellEntryId,
          },
        );
      }
    });

    // Encounter notifications are rendered as an in-map overlay below so they
    // do not fight the root bottom navigation or MapLibre attribution DOM.

    final effectiveLocation = switch (locationState) {
      LocationProviderActive(location: final loc) => loc,
      LocationProviderPaused() =>
        playerMarkerState.lat != 0.0
            ? LocationState(
                lat: playerMarkerState.lat,
                lng: playerMarkerState.lng,
                accuracy: 0.0,
                timestamp: DateTime.now(),
                isConfident: false,
              )
            : null,
      _ => null,
    };

    return ObservableScreen(
      screenName: 'map_screen',
      observability: obs,
      builder: (_) => switch (locationState) {
        LocationProviderLoading() => const _MapLoadingScaffold(),
        LocationProviderPermissionDenied() => const _MapStatusScaffold(
          title: 'Location needed',
          message: 'Enable location access to explore the map.',
          tone: AppNoticeTone.warning,
        ),
        LocationProviderError(message: final message) => _MapStatusScaffold(
          title: 'Map unavailable',
          message: message,
        ),
        LocationProviderPaused() when effectiveLocation == null =>
          const _MapStatusScaffold(
            title: 'GPS unavailable',
            message: 'Waiting for GPS signal to resume discovery.',
            tone: AppNoticeTone.warning,
          ),
        LocationProviderPaused() ||
        LocationProviderActive() => _buildMapScaffold(
          context,
          location: effectiveLocation!,
          mapState: mapState,
          cameraFollowState: cameraFollowState,
          readiness: readiness,
          playerMarkerState: playerMarkerState,
          explorationEligibility: explorationEligibility,
          explorationState: explorationState,
          town: townState.town,
          encounterState: encounterState,
        ),
      },
    );
  }

  Widget _buildMapScaffold(
    BuildContext context, {
    required LocationState location,
    required MapState mapState,
    required MapReadinessState readiness,
    required PlayerMarkerState playerMarkerState,
    required CameraFollowState cameraFollowState,
    required ExplorationEligibility explorationEligibility,
    required ExplorationStateData explorationState,
    required EncounterState encounterState,
    required TownProjection? town,
  }) {
    void logger({
      required String event,
      required String category,
      Map<String, dynamic>? data,
    }) {
      _logMapEvent(event, category: category, data: data);
    }

    final renderableMapState = _renderableMapState(mapState);

    final footprint = const ExploredFootprintService().project(
      persistedVisitedCellIds: renderableMapState?.visitedCellIds ?? const {},
      optimisticVisitedCellIds: explorationState.visitedCellIds,
    );
    final cellsObserved = footprint.uniqueCount;
    final desktopControlsAvailable = ref.watch(
      desktopControlsAvailableProvider,
    );
    final desktopControlsEnabled = ref.watch(desktopControlsProvider);
    final pendingEncounterState = ref.watch(pendingEncounterProvider);
    final desktopTraversalEnabled =
        desktopControlsAvailable && desktopControlsEnabled;
    final locationNotifier = ref.read(locationProvider.notifier);
    final visitQueueState = ref.watch(visitQueueProvider);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final mapSize = constraints.biggest;
          _syncWebMapLayoutSize(mapSize);
          final screenCenter = Offset(mapSize.width / 2, mapSize.height / 2);
          final desiredCameraPosition = cameraFollowState.hasFix
              ? (lat: cameraFollowState.lat, lng: cameraFollowState.lng)
              : (lat: location.lat, lng: location.lng);
          final renderCameraPosition =
              _renderCameraPosition ?? desiredCameraPosition;
          final renderZoom = _renderCameraZoom ?? _kGpsZoom;
          final cellsWithStates = renderableMapState != null
              ? _buildCellStates(
                  renderableMapState,
                  footprint.visitedCellIds,
                  explorationState,
                )
              : <({Cell cell, CellState state})>[];
          final markerGeoCoord = (
            lat: playerMarkerState.lat,
            lng: playerMarkerState.lng,
          );
          final exactProjectionRequest = _ExactScreenProjectionRequest.from(
            cellsWithStates: cellsWithStates,
            markerPosition: markerGeoCoord,
            cameraPosition: renderCameraPosition,
            zoom: renderZoom,
          );
          _scheduleExactScreenProjection(exactProjectionRequest);
          final exactProjectionReady =
              _exactScreenProjectionKey == exactProjectionRequest.key;
          final rawExactProjector = _exactScreenProjectionProjector(
            exactProjectionRequest.key,
          );
          final exactProjectedCameraPosition = exactProjectionReady
              ? _exactScreenProjectionByCoordKey[exactProjectionRequest
                    .cameraCoordKey]
              : null;
          final exactProjectionCenterAligned =
              !exactProjectionReady ||
              _isExactProjectionCenterAligned(
                exactProjectedCameraPosition: exactProjectedCameraPosition,
                screenCenter: screenCenter,
              );
          if (exactProjectionReady && !exactProjectionCenterAligned) {
            _handleMisalignedExactProjection(
              projectionKey: exactProjectionRequest.key,
              exactProjectedCameraPosition: exactProjectedCameraPosition,
              screenCenter: screenCenter,
              mapSize: mapSize,
            );
          }
          final projectionMode = exactProjectionReady
              ? (exactProjectionCenterAligned
                    ? 'maplibre_exact_screen'
                    : 'mercator_fallback_misaligned_exact')
              : 'mercator_fallback';
          final effectiveExactProjector = exactProjectionCenterAligned
              ? rawExactProjector
              : null;
          Offset projectGeoCoord(GeoCoord coord) {
            return _projectGeoCoordToScreen(
              coord,
              exactProjector: effectiveExactProjector,
              cameraPosition: renderCameraPosition,
              screenCenter: screenCenter,
              zoom: renderZoom,
            );
          }

          final markerScreenPosition = exactProjectionCenterAligned
              ? _exactProjectedMarkerPosition(exactProjectionRequest.key) ??
                    projectGeoCoord(markerGeoCoord)
              : projectGeoCoord(markerGeoCoord);
          final venueAnchors = _knownVenueAnchors(town, cellsWithStates);
          final renderDiagnostics = {
            ...const MapRenderDiagnosticsService().summarize(
              cellsWithStates: cellsWithStates,
              viewportSize: mapSize,
              project: projectGeoCoord,
              markerScreenPosition: markerScreenPosition,
              currentCellId: explorationState.currentCellId,
              visitedCellCount: footprint.uniqueCount,
              markerIsRing: playerMarkerState.isRing,
              markerGapDistanceMeters: playerMarkerState.gapDistance,
            ),
            'projection_mode': projectionMode,
            'screen_projection_revision': exactProjectionReady
                ? _exactScreenProjectionRevision
                : null,
          };
          final desktopTraversalBlocked =
              !readiness.isSteadyStateReady ||
              _isPendingEncounterVisible(pendingEncounterState) ||
              encounterState.hasActiveReward ||
              !(ModalRoute.of(context)?.isCurrent ?? true);
          _armOverlayFrameReadiness(
            readiness,
            renderDiagnostics: renderDiagnostics,
          );
          _logReadinessWaiting(readiness);
          _logGeometryRenderDiagnostics(
            cellsWithStates: cellsWithStates,
            renderDiagnostics: renderDiagnostics,
          );

          return Stack(
            children: [
              // Base map layer — key must NOT include location data.
              // Previously `ValueKey('$timestamp:$lat:$lng')` caused the entire
              // MapLibreMap (and its GL context) to be torn down and rebuilt on
              // every GPS tick (~1 Hz), making the map constantly flash.
              // Camera follow is handled by cameraFollowProvider above so raw
              // GPS remains the target without hard-snapping the camera.
              Positioned.fill(
                child: DesktopTraversalInput(
                  enabled: desktopTraversalEnabled,
                  blocked: desktopTraversalBlocked,
                  onMove: (north, east) => locationNotifier.moveDesktopByMeters(
                    north: north,
                    east: east,
                  ),
                  onMovementEnded: locationNotifier.persistDesktopPosition,
                  child: maplibre.MapLibreMap(
                    styleString: kIsWeb
                        ? _kWebMapStyleUrl
                        : _kNativeMapStyleUrl,
                    initialCameraPosition: maplibre.CameraPosition(
                      target: maplibre.LatLng(
                        desiredCameraPosition.lat,
                        desiredCameraPosition.lng,
                      ),
                      zoom: _kGpsZoom,
                    ),
                    compassEnabled: false,
                    rotateGesturesEnabled: false,
                    scrollGesturesEnabled: desktopTraversalEnabled,
                    zoomGesturesEnabled: desktopTraversalEnabled,
                    tiltGesturesEnabled: false,
                    doubleClickZoomEnabled: desktopTraversalEnabled,
                    dragEnabled: desktopTraversalEnabled,
                    trackCameraPosition: true,
                    myLocationEnabled: false,
                    myLocationTrackingMode:
                        maplibre.MyLocationTrackingMode.none,
                    attributionButtonPosition:
                        maplibre.AttributionButtonPosition.topRight,
                    attributionButtonMargins: const math.Point(12, 144),
                    onMapCreated: (controller) {
                      _mapController = controller;
                      _updateRenderCamera(
                        controller.cameraPosition ??
                            maplibre.CameraPosition(
                              target: maplibre.LatLng(
                                desiredCameraPosition.lat,
                                desiredCameraPosition.lng,
                              ),
                              zoom: _kGpsZoom,
                            ),
                      );
                      _markMapCreated();
                      _logMapFlowEvent(
                        TelemetryFlowPhase.dependencyReady,
                        eventName: 'map.map_created',
                        dependency: 'map_widget',
                      );
                    },
                    onCameraMove: (cameraPosition) {
                      _updateRenderCamera(cameraPosition);
                    },
                    onMapClick: desktopTraversalEnabled
                        ? (point, _) {
                            final readyMapState = renderableMapState;
                            if (readyMapState == null) return;
                            _onMapTapAt(
                              context,
                              Offset(point.x, point.y),
                              readyMapState,
                              exactProjectionRequest.key,
                              cellsWithStates,
                              projectGeoCoord,
                              venueAnchors,
                            );
                          }
                        : null,
                    onStyleLoadedCallback: () {
                      _handleStyleLoaded(source: 'plugin_style_loaded');
                    },
                    onMapIdle: () {
                      _markBaseMapSettled(source: 'map_idle');
                    },
                  ),
                ),
              ),

              // Shimmer while loading
              if (mapState is MapStateLoading)
                Positioned.fill(
                  child: ShimmerCells(
                    cameraPosition: renderCameraPosition,
                    zoom: renderZoom,
                  ),
                ),

              // Cell overlay layer - drawn on top of map using Flutter Canvas
              if (renderableMapState != null)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: desktopTraversalEnabled,
                    // eac-clickable-owner-logs: _onMapTapAt owns this Map-cell action trace.
                    child: GestureDetector(
                      onTapUp: (details) => _onMapTapAt(
                        context,
                        details.localPosition,
                        renderableMapState,
                        exactProjectionRequest.key,
                        cellsWithStates,
                        projectGeoCoord,
                        venueAnchors,
                      ),
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: CellOverlayPainter(
                          cellsWithStates: cellsWithStates,
                          cameraPosition: renderCameraPosition,
                          zoom: renderZoom,
                          cameraPixelOffset: screenCenter,
                          project: projectGeoCoord,
                          projectionRevision: exactProjectionReady
                              ? _exactScreenProjectionRevision
                              : -1,
                        ),
                      ),
                    ),
                  ),
                ),

              // Player marker overlay — the app owns one gameplay marker.
              if (playerMarkerState.lat != 0.0)
                Positioned(
                  left: markerScreenPosition.dx - 24,
                  top: markerScreenPosition.dy - 24,
                  child: const IgnorePointer(child: PlayerMarker()),
                ),

              for (final venueAnchor in venueAnchors)
                Positioned(
                  left: projectGeoCoord(venueAnchor.position).dx - 16,
                  top: projectGeoCoord(venueAnchor.position).dy - 16,
                  child: IgnorePointer(
                    child: VenueMarker(
                      venue: venueAnchor.venue,
                      displayMode:
                          venueAnchor.relationship == CellRelationship.present
                          ? VenueMarkerDisplayMode.compactLabel
                          : VenueMarkerDisplayMode.glyphOnly,
                    ),
                  ),
                ),

              // Neutral status chrome remains overlaid on the edge-to-edge map.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MapStatusBar(
                      cellsObserved: cellsObserved,
                      totalSteps: 0,
                      streakDays: 0,
                      pendingVisits: visitQueueState.pendingCount,
                    ),
                    if (_notificationCellId != null)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: Spacing.sm,
                          left: Spacing.lg,
                          right: Spacing.giant,
                        ),
                        child: IgnorePointer(
                          child: DiscoveryNotification(
                            cellName: _notificationCellId!,
                          ),
                        ),
                      ),
                    if (explorationEligibility.isPaused)
                      const Padding(
                        padding: EdgeInsets.only(
                          top: Spacing.sm,
                          left: Spacing.lg,
                          right: Spacing.giant,
                        ),
                        child: IgnorePointer(child: DiscoveryPausedBanner()),
                      ),
                  ],
                ),
              ),

              if (encounterState.currentEncounter != null)
                Positioned.fill(
                  child: _DiscoveryRewardModal(
                    encounter: encounterState.currentEncounter!,
                    onContinue: ObservableInteraction.wrapVoidCallback(
                      logger: logger,
                      screenName: 'map_screen',
                      widgetName: 'discovery_reward_modal',
                      actionType: 'continue_discovery_reward',
                      playerActionId: PlayerActions.continueDiscoveryReward,
                      callback: () {
                        ref
                            .read(encounterProvider.notifier)
                            .continueDiscoveryReward();
                      },
                    ),
                  ),
                ),

              // Loading indicator
              if (mapState is MapStateLoading || mapState is MapStateRefreshing)
                const Positioned(
                  top: 24,
                  left: 0,
                  right: 0,
                  child: Center(child: LoadingDots()),
                ),

              if (mapState is! MapStateError)
                const Positioned(
                  left: Spacing.lg,
                  right: Spacing.lg,
                  bottom: Spacing.huge,
                  child: IgnorePointer(child: MapCellKnowledgeLegend()),
                ),

              // Error message
              if (mapState is MapStateError)
                Positioned(
                  left: Spacing.lg,
                  right: Spacing.lg,
                  bottom: Spacing.xxl,
                  child: AppCard(
                    child: AppNotice(
                      title: 'Map unavailable',
                      message: mapState.message,
                      tone: AppNoticeTone.error,
                    ),
                  ),
                ),

              if (!readiness.isSteadyStateReady)
                Positioned.fill(
                  child: _MapSteadyStateLoadingOverlay(
                    waitingFor: readiness.waitingFor,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _onMapTapAt(
    BuildContext context,
    Offset tapPosition,
    MapStateReady mapState,
    String exactProjectionKey,
    List<({Cell cell, CellState state})> cellsWithStates,
    Offset Function(GeoCoord coord) project,
    List<_KnownVenueAnchor> venueAnchors,
  ) {
    final interaction = ObservableInteractionTrace.start(
      observability: ref.read(appObservabilityProvider),
      interaction: PlayerActions.inspectMapCell,
      surface: 'map.cell_overlay',
      readinessState: ref.read(appReadinessProvider).phase.name,
      screenName: 'map_screen',
      widgetName: 'cell_overlay',
      actionType: 'cell_overlay_tap',
    );
    // Find the cell that was tapped (simplified - find closest cell center)
    ({Cell cell, CellState state})? closestEntry;
    double closestDistance = double.infinity;

    for (final entry in cellsWithStates) {
      final cell = entry.cell;
      final center = _cellCenter(cell);
      if (center == null) continue;

      final screenPos =
          _exactProjectedCellCenter(exactProjectionKey, cell.id) ??
          project(center);

      final distance = (tapPosition - screenPos).distance;
      if (distance < closestDistance && distance < 100) {
        closestDistance = distance;
        closestEntry = entry;
      }
    }

    if (closestEntry != null) {
      final cell = closestEntry.cell;
      final isFirstVisit = !mapState.visitedCellIds.contains(cell.id);
      final cellVenues = venueAnchors
          .where((anchor) => anchor.anchorCellId == cell.id)
          .map((anchor) => anchor.venue)
          .toList(growable: false);
      _showCellDetailSheet(
        context,
        cell,
        isFirstVisit,
        closestEntry.state,
        cellVenues,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          interaction.complete(transition: 'cell_sheet_visible');
        }
      });
      return;
    }
    interaction.complete(transition: 'no_cell_selected', outcome: 'ignored');
  }

  Offset _projectGeoCoordToScreen(
    GeoCoord coord, {
    required Offset? Function(GeoCoord coord)? exactProjector,
    required GeoCoord cameraPosition,
    required Offset screenCenter,
    required double zoom,
  }) {
    final exactProjection = exactProjector?.call(coord);
    if (exactProjection != null) return exactProjection;
    return _fallbackProjectGeoCoordToScreen(
      coord,
      cameraPosition,
      screenCenter,
      zoom: zoom,
    );
  }

  Offset _fallbackProjectGeoCoordToScreen(
    GeoCoord coord,
    GeoCoord cameraPosition,
    Offset screenCenter, {
    required double zoom,
  }) {
    return CellOverlayPainter.projectGeoCoord(
      coord: coord,
      cameraPosition: cameraPosition,
      zoom: zoom,
      cameraPixelOffset: screenCenter,
    );
  }

  List<_KnownVenueAnchor> _knownVenueAnchors(
    TownProjection? town,
    List<({Cell cell, CellState state})> cellsWithStates,
  ) {
    if (town == null || town.venues.isEmpty || cellsWithStates.isEmpty) {
      return const [];
    }

    final renderedCellsById = {
      for (final entry in cellsWithStates) entry.cell.id: entry,
    };
    final anchors = <_KnownVenueAnchor>[];
    for (final venue in town.venues) {
      final anchorCellId = venue.venue.anchorCellId;
      final entry = renderedCellsById[anchorCellId];
      if (entry == null ||
          (entry.state.knowledgeState != CellKnowledgeState.explored &&
              entry.state.knowledgeState != CellKnowledgeState.present)) {
        continue;
      }
      final position = _cellCenter(entry.cell);
      if (position == null) continue;
      anchors.add(
        _KnownVenueAnchor(
          venue: venue,
          anchorCellId: anchorCellId,
          position: position,
          relationship: entry.state.relationship,
        ),
      );
    }
    return List<_KnownVenueAnchor>.unmodifiable(anchors);
  }

  void _showCellDetailSheet(
    BuildContext context,
    Cell cell,
    bool isFirstVisit,
    CellState cellState,
    List<TownVenue> knownVenues,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => CellDetailSheet(
        cell: cell,
        visitCount: isFirstVisit ? 0 : 1,
        isFirstVisit: isFirstVisit,
        currentRelationship: cellState.relationship,
        knowledgeState: cellState.knowledgeState,
        category: cellState.category,
        knownVenues: switch (cellState.knowledgeState) {
          CellKnowledgeState.explored ||
          CellKnowledgeState.present => knownVenues,
          CellKnowledgeState.informed ||
          CellKnowledgeState.shrouded => const [],
        },
      ),
    );
  }

  List<({Cell cell, CellState state})> _buildCellStates(
    MapStateReady mapState,
    Set<String> exploredCellIds,
    ExplorationStateData explorationState,
  ) {
    return const FogStateService().compute(
      cells: mapState.cells,
      currentCellId: explorationState.currentCellId,
      exploredCellIds: exploredCellIds,
      currentPositionIsTrusted: explorationState.currentPositionIsTrusted,
      knowledgeByCellId: mapState.knowledgeByCellId,
    );
  }
}

class _KnownVenueAnchor {
  const _KnownVenueAnchor({
    required this.venue,
    required this.anchorCellId,
    required this.position,
    required this.relationship,
  });

  final TownVenue venue;
  final String anchorCellId;
  final GeoCoord position;
  final CellRelationship relationship;
}

class _ExactScreenProjectionRequest {
  const _ExactScreenProjectionRequest({
    required this.key,
    required this.coordinates,
    required this.coordinateKeys,
    required this.cellCenterCoordKeyById,
    required this.markerCoordKey,
    required this.cameraCoordKey,
  });

  factory _ExactScreenProjectionRequest.from({
    required List<({Cell cell, CellState state})> cellsWithStates,
    required GeoCoord markerPosition,
    required GeoCoord cameraPosition,
    required double zoom,
  }) {
    final coordinates = <GeoCoord>[];
    final coordinateKeys = <String>[];
    final seenKeys = <String>{};

    String addCoordinate(GeoCoord coord) {
      final key = _projectionCoordKey(coord);
      if (seenKeys.add(key)) {
        coordinates.add(coord);
        coordinateKeys.add(key);
      }
      return key;
    }

    final markerCoordKey = addCoordinate(markerPosition);
    final cameraCoordKey = addCoordinate(cameraPosition);
    final cellCenterCoordKeyById = <String, String>{};
    for (final entry in cellsWithStates) {
      for (final polygon in entry.cell.polygons) {
        for (final ring in polygon) {
          for (final coord in ring) {
            addCoordinate(coord);
          }
        }
      }
      final center = _cellCenter(entry.cell);
      if (center != null) {
        cellCenterCoordKeyById[entry.cell.id] = addCoordinate(center);
      }
    }

    final keyBuffer = StringBuffer()
      ..write('camera=')
      ..write(_projectionCoordKey(cameraPosition))
      ..write(':zoom=')
      ..write(zoom.toStringAsFixed(4))
      ..write(':marker=')
      ..write(markerCoordKey);
    for (final coordKey in coordinateKeys) {
      keyBuffer
        ..write('|')
        ..write(coordKey);
    }

    return _ExactScreenProjectionRequest(
      key: keyBuffer.toString(),
      coordinates: coordinates,
      coordinateKeys: coordinateKeys,
      cellCenterCoordKeyById: cellCenterCoordKeyById,
      markerCoordKey: markerCoordKey,
      cameraCoordKey: cameraCoordKey,
    );
  }

  final String key;
  final List<GeoCoord> coordinates;
  final List<String> coordinateKeys;
  final Map<String, String> cellCenterCoordKeyById;
  final String markerCoordKey;
  final String cameraCoordKey;
}

String _projectionCoordKey(GeoCoord coord) {
  return '${coord.lat.toStringAsFixed(7)},${coord.lng.toStringAsFixed(7)}';
}

GeoCoord? _cellCenter(Cell cell) {
  final exteriorPoints = cell.exteriorPoints;
  if (exteriorPoints.isEmpty) return null;

  var sumLat = 0.0;
  var sumLng = 0.0;
  for (final coord in exteriorPoints) {
    sumLat += coord.lat;
    sumLng += coord.lng;
  }
  return (
    lat: sumLat / exteriorPoints.length,
    lng: sumLng / exteriorPoints.length,
  );
}

class MapCellKnowledgeLegend extends StatelessWidget {
  const MapCellKnowledgeLegend({super.key});

  @override
  Widget build(BuildContext context) {
    const entries = <({String keyName, String label, CellState state})>[
      (
        keyName: 'shrouded',
        label: 'Shrouded',
        state: CellState(
          knowledgeState: CellKnowledgeState.shrouded,
          relationship: CellRelationship.unknown,
          contents: CellContents.empty,
        ),
      ),
      (
        keyName: 'informed',
        label: 'Informed',
        state: CellState(
          knowledgeState: CellKnowledgeState.informed,
          category: 'category',
          relationship: CellRelationship.explored,
          contents: CellContents.empty,
        ),
      ),
      (
        keyName: 'explored',
        label: 'Explored',
        state: CellState(
          knowledgeState: CellKnowledgeState.explored,
          relationship: CellRelationship.explored,
          contents: CellContents.empty,
        ),
      ),
      (
        keyName: 'present',
        label: 'Present',
        state: CellState(
          knowledgeState: CellKnowledgeState.present,
          relationship: CellRelationship.present,
          contents: CellContents.empty,
        ),
      ),
    ];

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Cell knowledge',
      child: ShadCard(
        key: const ValueKey('map-cell-knowledge-legend'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        shadows: const [],
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: Spacing.md,
          runSpacing: Spacing.xs,
          children: [
            for (final entry in entries)
              _MapCellKnowledgeLegendItem(
                key: ValueKey('cell-knowledge-${entry.keyName}'),
                label: entry.label,
                state: entry.state,
              ),
          ],
        ),
      ),
    );
  }
}

class _MapCellKnowledgeLegendItem extends StatelessWidget {
  const _MapCellKnowledgeLegendItem({
    super.key,
    required this.label,
    required this.state,
  });

  final String label;
  final CellState state;

  @override
  Widget build(BuildContext context) {
    final fill = FogRenderer.fillColor(state);
    final stroke = FogRenderer.strokeColor(state);
    final semanticLabel = switch (state.knowledgeState) {
      CellKnowledgeState.informed => 'Informed Cell, category known',
      CellKnowledgeState.present => 'Present Cell, player here',
      CellKnowledgeState.explored => 'Explored Cell',
      CellKnowledgeState.shrouded => 'Shrouded Cell',
    };
    return Semantics(
      container: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: Spacing.xxl,
            height: Spacing.xxl,
            decoration: BoxDecoration(
              color: fill,
              border: stroke.a > 0 ? Border.all(color: stroke) : null,
              borderRadius: BorderRadius.circular(Radii.xs),
            ),
            child: switch (state.knowledgeState) {
              CellKnowledgeState.informed => const Icon(
                key: ValueKey('cell-knowledge-informed-category-cue'),
                Icons.category,
                size: Spacing.xl,
              ),
              CellKnowledgeState.present => Center(
                child: Container(
                  key: const ValueKey('cell-knowledge-present-player-marker'),
                  width: Spacing.lg,
                  height: Spacing.lg,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: Spacing.xxs),
                  ),
                  child: Container(
                    key: const ValueKey('cell-knowledge-present-player-dot'),
                    width: Spacing.xs,
                    height: Spacing.xs,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              CellKnowledgeState.explored ||
              CellKnowledgeState.shrouded => null,
            },
          ),
          const SizedBox(width: Spacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class DiscoveryPausedBanner extends StatelessWidget {
  const DiscoveryPausedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const ValueKey('discovery-paused-status'),
      container: true,
      liveRegion: true,
      label: 'Discovery paused',
      child: const ExcludeSemantics(
        child: AppCard(
          child: AppNotice(
            title: 'Discovery paused',
            message: 'Waiting for reliable GPS before recording progress.',
            tone: AppNoticeTone.warning,
          ),
        ),
      ),
    );
  }
}

class _MapSteadyStateLoadingOverlay extends StatelessWidget {
  const _MapSteadyStateLoadingOverlay({required this.waitingFor});

  final List<String> waitingFor;

  @override
  Widget build(BuildContext context) {
    final waitingText = waitingFor.isEmpty
        ? 'Revealing map...'
        : 'Revealing map... ${waitingFor.first.replaceAll('_', ' ')}';

    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Semantics(
                key: const ValueKey('map-readiness-cover'),
                container: true,
                liveRegion: true,
                label: waitingText,
                child: ExcludeSemantics(
                  child: AppCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const LoadingDots(),
                        const SizedBox(height: Spacing.lg),
                        Text(
                          waitingText,
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

@visibleForTesting
Widget buildDiscoveryRewardModalForTesting({
  required Encounter encounter,
  required VoidCallback onContinue,
}) {
  return _DiscoveryRewardModal(encounter: encounter, onContinue: onContinue);
}

class _DiscoveryRewardModal extends StatelessWidget {
  const _DiscoveryRewardModal({
    required this.encounter,
    required this.onContinue,
  });

  final Encounter encounter;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final rewardLabel =
        encounter.acquiredItem?.visibleDisplayName ??
        (encounter.type == EncounterType.species
            ? 'Unidentified fauna specimen'
            : encounter.displayName);

    // eac-clickable-owner-logs: MapScreen passes an ObservableInteraction-wrapped continue-discovery-reward callback into every dismissal surface.
    return BlockSemantics(
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): onContinue,
        },
        child: FocusScope(
          child: Semantics(
            scopesRoute: true,
            namesRoute: true,
            liveRegion: true,
            explicitChildNodes: true,
            label: 'Discovery reward: $rewardLabel. Added to Pack.',
            // eac-clickable-owner-logs: onTap uses MapScreen's ObservableInteraction-wrapped continueDiscoveryReward callback and stable action evidence.
            child: GestureDetector(
              key: const Key('discovery-reward-modal'),
              behavior: HitTestBehavior.opaque,
              onTap: onContinue,
              child: ColoredBox(
                color: Theme.of(
                  context,
                ).colorScheme.scrim.withValues(alpha: 0.72),
                child: SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(Spacing.xxl),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _DiscoveryRewardCard(encounter: encounter),
                            const SizedBox(height: Spacing.lg),
                            // eac-clickable-owner-logs: the same wrapped callback preserves the stable continue action boundary.
                            Focus(
                              autofocus: true,
                              child: AppButton(
                                label: 'Return to Map',
                                onPressed: onContinue,
                                expand: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscoveryRewardCard extends StatelessWidget {
  const _DiscoveryRewardCard({required this.encounter});

  final Encounter encounter;

  @override
  Widget build(BuildContext context) {
    final title =
        encounter.acquiredItem?.visibleDisplayName ??
        (encounter.type == EncounterType.species
            ? 'Unidentified fauna specimen'
            : encounter.displayName);

    return ExcludeSemantics(
      child: AppCard(
        title: 'Added to Pack',
        description: 'Identify this specimen later to reveal the species.',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 44,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(height: Spacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _MapLoadingScaffold extends StatelessWidget {
  const _MapLoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Semantics(
            container: true,
            liveRegion: true,
            label: 'Finding your location',
            child: const ExcludeSemantics(
              child: AppCard(
                title: 'Finding your location',
                child: LoadingDots(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapStatusScaffold extends StatelessWidget {
  const _MapStatusScaffold({
    required this.title,
    required this.message,
    this.tone = AppNoticeTone.error,
  });

  final String title;
  final String message;
  final AppNoticeTone tone;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Spacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AppCard(
                child: AppNotice(title: title, message: message, tone: tone),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
