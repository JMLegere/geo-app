import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fog_of_world/core/state/player_provider.dart';
import 'package:fog_of_world/features/caretaking/models/caretaking_state.dart';
import 'package:fog_of_world/features/caretaking/services/caretaking_service.dart';

/// Notifier for managing daily visit streak state.
///
/// Handles:
/// - Recording visits when the sanctuary screen is opened
/// - Syncing streak changes with [PlayerNotifier]
/// - Restoring saved state from persistence
class CaretakingNotifier extends Notifier<CaretakingState> {
  late final CaretakingService _service = CaretakingService();

  @override
  CaretakingState build() {
    return const CaretakingState();
  }

  /// Records a visit on the given date (defaults to now).
  ///
  /// Updates the internal state and syncs with [PlayerNotifier].
  /// The [now] parameter is optional for testability.
  void recordVisit({DateTime? now}) {
    now ??= DateTime.now();

    // Skip if already visited today
    if (_service.hasVisitedToday(state, now)) {
      return;
    }

    // Update caretaking state
    final newState = _service.recordVisit(state, now);
    state = newState;

    // Sync with PlayerNotifier
    final playerNotifier = ref.read(playerProvider.notifier);
    playerNotifier.resetStreak();
    for (int i = 0; i < newState.currentStreak; i++) {
      playerNotifier.incrementStreak();
    }
  }

  /// Restores caretaking state from persistence.
  ///
  /// Used when loading saved state from the database.
  void loadState(CaretakingState saved) {
    state = saved;

    // Sync with PlayerNotifier
    final playerNotifier = ref.read(playerProvider.notifier);
    playerNotifier.resetStreak();
    for (int i = 0; i < saved.currentStreak; i++) {
      playerNotifier.incrementStreak();
    }
    // Also sync longestStreak if it's higher than what incrementStreak set
    if (saved.longestStreak > saved.currentStreak) {
      final playerState = ref.read(playerProvider);
      if (saved.longestStreak > playerState.longestStreak) {
        playerNotifier.state = playerState.copyWith(
          longestStreak: saved.longestStreak,
        );
      }
    }
  }
}

/// Global provider for [CaretakingNotifier].
final caretakingProvider =
    NotifierProvider<CaretakingNotifier, CaretakingState>(
  CaretakingNotifier.new,
);
