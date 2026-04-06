import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;

import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/features/map/presentation/painters/cell_overlay_painter.dart';
import 'package:earth_nova/features/map/presentation/providers/location_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/map_provider.dart';
import 'package:earth_nova/shared/theme/app_theme.dart';
import 'package:earth_nova/shared/widgets/loading_dots.dart';

const _kMapStyleUrl = 'https://demotiles.maplibre.org/style.json';
const _kGpsZoom = 15.0;

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    final mapState = ref.watch(mapProvider);

    return switch (locationState) {
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
      LocationProviderActive(location: final location) => Scaffold(
          backgroundColor: AppTheme.surface,
          body: Stack(
            children: [
              // Base map layer
              Positioned.fill(
                child: maplibre.MapLibreMap(
                  key: ValueKey(
                    '${location.timestamp.microsecondsSinceEpoch}:${location.lat}:${location.lng}',
                  ),
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
                  myLocationTrackingMode:
                      maplibre.MyLocationTrackingMode.tracking,
                  onStyleLoadedCallback: () {
                    ref.read(mapProvider.notifier).setZoom(_kGpsZoom);
                  },
                ),
              ),

              // Cell overlay layer - drawn on top of map using Flutter Canvas
              if (mapState is MapStateReady)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: CellOverlayPainter(
                        cellsWithStates: _buildCellStates(
                          mapState.cells,
                          mapState.visitedCellIds,
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

              // Loading indicator
              if (mapState is MapStateLoading)
                const Positioned(
                  top: 24,
                  left: 0,
                  right: 0,
                  child: Center(child: LoadingDots()),
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
            ],
          ),
        ),
    };
  }

  /// Build cell state list from cells and visited cell IDs.
  ///
  /// For now, all cells are marked as 'nearby' since we haven't implemented
  /// the cell visit detection yet. This will be updated in task 07.
  List<({Cell cell, CellState state})> _buildCellStates(
    List<Cell> cells,
    Set<String> visitedCellIds,
  ) {
    return cells.map((cell) {
      final isVisited = visitedCellIds.contains(cell.id);
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
