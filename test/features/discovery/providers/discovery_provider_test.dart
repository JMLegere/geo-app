import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/models/iucn_status.dart';
import 'package:earth_nova/core/models/item_definition.dart';
import 'package:earth_nova/core/models/discovery_event.dart';
import 'package:earth_nova/core/species/species_service.dart';
import 'package:earth_nova/features/discovery/providers/discovery_provider.dart';

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

      final discoveries = container.read(discoveryProvider).recentDiscoveries;
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

    test('dismissNotification clears currentNotification when single item', () {
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

    test(
        'dismissNotification sets hasActiveNotification to false when single item',
        () {
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

    test('dismissNotification promotes next item to top', () {
      final container = _makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(discoveryProvider.notifier);
      final first = _makeEvent(cellId: 'cell_1');
      final second = _makeEvent(cellId: 'cell_2');
      final third = _makeEvent(cellId: 'cell_3');

      notifier.showDiscovery(first);
      notifier.showDiscovery(second);
      notifier.showDiscovery(third);

      // Top of queue should be the first one added (FIFO).
      expect(container.read(discoveryProvider).currentNotification, first);

      notifier.dismissNotification();
      expect(container.read(discoveryProvider).currentNotification, second);
      expect(container.read(discoveryProvider).hasActiveNotification, isTrue);

      notifier.dismissNotification();
      expect(container.read(discoveryProvider).currentNotification, third);

      notifier.dismissNotification();
      expect(container.read(discoveryProvider).currentNotification, isNull);
      expect(container.read(discoveryProvider).hasActiveNotification, isFalse);
    });

    test('notificationQueue is capped at kMaxNotificationQueue', () {
      final container = _makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(discoveryProvider.notifier);

      for (var i = 0; i < kMaxNotificationQueue + 5; i++) {
        notifier.showDiscovery(_makeEvent(cellId: 'cell_$i'));
      }

      expect(
        container.read(discoveryProvider).notificationQueue.length,
        equals(kMaxNotificationQueue),
      );
    });

    test('dismissNotification is no-op when queue is empty', () {
      final container = _makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(discoveryProvider.notifier);
      // Should not throw.
      notifier.dismissNotification();

      expect(container.read(discoveryProvider).hasActiveNotification, isFalse);
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
    test('empty notificationQueue yields null currentNotification', () {
      const state = DiscoveryState();

      expect(state.currentNotification, isNull);
      expect(state.hasActiveNotification, isFalse);
    });

    test('notificationQueue yields first item as currentNotification', () {
      final event = _makeEvent();
      final state = DiscoveryState(
        notificationQueue: [event],
      );

      expect(state.currentNotification, equals(event));
      expect(state.hasActiveNotification, isTrue);
    });

    test('preserves unchanged fields', () {
      final event = _makeEvent();
      final state = DiscoveryState(
        recentDiscoveries: [event],
        notificationQueue: [event],
      );

      final updated = state.copyWith();

      expect(updated.recentDiscoveries, equals([event]));
      expect(updated.notificationQueue, equals([event]));
      expect(updated.hasActiveNotification, isTrue);
      expect(updated.currentNotification, equals(event));
    });

    test('replacing notificationQueue updates derived getters', () {
      final event = _makeEvent();
      final state = DiscoveryState(
        notificationQueue: [event],
      );

      final updated = state.copyWith(notificationQueue: []);

      expect(updated.hasActiveNotification, isFalse);
      expect(updated.currentNotification, isNull);
    });
  });

  group('speciesServiceProvider', () {
    ProviderContainer makeSpeciesContainer() {
      return ProviderContainer(
        overrides: [
          speciesServiceProvider.overrideWithValue(
            SpeciesService(
              (jsonDecode(kSpeciesFixtureJson) as List)
                  .map((e) =>
                      FaunaDefinition.fromJson(e as Map<String, dynamic>))
                  .where((d) => d.rarity != null)
                  .toList(),
            ),
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
        dailySeed: 'test_seed',
        habitats: {Habitat.forest},
        continent: Continent.northAmerica,
      );

      expect(species, isNotEmpty);
    });
  });
}
