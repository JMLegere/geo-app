@capability.map @feature.states
Feature: States
  States or provinces are the travel-scale passport layer. They let city progress
  become regional exploration without losing the cozy solo footprint.

  Scenario: States roll up city progress
    Given the player has explored map cells across cities in a state or province
    When they view the state scope
    Then the state should show city rollups and regional explored progress
    And it should preserve the link back to the Voronoi map cells that created that progress

  Scenario: States make travel feel meaningful
    Given the player visits a new city or district inside a state
    When state progress changes
    Then the state view should be able to acknowledge regional growth
    And the player should feel that travel expanded their world beyond their usual local map
