import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/achievements/models/achievement.dart';
import 'package:earth_nova/features/achievements/models/achievement_state.dart';
import 'package:earth_nova/features/achievements/services/achievement_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Returns a fully-initialised `AchievementsState` with all achievements
/// locked and at zero progress (mirroring what `AchievementNotifier.build`
/// produces).
AchievementsState _initialState() {
  final map = <AchievementId, AchievementProgress>{};
  for (final id in AchievementId.values) {
    final def = kAchievementDefinitions[id]!;
    map[id] = AchievementProgress(
      id: id,
      currentValue: 0,
      targetValue: def.targetValue,
    );
  }
  return AchievementsState(achievements: map);
}

/// Minimal [AchievementContext] with all values defaulting to zero.
AchievementContext _ctx({
  int cellsObserved = 0,
  int speciesCollected = 0,
  int currentStreak = 0,
  double totalDistanceKm = 0.0,
  Map<String, int>? collectedByHabitat,
  Map<String, int>? totalByHabitat,
}) {
  return AchievementContext(
    cellsObserved: cellsObserved,
    speciesCollected: speciesCollected,
    currentStreak: currentStreak,
    totalDistanceKm: totalDistanceKm,
    collectedByHabitat: collectedByHabitat ?? const {},
    totalByHabitat: totalByHabitat ?? const {},
  );
}

