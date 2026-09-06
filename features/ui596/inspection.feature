@issue596 @target_specification @capability.exploration-discovery-lifecycle
Feature: Item inspection and contextual help
  Target acceptance specification from issue 596.
  Step definitions are not implemented by this specification-only change.
  Visual review and calibration scenarios require real rendering evidence.

  @behavior @UI596-025 @Q081 @Q083 @Q084 @A003 @A005
  Scenario: [UI596-025] Inspection can close before its presentation animation finishes
    Given the Player opens one Item inspection
    And its short fade and slight scale-up are still in progress
    When the Player taps Close or the backdrop
    Then the requested dismissal should begin immediately
    And the opening animation should yield without waiting to finish
    And closing should use a shorter fade
    And the Pack should return to its prior browsing context
    And another Item should be opened through its own separate inspection rather than a swipe-between-Items mode

  @behavior @UI596-026 @Q081 @Q100
  Scenario: [UI596-026] Pending authoritative work survives dismissal
    Given the Player explicitly submitted an eligible authoritative Item action
    And the result is pending
    When the Player dismisses its inspection
    Then the presentation should close without cancelling or duplicating the submitted mutation
    And success should not be shown until the authoritative result is known
    And a later confirmed result should reconcile into the correct Item in the Client Working Set
    And pending commands should use only command kinds already supported by Local State and Sync

  @behavior @UI596-027 @Q077 @Q082 @Q085 @Q086
  Scenario: [UI596-027] Long inspection content stays reachable
    Given an Item has long metadata, long stat labels, secondary units, and a long description
    When the Player reads the inspection on iPhone
    Then metadata should wrap onto additional lines
    And meaningful short stat labels should be used where available
    And remaining long stat labels should wrap instead of inheriting the title's unlimited shrinking rule
    And secondary units or rates should move to another line without losing the precise value
    And the inspection content should scroll with Close and an action footer reachable
    And reserved content padding should keep the footer from covering the final content

  @visual_review @UI596-028 @A012
  Scenario: [UI596-028] Inspection backdrop keeps only relevant counters prominent
    Given an existing inspection action consumes a displayed resource
    When the inspection opens
    Then the underlying screen should be heavily dimmed but recognizable
    And the relevant existing resource counter should remain bright
    And unrelated background counters should dim
    And the modal should not create a new currency merely to populate that counter

  @behavior @UI596-029 @Q092 @Q093 @A019
  Scenario: [UI596-029] Help starts with current symbols and offers a full glossary
    Given an inspection description uses several property or effect icons
    When the Player taps its panel-level information button
    Then a contextual legend should explain the current panel's symbols first
    And a "Full glossary" action should provide access to all available symbol meanings
    And the legend should be anchored to the information control when space permits
    And it may expand to a sheet when necessary without losing the underlying Item context
    And returning from the glossary should restore the inspection

  @behavior @UI596-030 @Q067 @A007
  Scenario: [UI596-030] Help labels remain under Player control
    Given main navigation shows only its illustrated destination icons
    When the Player activates Help
    Then all destination names should appear beneath their icons
    And labels should not disappear because an arbitrary timer elapsed
    When the Player dismisses Help or selects a destination
    Then temporary labels should disappear
    And accessible names should remain available whether or not visual labels are shown

  @behavior @UI596-031 @Q072
  Scenario: [UI596-031] Resource details remain contextual
    Given a displayed resource has an existing balance and defined details
    When the Player selects its counter
    Then its exact balance and applicable existing actions should be shown in context
    And no undefined acquisition or purchase shortcut should be added
    And returning should preserve the Pack's current category, query, filters, sort order, and scroll position
