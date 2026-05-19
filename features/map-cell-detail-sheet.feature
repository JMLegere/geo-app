@capability.map @feature.map-cell-detail-sheet
Feature: Map Cell Detail Sheet
  The Map Cell Detail Sheet describes the current Voronoi map cell. It should make
  cell entry inspectable before discovery, pack, or collection systems take over.

  Scenario: First entry acknowledges a Voronoi map cell
    Given the player crosses a border into a map cell they have not visited before
    When the map cell detail sheet is shown
    Then the sheet should describe the current map cell context
    And it should communicate that this is a first entry without overclaiming a discovery reward

  Scenario: Revisits preserve continuity without over-rewarding
    Given the player crosses a border into a map cell they have already explored
    When the map cell detail sheet is shown
    Then the sheet should emphasize visit history, footprint, and current context
    And it should avoid replaying the first-entry reward treatment

  Scenario: The sheet hands off without owning downstream systems
    Given the current map cell is eligible for finds, identification, field guide updates, or world events
    When the player inspects the map cell detail sheet
    Then the sheet may expose affordances into those systems
    But ownership of discovery, identification, pack, and field guide outcomes remains outside the Map

  Scenario: First slice detail explains cell before reward
    Given a first-visit map cell event has just revealed fog
    When the map cell detail sheet appears in the first playable slice
    Then the sheet should explain the current map cell, territory context, and visit status first
    And any find, identification, pack, or field guide affordance should be secondary handoff

  Scenario: First-slice sheet has technical field-note anatomy
    Given the map cell detail sheet opens from a current or entered map cell
    When the sheet renders its first-slice content
    Then it should show map cell heading, status pill, territory context, visit facts, and fog/progress note
    And any downstream handoff should appear as secondary context rather than the main reward

  Scenario: Detail inspection is non-mutating by default
    Given the player opens the first-slice map cell detail sheet
    When they read map cell status, territory context, visit facts, and fog progress
    Then the sheet should not mutate pack, field guide, identification, or discovery state
    And any future mutation should require an explicit downstream handoff action

  Scenario: Paused inspection shows paused status without fake progress
    Given exploration is browse-only or paused while the player inspects the current map cell
    When the map cell detail sheet is shown
    Then the sheet may show current context and a paused status pill
    And it should not imply that movement is currently counting toward new map cell progress

  @action.inspect-map-cell
  Scenario: Player inspects a map cell
    Given a map cell is visible or current
    When the player opens the map cell detail sheet
    Then the sheet should show read-only map cell context, visit facts, territory context, and handoffs
