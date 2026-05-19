@capability.map @feature.world
Feature: World
  World is the lifetime atlas. It lets the player zoom out from today's walk and
  see that many small real-world movements have become a global footprint.

  Scenario: World scope shows lifetime footprint
    Given the player has explored map cells across territories
    When they view the world scope
    Then the world should show the player's broad explored footprint and top-level territory progress
    And it should keep the experience personal rather than becoming a generic map app

  Scenario: World scope motivates returning to the local map
    Given the player is viewing world scope
    When they inspect unexplored or lightly explored regions
    Then the Map should create curiosity about future movement
    And the player should always be able to return to the live GPS-level map
