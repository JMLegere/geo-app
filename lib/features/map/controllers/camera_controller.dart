/// Manages the map camera follow/free mode.
///
/// Pure logic — no MapLibre dependency. The map screen wires `onCameraMove`
/// to the actual map controller (e.g. MapLibre's animateCamera) in Phase 2.
///
/// ## Modes
///
/// - `CameraMode.following`: Camera tracks the player's location automatically.
///   Any `onLocationUpdate` call moves the camera to the player's position.
/// - `CameraMode.free`: User has panned the map. Camera no longer auto-follows.
///   Call `recenter` to snap back to the player and resume following.
enum CameraMode {
  /// Camera tracks the player's position automatically.
  following,

  /// User has panned the map; camera no longer auto-follows.
  free,
}

/// Controls the map camera follow/free mode and delegates movement to the map.
///
/// Register [onCameraMove] to receive lat/lon updates that should animate the
/// actual map camera. The map screen sets this callback in Phase 2.
class CameraController {
  /// Current camera mode. Starts in [CameraMode.following].
  CameraMode mode = CameraMode.following;

  /// Callback invoked when the camera should move to a new position.
  ///
  /// The map screen sets this to call the actual map controller
  /// (e.g. `MapController.animateCamera`). May be null before the map is ready.
  void Function(double lat, double lon)? onCameraMove;

  /// Called on every GPS location update.
  ///
  /// If in [CameraMode.following], invokes [onCameraMove] with the new position.
  /// No-op in [CameraMode.free] — user has control.
  void onLocationUpdate(double lat, double lon) {
    if (mode != CameraMode.following) return;
    onCameraMove?.call(lat, lon);
  }

  /// Called when the user begins a manual map gesture (pan/zoom).
  ///
  /// Switches to [CameraMode.free] to stop auto-following.
  void onUserGesture() {
    mode = CameraMode.free;
  }

  /// Snaps the camera back to the player's position and resumes following.
  ///
  /// Switches to [CameraMode.following] and immediately calls [onCameraMove]
  /// with the given coordinates.
  void recenter(double lat, double lon) {
    mode = CameraMode.following;
    onCameraMove?.call(lat, lon);
  }
}
