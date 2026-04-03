import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/models/item_instance.dart';
import 'package:earth_nova/models/item_category.dart';
import 'package:earth_nova/models/habitat.dart';
import 'package:earth_nova/providers/achievement_provider.dart';
import 'package:earth_nova/providers/inventory_provider.dart';
import 'package:earth_nova/providers/player_provider.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ItemInstance _makeFaunaItem({
  String id = 'item_1',
  List<Habitat> habitats = const [Habitat.forest],
}) =>
    ItemInstance(
      id: id,
      definitionId: 'def_$id',
      displayName: 'Test Fauna',
      category: ItemCategory.fauna,
      habitats: habitats,
      acquiredAt: DateTime(2026, 1, 1),
    );

void main() {
  group('AchievementNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('initial state has no completed achievements', () {
      final state = container.read(achievementProvider);
      expect(state.unlockedIds, isEmpty);
    });

    test('all achievement progress starts at 0', () {
      final state = container.read(achievementProvider);
      for (final id in AchievementId.values) {
        expect(state.achievements[id]!.currentValue, 0,
            reason: '${id.name} should start at 0');
        expect(state.achievements[id]!.isUnlocked, isFalse,
            reason: '${id.name} should not be unlocked initially');
      }
    });

    test('evaluate with 1 cell unlocks firstSteps achievement', () {
      container.read(playerProvider.notifier).loadProfile(
            cellsObserved: 1,
            totalDistanceKm: 0,
            currentStreak: 0,
            longestStreak: 0,
          );
      container.read(achievementProvider.notifier).evaluate();

      final state = container.read(achievementProvider);
      expect(state.achievements[AchievementId.firstSteps]!.isUnlocked, isTrue);
    });

    test('evaluate with 10+ cells unlocks explorer achievement', () {
      container.read(playerProvider.notifier).loadProfile(
            cellsObserved: 10,
            totalDistanceKm: 0,
            currentStreak: 0,
            longestStreak: 0,
          );
      container.read(achievementProvider.notifier).evaluate();

      expect(
        container
            .read(achievementProvider)
            .achievements[AchievementId.explorer]!
            .isUnlocked,
        isTrue,
      );
    });

    test('evaluate with 5+ species unlocks naturalist achievement', () {
      container.read(playerProvider.notifier).loadProfile(
            cellsObserved: 0,
            totalDistanceKm: 0,
            currentStreak: 0,
            longestStreak: 0,
          );
      // Add 5 species to inventory.
      for (var i = 0; i < 5; i++) {
        container
            .read(inventoryProvider.notifier)
            .addItem(_makeFaunaItem(id: 'sp_$i'));
        container.read(playerProvider.notifier).incrementSpeciesCollected();
      }
      container.read(achievementProvider.notifier).evaluate();

      expect(
        container
            .read(achievementProvider)
            .achievements[AchievementId.naturalist]!
            .isUnlocked,
        isTrue,
      );
    });

    test('forestFriend unlocks when player has a forest-habitat item', () {
      container.read(inventoryProvider.notifier).loadItems([
        _makeFaunaItem(id: 'forest_sp', habitats: [Habitat.forest]),
      ]);
      container.read(playerProvider.notifier).loadProfile(
            cellsObserved: 0,
            totalDistanceKm: 0,
            currentStreak: 0,
            longestStreak: 0,
          );
      container.read(achievementProvider.notifier).evaluate();

      expect(
        container
            .read(achievementProvider)
            .achievements[AchievementId.forestFriend]!
            .isUnlocked,
        isTrue,
      );
    });

    test('mountaineer does NOT unlock when no mountain items present', () {
      container.read(inventoryProvider.notifier).loadItems([
        _makeFaunaItem(id: 'plains_sp', habitats: [Habitat.plains]),
      ]);
      container.read(playerProvider.notifier).loadProfile(
            cellsObserved: 0,
            totalDistanceKm: 0,
            currentStreak: 0,
            longestStreak: 0,
          );
      container.read(achievementProvider.notifier).evaluate();

      expect(
        container
            .read(achievementProvider)
            .achievements[AchievementId.mountaineer]!
            .isUnlocked,
        isFalse,
      );
    });

    test('already-completed achievements do not re-trigger on re-evaluation',
        () {
      container.read(playerProvider.notifier).loadProfile(
            cellsObserved: 1,
            totalDistanceKm: 0,
            currentStreak: 0,
            longestStreak: 0,
          );
      container.read(achievementProvider.notifier).evaluate();

      final firstUnlockedAt = container
          .read(achievementProvider)
          .achievements[AchievementId.firstSteps]!
          .unlockedAt;

      // Wait a tick and re-evaluate.
      container.read(achievementProvider.notifier).evaluate();

      final secondUnlockedAt = container
          .read(achievementProvider)
          .achievements[AchievementId.firstSteps]!
          .unlockedAt;

      // unlockedAt is set once; subsequent evaluations don't change it.
      expect(secondUnlockedAt, equals(firstUnlockedAt));
    });

    test('progress tracking is cumulative across evaluate calls', () {
      container.read(playerProvider.notifier).loadProfile(
            cellsObserved: 5,
            totalDistanceKm: 0,
            currentStreak: 0,
            longestStreak: 0,
          );
      container.read(achievementProvider.notifier).evaluate();

      final progress = container
          .read(achievementProvider)
          .achievements[AchievementId.explorer]!;
      expect(progress.currentValue, 5);
      expect(progress.isUnlocked, isFalse); // target is 10

      // Increase to 10.
      container.read(playerProvider.notifier).loadProfile(
            cellsObserved: 10,
            totalDistanceKm: 0,
            currentStreak: 0,
            longestStreak: 0,
          );
      container.read(achievementProvider.notifier).evaluate();

      expect(
        container
            .read(achievementProvider)
            .achievements[AchievementId.explorer]!
            .isUnlocked,
        isTrue,
      );
    });
  });
}
