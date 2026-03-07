import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:fog_of_world/core/state/location_provider.dart';

/// A dismissable banner displayed when GPS permission is denied or location
/// services are disabled.
///
/// Shows a contextual message and an action button appropriate to each error:
/// - [LocationError.permissionDenied]: prompt to re-request permission
/// - [LocationError.permissionDeniedForever]: button to open app settings
/// - [LocationError.serviceDisabled]: button to open location settings
///
/// Hidden for [LocationError.none] and [LocationError.lowAccuracy] (which
/// has its own inline indicator on the status bar).
class LocationPermissionBanner extends ConsumerStatefulWidget {
  const LocationPermissionBanner({super.key});

  @override
  ConsumerState<LocationPermissionBanner> createState() =>
      _LocationPermissionBannerState();
}

class _LocationPermissionBannerState
    extends ConsumerState<LocationPermissionBanner> {
  bool _dismissed = false;
  LocationError? _lastDismissedError;

  @override
  Widget build(BuildContext context) {
    final locationError = ref.watch(
      locationProvider.select((s) => s.locationError),
    );

    // Reset dismissed state when the error changes (e.g., user granted later).
    if (locationError != _lastDismissedError && locationError != LocationError.none) {
      _dismissed = false;
    }

    if (_dismissed ||
        locationError == LocationError.none ||
        locationError == LocationError.lowAccuracy) {
      return const SizedBox.shrink();
    }

    final config = _bannerConfig(locationError);
    if (config == null) return const SizedBox.shrink();

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.location_off_rounded,
                  color: Theme.of(context).colorScheme.error,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),

              // Text + action
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      config.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      config.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: config.onAction,
                      child: Text(
                        config.actionLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Dismiss button
              GestureDetector(
                onTap: () {
                  setState(() {
                    _dismissed = true;
                    _lastDismissedError = locationError;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _BannerConfig? _bannerConfig(LocationError error) {
    return switch (error) {
      LocationError.permissionDenied => _BannerConfig(
          title: 'Location Access Required',
          subtitle:
              'Allow location access to reveal fog and track your exploration.',
          actionLabel: 'Allow Location',
          onAction: () => Geolocator.openAppSettings(),
        ),
      LocationError.permissionDeniedForever => _BannerConfig(
          title: 'Location Permanently Denied',
          subtitle:
              'Open Settings to allow Fog of World to access your location.',
          actionLabel: 'Open Settings',
          onAction: () => Geolocator.openAppSettings(),
        ),
      LocationError.serviceDisabled => _BannerConfig(
          title: 'Location Services Off',
          subtitle: 'Turn on Location Services to track your position and reveal the map.',
          actionLabel: 'Enable Location Services',
          onAction: () => Geolocator.openLocationSettings(),
        ),
      _ => null,
    };
  }
}

class _BannerConfig {
  const _BannerConfig({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;
}
