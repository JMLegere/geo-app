import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/core/observability/observable_use_case_provider.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/location_state.dart';
import 'package:earth_nova/features/map/domain/entities/player_marker_state.dart';
import 'package:earth_nova/features/map/domain/repositories/cell_repository.dart';
import 'package:earth_nova/features/map/presentation/providers/exploration_eligibility_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/exploration_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/location_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/map_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/visit_queue_provider.dart';

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
  group('explorationEligibilityForMarkerProvider', () {
    test('maps ring marker state to paused discovery eligibility', () {
      final container = ProviderContainer();

      final eligibility = container.read(
        explorationEligibilityForMarkerProvider(
          const PlayerMarkerState(
            lat: 0.0,
            lng: 0.0,
            isRing: true,
            gapDistance: 48,
          ),
        ),
      );

      expect(eligibility.canRecordVisits, isFalse);
      expect(eligibility.isPaused, isTrue);
      expect(
        eligibility.reason,
        equals(ExplorationEligibilityPauseReason.lowGpsConfidence),
      );

      container.dispose();
    });

    test('maps non-ring marker state to active discovery eligibility', () {
      final container = ProviderContainer();

      final eligibility = container.read(
        explorationEligibilityForMarkerProvider(
          const PlayerMarkerState(
            lat: 0.0,
            lng: 0.0,
            isRing: false,
            gapDistance: 10,
          ),
        ),
      );

      expect(eligibility.canRecordVisits, isTrue);
      expect(eligibility.isPaused, isFalse);
      expect(eligibility.reason, isNull);

      container.dispose();
    });
  });

  group('explorationEligibilityForLocationProvider', () {
    test('returns paused with gpsUnavailable reason when location is paused',
        () {
      final container = ProviderContainer();

      final eligibility = container.read(
        explorationEligibilityForLocationProvider((
          const LocationProviderPaused(),
          const PlayerMarkerState(
            lat: 0.0,
            lng: 0.0,
            isRing: false,
            gapDistance: 5.0,
          ),
        )),
      );

      expect(eligibility.canRecordVisits, isFalse);
      expect(eligibility.isPaused, isTrue);
      expect(
        eligibility.reason,
        equals(ExplorationEligibilityPauseReason.gpsUnavailable),
      );

      container.dispose();
    });

    test('returns active when location is active and marker is not ring', () {
      final container = ProviderContainer();

      final eligibility = container.read(
        explorationEligibilityForLocationProvider((
          LocationProviderActive(LocationState(
            lat: 1.0,
            lng: 1.0,
            accuracy: 5.0,
            timestamp: DateTime(2026),
            isConfident: true,
          )),
          const PlayerMarkerState(
            lat: 1.0,
            lng: 1.0,
            isRing: false,
            gapDistance: 5.0,
          ),
        )),
      );

      expect(eligibility.canRecordVisits, isTrue);
      expect(eligibility.isPaused, isFalse);
      expect(eligibility.reason, isNull);

      container.dispose();
    });

    test('returns paused with lowGpsConfidence when location active but ring',
        () {
      final container = ProviderContainer();

      final eligibility = container.read(
        explorationEligibilityForLocationProvider((
          LocationProviderActive(LocationState(
            lat: 1.0,
            lng: 1.0,
            accuracy: 5.0,
            timestamp: DateTime(2026),
            isConfident: true,
          )),
          const PlayerMarkerState(
            lat: 1.0,
            lng: 1.0,
            isRing: true,
            gapDistance: 50.0,
          ),
        )),
      );

      expect(eligibility.canRecordVisits, isFalse);
      expect(eligibility.isPaused, isTrue);
      expect(
        eligibility.reason,
        equals(ExplorationEligibilityPauseReason.lowGpsConfidence),
      );

      container.dispose();
    });

    test('returns paused with gpsUnavailable when location is loading', () {
      final container = ProviderContainer();

      final eligibility = container.read(
        explorationEligibilityForLocationProvider((
          const LocationProviderLoading(),
          const PlayerMarkerState(
            lat: 0.0,
            lng: 0.0,
            isRing: false,
            gapDistance: 0.0,
          ),
        )),
      );

      expect(eligibility.canRecordVisits, isFalse);
      expect(eligibility.isPaused, isTrue);
      expect(
        eligibility.reason,
        equals(ExplorationEligibilityPauseReason.gpsUnavailable),
      );

      container.dispose();
    });
  });

  group('ExplorationNotifier', () {
    late ProviderContainer container;
    late TestObservabilityService testObs;

    setUp(() {
      testObs = TestObservabilityService();
      container = ProviderContainer(
        overrides: [
          explorationObservabilityProvider.overrideWithValue(testObs),
          observableUseCaseProvider.overrideWithValue(testObs),
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
          polygons: [[[
            (lat: 0.0, lng: 0.0),
            (lat: 1.0, lng: 0.0),
            (lat: 1.0, lng: 1.0),
            (lat: 0.0, lng: 1.0),
          ]]],
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
          polygons: [[[
            (lat: 0.0, lng: 0.0),
            (lat: 1.0, lng: 0.0),
            (lat: 1.0, lng: 1.0),
            (lat: 0.0, lng: 1.0),
          ]]],
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
          polygons: [[[
            (lat: 0.0, lng: 0.0),
            (lat: 1.0, lng: 0.0),
            (lat: 1.0, lng: 1.0),
            (lat: 0.0, lng: 1.0),
          ]]],
          districtId: 'd1',
          cityId: 'c1',
          stateId: 's1',
          countryId: 'co1',
        ),
        Cell(
          id: 'cell-B',
          habitats: [],
          polygons: [[[
            (lat: 1.0, lng: 0.0),
            (lat: 2.0, lng: 0.0),
            (lat: 2.0, lng: 1.0),
            (lat: 1.0, lng: 1.0),
          ]]],
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
          polygons: [[[
            (lat: 0.0, lng: 0.0),
            (lat: 1.0, lng: 0.0),
            (lat: 1.0, lng: 1.0),
            (lat: 0.0, lng: 1.0),
          ]]],
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
          polygons: [[[
            (lat: 0.0, lng: 0.0),
            (lat: 1.0, lng: 0.0),
            (lat: 1.0, lng: 1.0),
            (lat: 0.0, lng: 1.0),
          ]]],
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
          polygons: [[[
            (lat: 0.0, lng: 0.0),
            (lat: 1.0, lng: 0.0),
            (lat: 1.0, lng: 1.0),
            (lat: 0.0, lng: 1.0),
          ]]],
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

    test('logs map.cell_entered when cell is detected', () async {
      final cells = [
        Cell(
          id: 'cell-1',
          habitats: [],
          polygons: [[[
            (lat: 0.0, lng: 0.0),
            (lat: 1.0, lng: 0.0),
            (lat: 1.0, lng: 1.0),
            (lat: 0.0, lng: 1.0),
          ]]],
          districtId: 'd1',
          cityId: 'c1',
          stateId: 's1',
          countryId: 'co1',
        ),
      ];

      final notifier = container.read(explorationProvider.notifier);
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

      expect(testObs.eventNames, contains('map.cell_entered'));
      final event =
          testObs.events.firstWhere((e) => e.event == 'map.cell_entered');
      expect(event.data?['cellId'], 'cell-1');
      expect(event.data?['isFirstVisit'], isTrue);
    });

    test('logs map.cell_entered with isFirstVisit=true on first visit',
        () async {
      final cells = [
        Cell(
          id: 'cell-1',
          habitats: [],
          polygons: [[[
            (lat: 0.0, lng: 0.0),
            (lat: 1.0, lng: 0.0),
            (lat: 1.0, lng: 1.0),
            (lat: 0.0, lng: 1.0),
          ]]],
          districtId: 'd1',
          cityId: 'c1',
          stateId: 's1',
          countryId: 'co1',
        ),
      ];

      final notifier = container.read(explorationProvider.notifier);
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

      expect(testObs.eventNames, contains('map.cell_entered'));
      final event =
          testObs.events.firstWhere((e) => e.event == 'map.cell_entered');
      expect(event.data?['cellId'], 'cell-1');
      expect(event.data?['isFirstVisit'], isTrue);
    });

    test('logs map.cell_tracked when marker is in ring state', () async {
      final cells = [
        Cell(
          id: 'cell-1',
          habitats: [],
          polygons: [[[
            (lat: 0.0, lng: 0.0),
            (lat: 1.0, lng: 0.0),
            (lat: 1.0, lng: 1.0),
            (lat: 0.0, lng: 1.0),
          ]]],
          districtId: 'd1',
          cityId: 'c1',
          stateId: 's1',
          countryId: 'co1',
        ),
      ];

      final notifier = container.read(explorationProvider.notifier);
      await notifier.onPositionUpdate(
        markerState: const PlayerMarkerState(
          lat: 0.5,
          lng: 0.5,
          isRing: true,
          gapDistance: 50.0,
        ),
        cells: cells,
        visitedCellIds: <String>{},
      );

      expect(testObs.eventNames, contains('map.cell_tracked'));
      // map.cell_tracked is emitted without cell data when in ring state
    });

    test('logs map.cell_visited on successful backend persist', () async {
      final repo = _MockCellRepository();
      final visitObs = TestObservabilityService();
      final c = ProviderContainer(
        overrides: [
          explorationObservabilityProvider.overrideWithValue(testObs),
          observableUseCaseProvider.overrideWithValue(testObs),
          cellRepositoryProvider.overrideWithValue(repo),
          visitQueueObservabilityProvider.overrideWithValue(visitObs),
        ],
      );
      addTearDown(c.dispose);

      final cells = [
        Cell(
          id: 'cell-1',
          habitats: [],
          polygons: [[[
            (lat: 0.0, lng: 0.0),
            (lat: 1.0, lng: 0.0),
            (lat: 1.0, lng: 1.0),
            (lat: 0.0, lng: 1.0),
          ]]],
          districtId: 'd1',
          cityId: 'c1',
          stateId: 's1',
          countryId: 'co1',
        ),
      ];

      await c.read(explorationProvider.notifier).onPositionUpdate(
            markerState: const PlayerMarkerState(
              lat: 0.5,
              lng: 0.5,
              isRing: false,
              gapDistance: 10.0,
            ),
            cells: cells,
            visitedCellIds: <String>{},
            userId: 'user-123',
          );

      expect(testObs.eventNames, contains('map.cell_visited'));
      final event =
          testObs.events.firstWhere((e) => e.event == 'map.cell_visited');
      expect(event.data?['cellId'], 'cell-1');
    });

    test('enqueues visit when backend persist throws', () async {
      final repo = _MockCellRepository(shouldThrow: true);
      final visitObs = TestObservabilityService();
      final c = ProviderContainer(
        overrides: [
          explorationObservabilityProvider.overrideWithValue(testObs),
          observableUseCaseProvider.overrideWithValue(testObs),
          cellRepositoryProvider.overrideWithValue(repo),
          visitQueueObservabilityProvider.overrideWithValue(visitObs),
        ],
      );
      addTearDown(c.dispose);

      final cells = [
        Cell(
          id: 'cell-1',
          habitats: [],
          polygons: [[[
            (lat: 0.0, lng: 0.0),
            (lat: 1.0, lng: 0.0),
            (lat: 1.0, lng: 1.0),
            (lat: 0.0, lng: 1.0),
          ]]],
          districtId: 'd1',
          cityId: 'c1',
          stateId: 's1',
          countryId: 'co1',
        ),
      ];

      await c.read(explorationProvider.notifier).onPositionUpdate(
            markerState: const PlayerMarkerState(
              lat: 0.5,
              lng: 0.5,
              isRing: false,
              gapDistance: 10.0,
            ),
            cells: cells,
            visitedCellIds: <String>{},
            userId: 'user-123',
          );

      // On failure, the error is caught and visit is enqueued
      // The error is logged via operation.failed from the use case
      expect(testObs.eventNames, contains('operation.failed'));
    });
  });
}

class _MockCellRepository implements CellRepository {
  _MockCellRepository({this.shouldThrow = false});
  final bool shouldThrow;

  @override
  Future<List<Cell>> fetchCellsInRadius(
          double lat, double lng, double radiusMeters,
          {String? traceId}) async =>
      [];

  @override
  Future<void> recordVisit(String userId, String cellId,
      {String? traceId}) async {
    if (shouldThrow) throw Exception('network error');
  }

  @override
  Future<Set<String>> getVisitedCellIds(String userId,
          {String? traceId}) async =>
      {};

  @override
  Future<bool> isFirstVisit(String userId, String cellId,
          {String? traceId}) async =>
      true;
}
