import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;

import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
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
import 'package:earth_nova/features/map/presentation/painters/player_marker.dart';
import 'package:earth_nova/features/map/presentation/providers/camera_follow_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/encounter_provider.dart';
import 'package:earth_nova/features/map/presentation/platform/base_map_settled_signal.dart';
import 'package:earth_nova/features/map/presentation/platform/base_map_style_loaded_signal.dart';
import 'package:earth_nova/features/map/presentation/platform/map_style_label_layers.dart';
import 'package:earth_nova/features/map/presentation/presenters/encounter_presenter.dart';
import 'package:earth_nova/features/map/presentation/providers/exploration_eligibility_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/exploration_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/location_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/map_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/player_marker_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/visit_queue_provider.dart';
import 'package:earth_nova/features/map/presentation/widgets/cell_detail_sheet.dart';
import 'package:earth_nova/features/map/presentation/widgets/discovery_notification.dart';
import 'package:earth_nova/features/map/presentation/widgets/map_status_bar.dart';
import 'package:earth_nova/features/map/presentation/state/map_readiness_state.dart';
import 'package:earth_nova/features/map/presentation/widgets/shimmer_cells.dart';
import 'package:earth_nova/shared/observability/widgets/observable_interaction.dart';
import 'package:earth_nova/shared/product/player_actions.dart';
import 'package:earth_nova/shared/observability/widgets/observable_screen.dart';
import 'package:earth_nova/shared/theme/app_theme.dart';
import 'package:earth_nova/shared/widgets/loading_dots.dart';

const _kMapStyleUrl = 'https://tiles.openfreemap.org/styles/liberty';
const _kGpsZoom = 15.0;

/// Build version injected at compile time via --dart-define=BUILD_TIMESTAMP.
/// Format: yyyy-mm-dd-hhmm-commit (AST). Falls back to 'dev' for local builds.
const _kBuildVersion =
    String.fromEnvironment('BUILD_TIMESTAMP', defaultValue: 'dev');

