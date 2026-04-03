import 'dart:math' show min;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/providers/inventory_provider.dart';
import 'package:earth_nova/providers/player_provider.dart';

// ===========================================================================
// Inlined achievement models (ported from features/achievements/models/)
// ===========================================================================

enum AchievementId {
  firstSteps,
  explorer,
  cartographer,
  naturalist,
  biologist,
  taxonomist,
  forestFriend,
  oceanExplorer,
  mountaineer,
  dedicated,
  devoted,
  marathon,
}

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

  double get progressFraction => min(1.0, currentValue / targetValue);

  AchievementProgress copyWith({
    int? currentValue,
    bool? isUnlocked,
    DateTime? unlockedAt,
    bool clearUnlockedAt = false,
  }) =>
      AchievementProgress(
        id: id,
        currentValue: currentValue ?? this.currentValue,
        targetValue: targetValue,
        isUnlocked: isUnlocked ?? this.isUnlocked,
        unlockedAt: clearUnlockedAt ? null : (unlockedAt ?? this.unlockedAt),
      );
}

class AchievementsState {
  final Map<AchievementId, AchievementProgress> achievements;

  const AchievementsState({required this.achievements});

  List<AchievementId> get unlockedIds =>
      achievements.values.where((p) => p.isUnlocked).map((p) => p.id).toList();

  AchievementsState copyWith({
    Map<AchievementId, AchievementProgress>? achievements,
  }) =>
      AchievementsState(achievements: achievements ?? this.achievements);
}

const Map<AchievementId, int> _kTargets = {
  AchievementId.firstSteps: 1,
  AchievementId.explorer: 10,
  AchievementId.cartographer: 50,
  AchievementId.naturalist: 5,
  AchievementId.biologist: 15,
  AchievementId.taxonomist: 50,
  AchievementId.forestFriend: 1,
  AchievementId.oceanExplorer: 1,
  AchievementId.mountaineer: 1,
  AchievementId.dedicated: 7,
  AchievementId.devoted: 30,
  AchievementId.marathon: 10,
};

AchievementsState _buildInitial() => AchievementsState(
      achievements: {
        for (final id in AchievementId.values)
          id: AchievementProgress(
            id: id,
            currentValue: 0,
            targetValue: _kTargets[id]!,
          ),
      },
    );

// ===========================================================================
// Provider + Notifier
// ===========================================================================

final achievementProvider =
    NotifierProvider<AchievementNotifier, AchievementsState>(
        AchievementNotifier.new);

class AchievementNotifier extends Notifier<AchievementsState> {
  @override
  AchievementsState build() => _buildInitial();

  /// Re-evaluate all achievements from current player + inventory state.
  ///
  /// Called by [engine_provider] after any relevant stat change.
  void evaluate() {
    final player = ref.read(playerProvider);
    final inventory = ref.read(inventoryProvider);

    final byHabitat = <String, int>{};
    for (final item in inventory.items) {
      for (final habitat in item.habitats) {
        byHabitat[habitat.name] = (byHabitat[habitat.name] ?? 0) + 1;
      }
    }

    final now = DateTime.now();
    final updated =
        Map<AchievementId, AchievementProgress>.from(state.achievements);

    for (final id in AchievementId.values) {
      final existing = updated[id]!;
      final newValue = _computeValue(
        id,
        cellsObserved: player.cellsObserved,
        speciesCollected: player.speciesCollected,
        currentStreak: player.currentStreak,
        totalDistanceKm: player.totalDistanceKm,
        byHabitat: byHabitat,
      );
      final justUnlocked =
          !existing.isUnlocked && newValue >= existing.targetValue;
      updated[id] = existing.copyWith(
        currentValue: newValue,
        isUnlocked: existing.isUnlocked || justUnlocked,
        unlockedAt: justUnlocked ? now : null,
      );
    }

    state = state.copyWith(achievements: updated);
  }

  static int _computeValue(
    AchievementId id, {
    required int cellsObserved,
    required int speciesCollected,
    required int currentStreak,
    required double totalDistanceKm,
    required Map<String, int> byHabitat,
  }) {
    return switch (id) {
      AchievementId.firstSteps => cellsObserved >= 1 ? 1 : 0,
      AchievementId.explorer => cellsObserved,
      AchievementId.cartographer => cellsObserved,
      AchievementId.naturalist => speciesCollected,
      AchievementId.biologist => speciesCollected,
      AchievementId.taxonomist => speciesCollected,
      AchievementId.forestFriend => (byHabitat['forest'] ?? 0) > 0 ? 1 : 0,
      AchievementId.oceanExplorer => (byHabitat['saltwater'] ?? 0) > 0 ? 1 : 0,
      AchievementId.mountaineer => (byHabitat['mountain'] ?? 0) > 0 ? 1 : 0,
      AchievementId.dedicated => currentStreak,
      AchievementId.devoted => currentStreak,
      AchievementId.marathon => totalDistanceKm.floor(),
    };
  }
}
