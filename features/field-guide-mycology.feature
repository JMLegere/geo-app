@capability.mycology @feature.mycology
Feature: Mycology legacy evidence
  Status: Mycology is not one of the five resolved Disciplines. This retained
  Index scenario evidence is historical and does not define target behavior.

  Scenario: Mycology defines its app section
    Given Mycology is surfaced through the Index feature
    When the feature is expanded beyond this stub
    Then it should specify fungi pages, substrate context, spore or condition cues, and fungal observation models

  @action.view-mycology-guide
  Scenario: Player views Mycology guide
    Given the Index has a Mycology section
    When the player opens the Mycology guide
    Then fungi-focused knowledge should be organized around fungi, substrates, spores, and hidden conditions

  @action.inspect-fungus-record
  Scenario: Player inspects a fungus record
    Given a fungus record is available
    When the player inspects the fungus record
    Then the Index should show fungal facts, observations, substrate context, and discovered history
