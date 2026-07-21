@capability.progression-permanence @feature.sanctuary
Feature: Home
  Status: The sanctuary feature tag and action identifiers preserve legacy
  evidence. The approved target gives every Player exactly one Home; Home
  Module and Item-placement behavior remain unresolved.

  Scenario: Home is one persistent identity
    Given a Player has persistent base state
    When the approved target is described
    Then that Player has exactly one Home
    And relocation, upgrades, or module changes do not create additional Homes

  @action.open-sanctuary
  @action.place-find-in-sanctuary
  Scenario: Legacy Home action identifiers are explicitly gated
    Given the legacy action identifiers remain for evidence compatibility
    When their catalog entries are read
    Then they must not claim implemented Home Module or Item-placement behavior