/// Duration the discovery notification is visible before auto-dismissing.
const _kDiscoveryNotificationDuration = Duration(seconds: 3);
const _kBaseMapSettledFallbackDelay = Duration(seconds: 5);
const _kMapBootstrapTimeout = Duration(seconds: 12);

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  maplibre.MapLibreMapController? _mapController;

  bool _mapCreated = false;
  bool _mapStyleLoaded = false;
  bool _baseMapSettled = false;
  bool _baseMapTextLabelsHidden = false;
  bool _overlayFramePainted = false;
  bool _steadyStateLogged = false;
  bool _readinessWaitingLogged = false;
  BaseMapSettledSignal? _baseMapSettledSignal;
  BaseMapStyleLoadedSignal? _baseMapStyleLoadedSignal;
  Timer? _mapSettledFallbackTimer;
  Timer? _mapBootstrapTimeoutTimer;
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

  /// Cell ID for the currently-shown discovery notification (null = hidden).
  String? _notificationCellId;
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    _mapBootstrapSpan = ref.read(appObservabilityProvider).startSpan(
      'map.bootstrap',
      attributes: {'flow': 'map.bootstrap', 'screen': 'map_screen'},
    );
    ref.read(appObservabilityProvider).logFlowEvent(
      'map.bootstrap',
      TelemetryFlowPhase.started,
      'map',
      span: _mapBootstrapSpan,
      data: {'screen': 'map_screen'},
    );
    _mapBootstrapTimeoutTimer = Timer(
      _kMapBootstrapTimeout,
      _handleMapBootstrapTimeout,
    );
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
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _baseMapSettledSignal?.dispose();
    _baseMapStyleLoadedSignal?.dispose();
    _mapSettledFallbackTimer?.cancel();
    _mapBootstrapTimeoutTimer?.cancel();
    final span = _mapBootstrapSpan;
    if (span != null && !_steadyStateLogged) {
      ref.read(appObservabilityProvider).logFlowEvent(
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
    super.dispose();
  }

  TelemetrySpan _ensureMapBootstrapSpan() {
    final existing = _mapBootstrapSpan;
    if (existing != null) return existing;
    final span = ref.read(appObservabilityProvider).startSpan(
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
    ref.read(appObservabilityProvider).endSpan(
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
    ref.read(appObservabilityProvider).log(
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
    ref.read(appObservabilityProvider).logFlowEvent(
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
    if (_mapCreated) return;
    setState(() => _mapCreated = true);
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
    if (!_mapStyleLoaded) {
      setState(() => _mapStyleLoaded = true);
    }
    _scheduleBaseMapSettledFallback();
  }

  void _handleStyleLoaded({required String source}) {
    if (_mapStyleLoaded) {
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
        data: {
          'source': source,
          'reason': error.toString(),
        },
      );
    }
  }

  void _scheduleBaseMapSettledFallback({
    String source = 'style_loaded_fallback',
  }) {
    if (_baseMapSettled) return;
    _mapSettledFallbackTimer?.cancel();
    _mapSettledFallbackTimer = Timer(_kBaseMapSettledFallbackDelay, () {
      _mapSettledFallbackTimer = null;
      if (mounted) _markBaseMapSettled(source: source);
    });
  }

  void _markBaseMapSettled({required String source}) {
    if (_baseMapSettled) return;
    _mapSettledFallbackTimer?.cancel();
    _mapSettledFallbackTimer = null;
    setState(() => _baseMapSettled = true);
    _logMapFlowEvent(
      TelemetryFlowPhase.dependencyReady,
      eventName: 'map.base_map_settled',
      dependency: 'base_map',
      data: {'source': source},
    );
  }

  void _ensureBaseMapSettledFallback(MapReadinessState readiness) {
    if (_baseMapSettled || _mapSettledFallbackTimer != null) return;
    if (!readiness.mapCreated ||
        !readiness.styleLoaded ||
        !readiness.cellsFetched) {
      return;
    }
    _scheduleBaseMapSettledFallback(source: 'readiness_safety_fallback');
  }

  void _resetOverlayReadinessForRefetch() {
    if (!_overlayFramePainted && !_steadyStateLogged) return;
    setState(() {
      _overlayFramePainted = false;
      _steadyStateLogged = false;
      _readinessWaitingLogged = false;
    });
  }

  MapStateReady? _renderableMapState(MapState mapState) {
    return switch (mapState) {
      MapStateReady ready => ready,
      MapStateRefreshing refreshing => refreshing.previous,
      _ => null,
    };
  }

  MapReadinessState _readinessFor({
    required bool locationReady,
    required MapState mapState,
  }) {
    return MapReadinessState(
      locationReady: locationReady,
      mapCreated: _mapCreated,
      styleLoaded: _mapStyleLoaded,
      baseMapSettled: _baseMapSettled,
      cellsFetched: _renderableMapState(mapState) != null,
      overlayFramePainted: _overlayFramePainted,
    );
  }

  void _armOverlayFrameReadiness(
    MapReadinessState readiness, {
    required Map<String, dynamic> renderDiagnostics,
  }) {
    final canPaintSteadyOverlay = readiness.locationReady &&
        readiness.mapCreated &&
        readiness.styleLoaded &&
        readiness.baseMapSettled &&
        readiness.cellsFetched;

    if (!canPaintSteadyOverlay || readiness.overlayFramePainted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _overlayFramePainted) return;
      setState(() => _overlayFramePainted = true);
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
      dependency:
          readiness.waitingFor.isEmpty ? null : readiness.waitingFor.first,
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
    _logMapEvent(
      'map.geometry_rendered',
      data: renderDiagnostics,
    );
  }

  void _logSteadyStateReady() {
    if (_steadyStateLogged) return;
    _steadyStateLogged = true;
    final readiness = MapReadinessState(
      locationReady: true,
      mapCreated: _mapCreated,
      styleLoaded: _mapStyleLoaded,
      baseMapSettled: _baseMapSettled,
      cellsFetched: true,
      overlayFramePainted: true,
    );
    _logMapFlowEvent(
      TelemetryFlowPhase.completed,
      eventName: 'map.steady_state_ready',
      data: readiness.toLogData(),
    );
    _mapBootstrapTimeoutTimer?.cancel();
    _mapBootstrapTimeoutTimer = null;
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

  void _scheduleExactScreenProjection(
    _ExactScreenProjectionRequest request,
  ) {
    if (!_mapCreated ||
        !_mapStyleLoaded ||
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

      final hasNewerPending = _pendingExactScreenProjectionRequest != null &&
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

  Offset? _exactProjectedMarkerPosition(String projectionKey) {
    if (_exactScreenProjectionKey != projectionKey) return null;
    return _exactScreenProjectionMarkerScreenPosition;
  }

  Offset? _exactProjectedCellCenter(
    String projectionKey,
    String cellId,
  ) {
    if (_exactScreenProjectionKey != projectionKey) return null;
    return _exactScreenProjectionCellCentersById[cellId];
  }

  void _handleMapBootstrapTimeout() {
    if (!mounted || _steadyStateLogged) return;
    final locationState = ref.read(locationProvider);
    final readiness = _readinessFor(
      locationReady: locationState is LocationProviderActive ||
          locationState is LocationProviderPaused,
      mapState: ref.read(mapProvider),
    );
    _logMapFlowEvent(
      TelemetryFlowPhase.timedOut,
      eventName: 'map.bootstrap.timed_out',
      dependency:
          readiness.waitingFor.isEmpty ? null : readiness.waitingFor.first,
      reason: 'steady_state_not_reached',
      data: {
        ...readiness.toLogData(),
        ..._locationStateDiagnostics(locationState),
        'waiting_for': readiness.waitingFor,
        'timeout_ms': _kMapBootstrapTimeout.inMilliseconds,
      },
    );
    _endMapBootstrapSpan(
      statusCode: TelemetrySpanStatus.error,
      statusMessage: 'steady_state_not_reached',
      attributes: {
        ...readiness.toLogData(),
        ..._locationStateDiagnostics(locationState),
        'timeout_ms': _kMapBootstrapTimeout.inMilliseconds,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final obs = ref.watch(appObservabilityProvider);
    final authState = ref.watch(authProvider);
    final userId =
        authState.status == AuthStatus.authenticated ? authState.user!.id : '';
    final locationState = ref.watch(locationProvider);
    final mapState = ref.watch(mapProvider);
    final cameraFollowState = ref.watch(cameraFollowProvider);
    final playerMarkerState = ref.watch(playerMarkerProvider);
    final explorationEligibility = ref.watch(explorationEligibilityProvider);
    final explorationState = ref.watch(explorationProvider);
    final encounterState = ref.watch(encounterProvider);

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
      if (mapState case MapStateReady(:final cells, :final visitedCellIds)) {
        final explorationEligibility = ref.read(explorationEligibilityProvider);
        unawaited(
          ref.read(explorationProvider.notifier).onPositionUpdate(
                markerState: markerState,
                cells: cells,
                visitedCellIds: visitedCellIds,
                userId: userId,
                explorationEligibility: explorationEligibility,
              ),
        );
      }
    });

    ref.listen<MapState>(mapProvider, (_, next) {
      if (next is MapStateLoading) {
        _resetOverlayReadinessForRefetch();
      }
      if (next case MapStateReady(:final cells, :final visitedCellIds)) {
        final explorationEligibility = ref.read(explorationEligibilityProvider);
        unawaited(
          ref.read(explorationProvider.notifier).onPositionUpdate(
                markerState: ref.read(playerMarkerProvider),
                cells: cells,
                visitedCellIds: visitedCellIds,
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
      final isNewGameplayEntry = borderCrossingEvent != null &&
          borderCrossingEvent.mapCellEntryId != previousMapCellEntryId;
      if (!isNewGameplayEntry) return;

      final enteredCellId = borderCrossingEvent.enteredCellId;
      final isFirstVisit = borderCrossingEvent.isFirstVisit;
      ref.read(encounterProvider.notifier).onCellEntered(
            cellId: enteredCellId,
            isFirstVisit: isFirstVisit,
            userId: userId,
            mapCellEntryId: borderCrossingEvent.mapCellEntryId,
          );
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
      LocationProviderPaused() => playerMarkerState.lat != 0.0
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
        LocationProviderLoading() => const Scaffold(
            backgroundColor: AppTheme.surface,
            body: Center(child: LoadingDots()),
          ),
        LocationProviderPermissionDenied() => const _MapStatusScaffold(
            title: 'Location needed',
            message: 'Enable location access to explore the map.',
          ),
        LocationProviderError(message: final message) => _MapStatusScaffold(
            title: 'Map unavailable',
            message: message,
          ),
        LocationProviderPaused() when effectiveLocation == null =>
          const _MapStatusScaffold(
            title: 'GPS unavailable',
            message: 'Waiting for GPS signal to resume discovery.',
          ),
        LocationProviderPaused() ||
        LocationProviderActive() =>
          _buildMapScaffold(
            context,
            location: effectiveLocation!,
            mapState: mapState,
            cameraFollowState: cameraFollowState,
            playerMarkerState: playerMarkerState,
            explorationEligibility: explorationEligibility,
            explorationState: explorationState,
            encounterState: encounterState,
          ),
      },
    );
  }

  Widget _buildMapScaffold(
    BuildContext context, {
    required LocationState location,
    required MapState mapState,
    required PlayerMarkerState playerMarkerState,
    required CameraFollowState cameraFollowState,
    required ExplorationEligibility explorationEligibility,
    required ExplorationStateData explorationState,
    required EncounterState encounterState,
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
    final visitQueueState = ref.watch(visitQueueProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final mapSize = constraints.biggest;
          final screenCenter = Offset(mapSize.width / 2, mapSize.height / 2);
          final desiredCameraPosition = cameraFollowState.hasFix
              ? (lat: cameraFollowState.lat, lng: cameraFollowState.lng)
              : (lat: location.lat, lng: location.lng);
          final renderCameraPosition =
              _renderCameraPosition ?? desiredCameraPosition;
          final renderZoom = _renderCameraZoom ?? _kGpsZoom;
          final cellsWithStates = renderableMapState != null
              ? _buildCellStates(
                  renderableMapState.cells,
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
          final projectionMode = exactProjectionReady
              ? 'maplibre_exact_screen'
              : 'mercator_fallback';
          final exactProjector =
              _exactScreenProjectionProjector(exactProjectionRequest.key);
          Offset projectGeoCoord(GeoCoord coord) {
            return _projectGeoCoordToScreen(
              coord,
              exactProjector: exactProjector,
              cameraPosition: renderCameraPosition,
              screenCenter: screenCenter,
              zoom: renderZoom,
            );
          }

          final markerScreenPosition =
              _exactProjectedMarkerPosition(exactProjectionRequest.key) ??
                  projectGeoCoord(markerGeoCoord);
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
            'screen_projection_revision':
                exactProjectionReady ? _exactScreenProjectionRevision : null,
          };
          final readiness = _readinessFor(
            locationReady: true,
            mapState: mapState,
          );
          _ensureBaseMapSettledFallback(readiness);
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
                child: maplibre.MapLibreMap(
                  styleString: _kMapStyleUrl,
                  initialCameraPosition: maplibre.CameraPosition(
                    target: maplibre.LatLng(
                      desiredCameraPosition.lat,
                      desiredCameraPosition.lng,
                    ),
                    zoom: _kGpsZoom,
                  ),
                  compassEnabled: false,
                  rotateGesturesEnabled: false,
                  scrollGesturesEnabled: false,
                  zoomGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  doubleClickZoomEnabled: false,
                  dragEnabled: false,
                  trackCameraPosition: true,
                  myLocationEnabled: false,
                  myLocationTrackingMode: maplibre.MyLocationTrackingMode.none,
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
                  onStyleLoadedCallback: () {
                    _handleStyleLoaded(source: 'plugin_style_loaded');
                  },
                  onMapIdle: () {
                    _markBaseMapSettled(source: 'map_idle');
                  },
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
                  child: GestureDetector(
                    onTapUp: ObservableInteraction.wrapTapUp(
                      logger: logger,
                      screenName: 'map_screen',
                      widgetName: 'cell_overlay',
                      actionType: 'cell_overlay_tap',
                      playerActionId: PlayerActions.inspectMapCell,
                      callback: (details) => _onMapTap(
                        context,
                        details,
                        renderableMapState,
                        exactProjectionRequest.key,
                        cellsWithStates,
                        projectGeoCoord,
                      ),
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

              // Player marker overlay — the app owns one gameplay marker.
              if (playerMarkerState.lat != 0.0)
                Positioned(
                  left: markerScreenPosition.dx - 24,
                  top: markerScreenPosition.dy - 24,
                  child: const IgnorePointer(
                    child: PlayerMarker(),
                  ),
                ),

              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 156,
                child: IgnorePointer(child: _MapTopFogFeather()),
              ),
              // Frosted glass status bar — overlaid at top of map
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: MapStatusBar(
                  cellsObserved: cellsObserved,
                  totalSteps: 0,
                  streakDays: 0,
                  pendingVisits: visitQueueState.pendingCount,
                ),
              ),

              // Discovery notification — appears just below status bar on new cell entry
              if (_notificationCellId != null)
                Positioned(
                  top: 44 + 56 + 8,
                  left: 16,
                  right: 16,
                  child: IgnorePointer(
                    child: DiscoveryNotification(
                      cellName: _notificationCellId!,
                    ),
                  ),
                ),

              if (encounterState.currentEncounter != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 96,
                  child: _EncounterToast(
                    encounter: encounterState.currentEncounter!,
                    onDismiss: ObservableInteraction.wrapVoidCallback(
                      logger: logger,
                      screenName: 'map_screen',
                      widgetName: 'encounter_toast_dismiss',
                      actionType: 'toast_dismiss',
                      playerActionId: PlayerActions.acknowledgeDiscoveryResult,
                      callback: () {
                        ref.read(encounterProvider.notifier).dismissEncounter();
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

              // Build version — bottom-left corner, visible to devs during testing
              Positioned(
                left: 8,
                bottom: 8,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      child: Text(
                        'β $_kBuildVersion',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontFamily: 'monospace',
                          letterSpacing: 0,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Error message
              if (mapState is MapStateError)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 24,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.outline),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        mapState.message,
                        style: const TextStyle(color: AppTheme.onSurface),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),

              // Discovery paused banner — shown when GPS is unavailable or ring state
              if (explorationEligibility.isPaused)
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text(
                          'Discovery paused',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
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

  void _onMapTap(
    BuildContext context,
    TapUpDetails details,
    MapStateReady mapState,
    String exactProjectionKey,
    List<({Cell cell, CellState state})> cellsWithStates,
    Offset Function(GeoCoord coord) project,
  ) {
    final tapPosition = details.localPosition;

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
      _showCellDetailSheet(context, cell, isFirstVisit, closestEntry.state);
    }
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

  void _showCellDetailSheet(
    BuildContext context,
    Cell cell,
    bool isFirstVisit,
    CellState cellState,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => CellDetailSheet(
        cell: cell,
        visitCount: isFirstVisit ? 0 : 1,
        isFirstVisit: isFirstVisit,
        currentRelationship: cellState.relationship,
      ),
    );
  }

  List<({Cell cell, CellState state})> _buildCellStates(
    List<Cell> cells,
    Set<String> exploredCellIds,
    ExplorationStateData explorationState,
  ) {
    return const FogStateService().compute(
      cells: cells,
      currentCellId: explorationState.currentCellId,
      exploredCellIds: exploredCellIds,
    );
  }
}

class _ExactScreenProjectionRequest {
  const _ExactScreenProjectionRequest({
    required this.key,
    required this.coordinates,
    required this.coordinateKeys,
    required this.cellCenterCoordKeyById,
    required this.markerCoordKey,
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
    );
  }

  final String key;
  final List<GeoCoord> coordinates;
  final List<String> coordinateKeys;
  final Map<String, String> cellCenterCoordKeyById;
  final String markerCoordKey;
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

class _MapTopFogFeather extends StatelessWidget {
  const _MapTopFogFeather();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.surface.withValues(alpha: 0.62),
            AppTheme.surface.withValues(alpha: 0.32),
            AppTheme.surface.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.48, 1.0],
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
        ? 'Revealing map…'
        : 'Revealing map… ${waitingFor.first.replaceAll('_', ' ')}';

    return DecoratedBox(
      decoration: const BoxDecoration(color: AppTheme.surface),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LoadingDots(),
            const SizedBox(height: 16),
            Text(
              waitingText,
              style: const TextStyle(
                color: AppTheme.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EncounterToast extends StatelessWidget {
  const _EncounterToast({
    required this.encounter,
    required this.onDismiss,
  });

  final Encounter encounter;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(
              child: Text(
                EncounterPresenter.message(encounter),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onDismiss,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                minimumSize: const Size(64, 34),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Dismiss'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapStatusScaffold extends StatelessWidget {
  const _MapStatusScaffold({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(
                  color: AppTheme.onSurfaceVariant,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