const _service = AchievementService();
final _fixedNow = DateTime(2024, 6, 15, 12);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AchievementService.evaluate — cell achievements', () {
    test('"First Steps" unlocks when cellsObserved == 1', () {
      final before = _initialState();
      final after = _service.evaluate(
        before,
        _ctx(cellsObserved: 1),
        now: _fixedNow,
      );
      final progress = after.achievements[AchievementId.firstSteps]!;
      expect(progress.isUnlocked, isTrue);
      expect(progress.unlockedAt, equals(_fixedNow));
    });

    test('"First Steps" does NOT unlock when cellsObserved == 0', () {
      final before = _initialState();
      final after = _service.evaluate(before, _ctx(cellsObserved: 0));
      expect(after.achievements[AchievementId.firstSteps]!.isUnlocked, isFalse);
    });

    test('"Explorer" unlocks at exactly 10 cells', () {
      final before = _initialState();
      final after =
          _service.evaluate(before, _ctx(cellsObserved: 10), now: _fixedNow);
      expect(after.achievements[AchievementId.explorer]!.isUnlocked, isTrue);
    });

    test('"Explorer" does NOT unlock at 9 cells', () {
      final before = _initialState();
      final after = _service.evaluate(before, _ctx(cellsObserved: 9));
      expect(after.achievements[AchievementId.explorer]!.isUnlocked, isFalse);
    });

    test('"Cartographer" unlocks at exactly 50 cells', () {
      final before = _initialState();
      final after =
          _service.evaluate(before, _ctx(cellsObserved: 50), now: _fixedNow);
      expect(
          after.achievements[AchievementId.cartographer]!.isUnlocked, isTrue);
    });

    test('progress tracking: "Explorer" shows 3/10 at 3 cells', () {
      final before = _initialState();
      final after = _service.evaluate(before, _ctx(cellsObserved: 3));
      final p = after.achievements[AchievementId.explorer]!;
      expect(p.currentValue, equals(3));
      expect(p.targetValue, equals(10));
      expect(p.progressFraction, closeTo(0.3, 0.0001));
    });
  });

  group('AchievementService.evaluate — species achievements', () {
    test('"Naturalist" unlocks at exactly 5 species', () {
      final before = _initialState();
      final after =
          _service.evaluate(before, _ctx(speciesCollected: 5), now: _fixedNow);
      expect(after.achievements[AchievementId.naturalist]!.isUnlocked, isTrue);
    });

    test('"Naturalist" does NOT unlock at 4 species', () {
      final before = _initialState();
      final after = _service.evaluate(before, _ctx(speciesCollected: 4));
      expect(after.achievements[AchievementId.naturalist]!.isUnlocked, isFalse);
    });

    test('"Biologist" unlocks at 15 species', () {
      final before = _initialState();
      final after = _service.evaluate(
        before,
        _ctx(speciesCollected: 15),
        now: _fixedNow,
      );
      expect(after.achievements[AchievementId.biologist]!.isUnlocked, isTrue);
    });

    test('"Taxonomist" unlocks at 50 species', () {
      final before = _initialState();
      final after = _service.evaluate(
        before,
        _ctx(speciesCollected: 50),
        now: _fixedNow,
      );
      expect(after.achievements[AchievementId.taxonomist]!.isUnlocked, isTrue);
    });
  });

  group('AchievementService.evaluate — streak achievements', () {
    test('"Dedicated" unlocks at exactly 7-day streak', () {
      final before = _initialState();
      final after = _service.evaluate(
        before,
        _ctx(currentStreak: 7),
        now: _fixedNow,
      );
      expect(after.achievements[AchievementId.dedicated]!.isUnlocked, isTrue);
    });

    test('"Dedicated" does NOT unlock at 6 days', () {
      final before = _initialState();
      final after = _service.evaluate(before, _ctx(currentStreak: 6));
      expect(after.achievements[AchievementId.dedicated]!.isUnlocked, isFalse);
    });

    test('"Devoted" unlocks at 30-day streak', () {
      final before = _initialState();
      final after = _service.evaluate(
        before,
        _ctx(currentStreak: 30),
        now: _fixedNow,
      );
      expect(after.achievements[AchievementId.devoted]!.isUnlocked, isTrue);
    });
  });

  group('AchievementService.evaluate — distance achievements', () {
    test('"Marathon" unlocks at 10km total distance', () {
      final before = _initialState();
      final after = _service.evaluate(
        before,
        _ctx(totalDistanceKm: 10.0),
        now: _fixedNow,
      );
      expect(after.achievements[AchievementId.marathon]!.isUnlocked, isTrue);
    });

    test('"Marathon" does NOT unlock at 9.9km', () {
      final before = _initialState();
      final after = _service.evaluate(before, _ctx(totalDistanceKm: 9.9));
      expect(after.achievements[AchievementId.marathon]!.isUnlocked, isFalse);
    });

    test('"Marathon" progress reflects floored km', () {
      final before = _initialState();
      final after = _service.evaluate(before, _ctx(totalDistanceKm: 6.7));
      expect(
          after.achievements[AchievementId.marathon]!.currentValue, equals(6));
    });
  });

  group('AchievementService.evaluate — habitat achievements', () {
    test('"Forest Friend" unlocks when all Forest species collected', () {
      final before = _initialState();
      final after = _service.evaluate(
        before,
        _ctx(
          collectedByHabitat: {'Forest': 3},
          totalByHabitat: {'Forest': 3},
        ),
        now: _fixedNow,
      );
      expect(
          after.achievements[AchievementId.forestFriend]!.isUnlocked, isTrue);
    });

    test('"Forest Friend" does NOT unlock when partial Forest species', () {
      final before = _initialState();
      final after = _service.evaluate(
        before,
        _ctx(
          collectedByHabitat: {'Forest': 2},
          totalByHabitat: {'Forest': 3},
        ),
      );
      expect(
          after.achievements[AchievementId.forestFriend]!.isUnlocked, isFalse);
    });

    test('"Forest Friend" does NOT unlock when no Forest species in pool', () {
      final before = _initialState();
      // totalByHabitat omits Forest — no species available.
      final after = _service.evaluate(
        before,
        _ctx(
          collectedByHabitat: {'Forest': 0},
          totalByHabitat: {},
        ),
      );
      expect(
          after.achievements[AchievementId.forestFriend]!.isUnlocked, isFalse);
    });

    test('"Ocean Explorer" unlocks when all Saltwater species collected', () {
      final before = _initialState();
      final after = _service.evaluate(
        before,
        _ctx(
          collectedByHabitat: {'Saltwater': 5},
          totalByHabitat: {'Saltwater': 5},
        ),
        now: _fixedNow,
      );
      expect(
          after.achievements[AchievementId.oceanExplorer]!.isUnlocked, isTrue);
    });
  });

  group('AchievementService — re-trigger prevention', () {
    test('already-unlocked achievement keeps isUnlocked = true on re-evaluate',
        () {
      final initial = _initialState();
      final afterFirst = _service.evaluate(
        initial,
        _ctx(cellsObserved: 1),
        now: _fixedNow,
      );
      // Simulate a second evaluation with same data.
      final afterSecond = _service.evaluate(
        afterFirst,
        _ctx(cellsObserved: 1),
        now: DateTime(2025),
      );
      final p = afterSecond.achievements[AchievementId.firstSteps]!;
      expect(p.isUnlocked, isTrue);
      // unlockedAt should remain from the first unlock, not reset.
      expect(p.unlockedAt, equals(_fixedNow));
    });

    test(
        'unlocked achievement does not appear in findNewUnlocks on re-evaluate',
        () {
      final initial = _initialState();
      final after1 = _service.evaluate(
        initial,
        _ctx(cellsObserved: 1),
        now: _fixedNow,
      );
      final after2 = _service.evaluate(after1, _ctx(cellsObserved: 1));
      final newUnlocks = _service.findNewUnlocks(after1, after2);
      expect(newUnlocks, isEmpty);
    });
  });

  group('AchievementService.findNewUnlocks', () {
    test('returns achievement that was just unlocked', () {
      final before = _initialState();
      final after = _service.evaluate(
        before,
        _ctx(cellsObserved: 1),
        now: _fixedNow,
      );
      final newUnlocks = _service.findNewUnlocks(before, after);
      expect(newUnlocks, contains(AchievementId.firstSteps));
    });

    test('returns empty list when nothing newly unlocked', () {
      final state = _initialState();
      // Evaluate with same (empty) context.
      final after = _service.evaluate(state, _ctx());
      final newUnlocks = _service.findNewUnlocks(state, after);
      expect(newUnlocks, isEmpty);
    });

    test('multiple achievements can unlock simultaneously', () {
      // cellsObserved = 1 unlocks firstSteps; speciesCollected = 5 unlocks naturalist.
      final before = _initialState();
      final after = _service.evaluate(
        before,
        _ctx(cellsObserved: 1, speciesCollected: 5),
        now: _fixedNow,
      );
      final newUnlocks = _service.findNewUnlocks(before, after);
      expect(
          newUnlocks,
          containsAll([
            AchievementId.firstSteps,
            AchievementId.naturalist,
          ]));
    });

    test('returns only newly unlocked (not previously unlocked)', () {
      // Unlock firstSteps in step 1.
      final initial = _initialState();
      final step1 = _service.evaluate(
        initial,
        _ctx(cellsObserved: 1),
        now: _fixedNow,
      );
      // Add speciesCollected=5 to unlock naturalist in step 2.
      final step2 = _service.evaluate(
        step1,
        _ctx(cellsObserved: 1, speciesCollected: 5),
        now: DateTime(2024, 7),
      );
      final newInStep2 = _service.findNewUnlocks(step1, step2);
      expect(newInStep2, contains(AchievementId.naturalist));
      expect(newInStep2, isNot(contains(AchievementId.firstSteps)));
    });
  });
}
