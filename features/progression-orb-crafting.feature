@capability.progression-permanence @feature.orb-crafting
Feature: Orb behavior remains open
  Status: The orb-crafting feature tag and use-orb-on-animal action identifier
  preserve historical evidence only. Orb purpose, consumption, crafting, and
  reroll behavior are unresolved; rarity is not a current mechanic.

  Scenario: Orb does not imply a target mechanic
    Given Orb is an Item Category with explicit Orb Base Items
    When current product evidence is read
    Then it must not claim Orb stacks, currency, crafting, consumption, rerolls, or Release to Wild rewards

  @action.use-orb-on-animal
  Scenario: The legacy Orb action is explicitly gated
    Given the legacy action identifier remains for evidence compatibility
    When its catalog entry is read
    Then it must be marked open rather than an implemented target behavior
