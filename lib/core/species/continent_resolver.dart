import 'package:fog_of_world/core/models/continent.dart';

/// Resolves GPS coordinates to a continent using bounding-box regions.
///
/// Uses simplified continental boundaries sufficient for gameplay.
/// For coordinates that don't fall in any bounding box (e.g., oceans),
/// returns the nearest continent based on a latitude/longitude heuristic.
///
/// Note: Africa is checked before Asia because the Asia bounding box
/// (lon 25–180) would otherwise swallow East Africa and North Africa.
/// Africa is split into two boxes:
///   - North/West Africa:    lat -35–38, lon -20–35  (stops at Suez Canal)
///   - East/Southern Africa: lat -35–15, lon 35–52
class ContinentResolver {
  /// Resolve GPS coordinates to a continent.
  ///
  /// [lat] is latitude in degrees (-90 to 90).
  /// [lon] is longitude in degrees (-180 to 180).
  static Continent resolve(double lat, double lon) {
    // Europe (check before Asia; European longitudes overlap with western Asia).
    if (_inBox(lat, lon, 35, -25, 72, 45)) return Continent.europe;

    // Africa — must be checked BEFORE Asia because the Asia longitude range
    // (25–180) swallows East/North Africa.
    //
    // Box 1: North Africa + West Africa (west of Suez Canal, lon ≤ 35).
    if (_inBox(lat, lon, -35, -20, 38, 35)) return Continent.africa;
    // Box 2: East Africa + Horn of Africa (lat ≤ 15, lon 35–52).
    if (_inBox(lat, lon, -35, 35, 15, 52)) return Continent.africa;

    // Asia (main Eurasian landmass, east of Europe and the Suez line).
    if (_inBox(lat, lon, -12, 25, 82, 180)) return Continent.asia;
    // SE Asia islands (Indonesia, Philippines etc., east of 95°E).
    if (_inBox(lat, lon, -12, 95, 10, 141)) return Continent.asia;

    // North America (including Central America and Caribbean).
    if (_inBox(lat, lon, 7, -170, 84, -50)) return Continent.northAmerica;

    // South America.
    if (_inBox(lat, lon, -60, -82, 15, -34)) return Continent.southAmerica;

    // Oceania (Australia, NZ, and Pacific Islands east of SE Asia).
    if (_inBox(lat, lon, -50, 110, 0, 180)) return Continent.oceania;
    // Far Pacific (past the date line, e.g., Samoa, Tonga, Hawaii).
    if (_inBox(lat, lon, -50, -180, 0, -120)) return Continent.oceania;

    // Default: nearest by latitude/longitude heuristic.
    // Handles open-ocean coordinates that don't fall into any bounding box.
    if (lat > 35) return lon > 0 ? Continent.europe : Continent.northAmerica;
    if (lat > -10) return lon > 0 ? Continent.africa : Continent.southAmerica;
    return Continent.oceania;
  }

  static bool _inBox(
    double lat,
    double lon,
    double minLat,
    double minLon,
    double maxLat,
    double maxLon,
  ) {
    return lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon;
  }
}
