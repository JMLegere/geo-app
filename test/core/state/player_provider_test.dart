import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/state/player_provider.dart';

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

    test('addSteps accumulates total steps', () {
      final container = ProviderContainer();
      final notifier = container.read(playerProvider.notifier);

      notifier.addSteps(100);
      notifier.addSteps(250);
      notifier.addSteps(50);

      final state = container.read(playerProvider);
      expect(state.totalSteps, equals(400));
    });

    test('updateLastKnownStepCount stores OS baseline', () {
      final container = ProviderContainer();
      final notifier = container.read(playerProvider.notifier);

      notifier.updateLastKnownStepCount(12345);

      final state = container.read(playerProvider);
      expect(state.lastKnownStepCount, equals(12345));
    });

    test('loadProfile restores step fields when provided', () {
      final container = ProviderContainer();
      final notifier = container.read(playerProvider.notifier);

      notifier.loadProfile(
        cellsObserved: 10,
        totalDistanceKm: 5.0,
        currentStreak: 3,
        longestStreak: 7,
        totalSteps: 5000,
        lastKnownStepCount: 9999,
      );

      final state = container.read(playerProvider);
      expect(state.totalSteps, equals(5000));
      expect(state.lastKnownStepCount, equals(9999));
    });

    test('loadProfile defaults step fields to zero', () {
      final container = ProviderContainer();
      final notifier = container.read(playerProvider.notifier);

      notifier.loadProfile(
        cellsObserved: 10,
        totalDistanceKm: 5.0,
        currentStreak: 3,
        longestStreak: 7,
      );

      final state = container.read(playerProvider);
      expect(state.totalSteps, equals(0));
      expect(state.lastKnownStepCount, equals(0));
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

    group('spendSteps', () {
      test('returns true and reduces totalSteps when amount <= totalSteps', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(playerProvider.notifier);

        notifier.addSteps(1000);
        final result = notifier.spendSteps(500);

        expect(result, isTrue);
        final state = container.read(playerProvider);
        expect(state.totalSteps, equals(500));
      });

      test('returns false and does not mutate state when amount > totalSteps',
          () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(playerProvider.notifier);

        notifier.addSteps(499);
        final result = notifier.spendSteps(500);

        expect(result, isFalse);
        final state = container.read(playerProvider);
        expect(state.totalSteps, equals(499));
      });

      test('returns true when spending exact balance', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(playerProvider.notifier);

        notifier.addSteps(500);
        final result = notifier.spendSteps(500);

        expect(result, isTrue);
        final state = container.read(playerProvider);
        expect(state.totalSteps, equals(0));
      });

      test('returns false when spending zero', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(playerProvider.notifier);

        notifier.addSteps(1000);
        final result = notifier.spendSteps(0);

        expect(result, isFalse);
        final state = container.read(playerProvider);
        expect(state.totalSteps, equals(1000));
      });

      test('returns false when spending negative amount', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(playerProvider.notifier);

        notifier.addSteps(1000);
        final result = notifier.spendSteps(-100);

        expect(result, isFalse);
        final state = container.read(playerProvider);
        expect(state.totalSteps, equals(1000));
      });

      test('does not modify other PlayerState fields', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(playerProvider.notifier);

        notifier.addSteps(1000);
        notifier.incrementStreak();
        notifier.addDistance(5.0);
        notifier.incrementCellsObserved();

        notifier.spendSteps(500);

        final state = container.read(playerProvider);
        expect(state.currentStreak, equals(1));
        expect(state.totalDistanceKm, equals(5.0));
        expect(state.cellsObserved, equals(1));
        expect(state.totalSteps, equals(500));
      });
    });
  });
}
