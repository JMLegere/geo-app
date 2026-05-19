@capability.map @feature.fog-state-model
Feature: Fog State Model
  The Map fog model answers where the player is, where they have been,
  and what is just beyond reach. Fog is computed from visits and current marker
  position; it is not a persisted snapshot.

  Scenario: Fog relationships are computed from marker and visits
    Given the player has a current marker map cell and a history of map cell visits
    When the Map computes fog state
    Then the marker map cell should be present
    And previously visited non-current map cells should be explored
    And reachable unvisited neighbors should be frontier
    And everything outside render distance should be beyond

  Scenario: Current presence overrides historical state
    Given the player has visited a map cell before
    When the gameplay marker is currently inside that map cell
    Then the map cell should be treated as present rather than merely explored
    And present state should be available to visual overlay, border crossing acknowledgement, and detail surfaces

  Scenario: Fog state does not duplicate source-of-truth data
    Given visits are the source of exploration history
    When fog is recomputed for a map frame
    Then no separate fog snapshot is required
    And the computed state should be reproducible from marker, visits, and nearby cell geometry

  Scenario: First-slice fog state feeds every surface consistently
    Given a border crossing identity has produced a current map cell and visit result
    When fog relationships are recomputed
    Then the overlay, map cell detail sheet, and entry feedback should read the same present/explored/frontier/beyond result
    And no surface should invent a conflicting relationship state
