import 'package:geobase/geobase.dart';

/// Simplified camera controller — always follows the player.
///
/// No free mode, no overview, no panning. The camera is locked to the
/// player position at all times. Zoom is constrained to z15–z16.
///
/// The hierarchy views (district/city/state/country/world) are separate
/// screens accessed via pinch-out transition, not camera zoom modes.
class CameraController {
  CameraController({required this.onMoveToPlayer});

  /// Callback: instant camera move to player position.
  final void Function(Geographic center) onMoveToPlayer;

  /// Last known player position from rubber-band.
  Geographic? _playerPosition;

  /// The last player position.
  Geographic? get playerPosition => _playerPosition;

  /// Called on each rubber-band display update.
  /// Always moves the camera to track the player.
  void onPlayerPositionUpdate(Geographic position) {
    _playerPosition = position;
    onMoveToPlayer(position);
  }

  void dispose() {
    // No resources to clean up.
  }
}
