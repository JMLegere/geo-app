@capability.progression-permanence @feature.orb-crafting
Feature: Orb Crafting
  Orb Crafting is the PoE-style crafting sink for Orb item stacks. Orbs are
  consumable Pack/inventory resources earned from Release to Wild and spent to
  reroll safe authored attributes on owned animals.

  Scenario: Orb Crafting defines its game system
    Given Orb Crafting belongs to the Progression-Permanence capability
    When the feature is expanded beyond its first design pass
    Then it should specify Orb item-stack ownership, Orb consumption, target animal eligibility, safe reroll bounds, result audit history, and failed-crafting protection

  @action.use-orb-on-animal
  Scenario: Player uses an Orb on an animal
    Given the player owns an Orb item stack and an eligible owned animal
    When the player uses the Orb on that animal
    Then one Orb stack quantity should be consumed exactly once
    And the animal should reroll a trait, personality, or variant within authored safe bounds
    And the original animal instance should remain owned by the player
    And the crafting result should be recorded for audit/history

  Scenario: Orb Crafting protects ineligible targets
    Given the player owns an Orb item stack
    When Orb Crafting evaluates a target animal
    Then released animals should be ineligible
    And animals not owned by the player should be ineligible
    And unidentified animals should be ineligible until identified
