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
import 'package:earth_nova/features/map/domain/entities/player_marker_state.dart';
import 'package:earth_nova/features/map/presentation/painters/cell_overlay_painter.dart';
import 'package:earth_nova/features/map/presentation/providers/encounter_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/exploration_eligibility_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/exploration_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/location_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/map_controller_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/map_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/player_marker_provider.dart';
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
    ref.read(mapControllerProvider.notifier).clear();
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
    void logger({
      required String event,
      required String category,
      Map<String, dynamic>? data,
    }) {
      ref.read(mapProvider.notifier).obs.log(event, category, data: data);
    }

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

    // Show encounter Snackbar when triggered
    if (encounterState.currentEncounter != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              encounterState.currentEncounter!.type.name == 'species'
                  ? 'You found a ${encounterState.currentEncounter!.speciesId}!'
                  : 'A critter appeared!',
            ),
            backgroundColor: AppTheme.primary,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: ObservableInteraction.wrapVoidCallback(
                logger: logger,
                screenName: 'map_screen',
                widgetName: 'encounter_snackbar_dismiss',
                actionType: 'snackbar_dismiss',
                callback: () {
                  ref.read(encounterProvider.notifier).dismissEncounter();
                },
              ),
            ),
          ),
        );
        ref.read(encounterProvider.notifier).dismissEncounter();
      });
    }

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
  }) {
    void logger({
      required String event,
      required String category,
      Map<String, dynamic>? data,
    }) {
      ref.read(mapProvider.notifier).obs.log(event, category, data: data);
    }

    // Compute status bar stats from exploration state
    final cellsObserved = explorationState.visitedCellIds.length +
        (mapState is MapStateReady ? mapState.visitedCellIds.length : 0);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Stack(
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
              myLocationEnabled: true,
              myLocationTrackingMode: maplibre.MyLocationTrackingMode.tracking,
              onMapCreated: (controller) {
                _mapController = controller;
                ref.read(mapControllerProvider.notifier).set(controller);
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
              child: IgnorePointer(
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
                    ),
                  ),
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: CellOverlayPainter(
                      cellsWithStates: _buildCellStates(
                        mapState.cells,
                        mapState.visitedCellIds,
                        explorationState.visitedCellIds,
                      ),
                      cameraPosition: (
                        lat: location.lat,
                        lng: location.lng,
                      ),
                      zoom: _kGpsZoom,
                      cameraPixelOffset: Offset(
                        MediaQuery.of(context).size.width / 2,
                        MediaQuery.of(context).size.height / 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Player marker overlay
          if (playerMarkerState.lat != 0.0)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _PlayerMarkerPainter(
                    markerState: playerMarkerState,
                    isPaused: explorationEligibility.isPaused,
                    cameraPosition: (lat: location.lat, lng: location.lng),
                    zoom: _kGpsZoom,
                    screenCenter: Offset(
                      MediaQuery.of(context).size.width / 2,
                      MediaQuery.of(context).size.height / 2,
                    ),
                  ),
                ),
              ),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      ),
    );
  }

  void _onMapTap(
    BuildContext context,
    TapUpDetails details,
    MapStateReady mapState,
    LocationState location,
  ) {
    final tapPosition = details.localPosition;
    final screenCenter = Offset(
      MediaQuery.of(context).size.width / 2,
      MediaQuery.of(context).size.height / 2,
    );

    // Find the cell that was tapped (simplified - find closest cell center)
    Cell? closestCell;
    double closestDistance = double.infinity;

    for (final cell in mapState.cells) {
      if (cell.polygon.isEmpty) continue;

      // Calculate cell center in screen coordinates
      double sumLat = 0;
      double sumLng = 0;
      for (final coord in cell.polygon) {
        sumLat += coord.lat;
        sumLng += coord.lng;
      }
      final centerLat = sumLat / cell.polygon.length;
      final centerLng = sumLng / cell.polygon.length;

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
    Set<String> visitedCellIds,
    Set<String> explorationVisitedCellIds,
  ) {
    final allVisited = {...visitedCellIds, ...explorationVisitedCellIds};

    return cells.map((cell) {
      final isVisited = allVisited.contains(cell.id);
      final relationship =
          isVisited ? CellRelationship.explored : CellRelationship.nearby;

      return (
        cell: cell,
        state: CellState(
          relationship: relationship,
          contents: CellContents.empty,
        ),
      );
    }).toList();
  }
}

class _PlayerMarkerPainter extends CustomPainter {
  _PlayerMarkerPainter({
    required this.markerState,
    required this.isPaused,
    required this.cameraPosition,
    required this.zoom,
    required this.screenCenter,
  });

  final PlayerMarkerState markerState;
  final bool isPaused;
  final ({double lat, double lng}) cameraPosition;
  final double zoom;
  final Offset screenCenter;

  @override
  void paint(Canvas canvas, Size size) {
    if (markerState.lat == 0.0 && markerState.lng == 0.0) return;

    const earthCircumference = 156543.03392;
    // Divide by 2^zoom — previously used multiplication which made
    // metersPerPixel ~5 billion, placing the marker millions of pixels
    // off-screen and rendering it invisible.
    final metersPerPixel = earthCircumference *
        math.cos(cameraPosition.lat * math.pi / 180) /
        math.pow(2, zoom);

    final dx = (markerState.lng - cameraPosition.lng) *
        metersPerPixel *
        math.cos(cameraPosition.lat * math.pi / 180);
    final dy = (markerState.lat - cameraPosition.lat) * metersPerPixel;

    final markerPos = Offset(screenCenter.dx + dx, screenCenter.dy - dy);

    if (isPaused) {
      // Draw accuracy ring
      final ringPaint = Paint()
        ..color = Colors.blue.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(markerPos, 20, ringPaint);
    } else {
      // Draw solid marker dot
      final markerPaint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.fill;

      canvas.drawCircle(markerPos, 8, markerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PlayerMarkerPainter oldDelegate) {
    return oldDelegate.markerState != markerState ||
        oldDelegate.isPaused != isPaused;
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
