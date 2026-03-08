import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/caretaking/models/caretaking_state.dart';

void main() {
  group('CaretakingState', () {
    test('default constructor creates empty state', () {
      final state = const CaretakingState();

      expect(state.lastVisitDate, isNull);
      expect(state.currentStreak, 0);
      expect(state.longestStreak, 0);
    });

    test('constructor with parameters sets values correctly', () {
      final date = DateTime(2024, 3, 1);
      final state = CaretakingState(
        lastVisitDate: date,
        currentStreak: 5,
        longestStreak: 10,
      );

      expect(state.lastVisitDate, date);
      expect(state.currentStreak, 5);
      expect(state.longestStreak, 10);
    });

    test('copyWith replaces specified fields', () {
      final original = CaretakingState(
        lastVisitDate: DateTime(2024, 3, 1),
        currentStreak: 3,
        longestStreak: 5,
      );

      final updated = original.copyWith(currentStreak: 4);

      expect(updated.lastVisitDate, DateTime(2024, 3, 1));
      expect(updated.currentStreak, 4);
      expect(updated.longestStreak, 5);
    });

    test('copyWith preserves unspecified fields', () {
      final original = CaretakingState(
        lastVisitDate: DateTime(2024, 3, 1),
        currentStreak: 3,
        longestStreak: 5,
      );

      final updated = original.copyWith(longestStreak: 7);

      expect(updated.lastVisitDate, DateTime(2024, 3, 1));
      expect(updated.currentStreak, 3);
      expect(updated.longestStreak, 7);
    });

    test('copyWith can update all fields at once', () {
      final original = const CaretakingState();
      final newDate = DateTime(2024, 3, 1);

      final updated = original.copyWith(
        lastVisitDate: newDate,
        currentStreak: 5,
        longestStreak: 10,
      );

      expect(updated.lastVisitDate, newDate);
      expect(updated.currentStreak, 5);
      expect(updated.longestStreak, 10);
    });

    test('equality works correctly', () {
      final state1 = CaretakingState(
        lastVisitDate: DateTime(2024, 3, 1),
        currentStreak: 3,
        longestStreak: 5,
      );

      final state2 = CaretakingState(
        lastVisitDate: DateTime(2024, 3, 1),
        currentStreak: 3,
        longestStreak: 5,
      );

      expect(state1, state2);
    });

    test('inequality works correctly', () {
      final state1 = CaretakingState(
        lastVisitDate: DateTime(2024, 3, 1),
        currentStreak: 3,
        longestStreak: 5,
      );

      final state2 = CaretakingState(
        lastVisitDate: DateTime(2024, 3, 1),
        currentStreak: 4,
        longestStreak: 5,
      );

      expect(state1, isNot(state2));
    });

    test('hashCode is consistent', () {
      final state1 = CaretakingState(
        lastVisitDate: DateTime(2024, 3, 1),
        currentStreak: 3,
        longestStreak: 5,
      );

      final state2 = CaretakingState(
        lastVisitDate: DateTime(2024, 3, 1),
        currentStreak: 3,
        longestStreak: 5,
      );

      expect(state1.hashCode, state2.hashCode);
    });

    test('toString returns readable string', () {
      final state = CaretakingState(
        lastVisitDate: DateTime(2024, 3, 1),
        currentStreak: 3,
        longestStreak: 5,
      );

      final str = state.toString();
      expect(str, contains('CaretakingState'));
      expect(str, contains('currentStreak: 3'));
      expect(str, contains('longestStreak: 5'));
    });
  });
}
