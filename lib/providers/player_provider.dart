import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Immutable player progress + hydration state.
class PlayerState {
  final String? userId;
  final int cellsObserved;
  final int speciesCollected;
  final int currentStreak;
  final int longestStreak;
  final double totalDistanceKm;
  final int totalSteps;
  final int lastKnownStepCount;
  final bool hasCompletedOnboarding;

  /// True once the initial SQLite hydration completes.
  /// UI shows a loading screen until this is true.
  final bool isHydrated;

  const PlayerState({
    this.userId,
    this.cellsObserved = 0,
    this.speciesCollected = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalDistanceKm = 0.0,
    this.totalSteps = 0,
    this.lastKnownStepCount = 0,
    this.hasCompletedOnboarding = false,
    this.isHydrated = false,
  });

  PlayerState copyWith({
    String? userId,
    int? cellsObserved,
    int? speciesCollected,
    int? currentStreak,
    int? longestStreak,
    double? totalDistanceKm,
    int? totalSteps,
    int? lastKnownStepCount,
    bool? hasCompletedOnboarding,
    bool? isHydrated,
  }) =>
      PlayerState(
        userId: userId ?? this.userId,
        cellsObserved: cellsObserved ?? this.cellsObserved,
        speciesCollected: speciesCollected ?? this.speciesCollected,
        currentStreak: currentStreak ?? this.currentStreak,
        longestStreak: longestStreak ?? this.longestStreak,
        totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
        totalSteps: totalSteps ?? this.totalSteps,
        lastKnownStepCount: lastKnownStepCount ?? this.lastKnownStepCount,
        hasCompletedOnboarding:
            hasCompletedOnboarding ?? this.hasCompletedOnboarding,
        isHydrated: isHydrated ?? this.isHydrated,
      );
}

// ---------------------------------------------------------------------------
// Provider + Notifier
// ---------------------------------------------------------------------------

final playerProvider =
    NotifierProvider<PlayerNotifier, PlayerState>(PlayerNotifier.new);

class PlayerNotifier extends Notifier<PlayerState> {
  @override
  PlayerState build() => const PlayerState();

  /// Hydrate from SQLite profile + cell visit rows.
  void loadProfile({
    required int cellsObserved,
    required double totalDistanceKm,
    required int currentStreak,
    required int longestStreak,
    bool? hasCompletedOnboarding,
    int totalSteps = 0,
    int lastKnownStepCount = 0,
  }) {
    state = state.copyWith(
      cellsObserved: cellsObserved,
      totalDistanceKm: totalDistanceKm,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      hasCompletedOnboarding: hasCompletedOnboarding,
      totalSteps: totalSteps,
      lastKnownStepCount: lastKnownStepCount,
    );
  }

  /// Called after all hydration steps complete — dismisses loading screen.
  void markHydrated() => state = state.copyWith(isHydrated: true);

  void setUserId(String? userId) => state = state.copyWith(userId: userId);

  void incrementCellsObserved() =>
      state = state.copyWith(cellsObserved: state.cellsObserved + 1);

  void incrementSpeciesCollected() =>
      state = state.copyWith(speciesCollected: state.speciesCollected + 1);

  void addDistance(double km) =>
      state = state.copyWith(totalDistanceKm: state.totalDistanceKm + km);

  void addSteps(int delta) {
    if (delta <= 0) return;
    state = state.copyWith(totalSteps: state.totalSteps + delta);
  }

  void completeOnboarding() =>
      state = state.copyWith(hasCompletedOnboarding: true);

  void updateStreak({required int current, required int longest}) =>
      state = state.copyWith(
        currentStreak: current,
        longestStreak: longest,
      );
}
