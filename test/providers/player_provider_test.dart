import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/providers/player_provider.dart';

void main() {
  group('PlayerNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('initial state has zero stats and isHydrated=false', () {
      final state = container.read(playerProvider);
      expect(state.cellsObserved, 0);
      expect(state.speciesCollected, 0);
      expect(state.currentStreak, 0);
      expect(state.longestStreak, 0);
      expect(state.totalDistanceKm, 0.0);
      expect(state.isHydrated, isFalse);
    });

    test('loadProfile sets all provided fields', () {
      container.read(playerProvider.notifier).loadProfile(
            cellsObserved: 42,
            totalDistanceKm: 7.5,
            currentStreak: 3,
            longestStreak: 10,
            hasCompletedOnboarding: true,
            totalSteps: 1500,
            lastKnownStepCount: 500,
          );

      final state = container.read(playerProvider);
      expect(state.cellsObserved, 42);
      expect(state.totalDistanceKm, 7.5);
      expect(state.currentStreak, 3);
      expect(state.longestStreak, 10);
      expect(state.hasCompletedOnboarding, isTrue);
      expect(state.totalSteps, 1500);
      expect(state.lastKnownStepCount, 500);
    });

    test('markHydrated sets isHydrated to true', () {
      container.read(playerProvider.notifier).markHydrated();
      expect(container.read(playerProvider).isHydrated, isTrue);
    });

    test('incrementCellsObserved increases cellsObserved by 1', () {
      container.read(playerProvider.notifier).incrementCellsObserved();
      container.read(playerProvider.notifier).incrementCellsObserved();
      expect(container.read(playerProvider).cellsObserved, 2);
    });

    test('incrementSpeciesCollected increases speciesCollected by 1', () {
      container.read(playerProvider.notifier).incrementSpeciesCollected();
      expect(container.read(playerProvider).speciesCollected, 1);
    });

    test('addDistance adds to totalDistanceKm', () {
      container.read(playerProvider.notifier).addDistance(2.5);
      container.read(playerProvider.notifier).addDistance(1.5);
      expect(
          container.read(playerProvider).totalDistanceKm, closeTo(4.0, 0.0001));
    });

    test('updateStreak sets currentStreak and longestStreak', () {
      container.read(playerProvider.notifier).updateStreak(
            current: 5,
            longest: 12,
          );
      final state = container.read(playerProvider);
      expect(state.currentStreak, 5);
      expect(state.longestStreak, 12);
    });

    test('setUserId stores userId on state', () {
      container.read(playerProvider.notifier).setUserId('user_abc');
      expect(container.read(playerProvider).userId, 'user_abc');

      // Changing to a different ID works correctly.
      container.read(playerProvider.notifier).setUserId('user_xyz');
      expect(container.read(playerProvider).userId, 'user_xyz');
    });

    test('completeOnboarding sets hasCompletedOnboarding=true', () {
      container.read(playerProvider.notifier).completeOnboarding();
      expect(container.read(playerProvider).hasCompletedOnboarding, isTrue);
    });
  });
}
