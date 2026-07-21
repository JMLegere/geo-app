@capability.geology @feature.geology
Feature: Geology
  The Index feature needs a concrete geology section for rock and mineral finds,
  specimen details, and landform context.

  Scenario: Geology defines its app section
    Given Geology is surfaced through the Index feature
    When the feature is expanded beyond this stub
    Then it should specify mineral and rock records, landform context, specimen details, and place relationships

  @action.view-geology-guide
  Scenario: Player views Geology guide
    Given the Index has a Geology section
    When the player opens the Geology guide
    Then earth-material knowledge should be organized around rocks, minerals, and landforms

  @action.inspect-rock-mineral-record
  Scenario: Player inspects a rock or mineral record
    Given a rock or mineral record is available
    When the player inspects the rock or mineral record
    Then the Index should show specimen facts, landform context, and discovered history
