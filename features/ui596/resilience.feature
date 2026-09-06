@issue596 @target_specification @capability.exploration-discovery-lifecycle
Feature: Useful Pack state during loading and failure
  Target acceptance specification from issue 596.
  Step definitions are not implemented by this specification-only change.
  Visual review and calibration scenarios require real rendering evidence.

  @behavior @UI596-039 @Q102 @Q105
  Scenario: [UI596-039] Refresh failure keeps a usable Pack visible
    Given App Readiness has produced a valid internally consistent Client Working Set
    And the Pack is displaying loaded Items
    When a refresh cannot complete
    Then the Player should keep browsing the loaded Items
    And a small connection notice with Retry should explain the refresh problem
    And the current category, search, filters, sort order, and scroll context should remain intact
    And the data should not be represented as freshly confirmed
    And unsafe authoritative actions should follow existing disabled or supported-queue behavior

  @behavior @UI596-040 @Q102 @Q105
  Scenario: [UI596-040] Initial loading is different from readiness failure
    Given no usable Pack content is available yet
    When permitted initial content loading is in progress
    Then a skeleton matching the eventual grid should communicate that loading is incomplete
    But if App Readiness cannot produce a valid working set
    Then app entry should be blocked by the existing Retry and Sign out recovery state
    And the UI should not show an empty Pack or an indefinitely stalled progress bar as a substitute

  @behavior @UI596-041 @Q103 @Q104
  Scenario: [UI596-041] Empty collection and no matches have different recovery
    Given an authenticated Player owns no active Items
    When Pack is shown
    Then a small contextual illustration and concise empty-Pack explanation should appear
    And an applicable existing next action may be offered
    When a Player with owned Items applies a query or filters that match nothing
    Then a no-match explanation and active constraints should be shown
    And a clear or reset route should recover the results
    And no-match state should not be presented as a network error

  @behavior @UI596-042
  Scenario: [UI596-042] Context remains scoped to the signed-in Player
    Given Player A has a Pack context and inspected Base Item knowledge
    When Player A explicitly signs out and Player B signs in
    Then A's persisted Client Working Set should be purged according to the existing sign-out rule
    And B should not inherit A's query results, Item state, or Unknown knowledge
    And an ordinary refresh retry should not behave like Sign out

  @measurement @UI596-043 @A005
  Scenario: [UI596-043] Meaningful local response remains within the existing target
    Given App Readiness is complete
    And the named primary interaction is a reversible Pack interaction supported by client-resident state
    When its input-to-first-meaningful-render latency is measured under the approved production protocol
    Then its p95 should be at most 100 milliseconds
    And a pressed-state acknowledgement alone should not count as a meaningful result
    And server-confirmed mutation completion should be measured separately
    And no measurement result should be claimed before the protocol is run
