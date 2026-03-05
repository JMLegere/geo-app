import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/core/state/collection_provider.dart';

void main() {
  group('CollectionNotifier', () {
    test('starts with empty collection', () {
      final container = ProviderContainer();
      final state = container.read(collectionProvider);

      expect(state.collectedSpeciesIds, isEmpty);
      expect(state.totalCollected, equals(0));
    });

    test('addSpecies adds to list', () {
      final container = ProviderContainer();
      final notifier = container.read(collectionProvider.notifier);

      notifier.addSpecies('species1');

      final state = container.read(collectionProvider);
      expect(state.collectedSpeciesIds, contains('species1'));
      expect(state.totalCollected, equals(1));
    });

    test('removeSpecies removes from list', () {
      final container = ProviderContainer();
      final notifier = container.read(collectionProvider.notifier);

      notifier.addSpecies('species1');
      notifier.addSpecies('species2');
      notifier.removeSpecies('species1');

      final state = container.read(collectionProvider);
      expect(state.collectedSpeciesIds, isNot(contains('species1')));
      expect(state.collectedSpeciesIds, contains('species2'));
      expect(state.totalCollected, equals(1));
    });

    test('isCollected returns correct boolean', () {
      final container = ProviderContainer();
      final notifier = container.read(collectionProvider.notifier);

      notifier.addSpecies('species1');

      expect(notifier.isCollected('species1'), isTrue);
      expect(notifier.isCollected('species2'), isFalse);
    });

    test('adding duplicate species does not create duplicates', () {
      final container = ProviderContainer();
      final notifier = container.read(collectionProvider.notifier);

      notifier.addSpecies('species1');
      notifier.addSpecies('species1');
      notifier.addSpecies('species1');

      final state = container.read(collectionProvider);
      expect(state.totalCollected, equals(1));
      expect(
        state.collectedSpeciesIds.where((id) => id == 'species1').length,
        equals(1),
      );
    });

    test('multiple species can be added and removed', () {
      final container = ProviderContainer();
      final notifier = container.read(collectionProvider.notifier);

      notifier.addSpecies('species1');
      notifier.addSpecies('species2');
      notifier.addSpecies('species3');

      final state1 = container.read(collectionProvider);
      expect(state1.totalCollected, equals(3));

      notifier.removeSpecies('species2');

      final state2 = container.read(collectionProvider);
      expect(state2.totalCollected, equals(2));
      expect(state2.collectedSpeciesIds, containsAll(['species1', 'species3']));
    });
  });
}
