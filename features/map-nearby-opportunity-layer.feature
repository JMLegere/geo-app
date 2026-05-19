@capability.map @feature.nearby-opportunity-layer
Feature: Nearby Opportunity Layer
  The Map nearby opportunity layer answers where should I go next. It
  should create a soft pull toward exploration without becoming a chore list.

  Scenario: Reachable frontier creates soft direction
    Given there are reachable frontier map cells near the player
    When the map frame is steady and exploration is eligible
    Then the opportunity layer should hint at nearby map cells worth walking toward
    And the hint should stay spatial and lightweight rather than demanding completion

  Scenario: Opportunity hints respect fog semantics
    Given a nearby map cell is still frontier
    When the opportunity layer represents that map cell
    Then it may signal possibility or presence
    But it should not reveal specific hidden details before the player crosses a border into the map cell

  Scenario: Untrusted location suppresses movement prompts
    Given exploration is paused because location is untrusted
    When the player views the map
    Then nearby opportunity hints should avoid implying that walking now will produce reliable progress
    And the map should prefer browse/context affordances until trust recovers

  @action.inspect-nearby-opportunity
  Scenario: Player inspects a nearby opportunity
    Given a nearby opportunity cue is visible on the Map
    When the player inspects the opportunity
    Then the Map should explain the reachable cue without forcing a quest or reward
