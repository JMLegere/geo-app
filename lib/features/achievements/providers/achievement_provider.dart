import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fog_of_world/core/models/habitat.dart';
import 'package:fog_of_world/core/state/collection_provider.dart';
import 'package:fog_of_world/core/state/player_provider.dart';
import 'package:fog_of_world/features/achievements/models/achievement.dart';
import 'package:fog_of_world/features/achievements/models/achievement_state.dart';
import 'package:fog_of_world/features/achievements/services/achievement_service.dart';
import 'package:fog_of_world/features/discovery/providers/discovery_provider.dart';
import 'package:fog_of_world/features/restoration/providers/restoration_provider.dart';

// ---------------------------------------------------------------------------
// AchievementNotification state + notifier
// ---------------------------------------------------------------------------

/// The currently queued achievement notification to display.
class AchievementNotificationState {
  final bool hasActiveNotification;
  final AchievementId? currentNotification;

  const AchievementNotificationState({
    this.hasActiveNotification = false,
    this.currentNotification,
  });

  AchievementNotificationState copyWith({
    bool? hasActiveNotification,
    AchievementId? currentNotification,
    bool clearCurrentNotification = false,
  }) {
    return AchievementNotificationState(
      hasActiveNotification:
          hasActiveNotification ?? this.hasActiveNotification,
      currentNotification: clearCurrentNotification
          ? null
          : (currentNotification ?? this.currentNotification),
    );
  }
}

/// Manages the achievement toast notification queue.
///
/// Pattern mirrors [DiscoveryNotifier]: one active notification at a time,
/// replaced immediately if a new one arrives while one is showing.
class AchievementNotificationNotifier
    extends Notifier<AchievementNotificationState> {
  @override
  AchievementNotificationState build() =>
      const AchievementNotificationState();

  /// Queues [id] as the active notification.
  void showNotification(AchievementId id) {
    state = state.copyWith(
      hasActiveNotification: true,
      currentNotification: id,
    );
  }

  /// Dismisses the active notification (called by the overlay after auto-dismiss).
  void dismissNotification() {
    state = state.copyWith(
      hasActiveNotification: false,
      clearCurrentNotification: true,
    );
  }
}

/// Provider for the achievement notification toast state.
final achievementNotificationProvider = NotifierProvider<
    AchievementNotificationNotifier, AchievementNotificationState>(
  AchievementNotificationNotifier.new,
);

// ---------------------------------------------------------------------------
// AchievementNotifier
// ---------------------------------------------------------------------------

/// Riverpod notifier that owns the achievement progress state.
///
/// Call [checkAchievements] after any state-changing action (cell observed,
/// species collected, streak updated, distance added, cell restored) to
/// re-evaluate all achievements and emit toast notifications for new unlocks.
class AchievementNotifier extends Notifier<AchievementsState> {
  static const _service = AchievementService();

  @override
  AchievementsState build() {
    // Initialise all achievements as locked with zero progress.
    final initial = <AchievementId, AchievementProgress>{};
    for (final id in AchievementId.values) {
      final def = kAchievementDefinitions[id]!;
      initial[id] = AchievementProgress(
        id: id,
        currentValue: 0,
        targetValue: def.targetValue,
        isUnlocked: false,
      );
    }
    return AchievementsState(achievements: initial);
  }

  /// Re-evaluates all achievements using current provider state.
  ///
  /// Builds an [AchievementContext] from [playerProvider],
  /// [collectionProvider], and [restorationProvider], then calls the pure
  /// service to compute new progress. Any newly unlocked achievements trigger
  /// a toast notification via [achievementNotificationProvider].
  ///
  /// Pass [now] in tests to keep timestamps deterministic.
  void checkAchievements({DateTime? now}) {
    final playerState = ref.read(playerProvider);
    final collectionState = ref.read(collectionProvider);
    final restorationState = ref.read(restorationProvider);
    final speciesService = ref.read(speciesServiceProvider);

    // Build habitat counts: total species available per habitat from service.
    final totalByHabitat = <String, int>{};
    for (final habitat in Habitat.values) {
      final count = speciesService.forHabitat(habitat).length;
      if (count > 0) totalByHabitat[habitat.displayName] = count;
    }

    // Build collected-by-habitat: cross-reference collected IDs with records.
    final collectedByHabitat = <String, int>{};
    final collectedIds = collectionState.collectedSpeciesIds.toSet();
    for (final record in speciesService.all) {
      if (collectedIds.contains(record.id)) {
        for (final habitat in record.habitats) {
          collectedByHabitat[habitat.displayName] =
              (collectedByHabitat[habitat.displayName] ?? 0) + 1;
        }
      }
    }

    // Count fully-restored cells (level >= 1.0).
    final restoredCellCount =
        restorationState.levels.values.where((lvl) => lvl >= 1.0).length;

    final context = AchievementContext(
      cellsObserved: playerState.cellsObserved,
      speciesCollected: collectionState.totalCollected,
      currentStreak: playerState.currentStreak,
      totalDistanceKm: playerState.totalDistanceKm,
      restoredCellCount: restoredCellCount,
      collectedByHabitat: collectedByHabitat,
      totalByHabitat: totalByHabitat,
    );

    final before = state;
    final after = _service.evaluate(before, context, now: now);
    final newUnlocks = _service.findNewUnlocks(before, after);

    state = after;

    // Fire toast for each newly unlocked achievement.
    for (final id in newUnlocks) {
      ref.read(achievementNotificationProvider.notifier).showNotification(id);
    }
  }

  /// Restores previously persisted achievement state (called on app startup).
  void loadState(AchievementsState saved) {
    state = saved;
  }
}

/// Global provider for [AchievementNotifier].
final achievementProvider =
    NotifierProvider<AchievementNotifier, AchievementsState>(
  AchievementNotifier.new,
);
