@capability.map @feature.cell-border-crossing-model
Feature: Cell Border Crossing Model
  The Map cell border crossing model turns physical movement across a Voronoi map
  cell border into one auditable cell-entry event. It is the technical source
  of truth for cell entry, visit recording, fog recompute, and entry feedback.

  Scenario: Crossing a border into a new map cell creates one event
    Given exploration is eligible and the gameplay marker is inside a known map cell
    When the marker crosses a Voronoi map cell border into a different map cell
    Then the Map should produce one cell-border-crossing event
    And the event should include previous cell, entered cell, first-visit status, and territory context


  Scenario: Re-entering an explored map cell is quieter than first entry
    Given the player has already visited the current map cell before
    When they cross a border back into that map cell
    Then the border crossing model should record the revisit
    And downstream surfaces should treat it as continuity rather than a fresh reveal moment

  Scenario: The first slice emits one cell entry moment
    Given the player crosses a border into a first-visit map cell during the first playable slice
    When the border crossing model creates the cell entry event
    Then fog reveal, map cell acknowledgement, and visit recording should share the same border crossing identity
    And downstream discovery systems may consume that identity later without replaying the border crossing

  Scenario: Border crossing identity carries enough context
    Given an eligible marker crosses a border from one map cell into another
    When the border crossing event is emitted
    Then it should include border crossing id, previous cell, entered cell, first-or-revisit status, and timestamp
    And that context should be enough for fog, entry feedback, visit recording, and observability to agree

  Scenario: Border crossing payload stays reward-clean
    Given the first-slice border crossing event is created before downstream discovery systems run
    When the event is passed to fog, feedback, detail, and observability surfaces
    Then it should not include species, item, pack, or field guide mutation payloads
    And those downstream systems should attach their own reward results later

  Scenario: Same-cell movement emits no border crossing event
    Given the gameplay marker remains inside the same map cell
    When the player moves without crossing a Voronoi map cell border
    Then the border crossing model should emit no border crossing event
    And visit, fog, and entry feedback systems should receive no new border crossing identity

  @action.cross-map-cell-border
  Scenario: Player crosses a map cell border
    Given the player marker is trusted and exploration is eligible
    When the player crosses a Voronoi map cell border
    Then the Map should emit one cell border crossing event and update visits and fog through the normal gates
