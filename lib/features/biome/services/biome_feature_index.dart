import 'dart:convert';
import 'dart:math';

import 'package:earth_nova/core/models/habitat.dart';

/// A spatial index over biome feature points and regions for fast proximity
/// queries.
///
/// Feature types and their Habitat mapping:
/// - `coastline` → Saltwater (within 5 km)
/// - `rivers` → Freshwater (within 5 km)
/// - `lakes` → Freshwater (within 5 km)
/// - `mountains` → Mountain (within 5 km)
/// - `deserts` → Desert (centroid + radiusKm)
/// - `wetlands` → Swamp (centroid + radiusKm)
/// - `forests` → Forest (centroid + radiusKm)
/// - (default when nothing matches within 5 km) → Plains
///
/// ## Spatial index
/// Points are bucketed into ~1° grid cells. A proximity query only visits the
/// 9 grid cells surrounding the query point, keeping look-up cost low even for
/// tens-of-thousands of stored points.
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

    // Region features: [[lat, lon, radiusKm], ...]
    List<(double, double, double)> parseRegions(String key) {
      final list = raw[key] as List? ?? [];
      return list
          .map((e) => (
                ((e as List)[0] as num).toDouble(),
                (e[1] as num).toDouble(),
                (e[2] as num).toDouble(),
              ))
          .toList();
    }

    return BiomeFeatureIndex._(
      coastline: parsePoints('coastline'),
      rivers: parsePoints('rivers'),
      lakes: parsePoints('lakes'),
      mountains: parsePoints('mountains'),
      deserts: parseRegions('deserts'),
      wetlands: parseRegions('wetlands'),
      forests: parseRegions('forests'),
    );
  }

  // ── Point features ─────────────────────────────────────────────────────────

  /// Grid index for fast nearest-point lookups.
  /// Key: "latBucket_lonBucket", value: list of (lat, lon) pairs.
  final Map<String, List<(double, double)>> _coastlineGrid;
  final Map<String, List<(double, double)>> _riverGrid;
  final Map<String, List<(double, double)>> _lakeGrid;
  final Map<String, List<(double, double)>> _mountainGrid;

  // ── Region features (centroid + radius) ────────────────────────────────────
  final List<(double, double, double)> _deserts;
  final List<(double, double, double)> _wetlands;
  final List<(double, double, double)> _forests;

  /// Cache: grid-key → computed `Set<Habitat>`, avoids recomputing for the
  /// same 1° tile many times during a session.
  final Map<String, Set<Habitat>> _cache = {};

  BiomeFeatureIndex._({
    required List<List<double>> coastline,
    required List<List<double>> rivers,
    required List<List<double>> lakes,
    required List<List<double>> mountains,
    required List<(double, double, double)> deserts,
    required List<(double, double, double)> wetlands,
    required List<(double, double, double)> forests,
  })  : _coastlineGrid = _buildGrid(coastline),
        _riverGrid = _buildGrid(rivers),
        _lakeGrid = _buildGrid(lakes),
        _mountainGrid = _buildGrid(mountains),
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

    // Point features — check grid neighbours.
    if (_hasNearby(_coastlineGrid, lat, lon, radiusKm)) {
      result.add(Habitat.saltwater);
    }
    if (_hasNearby(_riverGrid, lat, lon, radiusKm) ||
        _hasNearby(_lakeGrid, lat, lon, radiusKm)) {
      result.add(Habitat.freshwater);
    }
    if (_hasNearby(_mountainGrid, lat, lon, radiusKm)) {
      result.add(Habitat.mountain);
    }

    // Region features — centroid within radiusKm.
    if (_inAnyRegion(_deserts, lat, lon)) result.add(Habitat.desert);
    if (_inAnyRegion(_wetlands, lat, lon)) result.add(Habitat.swamp);
    if (_inAnyRegion(_forests, lat, lon)) result.add(Habitat.forest);

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

  /// Checks whether ([lat],[lon]) falls within any region's centroid+radius.
  static bool _inAnyRegion(
    List<(double, double, double)> regions,
    double lat,
    double lon,
  ) {
    for (final (rLat, rLon, radiusKm) in regions) {
      if (_haversineKm(lat, lon, rLat, rLon) <= radiusKm) return true;
    }
    return false;
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
