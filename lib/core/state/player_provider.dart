import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlayerState {
  final int currentStreak;
  final int longestStreak;
  final double totalDistanceKm;
  final int cellsObserved;

  PlayerState({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalDistanceKm = 0.0,
    this.cellsObserved = 0,
  });

  PlayerState copyWith({
    int? currentStreak,
    int? longestStreak,
    double? totalDistanceKm,
    int? cellsObserved,
  }) {
    return PlayerState(
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      cellsObserved: cellsObserved ?? this.cellsObserved,
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
}

final playerProvider =
    NotifierProvider<PlayerNotifier, PlayerState>(() => PlayerNotifier());
