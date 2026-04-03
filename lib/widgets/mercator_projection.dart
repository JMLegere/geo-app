import 'dart:math';
import 'dart:ui';

/// Pure Web Mercator (EPSG:3857) projection utilities.
///
/// Converts between geographic coordinates (WGS-84 lat/lon) and screen pixel
/// coordinates for a given camera position and zoom level.
///
/// Latitude is clamped to the Mercator limit of ±85.051129° to avoid
/// logarithm singularities at the poles.
///
/// All methods are static and pure — no async, no platform dependencies.
class MercatorProjection {
  /// Mercator latitude limit in degrees. Values beyond this produce invalid
  /// projections (log singularity approaches infinity near ±90°).
  static const double kMercatorMaxLat = 85.051129;

  MercatorProjection._();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Projects geographic coordinates to screen pixel coordinates.
  ///
  /// Uses standard Web Mercator projection where the world is a 256×256 tile
  /// at zoom 0, doubling in both dimensions per zoom level.
  ///
  /// [lat], [lon] — target point in degrees (lat clamped to ±85.051129°)
  /// [cameraLat], [cameraLon] — camera center in degrees
  /// [zoom] — map zoom level (standard web map zoom, e.g. 13.0)
  /// [viewportSize] — screen viewport size in logical pixels
  ///
  /// Returns screen [Offset] relative to viewport top-left. Points outside
  /// the viewport will have negative coordinates or exceed viewport bounds.
  static Offset geoToScreen({
    required double lat,
    required double lon,
    required double cameraLat,
    required double cameraLon,
    required double zoom,
    required Size viewportSize,
  }) {
    final worldSize = _worldSize(zoom);

    final targetX = _lonToX(lon, worldSize);
    final targetY = _latToY(lat, worldSize);

    final cameraX = _lonToX(cameraLon, worldSize);
    final cameraY = _latToY(cameraLat, worldSize);

    final screenX = (targetX - cameraX) + viewportSize.width / 2;
    final screenY = (targetY - cameraY) + viewportSize.height / 2;

    return Offset(screenX, screenY);
  }

  /// Inverse projection: screen pixel coordinates to geographic coordinates.
  ///
  /// [screenPoint] — pixel offset relative to viewport top-left
  /// [cameraLat], [cameraLon] — camera center in degrees
  /// [zoom] — map zoom level
  /// [viewportSize] — screen viewport size in logical pixels
  ///
  /// Returns a named record with `lat` and `lon` in degrees.
  static ({double lat, double lon}) screenToGeo({
    required Offset screenPoint,
    required double cameraLat,
    required double cameraLon,
    required double zoom,
    required Size viewportSize,
  }) {
    final worldSize = _worldSize(zoom);

    final cameraX = _lonToX(cameraLon, worldSize);
    final cameraY = _latToY(cameraLat, worldSize);

    final targetX = (screenPoint.dx - viewportSize.width / 2) + cameraX;
    final targetY = (screenPoint.dy - viewportSize.height / 2) + cameraY;

    final lon = _xToLon(targetX, worldSize);
    final lat = _yToLat(targetY, worldSize);

    return (lat: lat, lon: lon);
  }

  /// Returns the visible geographic bounding box for the given camera state.
  ///
  /// The four corners of the viewport are projected to geographic coordinates
  /// and their extremes form the bounding box. This is a conservative estimate
  /// — the actual visible area may be slightly smaller for tilted projections,
  /// but Web Mercator is axis-aligned so this is exact.
  ///
  /// Returns a named record with `minLat`, `maxLat`, `minLon`, `maxLon`.
  static ({double minLat, double maxLat, double minLon, double maxLon})
      visibleBounds({
    required double cameraLat,
    required double cameraLon,
    required double zoom,
    required Size viewportSize,
  }) {
    final topLeft = screenToGeo(
      screenPoint: Offset.zero,
      cameraLat: cameraLat,
      cameraLon: cameraLon,
      zoom: zoom,
      viewportSize: viewportSize,
    );
    final bottomRight = screenToGeo(
      screenPoint: Offset(viewportSize.width, viewportSize.height),
      cameraLat: cameraLat,
      cameraLon: cameraLon,
      zoom: zoom,
      viewportSize: viewportSize,
    );

    // Screen Y increases downward, so top-left has higher lat than bottom-right.
    return (
      minLat: bottomRight.lat,
      maxLat: topLeft.lat,
      minLon: topLeft.lon,
      maxLon: bottomRight.lon,
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// World size in pixels at the given zoom level.
  /// At zoom 0: 256×256. Doubles each zoom level.
  static double _worldSize(double zoom) => pow(2, zoom).toDouble() * 256.0;

  /// Converts longitude (degrees) to Web Mercator world X coordinate.
  static double _lonToX(double lon, double worldSize) {
    return (lon + 180.0) / 360.0 * worldSize;
  }

  /// Converts latitude (degrees, clamped) to Web Mercator world Y coordinate.
  /// Screen Y increases downward; larger Y = lower latitude.
  static double _latToY(double lat, double worldSize) {
    final clampedLat = lat.clamp(-kMercatorMaxLat, kMercatorMaxLat);
    final latRad = clampedLat * pi / 180.0;
    final sinLat = sin(latRad);
    // Equivalent to ln(tan(lat) + sec(lat)) = ln((1+sin)/(1-sin)) / 2
    final y = (1.0 - log((1.0 + sinLat) / (1.0 - sinLat)) / (2 * pi)) /
        2.0 *
        worldSize;
    return y;
  }

  /// Converts Web Mercator world X coordinate to longitude (degrees).
  static double _xToLon(double x, double worldSize) {
    return x / worldSize * 360.0 - 180.0;
  }

  /// Converts Web Mercator world Y coordinate to latitude (degrees).
  static double _yToLat(double y, double worldSize) {
    final n = pi - 2.0 * pi * y / worldSize;
    return 180.0 / pi * atan(0.5 * (exp(n) - exp(-n)));
  }
}
