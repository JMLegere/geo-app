import 'package:geobase/geobase.dart';

import 'cell_service.dart';

/// In-memory cache wrapping any [CellService] implementation.
///
/// Caches cell centers, boundaries, and neighbor lookups to avoid
/// redundant computation. All game code should use this wrapper.
class CellCache implements CellService {
  final CellService _delegate;

  static const _maxCells = 500;

  final Map<String, Geographic> _centerCache = {};
  final Map<String, List<Geographic>> _boundaryCache = {};
  final Map<String, List<String>> _neighborCache = {};
  // Ring cache keyed by "cellId:k"
  final Map<String, List<String>> _ringCache = {};

  /// Tracks cell access order for LRU eviction (most recent at end).
  final List<String> _accessOrder = [];

  CellCache(this._delegate);

  /// Marks [cellId] as recently used and evicts oldest entries if over capacity.
  void _touch(String cellId) {
    _accessOrder.remove(cellId);
    _accessOrder.add(cellId);
    _evictIfNeeded();
  }

  void _evictIfNeeded() {
    while (_centerCache.length > _maxCells && _accessOrder.isNotEmpty) {
      final oldest = _accessOrder.removeAt(0);
      _centerCache.remove(oldest);
      _boundaryCache.remove(oldest);
      _neighborCache.remove(oldest);
      // Remove all ring entries for this cell (keyed "cellId:k")
      _ringCache.removeWhere((key, _) => key.startsWith('$oldest:'));
    }
  }

  @override
  String getCellId(double lat, double lon) => _delegate.getCellId(lat, lon);
  // getCellId is NOT cached — coordinate → cell mapping is already O(1) in H3

  @override
  Geographic getCellCenter(String cellId) {
    final result =
        _centerCache.putIfAbsent(cellId, () => _delegate.getCellCenter(cellId));
    _touch(cellId);
    return result;
  }

  @override
  List<Geographic> getCellBoundary(String cellId) {
    final result = _boundaryCache.putIfAbsent(
        cellId, () => _delegate.getCellBoundary(cellId));
    _touch(cellId);
    return result;
  }

  @override
  List<String> getNeighborIds(String cellId) {
    final result = _neighborCache.putIfAbsent(
        cellId, () => _delegate.getNeighborIds(cellId));
    _touch(cellId);
    return result;
  }

  @override
  List<String> getCellsInRing(String cellId, int k) {
    final result = _ringCache.putIfAbsent(
        '$cellId:$k', () => _delegate.getCellsInRing(cellId, k));
    _touch(cellId);
    return result;
  }

  @override
  List<String> getCellsAroundLocation(double lat, double lon, int k) {
    final cellId = getCellId(lat, lon);
    final result = getCellsInRing(cellId, k);
    _touch(cellId);
    return result;
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
    _accessOrder.clear();
  }

  /// Number of cached entries (for diagnostics).
  int get cacheSize =>
      _centerCache.length +
      _boundaryCache.length +
      _neighborCache.length +
      _ringCache.length;
}
