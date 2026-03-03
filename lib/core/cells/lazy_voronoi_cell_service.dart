import 'dart:math';

import 'package:geobase/geobase.dart';

import 'package:fog_of_world/core/cells/cell_service.dart';
import 'package:fog_of_world/core/cells/delaunay.dart';

/// Cached Voronoi data for a single cell, computed from local Delaunay
/// triangulation.
class _CellVoronoiData {
  /// Ordered polygon boundary vertices (does NOT repeat the first vertex).
  final List<(double, double)> boundary;

  /// Cell IDs of Voronoi neighbors (cells sharing a Delaunay edge).
  final List<String> neighborIds;

  const _CellVoronoiData({
    required this.boundary,
    required this.neighborIds,
  });
}

/// Infinite-world Voronoi cell service with lazy seed materialization.
///
/// Seeds are placed on a conceptual global lat/lon grid with deterministic
/// jitter. Cell boundaries are exact Voronoi polygons computed via Delaunay
/// triangulation (Bowyer-Watson), not convex hull approximations.
///
/// Cell IDs have the format `"v_{row}_{col}"` — globally unique, deterministic,
/// and parseable back to grid coordinates.
///
/// Performance:
/// - [getCellId]: O(9) — checks 3×3 neighborhood of grid cells
/// - [getCellBoundary]: O(n log n) first call (Delaunay of ~49 points), cached
/// - [getNeighborIds]: same as boundary (computed together), cached
class LazyVoronoiCellService implements CellService {
  /// Grid step in degrees. Default 0.002° ≈ 180m at 45° latitude.
  /// Tuned for ~2 min walking between discoveries at 5 km/h.
  final double gridStep;

  /// Jitter factor (0.0–1.0). Controls how far seeds deviate from grid center.
  /// Higher values create more variable cell sizes (variable-ratio reinforcement).
  final double jitterFactor;

  /// Global seed for deterministic jitter generation.
  final int globalSeed;

  /// Radius (in grid steps) around a target cell for Delaunay computation.
  /// A radius of 3 means a 7×7 = 49 seed neighborhood.
  final int neighborRadius;

  /// Cache of computed Voronoi data per cell ID.
  final Map<String, _CellVoronoiData> _voronoiCache = {};

  /// Creates a lazy Voronoi cell service.
  ///
  /// Parameters:
  /// - [gridStep]: spacing between grid cells in degrees (default: 0.002)
  /// - [jitterFactor]: jitter magnitude as fraction of grid step (default: 0.75)
  /// - [globalSeed]: seed for deterministic RNG (default: 42)
  /// - [neighborRadius]: grid radius for local Delaunay (default: 3)
  LazyVoronoiCellService({
    this.gridStep = 0.002,
    this.jitterFactor = 0.75,
    this.globalSeed = 42,
    this.neighborRadius = 3,
  });

  // ---------------------------------------------------------------------------
  // CellService interface
  // ---------------------------------------------------------------------------

