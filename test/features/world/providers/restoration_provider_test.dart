import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/world/providers/restoration_provider.dart';

void main() {
  group('RestorationNotifier', () {
    // -------------------------------------------------------------------------
    // Initial state
    // -------------------------------------------------------------------------

    test('initial state has empty levels', () {
      final container = ProviderContainer();
      final state = container.read(restorationProvider);
      expect(state.levels, isEmpty);
    });

    test('initial state has empty cellSpecies', () {
      final container = ProviderContainer();
      final state = container.read(restorationProvider);
      expect(state.cellSpecies, isEmpty);
    });

    // -------------------------------------------------------------------------
    // recordCollection
    // -------------------------------------------------------------------------

    test('recordCollection updates level for cell', () {
      final container = ProviderContainer();
      container.read(restorationProvider.notifier).recordCollection(
            'cell1',
            'sp1',
          );
      final state = container.read(restorationProvider);
      expect(state.levels['cell1'], closeTo(1 / 3, 0.001));
    });

    test('recordCollection with 3 unique species yields exactly 1.0', () {
      final container = ProviderContainer();
      final notifier = container.read(restorationProvider.notifier);
      notifier.recordCollection('cell1', 'sp1');
      notifier.recordCollection('cell1', 'sp2');
      notifier.recordCollection('cell1', 'sp3');
      expect(container.read(restorationProvider).levels['cell1'], equals(1.0));
    });

    test('recording same species twice does not change level', () {
      final container = ProviderContainer();
      final notifier = container.read(restorationProvider.notifier);
      notifier.recordCollection('cell1', 'sp1');
      notifier.recordCollection('cell1', 'sp1');
      expect(
        container.read(restorationProvider).levels['cell1'],
        closeTo(1 / 3, 0.001),
      );
    });

    // -------------------------------------------------------------------------
    // getLevel
    // -------------------------------------------------------------------------

    test('getLevel returns 0.0 for unknown cell', () {
      final container = ProviderContainer();
      final notifier = container.read(restorationProvider.notifier);
      expect(notifier.getLevel('unknown'), equals(0.0));
    });

    test('getLevel returns correct level after collection', () {
      final container = ProviderContainer();
      final notifier = container.read(restorationProvider.notifier);
      notifier.recordCollection('cell1', 'sp1');
      notifier.recordCollection('cell1', 'sp2');
      expect(notifier.getLevel('cell1'), closeTo(2 / 3, 0.001));
    });

    // -------------------------------------------------------------------------
    // isRestored
    // -------------------------------------------------------------------------

    test('isRestored returns false before full restoration', () {
      final container = ProviderContainer();
      final notifier = container.read(restorationProvider.notifier);
      notifier.recordCollection('cell1', 'sp1');
      expect(notifier.isRestored('cell1'), isFalse);
    });

    test('isRestored returns true when fully restored', () {
      final container = ProviderContainer();
      final notifier = container.read(restorationProvider.notifier);
      notifier.recordCollection('cell1', 'sp1');
      notifier.recordCollection('cell1', 'sp2');
      notifier.recordCollection('cell1', 'sp3');
      expect(notifier.isRestored('cell1'), isTrue);
    });

    // -------------------------------------------------------------------------
    // Multiple cells
    // -------------------------------------------------------------------------

    test('multiple cells are tracked independently', () {
      final container = ProviderContainer();
      final notifier = container.read(restorationProvider.notifier);
      notifier.recordCollection('cell1', 'sp1');
      notifier.recordCollection('cell2', 'sp1');
      notifier.recordCollection('cell2', 'sp2');

      final state = container.read(restorationProvider);
      expect(state.levels['cell1'], closeTo(1 / 3, 0.001));
      expect(state.levels['cell2'], closeTo(2 / 3, 0.001));
    });

    test('same species id in different cells counts independently', () {
      final container = ProviderContainer();
      final notifier = container.read(restorationProvider.notifier);
      // sp1 collected in both cells — each cell should gain its own level
      notifier.recordCollection('cell1', 'sp1');
      notifier.recordCollection('cell2', 'sp1');

      final state = container.read(restorationProvider);
      expect(state.levels['cell1'], closeTo(1 / 3, 0.001));
      expect(state.levels['cell2'], closeTo(1 / 3, 0.001));
    });

    test('state updates do not mutate previous state objects', () {
      final container = ProviderContainer();
      final notifier = container.read(restorationProvider.notifier);

      notifier.recordCollection('cell1', 'sp1');
      final stateAfterFirst = container.read(restorationProvider);

      notifier.recordCollection('cell1', 'sp2');
      final stateAfterSecond = container.read(restorationProvider);

      // First captured state should not reflect the second collection.
      expect(stateAfterFirst.levels['cell1'], closeTo(1 / 3, 0.001));
      expect(stateAfterSecond.levels['cell1'], closeTo(2 / 3, 0.001));
    });
  });
}
