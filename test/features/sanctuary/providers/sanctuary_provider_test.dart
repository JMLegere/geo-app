import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/models/iucn_status.dart';
import 'package:earth_nova/core/models/item_definition.dart';
import 'package:earth_nova/core/models/item_instance.dart';
import 'package:earth_nova/core/species/species_service.dart';
import 'package:earth_nova/core/state/inventory_provider.dart';
import 'package:earth_nova/core/state/player_provider.dart';
import 'package:earth_nova/features/discovery/providers/discovery_provider.dart';
import 'package:earth_nova/features/sanctuary/providers/sanctuary_provider.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _forestFox = FaunaDefinition(
  id: 'fauna_vulpes_vulpes',
  displayName: 'Red Fox',
  scientificName: 'Vulpes vulpes',
  taxonomicClass: 'Mammalia',
  continents: [Continent.europe],
  habitats: [Habitat.forest],
  rarity: IucnStatus.leastConcern,
);

final _forestBear = FaunaDefinition(
  id: 'fauna_ursus_arctos_horribilis',
  displayName: 'Grizzly Bear',
  scientificName: 'Ursus arctos horribilis',
  taxonomicClass: 'Mammalia',
  continents: [Continent.northAmerica],
  habitats: [Habitat.forest],
  rarity: IucnStatus.leastConcern,
);

final _plainsElephant = FaunaDefinition(
  id: 'fauna_loxodonta_africana',
  displayName: 'African Elephant',
  scientificName: 'Loxodonta africana',
  taxonomicClass: 'Mammalia',
  continents: [Continent.africa],
  habitats: [Habitat.plains],
  rarity: IucnStatus.endangered,
);

final _mountainLeopard = FaunaDefinition(
  id: 'fauna_panthera_uncia',
  displayName: 'Snow Leopard',
  scientificName: 'Panthera uncia',
  taxonomicClass: 'Mammalia',
  continents: [Continent.asia],
  habitats: [Habitat.mountain],
  rarity: IucnStatus.vulnerable,
);

