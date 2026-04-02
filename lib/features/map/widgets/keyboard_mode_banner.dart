import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:earth_nova/core/state/gps_permission_provider.dart';
import 'package:earth_nova/features/location/services/location_service.dart';
import 'package:earth_nova/shared/design_tokens.dart';

/// Prominent banner shown when in keyboard/simulated location mode.
///
/// Always visible when LocationMode.keyboard is active. Contains a
/// "Use My Real Location" button to request GPS permission and switch modes.
class KeyboardModeBanner extends ConsumerWidget {
  final LocationMode locationMode;

  const KeyboardModeBanner({
    super.key,
    required this.locationMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (locationMode != LocationMode.keyboard) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: Radii.borderLg,
        border: Border.all(color: cs.primary.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.keyboard_arrow_up_rounded,
                color: cs.primary,
                size: 20,
              ),
              const SizedBox(width: Spacing.xs),
              Expanded(
                child: Text(
                  'Simulated Location',
                  style: tt.titleSmall?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'You are controlling movement with arrow keys. Use your real location to explore your actual surroundings.',
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: Spacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _requestGpsPermission(context, ref),
              icon: const Icon(Icons.my_location, size: 18),
              label: const Text('Use My Real Location'),
            ),
          ),
        ],
      ),
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
        ref.read(gpsPermissionProvider.notifier).markDenied();
      } else {
        if (context.mounted) {
          _showSnackBar(
              context, 'Location permission granted! Switching to GPS...');
        }
        ref.read(gpsPermissionProvider.notifier).markGranted();
        // LocationService will detect the mode switch automatically
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
