import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/cells/cell_cache.dart';
import 'package:earth_nova/core/cells/h3_cell_service.dart';

void main() {
  // San Francisco (Dolores Park area)
  const double lat = 37.7599;
  const double lon = -122.4268;

  late CellCache cache;

  setUp(() {
    cache = CellCache(H3CellService());
  });

  group('CellCache', () {
    // Test 12: Cache returns same object reference on second call
    test('getCellCenter returns same object reference on second call', () {
      final cellId = cache.getCellId(lat, lon);
      final first = cache.getCellCenter(cellId);
      final second = cache.getCellCenter(cellId);
      expect(identical(first, second), isTrue,
          reason: 'Second call should return the cached object (same identity)');
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
      final direct = H3CellService();
      final cached = CellCache(direct);
      expect(cached.getCellId(lat, lon), equals(direct.getCellId(lat, lon)));
    });

    test('cache delegates getCellCenter to underlying service', () {
      final direct = H3CellService();
      final cached = CellCache(direct);
      final cellId = direct.getCellId(lat, lon);
      final directCenter = direct.getCellCenter(cellId);
      final cachedCenter = cached.getCellCenter(cellId);
      expect(cachedCenter.lat, closeTo(directCenter.lat, 1e-9));
      expect(cachedCenter.lon, closeTo(directCenter.lon, 1e-9));
    });

    test('cache delegates getCellBoundary to underlying service', () {
      final direct = H3CellService();
      final cached = CellCache(direct);
      final cellId = direct.getCellId(lat, lon);
      final directBoundary = direct.getCellBoundary(cellId);
      final cachedBoundary = cached.getCellBoundary(cellId);
      expect(cachedBoundary.length, equals(directBoundary.length));
    });

    test('cache delegates getNeighborIds to underlying service', () {
      final direct = H3CellService();
      final cached = CellCache(direct);
      final cellId = direct.getCellId(lat, lon);
      final directNeighbors = direct.getNeighborIds(cellId);
      final cachedNeighbors = cached.getNeighborIds(cellId);
      expect(cachedNeighbors.toSet(), equals(directNeighbors.toSet()));
    });

    test('cellEdgeLengthMeters delegates to underlying service', () {
      final direct = H3CellService();
      final cached = CellCache(direct);
      expect(cached.cellEdgeLengthMeters, equals(direct.cellEdgeLengthMeters));
    });

    test('systemName delegates to underlying service', () {
      final direct = H3CellService();
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
}
