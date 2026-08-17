@capability.exploration-discovery-lifecycle @feature.identification
Feature: Identification
  Identification is a distinct Service for one examined, unidentified, owned
  active Item. It retains the exact prepared Item, Villager, current published
  Service Version, and exact Base Item Version through hold/reveal.

  @action.open-identification-service
  Scenario: Examined Item opens a distinct known-Villager Service
    Given an examined unidentified owned active Item is in Pack
    And the player knows a Villager whose current Version offers the current published Identification Service
    And the player has no current Venue Visit
    When the player opens Identification Service from the Item card
    Then the distinct Service screen should prepare that exact Item once
    And it should show the Villager and Service
    And Town should not become an active bottom destination
    And no Property Value should be committed

  @action.identify-unidentified-find
  Scenario: Player starts the retained Identification plan
    Given the Identification Service prepared an eligible exact Item
    When the player starts Identification
    Then the reveal control should retain the prepared Item, Villager, and Service Version
    And starting should not commit Property Values

  Scenario: Cancel before reveal writes nothing
    Given an Identification reveal is ready
    When the player cancels or releases before completing hold-to-reveal
    Then no Identification commit should run
    And no Discovery or Item Property Value should be written

  @action.reveal-identification
  Scenario: Hold and reveal identifies the same exact Item once
    Given an Identification reveal is ready for the retained plan
    When the player completes hold-to-reveal
    Then the exact authored-version Property Values should be committed once
    And the identified result should retain the same Item ID
    And reloading should preserve the same Item and identified state
    And retrying should not duplicate Item, Journal Entry, Discovery, or Property Values
