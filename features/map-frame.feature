@capability.map @feature.map-frame
Feature: Map Frame
  The Map Frame is the player's entry into the real-world map.
  It should make the player feel oriented, protected from loading/raw-GPS jank,
  and ready to move before deeper fog, border crossing, or reward systems fire.

  Scenario: The map opens as a trusted map
    Given the player opens the Map tab with usable location access
    When the Map reaches steady state
    Then the camera is framed on the gameplay marker at GPS-level scale
    And the player can read where they are, where they have been, and where they might go next

  Scenario: The map hides raw readiness jank
    Given cells, base map style, location, and overlay paint are still loading
    When the player is waiting for the Map tab to become ready
    Then the map frame should not expose a fog-free map, empty overlay, or raw debug state
    And readiness should show a branded spinning-world loading state until it resolves into either a playable map or an observable load failure

  Scenario: Base map labels stay hidden behind the game layer
    Given the MapLibre base map style has loaded
    When the GPS-level Map becomes playable
    Then base-map text labels should be hidden from the map
    And legal attribution should remain available

  Scenario: The GPS-level view stays intimate
    Given the player is viewing the GPS-level map
    When they want to change what the map shows at that level
    Then physical movement should be the primary way the visible map changes
    And broader territory browsing should happen through explicit scale navigation rather than free panning

  Scenario: First playable slice stays focused
    Given the Map first slice is being designed
    When the map frame coordinates marker trust, cell border crossing, fog reveal, and map cell acknowledgement
    Then the player should get one coherent walking loop before territory dashboards or discovery rewards expand
    And the frame should not require Pack, Identification, Index, or multiplayer systems to feel playable

  Scenario: Readiness contract prevents false playability
    Given the first-slice map requires map style, nearby cells, visit history, location state, and overlay paint
    When any required input is missing or failed
    Then the map frame should keep the player out of fake-ready gameplay
    And it should expose either a coherent spinning-world loading state or an observable failure reason

  Scenario: Steady state waits for map-specific dependencies
    Given map style, nearby cells, visit history, location state, and overlay paint do not become ready at the same time
    When readiness is evaluated for the first playable slice
    Then gameplay should remain non-playable until all required dependencies are coherent
    And the map should not expose fake current-cell, fog, or entry feedback states early

  Scenario: Startup position produces a playable first overlay
    Given nearby cells and a trusted player position are available before Cell entry tracking settles
    When the first fog overlay is prepared
    Then the Cell containing the trusted player position should be presented as Present
    And visible translucent frontier geometry should count as meaningful map content
    But empty, offscreen, or fully opaque unknown geometry should not complete Map readiness

  @action.open-map
  Scenario: Player opens the Map
    Given the player is signed in
    When the player opens the Map tab
    Then the GPS-level Map should become the active play surface
    And opening the Map alone should not grant exploration progress

  @action.read-map-status
  Scenario: Player reads map status
    Given the player is viewing the Map
    When the player reads the status bar or readiness overlay
    Then the Map should explain playability, pending visits, and readiness without mutating progress
