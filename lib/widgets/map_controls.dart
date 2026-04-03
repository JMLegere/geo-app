import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:earth_nova/providers/location_provider.dart';
import 'package:earth_nova/data/location/location_service.dart';

/// Floating action buttons for the map screen.
///
/// Stacked vertically with 8 px gap:
/// - GPS button (keyboard mode only): requests GPS permission
/// - Recenter button (always visible): compass/crosshair icon snaps camera
///   back to the player and resumes follow mode.
/// - Debug toggle (kDebugMode only): opens/closes the debug HUD overlay.
///
/// Colours adapt to the active theme via [Theme.of] — primary colour for
/// icons, surfaceContainer for the button background.
///
/// ## Usage
///
/// ```dart
/// Positioned(
///   right: 16, bottom: 16,
///   child: MapControls(
///     onRecenter: _cameraController.recenter,
///     onToggleDebug: () => setState(() => _showDebug = !_showDebug),
///     locationMode: LocationMode.realGps,
///   ),
/// )
/// ```
class MapControls extends ConsumerWidget {
  /// Called when the recenter button is tapped.
  final VoidCallback onRecenter;

  /// Called when the debug toggle button is tapped. Only visible in debug builds.
  final VoidCallback onToggleDebug;

  /// Called when the zoom level toggle is tapped.
  final VoidCallback onToggleZoom;

  /// Whether the current zoom preset is world (true) or player (false).
  final bool isWorldZoom;

  /// Current location mode (controls visibility of GPS button).
  final LocationMode locationMode;

  const MapControls({
    super.key,
    required this.onRecenter,
    required this.onToggleDebug,
    required this.onToggleZoom,
    this.isWorldZoom = false,
    required this.locationMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (kDebugMode) ...[
          _ControlButton(
            icon: Icons.bug_report_outlined,
            tooltip: 'Toggle debug HUD',
            onPressed: onToggleDebug,
          ),
          const SizedBox(height: 8),
        ],
        // GPS button only visible in keyboard mode
        if (locationMode == LocationMode.keyboard) ...[
          _ControlButton(
            icon: Icons.location_searching,
            tooltip: 'Use My Location',
            onPressed: () => _requestGpsPermission(context, ref),
          ),
          const SizedBox(height: 8),
        ],
        _ControlButton(
          icon: isWorldZoom ? Icons.person_pin_circle : Icons.public,
          tooltip: isWorldZoom ? 'Zoom to player' : 'Zoom to world',
          onPressed: onToggleZoom,
        ),
        const SizedBox(height: 8),
        _ControlButton(
          icon: Icons.my_location,
          tooltip: 'Recenter map',
          onPressed: onRecenter,
        ),
      ],
    );
  }

  Future<void> _requestGpsPermission(
      BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (context.mounted) {
          _showSnackBar(context, 'Location services are disabled');
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (context.mounted) {
          _showSnackBar(
              context, 'Location permission denied. Open settings to enable.');
        }
        await Geolocator.openAppSettings();
      } else if (permission == LocationPermission.denied) {
        if (context.mounted) {
          _showSnackBar(context, 'Location permission denied');
        }
        ref
            .read(locationProvider.notifier)
            .setPermission(LocationPermissionStatus.denied);
      } else {
        if (context.mounted) {
          _showSnackBar(context, 'Location permission granted!');
        }
        ref
            .read(locationProvider.notifier)
            .setPermission(LocationPermissionStatus.granted);
      }
    } catch (e) {
      if (context.mounted) {
        _showSnackBar(context, 'Error requesting location: $e');
      }
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// A single circular floating control button.
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ControlButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(28),
        color: cs.surfaceContainerHigh,
        shadowColor: cs.shadow.withValues(alpha: 0.4),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onPressed();
          },
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            width: 56,
            height: 56,
            child: Icon(
              icon,
              size: 24,
              color: cs.primary,
            ),
          ),
        ),
      ),
    );
  }
}
