import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/entities/encounter.dart';
import 'package:earth_nova/features/map/domain/use_cases/compute_encounter.dart';

class TestObservabilityService extends ObservabilityService {
  TestObservabilityService() : super(sessionId: 'test-session');

  final logs = <Map<String, Object?>>[];

  @override
  void log(String event, String category, {Map<String, dynamic>? data}) {
    logs.add({'event': event, 'category': category, 'data': data});
  }
}

void main() {
  group('Encounter', () {
    test('creates species encounter with correct properties', () {
      const encounter = Encounter(
        type: EncounterType.species,
        speciesId: 'species_123',
        displayName: 'Test Warbler',
        cellId: 'cell_abc',
        seed: 'seed_xyz',
      );

      expect(encounter.type, EncounterType.species);
      expect(encounter.speciesId, 'species_123');
      expect(encounter.cellId, 'cell_abc');
      expect(encounter.seed, 'seed_xyz');
      expect(encounter.displayName, 'Test Warbler');
    });

    test('creates critter encounter with correct properties', () {
      const encounter = Encounter(
        type: EncounterType.critter,
        speciesId: 'critter_456',
        displayName: 'Test Critter',
        cellId: 'cell_def',
        seed: 'seed_abc',
      );

      expect(encounter.type, EncounterType.critter);
      expect(encounter.speciesId, 'critter_456');
      expect(encounter.cellId, 'cell_def');
      expect(encounter.seed, 'seed_abc');
      expect(encounter.displayName, 'Test Critter');
    });
  });

  group('ComputeEncounter', () {
    test('same cellId and seed produces same encounter (deterministic)',
        () async {
      final obs = TestObservabilityService();
      final compute = ComputeEncounter(obs);

      final encounter1 = await compute.call(
        (
          cellId: 'cell_123',
          seed: 'daily_seed',
          isFirstVisit: true,
          hasLoot: false,
        ),
      );

      final encounter2 = await compute.call(
        (
          cellId: 'cell_123',
          seed: 'daily_seed',
          isFirstVisit: true,
          hasLoot: false,
        ),
      );

      expect(encounter1, isNotNull);
      expect(encounter2, isNotNull);
      expect(encounter1!.speciesId, encounter2!.speciesId);
      expect(encounter1.cellId, encounter2.cellId);
      expect(obs.logs[0]['event'], 'operation.started');
      expect(obs.logs[1]['event'], 'operation.completed');
    });

    test('first visit produces a Pack-ready known find result', () async {
      final compute = ComputeEncounter(TestObservabilityService());

      final encounter = await compute.call(
        (
          cellId: 'cell_123',
          seed: 'daily_seed',
          isFirstVisit: true,
          hasLoot: false,
        ),
      );

      expect(encounter, isNotNull);
      expect(encounter!.displayName, isNotEmpty);
      expect(encounter.displayName, isNot(startsWith('species_')));
      expect(encounter.scientificName, isNotEmpty);
      expect(encounter.rarity, isNotEmpty);
      expect(encounter.taxonomicClass, isNotEmpty);
      expect(encounter.speciesId, startsWith('species.'));
    });

    test('different cellId produces different encounter', () async {
      final compute = ComputeEncounter(TestObservabilityService());

      final encounter1 = await compute.call(
        (
          cellId: 'cell_123',
          seed: 'daily_seed',
          isFirstVisit: true,
          hasLoot: false,
        ),
      );

      final encounter2 = await compute.call(
        (
          cellId: 'cell_456',
          seed: 'daily_seed',
          isFirstVisit: true,
          hasLoot: false,
        ),
      );

      expect(encounter1, isNotNull);
      expect(encounter2, isNotNull);
      expect(encounter1!.speciesId, isNot(encounter2!.speciesId));
    });

    test('different seed produces different encounter', () async {
      final compute = ComputeEncounter(TestObservabilityService());

      final encounter1 = await compute.call(
        (
          cellId: 'cell_123',
          seed: 'seed_a',
          isFirstVisit: true,
          hasLoot: false,
        ),
      );

      final encounter2 = await compute.call(
        (
          cellId: 'cell_123',
          seed: 'seed_b',
          isFirstVisit: true,
          hasLoot: false,
        ),
      );

      expect(encounter1, isNotNull);
      expect(encounter2, isNotNull);
      expect(encounter1!.speciesId, isNot(encounter2!.speciesId));
    });

    test('first visit produces species encounter', () async {
      final compute = ComputeEncounter(TestObservabilityService());

      final encounter = await compute.call(
        (
          cellId: 'cell_123',
          seed: 'daily_seed',
          isFirstVisit: true,
          hasLoot: false,
        ),
      );

      expect(encounter, isNotNull);
      expect(encounter!.type, EncounterType.species);
      expect(encounter.cellId, 'cell_123');
      expect(encounter.seed, 'daily_seed');
    });

    test('revisit with daily loot produces critter encounter', () async {
      final compute = ComputeEncounter(TestObservabilityService());

      final encounter = await compute.call(
        (
          cellId: 'cell_123',
          seed: 'daily_seed',
          isFirstVisit: false,
          hasLoot: true,
        ),
      );

      expect(encounter, isNotNull);
      expect(encounter!.type, EncounterType.critter);
      expect(encounter.cellId, 'cell_123');
    });

    test('revisit without loot produces null encounter', () async {
      final compute = ComputeEncounter(TestObservabilityService());

      final encounter = await compute.call(
        (
          cellId: 'cell_123',
          seed: 'daily_seed',
          isFirstVisit: false,
          hasLoot: false,
        ),
      );

      expect(encounter, isNull);
    });

    test('uses deterministic catalog mapping for species selection', () async {
      final compute = ComputeEncounter(TestObservabilityService());

      final encounter = await compute.call(
        (
          cellId: 'cell_test_123',
          seed: 'seed_2026_04_06',
          isFirstVisit: true,
          hasLoot: false,
        ),
      );

      expect(encounter, isNotNull);
      expect(encounter!.speciesId, startsWith('species.'));
      expect(encounter.displayName, isNotEmpty);
      expect(encounter.displayName, isNot(contains(RegExp(r'[0-9a-f]{8}'))));
    });
  });
}
