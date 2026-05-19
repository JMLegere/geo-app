@capability.multiplayer @feature.community
Feature: Community
  Multiplayer needs a concrete community feature for shared progress, aggregate
  discovery, community events, and shared milestones.

  Scenario: Community defines its app section
    Given Community belongs to the Multiplayer capability
    When the feature is expanded beyond this stub
    Then it should specify community progress panel, aggregate discovery model, community events, and shared milestones

  @action.open-community
  Scenario: Player opens Community
    Given the player has access to Community
    When the player opens Community
    Then shared progress, events, and community milestones should be visible without changing shared state

  @action.inspect-community-event
  Scenario: Player inspects a community event
    Given a community event is available
    When the player inspects the community event
    Then shared event context, eligibility, and progress should be visible without contributing automatically

  @action.contribute-to-community-progress
  Scenario: Player contributes to community progress
    Given the player has an eligible community contribution
    When the player contributes to community progress
    Then the contribution should be committed into an aggregate community goal
