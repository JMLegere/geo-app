import 'package:geobase/geobase.dart';

import 'cell_service.dart';

/// In-memory cache wrapping any [CellService] implementation.
///
/// Caches cell centers, boundaries, and neighbor lookups to avoid
/// redundant computation. All game code should use this wrapper.
class CellCache implements CellService {
  final CellService _delegate;

  final Map<String, Geographic> _centerCache = {};
  final Map<String, List<Geographic>> _boundaryCache = {};
  final Map<String, List<String>> _neighborCache = {};
  // Ring cache keyed by "cellId:k"
  final Map<String, List<String>> _ringCache = {};

  CellCache(this._delegate);

  @override
  String getCellId(double lat, double lon) => _delegate.getCellId(lat, lon);
  // getCellId is NOT cached — coordinate → cell mapping is already O(1) in H3

  @override
  Geographic getCellCenter(String cellId) =>
      _centerCache.putIfAbsent(cellId, () => _delegate.getCellCenter(cellId));

  @override
  List<Geographic> getCellBoundary(String cellId) =>
      _boundaryCache.putIfAbsent(
          cellId, () => _delegate.getCellBoundary(cellId));

  @override
  List<String> getNeighborIds(String cellId) =>
      _neighborCache.putIfAbsent(
          cellId, () => _delegate.getNeighborIds(cellId));

  @override
  List<String> getCellsInRing(String cellId, int k) =>
      _ringCache.putIfAbsent(
          '$cellId:$k', () => _delegate.getCellsInRing(cellId, k));

  @override
  List<String> getCellsAroundLocation(double lat, double lon, int k) {
    final cellId = getCellId(lat, lon);
    return getCellsInRing(cellId, k);
  }

  @override
  double get cellEdgeLengthMeters => _delegate.cellEdgeLengthMeters;

  @override
  String get systemName => _delegate.systemName;

  /// Clears all cached data. Call when the cell system changes or for testing.
  void clearCache() {
    _centerCache.clear();
    _boundaryCache.clear();
    _neighborCache.clear();
    _ringCache.clear();
  }

  /// Number of cached entries (for diagnostics).
  int get cacheSize =>
      _centerCache.length +
      _boundaryCache.length +
      _neighborCache.length +
      _ringCache.length;
}
