@capability.map @feature.districts
Feature: Districts
  Districts are the first territory scale above the live GPS map. They make a
  walk feel local: my nearby map cells are becoming my neighborhood-sized footprint.

  Scenario: Districts summarize nearby explored map cells
    Given the player has visited map cells inside a district
    When they view the district scope
    Then the district should show explored footprint, unvisited frontier, and local progress
    And it should preserve the sense that the district is made from real entered map cells

  Scenario: Districts connect map movement to local pride
    Given the player crosses a border into a first-visit map cell inside a district
    When district progress changes
    Then the Map should be able to show a small local progress delta
    And the delta should make the walk feel like it improved the player's little world
