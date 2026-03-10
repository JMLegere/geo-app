import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/achievements/models/achievement.dart';

void main() {
  group('AchievementDefinition registry', () {
    test('every AchievementId has a definition in the registry', () {
      for (final id in AchievementId.values) {
        expect(
          kAchievementDefinitions.containsKey(id),
          isTrue,
          reason: '$id is missing from kAchievementDefinitions',
        );
      }
    });

    test('registry contains no extra (unmapped) entries', () {
      expect(
        kAchievementDefinitions.length,
        equals(AchievementId.values.length),
      );
    });

    test('all definitions have non-empty title', () {
      for (final def in kAchievementDefinitions.values) {
        expect(
          def.title.trim().isNotEmpty,
          isTrue,
          reason: '${def.id} has an empty title',
        );
      }
    });

    test('all definitions have non-empty description', () {
      for (final def in kAchievementDefinitions.values) {
        expect(
          def.description.trim().isNotEmpty,
          isTrue,
          reason: '${def.id} has an empty description',
        );
      }
    });

    test('all definitions have non-empty icon', () {
      for (final def in kAchievementDefinitions.values) {
        expect(
          def.icon.trim().isNotEmpty,
          isTrue,
          reason: '${def.id} has an empty icon',
        );
      }
    });

    test('all target values are positive', () {
      for (final def in kAchievementDefinitions.values) {
        expect(
          def.targetValue > 0,
          isTrue,
          reason:
              '${def.id} has targetValue=${def.targetValue} which is not positive',
        );
      }
    });

    test('definition id field matches map key', () {
      for (final entry in kAchievementDefinitions.entries) {
        expect(
          entry.value.id,
          equals(entry.key),
          reason: 'Definition id mismatch for key ${entry.key}',
        );
      }
    });
  });

  group('Specific achievement definitions', () {
    test('firstSteps has targetValue 1', () {
      expect(
        kAchievementDefinitions[AchievementId.firstSteps]!.targetValue,
        equals(1),
      );
    });

    test('explorer has targetValue 10', () {
      expect(
        kAchievementDefinitions[AchievementId.explorer]!.targetValue,
        equals(10),
      );
    });

    test('cartographer has targetValue 50', () {
      expect(
        kAchievementDefinitions[AchievementId.cartographer]!.targetValue,
        equals(50),
      );
    });

    test('dedicated has targetValue 7', () {
      expect(
        kAchievementDefinitions[AchievementId.dedicated]!.targetValue,
        equals(7),
      );
    });

    test('devoted has targetValue 30', () {
      expect(
        kAchievementDefinitions[AchievementId.devoted]!.targetValue,
        equals(30),
      );
    });

    test('marathon has targetValue 10', () {
      expect(
        kAchievementDefinitions[AchievementId.marathon]!.targetValue,
        equals(10),
      );
    });

    test('restorer has targetValue 5', () {
      expect(
        kAchievementDefinitions[AchievementId.restorer]!.targetValue,
        equals(5),
      );
    });
  });
}
