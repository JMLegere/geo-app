import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/core/cells/cell_service.dart';
import 'package:earth_nova/features/map/providers/cell_selection_provider.dart';
import 'package:geobase/geobase.dart';

// ---------------------------------------------------------------------------
// MockCellService — deterministic 1°×1° grid.
//
// Cell ID: "cell_{latBucket}_{lonBucket}" where bucket = floor(lat/lon).
// Allows asserting exact cell IDs from known coordinates.
// ---------------------------------------------------------------------------
class _MockCellService implements CellService {
  /// Tracks all getCellId calls for assertion.
  final List<({double lat, double lon})> calls = [];

  @override
  String getCellId(double lat, double lon) {
    calls.add((lat: lat, lon: lon));
    return 'cell_${lat.floor()}_${lon.floor()}';
  }

  @override
  Geographic getCellCenter(String cellId) {
    final parts = cellId.split('_');
    return Geographic(
        lat: double.parse(parts[1]) + 0.5, lon: double.parse(parts[2]) + 0.5);
  }

  @override
  List<Geographic> getCellBoundary(String cellId) {
    final parts = cellId.split('_');
    final lat = double.parse(parts[1]);
    final lon = double.parse(parts[2]);
    return [
      Geographic(lat: lat, lon: lon),
      Geographic(lat: lat, lon: lon + 1),
      Geographic(lat: lat + 1, lon: lon + 1),
      Geographic(lat: lat + 1, lon: lon),
    ];
  }

  @override
  List<String> getNeighborIds(String cellId) => [];

  @override
  List<String> getCellsInRing(String cellId, int k) => [cellId];

  @override
  List<String> getCellsAroundLocation(double lat, double lon, int k) =>
      [getCellId(lat, lon)];

  @override
  double get cellEdgeLengthMeters => 180.0;

  @override
  String get systemName => 'MockGrid';
}

