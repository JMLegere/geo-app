@capability.paleontology @feature.paleontology
Feature: Paleontology
  The Field Guide feature needs a concrete paleontology section for fossil records,
  extinct life, and deep-time timeline context.

  Scenario: Paleontology defines its app section
    Given Paleontology is surfaced through the Field Guide feature
    When the feature is expanded beyond this stub
    Then it should specify fossil pages, deep-time timeline treatment, extinct life context, and place relationships

  @action.view-paleontology-guide
  Scenario: Player views Paleontology guide
    Given the Field Guide has a Paleontology section
    When the player opens the Paleontology guide
    Then fossil knowledge should be organized around extinct life, fossil records, and deep time

  @action.inspect-fossil-record
  Scenario: Player inspects a fossil record
    Given a fossil record is available
    When the player inspects the fossil record
    Then the Field Guide should show fossil facts, deep-time context, and discovered history
