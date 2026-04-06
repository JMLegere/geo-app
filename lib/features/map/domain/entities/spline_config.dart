import 'dart:math' as math;

class SplineConfig {
  SplineConfig._();

  /// Distance in meters at which the marker transitions to ring state.
  /// Design spec: ~30-50m (half a cell).
  static const double ringThresholdMeters = 40.0;

  /// Minimum lerp factor applied when the marker is very close to GPS.
  /// At near-zero gap, the marker barely moves per tick.
  static const double minLerpFactor = 0.02;

  /// Maximum lerp factor applied when the gap is very large.
  /// At large gaps, the marker covers most of the distance per tick.
  static const double maxLerpFactor = 0.25;

  /// Reference distance (meters) at which lerp factor reaches ~maxLerpFactor.
  static const double _referenceDistance = 200.0;

  /// Compute the lerp factor for a given gap distance in meters.
  ///
  /// Uses a logarithmic curve so that:
  /// - Close (< 5m): nearly locked on (minLerpFactor)
  /// - Walking (~10-20m): follows at walking pace
  /// - Driving/GPS jump (100m+): moves fast but visibly traveling
  static double lerpFactor(double gapMeters) {
    if (gapMeters <= 0.0) return minLerpFactor;
    final t = math.log(1.0 + gapMeters) / math.log(1.0 + _referenceDistance);
    final clamped = t.clamp(0.0, 1.0);
    return minLerpFactor + (maxLerpFactor - minLerpFactor) * clamped;
  }
}
