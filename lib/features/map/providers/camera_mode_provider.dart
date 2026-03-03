import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fog_of_world/features/map/controllers/camera_controller.dart';

/// Notifier that holds and mutates the camera's follow/free mode.
///
/// Defaults to `CameraMode.following` — the camera tracks the player.
class CameraModeNotifier extends Notifier<CameraMode> {
  @override
  CameraMode build() => CameraMode.following;

  /// Switches to the given mode directly.
  void setMode(CameraMode mode) {
    state = mode;
  }

  /// Convenience: switch to free mode (user panned the map).
  void setFree() {
    state = CameraMode.free;
  }

  /// Convenience: switch back to following mode (recenter tapped).
  void setFollowing() {
    state = CameraMode.following;
  }
}

/// Riverpod provider for the current camera follow/free mode.
///
/// Defaults to `CameraMode.following` — the camera tracks the player.
/// Switches to `CameraMode.free` on user gesture; call
/// `ref.read(cameraModeProvider.notifier).setFollowing()` to resume following.
///
/// Consumed by the map screen to show/hide the recenter button and by
/// `CameraController` to gate location update callbacks.
final cameraModeProvider =
    NotifierProvider<CameraModeNotifier, CameraMode>(CameraModeNotifier.new);
