import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/core/models/continent.dart';
import 'package:fog_of_world/core/models/habitat.dart';
import 'package:fog_of_world/core/models/iucn_status.dart';
import 'package:fog_of_world/core/models/species.dart';
import 'package:fog_of_world/core/species/species_service.dart';
import 'package:fog_of_world/core/state/collection_provider.dart';
import 'package:fog_of_world/features/discovery/providers/discovery_provider.dart';
import 'package:fog_of_world/features/pack/providers/pack_provider.dart';

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

final _forestLC = SpeciesRecord(
  commonName: 'Red Fox',
  scientificName: 'Vulpes vulpes',
  taxonomicClass: 'Mammalia',
  continents: [Continent.europe],
  habitats: [Habitat.forest],
  iucnStatus: IucnStatus.leastConcern,
);

final _plainsEN = SpeciesRecord(
  commonName: 'African Elephant',
  scientificName: 'Loxodonta africana',
  taxonomicClass: 'Mammalia',
  continents: [Continent.africa],
  habitats: [Habitat.plains],
  iucnStatus: IucnStatus.endangered,
);

final _mountainVU = SpeciesRecord(
  commonName: 'Snow Leopard',
  scientificName: 'Panthera uncia',
  taxonomicClass: 'Mammalia',
  continents: [Continent.asia],
  habitats: [Habitat.mountain],
  iucnStatus: IucnStatus.vulnerable,
);

final _testSpecies = [_forestLC, _plainsEN, _mountainVU];

// ---------------------------------------------------------------------------
// Container factory
// ---------------------------------------------------------------------------

