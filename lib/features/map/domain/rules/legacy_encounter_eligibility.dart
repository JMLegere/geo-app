import 'package:earth_nova/core/domain/rules/condition.dart';

/// Compatibility inputs for the pre-versioned encounter computation path.
///
/// These fields preserve current beta behavior while the authored Encounter
/// rules are introduced. They are not canonical Condition kinds and must not
/// be reused as implicit product policy.
final class LegacyEncounterEligibilityContext {
  const LegacyEncounterEligibilityContext({
    required this.isFirstVisit,
    required this.hasLegacyLoot,
  });

  final bool isFirstVisit;
  final bool hasLegacyLoot;
}

/// Compatibility leaf that reads the existing first-visit input.
final class LegacyFirstVisitCondition
    extends Condition<LegacyEncounterEligibilityContext> {
  const LegacyFirstVisitCondition();

  @override
  bool evaluate(LegacyEncounterEligibilityContext context) =>
      context.isFirstVisit;
}

/// Compatibility leaf that reads the existing daily-loot input.
final class LegacyLootAvailableCondition
    extends Condition<LegacyEncounterEligibilityContext> {
  const LegacyLootAvailableCondition();

  @override
  bool evaluate(LegacyEncounterEligibilityContext context) =>
      context.hasLegacyLoot;
}

/// Reproduces the current first-visit-or-loot eligibility rule explicitly.
Condition<LegacyEncounterEligibilityContext>
    legacyEncounterEligibilityCondition() =>
        AnyCondition<LegacyEncounterEligibilityContext>(const [
          LegacyFirstVisitCondition(),
          LegacyLootAvailableCondition(),
        ]);
