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

  /// Trusted marker movement uses an approximately one-second convergence
  /// constant:
  /// - 100m away -> ~100m/s
  /// - 50m away -> ~50m/s
  /// - 10m away -> ~10m/s
  static const double gapSecondsPerSecond = 1.0;

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

  /// Compute the per-tick factor for the trusted movement rule.
  ///
  /// The marker covers roughly one second worth of the current gap each second,
  /// which means travel speed scales proportionally with distance.
  static double boundedLerpFactor({
    required double gapMeters,
    required Duration tickInterval,
  }) {
    if (gapMeters <= 0.0) return 0.0;
    final tickSeconds = tickInterval.inMilliseconds / 1000.0;
    final proportionalFactor = tickSeconds * gapSecondsPerSecond;
    return proportionalFactor.clamp(0.0, 1.0);
  }
}
