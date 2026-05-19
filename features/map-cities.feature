@capability.map @feature.cities
Feature: Cities
  Cities are the territory scale where district progress becomes civic identity.
  They help the player see that everyday walks are accumulating into a city atlas.

  Scenario: Cities roll up district progress
    Given the player has explored map cells across one or more districts in a city
    When they view the city scope
    Then the city should show district rollups, explored coverage, and city-level progress
    And it should make clear which local areas are familiar versus still unknown

  Scenario: Cities support choosing the next exploration area
    Given the player is browsing city scope
    When some districts have frontier or low explored progress
    Then the city view should help the player choose a nearby area to explore next
    And the suggestion should remain a soft pull rather than a chore checklist