ProviderContainer _makeContainer({List<SpeciesRecord>? species}) {
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
  group('PackState.filteredSpecies', () {
    test('initial state has all filters set to "all"', () {
      final container = _makeContainer();
      final state = container.read(packProvider);

      expect(state.habitatFilter, equals(HabitatFilter.all));
      expect(state.rarityFilter, equals(RarityFilter.all));
      expect(state.collectionFilter, equals(CollectionFilter.all));
    });

    test('initial filteredSpecies returns all species', () {
      final container = _makeContainer();
      final state = container.read(packProvider);

      expect(state.filteredSpecies.length, equals(_testSpecies.length));
    });

    test('setHabitatFilter(forest) returns only forest species', () {
      final container = _makeContainer();
      container
          .read(packProvider.notifier)
          .setHabitatFilter(HabitatFilter.forest);

      final filtered = container.read(packProvider).filteredSpecies;

      expect(filtered.length, equals(1));
      expect(filtered.first.commonName, equals('Red Fox'));
    });

    test('setHabitatFilter(plains) returns only plains species', () {
      final container = _makeContainer();
      container
          .read(packProvider.notifier)
          .setHabitatFilter(HabitatFilter.plains);

      final filtered = container.read(packProvider).filteredSpecies;

      expect(filtered.length, equals(1));
      expect(filtered.first.commonName, equals('African Elephant'));
    });

    test('setRarityFilter(endangered) returns only endangered species', () {
      final container = _makeContainer();
      container
          .read(packProvider.notifier)
          .setRarityFilter(RarityFilter.endangered);

      final filtered = container.read(packProvider).filteredSpecies;

      expect(filtered.length, equals(1));
      expect(filtered.first.commonName, equals('African Elephant'));
    });

    test('setRarityFilter(vulnerable) returns only vulnerable species', () {
      final container = _makeContainer();
      container
          .read(packProvider.notifier)
          .setRarityFilter(RarityFilter.vulnerable);

      final filtered = container.read(packProvider).filteredSpecies;

      expect(filtered.length, equals(1));
      expect(filtered.first.commonName, equals('Snow Leopard'));
    });

    test('setCollectionFilter(collected) shows only collected species', () {
      final container = _makeContainer();
      // Collect Red Fox only
      container.read(collectionProvider.notifier).addSpecies(_forestLC.id);

      container
          .read(packProvider.notifier)
          .setCollectionFilter(CollectionFilter.collected);

      final filtered = container.read(packProvider).filteredSpecies;

      expect(filtered.length, equals(1));
      expect(filtered.first.id, equals(_forestLC.id));
    });

    test('setCollectionFilter(undiscovered) shows only uncollected species',
        () {
      final container = _makeContainer();
      // Collect one species; the other two remain undiscovered
      container.read(collectionProvider.notifier).addSpecies(_forestLC.id);

      container
          .read(packProvider.notifier)
          .setCollectionFilter(CollectionFilter.undiscovered);

      final filtered = container.read(packProvider).filteredSpecies;

      expect(filtered.length, equals(2));
      expect(
        filtered.map((s) => s.id),
        isNot(contains(_forestLC.id)),
      );
    });

    test('multiple filters combine with AND logic', () {
      final container = _makeContainer();

      // Set forest + endangered — no species matches both
      container
          .read(packProvider.notifier)
          .setHabitatFilter(HabitatFilter.forest);
      container
          .read(packProvider.notifier)
          .setRarityFilter(RarityFilter.endangered);

      final filtered = container.read(packProvider).filteredSpecies;
      expect(filtered, isEmpty);
    });

    test('multiple filters combine: plains + endangered returns elephant', () {
      final container = _makeContainer();

      container
          .read(packProvider.notifier)
          .setHabitatFilter(HabitatFilter.plains);
      container
          .read(packProvider.notifier)
          .setRarityFilter(RarityFilter.endangered);

      final filtered = container.read(packProvider).filteredSpecies;
      expect(filtered.length, equals(1));
      expect(filtered.first.commonName, equals('African Elephant'));
    });

    test('filteredSpecies returns correct count after filter change', () {
      final container = _makeContainer();

      // Default — all 3
      expect(
        container.read(packProvider).filteredSpecies.length,
        equals(3),
      );

      // After habitat filter — only 1
      container
          .read(packProvider.notifier)
          .setHabitatFilter(HabitatFilter.mountain);
      expect(
        container.read(packProvider).filteredSpecies.length,
        equals(1),
      );
    });
  });

  group('PackState counts', () {
    test('totalCount reflects allSpecies length', () {
      final container = _makeContainer();
      expect(container.read(packProvider).totalCount, equals(3));
    });

    test('collectedCount reflects collectedIds', () {
      final container = _makeContainer();

      expect(container.read(packProvider).collectedCount, equals(0));

      container.read(collectionProvider.notifier).addSpecies(_forestLC.id);
      container.read(collectionProvider.notifier).addSpecies(_plainsEN.id);

      // Force the pack listener to fire by triggering a read
      // (listeners run synchronously in ProviderContainer in tests)
      container.read(packProvider);

      expect(container.read(packProvider).collectedCount, equals(2));
    });

    test('collectedCount starts at zero when collection is empty', () {
      final container = _makeContainer();
      expect(container.read(packProvider).collectedCount, equals(0));
    });
  });

  group('PackNotifier mutation methods', () {
    test('updateSpecies replaces the species list', () {
      final container = _makeContainer();
      final extra = SpeciesRecord(
        commonName: 'Jaguar',
        scientificName: 'Panthera onca',
        taxonomicClass: 'Mammalia',
        continents: [Continent.southAmerica],
        habitats: [Habitat.forest],
        iucnStatus: IucnStatus.nearThreatened,
      );

      container.read(packProvider.notifier).updateSpecies([extra]);
      expect(container.read(packProvider).allSpecies.length, equals(1));
      expect(
        container.read(packProvider).allSpecies.first.commonName,
        equals('Jaguar'),
      );
    });

    test('updateCollectedIds replaces collected set', () {
      final container = _makeContainer();

      container
          .read(packProvider.notifier)
          .updateCollectedIds({_forestLC.id, _plainsEN.id});

      expect(container.read(packProvider).collectedIds.length, equals(2));
      expect(
        container.read(packProvider).collectedIds,
        containsAll([_forestLC.id, _plainsEN.id]),
      );
    });

    test('filter methods preserve other filter state', () {
      final container = _makeContainer();
      final notifier = container.read(packProvider.notifier);

      notifier.setHabitatFilter(HabitatFilter.forest);
      notifier.setRarityFilter(RarityFilter.leastConcern);

      // Change only collection filter
      notifier.setCollectionFilter(CollectionFilter.undiscovered);

      final state = container.read(packProvider);
      expect(state.habitatFilter, equals(HabitatFilter.forest));
      expect(state.rarityFilter, equals(RarityFilter.leastConcern));
      expect(state.collectionFilter, equals(CollectionFilter.undiscovered));
    });
  });
}
