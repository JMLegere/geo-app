import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/map/domain/entities/encounter.dart';

void main() {
  group('EncounterType', () {
    test('has species, critter, loot values', () {
      expect(
          EncounterType.values,
          containsAll([
            EncounterType.species,
            EncounterType.critter,
            EncounterType.loot,
          ]));
    });

    test('has exactly 3 values', () {
      expect(EncounterType.values.length, 3);
    });
  });

  group('Encounter', () {
    test('constructs with required fields', () {
      const encounter = Encounter(
        type: EncounterType.species,
        speciesId: 'species-1',
        cellId: 'cell-1',
        seed: 'seed-123',
      );
      expect(encounter.type, EncounterType.species);
      expect(encounter.speciesId, 'species-1');
      expect(encounter.cellId, 'cell-1');
      expect(encounter.seed, 'seed-123');
    });

    test('equality', () {
      const a = Encounter(
        type: EncounterType.species,
        speciesId: 'species-1',
        cellId: 'cell-1',
        seed: 'seed-123',
      );
      const b = Encounter(
        type: EncounterType.species,
        speciesId: 'species-1',
        cellId: 'cell-1',
        seed: 'seed-123',
      );
      expect(a, equals(b));
    });

    test('inequality when type differs', () {
      const a = Encounter(
        type: EncounterType.species,
        speciesId: 'species-1',
        cellId: 'cell-1',
        seed: 'seed-123',
      );
      const b = Encounter(
        type: EncounterType.critter,
        speciesId: 'species-1',
        cellId: 'cell-1',
        seed: 'seed-123',
      );
      expect(a, isNot(equals(b)));
    });

    test('inequality when speciesId differs', () {
      const a = Encounter(
        type: EncounterType.species,
        speciesId: 'species-1',
        cellId: 'cell-1',
        seed: 'seed-123',
      );
      const b = Encounter(
        type: EncounterType.species,
        speciesId: 'species-2',
        cellId: 'cell-1',
        seed: 'seed-123',
      );
      expect(a, isNot(equals(b)));
    });

    test('inequality when cellId differs', () {
      const a = Encounter(
        type: EncounterType.species,
        speciesId: 'species-1',
        cellId: 'cell-1',
        seed: 'seed-123',
      );
      const b = Encounter(
        type: EncounterType.species,
        speciesId: 'species-1',
        cellId: 'cell-2',
        seed: 'seed-123',
      );
      expect(a, isNot(equals(b)));
    });

    test('inequality when seed differs', () {
      const a = Encounter(
        type: EncounterType.species,
        speciesId: 'species-1',
        cellId: 'cell-1',
        seed: 'seed-123',
      );
      const b = Encounter(
        type: EncounterType.species,
        speciesId: 'species-1',
        cellId: 'cell-1',
        seed: 'seed-456',
      );
      expect(a, isNot(equals(b)));
    });

    test('hashCode is consistent for equal encounters', () {
      const a = Encounter(
        type: EncounterType.species,
        speciesId: 'species-1',
        cellId: 'cell-1',
        seed: 'seed-123',
      );
      const b = Encounter(
        type: EncounterType.species,
        speciesId: 'species-1',
        cellId: 'cell-1',
        seed: 'seed-123',
      );
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
