@capability.exploration-discovery-lifecycle @feature.pack
Feature: Pack
  Pack is the newest-first, unlimited projection of the Player's owned active
  Items. Examination records durable shared Base Item knowledge; it does not
  identify an exact Item's Variable Property Values.

  Scenario: The committed exact Item is first without duplicate insertion
    Given an Encounter Outcome committed an exact Item ID
    And older active Items already exist in Pack
    When the player opens Pack after the reward
    Then that exact Item ID should appear first in recent Pack order
    And no duplicate Item should be inserted
    And the app should not force-open Pack or activate Town

  Scenario: Pack capacity never hides earned Items
    Given the player owns more than twenty active Items
    When the player opens Pack
    Then every owned active Item should remain browsable
    And acquisition should not be rejected, overwritten, hidden, or orphaned

  Scenario: An unexamined Item is a semantic silhouette
    Given an owned active Item is unexamined
    When Pack renders the Item
    Then assistive semantics should describe an unexamined Item
    And Base Item identity, intrinsic content, and Variable Property Values should be concealed

  @action.examine-pack-item
  Scenario: One Pack tap Examines the same Item
    Given an owned active Item is unexamined
    When the player taps its Pack grid surface once
    Then Examination should be dispatched once for that exact Item ID
    And at most one Player Base Item Journal Entry should exist
    And the recognized same-ID Item card should open
    And all current and future owned Items of that Base Item should be recognized
    But no Villager, Venue, or Service should be required
    And no Item Property Value should be resolved

  @action.open-pack
  Scenario: Player browses Pack without mutation
    Given the player has access to Pack
    When the player opens, filters, sorts, searches, or reads Pack
    Then owned Items should remain visible without changing Item knowledge or identification state

  @action.inspect-pack-find
  Scenario: Player inspects a recognized Pack Item
    Given an examined or identified Item is visible in Pack
    When the player inspects that same Item
    Then Pack should show allowed Base Item content, acquisition history, and identification state
    And inspection should not duplicate or mutate the Item