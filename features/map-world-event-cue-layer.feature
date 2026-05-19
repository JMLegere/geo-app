@capability.map @feature.world-event-cue-layer
Feature: World Event Cue Layer
  The Map event cue layer makes the world feel alive through optional,
  time-sensitive happenings. It should create serendipity without hijacking the
  core map loop.

  Scenario: Active events appear as optional map cues
    Given a world event instance is active near the player's current territory
    When the map frame is steady
    Then the cue layer should show a spatial hint that something unusual is happening
    And the cue should be inspectable without forcing the player into the event

  Scenario: Event cues do not overpower fog and cell border crossing
    Given the player is moving through unrevealed or frontier territory
    When an event cue and fog/crossing feedback are both relevant
    Then the Map should preserve fog reveal and cell border crossing as the primary loop
    And event cues should remain secondary unless the player chooses to inspect them

  Scenario: Wildlife migration uses the cue layer first
    Given a Wildlife Migration event is active
    When the player is close enough to notice it
    Then the cue layer should represent movement, direction, or presence on the map
    But detailed migration outcomes should wait for the event detail or discovery systems

  @action.inspect-world-event-cue
  Scenario: Player inspects a world event cue
    Given a world event cue is visible on the Map
    When the player inspects the cue
    Then the Map should show optional event context while event-specific rewards remain downstream
