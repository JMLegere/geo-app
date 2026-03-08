import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/models/fog_state.dart';
import 'package:earth_nova/core/state/fog_provider.dart';

void main() {
  group('FogNotifier', () {
    test('starts with empty map', () {
      final container = ProviderContainer();
      final state = container.read(fogProvider);

      expect(state, isEmpty);
    });

    test('updateCellFogState sets state correctly', () {
      final container = ProviderContainer();
      final notifier = container.read(fogProvider.notifier);

      notifier.updateCellFogState('cell1', FogState.unexplored);

      final state = container.read(fogProvider);
      expect(state['cell1'], equals(FogState.unexplored));
    });

    test('forward transitions succeed', () {
      final container = ProviderContainer();
      final notifier = container.read(fogProvider.notifier);

      notifier.updateCellFogState('cell1', FogState.undetected);
      notifier.updateCellFogState('cell1', FogState.unexplored);
      notifier.updateCellFogState('cell1', FogState.hidden);
      notifier.updateCellFogState('cell1', FogState.concealed);
      notifier.updateCellFogState('cell1', FogState.observed);

      final state = container.read(fogProvider);
      expect(state['cell1'], equals(FogState.observed));
    });

    test('any state update is accepted (computed model has no forward-only constraint)',
        () {
      final container = ProviderContainer();
      final notifier = container.read(fogProvider.notifier);

      notifier.updateCellFogState('cell1', FogState.observed);
      // In the computed model, states are not forward-only — any update is valid.
      notifier.updateCellFogState('cell1', FogState.hidden);

      final state = container.read(fogProvider);
      expect(state['cell1'], equals(FogState.hidden));
    });

    test('getCellFogState returns undetected for unknown cell', () {
      final container = ProviderContainer();
      final notifier = container.read(fogProvider.notifier);

      final state = notifier.getCellFogState('unknown_cell');

      expect(state, equals(FogState.undetected));
    });

    test('getCellFogState returns correct state for known cell', () {
      final container = ProviderContainer();
      final notifier = container.read(fogProvider.notifier);

      notifier.updateCellFogState('cell1', FogState.undetected);
      notifier.updateCellFogState('cell1', FogState.unexplored);
      notifier.updateCellFogState('cell1', FogState.hidden);

      final state = notifier.getCellFogState('cell1');

      expect(state, equals(FogState.hidden));
    });

    test('multiple cells can have different states', () {
      final container = ProviderContainer();
      final notifier = container.read(fogProvider.notifier);

      notifier.updateCellFogState('cell1', FogState.undetected);
      notifier.updateCellFogState('cell1', FogState.unexplored);

      notifier.updateCellFogState('cell2', FogState.undetected);
      notifier.updateCellFogState('cell2', FogState.unexplored);
      notifier.updateCellFogState('cell2', FogState.hidden);

      notifier.updateCellFogState('cell3', FogState.undetected);
      notifier.updateCellFogState('cell3', FogState.unexplored);
      notifier.updateCellFogState('cell3', FogState.hidden);
      notifier.updateCellFogState('cell3', FogState.concealed);
      notifier.updateCellFogState('cell3', FogState.observed);

      final state = container.read(fogProvider);

      expect(state['cell1'], equals(FogState.unexplored));
      expect(state['cell2'], equals(FogState.hidden));
      expect(state['cell3'], equals(FogState.observed));
    });
  });
}
