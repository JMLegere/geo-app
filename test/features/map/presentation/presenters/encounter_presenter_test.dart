import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/features/map/domain/entities/encounter.dart';
import 'package:earth_nova/features/map/presentation/presenters/encounter_presenter.dart';

void main() {
  group('EncounterPresenter', () {
    test('renders hash-backed species encounters as friendly names', () {
      const encounter = Encounter(
        type: EncounterType.species,
        speciesId: 'species_4f2a9c0d8b1e7a6f',
        cellId: 'v_22995_-33325',
        seed: 'seed',
      );

      final message = EncounterPresenter.message(encounter);

      expect(message, startsWith('You found a '));
      expect(message, isNot(contains('4f2a9c0d8b1e7a6f')));
      expect(message, isNot(contains('species_')));
    });

    test('preserves readable species ids as title-cased names', () {
      const encounter = Encounter(
        type: EncounterType.species,
        speciesId: 'species_red_fox',
        cellId: 'v_22995_-33325',
        seed: 'seed',
      );

      expect(EncounterPresenter.message(encounter), 'You found a Red Fox');
    });

    test('renders non-species encounter copy without raw ids', () {
      const critter = Encounter(
        type: EncounterType.critter,
        speciesId: 'species_abcdef',
        cellId: 'cell',
        seed: 'seed',
      );
      const loot = Encounter(
        type: EncounterType.loot,
        speciesId: 'species_abcdef',
        cellId: 'cell',
        seed: 'seed',
      );

      expect(EncounterPresenter.message(critter), 'A critter appeared');
      expect(EncounterPresenter.message(loot), 'You found supplies');
    });
  });
}
