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

      notifier.updateCellFogState('cell1', FogState.detected);

      final state = container.read(fogProvider);
      expect(state['cell1'], equals(FogState.detected));
    });

    test('forward transitions succeed', () {
      final container = ProviderContainer();
      final notifier = container.read(fogProvider.notifier);

      notifier.updateCellFogState('cell1', FogState.unknown);
      notifier.updateCellFogState('cell1', FogState.detected);
      notifier.updateCellFogState('cell1', FogState.visited);
      notifier.updateCellFogState('cell1', FogState.nearby);
      notifier.updateCellFogState('cell1', FogState.active);

      final state = container.read(fogProvider);
      expect(state['cell1'], equals(FogState.active));
    });

    test('any state update is accepted (computed model has no forward-only constraint)',
        () {
      final container = ProviderContainer();
      final notifier = container.read(fogProvider.notifier);

      notifier.updateCellFogState('cell1', FogState.active);
      // In the computed model, states are not forward-only — any update is valid.
      notifier.updateCellFogState('cell1', FogState.visited);

      final state = container.read(fogProvider);
      expect(state['cell1'], equals(FogState.visited));
    });

    test('getCellFogState returns undetected for unknown cell', () {
      final container = ProviderContainer();
      final notifier = container.read(fogProvider.notifier);

      final state = notifier.getCellFogState('unknown_cell');

      expect(state, equals(FogState.unknown));
    });

    test('getCellFogState returns correct state for known cell', () {
      final container = ProviderContainer();
      final notifier = container.read(fogProvider.notifier);

      notifier.updateCellFogState('cell1', FogState.unknown);
      notifier.updateCellFogState('cell1', FogState.detected);
      notifier.updateCellFogState('cell1', FogState.visited);

      final state = notifier.getCellFogState('cell1');

      expect(state, equals(FogState.visited));
    });

    test('multiple cells can have different states', () {
      final container = ProviderContainer();
      final notifier = container.read(fogProvider.notifier);

      notifier.updateCellFogState('cell1', FogState.unknown);
      notifier.updateCellFogState('cell1', FogState.detected);

      notifier.updateCellFogState('cell2', FogState.unknown);
      notifier.updateCellFogState('cell2', FogState.detected);
      notifier.updateCellFogState('cell2', FogState.visited);

      notifier.updateCellFogState('cell3', FogState.unknown);
      notifier.updateCellFogState('cell3', FogState.detected);
      notifier.updateCellFogState('cell3', FogState.visited);
      notifier.updateCellFogState('cell3', FogState.nearby);
      notifier.updateCellFogState('cell3', FogState.active);

      final state = container.read(fogProvider);

      expect(state['cell1'], equals(FogState.detected));
      expect(state['cell2'], equals(FogState.visited));
      expect(state['cell3'], equals(FogState.active));
    });
  });
}