final _testSpecies = [
  _forestFox,
  _forestBear,
  _plainsElephant,
  _mountainLeopard,
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Add a species to inventory by definition ID.
void _addSpecies(ProviderContainer container, FaunaDefinition species) {
  container.read(inventoryProvider.notifier).addItem(ItemInstance(
        id: 'test_${species.id}',
        definitionId: species.id,
        acquiredAt: DateTime.now(),
        acquiredInCellId: 'cell_1',
      ));
}

// ---------------------------------------------------------------------------
// Container factory
// ---------------------------------------------------------------------------

ProviderContainer _makeContainer({List<FaunaDefinition>? species}) {
  final records = species ?? _testSpecies;
  final container = ProviderContainer(
    overrides: [
      speciesServiceProvider.overrideWith((_) => SpeciesService(records)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SanctuaryState — initial state', () {
    test('speciesByHabitat is empty when no species collected', () {
      final container = _makeContainer();
      final state = container.read(sanctuaryProvider);

      expect(state.speciesByHabitat, isEmpty);
    });

    test('totalCollected is 0 when collection is empty', () {
      final container = _makeContainer();
      final state = container.read(sanctuaryProvider);

      expect(state.totalCollected, equals(0));
    });

    test('totalInPool equals the full species dataset size', () {
      final container = _makeContainer();
      final state = container.read(sanctuaryProvider);

      expect(state.totalInPool, equals(_testSpecies.length));
    });

    test('healthPercentage is 0.0 when nothing collected', () {
      final container = _makeContainer();
      final state = container.read(sanctuaryProvider);

      expect(state.healthPercentage, equals(0.0));
    });

    test('currentStreak defaults to 0', () {
      final container = _makeContainer();
      final state = container.read(sanctuaryProvider);

      expect(state.currentStreak, equals(0));
    });
  });

  group('SanctuaryState — grouping by habitat', () {
    test('collected forest species appear under Habitat.forest', () {
      final container = _makeContainer();
      _addSpecies(container, _forestFox);
      _addSpecies(container, _forestBear);

      final state = container.read(sanctuaryProvider);

      expect(state.speciesByHabitat[Habitat.forest], isNotNull);
      expect(state.speciesByHabitat[Habitat.forest]!.length, equals(2));
    });

    test('collected plains species appear under Habitat.plains', () {
      final container = _makeContainer();
      _addSpecies(container, _plainsElephant);

      final state = container.read(sanctuaryProvider);

      expect(state.speciesByHabitat[Habitat.plains], isNotNull);
      expect(state.speciesByHabitat[Habitat.plains]!.first.id,
          equals(_plainsElephant.id));
    });

    test('uncollected habitats are absent from speciesByHabitat', () {
      final container = _makeContainer();
      _addSpecies(container, _forestFox);

      final state = container.read(sanctuaryProvider);

      expect(state.speciesByHabitat.containsKey(Habitat.plains), isFalse);
      expect(state.speciesByHabitat.containsKey(Habitat.mountain), isFalse);
    });

    test('species grouped correctly across different habitats', () {
      final container = _makeContainer();
      _addSpecies(container, _forestFox);
      _addSpecies(container, _plainsElephant);
      _addSpecies(container, _mountainLeopard);

      final state = container.read(sanctuaryProvider);

      expect(state.speciesByHabitat.keys,
          containsAll([Habitat.forest, Habitat.plains, Habitat.mountain]));
      expect(state.speciesByHabitat[Habitat.forest]!.length, equals(1));
      expect(state.speciesByHabitat[Habitat.plains]!.length, equals(1));
      expect(state.speciesByHabitat[Habitat.mountain]!.length, equals(1));
    });
  });

  group('SanctuaryState — health percentage', () {
    test('2 out of 4 collected → healthPercentage = 0.5', () {
      final container = _makeContainer();
      _addSpecies(container, _forestFox);
      _addSpecies(container, _plainsElephant);

      final state = container.read(sanctuaryProvider);

      expect(state.healthPercentage, closeTo(0.5, 0.001));
    });

    test('1 out of 5 collected → healthPercentage = 0.2', () {
      // Use a 5-species pool
      final fiveSpecies = [
        ..._testSpecies,
        FaunaDefinition(
          id: 'fauna_panthera_onca',
          displayName: 'Jaguar',
          scientificName: 'Panthera onca',
          taxonomicClass: 'Mammalia',
          continents: [Continent.southAmerica],
          habitats: [Habitat.forest],
          rarity: IucnStatus.nearThreatened,
        ),
      ];
      final container = _makeContainer(species: fiveSpecies);
      _addSpecies(container, _forestFox);

      final state = container.read(sanctuaryProvider);

      expect(state.healthPercentage, closeTo(0.2, 0.001));
    });

    test('healthPercentage is 0.0 when totalInPool is 0', () {
      final container = _makeContainer(species: []);
      final state = container.read(sanctuaryProvider);

      expect(state.healthPercentage, equals(0.0));
    });

    test('all species collected → healthPercentage = 1.0', () {
      final container = _makeContainer();
      for (final s in _testSpecies) {
        _addSpecies(container, s);
      }

      final state = container.read(sanctuaryProvider);

      expect(state.healthPercentage, closeTo(1.0, 0.001));
    });
  });

  group('SanctuaryState — streak', () {
    test('reflects player streak when incremented', () {
      final container = _makeContainer();
      container.read(playerProvider.notifier).incrementStreak();
      container.read(playerProvider.notifier).incrementStreak();

      final state = container.read(sanctuaryProvider);

      expect(state.currentStreak, equals(2));
    });

    test('streak resets when player streak is reset', () {
      final container = _makeContainer();
      container.read(playerProvider.notifier).incrementStreak();
      container.read(playerProvider.notifier).resetStreak();

      final state = container.read(sanctuaryProvider);

      expect(state.currentStreak, equals(0));
    });
  });
}
