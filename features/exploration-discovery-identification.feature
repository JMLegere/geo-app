@capability.exploration-discovery-lifecycle @feature.identification
Feature: Identification
  Identification is the unknown-to-known follow-up path for owned mysteries. The
  first shippable Discovery slice may grant known finds directly, but mysteries
  must already have a truthful lifecycle boundary.

  Scenario: Identification defines its app surface
    Given Identification belongs to the Exploration-Discovery Lifecycle capability
    When the feature is expanded beyond direct known finds
    Then it should specify unidentified card state, hold-to-reveal interaction, reveal theater, deterministic trait results, and Pack state updates

  Scenario: Known Discovery finds do not require Identification
    Given Discovery has resolved and acquired a known find
    When the result is acknowledged
    Then the find should be immediately visible in Pack as known
    And Identification should not be required before Pack search can find it

  Scenario: Owned mystery is the only valid identification input
    Given the player has an eligible mystery find in Pack
    When the player starts identification
    Then the mystery should enter the unknown-to-known reveal path
    And the reveal should keep the same owned item identity rather than creating a second Pack item

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
