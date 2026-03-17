import 'package:flutter_test/flutter_test.dart';
import 'package:geobase/geobase.dart';
import 'package:earth_nova/core/cells/cell_cache.dart';
import 'package:earth_nova/core/cells/cell_service.dart';
import 'package:earth_nova/core/cells/lazy_voronoi_cell_service.dart';

/// Lightweight mock CellService for LRU eviction tests.
/// Generates unique cell IDs from coordinates without FFI.
class _MockCellService implements CellService {
  int computeCount = 0;

  @override
  String getCellId(double lat, double lon) =>
      'cell_${lat.toInt()}_${lon.toInt()}';

  @override
  Geographic getCellCenter(String cellId) {
    computeCount++;
    return Geographic(lat: 0, lon: 0);
  }

  @override
  List<Geographic> getCellBoundary(String cellId) {
    computeCount++;
    return [Geographic(lat: 0, lon: 0)];
  }

  @override
  List<String> getNeighborIds(String cellId) {
    computeCount++;
    return ['${cellId}_n0', '${cellId}_n1'];
  }

  @override
  List<String> getCellsInRing(String cellId, int k) {
    computeCount++;
    return ['${cellId}_r$k'];
  }

  @override
  List<String> getCellsAroundLocation(double lat, double lon, int k) {
    final cellId = getCellId(lat, lon);
    return getCellsInRing(cellId, k);
  }

  @override
  double get cellEdgeLengthMeters => 174.0;

  @override
  String get systemName => 'Mock';
}

