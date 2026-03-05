import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/core/state/collection_provider.dart';
import 'package:fog_of_world/core/state/player_provider.dart';
import 'package:fog_of_world/features/achievements/models/achievement.dart';
import 'package:fog_of_world/features/achievements/models/achievement_state.dart';
import 'package:fog_of_world/features/achievements/providers/achievement_provider.dart';

void main() {
  group('AchievementNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    // -------------------------------------------------------------------------
    // Initial state
    // -------------------------------------------------------------------------

    test('initial state has all achievements locked', () {
      final state = container.read(achievementProvider);
      for (final id in AchievementId.values) {
        expect(
          state.achievements[id]?.isUnlocked,
          isFalse,
          reason: '$id should be locked initially',
        );
      }
    });

    test('initial state has all achievements with currentValue == 0', () {
      final state = container.read(achievementProvider);
      for (final id in AchievementId.values) {
        expect(
          state.achievements[id]?.currentValue,
          equals(0),
          reason: '$id should start at 0 progress',
        );
      }
    });

    test('initial state has an entry for every AchievementId', () {
      final state = container.read(achievementProvider);
      for (final id in AchievementId.values) {
        expect(
          state.achievements.containsKey(id),
          isTrue,
          reason: '$id missing from initial state',
        );
      }
    });

    test('initial totalCount equals AchievementId.values.length', () {
      final state = container.read(achievementProvider);
      expect(state.totalCount, equals(AchievementId.values.length));
    });

    // -------------------------------------------------------------------------
    // checkAchievements — progress updates
    // -------------------------------------------------------------------------

    test('checkAchievements updates cells progress from playerProvider', () {
      // Increment cells to 3 via playerProvider.
      final player = container.read(playerProvider.notifier);
      player.incrementCellsObserved();
      player.incrementCellsObserved();
      player.incrementCellsObserved();

      container.read(achievementProvider.notifier).checkAchievements(
            now: DateTime(2024, 6, 1),
          );

      final state = container.read(achievementProvider);
      final explorerProgress = state.achievements[AchievementId.explorer]!;
      expect(explorerProgress.currentValue, equals(3));
    });

    test('checkAchievements unlocks "First Steps" after 1 cell observed', () {
      container.read(playerProvider.notifier).incrementCellsObserved();

      container.read(achievementProvider.notifier).checkAchievements(
            now: DateTime(2024, 6, 1),
          );

      final state = container.read(achievementProvider);
      expect(
          state.achievements[AchievementId.firstSteps]!.isUnlocked, isTrue);
    });

    test('checkAchievements updates species progress from collectionProvider',
        () {
      final collection = container.read(collectionProvider.notifier);
      collection.addSpecies('species_1');
      collection.addSpecies('species_2');
      collection.addSpecies('species_3');
      collection.addSpecies('species_4');
      collection.addSpecies('species_5');

      container.read(achievementProvider.notifier).checkAchievements(
            now: DateTime(2024, 6, 1),
          );

      final state = container.read(achievementProvider);
      expect(
          state.achievements[AchievementId.naturalist]!.isUnlocked, isTrue);
    });

    // -------------------------------------------------------------------------
    // loadState
    // -------------------------------------------------------------------------

    test('loadState restores saved state', () {
      final savedMap = <AchievementId, AchievementProgress>{};
      final unlockedAt = DateTime(2024, 1, 15);

      for (final id in AchievementId.values) {
        final def = kAchievementDefinitions[id]!;
        final isUnlocked = id == AchievementId.firstSteps;
        savedMap[id] = AchievementProgress(
          id: id,
          currentValue: isUnlocked ? def.targetValue : 0,
          targetValue: def.targetValue,
          isUnlocked: isUnlocked,
          unlockedAt: isUnlocked ? unlockedAt : null,
        );
      }

      final saved = AchievementsState(achievements: savedMap);
      container.read(achievementProvider.notifier).loadState(saved);

      final state = container.read(achievementProvider);
      expect(
          state.achievements[AchievementId.firstSteps]!.isUnlocked, isTrue);
      expect(state.achievements[AchievementId.firstSteps]!.unlockedAt,
          equals(unlockedAt));
      expect(
          state.achievements[AchievementId.explorer]!.isUnlocked, isFalse);
    });

    test('loadState replaces all previous state', () {
      // First put some data in via checkAchievements.
      container.read(playerProvider.notifier).incrementCellsObserved();
      container.read(achievementProvider.notifier).checkAchievements();

      // Then load a fresh (all-locked) state.
      final freshMap = <AchievementId, AchievementProgress>{};
      for (final id in AchievementId.values) {
        final def = kAchievementDefinitions[id]!;
        freshMap[id] = AchievementProgress(
          id: id,
          currentValue: 0,
          targetValue: def.targetValue,
        );
      }
      container
          .read(achievementProvider.notifier)
          .loadState(AchievementsState(achievements: freshMap));

      final state = container.read(achievementProvider);
      expect(
          state.achievements[AchievementId.firstSteps]!.isUnlocked, isFalse);
    });
  });

  group('AchievementNotificationNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state has no active notification', () {
      final state = container.read(achievementNotificationProvider);
      expect(state.hasActiveNotification, isFalse);
      expect(state.currentNotification, isNull);
    });

    test('showNotification sets hasActiveNotification and currentNotification',
        () {
      container
          .read(achievementNotificationProvider.notifier)
          .showNotification(AchievementId.firstSteps);

      final state = container.read(achievementNotificationProvider);
      expect(state.hasActiveNotification, isTrue);
      expect(state.currentNotification, equals(AchievementId.firstSteps));
    });

    test('dismissNotification clears hasActiveNotification', () {
      container
          .read(achievementNotificationProvider.notifier)
          .showNotification(AchievementId.explorer);

      container
          .read(achievementNotificationProvider.notifier)
          .dismissNotification();

      final state = container.read(achievementNotificationProvider);
      expect(state.hasActiveNotification, isFalse);
      expect(state.currentNotification, isNull);
    });
  });
}
