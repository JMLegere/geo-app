@capability.progression-permanence @feature.field-guide
Feature: Field Guide
  Progression-Permanence needs a concrete Field Guide feature where species
  pages, discipline sections, and learned observations persist beyond inventory
  ownership.

  Scenario: Field Guide defines its app section
    Given Field Guide belongs to the Progression-Permanence capability
    When the feature is expanded beyond this stub
    Then it should specify species pages, discipline indexes, known-find records, observation history, and knowledge persistence

  @action.open-field-guide
  Scenario: Player opens the Field Guide
    Given the player has access to the Field Guide
    When the player opens the Field Guide
    Then persistent knowledge indexes should be visible without mutating progress

  @action.inspect-field-guide-entry
  Scenario: Player inspects a Field Guide entry
    Given a Field Guide entry exists
    When the player inspects the Field Guide entry
    Then learned observations, known finds, and science context should be visible without changing inventory
