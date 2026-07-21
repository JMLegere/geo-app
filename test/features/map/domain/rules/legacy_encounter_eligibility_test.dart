import 'package:earth_nova/features/map/domain/rules/legacy_encounter_eligibility.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('legacy encounter eligibility compatibility inputs', () {
    test('first visit condition reads only the first-visit input', () {
      const condition = LegacyFirstVisitCondition();

      expect(
        condition.evaluate(
          const LegacyEncounterEligibilityContext(
            isFirstVisit: true,
            hasLegacyLoot: false,
          ),
        ),
        isTrue,
      );
      expect(
        condition.evaluate(
          const LegacyEncounterEligibilityContext(
            isFirstVisit: false,
            hasLegacyLoot: true,
          ),
        ),
        isFalse,
      );
    });

    test('legacy loot condition reads only the compatibility loot input', () {
      const condition = LegacyLootAvailableCondition();

      expect(
        condition.evaluate(
          const LegacyEncounterEligibilityContext(
            isFirstVisit: false,
            hasLegacyLoot: true,
          ),
        ),
        isTrue,
      );
      expect(
        condition.evaluate(
          const LegacyEncounterEligibilityContext(
            isFirstVisit: true,
            hasLegacyLoot: false,
          ),
        ),
        isFalse,
      );
    });

    test('compatibility rule preserves first-visit-or-loot behavior', () {
      final condition = legacyEncounterEligibilityCondition();

      expect(
        condition.evaluate(
          const LegacyEncounterEligibilityContext(
            isFirstVisit: true,
            hasLegacyLoot: false,
          ),
        ),
        isTrue,
      );
      expect(
        condition.evaluate(
          const LegacyEncounterEligibilityContext(
            isFirstVisit: false,
            hasLegacyLoot: true,
          ),
        ),
        isTrue,
      );
      expect(
        condition.evaluate(
          const LegacyEncounterEligibilityContext(
            isFirstVisit: false,
            hasLegacyLoot: false,
          ),
        ),
        isFalse,
      );
    });
  });
}
