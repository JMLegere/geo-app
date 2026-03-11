import 'dart:convert';

import 'package:earth_nova/core/cells/cell_property_resolver.dart';
import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/species/continent_resolver.dart' as legacy;

/// A single country's boundary data loaded from the bundled asset.
///
/// Each country has one or more polygons (MultiPolygon), each polygon
/// has one or more rings (outer boundary + optional holes).
/// Coordinates are stored as [lat, lon] pairs.
class CountryBoundary {
  /// ISO 3166-1 alpha-2 code (or alpha-3 fallback for disputed territories).
  final String code;

  /// Pre-mapped continent enum name from Natural Earth dataset.
  final Continent continent;

  /// List of polygons. Each polygon = list of rings.
  /// Each ring = list of [lat, lon] pairs.
  /// First ring is outer boundary, subsequent rings are holes.
  final List<List<List<List<double>>>> polygons;

  /// Bounding box for fast rejection: [minLat, maxLat, minLon, maxLon].
  final double minLat;
  final double maxLat;
  final double minLon;
  final double maxLon;

  CountryBoundary._({
    required this.code,
    required this.continent,
    required this.polygons,
    required this.minLat,
    required this.maxLat,
    required this.minLon,
    required this.maxLon,
  });

  /// Parse a single entry from the compact JSON format.
  ///
  /// JSON shape: `{"c": "US", "n": "northAmerica", "p": [[[[lat,lon],...]]]}`.
  factory CountryBoundary.fromJson(Map<String, dynamic> json) {
    final code = json['c'] as String;
    final continent = Continent.fromString(json['n'] as String);
    final rawPolygons = json['p'] as List;

    var minLat = 90.0;
    var maxLat = -90.0;
    var minLon = 180.0;
    var maxLon = -180.0;

    final polygons = <List<List<List<double>>>>[];
    for (final rawPoly in rawPolygons) {
      final rings = <List<List<double>>>[];
      for (final rawRing in rawPoly as List) {
        final ring = <List<double>>[];
        for (final rawPt in rawRing as List) {
          final pt = rawPt as List;
          final lat = (pt[0] as num).toDouble();
          final lon = (pt[1] as num).toDouble();
          ring.add([lat, lon]);

          if (lat < minLat) minLat = lat;
          if (lat > maxLat) maxLat = lat;
          if (lon < minLon) minLon = lon;
          if (lon > maxLon) maxLon = lon;
        }
        rings.add(ring);
      }
      polygons.add(rings);
    }

    return CountryBoundary._(
      code: code,
      continent: continent,
      polygons: polygons,
      minLat: minLat,
      maxLat: maxLat,
      minLon: minLon,
      maxLon: maxLon,
    );
  }
}

/// Resolves GPS coordinates to a country and continent using bundled
/// Natural Earth 1:110m country boundary polygons.
///
/// Implements [ContinentLookup] for use by [CellPropertyResolver].
///
/// ## Data source
/// `assets/country_boundaries.json` — 175 countries, ~146 KB.
/// Derived from Natural Earth ne_110m_admin_0_countries (public domain).
/// Coordinates stored as [lat, lon] at 2 decimal places (~1.1 km precision).
///
/// ## Algorithm
/// 1. Bounding-box pre-filter rejects ~95% of countries instantly.
/// 2. Ray-casting point-in-polygon test on remaining candidates.
/// 3. First hit wins (countries don't overlap at this resolution).
/// 4. Falls back to [ContinentResolver] bounding-box heuristic for
///    ocean coordinates not inside any country polygon.
///
/// ## Performance
/// ~175 bounding-box checks + 1–3 polygon tests per query.
/// Results are cached upstream by [CellPropertyRepository].
class CountryResolver implements ContinentLookup {
  final List<CountryBoundary> _boundaries;

  CountryResolver._(this._boundaries);

