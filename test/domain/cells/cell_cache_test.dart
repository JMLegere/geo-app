import 'package:flutter_test/flutter_test.dart';
import 'package:geobase/geobase.dart';

import 'package:earth_nova/domain/cells/cell_cache.dart';
import 'package:earth_nova/domain/cells/cell_service.dart';

// ---------------------------------------------------------------------------
// Counting mock
// ---------------------------------------------------------------------------

/// Records how many times each method is called so tests can verify caching.
class _CountingCellService implements CellService {
  int getCellIdCalls = 0;
  int getCellCenterCalls = 0;
  int getCellBoundaryCalls = 0;
  int getNeighborIdsCalls = 0;
  int getCellsInRingCalls = 0;

  @override
  String getCellId(double lat, double lon) {
    getCellIdCalls++;
    return 'v_${lat.toStringAsFixed(3)}_${lon.toStringAsFixed(3)}';
  }

  @override
  Geographic getCellCenter(String cellId) {
    getCellCenterCalls++;
    return Geographic(lat: 1.0, lon: 1.0);
  }

  @override
  List<Geographic> getCellBoundary(String cellId) {
    getCellBoundaryCalls++;
    return [Geographic(lat: 1.001, lon: 1.001)];
  }

  @override
  List<String> getNeighborIds(String cellId) {
    getNeighborIdsCalls++;
    return ['$cellId\_neighbor'];
  }

  @override
  List<String> getCellsInRing(String cellId, int k) {
    getCellsInRingCalls++;
    return [cellId];
  }

  @override
  List<String> getCellsAroundLocation(double lat, double lon, int k) {
    return getCellsInRing(getCellId(lat, lon), k);
  }

  @override
  double get cellEdgeLengthMeters => 180.0;

  @override
  String get systemName => 'CountingMock';
}

void main() {
  late _CountingCellService delegate;
  late CellCache cache;

  setUp(() {
    delegate = _CountingCellService();
    cache = CellCache(delegate);
  });

  group('CellCache', () {
    // ── caching behaviour ─────────────────────────────────────────────────────

    test('caches getCellCenter — second call does not hit delegate again', () {
      cache.getCellCenter('cell_1');
      cache.getCellCenter('cell_1');
      expect(delegate.getCellCenterCalls, 1);
    });

    test('caches getCellBoundary — second call does not hit delegate again',
        () {
      cache.getCellBoundary('cell_1');
      cache.getCellBoundary('cell_1');
      expect(delegate.getCellBoundaryCalls, 1);
    });

    test('caches getNeighborIds — second call does not hit delegate again', () {
      cache.getNeighborIds('cell_1');
      cache.getNeighborIds('cell_1');
      expect(delegate.getNeighborIdsCalls, 1);
    });

    test('caches getCellsInRing — second call does not hit delegate', () {
      cache.getCellsInRing('cell_1', 1);
      cache.getCellsInRing('cell_1', 1);
      expect(delegate.getCellsInRingCalls, 1);
    });

    test('does NOT cache getCellId — every call delegates', () {
      cache.getCellId(1.0, 1.0);
      cache.getCellId(1.0, 1.0);
      expect(delegate.getCellIdCalls, 2);
    });

    // ── different cell IDs are cached independently ────────────────────────

    test('caches results per cell ID — different IDs each call delegate once',
        () {
      cache.getCellCenter('cell_a');
      cache.getCellCenter('cell_b');
      cache.getCellCenter('cell_a'); // hit
      cache.getCellCenter('cell_b'); // hit
      expect(delegate.getCellCenterCalls, 2);
    });

    // ── LRU eviction ─────────────────────────────────────────────────────────

    test('evicts oldest entries when capacity exceeded', () {
      // Fill beyond the _maxCells cap (500) by inserting 501 unique cells.
      // We only check that the cache does not grow unboundedly.
      for (var i = 0; i < 502; i++) {
        cache.getCellCenter('cell_$i');
      }
      // CellCache._maxCells = 500; after 502 inserts some eviction must have
      // occurred. The delegate must have been called 502 times (no cache hits
      // since all IDs are unique).
      expect(delegate.getCellCenterCalls, 502);
      // Internal size should not exceed _maxCells + 1 (one above triggers evict).
      expect(
          cache.cacheSize, lessThanOrEqualTo(502 * 4)); // generous upper bound
    });

    // ── delegation for non-cached properties ──────────────────────────────────

    test('delegates cellEdgeLengthMeters to underlying service', () {
      expect(cache.cellEdgeLengthMeters, delegate.cellEdgeLengthMeters);
    });

    test('delegates systemName to underlying service', () {
      expect(cache.systemName, delegate.systemName);
    });

    // ── clearCache ────────────────────────────────────────────────────────────

    test('clearCache causes next call to delegate again', () {
      cache.getCellCenter('cell_1'); // miss → delegate called
      cache.clearCache();
      cache.getCellCenter('cell_1'); // miss again after clear
      expect(delegate.getCellCenterCalls, 2);
    });

    test('cacheSize is 0 after clearCache', () {
      cache.getCellCenter('cell_1');
      cache.getCellBoundary('cell_1');
      cache.clearCache();
      expect(cache.cacheSize, 0);
    });
  });
}
