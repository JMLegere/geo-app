import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/models/iucn_status.dart';
import 'package:earth_nova/core/models/item_definition.dart';
import 'package:earth_nova/core/species/species_service.dart';
import 'package:earth_nova/features/achievements/models/achievement.dart';
import 'package:earth_nova/features/achievements/models/achievement_state.dart';
import 'package:earth_nova/features/achievements/providers/achievement_provider.dart';
import 'package:earth_nova/features/achievements/screens/achievement_screen.dart';
import 'package:earth_nova/features/discovery/providers/discovery_provider.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a fully-populated [AchievementsState] with the first two achievements
/// unlocked and the rest locked.
AchievementsState _buildMixedState() {
  final map = <AchievementId, AchievementProgress>{};
  final ids = AchievementId.values;
  for (var i = 0; i < ids.length; i++) {
    final id = ids[i];
    final def = kAchievementDefinitions[id]!;
    final isUnlocked = i < 2;
    map[id] = AchievementProgress(
      id: id,
      currentValue: isUnlocked ? def.targetValue : (def.targetValue ~/ 2),
      targetValue: def.targetValue,
      isUnlocked: isUnlocked,
      unlockedAt: isUnlocked
          ? DateTime(2024, 6, i + 1) // newest first: june 2, then june 1
          : null,
    );
  }
  // Adjust so unlock dates produce deterministic order: first id latest.
  final firstId = ids[0];
  final secondId = ids[1];
  map[firstId] = map[firstId]!.copyWith(unlockedAt: DateTime(2024, 6, 2));
  map[secondId] = map[secondId]!.copyWith(unlockedAt: DateTime(2024, 6, 1));
  return AchievementsState(achievements: map);
}

/// Pumps the [AchievementScreen] with an optional pre-loaded [AchievementsState].
Future<void> _pumpScreen(
  WidgetTester tester, {
  AchievementsState? initialState,
}) async {
  final container = ProviderContainer(
    overrides: [
      speciesServiceProvider.overrideWith(
        (_) => SpeciesService([
          FaunaDefinition(
            id: 'fauna_vulpes_vulpes',
            displayName: 'Red Fox',
            scientificName: 'Vulpes vulpes',
            taxonomicClass: 'Mammalia',
            continents: [Continent.northAmerica],
            habitats: [Habitat.forest],
            rarity: IucnStatus.leastConcern,
          ),
        ]),
      ),
    ],
  );
  addTearDown(container.dispose);

  if (initialState != null) {
    container.read(achievementProvider.notifier).loadState(initialState);
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AchievementScreen()),
    ),
  );

  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AchievementScreen', () {
    testWidgets('renders without error', (tester) async {
      await _pumpScreen(tester);
      expect(find.byType(AchievementScreen), findsOneWidget);
    });

    testWidgets('shows "Achievements" title in AppBar', (tester) async {
      await _pumpScreen(tester);
      expect(find.text('Achievements'), findsOneWidget);
    });

    testWidgets('shows unlocked count header with correct format',
        (tester) async {
      final state = _buildMixedState();
      await _pumpScreen(tester, initialState: state);

      final total = AchievementId.values.length;
      expect(find.text('2 / $total Unlocked'), findsOneWidget);
    });

    testWidgets('shows "0 / N Unlocked" when nothing unlocked', (tester) async {
      await _pumpScreen(tester);
      final total = AchievementId.values.length;
      expect(find.text('0 / $total Unlocked'), findsOneWidget);
    });

    testWidgets('shows checkmark icon for unlocked achievements',
        (tester) async {
      final state = _buildMixedState();
      await _pumpScreen(tester, initialState: state);

      // At least one check_circle_rounded icon should be present for unlocked items.
      expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);
    });

    testWidgets('shows lock icon for locked achievements', (tester) async {
      final state = _buildMixedState();
      await _pumpScreen(tester, initialState: state);

      // There are locked achievements so at least one lock icon.
      expect(find.byIcon(Icons.lock_outline_rounded), findsWidgets);
    });

    testWidgets('shows progress bars for locked achievements', (tester) async {
      final state = _buildMixedState();
      await _pumpScreen(tester, initialState: state);

      // LinearProgressIndicator is used for both the header bar and the per-item
      // progress bars for locked achievements.
      expect(find.byType(LinearProgressIndicator), findsWidgets);
    });

    testWidgets('shows achievement titles in the list', (tester) async {
      await _pumpScreen(tester);

      // First Steps should be in the initial (all-locked) list somewhere.
      // SliverList renders visible items — scroll may be needed for all, but
      // at least the first few should be present.
      expect(find.byType(ListView).evaluate().isEmpty, isTrue);
      // Verify at least one definition title is visible in the rendered list.
      final anyTitle = kAchievementDefinitions.values
          .map((d) => d.title)
          .any((t) => find.text(t).evaluate().isNotEmpty);
      expect(anyTitle, isTrue);
    });

    testWidgets('unlocked achievements shown before locked ones',
        (tester) async {
      final state = _buildMixedState();
      await _pumpScreen(tester, initialState: state);

      // Find the vertical positions of the check (unlocked) and lock (locked) icons.
      final checkFinders = find.byIcon(Icons.check_circle_rounded);
      final lockFinders = find.byIcon(Icons.lock_outline_rounded);

      if (checkFinders.evaluate().isNotEmpty &&
          lockFinders.evaluate().isNotEmpty) {
        final checkTop =
            tester.getTopLeft(checkFinders.first).dy;
        final lockTop =
            tester.getTopLeft(lockFinders.first).dy;
        // Unlocked items come first → their icon tops are higher (smaller dy).
        expect(checkTop, lessThan(lockTop));
      }
    });

    testWidgets('shows "All achievements complete!" when all unlocked',
        (tester) async {
      // Build an all-unlocked state.
      final map = <AchievementId, AchievementProgress>{};
      for (final id in AchievementId.values) {
        final def = kAchievementDefinitions[id]!;
        map[id] = AchievementProgress(
          id: id,
          currentValue: def.targetValue,
          targetValue: def.targetValue,
          isUnlocked: true,
          unlockedAt: DateTime(2024, 6, 1),
        );
      }
      final allUnlocked = AchievementsState(achievements: map);
      await _pumpScreen(tester, initialState: allUnlocked);

      expect(find.text('All achievements complete!'), findsOneWidget);
    });
  });
}