  /// Load from the compact JSON asset string.
  ///
  /// Call once at app startup, reuse the instance.
  ///
  /// ```dart
  /// final json = await rootBundle.loadString('assets/country_boundaries.json');
  /// final resolver = CountryResolver.load(json);
  /// ```
  factory CountryResolver.load(String jsonString) {
    final raw = jsonDecode(jsonString) as List;
    final boundaries = raw
        .map((e) => CountryBoundary.fromJson(e as Map<String, dynamic>))
        .toList();
    return CountryResolver._(boundaries);
  }

  /// Number of loaded country boundaries (for diagnostics / tests).
  int get countryCount => _boundaries.length;

  /// Resolve a GPS coordinate to a country code.
  ///
  /// Returns ISO 3166-1 alpha-2 code (e.g., "US", "FR"), or alpha-3
  /// for disputed territories (e.g., "NOR", "FRA", "KOS").
  /// Returns null if the point is not inside any country polygon (ocean).
  String? resolveCountryCode(double lat, double lon) {
    for (final boundary in _boundaries) {
      if (!_inBoundingBox(lat, lon, boundary)) continue;
      if (_inCountry(lat, lon, boundary)) return boundary.code;
    }
    return null;
  }

  /// Resolve a GPS coordinate to a [Continent].
  ///
  /// Uses country polygons first, falls back to [ContinentResolver]
  /// bounding-box heuristic for ocean coordinates.
  @override
  Continent resolve(double lat, double lon) {
    for (final boundary in _boundaries) {
      if (!_inBoundingBox(lat, lon, boundary)) continue;
      if (_inCountry(lat, lon, boundary)) return boundary.continent;
    }
    return _fallbackContinent(lat, lon);
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  /// Fast bounding-box rejection test.
  static bool _inBoundingBox(double lat, double lon, CountryBoundary b) {
    return lat >= b.minLat &&
        lat <= b.maxLat &&
        lon >= b.minLon &&
        lon <= b.maxLon;
  }

  /// Full point-in-polygon test for a country (handles MultiPolygon + holes).
  ///
  /// A point is inside a country if it's inside any polygon's outer ring
  /// AND not inside any of that polygon's hole rings.
  static bool _inCountry(double lat, double lon, CountryBoundary b) {
    for (final polygon in b.polygons) {
      if (polygon.isEmpty) continue;

      // First ring is the outer boundary
      if (!_pointInRing(lat, lon, polygon[0])) continue;

      // Check holes (rings 1+). If point is in a hole, skip this polygon.
      var inHole = false;
      for (var h = 1; h < polygon.length; h++) {
        if (_pointInRing(lat, lon, polygon[h])) {
          inHole = true;
          break;
        }
      }
      if (!inHole) return true;
    }
    return false;
  }

  /// Ray-casting algorithm for point-in-polygon test.
  ///
  /// Casts a horizontal ray from (lat, lon) to the right (+lon direction)
  /// and counts how many times it crosses the polygon boundary.
  /// Odd number of crossings = inside.
  ///
  /// [ring] is a list of [lat, lon] coordinate pairs forming a closed polygon.
  /// The last point connects back to the first (implicit closing edge).
  static bool _pointInRing(
    double lat,
    double lon,
    List<List<double>> ring,
  ) {
    if (ring.length < 3) return false;

    var inside = false;
    final n = ring.length;

    for (var i = 0, j = n - 1; i < n; j = i++) {
      final yi = ring[i][0]; // lat of vertex i
      final xi = ring[i][1]; // lon of vertex i
      final yj = ring[j][0]; // lat of vertex j
      final xj = ring[j][1]; // lon of vertex j

      // Check if the ray crosses this edge
      if (((yi > lat) != (yj > lat)) &&
          (lon < (xj - xi) * (lat - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
    }

    return inside;
  }

  /// Fallback for coordinates not in any country polygon (oceans, edge cases).
  /// Uses the existing ContinentResolver bounding-box heuristic.
  static Continent _fallbackContinent(double lat, double lon) {
    return legacy.ContinentResolver.resolve(lat, lon);
  }
}
