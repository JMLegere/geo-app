@capability.exploration-discovery-lifecycle @feature.identification
Feature: Identification
  The Exploration-Discovery Lifecycle needs a concrete identification feature for
  turning unknown finds into known specimens or objects.

  Scenario: Identification defines its app surface
    Given Identification belongs to the Exploration-Discovery Lifecycle capability
    When the feature is expanded beyond this stub
    Then it should specify unidentified card state, hold-to-reveal interaction, reveal theater, and deterministic trait results

  @action.identify-mystery
  Scenario: Player identifies a mystery
    Given the player has an eligible mystery find
    When the player starts identification
    Then the mystery should enter the unknown-to-known reveal path

  @action.reveal-identification
  Scenario: Player reveals an identification
    Given an identification reveal is ready
    When the player reveals the identification
    Then the deterministic identification result, traits, and known-state transition should be committed
