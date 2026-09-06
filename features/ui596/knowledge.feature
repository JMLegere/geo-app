@issue596 @target_specification @capability.exploration-discovery-lifecycle
Feature: Unknown means uninspected Base Item knowledge
  Target acceptance specification from issue 596.
  Step definitions are not implemented by this specification-only change.
  Visual review and calibration scenarios require real rendering evidence.

  @behavior @UI596-021 @Q036 @Q038 @Q039 @Q040 @A002
  Scenario: [UI596-021] Unknown is shared by Player and stable Base Item
    Given Player A owns Item I1 from Base Item B version V1
    And Player A has never inspected B
    And Player A later receives Item I2 from B version V2
    And Player B also owns an Item from B
    When Player A inspects I1 and Examination succeeds
    Then B should be known to Player A across I1, I2, and future Items from B
    And B should remain Unknown to Player B
    And the recognized inspection should retain the exact Item ID I1
    And at most one durable examination record should exist for Player A and Base Item B
    And acquisition of a new instance or publication of a new version should not reset known status
    And no separate per-Item "New" flag, tag, count, filter, or clearing event should exist

  @visual_review @UI596-022 @Q036 @Q037
  Scenario: [UI596-022] Unknown artwork uses the actual silhouette
    Given the Player has never inspected an owned Item's Base Item
    When its Pack card is displayed
    Then the Item's own artwork shape should appear as a solid black silhouette with a transparent surround
    And its internal colors, markings, and shading should be concealed
    And its reference-style upper-left ribbon should read "Unknown"
    And its accessible description should identify an Unknown category Item without the hidden Base Item name
    And missing silhouette artwork should use a knowledge-safe fallback rather than expose full-color art
    And the solution should not assume hidden full-color assets are already available in the current client response

  @behavior @UI596-023 @Q048 @Q088
  Scenario: [UI596-023] Examination remains separate from Identification
    Given an owned Item has never been examined and requires Identification
    When the Player taps its Pack surface once and Examination succeeds
    Then its allowed shared Base Item content should become available
    And its Unknown silhouette treatment should clear
    But no Variable Property Value should be rolled
    And no Identification, Discovery, or Discipline XP should be granted by Examination alone
    And unrevealed property values should appear as "?"
    And properties not applicable to the Item should be omitted
    And an inspected but unidentified Item should still require the existing Identification Service

  @behavior @UI596-024
  Scenario: [UI596-024] Failed examination does not fabricate known state
    Given the Player taps an Unknown Item
    When its Examination request fails
    Then no completed examination state should be fabricated
    And the Player should see a local explanation and retry path
    And repeated taps while the same request is pending should not dispatch duplicate examination requests
    When a retry succeeds
    Then the same Item should open and shared Base Item knowledge should update once
