import 'dart:convert';
import 'dart:math';

import 'package:earth_nova/core/models/habitat.dart';

/// A spatial index over biome feature points and polygons for fast habitat
/// queries.
///
/// Feature types and their Habitat mapping:
/// - `coastline` → Saltwater (proximity, within radiusKm)
/// - `rivers` → Freshwater (proximity, within radiusKm)
/// - `lakes` → Freshwater (proximity, within radiusKm)
/// - `mountains` → Mountain (polygon containment — RESOLVE biomes 10-11)
/// - `deserts` → Desert (polygon containment — RESOLVE biome 13)
/// - `wetlands` → Swamp (polygon containment OR centroid proximity within radiusKm)
/// - `forests` → Forest (polygon containment OR centroid proximity within radiusKm)
/// - (default when nothing matches) → Plains
///
/// Point features use a 1°×1° bucket grid for fast neighbour lookups.
/// Polygon features use ray casting containment. Forest and swamp also build
/// a centroid grid so cells within [radiusKm] of any patch get the habitat —
/// this ensures parks and wetland patches influence nearby cells even when the
/// player is not strictly inside the polygon boundary.
class BiomeFeatureIndex {
  /// Loads a [BiomeFeatureIndex] from the JSON string produced by
  /// `assets/biome_features.json`.
  static BiomeFeatureIndex load(String jsonString) {
    final Map<String, dynamic> raw =
        jsonDecode(jsonString) as Map<String, dynamic>;

    // Point features: [[lat, lon], ...]
    List<List<double>> parsePoints(String key) {
      final list = raw[key] as List? ?? [];
      return list
          .map((e) => [(e as List)[0] as num, e[1] as num])
          .map((e) => [e[0].toDouble(), e[1].toDouble()])
          .toList();
    }

    // Polygon features: [[[lat, lon], ...], ...]
    List<List<(double, double)>> parsePolygons(String key) {
      final list = raw[key] as List? ?? [];
      return list.map((ring) {
        final coords = ring as List;
        return coords.map((e) {
          final pt = e as List;
          return ((pt[0] as num).toDouble(), (pt[1] as num).toDouble());
        }).toList();
      }).toList();
    }

    final wetlands = parsePolygons('wetlands');
    final forests = parsePolygons('forests');

    return BiomeFeatureIndex._(
      coastline: parsePoints('coastline'),
      rivers: parsePoints('rivers'),
      lakes: parsePoints('lakes'),
      mountains: parsePolygons('mountains'),
      deserts: parsePolygons('deserts'),
      wetlands: wetlands,
      forests: forests,
      wetlandCentroids: _computeCentroids(wetlands),
      forestCentroids: _computeCentroids(forests),
    );
  }

  final Map<String, List<(double, double)>> _coastlineGrid;
  final Map<String, List<(double, double)>> _riverGrid;
  final Map<String, List<(double, double)>> _lakeGrid;
  final Map<String, List<(double, double)>> _wetlandCentroidGrid;
  final Map<String, List<(double, double)>> _forestCentroidGrid;

  final List<List<(double, double)>> _mountains;
  final List<List<(double, double)>> _deserts;
  final List<List<(double, double)>> _wetlands;
  final List<List<(double, double)>> _forests;

  /// Cache: grid-key → computed `Set<Habitat>`, avoids recomputing for the
  /// same 1° tile many times during a session.
  final Map<String, Set<Habitat>> _cache = {};

