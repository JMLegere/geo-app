import 'dart:math';

import 'package:geobase/geobase.dart';

import 'package:earth_nova/core/cells/cell_service.dart';

/// Production Voronoi tessellation implementation of [CellService].
///
/// Generates a deterministic jittered grid of seed points within a bounding
/// box. Each seed point defines a Voronoi cell; cell membership is determined
/// by nearest-neighbor (brute-force O(n)). Cell IDs are string-encoded integer
/// indices: "0", "1", "42", etc.
///
/// Neighbor detection uses a 50×50 sampling grid scan (built once, cached).
/// [getCellsInRing] expands via BFS over the cached neighbor map.
class VoronoiCellService implements CellService {
  final double minLat;
  final double maxLat;
  final double minLon;
  final double maxLon;
  final int gridRows;
  final int gridCols;
  final int seed;

  late final List<(double lat, double lon)> _seeds;

  /// Lazily-built full neighbor map (cell ID → list of neighbor IDs).
  /// First call to [getNeighborIds] triggers construction; O(1) thereafter.
  Map<String, List<String>>? _neighborMap;

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

  /// Total number of Voronoi cells (= gridRows × gridCols).
  int get cellCount => _seeds.length;

  // ---------------------------------------------------------------------------
  // CellService interface
  // ---------------------------------------------------------------------------

  @override
  String getCellId(double lat, double lon) {
    int nearest = 0;
    double minDist = double.infinity;
    for (int i = 0; i < _seeds.length; i++) {
      final d = _squaredDistance(lat, lon, _seeds[i].$1, _seeds[i].$2);
      if (d < minDist) {
        minDist = d;
        nearest = i;
      }
    }
    return nearest.toString();
  }

  @override
  Geographic getCellCenter(String cellId) {
    final idx = _parseId(cellId);
    return Geographic(lat: _seeds[idx].$1, lon: _seeds[idx].$2);
  }

  @override
  List<Geographic> getCellBoundary(String cellId) {
    final idx = _parseId(cellId);
    final points = _sampleCellPoints(idx);
    if (points.length >= 3) {
      return _convexHull(points)
          .map((p) => Geographic(lat: p.$1, lon: p.$2))
          .toList();
    }

    // Fallback: synthetic triangle around seed center when fewer than
    // 3 sample points were assigned (very edge cells with sparse sampling).
    final seedPt = _seeds[idx];
    final delta = (maxLat - minLat) / (gridRows * 4);
    return [
      Geographic(lat: seedPt.$1 + delta, lon: seedPt.$2),
      Geographic(lat: seedPt.$1 - delta / 2, lon: seedPt.$2 + delta),
      Geographic(lat: seedPt.$1 - delta / 2, lon: seedPt.$2 - delta),
    ];
  }

  @override
  List<String> getNeighborIds(String cellId) {
    _buildNeighborMapIfNeeded();
    return _neighborMap![cellId] ?? const [];
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
    // Approximate average cell diameter from bounding-box extent / grid count.
    const metersPerDegLat = 111000.0;
    final midLat = (minLat + maxLat) / 2;
    final metersPerDegLon = 111000.0 * cos(midLat * pi / 180);
    final latCellSize = (maxLat - minLat) * metersPerDegLat / gridRows;
    final lonCellSize = (maxLon - minLon) * metersPerDegLon / gridCols;
    return (latCellSize + lonCellSize) / 2;
  }

  @override
  String get systemName => 'Voronoi (${gridRows}x$gridCols)';

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  List<(double, double)> _generateSeeds() {
    final rng = Random(seed);
    final seeds = <(double, double)>[];
    final latStep = (maxLat - minLat) / gridRows;
    final lonStep = (maxLon - minLon) / gridCols;

    for (int r = 0; r < gridRows; r++) {
      for (int c = 0; c < gridCols; c++) {
        final baseLat = minLat + r * latStep + latStep / 2;
        final baseLon = minLon + c * lonStep + lonStep / 2;
        final jitterLat = (rng.nextDouble() - 0.5) * latStep * 0.6;
        final jitterLon = (rng.nextDouble() - 0.5) * lonStep * 0.6;
        seeds.add((baseLat + jitterLat, baseLon + jitterLon));
      }
    }
    return seeds;
  }

  /// Builds the full neighbor map for all cells in one pass.
  /// Uses a 50×50 sampling grid: two cells are neighbors if any adjacent
  /// sample cells belong to different Voronoi regions.
  void _buildNeighborMapIfNeeded() {
    if (_neighborMap != null) return;

    const sampleRows = 50;
    const sampleCols = 50;
    final latStep = (maxLat - minLat) / sampleRows;
    final lonStep = (maxLon - minLon) / sampleCols;

    // Assign each sample point to its Voronoi cell.
    final grid = List.generate(
      sampleRows,
      (r) => List.generate(sampleCols, (c) {
        final lat = minLat + r * latStep + latStep / 2;
        final lon = minLon + c * lonStep + lonStep / 2;
        return int.parse(getCellId(lat, lon));
      }),
    );

    // Initialise empty neighbor sets for every cell.
    final neighborSets = <String, Set<int>>{
      for (int i = 0; i < _seeds.length; i++) i.toString(): <int>{},
    };

    for (int r = 0; r < sampleRows; r++) {
      for (int c = 0; c < sampleCols; c++) {
        final cell = grid[r][c];
        for (final dr in const [-1, 0, 1]) {
          for (final dc in const [-1, 0, 1]) {
            if (dr == 0 && dc == 0) continue;
            final nr = r + dr;
            final nc = c + dc;
            if (nr < 0 || nr >= sampleRows || nc < 0 || nc >= sampleCols) {
              continue;
            }
            final neighborCell = grid[nr][nc];
            if (neighborCell != cell) {
              neighborSets[cell.toString()]!.add(neighborCell);
            }
          }
        }
      }
    }

    _neighborMap = {
      for (final entry in neighborSets.entries)
        entry.key: (entry.value.toList()..sort())
            .map((i) => i.toString())
            .toList(),
    };
  }

  int _parseId(String cellId) {
    final idx = int.tryParse(cellId);
    if (idx == null || idx < 0 || idx >= _seeds.length) {
      throw ArgumentError(
          'Invalid cell ID: "$cellId" (valid range: 0–${_seeds.length - 1})');
    }
    return idx;
  }

  /// Samples a 30×30 grid and collects all points assigned to [cellIdx].
  List<(double, double)> _sampleCellPoints(int cellIdx) {
    const sampleRows = 30;
    const sampleCols = 30;
    final latStep = (maxLat - minLat) / sampleRows;
    final lonStep = (maxLon - minLon) / sampleCols;
    final points = <(double, double)>[];

    for (int r = 0; r < sampleRows; r++) {
      for (int c = 0; c < sampleCols; c++) {
        final lat = minLat + r * latStep + latStep / 2;
        final lon = minLon + c * lonStep + lonStep / 2;
        if (int.parse(getCellId(lat, lon)) == cellIdx) {
          points.add((lat, lon));
        }
      }
    }
    return points;
  }

  double _squaredDistance(
      double lat1, double lon1, double lat2, double lon2) {
    final dlat = lat1 - lat2;
    final dlon = lon1 - lon2;
    return dlat * dlat + dlon * dlon;
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
      while (hull.length >= 2 &&
          _cross(hull[hull.length - 2], hull.last, p) <= 0) {
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

  double _cross(
      (double, double) o, (double, double) a, (double, double) b) {
    return (a.$1 - o.$1) * (b.$2 - o.$2) - (a.$2 - o.$2) * (b.$1 - o.$1);
  }
}
