import 'dart:math';
import 'dart:ui';

import 'package:geobase/geobase.dart';
import 'package:maplibre/maplibre.dart';

/// Computes and enforces camera bounds from detection zone district centroids.
///
/// The camera is constrained to the bounding box of the current + adjacent
/// district centroids with 5% padding. Zoom is constrained to a minimum
/// level where the full zone fits the screen.
///
/// Bounds enforcement uses exponential decay interpolation (same math as
/// the rubber-band controller) so the camera smoothly splines to the
/// bounded position instead of snapping.
class CameraBoundsController {
  LngLatBounds? _bounds;
  double? _minZoom;

  static const _stiffness = 8.0;
  static const _snapThreshold = 0.0001; // degrees

  /// Current bounds, or null if unconstrained.
  LngLatBounds? get bounds => _bounds;

  /// Minimum zoom level, or null if unconstrained.
  double? get minZoom => _minZoom;

  /// Whether bounds are currently active.
  bool get hasBounds => _bounds != null;

  /// Update bounds from district centroids. Computes LngLatBounds with 5%
  /// padding and minZoom from the extent relative to screen size.
  void updateBounds(List<Geographic> districtCentroids, Size screenSize) {
    if (districtCentroids.isEmpty) {
      clearBounds();
      return;
    }

    var minLat = double.infinity;
    var maxLat = double.negativeInfinity;
    var minLon = double.infinity;
    var maxLon = double.negativeInfinity;

    for (final c in districtCentroids) {
      minLat = min(minLat, c.lat);
      maxLat = max(maxLat, c.lat);
      minLon = min(minLon, c.lon);
      maxLon = max(maxLon, c.lon);
    }

    // 5% padding on each side
    final latPad = (maxLat - minLat) * 0.05;
    final lonPad = (maxLon - minLon) * 0.05;
    // Minimum padding for single-centroid case
    const minPad = 0.005; // ~500m at mid-latitudes

    _bounds = LngLatBounds(
      longitudeWest: minLon - max(lonPad, minPad),
      longitudeEast: maxLon + max(lonPad, minPad),
      latitudeSouth: minLat - max(latPad, minPad),
      latitudeNorth: maxLat + max(latPad, minPad),
    );

    // Compute minZoom: the zoom where the bounding box fills the screen.
    final latExtent = _bounds!.latitudeNorth - _bounds!.latitudeSouth;
    final lonExtent = _bounds!.longitudeEast - _bounds!.longitudeWest;

    if (lonExtent > 0 && latExtent > 0 && screenSize.width > 0) {
      final minZoomLon = _log2((screenSize.width * 360) / (256 * lonExtent));
      final minZoomLat = _log2((screenSize.height * 180) / (256 * latExtent));
      _minZoom = min(minZoomLon, minZoomLat).clamp(0.0, 22.0);
    }
  }

  /// Clear bounds (back to unconstrained).
  void clearBounds() {
    _bounds = null;
    _minZoom = null;
  }

  /// Clamp a camera position to within bounds with smooth interpolation.
  ///
  /// Returns corrected (lat, lon, zoom) that smoothly approach the bounded
  /// position using exponential decay. Returns null if no correction needed.
  ///
  /// Call this on MapEventCameraIdle to apply iOS-style bounce-back.
  /// [dt] is delta time in seconds (use 0.05 for ~20fps idle check).
  ({double lat, double lon, double zoom})? clamp(
    double lat,
    double lon,
    double zoom,
    double dt,
  ) {
    if (_bounds == null) return null;

    final targetLat = lat.clamp(_bounds!.latitudeSouth, _bounds!.latitudeNorth);
    final targetLon = lon.clamp(_bounds!.longitudeWest, _bounds!.longitudeEast);
    final targetZoom = _minZoom != null ? max(zoom, _minZoom!) : zoom;

    final needsCorrection = (targetLat - lat).abs() > _snapThreshold ||
        (targetLon - lon).abs() > _snapThreshold ||
        (targetZoom - zoom) > 0.01;

    if (!needsCorrection) return null;

    final factor = 1.0 - exp(-_stiffness * dt.clamp(0.001, 0.1));
    return (
      lat: lat + (targetLat - lat) * factor,
      lon: lon + (targetLon - lon) * factor,
      zoom: zoom + (targetZoom - zoom) * factor,
    );
  }

  static double _log2(double x) => log(x) / ln2;
}
