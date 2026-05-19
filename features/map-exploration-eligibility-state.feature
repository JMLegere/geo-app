@capability.map @feature.exploration-eligibility-state
Feature: Exploration Eligibility State
  The Map needs one explicit state model for deciding when movement is
  allowed to create gameplay. This prevents GPS uncertainty from becoming
  semantic, visual, or reward jank.

  Scenario: Eligible movement can mutate exploration progress
    Given location is trusted and the gameplay marker is inside the playable map
    When the marker crosses a Voronoi map cell border
    Then exploration should be eligible to record map cell visits, reveal fog, and hand off to discovery systems

  Scenario: Untrusted movement is browse-only
    Given location is unavailable, inaccurate, or in ring state
    When the player interacts with the map
    Then the player may browse known territory
    But the Map should not record visits, clear fog, or trigger discovery handoffs

  Scenario: Eligibility transitions are observable
    Given exploration eligibility changes between locating, eligible, paused, and recovered
    When the state changes
    Then the transition should carry a clear reason for terminal-agent debugging
    And the UI should explain the practical effect to the player without exposing implementation terms

  Scenario: Eligibility gates every first-slice mutation
    Given the map has marker movement, cell border crossing, fog reveal, map cell acknowledgement, and downstream handoff checks
    When exploration eligibility is browse-only or paused
    Then none of those gameplay mutations should commit from movement
    And the player should still be able to inspect already-known map context

  Scenario: Recovery does not replay paused border crossings
    Given exploration became paused while the marker was untrusted near a map cell border
    When trust later recovers and exploration becomes eligible again
    Then the Map should resume from the current trusted state
    And it should not replay border crossings that were never valid while paused
