import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;

import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/features/map/domain/entities/location_state.dart';
import 'package:earth_nova/features/map/domain/entities/encounter.dart';
import 'package:earth_nova/features/map/domain/entities/player_marker_state.dart';
import 'package:earth_nova/features/map/domain/services/fog_state_service.dart';
import 'package:earth_nova/features/map/domain/services/explored_footprint_service.dart';
import 'package:earth_nova/features/map/presentation/painters/cell_overlay_painter.dart';
import 'package:earth_nova/features/map/presentation/painters/player_marker.dart';
import 'package:earth_nova/features/map/presentation/providers/encounter_provider.dart';
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
import 'package:earth_nova/features/map/presentation/widgets/shimmer_cells.dart';
import 'package:earth_nova/shared/observability/widgets/observable_interaction.dart';
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

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  maplibre.MapLibreMapController? _mapController;

  /// Cell ID for the currently-shown discovery notification (null = hidden).
  String? _notificationCellId;
  Timer? _notificationTimer;

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _showDiscoveryNotification(String cellId) {
    _notificationTimer?.cancel();
    setState(() => _notificationCellId = cellId);
    _notificationTimer = Timer(_kDiscoveryNotificationDuration, () {
      if (mounted) setState(() => _notificationCellId = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final obs = ref.watch(appObservabilityProvider);
    final authState = ref.watch(authProvider);
    final userId =
        authState.status == AuthStatus.authenticated ? authState.user!.id : '';
    final locationState = ref.watch(locationProvider);
    final mapState = ref.watch(mapProvider);
    final playerMarkerState = ref.watch(playerMarkerProvider);
    final explorationEligibility = ref.watch(explorationEligibilityProvider);
    final explorationState = ref.watch(explorationProvider);
    final encounterState = ref.watch(encounterProvider);

    // Move camera when GPS updates — without this, removing the location-keyed
    // ValueKey would freeze the map on its initial position.
    ref.listen<LocationProviderState>(locationProvider, (_, next) {
      if (next is LocationProviderActive && _mapController != null) {
        _mapController!.moveCamera(
          maplibre.CameraUpdate.newLatLng(
            maplibre.LatLng(next.location.lat, next.location.lng),
          ),
        );
      }
    });

    ref.listen<PlayerMarkerState>(playerMarkerProvider, (_, markerState) {
      final mapState = ref.read(mapProvider);
      if (mapState case MapStateReady(:final cells, :final visitedCellIds)) {
        unawaited(
          ref.read(explorationProvider.notifier).onPositionUpdate(
                markerState: markerState,
                cells: cells,
                visitedCellIds: visitedCellIds,
                userId: userId,
              ),
        );
      }
    });

    ref.listen<MapState>(mapProvider, (_, next) {
      if (next case MapStateReady(:final cells, :final visitedCellIds)) {
        unawaited(
          ref.read(explorationProvider.notifier).onPositionUpdate(
                markerState: ref.read(playerMarkerProvider),
                cells: cells,
                visitedCellIds: visitedCellIds,
                userId: userId,
              ),
        );
      }
    });

    // Listen for cell entry events to trigger encounters and discovery notification
    ref.listen<ExplorationStateData>(explorationProvider, (previous, next) {
      if (previous?.currentCellId != next.currentCellId &&
          next.currentCellId != null) {
        final isFirstVisit = previous == null ||
            !previous.visitedCellIds.contains(next.currentCellId);
        ref.read(encounterProvider.notifier).onCellEntered(
              cellId: next.currentCellId!,
              isFirstVisit: isFirstVisit,
            );
        // Show discovery notification on first visit
        if (isFirstVisit) {
          _showDiscoveryNotification(next.currentCellId!);
          ref.read(mapProvider.notifier).obs.log(
            'map.discovery_notification_shown',
            'map',
            data: {'cell_id': next.currentCellId},
          );
        }
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
    required ExplorationEligibility explorationEligibility,
    required ExplorationStateData explorationState,
    required EncounterState encounterState,
  }) {
    void logger({
      required String event,
      required String category,
      Map<String, dynamic>? data,
    }) {
      ref.read(mapProvider.notifier).obs.log(event, category, data: data);
    }

    final footprint = const ExploredFootprintService().project(
      persistedVisitedCellIds:
          mapState is MapStateReady ? mapState.visitedCellIds : const {},
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
          final markerScreenPosition = _latLngToScreen(
            (lat: playerMarkerState.lat, lng: playerMarkerState.lng),
            (lat: location.lat, lng: location.lng),
            _kGpsZoom,
            screenCenter,
          );

          return Stack(
            children: [
              // Base map layer — key must NOT include location data.
              // Previously `ValueKey('$timestamp:$lat:$lng')` caused the entire
              // MapLibreMap (and its GL context) to be torn down and rebuilt on
              // every GPS tick (~1 Hz), making the map constantly flash.
              // Camera follow is handled via _mapController.moveCamera() above.
              Positioned.fill(
                child: maplibre.MapLibreMap(
                  styleString: _kMapStyleUrl,
                  initialCameraPosition: maplibre.CameraPosition(
                    target: maplibre.LatLng(location.lat, location.lng),
                    zoom: _kGpsZoom,
                  ),
                  compassEnabled: false,
                  rotateGesturesEnabled: false,
                  scrollGesturesEnabled: false,
                  zoomGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  doubleClickZoomEnabled: false,
                  dragEnabled: false,
                  myLocationEnabled: false,
                  myLocationTrackingMode: maplibre.MyLocationTrackingMode.none,
                  attributionButtonPosition:
                      maplibre.AttributionButtonPosition.topRight,
                  attributionButtonMargins: const math.Point(12, 144),
                  onMapCreated: (controller) {
                    _mapController = controller;
                    ref
                        .read(mapProvider.notifier)
                        .obs
                        .log('map.map_created', 'map');
                  },
                  onStyleLoadedCallback: () {
                    ref
                        .read(mapProvider.notifier)
                        .obs
                        .log('map.style_loaded', 'map');
                    ref.read(mapProvider.notifier).setZoom(_kGpsZoom);
                  },
                ),
              ),

              // Shimmer while loading
              if (mapState is MapStateLoading)
                Positioned.fill(
                  child: ShimmerCells(
                    cameraPosition: (lat: location.lat, lng: location.lng),
                    zoom: _kGpsZoom,
                  ),
                ),

              // Cell overlay layer - drawn on top of map using Flutter Canvas
              if (mapState is MapStateReady)
                Positioned.fill(
                  child: GestureDetector(
                    onTapUp: ObservableInteraction.wrapTapUp(
                      logger: logger,
                      screenName: 'map_screen',
                      widgetName: 'cell_overlay',
                      actionType: 'cell_overlay_tap',
                      callback: (details) => _onMapTap(
                        context,
                        details,
                        mapState,
                        location,
                        screenCenter,
                      ),
                    ),
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: CellOverlayPainter(
                        cellsWithStates: _buildCellStates(
                          mapState.cells,
                          footprint.visitedCellIds,
                          explorationState,
                        ),
                        cameraPosition: (
                          lat: location.lat,
                          lng: location.lng,
                        ),
                        zoom: _kGpsZoom,
                        cameraPixelOffset: screenCenter,
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
                      callback: () {
                        ref.read(encounterProvider.notifier).dismissEncounter();
                      },
                    ),
                  ),
                ),

              // Loading indicator
              if (mapState is MapStateLoading)
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
    LocationState location,
    Offset screenCenter,
  ) {
    final tapPosition = details.localPosition;

    // Find the cell that was tapped (simplified - find closest cell center)
    Cell? closestCell;
    double closestDistance = double.infinity;

    for (final cell in mapState.cells) {
      final exteriorPoints = cell.exteriorPoints;
      if (exteriorPoints.isEmpty) continue;

      double sumLat = 0;
      double sumLng = 0;
      for (final coord in exteriorPoints) {
        sumLat += coord.lat;
        sumLng += coord.lng;
      }
      final centerLat = sumLat / exteriorPoints.length;
      final centerLng = sumLng / exteriorPoints.length;

      final screenPos = _latLngToScreen(
        (lat: centerLat, lng: centerLng),
        (lat: location.lat, lng: location.lng),
        _kGpsZoom,
        screenCenter,
      );

      final distance = (tapPosition - screenPos).distance;
      if (distance < closestDistance && distance < 100) {
        closestDistance = distance;
        closestCell = cell;
      }
    }

    if (closestCell != null) {
      final isFirstVisit = !mapState.visitedCellIds.contains(closestCell.id);
      _showCellDetailSheet(context, closestCell, isFirstVisit);
    }
  }

  Offset _latLngToScreen(
    ({double lat, double lng}) coord,
    ({double lat, double lng}) cameraPosition,
    double zoom,
    Offset screenCenter,
  ) {
    const earthCircumference = 156543.03392;
    final metersPerPixel = earthCircumference *
        math.cos(cameraPosition.lat * math.pi / 180) /
        math.pow(2, zoom);

    final dx = (coord.lng - cameraPosition.lng) *
        metersPerPixel *
        math.cos(cameraPosition.lat * math.pi / 180);
    final dy = (coord.lat - cameraPosition.lat) * metersPerPixel;

    return Offset(screenCenter.dx + dx, screenCenter.dy - dy);
  }

  void _showCellDetailSheet(
    BuildContext context,
    Cell cell,
    bool isFirstVisit,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => CellDetailSheet(
        cell: cell,
        visitCount: 1,
        isFirstVisit: isFirstVisit,
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
