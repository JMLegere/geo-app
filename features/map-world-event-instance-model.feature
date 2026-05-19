@capability.map @feature.world-event-instance-model
Feature: World Event Instance Model
  The world event instance model describes optional, time-sensitive map happenings
  such as Wildlife Migration. It keeps serendipity grounded in location, time, and
  eligibility.

  Scenario: Event instances have enough identity to be playable
    Given a world event is generated for the map
    When the Map stores or receives the event instance
    Then the instance should include event type, territory scope, active window, map cue geometry, and eligibility rules
    And the instance should be auditable enough to explain why the player could see it

  Scenario: Expired events leave the playable map cleanly
    Given a world event instance has passed its active window
    When the map frame refreshes event state
    Then expired event cues should leave the active map
    And historical or recap treatment should happen outside the live cue layer

  Scenario: Event instances hand off to event-specific systems
    Given the player inspects an active Wildlife Migration event cue
    When the event-specific experience opens
    Then the instance should provide the event identity and context needed by that downstream system
    But the generic Map model should not own the full event reward logic
