@capability.progression-permanence @feature.sanctuary
Feature: Sanctuary
  Progression-Permanence needs a concrete sanctuary feature for the persistent
  personal base or world where committed finds become visible growth.

  Scenario: Sanctuary defines its app section
    Given Sanctuary belongs to the Progression-Permanence capability
    When the feature is expanded beyond this stub
    Then it should specify sanctuary view, placement model, growth state, and placed-find details

  @action.open-sanctuary
  Scenario: Player opens the Sanctuary
    Given the player has a Sanctuary
    When the player opens the Sanctuary
    Then the persistent base should be visible without changing placement state

  @action.place-find-in-sanctuary
  Scenario: Player places a find in the Sanctuary
    Given the player owns a find eligible for Sanctuary placement
    When the player places the find in the Sanctuary
    Then the placement should be committed into the player's persistent sanctuary state
