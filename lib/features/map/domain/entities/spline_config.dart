import 'dart:math' as math;

class SplineConfig {
  SplineConfig._();

  /// Distance in meters at which marker-to-geolocation distance transitions
  /// into ring state.
  static const double ringThresholdMeters = 100.0;

  /// Minimum lerp factor applied when the marker is very close to GPS.
  /// At near-zero gap, the marker barely moves per tick.
  static const double minLerpFactor = 0.02;

  /// Maximum easing factor before the per-frame speed cap is applied.
  /// At large gaps, the marker wants to catch up faster but is still bounded.
  static const double maxLerpFactor = 0.25;

  /// Upper bound for trusted marker movement.
  ///
  /// This keeps a noisy GPS target from visually teleporting the marker while
  /// still allowing quick catch-up for debug movement, biking, and normal
  /// mobile GPS update batches.
  static const double maxTrustedSpeedMetersPerSecond = 16.0;

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

  /// Compute a lerp factor capped by the maximum trusted marker speed.
  static double boundedLerpFactor({
    required double gapMeters,
    required Duration tickInterval,
  }) {
    if (gapMeters <= 0.0) return 0.0;
    final easedFactor = lerpFactor(gapMeters);
    final maxStepMeters =
        maxTrustedSpeedMetersPerSecond * tickInterval.inMilliseconds / 1000.0;
    final maxStepFactor = (maxStepMeters / gapMeters).clamp(0.0, 1.0);
    return math.min(easedFactor, maxStepFactor);
  }
}
