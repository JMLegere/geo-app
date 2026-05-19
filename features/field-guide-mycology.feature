@capability.mycology @feature.mycology
Feature: Mycology
  The Field Guide feature needs a concrete mycology section for fungi, substrates, spores,
  and hidden environmental conditions.

  Scenario: Mycology defines its app section
    Given Mycology is surfaced through the Field Guide feature
    When the feature is expanded beyond this stub
    Then it should specify fungi pages, substrate context, spore or condition cues, and fungal observation models

  @action.view-mycology-guide
  Scenario: Player views Mycology guide
    Given the Field Guide has a Mycology section
    When the player opens the Mycology guide
    Then fungi-focused knowledge should be organized around fungi, substrates, spores, and hidden conditions

  @action.inspect-fungus-record
  Scenario: Player inspects a fungus record
    Given a fungus record is available
    When the player inspects the fungus record
    Then the Field Guide should show fungal facts, observations, substrate context, and discovered history
