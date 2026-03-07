import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fog_of_world/core/models/continent.dart';
import 'package:fog_of_world/core/models/habitat.dart';
import 'package:fog_of_world/core/models/iucn_status.dart';
import 'package:fog_of_world/core/models/item_definition.dart';
import 'package:fog_of_world/core/models/discovery_event.dart';
import 'package:fog_of_world/core/species/species_data_loader.dart';
import 'package:fog_of_world/core/species/species_service.dart';
import 'package:fog_of_world/features/discovery/providers/discovery_provider.dart';

import '../../../fixtures/species_fixture.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

DiscoveryEvent _makeEvent({
  String cellId = 'cell_1',
  bool isNew = true,
  DateTime? timestamp,
}) {
  return DiscoveryEvent(
    item: FaunaDefinition(
      id: 'fauna_vulpes_vulpes',
      displayName: 'Red Fox',
      scientificName: 'Vulpes vulpes',
      taxonomicClass: 'Mammalia',
      continents: [Continent.northAmerica],
      habitats: [Habitat.forest],
      rarity: IucnStatus.leastConcern,
    ),
    cellId: cellId,
    isNew: isNew,
    timestamp: timestamp ?? DateTime(2026, 3, 2),
  );
}

ProviderContainer _makeContainer() {
  final container = ProviderContainer();
  return container;
}

void main() {
  group('DiscoveryNotifier', () {
    test('builds with empty initial state', () {
      final container = _makeContainer();
      addTearDown(container.dispose);

      final state = container.read(discoveryProvider);

      expect(state.recentDiscoveries, isEmpty);
      expect(state.hasActiveNotification, isFalse);
      expect(state.currentNotification, isNull);
    });

    test('showDiscovery sets currentNotification', () {
      final container = _makeContainer();
      addTearDown(container.dispose);

      final event = _makeEvent();
      container.read(discoveryProvider.notifier).showDiscovery(event);

      final state = container.read(discoveryProvider);
      expect(state.currentNotification, equals(event));
    });

    test('showDiscovery sets hasActiveNotification to true', () {
      final container = _makeContainer();
      addTearDown(container.dispose);

      container.read(discoveryProvider.notifier).showDiscovery(_makeEvent());

      expect(
        container.read(discoveryProvider).hasActiveNotification,
        isTrue,
      );
    });

    test('showDiscovery adds event to recentDiscoveries', () {
      final container = _makeContainer();
      addTearDown(container.dispose);

      final event = _makeEvent();
      container.read(discoveryProvider.notifier).showDiscovery(event);

      expect(
        container.read(discoveryProvider).recentDiscoveries,
        contains(event),
      );
    });

    test('showDiscovery prepends events (newest first)', () {
      final container = _makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(discoveryProvider.notifier);
      final first = _makeEvent(cellId: 'cell_1');
      final second = _makeEvent(cellId: 'cell_2');

      notifier.showDiscovery(first);
      notifier.showDiscovery(second);

      final discoveries =
          container.read(discoveryProvider).recentDiscoveries;
      expect(discoveries.first, equals(second));
      expect(discoveries[1], equals(first));
    });

    test('recentDiscoveries is capped at 20 entries', () {
      final container = _makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(discoveryProvider.notifier);

      for (var i = 0; i < 25; i++) {
        notifier.showDiscovery(_makeEvent(cellId: 'cell_$i'));
      }

      expect(
        container.read(discoveryProvider).recentDiscoveries.length,
        equals(20),
      );
    });

    test('dismissNotification clears currentNotification', () {
      final container = _makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(discoveryProvider.notifier);
      notifier.showDiscovery(_makeEvent());
      notifier.dismissNotification();

      expect(
        container.read(discoveryProvider).currentNotification,
        isNull,
      );
    });

    test('dismissNotification sets hasActiveNotification to false', () {
      final container = _makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(discoveryProvider.notifier);
      notifier.showDiscovery(_makeEvent());
      notifier.dismissNotification();

      expect(
        container.read(discoveryProvider).hasActiveNotification,
        isFalse,
      );
    });

    test('dismissNotification preserves recentDiscoveries', () {
      final container = _makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(discoveryProvider.notifier);
      final event = _makeEvent();
      notifier.showDiscovery(event);
      notifier.dismissNotification();

      expect(
        container.read(discoveryProvider).recentDiscoveries,
        contains(event),
      );
    });

    test('clearHistory resets state to initial', () {
      final container = _makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(discoveryProvider.notifier);
      notifier.showDiscovery(_makeEvent());
      notifier.showDiscovery(_makeEvent(cellId: 'cell_2'));
      notifier.clearHistory();

      final state = container.read(discoveryProvider);
      expect(state.recentDiscoveries, isEmpty);
      expect(state.hasActiveNotification, isFalse);
      expect(state.currentNotification, isNull);
    });
  });

  group('DiscoveryState.copyWith', () {
    test('clearCurrentNotification sets currentNotification to null', () {
      final state = DiscoveryState(
        currentNotification: _makeEvent(),
        hasActiveNotification: true,
      );

      final updated = state.copyWith(
        hasActiveNotification: false,
        clearCurrentNotification: true,
      );

      expect(updated.currentNotification, isNull);
      expect(updated.hasActiveNotification, isFalse);
    });

    test('preserves unchanged fields', () {
      final event = _makeEvent();
      final state = DiscoveryState(
        recentDiscoveries: [event],
        hasActiveNotification: true,
        currentNotification: event,
      );

      final updated = state.copyWith();

      expect(updated.recentDiscoveries, equals([event]));
      expect(updated.hasActiveNotification, isTrue);
      expect(updated.currentNotification, equals(event));
    });
  });

  group('speciesServiceProvider', () {
    ProviderContainer makeSpeciesContainer() {
      return ProviderContainer(
        overrides: [
          speciesServiceProvider.overrideWithValue(
            SpeciesService(SpeciesDataLoader.fromJsonString(kSpeciesFixtureJson)),
          ),
        ],
      );
    }

    test('provides a SpeciesService with non-empty records', () {
      final container = makeSpeciesContainer();
      addTearDown(container.dispose);

      final service = container.read(speciesServiceProvider);
      expect(service.totalSpecies, greaterThan(0));
    });

    test('can find species for Forest + NorthAmerica', () {
      final container = makeSpeciesContainer();
      addTearDown(container.dispose);

      final service = container.read(speciesServiceProvider);
      final species = service.getSpeciesForCell(
        cellId: 'test_cell',
        habitats: {Habitat.forest},
        continent: Continent.northAmerica,
      );

      expect(species, isNotEmpty);
    });
  });
}
