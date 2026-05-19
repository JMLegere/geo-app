@capability.progression-permanence @feature.conservation
Feature: Conservation
  Progression-Permanence needs a concrete conservation feature that turns learned
  species/place knowledge into stewardship meaning and goals.

  Scenario: Conservation defines its game system
    Given Conservation belongs to the Progression-Permanence capability
    When the feature is expanded beyond this stub
    Then it should specify threat status meaning, stewardship goals, species/place care context, and conservation progress

  @action.view-conservation-goal
  Scenario: Player views a conservation goal
    Given a conservation goal exists
    When the player views the conservation goal
    Then stewardship context, threat status meaning, and goal progress should be visible without applying a contribution

  @action.contribute-to-conservation
  Scenario: Player contributes to conservation
    Given the player has an eligible stewardship contribution
    When the player contributes to conservation
    Then the contribution should be committed to the conservation goal or species/place care context
