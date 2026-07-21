@capability.map @feature.cell-entry-model
Feature: Cell Visit evidence and target routing
  Status: The retained map-cell-entry model is legacy implementation evidence.
  The approved target calls the player activity Exploration and records a Cell
  Visit for each eligible Cell entry. A Cell Visit resolves one Selector to an
  explicit None outcome or one Encounter; it is never itself Discovery.

  Scenario: Exploration records one Cell Visit
    Given Exploration is eligible and the Player enters a different Cell
    When the target lifecycle is described
    Then one Cell Visit records the entry
    And that Cell Visit resolves one Selector
    And the resolution creates zero or one Encounter

  Scenario: Legacy border-crossing evidence remains bounded
    Given a Voronoi border-crossing identifier remains in executable evidence
    When the evidence is read
    Then it is only a geometric detection detail
    And it must not imply an Item, Discovery, or mandatory Encounter

  @action.cross-map-cell-border
  Scenario: The legacy action identifier routes to Cell Visit terminology
    Given the action identifier is retained for evidence compatibility
    When its target meaning is described
    Then it records a Cell Visit through Exploration rather than creating Discovery