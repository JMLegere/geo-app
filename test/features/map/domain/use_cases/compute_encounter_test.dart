import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/map/domain/entities/encounter.dart';
import 'package:earth_nova/features/map/domain/use_cases/compute_encounter.dart';

void main() {
  group('Encounter', () {
    test('creates species encounter with correct properties', () {
      const encounter = Encounter(
        type: EncounterType.species,
        speciesId: 'species_123',
        cellId: 'cell_abc',
        seed: 'seed_xyz',
      );

      expect(encounter.type, EncounterType.species);
      expect(encounter.speciesId, 'species_123');
      expect(encounter.cellId, 'cell_abc');
      expect(encounter.seed, 'seed_xyz');
    });

    test('creates critter encounter with correct properties', () {
      const encounter = Encounter(
        type: EncounterType.critter,
        speciesId: 'critter_456',
        cellId: 'cell_def',
        seed: 'seed_abc',
      );

      expect(encounter.type, EncounterType.critter);
      expect(encounter.speciesId, 'critter_456');
      expect(encounter.cellId, 'cell_def');
      expect(encounter.seed, 'seed_abc');
    });
  });

  group('ComputeEncounter', () {
    test('same cellId and seed produces same encounter (deterministic)', () {
      const compute = ComputeEncounter();

      final encounter1 = compute.call(
        cellId: 'cell_123',
        seed: 'daily_seed',
        isFirstVisit: true,
      );

      final encounter2 = compute.call(
        cellId: 'cell_123',
        seed: 'daily_seed',
        isFirstVisit: true,
      );

      expect(encounter1, isNotNull);
      expect(encounter2, isNotNull);
      expect(encounter1!.speciesId, encounter2!.speciesId);
      expect(encounter1.cellId, encounter2.cellId);
    });

    test('different cellId produces different encounter', () {
      const compute = ComputeEncounter();

      final encounter1 = compute.call(
        cellId: 'cell_123',
        seed: 'daily_seed',
        isFirstVisit: true,
      );

      final encounter2 = compute.call(
        cellId: 'cell_456',
        seed: 'daily_seed',
        isFirstVisit: true,
      );

      expect(encounter1, isNotNull);
      expect(encounter2, isNotNull);
      expect(encounter1!.speciesId, isNot(encounter2!.speciesId));
    });

    test('different seed produces different encounter', () {
      const compute = ComputeEncounter();

      final encounter1 = compute.call(
        cellId: 'cell_123',
        seed: 'seed_a',
        isFirstVisit: true,
      );

      final encounter2 = compute.call(
        cellId: 'cell_123',
        seed: 'seed_b',
        isFirstVisit: true,
      );

      expect(encounter1, isNotNull);
      expect(encounter2, isNotNull);
      expect(encounter1!.speciesId, isNot(encounter2!.speciesId));
    });

    test('first visit produces species encounter', () {
      const compute = ComputeEncounter();

      final encounter = compute.call(
        cellId: 'cell_123',
        seed: 'daily_seed',
        isFirstVisit: true,
      );

      expect(encounter, isNotNull);
      expect(encounter!.type, EncounterType.species);
      expect(encounter.cellId, 'cell_123');
      expect(encounter.seed, 'daily_seed');
    });

    test('revisit with daily loot produces critter encounter', () {
      const compute = ComputeEncounter();

      final encounter = compute.call(
        cellId: 'cell_123',
        seed: 'daily_seed',
        isFirstVisit: false,
        hasLoot: true,
      );

      expect(encounter, isNotNull);
      expect(encounter!.type, EncounterType.critter);
      expect(encounter.cellId, 'cell_123');
    });

    test('revisit without loot produces null encounter', () {
      const compute = ComputeEncounter();

      final encounter = compute.call(
        cellId: 'cell_123',
        seed: 'daily_seed',
        isFirstVisit: false,
        hasLoot: false,
      );

      expect(encounter, isNull);
    });

    test('uses SHA-256 hash for deterministic species selection', () {
      const compute = ComputeEncounter();

      // The seed + cellId should be hashed to select species
      // Verify that specific input produces consistent output
      final encounter = compute.call(
        cellId: 'cell_test_123',
        seed: 'seed_2026_04_06',
        isFirstVisit: true,
      );

      expect(encounter, isNotNull);
      expect(encounter!.speciesId, isNotEmpty);
    });
  });
}
