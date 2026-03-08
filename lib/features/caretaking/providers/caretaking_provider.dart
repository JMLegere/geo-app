import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/state/player_provider.dart';
import 'package:earth_nova/features/caretaking/models/caretaking_state.dart';
import 'package:earth_nova/features/caretaking/services/caretaking_service.dart';

/// Notifier for managing daily visit streak state.
///
/// Handles:
/// - Recording visits when the sanctuary screen is opened
/// - Syncing streak changes with [PlayerNotifier]
/// - Restoring saved state from persistence
class CaretakingNotifier extends Notifier<CaretakingState> {
  final CaretakingService _service = CaretakingService();

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

    // Sync streak to player in one call — no reset-and-replay.
    _syncStreakToPlayer(newState);
  }

  /// Restores caretaking state from persistence.
  ///
  /// Used when loading saved state from the database.
  void loadState(CaretakingState saved) {
    state = saved;
    _syncStreakToPlayer(saved);
  }

  /// Pushes caretaking streak values to the player provider.
  void _syncStreakToPlayer(CaretakingState caretaking) {
    ref.read(playerProvider.notifier).setStreak(
          current: caretaking.currentStreak,
          longest: caretaking.longestStreak,
        );
  }
}

/// Global provider for [CaretakingNotifier].
final caretakingProvider =
    NotifierProvider<CaretakingNotifier, CaretakingState>(
  CaretakingNotifier.new,
);
