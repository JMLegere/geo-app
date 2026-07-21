@capability.exploration-discovery-lifecycle @feature.discovery
Feature: Legacy reward-card evidence and Discovery routing
  Status: This scenario file preserves legacy executable reward-card evidence;
  it is not an implementation of the approved target. In the target,
  Exploration records Cell Visits, a Cell Visit may create one Encounter, and
  Encounter Outcomes may generate Items. Discovery is recorded only on a
  Player's first Identification of a Base Item.

  Scenario: Legacy reward bridge consumes map-cell evidence
    Given Map has emitted one eligible map-cell entry event
    And the entry event includes entered cell, first-or-revisit status, timestamp, and territory context
    When Discovery resolves the entry
    Then the resolver should keep the Map entry identity as its correlation id
    And the legacy resolver should add result type, living specimen category, and reward eligibility
    And the resolver should not mutate fog, visits, or map-cell entry state

  Scenario: Legacy reward bridge commits an Item before presentation
    Given a first-visit map-cell entry resolves to an eligible living specimen reward
    And the reward category is fauna, flora, or fungi
    When Discovery prepares the reward presentation
    Then the owned unidentified find should already be committed to Pack state
    And the reward should include the owned item id, living specimen category, and acquisition cell id
    And the reward modal should present a Slay the Spire-style unidentified card moment
    But it should not reveal the specimen display name before Identification

  Scenario: Legacy reward bridge does not reveal an Item before Identification
    Given a first-visit map-cell entry resolves to a living specimen
    When Discovery commits acquisition
    Then Pack should receive an owned unidentified find rather than a known specimen card
    And no player-facing Discovery reward copy should reveal the specimen display name
    And Identification should be required before Pack treats the specimen as known

  Scenario: Acquisition failure does not show a false reward moment
    Given a map-cell entry resolves to an eligible living specimen reward
    When Pack acquisition cannot be committed
    Then Discovery should not open the reward modal
    And Discovery should not animate a card into the Pack
    And the failure should be observable with the map-cell entry correlation id
    And the result may be retried or withheld until ownership can be verified

  Scenario: Legacy reward bridge can remain quiet on a revisit
    Given a player re-enters a previously visited map cell
    When the Discovery resolver finds no daily or contextual reward
    Then no discovery reward should be shown
    And Pack state should remain unchanged
    And Map entry feedback may still acknowledge the revisit as exploration continuity

  Scenario: Reward modals queue instead of stacking
    Given one committed living specimen reward modal is already active
    And another eligible living specimen reward is committed before the first reward completes
    When Discovery receives the second committed reward
    Then the second reward should be queued behind the active reward
    And only one reward modal should be visible at a time
    And queued rewards should play one at a time without dropping ownership

  Scenario: Legacy reward telemetry links entry, result, Item, continuation, and Pack impact
    Given a Discovery living specimen reward is resolved from a map-cell entry
    When acquisition succeeds and the player continues the reward
    Then telemetry should link map-cell entry id, discovery result id, owned item id, living specimen category, continue action, and Pack impact
    And each step should remain queryable without relying on player-visible copy

  @action.continue-discovery-reward
  Scenario: Legacy action identifier continues a committed reward card
    Given a committed living specimen reward modal is active
    When the player clicks anywhere to continue the discovery reward
    Then the reward card should fly to the Pack target
    And the Pack target should react with a small impact shake when the card lands
    And the reward modal should leave the active overlay
    And the already-owned unidentified find should remain visible through Pack