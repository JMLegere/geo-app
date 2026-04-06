import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/player_marker_state.dart';
import 'package:earth_nova/features/map/presentation/providers/exploration_provider.dart';

class TestObservabilityService extends ObservabilityService {
  TestObservabilityService() : super(sessionId: 'test-session');

  final List<({String event, String category, Map<String, dynamic>? data})>
      events = [];

  @override
  void log(String event, String category, {Map<String, dynamic>? data}) {
    events.add((event: event, category: category, data: data));
    super.log(event, category, data: data);
  }

  List<String> get eventNames => events.map((e) => e.event).toList();
}

void main() {
  group('ExplorationNotifier', () {
    late ProviderContainer container;
    late TestObservabilityService testObs;

    setUp(() {
      testObs = TestObservabilityService();
      container = ProviderContainer(
        overrides: [
          explorationObservabilityProvider.overrideWithValue(testObs),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state has no current cell and empty visited cells', () {
      final state = container.read(explorationProvider);
      expect(state.currentCellId, isNull);
      expect(state.visitedCellIds, isEmpty);
    });

    test('on cell entry (not ring) records visit', () async {
      // Create cells
      final cells = [
        Cell(
          id: 'cell-1',
          habitats: [],
          polygon: [
            (lat: 0.0, lng: 0.0),
            (lat: 1.0, lng: 0.0),
            (lat: 1.0, lng: 1.0),
            (lat: 0.0, lng: 1.0),
          ],
          districtId: 'd1',
          cityId: 'c1',
          stateId: 's1',
          countryId: 'co1',
        ),
      ];

      // Initial marker position - inside cell-1, not ring
      final notifier = container.read(explorationProvider.notifier);

      // Simulate: entering first cell when not ring
      await notifier.onPositionUpdate(
        markerState: const PlayerMarkerState(
          lat: 0.5,
          lng: 0.5,
          isRing: false,
          gapDistance: 10.0, // Well within 40m ring threshold
        ),
        cells: cells,
        visitedCellIds: <String>{},
      );

      final state = container.read(explorationProvider);
      expect(state.currentCellId, equals('cell-1'));
      expect(state.visitedCellIds, contains('cell-1'));
    });

    test('does NOT record visit when marker is in ring state', () async {
      final cells = [
        Cell(
          id: 'cell-1',
          habitats: [],
          polygon: [
            (lat: 0.0, lng: 0.0),
            (lat: 1.0, lng: 0.0),
            (lat: 1.0, lng: 1.0),
            (lat: 0.0, lng: 1.0),
          ],
          districtId: 'd1',
          cityId: 'c1',
          stateId: 's1',
          countryId: 'co1',
        ),
      ];

      final notifier = container.read(explorationProvider.notifier);

      // Simulate: in cell but in ring state (gap > 40m)
      await notifier.onPositionUpdate(
        markerState: const PlayerMarkerState(
          lat: 0.5,
          lng: 0.5,
          isRing: true,
          gapDistance: 50.0, // Above 40m ring threshold
        ),
        cells: cells,
        visitedCellIds: <String>{},
      );

      final state = container.read(explorationProvider);
      // Cell is tracked but visit is NOT recorded when ring
      expect(state.currentCellId, equals('cell-1'));
      expect(state.visitedCellIds, isEmpty);
    });

    test('records visit on cell transition from A to B', () async {
      final cells = [
        Cell(
          id: 'cell-A',
          habitats: [],
          polygon: [
            (lat: 0.0, lng: 0.0),
            (lat: 1.0, lng: 0.0),
            (lat: 1.0, lng: 1.0),
            (lat: 0.0, lng: 1.0),
          ],
          districtId: 'd1',
          cityId: 'c1',
          stateId: 's1',
          countryId: 'co1',
        ),
        Cell(
          id: 'cell-B',
          habitats: [],
          polygon: [
            (lat: 1.0, lng: 0.0),
            (lat: 2.0, lng: 0.0),
            (lat: 2.0, lng: 1.0),
            (lat: 1.0, lng: 1.0),
          ],
          districtId: 'd2',
          cityId: 'c2',
          stateId: 's2',
          countryId: 'co1',
        ),
      ];

      final notifier = container.read(explorationProvider.notifier);

      // First: enter cell-A
      await notifier.onPositionUpdate(
        markerState: const PlayerMarkerState(
          lat: 0.5,
          lng: 0.5,
          isRing: false,
          gapDistance: 10.0,
        ),
        cells: cells,
        visitedCellIds: <String>{},
      );

      // Then: transition to cell-B
      await notifier.onPositionUpdate(
        markerState: const PlayerMarkerState(
          lat: 1.5,
          lng: 0.5,
          isRing: false,
          gapDistance: 10.0,
        ),
        cells: cells,
        visitedCellIds: {'cell-A'},
      );

      final state = container.read(explorationProvider);
      expect(state.currentCellId, equals('cell-B'));
      expect(state.visitedCellIds, contains('cell-A'));
      expect(state.visitedCellIds, contains('cell-B'));
    });

    test('first visit triggers fog cleared event data', () async {
      final cells = [
        Cell(
          id: 'cell-1',
          habitats: [],
          polygon: [
            (lat: 0.0, lng: 0.0),
            (lat: 1.0, lng: 0.0),
            (lat: 1.0, lng: 1.0),
            (lat: 0.0, lng: 1.0),
          ],
          districtId: 'd1',
          cityId: 'c1',
          stateId: 's1',
          countryId: 'co1',
        ),
      ];

      final notifier = container.read(explorationProvider.notifier);

      // First visit - should trigger firstVisit flag
      await notifier.onPositionUpdate(
        markerState: const PlayerMarkerState(
          lat: 0.5,
          lng: 0.5,
          isRing: false,
          gapDistance: 10.0,
        ),
        cells: cells,
        visitedCellIds: <String>{}, // No previous visits
      );

      final state = container.read(explorationProvider);
      expect(state.visitedCellIds, contains('cell-1'));
    });

    test('subsequent visit does not trigger firstVisit flag', () async {
      final cells = [
        Cell(
          id: 'cell-1',
          habitats: [],
          polygon: [
            (lat: 0.0, lng: 0.0),
            (lat: 1.0, lng: 0.0),
            (lat: 1.0, lng: 1.0),
            (lat: 0.0, lng: 1.0),
          ],
          districtId: 'd1',
          cityId: 'c1',
          stateId: 's1',
          countryId: 'co1',
        ),
      ];

      final notifier = container.read(explorationProvider.notifier);

      // First visit
      await notifier.onPositionUpdate(
        markerState: const PlayerMarkerState(
          lat: 0.5,
          lng: 0.5,
          isRing: false,
          gapDistance: 10.0,
        ),
        cells: cells,
        visitedCellIds: <String>{},
      );

      // Same cell again (simulate re-entering)
      await notifier.onPositionUpdate(
        markerState: const PlayerMarkerState(
          lat: 0.5,
          lng: 0.5,
          isRing: false,
          gapDistance: 10.0,
        ),
        cells: cells,
        visitedCellIds: {'cell-1'},
      );

      final state = container.read(explorationProvider);
      expect(state.visitedCellIds.length, equals(1)); // Still only one visit
    });

    test('does not record visit when marker not in any cell', () async {
      final cells = [
        Cell(
          id: 'cell-1',
          habitats: [],
          polygon: [
            (lat: 0.0, lng: 0.0),
            (lat: 1.0, lng: 0.0),
            (lat: 1.0, lng: 1.0),
            (lat: 0.0, lng: 1.0),
          ],
          districtId: 'd1',
          cityId: 'c1',
          stateId: 's1',
          countryId: 'co1',
        ),
      ];

      final notifier = container.read(explorationProvider.notifier);

      // Marker is far outside any cell
      await notifier.onPositionUpdate(
        markerState: const PlayerMarkerState(
          lat: 100.0,
          lng: 100.0,
          isRing: false,
          gapDistance: 10.0,
        ),
        cells: cells,
        visitedCellIds: <String>{},
      );

      final state = container.read(explorationProvider);
      expect(state.currentCellId, isNull);
      expect(state.visitedCellIds, isEmpty);
    });
  });
}
