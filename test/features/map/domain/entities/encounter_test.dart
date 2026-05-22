import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
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

    test('default displayName is used when none is provided', () {
      const encounter = Encounter(
        type: EncounterType.species,
        speciesId: 'species-1',
        cellId: 'cell-1',
        seed: 'seed-123',
      );
      expect(encounter.displayName, 'Unknown Discovery');
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

    test('copyWith updates owned metadata fields', () {
      final acquiredItem = Item(
        id: 'owned-1',
        definitionId: 'species-1',
        displayName: 'Red Fox',
        category: ItemCategory.fauna,
        acquiredAt: DateTime(2026),
        status: ItemStatus.active,
      );
      final encounter = Encounter(
        type: EncounterType.species,
        speciesId: 'species-1',
        displayName: 'Red Fox',
        cellId: 'cell-1',
        seed: 'seed-123',
      );

      final updated = encounter.copyWith(
        scientificName: 'Vulpes vulpes',
        rarity: 'rare',
        taxonomicClass: 'Mammalia',
        habitats: const ['forest'],
        continents: const ['North America'],
        acquiredItem: acquiredItem,
      );

      expect(updated.scientificName, 'Vulpes vulpes');
      expect(updated.rarity, 'rare');
      expect(updated.taxonomicClass, 'Mammalia');
      expect(updated.habitats, ['forest']);
      expect(updated.continents, ['North America']);
      expect(updated.acquiredItem, acquiredItem);
    });

    test('copyWith preserves existing acquired item when none is provided', () {
      final acquiredItem = Item(
        id: 'owned-1',
        definitionId: 'species-1',
        displayName: 'Red Fox',
        category: ItemCategory.fauna,
        acquiredAt: DateTime(2026),
        status: ItemStatus.active,
      );
      final encounter = Encounter(
        type: EncounterType.species,
        speciesId: 'species-1',
        displayName: 'Red Fox',
        cellId: 'cell-1',
        seed: 'seed-123',
        acquiredItem: acquiredItem,
      );

      final updated = encounter.copyWith(rarity: 'rare');

      expect(updated.acquiredItem, acquiredItem);
    });

    test('equality includes metadata lists and acquired item', () {
      final acquiredItem = Item(
        id: 'owned-1',
        definitionId: 'species-1',
        displayName: 'Red Fox',
        category: ItemCategory.fauna,
        acquiredAt: DateTime(2026),
        status: ItemStatus.active,
      );
      final a = Encounter(
        type: EncounterType.species,
        speciesId: 'species-1',
        displayName: 'Red Fox',
        cellId: 'cell-1',
        seed: 'seed-123',
        scientificName: 'Vulpes vulpes',
        rarity: 'rare',
        taxonomicClass: 'Mammalia',
        habitats: const ['forest'],
        continents: const ['North America'],
        acquiredItem: acquiredItem,
      );
      final b = Encounter(
        type: EncounterType.species,
        speciesId: 'species-1',
        displayName: 'Red Fox',
        cellId: 'cell-1',
        seed: 'seed-123',
        scientificName: 'Vulpes vulpes',
        rarity: 'rare',
        taxonomicClass: 'Mammalia',
        habitats: const ['forest'],
        continents: const ['North America'],
        acquiredItem: acquiredItem,
      );

      expect(a, equals(b));
    });

    test('inequality when habitat list lengths differ', () {
      final a = Encounter(
        type: EncounterType.species,
        speciesId: 'species-1',
        displayName: 'Red Fox',
        cellId: 'cell-1',
        seed: 'seed-123',
        habitats: const ['forest'],
      );
      final b = Encounter(
        type: EncounterType.species,
        speciesId: 'species-1',
        displayName: 'Red Fox',
        cellId: 'cell-1',
        seed: 'seed-123',
        habitats: const ['forest', 'urban'],
      );

      expect(a, isNot(equals(b)));
    });

    test('inequality when continent values differ', () {
      final a = Encounter(
        type: EncounterType.species,
        speciesId: 'species-1',
        displayName: 'Red Fox',
        cellId: 'cell-1',
        seed: 'seed-123',
        habitats: const ['forest'],
        continents: const ['North America'],
      );
      final b = Encounter(
        type: EncounterType.species,
        speciesId: 'species-1',
        displayName: 'Red Fox',
        cellId: 'cell-1',
        seed: 'seed-123',
        habitats: const ['forest'],
        continents: const ['Europe'],
      );

      expect(a, isNot(equals(b)));
    });
  });
}
