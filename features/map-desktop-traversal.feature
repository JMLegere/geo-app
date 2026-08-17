@capability.map @feature.desktop-traversal
Feature: Desktop Traversal
  Desktop Mode changes Player Position input only; Cell Visit and Encounter rules remain shared.

  Scenario: Desktop keyboard movement shares the ordinary exploration loop
    Given Desktop controls are unavailable
    When the Map opens without Desktop controls
    Then Desktop Mode is unavailable and GPS remains the Player Position input
    Given Desktop controls are available and Desktop Mode defaults enabled for the deployment and authenticated Player
    And no saved Player Position exists for that deployment and Player
    When the Desktop Map opens
    Then Player Position starts at 45.9636, -66.6431
    And native mouse click, wheel zoom, and drag pan remain available
    When the focused player presses ArrowRight and desktop movement ends
    Then Player Position moves through the ordinary location path
    And crossing a Cell border records an ordinary Cell Visit
    And the Visit may create one ordinary Encounter
    And neither the Visit nor Encounter records desktop provenance
    When a modal holds focus and the player presses ArrowUp
    Then Player Position does not change
    When Desktop Mode is disabled and the focused player presses ArrowUp
    Then Player Position does not change
    When the Desktop Player Position is persisted and the Map reloads for the same deployment and Player
    Then the canonical Player Position is restored
