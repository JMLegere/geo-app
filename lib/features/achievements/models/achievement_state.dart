import 'dart:math' show min;

import 'package:fog_of_world/features/achievements/models/achievement.dart';

/// Per-achievement progress snapshot: current value, target, unlock status.
class AchievementProgress {
  final AchievementId id;
  final int currentValue;
  final int targetValue;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  const AchievementProgress({
    required this.id,
    required this.currentValue,
    required this.targetValue,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  /// Fraction of progress toward the target, clamped to [0.0, 1.0].
  double get progressFraction => min(1.0, currentValue / targetValue);

  AchievementProgress copyWith({
    int? currentValue,
    int? targetValue,
    bool? isUnlocked,
    DateTime? unlockedAt,
    bool clearUnlockedAt = false,
  }) {
    return AchievementProgress(
      id: id,
      currentValue: currentValue ?? this.currentValue,
      targetValue: targetValue ?? this.targetValue,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt:
          clearUnlockedAt ? null : (unlockedAt ?? this.unlockedAt),
    );
  }
}

/// Immutable snapshot of the entire achievement subsystem.
class AchievementsState {
  /// Progress for every [AchievementId].
  final Map<AchievementId, AchievementProgress> achievements;

  const AchievementsState({
    required this.achievements,
  });

  /// IDs of achievements that have been unlocked.
  List<AchievementId> get unlockedIds => achievements.values
      .where((p) => p.isUnlocked)
      .map((p) => p.id)
      .toList();

  /// IDs of achievements that are still locked.
  List<AchievementId> get lockedIds => achievements.values
      .where((p) => !p.isUnlocked)
      .map((p) => p.id)
      .toList();

  /// Number of unlocked achievements.
  int get unlockedCount => unlockedIds.length;

  /// Total number of achievements.
  int get totalCount => achievements.length;

  AchievementsState copyWith({
    Map<AchievementId, AchievementProgress>? achievements,
  }) {
    return AchievementsState(
      achievements: achievements ?? this.achievements,
    );
  }
}
