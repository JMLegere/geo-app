import 'package:earth_nova/features/caretaking/models/caretaking_state.dart';

/// Pure logic service for daily visit streak calculations.
///
/// This service contains no Riverpod dependencies and is fully testable.
/// It handles the core streak logic:
/// - First visit: streak = 1
/// - Same day visit: no-op
/// - Consecutive day visit: increment streak
/// - Missed day: reset streak to 1, preserve longest
class CaretakingService {
  /// Records a visit on the given date.
  ///
  /// Returns a new [CaretakingState] with updated streak information.
  ///
  /// Logic:
  /// - If lastVisitDate is null: first visit → streak = 1
  /// - If lastVisitDate is same day as now: no-op → return current
  /// - If lastVisitDate is yesterday: consecutive → increment streak
  /// - If lastVisitDate is older: missed day → reset to 1, preserve longest
  CaretakingState recordVisit(CaretakingState current, DateTime now) {
    final lastDate = current.lastVisitDate;

    // First visit ever
    if (lastDate == null) {
      return current.copyWith(
        lastVisitDate: now,
        currentStreak: 1,
        longestStreak: 1,
      );
    }

    // Compare dates (year, month, day only)
    final lastDateOnly = DateTime(lastDate.year, lastDate.month, lastDate.day);
    final nowDateOnly = DateTime(now.year, now.month, now.day);

    // Same day visit: no-op
    if (lastDateOnly == nowDateOnly) {
      return current;
    }

    // Calculate days since last visit
    final daysSinceLastVisit = nowDateOnly.difference(lastDateOnly).inDays;

    if (daysSinceLastVisit == 1) {
      // Consecutive day: increment streak
      final newStreak = current.currentStreak + 1;
      final newLongest =
          newStreak > current.longestStreak ? newStreak : current.longestStreak;

      return current.copyWith(
        lastVisitDate: now,
        currentStreak: newStreak,
        longestStreak: newLongest,
      );
    } else {
      // Missed day(s): reset streak to 1, preserve longest
      final newLongest = current.currentStreak > current.longestStreak
          ? current.currentStreak
          : current.longestStreak;

      return current.copyWith(
        lastVisitDate: now,
        currentStreak: 1,
        longestStreak: newLongest,
      );
    }
  }

  /// Checks if the player has already visited today.
  ///
  /// Returns true if lastVisitDate is the same day as now.
  bool hasVisitedToday(CaretakingState state, DateTime now) {
    final lastDate = state.lastVisitDate;
    if (lastDate == null) return false;

    final lastDateOnly = DateTime(lastDate.year, lastDate.month, lastDate.day);
    final nowDateOnly = DateTime(now.year, now.month, now.day);

    return lastDateOnly == nowDateOnly;
  }
}
