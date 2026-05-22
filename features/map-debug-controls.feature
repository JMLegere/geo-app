@capability.map @feature.map-debug-controls
Feature: Map Debug Controls
  Developer-only Map controls let testers move the gameplay marker and inject
  map gestures from on-screen buttons without making debug behavior part of the
  player-facing game loop.

  Scenario: Debug controls require developer mode
    Given developer mode is disabled
    When the player opens the Map
    Then the map debug overlay should not be visible
    And no debug control should be reachable as normal gameplay UI

  Scenario: Player movement buttons simulate marker movement
    Given developer mode is enabled and the map debug overlay is visible
    When the tester taps P↑, P↓, P←, or P→
    Then the location source should switch into simulated-location mode
    And the simulated location should start from the current trusted location or the beta fixture location
    And the Map should process the movement through normal marker, cell detection, border crossing, fog, and visit paths

  Scenario: QA can target a first-visit cell without bypassing gameplay
    Given developer mode is enabled and the map has loaded nearby cell and visit state
    When the tester asks the debug overlay to move to the nearest unvisited map cell
    Then the location source should switch into simulated-location mode at that cell target
    And the Map should still process the movement through normal marker, cell detection, border crossing, fog, visit, and Discovery paths
    And the debug action should record which target cell was requested for observability

  Scenario: Debug player movement is clearly sourced
    Given a debug movement button changes the simulated player location
    When map observability records the movement
    Then the event should identify debug controls as the source
    And it should mark real geo-location as disabled for that update
    And downstream map events should remain traceable to the debug-driven movement

  Scenario: GPS button exits simulated marker control
    Given the tester has moved the player marker with debug controls
    When the tester taps GPS
    Then simulated-location mode should turn off
    And normal GPS permission, current-position, and stream handling should restart
    And stale debug-only border crossings should not replay after GPS resumes

  Scenario: Gesture buttons exercise map interactions
    Given developer mode is enabled and the map debug overlay is visible
    When the tester taps Pinch, Spread, ↑ Up, ↓ Dn, ← L, or → R
    Then the app should inject the corresponding pointer gesture through the normal gesture path
    And map zoom, hierarchy, swipe, or pan behavior should be exercised without a physical multitouch device

  Scenario: Debug controls cannot bypass gameplay gates
    Given a debug control triggers movement or a gesture
    When the Map evaluates readiness, marker trust, exploration eligibility, and border crossing rules
    Then the debug action should use the same gates as the real action
    And debug controls should never grant reward payloads directly
