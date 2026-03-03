import 'dart:math';

/// A single Voronoi seed point defining a cell.
class VoronoiSeed {
  final double lat;
  final double lon;

  const VoronoiSeed(this.lat, this.lon);
}

/// Spike implementation of Voronoi tessellation using brute-force nearest-neighbor.
///
/// Generates a deterministic jittered grid of seed points within a bounding box.
/// Cell IDs are integer indices into the seed list.
///
/// NOTE: This is an intentionally simple brute-force O(n·m) implementation for
/// spike evaluation. Production use would require Fortune's algorithm or a KD-tree.
class VoronoiCellService {
  final double minLat;
  final double maxLat;
  final double minLon;
  final double maxLon;
  final int gridRows;
  final int gridCols;
  final int seed;

  late final List<VoronoiSeed> _seeds;

  VoronoiCellService({
    required this.minLat,
    required this.maxLat,
    required this.minLon,
    required this.maxLon,
    this.gridRows = 20,
    this.gridCols = 20,
    this.seed = 42,
  }) {
    _seeds = _generateSeeds();
  }

  int get cellCount => _seeds.length;

  /// Returns the cell ID (index) containing the given lat/lon point.
  int getCellForPoint(double lat, double lon) {
    int nearest = 0;
    double minDist = double.infinity;
    for (int i = 0; i < _seeds.length; i++) {
      final d = _squaredDistance(lat, lon, _seeds[i].lat, _seeds[i].lon);
      if (d < minDist) {
        minDist = d;
        nearest = i;
      }
    }
    return nearest;
  }

  /// Returns the seed point (center) of the given cell.
  (double lat, double lon) getCellCenter(int cellId) {
    _assertValidCell(cellId);
    return (_seeds[cellId].lat, _seeds[cellId].lon);
  }

  /// Returns a convex-hull polygon approximation of the cell boundary.
  ///
  /// Samples a grid of points within the bounding box, collects those
  /// assigned to this cell, and computes their convex hull. For very small
  /// cells with fewer than 3 sample points, falls back to a synthetic
  /// triangle around the seed center.
  List<(double lat, double lon)> getCellBoundary(int cellId) {
    _assertValidCell(cellId);
    final points = _sampleCellPoints(cellId);
    if (points.length >= 3) return _convexHull(points);

    // Fallback: generate a small triangle around the seed center
    final seed = _seeds[cellId];
    final delta = (maxLat - minLat) / (gridRows * 4);
    return [
      (seed.lat + delta, seed.lon),
      (seed.lat - delta / 2, seed.lon + delta),
      (seed.lat - delta / 2, seed.lon - delta),
    ];
  }

  /// Returns the IDs of cells that share a border with the given cell.
  ///
  /// Two cells are neighbors if any sample point assigned to one is adjacent
  /// to a sample point assigned to the other in the sampling grid.
  List<int> getNeighbors(int cellId) {
    _assertValidCell(cellId);
    final neighborSet = <int>{};
    const sampleRows = 50;
    const sampleCols = 50;
    final latStep = (maxLat - minLat) / sampleRows;
    final lonStep = (maxLon - minLon) / sampleCols;

    final grid = List.generate(
      sampleRows,
      (r) => List.generate(sampleCols, (c) {
        final lat = minLat + r * latStep + latStep / 2;
        final lon = minLon + c * lonStep + lonStep / 2;
        return getCellForPoint(lat, lon);
      }),
    );

    for (int r = 0; r < sampleRows; r++) {
      for (int c = 0; c < sampleCols; c++) {
        if (grid[r][c] != cellId) continue;
        for (final dr in [-1, 0, 1]) {
          for (final dc in [-1, 0, 1]) {
            if (dr == 0 && dc == 0) continue;
            final nr = r + dr;
            final nc = c + dc;
            if (nr < 0 || nr >= sampleRows || nc < 0 || nc >= sampleCols) {
              continue;
            }
            final neighborCell = grid[nr][nc];
            if (neighborCell != cellId) {
              neighborSet.add(neighborCell);
            }
          }
        }
      }
    }
    return neighborSet.toList()..sort();
  }

  List<VoronoiSeed> _generateSeeds() {
    final rng = Random(seed);
    final seeds = <VoronoiSeed>[];
    final latStep = (maxLat - minLat) / gridRows;
    final lonStep = (maxLon - minLon) / gridCols;

    for (int r = 0; r < gridRows; r++) {
      for (int c = 0; c < gridCols; c++) {
        final baseLat = minLat + r * latStep + latStep / 2;
        final baseLon = minLon + c * lonStep + lonStep / 2;
        final jitterLat = (rng.nextDouble() - 0.5) * latStep * 0.6;
        final jitterLon = (rng.nextDouble() - 0.5) * lonStep * 0.6;
        seeds.add(VoronoiSeed(baseLat + jitterLat, baseLon + jitterLon));
      }
    }
    return seeds;
  }

  List<(double, double)> _sampleCellPoints(int cellId) {
    const sampleRows = 30;
    const sampleCols = 30;
    final latStep = (maxLat - minLat) / sampleRows;
    final lonStep = (maxLon - minLon) / sampleCols;
    final points = <(double, double)>[];

    for (int r = 0; r < sampleRows; r++) {
      for (int c = 0; c < sampleCols; c++) {
        final lat = minLat + r * latStep + latStep / 2;
        final lon = minLon + c * lonStep + lonStep / 2;
        if (getCellForPoint(lat, lon) == cellId) {
          points.add((lat, lon));
        }
      }
    }
    return points;
  }

  double _squaredDistance(double lat1, double lon1, double lat2, double lon2) {
    final dlat = lat1 - lat2;
    final dlon = lon1 - lon2;
    return dlat * dlat + dlon * dlon;
  }

  void _assertValidCell(int cellId) {
    if (cellId < 0 || cellId >= _seeds.length) {
      throw ArgumentError('Invalid cell ID: $cellId (max ${_seeds.length - 1})');
    }
  }

  List<(double, double)> _convexHull(List<(double, double)> points) {
    if (points.length <= 2) return List.from(points);

    final sorted = List<(double, double)>.from(points)
      ..sort((a, b) {
        final cmp = a.$1.compareTo(b.$1);
        return cmp != 0 ? cmp : a.$2.compareTo(b.$2);
      });

    final hull = <(double, double)>[];

    // Lower hull
    for (final p in sorted) {
      while (hull.length >= 2 && _cross(hull[hull.length - 2], hull.last, p) <= 0) {
        hull.removeLast();
      }
      hull.add(p);
    }

    // Upper hull
    final lowerLen = hull.length + 1;
    for (int i = sorted.length - 2; i >= 0; i--) {
      final p = sorted[i];
      while (hull.length >= lowerLen &&
          _cross(hull[hull.length - 2], hull.last, p) <= 0) {
        hull.removeLast();
      }
      hull.add(p);
    }

    hull.removeLast();
    return hull;
  }

  double _cross((double, double) o, (double, double) a, (double, double) b) {
    return (a.$1 - o.$1) * (b.$2 - o.$2) - (a.$2 - o.$2) * (b.$1 - o.$1);
  }
}
