@capability.exploration-discovery-lifecycle @feature.discovery
Feature: Discovery
  Discovery consumes reward-clean Map cell entry truth and resolves whether the
  entered map cell creates no result, a known owned find, or a mystery that can
  later move through Identification. It must not pretend a map-cell entry is a
  completed discovery until acquisition has been committed.

  Scenario: Discovery consumes map-cell entry truth
    Given Map has emitted one eligible map-cell entry event
    And the entry event includes entered cell, first-or-revisit status, timestamp, and territory context
    When Discovery resolves the entry
    Then the resolver should keep the Map entry identity as its correlation id
    And the resolver should add only Discovery outcome fields such as result type, definition id, display name, rarity, and acquisition eligibility
    And the resolver should not mutate fog, visits, or map-cell entry state

  Scenario: First-entry discovery commits acquisition before claiming ownership
    Given a first-visit map-cell entry resolves to an eligible known find
    When Discovery presents the result as found
    Then the owned find should already be committed to Pack state
    And the result should include the owned item id and acquisition cell id
    And the player-facing message may say the find was found or added to the Pack

  Scenario: Acquisition failure does not show a false found message
    Given a map-cell entry resolves to an eligible find
    When Pack acquisition cannot be committed
    Then Discovery should not tell the player that ownership is complete
    And the failure should be observable with the map-cell entry correlation id
    And the result may be retried or withheld until ownership can be verified

  Scenario: Revisit entries can stay quiet without breaking exploration
    Given a player re-enters a previously visited map cell
    When the Discovery resolver finds no daily or contextual result
    Then no discovery result should be shown
    And Pack state should remain unchanged
    And Map entry feedback may still acknowledge the revisit as exploration continuity

  Scenario: Discovery result telemetry links entry, resolver, acquisition, and acknowledgement
    Given a Discovery result is resolved from a map-cell entry
    When acquisition succeeds and the player acknowledges the result
    Then telemetry should link map-cell entry id, discovery result id, owned item id, and acknowledgement action
    And each step should remain queryable without relying on player-visible copy

  @action.acknowledge-discovery-result
  Scenario: Player acknowledges a committed discovery result
    Given a discovery result has been resolved and any eligible ownership mutation has completed
    When the player acknowledges the discovery result
    Then the result should leave the active overlay
    And the already-owned find should remain visible through Pack