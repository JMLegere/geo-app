import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/caretaking/models/caretaking_state.dart';
import 'package:earth_nova/features/caretaking/services/caretaking_service.dart';

void main() {
  group('CaretakingService', () {
    late CaretakingService service;

    setUp(() {
      service = CaretakingService();
    });

    group('recordVisit', () {
      test('first visit starts streak at 1', () {
        final initial = const CaretakingState();
        final now = DateTime(2024, 3, 1);

        final result = service.recordVisit(initial, now);

        expect(result.lastVisitDate, DateTime(2024, 3, 1));
        expect(result.currentStreak, 1);
        expect(result.longestStreak, 1);
      });

      test('visit on same day is no-op', () {
        final initial = CaretakingState(
          lastVisitDate: DateTime(2024, 3, 1, 10, 30),
          currentStreak: 1,
          longestStreak: 1,
        );
        final now = DateTime(2024, 3, 1, 15, 45);

        final result = service.recordVisit(initial, now);

        expect(result, initial);
      });

      test('visit on consecutive day increments streak', () {
        final initial = CaretakingState(
          lastVisitDate: DateTime(2024, 3, 1),
          currentStreak: 1,
          longestStreak: 1,
        );
        final now = DateTime(2024, 3, 2);

        final result = service.recordVisit(initial, now);

        expect(result.lastVisitDate, DateTime(2024, 3, 2));
        expect(result.currentStreak, 2);
        expect(result.longestStreak, 2);
      });

      test('missed day resets streak to 1, preserves longest', () {
        final initial = CaretakingState(
          lastVisitDate: DateTime(2024, 3, 1),
          currentStreak: 5,
          longestStreak: 5,
        );
        final now = DateTime(2024, 3, 3); // Skipped day 2

        final result = service.recordVisit(initial, now);

        expect(result.lastVisitDate, DateTime(2024, 3, 3));
        expect(result.currentStreak, 1);
        expect(result.longestStreak, 5);
      });

      test('longest streak preserved across resets', () {
        var state = const CaretakingState();

        // Build a 3-day streak
        state = service.recordVisit(state, DateTime(2024, 3, 1));
        state = service.recordVisit(state, DateTime(2024, 3, 2));
        state = service.recordVisit(state, DateTime(2024, 3, 3));

        expect(state.currentStreak, 3);
        expect(state.longestStreak, 3);

        // Miss a day, reset to 1
        state = service.recordVisit(state, DateTime(2024, 3, 5));

        expect(state.currentStreak, 1);
        expect(state.longestStreak, 3);

        // Build a 2-day streak
        state = service.recordVisit(state, DateTime(2024, 3, 6));

        expect(state.currentStreak, 2);
        expect(state.longestStreak, 3);
      });

      test('multiple consecutive days (day 1 through day 5)', () {
        var state = const CaretakingState();

        for (int i = 1; i <= 5; i++) {
          state = service.recordVisit(state, DateTime(2024, 3, i));
          expect(state.currentStreak, i);
          expect(state.longestStreak, i);
        }
      });

      test('edge case: visit at 11:59 PM, then 12:01 AM next day', () {
        final initial = CaretakingState(
          lastVisitDate: DateTime(2024, 3, 1, 23, 59),
          currentStreak: 1,
          longestStreak: 1,
        );
        final now = DateTime(2024, 3, 2, 0, 1);

        final result = service.recordVisit(initial, now);

        expect(result.currentStreak, 2);
        expect(result.longestStreak, 2);
      });

      test('new longest streak updates when exceeded', () {
        var state = const CaretakingState();

        // Build a 2-day streak
        state = service.recordVisit(state, DateTime(2024, 3, 1));
        state = service.recordVisit(state, DateTime(2024, 3, 2));

        expect(state.longestStreak, 2);

        // Miss a day
        state = service.recordVisit(state, DateTime(2024, 3, 4));
        expect(state.currentStreak, 1);
        expect(state.longestStreak, 2);

        // Build a 3-day streak (exceeds longest)
        state = service.recordVisit(state, DateTime(2024, 3, 5));
        state = service.recordVisit(state, DateTime(2024, 3, 6));

        expect(state.currentStreak, 3);
        expect(state.longestStreak, 3);
      });
    });

    group('hasVisitedToday', () {
      test('returns true if last visit is today', () {
        final now = DateTime(2024, 3, 1, 15, 30);
        final state = CaretakingState(
          lastVisitDate: DateTime(2024, 3, 1, 10, 0),
          currentStreak: 1,
          longestStreak: 1,
        );

        expect(service.hasVisitedToday(state, now), true);
      });

      test('returns false if last visit was yesterday', () {
        final now = DateTime(2024, 3, 2, 10, 0);
        final state = CaretakingState(
          lastVisitDate: DateTime(2024, 3, 1, 15, 30),
          currentStreak: 1,
          longestStreak: 1,
        );

        expect(service.hasVisitedToday(state, now), false);
      });

      test('returns false if never visited', () {
        final now = DateTime(2024, 3, 1, 10, 0);
        final state = const CaretakingState();

        expect(service.hasVisitedToday(state, now), false);
      });

      test('returns false if last visit was multiple days ago', () {
        final now = DateTime(2024, 3, 5, 10, 0);
        final state = CaretakingState(
          lastVisitDate: DateTime(2024, 3, 1, 15, 30),
          currentStreak: 1,
          longestStreak: 1,
        );

        expect(service.hasVisitedToday(state, now), false);
      });
    });
  });
}
