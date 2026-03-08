import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/achievements/models/achievement.dart';
import 'package:earth_nova/features/achievements/models/achievement_state.dart';

AchievementProgress _makeProgress({
  AchievementId id = AchievementId.explorer,
  int currentValue = 0,
  int targetValue = 10,
  bool isUnlocked = false,
  DateTime? unlockedAt,
}) {
  return AchievementProgress(
    id: id,
    currentValue: currentValue,
    targetValue: targetValue,
    isUnlocked: isUnlocked,
    unlockedAt: unlockedAt,
  );
}

AchievementsState _makeState({
  Map<AchievementId, AchievementProgress>? achievements,
}) {
  final map = achievements ??
      {
        AchievementId.firstSteps: _makeProgress(
          id: AchievementId.firstSteps,
          targetValue: 1,
        ),
        AchievementId.explorer: _makeProgress(
          id: AchievementId.explorer,
          targetValue: 10,
        ),
        AchievementId.naturalist: _makeProgress(
          id: AchievementId.naturalist,
          targetValue: 5,
          isUnlocked: true,
          unlockedAt: DateTime(2024, 6, 1),
        ),
      };
  return AchievementsState(achievements: map);
}

void main() {
  group('AchievementProgress', () {
    test('progressFraction returns 0 when currentValue is 0', () {
      final p = _makeProgress(currentValue: 0, targetValue: 10);
      expect(p.progressFraction, equals(0.0));
    });

    test('progressFraction calculates correct fraction mid-progress', () {
      final p = _makeProgress(currentValue: 3, targetValue: 10);
      expect(p.progressFraction, closeTo(0.3, 0.0001));
    });

    test('progressFraction equals 1.0 exactly at target', () {
      final p = _makeProgress(currentValue: 10, targetValue: 10);
      expect(p.progressFraction, equals(1.0));
    });

    test('progressFraction is capped at 1.0 when currentValue exceeds target',
        () {
      final p = _makeProgress(currentValue: 15, targetValue: 10);
      expect(p.progressFraction, equals(1.0));
    });

    test('progressFraction with target 1 gives 0.0 at 0 and 1.0 at 1', () {
      final p0 = _makeProgress(currentValue: 0, targetValue: 1);
      final p1 = _makeProgress(currentValue: 1, targetValue: 1);
      expect(p0.progressFraction, equals(0.0));
      expect(p1.progressFraction, equals(1.0));
    });

    test('copyWith updates currentValue', () {
      final p = _makeProgress(currentValue: 3, targetValue: 10);
      final updated = p.copyWith(currentValue: 7);
      expect(updated.currentValue, equals(7));
      expect(updated.targetValue, equals(10));
      expect(updated.id, equals(AchievementId.explorer));
    });

    test('copyWith updates isUnlocked', () {
      final p = _makeProgress(isUnlocked: false);
      final unlocked = p.copyWith(isUnlocked: true);
      expect(unlocked.isUnlocked, isTrue);
    });

    test('copyWith clears unlockedAt when clearUnlockedAt is true', () {
      final dt = DateTime(2024, 1, 1);
      final p = _makeProgress(isUnlocked: true, unlockedAt: dt);
      final cleared = p.copyWith(clearUnlockedAt: true);
      expect(cleared.unlockedAt, isNull);
    });
  });

  group('AchievementsState', () {
    test('unlockedIds returns only unlocked achievements', () {
      final state = _makeState();
      expect(state.unlockedIds, equals([AchievementId.naturalist]));
    });

    test('lockedIds returns only locked achievements', () {
      final state = _makeState();
      expect(
        state.lockedIds,
        containsAll([AchievementId.firstSteps, AchievementId.explorer]),
      );
      expect(state.lockedIds, isNot(contains(AchievementId.naturalist)));
    });

    test('unlockedCount returns correct count', () {
      final state = _makeState();
      expect(state.unlockedCount, equals(1));
    });

    test('totalCount returns total number of achievements', () {
      final state = _makeState();
      expect(state.totalCount, equals(3));
    });

    test('unlockedCount is 0 for all-locked state', () {
      final state = AchievementsState(
        achievements: {
          AchievementId.firstSteps: _makeProgress(
            id: AchievementId.firstSteps,
          ),
        },
      );
      expect(state.unlockedCount, equals(0));
    });

    test('copyWith replaces achievements map', () {
      final state = _makeState();
      final newMap = {
        AchievementId.explorer: _makeProgress(
          id: AchievementId.explorer,
          currentValue: 5,
        ),
      };
      final updated = state.copyWith(achievements: newMap);
      expect(updated.achievements[AchievementId.explorer]?.currentValue,
          equals(5));
      expect(updated.achievements.containsKey(AchievementId.firstSteps),
          isFalse);
    });

    test('copyWith with null keeps original achievements', () {
      final state = _makeState();
      final same = state.copyWith();
      expect(same.achievements, equals(state.achievements));
    });
  });
}
