@capability.exploration-discovery-lifecycle @feature.discovery
Feature: Discovery
  The Exploration-Discovery Lifecycle needs a concrete discovery feature that
  resolves eligible place entry into first-visit finds, revisit finds, rarity
  treatment, and place-shaped outcomes.

  Scenario: Discovery defines its game system
    Given Discovery belongs to the Exploration-Discovery Lifecycle capability
    When the feature is expanded beyond this stub
    Then it should specify the discovery resolver, result card, acquisition event model, rarity treatment, and revisit reward model

  @action.acknowledge-discovery-result
  Scenario: Player acknowledges a discovery result
    Given a discovery result has been resolved
    When the player acknowledges the discovery result
    Then the result should become available to downstream ownership systems
