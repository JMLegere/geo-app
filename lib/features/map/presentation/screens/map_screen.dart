import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:earth_nova/features/map/presentation/providers/location_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/map_provider.dart';
import 'package:earth_nova/shared/theme/app_theme.dart';
import 'package:earth_nova/shared/widgets/loading_dots.dart';

const _kMapStyleUrl = 'https://demotiles.maplibre.org/style.json';
const _kGpsZoom = 15.0;

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              Positioned.fill(
                child: MapLibreMap(
                  key: ValueKey(
                    '${location.timestamp.microsecondsSinceEpoch}:${location.lat}:${location.lng}',
                  ),
                  styleString: _kMapStyleUrl,
                  initialCameraPosition: CameraPosition(
                    target: LatLng(location.lat, location.lng),
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
                  myLocationTrackingMode: MyLocationTrackingMode.tracking,
                  onStyleLoadedCallback: () {
                    ref.read(mapProvider.notifier).setZoom(_kGpsZoom);
                  },
                ),
              ),
              if (mapState is MapStateLoading)
                const Positioned(
                  top: 24,
                  left: 0,
                  right: 0,
                  child: Center(child: LoadingDots()),
                ),
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
