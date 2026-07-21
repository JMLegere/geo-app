@capability.archaeology @feature.archaeology
Feature: Archaeology
  The Index feature needs a concrete archaeology section for artifacts, ruins,
  human traces, material culture, and place-based history.

  Scenario: Archaeology defines its app section
    Given Archaeology is surfaced through the Index feature
    When the feature is expanded beyond this stub
    Then it should specify artifact records, human trace context, material details, and place-based stories

  @action.view-archaeology-guide
  Scenario: Player views Archaeology guide
    Given the Index has an Archaeology section
    When the player opens the Archaeology guide
    Then artifact and human-trace knowledge should be organized around material culture and place history

  @action.inspect-artifact-record
  Scenario: Player inspects an artifact record
    Given an artifact record is available
    When the player inspects the artifact record
    Then the Index should show artifact facts, human-history context, and discovered history
