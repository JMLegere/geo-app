import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/entities/encounter.dart';
import 'package:earth_nova/features/map/domain/use_cases/compute_encounter.dart';
import 'package:earth_nova/features/map/presentation/providers/encounter_provider.dart';

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
  group('EncounterProvider', () {
    late ProviderContainer container;
    late TestObservabilityService testObs;

    setUp(() {
      testObs = TestObservabilityService();
      container = ProviderContainer(
        overrides: [
          encounterObservabilityProvider.overrideWithValue(testObs),
          computeEncounterProvider.overrideWithValue(const ComputeEncounter()),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state has no current encounter', () {
      final state = container.read(encounterProvider);
      expect(state.currentEncounter, isNull);
    });

    test('first visit triggers species encounter', () {
      final notifier = container.read(encounterProvider.notifier);

      notifier.onCellEntered(
        cellId: 'cell_123',
        isFirstVisit: true,
        seed: 'daily_seed_2026_04_06',
      );

      final state = container.read(encounterProvider);
      expect(state.currentEncounter, isNotNull);
      expect(state.currentEncounter!.type, EncounterType.species);
      expect(state.currentEncounter!.cellId, 'cell_123');

      // Verify observability logging
      expect(testObs.eventNames.contains('map.encounter_triggered'), isTrue);
      final encounterLog = testObs.events
          .firstWhere((l) => l.event == 'map.encounter_triggered');
      expect(encounterLog.data?['cellId'], 'cell_123');
      expect(encounterLog.data?['encounterType'], 'species');
    });

    test('revisit with loot triggers critter encounter', () {
      final notifier = container.read(encounterProvider.notifier);

      // First visit - species
      notifier.onCellEntered(
        cellId: 'cell_123',
        isFirstVisit: true,
        seed: 'daily_seed',
      );

      // Check first state
      final firstState = container.read(encounterProvider);
      expect(firstState.currentEncounter?.type, EncounterType.species);

      // Clear current encounter
      notifier.dismissEncounter();

      // Revisit with loot
      notifier.onCellEntered(
        cellId: 'cell_123',
        isFirstVisit: false,
        hasLoot: true,
        seed: 'daily_seed',
      );

      final state = container.read(encounterProvider);
      expect(state.currentEncounter, isNotNull);
      expect(state.currentEncounter!.type, EncounterType.critter);
    });

    test('revisit without loot does not trigger encounter', () {
      final notifier = container.read(encounterProvider.notifier);

      // First visit
      notifier.onCellEntered(
        cellId: 'cell_123',
        isFirstVisit: true,
        seed: 'daily_seed',
      );

      // Clear current encounter
      notifier.dismissEncounter();

      // Revisit without loot
      notifier.onCellEntered(
        cellId: 'cell_123',
        isFirstVisit: false,
        hasLoot: false,
        seed: 'daily_seed',
      );

      final state = container.read(encounterProvider);
      expect(state.currentEncounter, isNull);
    });

    test('dismiss encounter clears current encounter', () {
      final notifier = container.read(encounterProvider.notifier);

      notifier.onCellEntered(
        cellId: 'cell_123',
        isFirstVisit: true,
        seed: 'daily_seed',
      );

      var state = container.read(encounterProvider);
      expect(state.currentEncounter, isNotNull);

      notifier.dismissEncounter();

      state = container.read(encounterProvider);
      expect(state.currentEncounter, isNull);

      // Verify dismiss logging
      expect(testObs.eventNames.contains('map.encounter_dismissed'), isTrue);
    });
  });

  group('EncounterState', () {
    test('copyWith preserves unchanged fields', () {
      const encounter = Encounter(
        type: EncounterType.species,
        speciesId: 'species_123',
        cellId: 'cell_abc',
        seed: 'seed_xyz',
      );

      final state = EncounterState(currentEncounter: encounter);
      final copied = state.copyWith();

      expect(copied.currentEncounter, encounter);
    });

    test('copyWith can clear encounter', () {
      const encounter = Encounter(
        type: EncounterType.species,
        speciesId: 'species_123',
        cellId: 'cell_abc',
        seed: 'seed_xyz',
      );

      final state = EncounterState(currentEncounter: encounter);
      final copied = state.copyWith(clearEncounter: true);

      expect(copied.currentEncounter, isNull);
    });
  });
}
