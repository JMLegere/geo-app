@issue596 @target_specification @capability.exploration-discovery-lifecycle
Feature: Responsive action feedback and gameplay outcomes
  Target acceptance specification from issue 596.
  Step definitions are not implemented by this specification-only change.
  Visual review and calibration scenarios require real rendering evidence.

  @behavior @UI596-032 @Q099 @A009 @A022
  Scenario: [UI596-032] Unavailable actions remain visible and explain requirements
    Given an existing Item action is currently unavailable
    When its controls are rendered
    Then the action should remain visible with a neutral face and muted lettering
    And it should retain its beveled geometry
    When the Player taps it
    Then a concise inline explanation near the action area should explain the unmet requirement
    And the Item should remain visible
    And no action should execute

  @visual_review @UI596-033 @A005 @A022
  Scenario: [UI596-033] Buttons respond to pressure without bounce
    Given an available beveled action button is visible
    When the Player presses and holds the button
    Then its face should move down and its shadow should disappear
    When the Player releases the button
    Then it should return quickly and smoothly without overshoot
    And another input should interrupt that return immediately
    And routine button feedback should not play a sound

  @behavior @UI596-034 @Q100 @Q101 @A010
  Scenario: [UI596-034] Processing and success are visibly different
    Given an examined owned Item is eligible for the existing Identification Service
    And its exact Item, Base Item Version, Villager, and Service Version have been prepared
    When the Player completes the existing explicit Identification commit gesture
    Then the action surface should retain stable dimensions and show pending status
    And further input should not duplicate the commit
    When Identification succeeds
    Then the newly revealed properties on that exact Item should briefly highlight in place
    And the same result should be retained after reload
    And an additional result-summary screen should not become the main feedback
    And the action should not bypass its existing Service eligibility or hold/reveal rules

  @behavior @UI596-035 @Q101
  Scenario: [UI596-035] Failure never receives success feedback
    Given an explicit Identification request is pending
    When the authoritative request fails
    Then the newly revealed-properties success highlight should not play
    And no uncommitted Property Value or reward should be displayed as granted
    And the Item should retain its previous authoritative state
    And the existing retry or recovery path should remain available

  @visual_review @UI596-036 @A010
  Scenario: [UI596-036] First Discovery adds only a small badge
    Given one Identification is the Player's first Discovery of a Base Item
    And another Identification concerns an already Discovered Base Item
    When their successful reveals are compared
    Then both should use the same core reveal and property-highlight treatment
    And the first Discovery should add only a small first-Discovery badge
    And it should not add a separate ceremony, larger effect sequence, or extra screen

  @behavior @UI596-037 @A006
  Scenario: [UI596-037] Sounds represent gameplay outcomes only
    Given the Player has enabled sound effects
    When the Player searches, filters, sorts, opens Help, presses a routine control, or opens or closes an inspection
    Then no routine interaction sound should play
    When acquisition, Identification, or an Encounter result is confirmed
    Then its applicable gameplay outcome sound may play
    When sound effects are disabled
    Then those outcome sounds should remain silent

  @behavior @UI596-038 @A008
  Scenario: [UI596-038] A new Encounter does not take over the current task
    Given the Player is using the Map
    When a new Encounter becomes available
    Then it should be marked on the Map
    And the Player should choose when to open it
    And no automatic screen opening or attention-stealing notice should interrupt the current task
    And this presentation should not redefine Encounter expiry, persistence, or resolution rules
