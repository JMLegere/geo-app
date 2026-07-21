@capability.zoology @feature.zoology
Feature: Zoology
  The Index feature needs a concrete zoology section for fauna, threatened species
  meaning, animal behavior, field signs, and migrations.

  Scenario: Zoology defines its app section
    Given Zoology is surfaced through the Index feature
    When the feature is expanded beyond this stub
    Then it should specify animal species pages, threat status treatment, behavior observations, and migration links

  @action.view-zoology-guide
  Scenario: Player views Zoology guide
    Given the Index has a Zoology section
    When the player opens the Zoology guide
    Then animal-focused knowledge should be organized around fauna, behavior, signs, and migrations

  @action.inspect-animal-record
  Scenario: Player inspects an animal record
    Given an animal record is available
    When the player inspects the animal record
    Then the Index should show animal facts, observations, habitats, and discovered history