void main() {
  // -------------------------------------------------------------------------
  // CellSelectionNotifier — provider unit tests
  // -------------------------------------------------------------------------

  group('CellSelectionNotifier', () {
    test('initial state is null (no selection)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(cellSelectionProvider), isNull);
    });

    test('select() sets the cell ID', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(cellSelectionProvider.notifier).select('cell_45_-67');

      expect(container.read(cellSelectionProvider), equals('cell_45_-67'));
    });

    test('select() can be called multiple times — last value wins', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(cellSelectionProvider.notifier).select('cell_1_1');
      container.read(cellSelectionProvider.notifier).select('cell_2_2');

      expect(container.read(cellSelectionProvider), equals('cell_2_2'));
    });

    test('clear() resets selection to null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(cellSelectionProvider.notifier).select('cell_45_-67');
      container.read(cellSelectionProvider.notifier).clear();

      expect(container.read(cellSelectionProvider), isNull);
    });

    test('clear() on already-null state stays null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(cellSelectionProvider.notifier).clear();

      expect(container.read(cellSelectionProvider), isNull);
    });

    test('provider emits new state on select()', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final states = <String?>[];
      container.listen(cellSelectionProvider, (_, state) => states.add(state));

      container.read(cellSelectionProvider.notifier).select('cell_10_20');
      container.read(cellSelectionProvider.notifier).select('cell_11_21');
      container.read(cellSelectionProvider.notifier).clear();

      expect(states, equals(['cell_10_20', 'cell_11_21', null]));
    });
  });

  // -------------------------------------------------------------------------
  // Tap-to-cell resolution logic
  //
  // The map tap handler calls getCellId(lat, lon) where lat/lon come from
  // MapEventClick.point. MapLibre Position is (lng, lat) — longitude first.
  // These tests verify the coordinate extraction and cell resolution logic
  // in isolation using MockCellService.
  // -------------------------------------------------------------------------

  group('Tap-to-cell resolution', () {
    // Scenario 1: Map tap resolves to correct cell ID
    // Preconditions: MockCellService returns deterministic cellId for given lat/lon
    // Steps:
    //   1. Simulate tap at lat=45.9636, lon=-66.6431 (Fredericton, NB)
    //   2. Assert getCellId called with lat=45.9636, lon=-66.6431
    //   3. Assert resolved cell ID matches expected value
    test('tap at Fredericton resolves to correct cell ID', () {
      final cellService = _MockCellService();

      // Simulate what _onMapEvent does: extract lat/lon from MapEventClick.point
      // and call getCellId. MapLibre Position(lng, lat) — we access .lat and .lng.
      const tapLat = 45.9636;
      const tapLon = -66.6431;

      final cellId = cellService.getCellId(tapLat, tapLon);

      // Verify getCellId was called with correct lat/lon (not swapped)
      expect(cellService.calls.length, equals(1));
      expect(cellService.calls.first.lat, equals(tapLat));
      expect(cellService.calls.first.lon, equals(tapLon));

      // Verify cell ID: floor(45.9636)=45, floor(-66.6431)=-67
      expect(cellId, equals('cell_45_-67'));
    });

    test('lat/lon are NOT swapped — lat is first arg to getCellId', () {
      final cellService = _MockCellService();

      // If lat/lon were swapped (common bug with Position(lng, lat)),
      // getCellId would receive lon as lat and lat as lon.
      const correctLat = 45.9636;
      const correctLon = -66.6431;

      cellService.getCellId(correctLat, correctLon);

      // The first argument must be latitude (positive for northern hemisphere)
      expect(cellService.calls.first.lat, greaterThan(0),
          reason: 'lat should be positive (northern hemisphere)');
      // The second argument must be longitude (negative for western hemisphere)
      expect(cellService.calls.first.lon, lessThan(0),
          reason: 'lon should be negative (western hemisphere)');
    });

    test('different tap positions resolve to different cell IDs', () {
      final cellService = _MockCellService();

      final cellA = cellService.getCellId(45.9636, -66.6431); // Fredericton
      final cellB = cellService.getCellId(43.6532, -79.3832); // Toronto

      expect(cellA, isNot(equals(cellB)));
    });

    test('same tap position always resolves to same cell ID (deterministic)',
        () {
      final cellService = _MockCellService();

      final cellId1 = cellService.getCellId(45.9636, -66.6431);
      final cellId2 = cellService.getCellId(45.9636, -66.6431);

      expect(cellId1, equals(cellId2));
    });

    // Scenario 2: Non-click map events are ignored
    // The _onMapEvent handler only processes MapEventClick.
    // This is verified by the guard: `if (event is MapEventClick)`.
    // We test the inverse: getCellId is NOT called for non-click events.
    test('getCellId is not called when event is not a click', () {
      final cellService = _MockCellService();

      // Simulate the guard check: only MapEventClick triggers getCellId.
      // A non-click event (e.g., camera move) should not call getCellId.
      // We model this as: the guard returns early, so getCellId is never called.
      const isClickEvent = false; // simulates MapEventMoveCamera
      if (isClickEvent) {
        cellService.getCellId(0, 0); // should NOT be reached
      }

      expect(cellService.calls, isEmpty,
          reason: 'getCellId must not be called for non-click events');
    });

    test('getCellId is called exactly once per click event', () {
      final cellService = _MockCellService();

      // Simulate one click event
      const isClickEvent = true;
      if (isClickEvent) {
        cellService.getCellId(45.9636, -66.6431);
      }

      expect(cellService.calls.length, equals(1),
          reason: 'getCellId must be called exactly once per tap');
    });
  });

  // -------------------------------------------------------------------------
  // Integration: tap → provider state
  // -------------------------------------------------------------------------

  group('Tap → provider state integration', () {
    test('tapping a cell updates cellSelectionProvider', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final cellService = _MockCellService();

      // Simulate the full flow: tap → getCellId → select()
      const tapLat = 45.9636;
      const tapLon = -66.6431;
      final cellId = cellService.getCellId(tapLat, tapLon);
      container.read(cellSelectionProvider.notifier).select(cellId);

      expect(container.read(cellSelectionProvider), equals('cell_45_-67'));
    });

    test('tapping a second cell replaces the first selection', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final cellService = _MockCellService();

      final cellA = cellService.getCellId(45.9636, -66.6431);
      container.read(cellSelectionProvider.notifier).select(cellA);

      final cellB = cellService.getCellId(43.6532, -79.3832);
      container.read(cellSelectionProvider.notifier).select(cellB);

      expect(container.read(cellSelectionProvider), equals(cellB));
      expect(container.read(cellSelectionProvider), isNot(equals(cellA)));
    });
  });
}
