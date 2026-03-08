import 'dart:math';

import 'package:flutter/scheduler.dart';

import 'package:earth_nova/features/map/utils/map_logger.dart';
import 'package:earth_nova/shared/constants.dart';

/// Smoothly interpolates a display position toward a target GPS position.
///
/// The "rubber band" effect decouples the visible player marker + camera
/// from raw GPS coordinates. On each GPS tick (1 Hz), the target is updated.
/// A [Ticker] drives 60 fps interpolation of the display position toward the
/// target. Speed scales with distance: `speed = max(minSpeed, k * distance)`.
///
/// ## Usage
///
/// Create in `initState` with `this` as the `TickerProvider`:
///
/// ```dart
/// _rubberBand = RubberBandController(
///   vsync: this,
///   onDisplayUpdate: (lat, lon) { /* move marker + camera */ },
/// );
/// ```
///
/// Feed GPS updates via [setTarget]. Dispose in `dispose()`.
class RubberBandController {
  /// Called on every frame (~60 fps) with the interpolated display position.
  final void Function(double lat, double lon) onDisplayUpdate;

  /// Minimum speed in meters/second. The marker never moves slower than this.
  final double minSpeedMps;

  /// Multiplier: `speed = max(minSpeed, k * distanceMeters)`.
  final double speedMultiplier;

  /// Below this distance (meters) the marker snaps to the target instantly.
  final double snapThresholdMeters;

  late final Ticker _ticker;

  // Target position (raw GPS / simulator)
  double _targetLat;
  double _targetLon;

  // Display position (interpolated, drives marker + camera)
  double _displayLat;
  double _displayLon;

  /// Whether the controller has received at least one target position.
  bool _initialized = false;

  Duration _lastTickTime = Duration.zero;

  RubberBandController({
    required TickerProvider vsync,
    required this.onDisplayUpdate,
    this.minSpeedMps = kRubberBandMinSpeedMps,
    this.speedMultiplier = kRubberBandSpeedMultiplier,
    this.snapThresholdMeters = kRubberBandSnapThresholdMeters,
  })  : _targetLat = 0,
        _targetLon = 0,
        _displayLat = 0,
        _displayLon = 0 {
    _ticker = vsync.createTicker(_onTick);
  }

  /// Current display latitude (interpolated).
  double get displayLat => _displayLat;

  /// Current display longitude (interpolated).
  double get displayLon => _displayLon;

  /// Current target latitude (raw GPS).
  double get targetLat => _targetLat;

  /// Current target longitude (raw GPS).
  double get targetLon => _targetLon;

  /// Whether display has arrived at the target (within snap threshold).
  bool get isAtTarget => _initialized && _distanceMeters(_displayLat, _displayLon, _targetLat, _targetLon) < snapThresholdMeters;

  /// Sets the target position. On the first call, display snaps to target
  /// and the ticker starts. Subsequent calls smoothly interpolate.
  void setTarget(double lat, double lon) {
    _targetLat = lat;
    _targetLon = lon;

    if (!_initialized) {
      _displayLat = lat;
      _displayLon = lon;
      _initialized = true;
      _lastTickTime = Duration.zero;
      _ticker.start();
      MapLogger.rubberBandInitialized(lat, lon);
      // Emit initial position immediately.
      onDisplayUpdate(_displayLat, _displayLon);
    }
  }

  void _onTick(Duration elapsed) {
    if (!_initialized) return;

    // Compute delta time in seconds.
    final dt = _lastTickTime == Duration.zero
        ? 1.0 / 60.0 // First frame: assume 60fps
        : (elapsed - _lastTickTime).inMicroseconds / 1e6;
    _lastTickTime = elapsed;

    // Clamp dt to prevent huge jumps on tab-switch resume.
    final clampedDt = dt.clamp(0.0, 0.1); // Max 100ms step

    final distM = _distanceMeters(_displayLat, _displayLon, _targetLat, _targetLon);

    // Snap if close enough — prevents sub-pixel oscillation.
    if (distM < snapThresholdMeters) {
      if (_displayLat != _targetLat || _displayLon != _targetLon) {
        _displayLat = _targetLat;
        _displayLon = _targetLon;
        MapLogger.tickFired(
          displayLat: _displayLat,
          displayLon: _displayLon,
          targetLat: _targetLat,
          targetLon: _targetLon,
          distanceM: distM,
          skipped: false,
        );
        onDisplayUpdate(_displayLat, _displayLon);
      } else {
        // At target, no update needed — log as skip.
        MapLogger.tickFired(
          displayLat: _displayLat,
          displayLon: _displayLon,
          targetLat: _targetLat,
          targetLon: _targetLon,
          distanceM: distM,
          skipped: true,
        );
      }
      return;
    }

    // Speed scales with distance, with a floor of minSpeedMps.
    final speedMps = max(minSpeedMps, speedMultiplier * distM);

    // How far to move this frame (meters).
    final stepMeters = speedMps * clampedDt;

    // Fraction of the distance to cover (clamped to 1.0 so we don't overshoot).
    final t = (stepMeters / distM).clamp(0.0, 1.0);

    // Linear interpolation in lat/lon space. Acceptable at city scale.
    _displayLat = _displayLat + (_targetLat - _displayLat) * t;
    _displayLon = _displayLon + (_targetLon - _displayLon) * t;

    MapLogger.tickFired(
      displayLat: _displayLat,
      displayLon: _displayLon,
      targetLat: _targetLat,
      targetLon: _targetLon,
      distanceM: distM,
      skipped: false,
    );
    onDisplayUpdate(_displayLat, _displayLon);
  }

  /// Stops the ticker and releases resources.
  void dispose() {
    _ticker.stop();
    _ticker.dispose();
  }

  // ---------------------------------------------------------------------------
  // Haversine distance (meters) between two lat/lon pairs.
  // ---------------------------------------------------------------------------

  static const double _earthRadiusM = 6371000.0;

  static double _distanceMeters(
    double lat1, double lon1, double lat2, double lon2,
  ) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return _earthRadiusM * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _toRadians(double degrees) => degrees * pi / 180.0;
}
