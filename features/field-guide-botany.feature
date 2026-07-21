@capability.botany @feature.botany
Feature: Botany
  The Index feature needs a concrete botany section for flora, habitats, growth
  stages, and seasonal plant states.

  Scenario: Botany defines its app section
    Given Botany is surfaced through the Index feature
    When the feature is expanded beyond this stub
    Then it should specify plant species pages, habitat context, growth stages, and seasonal state treatment

  @action.view-botany-guide
  Scenario: Player views Botany guide
    Given the Index has a Botany section
    When the player opens the Botany guide
    Then plant-focused knowledge should be organized around flora, growth, habitats, and seasons

  @action.inspect-plant-record
  Scenario: Player inspects a plant record
    Given a plant record is available
    When the player inspects the plant record
    Then the Index should show plant facts, observations, growth context, and discovered history
