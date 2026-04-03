import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/engine/game_event.dart';
import 'package:earth_nova/providers/discovery_provider.dart';

GameEvent _makeDiscoveryEvent({String displayName = 'Red Fox'}) =>
    GameEvent.speciesDiscovered(
      sessionId: 'sess_1',
      cellId: 'v_1',
      definitionId: 'def_1',
      displayName: displayName,
      category: 'fauna',
      rarity: 'leastConcern',
      dailySeed: 'seed_abc',
      cellEventType: null,
      instance: null,
      hasEnrichment: false,
      affixCount: 0,
    );

void main() {
  group('DiscoveryNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('initial toast queue is empty', () {
      expect(container.read(discoveryProvider).toastQueue, isEmpty);
      expect(container.read(discoveryProvider).activeToast, isNull);
    });

    test('enqueueToast adds event to queue', () {
      final event = _makeDiscoveryEvent();
      container.read(discoveryProvider.notifier).enqueueToast(event);

      final queue = container.read(discoveryProvider).toastQueue;
      expect(queue.length, 1);
      expect(queue.first.data['display_name'], 'Red Fox');
    });

    test('dismissToast removes the first item from the queue', () {
      container.read(discoveryProvider.notifier)
        ..enqueueToast(_makeDiscoveryEvent(displayName: 'Fox'))
        ..enqueueToast(_makeDiscoveryEvent(displayName: 'Bear'));

      container.read(discoveryProvider.notifier).dismissToast();

      final queue = container.read(discoveryProvider).toastQueue;
      expect(queue.length, 1);
      expect(queue.first.data['display_name'], 'Bear');
    });

    test('multiple toasts queue in insertion order', () {
      final names = ['Ant', 'Bee', 'Cat'];
      for (final name in names) {
        container
            .read(discoveryProvider.notifier)
            .enqueueToast(_makeDiscoveryEvent(displayName: name));
      }

      final queue = container.read(discoveryProvider).toastQueue;
      expect(queue.map((e) => e.data['display_name']).toList(), names);
    });

    test('dismissToast on empty queue is a no-op', () {
      // Should not throw.
      expect(
        () => container.read(discoveryProvider.notifier).dismissToast(),
        returnsNormally,
      );
      expect(container.read(discoveryProvider).toastQueue, isEmpty);
    });

    test('clearAll removes all queued toasts', () {
      for (var i = 0; i < 3; i++) {
        container
            .read(discoveryProvider.notifier)
            .enqueueToast(_makeDiscoveryEvent());
      }
      container.read(discoveryProvider.notifier).clearAll();
      expect(container.read(discoveryProvider).toastQueue, isEmpty);
    });
  });
}
