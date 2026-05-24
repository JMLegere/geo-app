import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/core/observability/observable_use_case_provider.dart';
import 'package:earth_nova/features/living_world/presentation/providers/npc_venue_provider.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_border_crossing_event.dart';
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

    Cell cell({
      required String id,
      required double minLat,
      required double maxLat,
      String districtId = 'd1',
      String cityId = 'c1',
      String stateId = 's1',
      String countryId = 'co1',
    }) {
      return Cell(
        id: id,
        habitats: const [],
        polygons: [
          [
            [
              (lat: minLat, lng: 0.0),
              (lat: maxLat, lng: 0.0),
              (lat: maxLat, lng: 1.0),
              (lat: minLat, lng: 1.0),
            ],
          ],
        ],
        districtId: districtId,
        cityId: cityId,
        stateId: stateId,
        countryId: countryId,
      );
    }

    List<Cell> adjacentCells() => [
          cell(id: 'cell-A', minLat: 0.0, maxLat: 1.0),
          cell(
            id: 'cell-B',
            minLat: 1.0,
            maxLat: 2.0,
            districtId: 'd2',
            cityId: 'c2',
            stateId: 's2',
          ),
        ];

    setUp(() {
      testObs = TestObservabilityService();
      container = ProviderContainer(
        overrides: [
          appObservabilityProvider.overrideWithValue(testObs),
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
      expect(state.lastBorderCrossingEvent, isNull);
    });

    test(
        'eligible initial occupancy tracks current cell without visit mutation',
        () async {
      final notifier = container.read(explorationProvider.notifier);
      await notifier.onPositionUpdate(
        markerState: const PlayerMarkerState(
          lat: 0.5,
          lng: 0.5,
          isRing: false,
          gapDistance: 10.0,
        ),
        cells: adjacentCells(),
        visitedCellIds: const <String>{},
      );

      final state = container.read(explorationProvider);
      expect(state.currentCellId, 'cell-A');
      expect(state.visitedCellIds, isEmpty);
      expect(state.lastEnteredCellId, isNull);
      expect(state.lastEntrySequence, 0);
      expect(state.lastBorderCrossingEvent, isNull);
      expect(testObs.eventNames, contains('map.cell_tracked'));
      expect(testObs.eventNames, isNot(contains('map.cell_entered')));
    });

    test(
        "eligible initial occupancy discovers Rowan's Wildlife Rehab Center venue",
        () async {
      final notifier = container.read(explorationProvider.notifier);
      await notifier.onPositionUpdate(
        markerState: const PlayerMarkerState(
          lat: 0.5,
          lng: 0.5,
          isRing: false,
          gapDistance: 10.0,
        ),
        cells: adjacentCells(),
        visitedCellIds: const <String>{},
      );

      final venue = container.read(npcVenueProvider).discoveredVenue;
      expect(venue, isNotNull);
      expect(venue!.venueName, "Rowan's Wildlife Rehab Center");
      expect(venue.npcName, 'Rowan');
      expect(venue.featureName, 'Release to Wild');
      expect(venue.cellId, 'cell-A');
    });

    test('paused eligibility tracks cell without recording a visit', () async {
      final notifier = container.read(explorationProvider.notifier);
      await notifier.onPositionUpdate(
        markerState: const PlayerMarkerState(
          lat: 0.5,
          lng: 0.5,
          isRing: false,
          gapDistance: 10.0,
        ),
        cells: adjacentCells(),
        visitedCellIds: const <String>{},
        explorationEligibility: const ExplorationEligibility(
          canRecordVisits: false,
          isPaused: true,
          reason: ExplorationEligibilityPauseReason.gpsUnavailable,
        ),
      );

      final state = container.read(explorationProvider);
      expect(state.currentCellId, 'cell-A');
      expect(state.visitedCellIds, isEmpty);
      expect(state.lastEnteredCellId, isNull);
      expect(state.lastBorderCrossingEvent, isNull);
      expect(testObs.eventNames, contains('map.cell_tracked'));
      expect(testObs.eventNames, isNot(contains('map.cell_entered')));
      expect(testObs.eventNames, isNot(contains('map.cell_visited')));
      final tracked = testObs.events
          .firstWhere((event) => event.event == 'map.cell_tracked');
      expect(
        tracked.data?['paused_reason'],
        ExplorationEligibilityPauseReason.gpsUnavailable.name,
      );
    });

    test('paused tracking same cell does not spam tracking events', () async {
      final notifier = container.read(explorationProvider.notifier);
      const pausedEligibility = ExplorationEligibility(
        canRecordVisits: false,
        isPaused: true,
        reason: ExplorationEligibilityPauseReason.gpsUnavailable,
      );

      await notifier.onPositionUpdate(
        markerState: const PlayerMarkerState(
          lat: 0.5,
          lng: 0.5,
          isRing: false,
          gapDistance: 10.0,
        ),
        cells: adjacentCells(),
        visitedCellIds: const <String>{},
        explorationEligibility: pausedEligibility,
      );
      await notifier.onPositionUpdate(
        markerState: const PlayerMarkerState(
          lat: 0.5,
          lng: 0.5,
          isRing: false,
          gapDistance: 10.0,
        ),
        cells: adjacentCells(),
        visitedCellIds: const <String>{},
        explorationEligibility: pausedEligibility,
      );

      expect(
        testObs.eventNames.where((event) => event == 'map.cell_tracked').length,
        1,
      );
    });

    test('ring tracking does not create a gameplay entry event', () async {
      await container.read(explorationProvider.notifier).onPositionUpdate(
        markerState: const PlayerMarkerState(
          lat: 0.5,
          lng: 0.5,
          isRing: true,
          gapDistance: 50.0,
        ),
        cells: adjacentCells(),
        visitedCellIds: const <String>{},
      );

      final state = container.read(explorationProvider);
      expect(state.currentCellId, 'cell-A');
      expect(state.visitedCellIds, isEmpty);
      expect(state.lastEnteredCellId, isNull);
      expect(state.lastEntrySequence, 0);
      expect(state.lastBorderCrossingEvent, isNull);
      expect(testObs.eventNames, contains('map.cell_tracked'));
      expect(testObs.eventNames, isNot(contains('map.cell_entered')));
      expect(testObs.eventNames, isNot(contains('map.cell_visited')));
    });

    test('trusted recovery in the same cell does not replay a border crossing',
        () async {
      final notifier = container.read(explorationProvider.notifier);
      const pausedEligibility = ExplorationEligibility(
        canRecordVisits: false,
        isPaused: true,
        reason: ExplorationEligibilityPauseReason.gpsUnavailable,
      );

      await notifier.onPositionUpdate(
        markerState: const PlayerMarkerState(
          lat: 0.5,
          lng: 0.5,
          isRing: false,
          gapDistance: 10.0,
        ),
        cells: adjacentCells(),
        visitedCellIds: const <String>{},
        explorationEligibility: pausedEligibility,
      );
      testObs.events.clear();

      await notifier.onPositionUpdate(
        markerState: const PlayerMarkerState(
          lat: 0.5,
          lng: 0.5,
          isRing: false,
          gapDistance: 10.0,
        ),
        cells: adjacentCells(),
        visitedCellIds: const <String>{},
        explorationEligibility: const ExplorationEligibility(
          canRecordVisits: true,
          isPaused: false,
          reason: null,
        ),
      );

      final state = container.read(explorationProvider);
      expect(state.currentCellId, 'cell-A');
      expect(state.visitedCellIds, isEmpty);
      expect(state.lastEnteredCellId, isNull);
      expect(state.lastBorderCrossingEvent, isNull);
      expect(testObs.eventNames, isNot(contains('map.cell_entered')));
      expect(testObs.eventNames, isNot(contains('map.cell_visited')));
    });

    test(
        'records visit on eligible border crossing and emits crossing identity',
        () async {
      final notifier = container.read(explorationProvider.notifier);
      final cells = adjacentCells();

      await notifier.onPositionUpdate(
        markerState: const PlayerMarkerState(
          lat: 0.5,
          lng: 0.5,
          isRing: false,
          gapDistance: 10.0,
        ),
        cells: cells,
        visitedCellIds: const <String>{},
      );
      testObs.events.clear();

      await notifier.onPositionUpdate(
        markerState: const PlayerMarkerState(
          lat: 1.5,
          lng: 0.5,
          isRing: false,
          gapDistance: 10.0,
        ),
        cells: cells,
        visitedCellIds: const <String>{},
      );

      final state = container.read(explorationProvider);
      expect(state.currentCellId, 'cell-B');
      expect(state.visitedCellIds, {'cell-B'});
      expect(state.lastEnteredCellId, 'cell-B');
      expect(state.lastEntryWasFirstVisit, isTrue);
      expect(state.lastEntrySequence, 1);
      expect(state.lastBorderCrossingEvent, isNotNull);
      final borderCrossing = state.lastBorderCrossingEvent!;
      expect(borderCrossing.previousCellId, 'cell-A');
      expect(borderCrossing.enteredCellId, 'cell-B');
      expect(borderCrossing.isFirstVisit, isTrue);
      expect(
          borderCrossing.borderCrossingType, CellBorderCrossingType.firstEntry);
      expect(borderCrossing.borderCrossingId,
          startsWith('cell-border-crossing-1-'));
      expect(borderCrossing.districtId, 'd2');
      expect(borderCrossing.cityId, 'c2');
      expect(borderCrossing.stateId, 's2');
      expect(borderCrossing.countryId, 'co1');
      expect(testObs.eventNames, contains('map.cell_entered'));
      expect(testObs.eventNames, contains('map.cell_visited'));
      expect(testObs.eventNames, contains('map.fog_cleared'));
      final entered = testObs.events
          .firstWhere((event) => event.event == 'map.cell_entered');
      expect(entered.data?['previous_cell_id'], 'cell-A');
      expect(entered.data?['entered_cell_id'], 'cell-B');
      expect(entered.data?['border_crossing_type'], 'firstEntry');
    });

    test('re-entry border crossing is quieter than first entry', () async {
      final notifier = container.read(explorationProvider.notifier);
      final cells = adjacentCells();

      await notifier.onPositionUpdate(
        markerState: const PlayerMarkerState(
          lat: 1.5,
          lng: 0.5,
          isRing: false,
          gapDistance: 10.0,
        ),
        cells: cells,
        visitedCellIds: const {'cell-A'},
      );
      testObs.events.clear();

      await notifier.onPositionUpdate(
        markerState: const PlayerMarkerState(
          lat: 0.5,
          lng: 0.5,
          isRing: false,
          gapDistance: 10.0,
        ),
        cells: cells,
        visitedCellIds: const {'cell-A'},
      );

      final state = container.read(explorationProvider);
      expect(state.currentCellId, 'cell-A');
      expect(state.visitedCellIds, {'cell-A'});
      expect(state.lastBorderCrossingEvent, isNotNull);
      final borderCrossing = state.lastBorderCrossingEvent!;
      expect(borderCrossing.previousCellId, 'cell-B');
      expect(borderCrossing.enteredCellId, 'cell-A');
      expect(borderCrossing.isFirstVisit, isFalse);
      expect(borderCrossing.borderCrossingType, CellBorderCrossingType.reEntry);
      expect(testObs.eventNames, contains('map.cell_entered'));
      expect(testObs.eventNames, contains('map.cell_visited'));
      expect(testObs.eventNames, isNot(contains('map.fog_cleared')));
    });

    test('moving outside every cell clears current tracked cell', () async {
      final notifier = container.read(explorationProvider.notifier);
      final cells = adjacentCells();

      await notifier.onPositionUpdate(
        markerState: const PlayerMarkerState(
          lat: 0.5,
          lng: 0.5,
          isRing: false,
          gapDistance: 10.0,
        ),
        cells: cells,
        visitedCellIds: const <String>{},
      );
      await notifier.onPositionUpdate(
        markerState: const PlayerMarkerState(
          lat: 100.0,
          lng: 100.0,
          isRing: false,
          gapDistance: 10.0,
        ),
        cells: cells,
        visitedCellIds: const <String>{},
      );

      final state = container.read(explorationProvider);
      expect(state.currentCellId, isNull);
      expect(testObs.eventNames, contains('map.cell_exited'));
    });

    test('logs map.cell_visited on successful backend persist after crossing',
        () async {
      final repo = _MockCellRepository();
      final visitObs = TestObservabilityService();
      final cells = adjacentCells();
      final c = ProviderContainer(
        overrides: [
          appObservabilityProvider.overrideWithValue(testObs),
          explorationObservabilityProvider.overrideWithValue(testObs),
          observableUseCaseProvider.overrideWithValue(testObs),
          cellRepositoryProvider.overrideWithValue(repo),
          visitQueueObservabilityProvider.overrideWithValue(visitObs),
        ],
      );
      addTearDown(c.dispose);

      await c.read(explorationProvider.notifier).onPositionUpdate(
            markerState: const PlayerMarkerState(
              lat: 0.5,
              lng: 0.5,
              isRing: false,
              gapDistance: 10.0,
            ),
            cells: cells,
            visitedCellIds: const <String>{},
            userId: 'user-123',
          );
      testObs.events.clear();

      await c.read(explorationProvider.notifier).onPositionUpdate(
            markerState: const PlayerMarkerState(
              lat: 1.5,
              lng: 0.5,
              isRing: false,
              gapDistance: 10.0,
            ),
            cells: cells,
            visitedCellIds: const <String>{},
            userId: 'user-123',
          );

      expect(testObs.eventNames, contains('map.cell_visited'));
      final event = testObs.events
          .firstWhere((entry) => entry.event == 'map.cell_visited');
      expect(event.data?['cellId'], 'cell-B');
      expect(event.data?['entered_cell_id'], 'cell-B');
    });

    test('enqueues visit when backend persist throws after crossing', () async {
      final repo = _MockCellRepository(shouldThrow: true);
      final visitObs = TestObservabilityService();
      final cells = adjacentCells();
      final c = ProviderContainer(
        overrides: [
          appObservabilityProvider.overrideWithValue(testObs),
          explorationObservabilityProvider.overrideWithValue(testObs),
          observableUseCaseProvider.overrideWithValue(testObs),
          cellRepositoryProvider.overrideWithValue(repo),
          visitQueueObservabilityProvider.overrideWithValue(visitObs),
        ],
      );
      addTearDown(c.dispose);

      await c.read(explorationProvider.notifier).onPositionUpdate(
            markerState: const PlayerMarkerState(
              lat: 0.5,
              lng: 0.5,
              isRing: false,
              gapDistance: 10.0,
            ),
            cells: cells,
            visitedCellIds: const <String>{},
            userId: 'user-123',
          );

      await c.read(explorationProvider.notifier).onPositionUpdate(
            markerState: const PlayerMarkerState(
              lat: 1.5,
              lng: 0.5,
              isRing: false,
              gapDistance: 10.0,
            ),
            cells: cells,
            visitedCellIds: const <String>{},
            userId: 'user-123',
          );

      final explorationState = c.read(explorationProvider);
      final queueState = c.read(visitQueueProvider);

      expect(explorationState.visitedCellIds, {'cell-B'});
      expect(queueState.pendingCount, 1);
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
