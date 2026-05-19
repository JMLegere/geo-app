@capability.map @feature.territory-navigation
Feature: Territory Navigation
  Territory navigation connects the intimate GPS-level map to the larger world.
  It lets the player understand that a small walk belongs to a district, city,
  state, country, and world-scale footprint.

  Scenario: Pinching out moves through territory scale
    Given the player is viewing the GPS-level map
    When they use the territory navigation gesture or affordance
    Then the Map should move through District, City, State, Country, and World scopes in order
    And each scope should preserve the player's current context inside the larger territory

  Scenario: GPS-level browsing remains movement-first
    Given the player returns to GPS-level scope
    When they are viewing the immediate map around the marker
    Then free panning should not replace physical movement as the way to change the map
    And broader browsing should remain an explicit territory-scale action

  Scenario: The player can return to themselves
    Given the player is browsing a broader territory scope
    When they choose to return to the live map
    Then the Map should restore the GPS-level frame around the gameplay marker
    And the transition should preserve orientation rather than feel like a teleport into an unrelated map

  @action.change-territory-scale
  Scenario: Player changes territory scale
    Given the player is viewing a map scope
    When the player changes territory scale
    Then the Map should move between GPS, District, City, State, Country, and World scopes
