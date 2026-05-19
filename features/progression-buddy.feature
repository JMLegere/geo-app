@capability.progression-permanence @feature.buddy
Feature: Buddy
  Progression-Permanence needs a concrete buddy feature for selecting one active
  companion and caring for it through tamagotchi-style loops.

  Scenario: Buddy defines its app section
    Given Buddy belongs to the Progression-Permanence capability
    When the feature is expanded beyond this stub
    Then it should specify buddy slot, buddy map presence, buddy care state, and buddy care panel

  @action.select-buddy
  Scenario: Player selects a buddy
    Given the player has a find eligible to become a buddy
    When the player selects a buddy
    Then that companion should become the active buddy for presence, care, and future map expression

  @action.care-for-buddy
  Scenario: Player cares for a buddy
    Given the player has an active buddy
    When the player performs a buddy care interaction
    Then the care interaction should update the active buddy state
