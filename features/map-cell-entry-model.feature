@capability.map @feature.cell-entry-model
Feature: Map Cell Entry Model
  Map-cell entry is the detection and product moment. Voronoi border crossing is
  the geometric implementation detail used when movement enters a different map
  cell. The model emits one reward-clean map-cell entry identity for visits, fog,
  entry feedback, and downstream Discovery correlation.

  Scenario: Entering a different map cell creates one entry event
    Given exploration is eligible and the gameplay marker is inside a known map cell
    When movement places the marker inside a different Voronoi map cell
    Then the Map should produce one map-cell entry event
    And the event should include previous cell, entered cell, first-visit status, and territory context
    And any border-crossing fields should be treated as technical correlation details, not player-facing reward truth

  Scenario: Re-entering an explored map cell is quieter than first entry
    Given the player has already visited the current map cell before
    When they enter that map cell again
    Then the entry model should record the revisit
    And downstream surfaces should treat it as continuity rather than a fresh reveal moment

  Scenario: The first slice emits one cell entry moment
    Given the player enters a first-visit map cell during the first playable slice
    When the entry model creates the map-cell entry event
    Then fog reveal, map cell acknowledgement, and visit recording should share the same entry identity
    And downstream discovery systems may consume that identity later without replaying the entry

  Scenario: Entry identity carries enough context
    Given an eligible marker enters a different map cell
    When the entry event is emitted
    Then it should include map-cell entry id, previous cell, entered cell, first-or-revisit status, and timestamp
    And that context should be enough for fog, entry feedback, visit recording, Discovery handoff, and observability to agree

  Scenario: Entry payload stays reward-clean
    Given the first-slice map-cell entry event is created before downstream discovery systems run
    When the event is passed to fog, feedback, detail, observability, and Discovery surfaces
    Then it should not include species, item, pack, or field guide mutation payloads
    And those downstream systems should attach their own reward results later

  Scenario: Same-cell movement emits no entry event
    Given the gameplay marker remains inside the same map cell
    When the player moves without entering a different Voronoi map cell
    Then the entry model should emit no map-cell entry event
    And visit, fog, entry feedback, and Discovery systems should receive no new entry identity

  @action.cross-map-cell-border
  Scenario: Player enters a different map cell
    Given the player marker is trusted and exploration is eligible
    When the player enters a different Voronoi map cell
    Then the Map should emit one map-cell entry event and update visits and fog through the normal gates