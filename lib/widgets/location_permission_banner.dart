import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/providers/location_provider.dart';

/// Banner shown at the top of the map when location permission is not granted.
///
/// Displays a prompt to enable location access. Tapping "Allow" fires
/// [onRequestPermission] — the caller is responsible for the platform-specific
/// permission request.
class LocationPermissionBanner extends ConsumerWidget {
  /// Called when the user taps the "Allow" button.
  final VoidCallback? onRequestPermission;

  const LocationPermissionBanner({
    super.key,
    this.onRequestPermission,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permission = ref.watch(
      locationProvider.select((s) => s.permission),
    );

    // Only show when permission is not yet granted.
    if (permission == LocationPermissionStatus.granted) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D44),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.location_off, color: Colors.amber, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Enable location to explore',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: onRequestPermission,
              style: TextButton.styleFrom(
                foregroundColor: Colors.amber,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Allow',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
