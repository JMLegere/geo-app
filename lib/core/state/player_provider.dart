import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlayerState {
  final int currentStreak;
  final int longestStreak;
  final double totalDistanceKm;
  final int cellsObserved;

  /// Cumulative in-game step total across all sessions.
  final int totalSteps;

  /// Last OS pedometer value seen — used to compute delta on next app open.
  final int lastKnownStepCount;

  /// Whether the player has completed the onboarding flow.
  final bool hasCompletedOnboarding;

  PlayerState({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalDistanceKm = 0.0,
    this.cellsObserved = 0,
    this.totalSteps = 0,
    this.lastKnownStepCount = 0,
    this.hasCompletedOnboarding = false,
  });

  PlayerState copyWith({
    int? currentStreak,
    int? longestStreak,
    double? totalDistanceKm,
    int? cellsObserved,
    int? totalSteps,
    int? lastKnownStepCount,
    bool? hasCompletedOnboarding,
  }) {
    return PlayerState(
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      cellsObserved: cellsObserved ?? this.cellsObserved,
      totalSteps: totalSteps ?? this.totalSteps,
      lastKnownStepCount: lastKnownStepCount ?? this.lastKnownStepCount,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
    );
  }
}

class PlayerNotifier extends Notifier<PlayerState> {
  @override
  PlayerState build() {
    return PlayerState();
  }

  void incrementStreak() {
    final newStreak = state.currentStreak + 1;
    final newLongest =
        newStreak > state.longestStreak ? newStreak : state.longestStreak;

    state = state.copyWith(
      currentStreak: newStreak,
      longestStreak: newLongest,
    );
  }

  void resetStreak() {
    state = state.copyWith(currentStreak: 0);
  }

  /// Directly sets streak values. Used by caretaking to sync streak state
  /// without the fragile reset-and-replay pattern.
  void setStreak({required int current, required int longest}) {
    state = state.copyWith(
      currentStreak: current,
      longestStreak: longest,
    );
  }

  /// Adds [delta] steps to the running total and updates the OS baseline.
  ///
  /// Called by [StepNotifier] during hydration and live pedometer streaming.
  void addSteps(int delta) {
    state = state.copyWith(
      totalSteps: state.totalSteps + delta,
    );
  }

  /// Spends [amount] steps from the player's balance.
  ///
  /// Returns true and reduces totalSteps by [amount] if [amount] <= totalSteps.
  /// Returns false and does not mutate state if [amount] > totalSteps or [amount] <= 0.
  bool spendSteps(int amount) {
    if (amount <= 0 || amount > state.totalSteps) {
      return false;
    }

    state = state.copyWith(
      totalSteps: state.totalSteps - amount,
    );
    return true;
  }

  /// Updates the last-known OS pedometer value for next-session delta calc.
  void updateLastKnownStepCount(int osSteps) {
    state = state.copyWith(lastKnownStepCount: osSteps);
  }

  void addDistance(double km) {
    state = state.copyWith(
      totalDistanceKm: state.totalDistanceKm + km,
    );
  }

  void incrementCellsObserved() {
    state = state.copyWith(
      cellsObserved: state.cellsObserved + 1,
    );
  }

  /// Replaces the entire player state from persisted data.
  ///
  /// Called during startup hydration to restore profile from SQLite.
  void loadProfile({
    required int cellsObserved,
    required double totalDistanceKm,
    required int currentStreak,
    required int longestStreak,
    int totalSteps = 0,
    int lastKnownStepCount = 0,
    bool hasCompletedOnboarding = false,
  }) {
    state = PlayerState(
      cellsObserved: cellsObserved,
      totalDistanceKm: totalDistanceKm,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      totalSteps: totalSteps,
      lastKnownStepCount: lastKnownStepCount,
      hasCompletedOnboarding: hasCompletedOnboarding,
    );
  }

  void markOnboardingComplete() {
    state = state.copyWith(hasCompletedOnboarding: true);
  }
}

final playerProvider =
    NotifierProvider<PlayerNotifier, PlayerState>(() => PlayerNotifier());
