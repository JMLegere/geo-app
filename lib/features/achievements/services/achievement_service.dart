import 'package:earth_nova/features/achievements/models/achievement.dart';
import 'package:earth_nova/features/achievements/models/achievement_state.dart';

/// Snapshot of player stats used to evaluate achievement conditions.
///
/// Passed to [AchievementService.evaluate] so the service has no direct
/// dependency on Riverpod providers (keeping it a pure logic class).
class AchievementContext {
  /// Total number of cells the player has observed.
  final int cellsObserved;

  /// Total number of unique species collected.
  final int speciesCollected;

  /// Current consecutive-day visit streak.
  final int currentStreak;

  /// Total distance walked in kilometres.
  final double totalDistanceKm;

  /// Number of cells that have been fully restored (level == 1.0).
  final int restoredCellCount;

  /// Collected species count broken down by habitat display name.
  ///
  /// Keys match `Habitat.displayName` (e.g. `'Forest'`, `'Saltwater'`).
  /// Values are the count of collected species in that habitat.
  final Map<String, int> collectedByHabitat;

  /// Total species available per habitat (used for "collect all" achievements).
  ///
  /// Keys match `Habitat.displayName`. If a habitat has no species in the
  /// pool, it should be omitted — zero-count habitats never unlock.
  final Map<String, int> totalByHabitat;

  const AchievementContext({
    required this.cellsObserved,
    required this.speciesCollected,
    required this.currentStreak,
    required this.totalDistanceKm,
    required this.restoredCellCount,
    required this.collectedByHabitat,
    required this.totalByHabitat,
  });
}

/// Pure logic class for evaluating achievement progress and unlocks.
///
/// Stateless — takes current [AchievementsState] + [AchievementContext] and
/// returns a new [AchievementsState]. Does not depend on Flutter or Riverpod.
class AchievementService {
  const AchievementService();

  /// Evaluates all achievements against [context] and returns the updated state.
  ///
  /// For each achievement:
  ///   1. Computes the new current value from [context].
  ///   2. If the new value meets the target AND the achievement is not yet
  ///      unlocked, marks it as unlocked with [now] as the timestamp.
  ///   3. Otherwise, only updates the progress value (does not clear unlocks).
  ///
  /// Pass a custom [now] in tests to keep output deterministic.
  AchievementsState evaluate(
    AchievementsState current,
    AchievementContext context, {
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final updated = Map<AchievementId, AchievementProgress>.from(
      current.achievements,
    );

    for (final id in AchievementId.values) {
      final existing = updated[id];
      if (existing == null) continue;

      final newValue = _computeValue(id, context);
      final alreadyUnlocked = existing.isUnlocked;
      final justUnlocked = !alreadyUnlocked && newValue >= existing.targetValue;

      updated[id] = existing.copyWith(
        currentValue: newValue,
        isUnlocked: alreadyUnlocked || justUnlocked,
        unlockedAt: justUnlocked ? timestamp : null,
        clearUnlockedAt: false,
      );
    }

    return current.copyWith(achievements: updated);
  }

  /// Returns IDs that transitioned from locked in [before] to unlocked in [after].
  List<AchievementId> findNewUnlocks(
    AchievementsState before,
    AchievementsState after,
  ) {
    final result = <AchievementId>[];
    for (final id in AchievementId.values) {
      final wasBefore = before.achievements[id]?.isUnlocked ?? false;
      final isAfter = after.achievements[id]?.isUnlocked ?? false;
      if (!wasBefore && isAfter) result.add(id);
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Private: value extraction per achievement ID
  // ---------------------------------------------------------------------------

  int _computeValue(AchievementId id, AchievementContext ctx) {
    return switch (id) {
      AchievementId.firstSteps => ctx.cellsObserved >= 1 ? 1 : 0,
      AchievementId.explorer => ctx.cellsObserved,
      AchievementId.cartographer => ctx.cellsObserved,
      AchievementId.naturalist => ctx.speciesCollected,
      AchievementId.biologist => ctx.speciesCollected,
      AchievementId.taxonomist => ctx.speciesCollected,
      AchievementId.forestFriend =>
        _habitatCompleted(ctx, 'Forest') ? 1 : 0,
      AchievementId.oceanExplorer =>
        _habitatCompleted(ctx, 'Saltwater') ? 1 : 0,
      AchievementId.mountaineer =>
        _habitatCompleted(ctx, 'Mountain') ? 1 : 0,
      AchievementId.dedicated => ctx.currentStreak,
      AchievementId.devoted => ctx.currentStreak,
      AchievementId.marathon => ctx.totalDistanceKm.floor(),
      AchievementId.restorer => ctx.restoredCellCount,
    };
  }

  /// Returns true if every species in [habitat] has been collected.
  ///
  /// Returns false if the habitat has no species in the pool (to avoid
  /// triggering on empty habitats).
  bool _habitatCompleted(AchievementContext ctx, String habitat) {
    final total = ctx.totalByHabitat[habitat] ?? 0;
    if (total == 0) return false;
    final collected = ctx.collectedByHabitat[habitat] ?? 0;
    return collected >= total;
  }
}