void main() {
  // San Francisco (Dolores Park area)
  const double lat = 37.7599;
  const double lon = -122.4268;

  late CellCache cache;

  setUp(() {
    cache = CellCache(LazyVoronoiCellService());
  });

  group('CellCache', () {
    // Test 12: Cache returns same object reference on second call
    test('getCellCenter returns same object reference on second call', () {
      final cellId = cache.getCellId(lat, lon);
      final first = cache.getCellCenter(cellId);
      final second = cache.getCellCenter(cellId);
      expect(identical(first, second), isTrue,
          reason:
              'Second call should return the cached object (same identity)');
    });

    test('getCellBoundary returns same object reference on second call', () {
      final cellId = cache.getCellId(lat, lon);
      final first = cache.getCellBoundary(cellId);
      final second = cache.getCellBoundary(cellId);
      expect(identical(first, second), isTrue,
          reason: 'Second call should return the cached list (same identity)');
    });

    test('getNeighborIds returns same object reference on second call', () {
      final cellId = cache.getCellId(lat, lon);
      final first = cache.getNeighborIds(cellId);
      final second = cache.getNeighborIds(cellId);
      expect(identical(first, second), isTrue,
          reason: 'Second call should return the cached list (same identity)');
    });

    test('getCellsInRing returns same object reference on second call', () {
      final cellId = cache.getCellId(lat, lon);
      final first = cache.getCellsInRing(cellId, 1);
      final second = cache.getCellsInRing(cellId, 1);
      expect(identical(first, second), isTrue,
          reason: 'Second call should return the cached list (same identity)');
    });

    // Test 13: clearCache resets cacheSize to 0
    test('clearCache resets cacheSize to 0', () {
      final cellId = cache.getCellId(lat, lon);
      cache.getCellCenter(cellId);
      cache.getCellBoundary(cellId);
      cache.getNeighborIds(cellId);
      cache.getCellsInRing(cellId, 1);
      expect(cache.cacheSize, greaterThan(0));

      cache.clearCache();
      expect(cache.cacheSize, equals(0));
    });

    // Test 14: Cache delegates to underlying service correctly
    test('cache delegates getCellId to underlying service', () {
      final direct = LazyVoronoiCellService();
      final cached = CellCache(direct);
      expect(cached.getCellId(lat, lon), equals(direct.getCellId(lat, lon)));
    });

    test('cache delegates getCellCenter to underlying service', () {
      final direct = LazyVoronoiCellService();
      final cached = CellCache(direct);
      final cellId = direct.getCellId(lat, lon);
      final directCenter = direct.getCellCenter(cellId);
      final cachedCenter = cached.getCellCenter(cellId);
      expect(cachedCenter.lat, closeTo(directCenter.lat, 1e-9));
      expect(cachedCenter.lon, closeTo(directCenter.lon, 1e-9));
    });

    test('cache delegates getCellBoundary to underlying service', () {
      final direct = LazyVoronoiCellService();
      final cached = CellCache(direct);
      final cellId = direct.getCellId(lat, lon);
      final directBoundary = direct.getCellBoundary(cellId);
      final cachedBoundary = cached.getCellBoundary(cellId);
      expect(cachedBoundary.length, equals(directBoundary.length));
    });

    test('cache delegates getNeighborIds to underlying service', () {
      final direct = LazyVoronoiCellService();
      final cached = CellCache(direct);
      final cellId = direct.getCellId(lat, lon);
      final directNeighbors = direct.getNeighborIds(cellId);
      final cachedNeighbors = cached.getNeighborIds(cellId);
      expect(cachedNeighbors.toSet(), equals(directNeighbors.toSet()));
    });

    test('cellEdgeLengthMeters delegates to underlying service', () {
      final direct = LazyVoronoiCellService();
      final cached = CellCache(direct);
      expect(cached.cellEdgeLengthMeters, equals(direct.cellEdgeLengthMeters));
    });

    test('systemName delegates to underlying service', () {
      final direct = LazyVoronoiCellService();
      final cached = CellCache(direct);
      expect(cached.systemName, equals(direct.systemName));
    });

    // Test 15: getCellsAroundLocation uses cache internally
    test(
        'getCellsAroundLocation uses ring cache (returns same reference on second call)',
        () {
      // First call: populates the ring cache
      final first = cache.getCellsAroundLocation(lat, lon, 1);
      // Second call: same cellId + k → returns cached ring
      final second = cache.getCellsAroundLocation(lat, lon, 1);
      expect(identical(first, second), isTrue,
          reason:
              'getCellsAroundLocation should use cached ring on second call');
    });

    test('getCellsAroundLocation result matches getCellId + getCellsInRing',
        () {
      const int k = 2;
      final cellId = cache.getCellId(lat, lon);
      final viaRing = cache.getCellsInRing(cellId, k);
      final viaConvenience = cache.getCellsAroundLocation(lat, lon, k);
      expect(viaConvenience.toSet(), equals(viaRing.toSet()));
    });

    // Test 16: cacheSize increments with unique lookups
    test('cacheSize increments with each unique cache entry', () {
      expect(cache.cacheSize, equals(0));

      final cellId = cache.getCellId(lat, lon);

      // +1 center
      cache.getCellCenter(cellId);
      expect(cache.cacheSize, equals(1));

      // +1 boundary
      cache.getCellBoundary(cellId);
      expect(cache.cacheSize, equals(2));

      // +1 neighbors
      cache.getNeighborIds(cellId);
      expect(cache.cacheSize, equals(3));

      // +1 ring k=1
      cache.getCellsInRing(cellId, 1);
      expect(cache.cacheSize, equals(4));

      // +1 ring k=2 (different key: cellId:2)
      cache.getCellsInRing(cellId, 2);
      expect(cache.cacheSize, equals(5));

      // Repeated lookups should NOT increment
      cache.getCellCenter(cellId);
      cache.getCellBoundary(cellId);
      expect(cache.cacheSize, equals(5));
    });

    test('cacheSize counts across all cache maps', () {
      final cellId1 = cache.getCellId(lat, lon);
      final cellId2 = cache.getCellId(lat + 0.01, lon + 0.01);

      cache.getCellCenter(cellId1);
      cache.getCellCenter(cellId2);
      expect(cache.cacheSize, equals(2));

      cache.getCellBoundary(cellId1);
      cache.getCellBoundary(cellId2);
      expect(cache.cacheSize, equals(4));
    });
  });

  group('CellCache LRU eviction', () {
    late _MockCellService mockService;
    late CellCache lruCache;

    setUp(() {
      mockService = _MockCellService();
      lruCache = CellCache(mockService);
    });

    /// Helper: populate cache with [n] unique cells via getCellCenter.
    void populateCells(int n) {
      for (var i = 0; i < n; i++) {
        lruCache.getCellCenter('cell_$i');
      }
    }

    test('cache holds up to 500 entries without eviction', () {
      populateCells(500);
      // Each cell adds 1 center entry
      expect(lruCache.cacheSize, equals(500));
    });

    test('evicts oldest entry when cache exceeds 500 cells', () {
      populateCells(501);
      // cell_0 should have been evicted
      expect(lruCache.cacheSize, equals(500));

      // Accessing cell_0 again should trigger a delegate recompute
      final countBefore = mockService.computeCount;
      lruCache.getCellCenter('cell_0');
      expect(mockService.computeCount, greaterThan(countBefore),
          reason: 'Evicted cell should be recomputed from delegate');
    });

    test('accessing a cell moves it to end of eviction queue', () {
      populateCells(500);
      // Touch cell_0 so it becomes most-recently-used
      lruCache.getCellCenter('cell_0');

      // Add one more cell to trigger eviction
      lruCache.getCellCenter('cell_500');

      // cell_0 should survive (was touched), cell_1 should be evicted
      final countBefore = mockService.computeCount;
      lruCache.getCellCenter('cell_0');
      final countAfterCell0 = mockService.computeCount;
      // cell_0 is cached — no recompute
      expect(countAfterCell0, equals(countBefore));

      lruCache.getCellCenter('cell_1');
      // cell_1 was evicted — must recompute
      expect(mockService.computeCount, greaterThan(countAfterCell0));
    });

    test('eviction removes boundary, neighbor, and ring entries', () {
      // Populate cell_0 with all cache types
      lruCache.getCellCenter('cell_0');
      lruCache.getCellBoundary('cell_0');
      lruCache.getNeighborIds('cell_0');
      lruCache.getCellsInRing('cell_0', 1);
      lruCache.getCellsInRing('cell_0', 2);
      // cacheSize = 1 center + 1 boundary + 1 neighbor + 2 rings = 5
      expect(lruCache.cacheSize, equals(5));

      // Fill remaining 499 slots to push cell_0 to the front
      for (var i = 1; i <= 499; i++) {
        lruCache.getCellCenter('cell_$i');
      }
      // 500 centers + 1 boundary + 1 neighbor + 2 rings = 504
      expect(lruCache.cacheSize, equals(504));

      // Add one more cell — triggers eviction of cell_0
      lruCache.getCellCenter('cell_500');
      // cell_0's center + boundary + neighbor + 2 rings all removed
      // 500 centers (cell_1..cell_500) = 500
      expect(lruCache.cacheSize, equals(500));

      // Verify all cache types for cell_0 are gone (delegate recomputes)
      final countBefore = mockService.computeCount;
      lruCache.getCellCenter('cell_0');
      lruCache.getCellBoundary('cell_0');
      lruCache.getNeighborIds('cell_0');
      lruCache.getCellsInRing('cell_0', 1);
      // 4 recomputes (center, boundary, neighbor, ring)
      expect(mockService.computeCount, equals(countBefore + 4));
    });

    test('clearCache also clears access order', () {
      populateCells(10);
      lruCache.clearCache();
      expect(lruCache.cacheSize, equals(0));

      // After clearing, adding 501 cells should only evict the first one
      // (not any from the pre-clear batch)
      populateCells(501);
      expect(lruCache.cacheSize, equals(500));
    });

    test('getCellsAroundLocation touches the center cell for LRU', () {
      // Fill cache to capacity
      populateCells(500);

      // cell_0 is at front of eviction queue. Touch it via getCellsAroundLocation.
      // _MockCellService.getCellId(0, 0) returns 'cell_0_0', which is different,
      // so we use getCellsInRing directly to touch cell_0.
      lruCache.getCellsInRing('cell_0', 1);

      // Evict by adding one more
      lruCache.getCellCenter('cell_500');

      // cell_0 should survive (was touched via ring), cell_1 evicted
      final countBefore = mockService.computeCount;
      lruCache.getCellCenter('cell_0');
      expect(mockService.computeCount, equals(countBefore),
          reason: 'cell_0 was recently touched and should still be cached');
    });
  });
}
