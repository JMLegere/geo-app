@capability.exploration-discovery-lifecycle @feature.discovery
Feature: Discovery
  Discovery consumes reward-clean Map cell entry truth and resolves whether the
  entered map cell creates no result or an owned unidentified find for
  Identification. It must not pretend a map-cell entry is a completed discovery
  until unidentified acquisition has been committed, and it must not reveal the
  fauna species before Identification.

  Scenario: Discovery consumes map-cell entry truth
    Given Map has emitted one eligible map-cell entry event
    And the entry event includes entered cell, first-or-revisit status, timestamp, and territory context
    When Discovery resolves the entry
    Then the resolver should keep the Map entry identity as its correlation id
    And the resolver should add only Discovery outcome fields such as result type, unidentified category, rarity, and acquisition eligibility
    And the resolver should not mutate fog, visits, or map-cell entry state

  Scenario: First-entry discovery commits unidentified acquisition before claiming ownership
    Given a first-visit map-cell entry resolves to an eligible unidentified fauna find
    When Discovery presents the result as acquired
    Then the owned unidentified find should already be committed to Pack state
    And the result should include the owned item id, unidentified category, and acquisition cell id
    And the player-facing message may say an unidentified specimen was found or added to the Pack
    But it should not reveal the fauna species name before Identification

  Scenario: Cell entry does not grant direct known fauna
    Given a first-visit map-cell entry resolves to fauna
    When Discovery commits acquisition
    Then Pack should receive an owned unidentified find rather than a known species card
    And no player-facing Discovery copy should reveal the species display name
    And Identification should be required before Pack treats the specimen as known

  Scenario: Acquisition failure does not show a false found message
    Given a map-cell entry resolves to an eligible unidentified find
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
    Given a Discovery unidentified result is resolved from a map-cell entry
    When acquisition succeeds and the player acknowledges the result
    Then telemetry should link map-cell entry id, discovery result id, owned item id, unidentified category, and acknowledgement action
    And each step should remain queryable without relying on player-visible copy

  @action.acknowledge-discovery-result
  Scenario: Player acknowledges a committed discovery result
    Given a discovery result has been resolved and any eligible unidentified acquisition has completed
    When the player acknowledges the discovery result
    Then the result should leave the active overlay
    And the already-owned unidentified find should remain visible through Pack