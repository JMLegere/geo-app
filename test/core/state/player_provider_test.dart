import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/core/state/player_provider.dart';

void main() {
  group('PlayerNotifier', () {
    test('starts with all zeros', () {
      final container = ProviderContainer();
      final state = container.read(playerProvider);

      expect(state.currentStreak, equals(0));
      expect(state.longestStreak, equals(0));
      expect(state.totalDistanceKm, equals(0.0));
      expect(state.cellsObserved, equals(0));
    });

    test('incrementStreak increases current and updates longest', () {
      final container = ProviderContainer();
      final notifier = container.read(playerProvider.notifier);

      notifier.incrementStreak();
      notifier.incrementStreak();
      notifier.incrementStreak();

      final state = container.read(playerProvider);
      expect(state.currentStreak, equals(3));
      expect(state.longestStreak, equals(3));
    });

    test('incrementStreak updates longest when current exceeds it', () {
      final container = ProviderContainer();
      final notifier = container.read(playerProvider.notifier);

      notifier.incrementStreak();
      notifier.incrementStreak();
      notifier.resetStreak();
      notifier.incrementStreak();
      notifier.incrementStreak();
      notifier.incrementStreak();
      notifier.incrementStreak();

      final state = container.read(playerProvider);
      expect(state.currentStreak, equals(4));
      expect(state.longestStreak, equals(4));
    });

    test('resetStreak sets current to 0 but preserves longest', () {
      final container = ProviderContainer();
      final notifier = container.read(playerProvider.notifier);

      notifier.incrementStreak();
      notifier.incrementStreak();
      notifier.incrementStreak();
      notifier.resetStreak();

      final state = container.read(playerProvider);
      expect(state.currentStreak, equals(0));
      expect(state.longestStreak, equals(3));
    });

    test('addDistance accumulates correctly', () {
      final container = ProviderContainer();
      final notifier = container.read(playerProvider.notifier);

      notifier.addDistance(1.5);
      notifier.addDistance(2.3);
      notifier.addDistance(0.7);

      final state = container.read(playerProvider);
      expect(state.totalDistanceKm, closeTo(4.5, 0.01));
    });

    test('incrementCellsObserved increments counter', () {
      final container = ProviderContainer();
      final notifier = container.read(playerProvider.notifier);

      notifier.incrementCellsObserved();
      notifier.incrementCellsObserved();
      notifier.incrementCellsObserved();

      final state = container.read(playerProvider);
      expect(state.cellsObserved, equals(3));
    });

    test('all stats can be updated independently', () {
      final container = ProviderContainer();
      final notifier = container.read(playerProvider.notifier);

      notifier.incrementStreak();
      notifier.addDistance(5.0);
      notifier.incrementCellsObserved();

      final state = container.read(playerProvider);
      expect(state.currentStreak, equals(1));
      expect(state.totalDistanceKm, equals(5.0));
      expect(state.cellsObserved, equals(1));
    });
  });
}