  @override
  String getCellId(double lat, double lon) {
    final centerRow = (lat / gridStep).floor();
    final centerCol = (lon / gridStep).floor();

    // Check the 3×3 neighborhood around the grid cell containing (lat, lon).
    String nearestId = '';
    double minDist = double.infinity;

    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        final r = centerRow + dr;
        final c = centerCol + dc;
        final seed = _generateSeed(r, c);
        final d = _squaredDistance(lat, lon, seed.$1, seed.$2);
        if (d < minDist) {
          minDist = d;
          nearestId = _cellId(r, c);
        }
      }
    }

    return nearestId;
  }

  @override
  Geographic getCellCenter(String cellId) {
    final (row, col) = _parseId(cellId);
    final seed = _generateSeed(row, col);
    return Geographic(lat: seed.$1, lon: seed.$2);
  }

  @override
  List<Geographic> getCellBoundary(String cellId) {
    final data = _getVoronoiData(cellId);
    return data.boundary
        .map((p) => Geographic(lat: p.$1, lon: p.$2))
        .toList();
  }

  @override
  List<String> getNeighborIds(String cellId) {
    final data = _getVoronoiData(cellId);
    return data.neighborIds;
  }

  @override
  List<String> getCellsInRing(String cellId, int k) {
    if (k == 0) return [cellId];

    final visited = <String>{cellId};
    var frontier = <String>{cellId};

    for (var ring = 0; ring < k; ring++) {
      final nextFrontier = <String>{};
      for (final cell in frontier) {
        for (final neighbor in getNeighborIds(cell)) {
          if (visited.add(neighbor)) {
            nextFrontier.add(neighbor);
          }
        }
      }
      frontier = nextFrontier;
    }

    return visited.toList();
  }

  @override
  List<String> getCellsAroundLocation(double lat, double lon, int k) {
    final cellId = getCellId(lat, lon);
    return getCellsInRing(cellId, k);
  }

  @override
  double get cellEdgeLengthMeters {
    // Approximate at 45° latitude.
    const metersPerDegLat = 111000.0;
    final metersPerDegLon = metersPerDegLat * cos(45.0 * pi / 180);
    return gridStep * (metersPerDegLat + metersPerDegLon) / 2;
  }

  @override
  String get systemName => 'Lazy Voronoi (step=$gridStep°)';

  // ---------------------------------------------------------------------------
  // Seed generation
  // ---------------------------------------------------------------------------

  /// Generates the deterministic seed point for grid cell (row, col).
  ///
  /// The seed is placed at the grid cell center plus deterministic jitter
  /// derived from a hash of (globalSeed, row, col).
  (double, double) _generateSeed(int row, int col) {
    final baseLat = (row + 0.5) * gridStep;
    final baseLon = (col + 0.5) * gridStep;

    final rng = Random(_hashSeed(row, col));
    final jitterLat = (rng.nextDouble() - 0.5) * gridStep * jitterFactor;
    final jitterLon = (rng.nextDouble() - 0.5) * gridStep * jitterFactor;

    return (baseLat + jitterLat, baseLon + jitterLon);
  }

  /// Generates seeds for a square neighborhood of grid cells.
  ///
  /// Returns a map from (row, col) to seed point (lat, lon).
  Map<(int, int), (double, double)> _getLocalSeeds(
      int centerRow, int centerCol, int radius) {
    final seeds = <(int, int), (double, double)>{};
    for (int dr = -radius; dr <= radius; dr++) {
      for (int dc = -radius; dc <= radius; dc++) {
        final r = centerRow + dr;
        final c = centerCol + dc;
        seeds[(r, c)] = _generateSeed(r, c);
      }
    }
    return seeds;
  }

  // ---------------------------------------------------------------------------
  // Voronoi computation
  // ---------------------------------------------------------------------------

  /// Returns cached Voronoi data for a cell, computing it if necessary.
  _CellVoronoiData _getVoronoiData(String cellId) {
    final cached = _voronoiCache[cellId];
    if (cached != null) return cached;

    final (row, col) = _parseId(cellId);
    final data = _computeLocalVoronoi(row, col);
    _voronoiCache[cellId] = data;
    return data;
  }

  /// Computes the Voronoi polygon and neighbors for cell (row, col) using
  /// local Delaunay triangulation.
  _CellVoronoiData _computeLocalVoronoi(int row, int col) {
    final localSeeds = _getLocalSeeds(row, col, neighborRadius);
    final gridKeys = localSeeds.keys.toList();
    final points = localSeeds.values.toList();

    // Find the index of the target cell in the local point list.
    final targetIdx = gridKeys.indexOf((row, col));
    if (targetIdx < 0) {
      // Should never happen — the target is always in its own neighborhood.
      return const _CellVoronoiData(boundary: [], neighborIds: []);
    }

    final result = delaunayTriangulate(points);

    // Extract Voronoi polygon: circumcenters of triangles containing the target.
    final voronoiVertices = <(double, double, double)>[]; // (x, y, angle)
    final targetSeed = points[targetIdx];

    // Also collect Delaunay neighbors (cells sharing an edge with target).
    final neighborGridKeys = <(int, int)>{};

    for (int i = 0; i < result.triangles.length; i++) {
      final tri = result.triangles[i];
      final hasTarget =
          tri.$1 == targetIdx || tri.$2 == targetIdx || tri.$3 == targetIdx;

      if (hasTarget) {
        final cc = result.circumcenters[i];
        final angle = atan2(cc.$2 - targetSeed.$2, cc.$1 - targetSeed.$1);
        voronoiVertices.add((cc.$1, cc.$2, angle));

        // The other two vertices of this triangle are Delaunay neighbors.
        for (final idx in [tri.$1, tri.$2, tri.$3]) {
          if (idx != targetIdx && idx >= 0 && idx < gridKeys.length) {
            neighborGridKeys.add(gridKeys[idx]);
          }
        }
      }
    }

    // Sort circumcenters by angle around the seed to form a proper polygon.
    voronoiVertices.sort((a, b) => a.$3.compareTo(b.$3));

    final boundary =
        voronoiVertices.map((v) => (v.$1, v.$2)).toList();

    final neighborIds = neighborGridKeys
        .map((key) => _cellId(key.$1, key.$2))
        .toList()
      ..sort();

    return _CellVoronoiData(
      boundary: boundary,
      neighborIds: neighborIds,
    );
  }

  // ---------------------------------------------------------------------------
  // ID encoding / decoding
  // ---------------------------------------------------------------------------

  /// Encodes grid coordinates as a cell ID string.
  static String _cellId(int row, int col) => 'v_${row}_$col';

  /// Parses a cell ID string back to grid coordinates.
  static (int, int) _parseId(String cellId) {
    final parts = cellId.split('_');
    if (parts.length != 3 || parts[0] != 'v') {
      throw ArgumentError(
          'Invalid lazy Voronoi cell ID: "$cellId" (expected "v_{row}_{col}")');
    }
    final row = int.tryParse(parts[1]);
    final col = int.tryParse(parts[2]);
    if (row == null || col == null) {
      throw ArgumentError(
          'Invalid lazy Voronoi cell ID: "$cellId" (non-integer row/col)');
    }
    return (row, col);
  }

  // ---------------------------------------------------------------------------
  // Hash / distance helpers
  // ---------------------------------------------------------------------------

  /// Combines globalSeed, row, and col into a single deterministic hash.
  int _hashSeed(int row, int col) {
    return _hashCombine(_hashCombine(globalSeed, row), col);
  }

  /// Jenkins one-at-a-time hash combine for deterministic seed generation.
  static int _hashCombine(int a, int b) {
    var hash = a;
    hash = (hash + b) & 0x3fffffff;
    hash = (hash + (hash << 10)) & 0x3fffffff;
    hash = hash ^ (hash >> 6);
    hash = (hash + (hash << 3)) & 0x3fffffff;
    hash = hash ^ (hash >> 11);
    hash = (hash + (hash << 15)) & 0x3fffffff;
    return hash;
  }

  /// Squared Euclidean distance in lat/lon space (sufficient for nearest
  /// neighbor among nearby points).
  static double _squaredDistance(
      double lat1, double lon1, double lat2, double lon2) {
    final dlat = lat1 - lat2;
    final dlon = lon1 - lon2;
    return dlat * dlat + dlon * dlon;
  }
}
