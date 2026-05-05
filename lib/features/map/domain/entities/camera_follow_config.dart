import 'dart:math' as math;

class CameraFollowConfig {
  CameraFollowConfig._();

  /// Minimum lerp factor for camera catch-up on small GPS jitter.
  /// Kept well above the gameplay marker so camera framing feels responsive.
  static const double minLerpFactor = 0.18;

  /// Maximum lerp factor for large GPS jumps.
  /// Still below 1.0 so the camera never hard-snaps after startup.
  static const double maxLerpFactor = 0.55;

  /// Reference distance where the camera approaches max catch-up speed.
  static const double _referenceDistance = 80.0;

  /// Ignore sub-decimeter residual drift to avoid endless tiny camera moves.
  static const double settleDistanceMeters = 0.1;

  /// Compute the fast camera lerp factor for a gap to raw GPS.
  ///
  /// The camera tracks the raw GPS target faster than the gameplay marker, but
  /// it still eases so noisy GPS updates do not make the map feel jittery.
  static double lerpFactor(double gapMeters) {
    if (gapMeters <= 0.0) return minLerpFactor;
    final t = math.log(1.0 + gapMeters) / math.log(1.0 + _referenceDistance);
    final clamped = t.clamp(0.0, 1.0);
    return minLerpFactor + (maxLerpFactor - minLerpFactor) * clamped;
  }
}