  BiomeFeatureIndex._({
    required List<List<double>> coastline,
    required List<List<double>> rivers,
    required List<List<double>> lakes,
    required List<List<(double, double)>> mountains,
    required List<List<(double, double)>> deserts,
    required List<List<(double, double)>> wetlands,
    required List<List<(double, double)>> forests,
    required List<List<double>> wetlandCentroids,
    required List<List<double>> forestCentroids,
  })  : _coastlineGrid = _buildGrid(coastline),
        _riverGrid = _buildGrid(rivers),
        _lakeGrid = _buildGrid(lakes),
        _wetlandCentroidGrid = _buildGrid(wetlandCentroids),
        _forestCentroidGrid = _buildGrid(forestCentroids),
        _mountains = mountains,
        _deserts = deserts,
        _wetlands = wetlands,
        _forests = forests;

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Returns the set of [Habitat]s present within [radiusKm] of ([lat], [lon]).
  ///
  /// Always returns at least `{Habitat.plains}` as the default fallback when
  /// no features are within range.
  Set<Habitat> getBiomesNear(
    double lat,
    double lon, {
    double radiusKm = 5.0,
  }) {
    final cacheKey = _cacheKey(lat, lon, radiusKm);
    return _cache.putIfAbsent(cacheKey, () => _compute(lat, lon, radiusKm));
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  Set<Habitat> _compute(double lat, double lon, double radiusKm) {
    final result = <Habitat>{};

    if (_hasNearby(_coastlineGrid, lat, lon, radiusKm)) {
      result.add(Habitat.saltwater);
    }
    if (_hasNearby(_riverGrid, lat, lon, radiusKm) ||
        _hasNearby(_lakeGrid, lat, lon, radiusKm)) {
      result.add(Habitat.freshwater);
    }
    if (_inAnyPolygon(_mountains, lat, lon)) result.add(Habitat.mountain);
    if (_inAnyPolygon(_deserts, lat, lon)) result.add(Habitat.desert);
    if (_inAnyPolygon(_wetlands, lat, lon) ||
        _hasNearby(_wetlandCentroidGrid, lat, lon, radiusKm)) {
      result.add(Habitat.swamp);
    }
    if (_inAnyPolygon(_forests, lat, lon) ||
        _hasNearby(_forestCentroidGrid, lat, lon, radiusKm)) {
      result.add(Habitat.forest);
    }

    if (result.isEmpty) result.add(Habitat.plains);
    return result;
  }

  /// Checks whether any point in [grid] is within [radiusKm] of ([lat],[lon]).
  static bool _hasNearby(
    Map<String, List<(double, double)>> grid,
    double lat,
    double lon,
    double radiusKm,
  ) {
    final latBucket = lat.floor();
    final lonBucket = lon.floor();

    for (var dLat = -2; dLat <= 2; dLat++) {
      for (var dLon = -2; dLon <= 2; dLon++) {
        final key = '${latBucket + dLat}_${lonBucket + dLon}';
        final pts = grid[key];
        if (pts == null) continue;
        for (final (pLat, pLon) in pts) {
          if (_haversineKm(lat, lon, pLat, pLon) <= radiusKm) return true;
        }
      }
    }
    return false;
  }

  static bool _inAnyPolygon(
    List<List<(double, double)>> polygons,
    double lat,
    double lon,
  ) {
    for (final ring in polygons) {
      if (_pointInPolygon(lat, lon, ring)) return true;
    }
    return false;
  }

  // Ray casting algorithm — O(n) per ring where n = vertex count.
  // Returns true when (lat, lon) is inside the closed polygon ring.
  static bool _pointInPolygon(
    double lat,
    double lon,
    List<(double, double)> ring,
  ) {
    var inside = false;
    final n = ring.length;
    for (var i = 0, j = n - 1; i < n; j = i++) {
      final (iLat, iLon) = ring[i];
      final (jLat, jLon) = ring[j];
      if ((iLon > lon) != (jLon > lon) &&
          lat < (jLat - iLat) * (lon - iLon) / (jLon - iLon) + iLat) {
        inside = !inside;
      }
    }
    return inside;
  }

  /// Computes polygon centroids as [lat, lon] pairs.
  ///
  /// Each ring's centroid is the mean of its vertices. Used to build proximity
  /// grids for forest and swamp so cells within [radiusKm] of any patch get
  /// the habitat even when not strictly inside the polygon boundary.
  static List<List<double>> _computeCentroids(
    List<List<(double, double)>> polygons,
  ) {
    final centroids = <List<double>>[];
    for (final ring in polygons) {
      if (ring.isEmpty) continue;
      var sumLat = 0.0;
      var sumLon = 0.0;
      for (final (lat, lon) in ring) {
        sumLat += lat;
        sumLon += lon;
      }
      centroids.add([sumLat / ring.length, sumLon / ring.length]);
    }
    return centroids;
  }

  /// Builds a 1°×1° bucket grid from a flat list of [lat, lon] pairs.
  static Map<String, List<(double, double)>> _buildGrid(
    List<List<double>> points,
  ) {
    final grid = <String, List<(double, double)>>{};
    for (final pt in points) {
      final key = '${pt[0].floor()}_${pt[1].floor()}';
      (grid[key] ??= []).add((pt[0], pt[1]));
    }
    return grid;
  }

  /// Haversine distance in kilometres between two geographic points.
  static double _haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  /// Cache key at ~0.1° resolution (~11 km) per radius tier.
  static String _cacheKey(double lat, double lon, double radiusKm) {
    return '${(lat * 10).round()}_${(lon * 10).round()}_$radiusKm';
  }
}
