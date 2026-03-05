/// Immutable state for the daily visit streak system.
///
/// Tracks:
/// - [lastVisitDate]: The date of the last sanctuary visit (null if never visited).
/// - [currentStreak]: Number of consecutive days visited (0 if no active streak).
/// - [longestStreak]: The highest streak ever achieved (preserved across resets).
class CaretakingState {
  /// The date of the last sanctuary visit, or null if never visited.
  final DateTime? lastVisitDate;

  /// Number of consecutive days the player has visited the sanctuary.
  /// Resets to 0 when a day is missed, but [longestStreak] is preserved.
  final int currentStreak;

  /// The highest streak ever achieved.
  /// Never decreases; only increases when [currentStreak] exceeds it.
  final int longestStreak;

  const CaretakingState({
    this.lastVisitDate,
    this.currentStreak = 0,
    this.longestStreak = 0,
  });

  /// Returns a copy of this state with specified fields replaced.
  CaretakingState copyWith({
    DateTime? lastVisitDate,
    int? currentStreak,
    int? longestStreak,
  }) {
    return CaretakingState(
      lastVisitDate: lastVisitDate ?? this.lastVisitDate,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
    );
  }

  @override
  String toString() =>
      'CaretakingState(lastVisitDate: $lastVisitDate, currentStreak: $currentStreak, longestStreak: $longestStreak)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CaretakingState &&
          runtimeType == other.runtimeType &&
          lastVisitDate == other.lastVisitDate &&
          currentStreak == other.currentStreak &&
          longestStreak == other.longestStreak;

  @override
  int get hashCode =>
      lastVisitDate.hashCode ^ currentStreak.hashCode ^ longestStreak.hashCode;
}
