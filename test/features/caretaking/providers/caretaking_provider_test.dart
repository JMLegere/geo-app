import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/core/state/player_provider.dart';
import 'package:fog_of_world/features/caretaking/models/caretaking_state.dart';
import 'package:fog_of_world/features/caretaking/providers/caretaking_provider.dart';

void main() {
  group('CaretakingNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is empty', () {
      final state = container.read(caretakingProvider);

      expect(state.lastVisitDate, isNull);
      expect(state.currentStreak, 0);
      expect(state.longestStreak, 0);
    });

    test('recordVisit updates state correctly', () {
      final notifier = container.read(caretakingProvider.notifier);
      final now = DateTime(2024, 3, 1);

      notifier.recordVisit(now: now);

      final state = container.read(caretakingProvider);
      expect(state.lastVisitDate, DateTime(2024, 3, 1));
      expect(state.currentStreak, 1);
      expect(state.longestStreak, 1);
    });

    test('recordVisit syncs with playerProvider', () {
      final notifier = container.read(caretakingProvider.notifier);
      final now = DateTime(2024, 3, 1);

      notifier.recordVisit(now: now);

      final playerState = container.read(playerProvider);
      expect(playerState.currentStreak, 1);
      expect(playerState.longestStreak, 1);
    });

    test('consecutive recordVisit calls increment streak', () {
      final notifier = container.read(caretakingProvider.notifier);

      notifier.recordVisit(now: DateTime(2024, 3, 1));
      notifier.recordVisit(now: DateTime(2024, 3, 2));
      notifier.recordVisit(now: DateTime(2024, 3, 3));

      final state = container.read(caretakingProvider);
      expect(state.currentStreak, 3);
      expect(state.longestStreak, 3);

      final playerState = container.read(playerProvider);
      expect(playerState.currentStreak, 3);
      expect(playerState.longestStreak, 3);
    });

    test('same-day recordVisit is no-op', () {
      final notifier = container.read(caretakingProvider.notifier);
      final now = DateTime(2024, 3, 1, 10, 0);

      notifier.recordVisit(now: now);
      final stateAfterFirst = container.read(caretakingProvider);

      notifier.recordVisit(now: DateTime(2024, 3, 1, 15, 30));
      final stateAfterSecond = container.read(caretakingProvider);

      expect(stateAfterFirst, stateAfterSecond);
    });

    test('loadState restores saved state', () {
      final saved = CaretakingState(
        lastVisitDate: DateTime(2024, 3, 1),
        currentStreak: 5,
        longestStreak: 7,
      );

      final notifier = container.read(caretakingProvider.notifier);
      notifier.loadState(saved);

      final state = container.read(caretakingProvider);
      expect(state.lastVisitDate, DateTime(2024, 3, 1));
      expect(state.currentStreak, 5);
      expect(state.longestStreak, 7);
    });

    test('loadState syncs with playerProvider', () {
      final saved = CaretakingState(
        lastVisitDate: DateTime(2024, 3, 1),
        currentStreak: 5,
        longestStreak: 7,
      );

      final notifier = container.read(caretakingProvider.notifier);
      notifier.loadState(saved);

      final playerState = container.read(playerProvider);
      expect(playerState.currentStreak, 5);
      expect(playerState.longestStreak, 7);
    });

    test('missed day resets streak but preserves longest', () {
      final notifier = container.read(caretakingProvider.notifier);

      notifier.recordVisit(now: DateTime(2024, 3, 1));
      notifier.recordVisit(now: DateTime(2024, 3, 2));
      notifier.recordVisit(now: DateTime(2024, 3, 3));

      expect(container.read(caretakingProvider).currentStreak, 3);
      expect(container.read(caretakingProvider).longestStreak, 3);

      // Miss a day
      notifier.recordVisit(now: DateTime(2024, 3, 5));

      final state = container.read(caretakingProvider);
      expect(state.currentStreak, 1);
      expect(state.longestStreak, 3);

      final playerState = container.read(playerProvider);
      expect(playerState.currentStreak, 1);
      expect(playerState.longestStreak, 3);
    });

    test('recordVisit defaults to DateTime.now() when not provided', () {
      final notifier = container.read(caretakingProvider.notifier);

      // This should not throw and should use current date
      notifier.recordVisit();

      final state = container.read(caretakingProvider);
      expect(state.lastVisitDate, isNotNull);
      expect(state.currentStreak, 1);
    });
  });
}
