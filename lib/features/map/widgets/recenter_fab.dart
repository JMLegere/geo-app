import 'package:flutter/material.dart';

import 'package:earth_nova/features/map/controllers/camera_controller.dart';

/// Floating action button that recenters the camera on the player.
///
/// Visible when the camera is in [CameraMode.free] or [CameraMode.overview].
/// Hidden when the camera is following the player.
///
/// Uses [ValueListenableBuilder] to scope rebuilds to mode changes only —
/// the rest of the map screen is not affected.
class RecenterFab extends StatelessWidget {
  const RecenterFab({
    required this.modeNotifier,
    required this.onRecenter,
    super.key,
  });

  final ValueNotifier<CameraMode> modeNotifier;
  final VoidCallback onRecenter;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CameraMode>(
      valueListenable: modeNotifier,
      builder: (context, mode, _) {
        if (mode == CameraMode.following) return const SizedBox.shrink();
        return FloatingActionButton.small(
          heroTag: 'recenter_fab',
          onPressed: onRecenter,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
          child: const Icon(Icons.my_location),
        );
      },
    );
  }
}
