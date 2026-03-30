import 'package:flutter/foundation.dart';
import 'package:geobase/geobase.dart';

import 'package:earth_nova/features/map/utils/map_logger.dart';
import 'package:earth_nova/shared/constants.dart';

/// Camera modes for the map screen.
///
/// Three states: following the player, free exploration, or overview.
/// No heading mode (no compass data yet) and no "returning" mode
/// (animation tracked by [isAnimating], not a separate mode).
enum CameraMode {
  /// Camera locked to player position, north-up.
  /// Updated on each rubber-band display tick.
  following,

  /// User has panned/zoomed. Camera is free. Recenter FAB visible.
  free,

  /// fitBounds showing explored area or detection zone.
  overview,
}

/// Pure Dart camera controller — no Flutter widgets, no Riverpod.
///
/// Processes inputs (GPS updates, user gestures, mode changes) and
/// emits camera move commands via callbacks. The map screen wires
/// these callbacks to [MapController.animateCamera] / [fitBounds].
///
/// Exposes [mode] as a [ValueNotifier] so the recenter FAB can
/// react via [ValueListenableBuilder] — consistent with the
/// [_markerPosition] pattern already in use.
class CameraController {
  CameraController({
    required this.onMoveToPlayer,
  });

  /// Callback: animate camera to player position.
  /// Map screen implements this as `mapController.animateCamera(...)`.
  final void Function(Geographic center, Duration duration) onMoveToPlayer;

  /// Current camera mode — consumed by RecenterFab.
  final ValueNotifier<CameraMode> mode = ValueNotifier(CameraMode.following);

  /// Last known player position from rubber-band.
  Geographic? _playerPosition;

  /// Whether a programmatic camera animation is in progress.
  /// When true, we suppress additional moves to prevent jitter.
  bool _isAnimating = false;

  /// The last player position — exposed for the recenter FAB.
  Geographic? get playerPosition => _playerPosition;

  /// Called on each rubber-band display update.
  ///
  /// In [CameraMode.following], emits a camera move to track the player.
  /// In other modes, just caches the position for later recenter.
  void onPlayerPositionUpdate(Geographic position) {
    _playerPosition = position;
    if (mode.value == CameraMode.following && !_isAnimating) {
      onMoveToPlayer(position, kGpsFollowDuration);
    }
  }

  /// Called when MapLibre detects a user gesture (pan/pinch/rotate).
  ///
  /// Transitions to [CameraMode.free] and cancels any in-progress
  /// animation. Idempotent — multiple gestures in free mode are no-ops.
  void onUserGesture() {
    _isAnimating = false;
    if (mode.value != CameraMode.free) {
      MapLogger.cameraModeChanged(mode.value.name, 'free', 'gesture');
      mode.value = CameraMode.free;
    }
  }

  /// Called when user taps the recenter FAB.
  ///
  /// Animates camera back to player position and transitions to
  /// [CameraMode.following]. No-op if player position is unknown.
  void recenter() {
    final pos = _playerPosition;
    if (pos == null) return;
    _isAnimating = true;
    onMoveToPlayer(pos, kRecenterDuration);
    // Schedule mode change after animation completes.
    Future.delayed(kRecenterDuration, () {
      _isAnimating = false;
      if (mode.value != CameraMode.following) {
        MapLogger.cameraModeChanged(mode.value.name, 'following', 'recenter');
        mode.value = CameraMode.following;
      }
    });
  }

  /// Called when the user requests the overview mode (zoom toggle).
  void enterOverview() {
    MapLogger.cameraModeChanged(mode.value.name, 'overview', 'zoomToggle');
    mode.value = CameraMode.overview;
  }

  /// Called when the user exits overview (gesture or recenter).
  void exitOverview() {
    MapLogger.cameraModeChanged(mode.value.name, 'free', 'exitOverview');
    mode.value = CameraMode.free;
  }

  void dispose() {
    mode.dispose();
  }
}
