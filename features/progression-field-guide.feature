@capability.progression-permanence @feature.field-guide
Feature: Index
  Status: The field-guide feature tag and action identifiers are retained legacy
  identifiers. Index is the approved target name and projects the Base Items
  the Player has Discovered; Pack contains owned Item instances.

  Scenario: Index is durable knowledge, not Item ownership
    Given the Player identifies a Base Item for the first time
    When Discovery is recorded
    Then Index may project that Base Item
    And Pack ownership remains separate from Index knowledge

  @action.open-field-guide
  Scenario: Player opens Index through the legacy action identifier
    Given the Player has an Index entry
    When the player opens Index
    Then the known Base Item projection is visible without mutating progress

  @action.inspect-field-guide-entry
  Scenario: Player inspects an Index entry through the legacy action identifier
    Given an Index entry exists
    When the player inspects the Index entry
    Then it describes durable Discovery knowledge without claiming Pack ownership
