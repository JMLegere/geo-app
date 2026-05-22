import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/item.dart';

import 'package:earth_nova/features/map/domain/entities/encounter.dart';
import 'package:earth_nova/features/map/presentation/presenters/encounter_presenter.dart';

void main() {
  group('EncounterPresenter', () {
    test('renders committed species encounters with owned display name', () {
      final encounter = Encounter(
        type: EncounterType.species,
        speciesId: 'species.amberwing_warbler',
        displayName: 'Amberwing Warbler',
        cellId: 'v_22995_-33325',
        seed: 'seed',
        acquiredItem: Item(
          id: 'owned-1',
          definitionId: 'species.amberwing_warbler',
          displayName: 'Amberwing Warbler',
          category: ItemCategory.fauna,
          acquiredAt: DateTime(2026),
          status: ItemStatus.active,
        ),
      );

      final message = EncounterPresenter.message(encounter);

      expect(message, 'You found a Amberwing Warbler');
      expect(message, isNot(contains('species.')));
    });

    test(
        'uncommitted species encounters use spotted copy instead of ownership copy',
        () {
      const encounter = Encounter(
        type: EncounterType.species,
        speciesId: 'species.red_fox',
        displayName: 'Red Fox',
        cellId: 'v_22995_-33325',
        seed: 'seed',
      );

      expect(EncounterPresenter.message(encounter), 'You spotted a Red Fox');
    });

    test('renders non-species encounter copy without raw ids', () {
      const critter = Encounter(
        type: EncounterType.critter,
        speciesId: 'species_abcdef',
        displayName: 'Tiny Critter',
        cellId: 'cell',
        seed: 'seed',
      );
      const loot = Encounter(
        type: EncounterType.loot,
        speciesId: 'species_abcdef',
        displayName: 'Field Supplies',
        cellId: 'cell',
        seed: 'seed',
      );

      expect(EncounterPresenter.message(critter), 'A critter appeared');
      expect(EncounterPresenter.message(loot), 'You found supplies');
    });

    test('friendlySpeciesName returns fallback for empty ids', () {
      expect(EncounterPresenter.friendlySpeciesName(''), 'New Species');
    });

    test('friendlySpeciesName title-cases readable species ids', () {
      expect(
        EncounterPresenter.friendlySpeciesName('species_red_fox'),
        'Red Fox',
      );
    });

    test('friendlySpeciesName stabilizes hash-like species ids', () {
      final first = EncounterPresenter.friendlySpeciesName(
        'species_4f2a9c0d8b1e7a6f',
      );
      final second = EncounterPresenter.friendlySpeciesName(
        'species_4f2a9c0d8b1e7a6f',
      );

      expect(first, equals(second));
      expect(first, isNot(contains('4f2a9c0d8b1e7a6f')));
      expect(first.split(' '), hasLength(2));
    });
  });
}
