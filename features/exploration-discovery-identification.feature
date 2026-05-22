@capability.exploration-discovery-lifecycle @feature.identification
Feature: Identification
  Identification is the required unknown-to-known follow-up path for owned
  unidentified finds. Fauna found from map-cell entry starts as unidentified; the
  species name, deterministic traits, and known state are revealed only through
  Identification.

  Scenario: Identification defines its app surface
    Given Identification belongs to the Exploration-Discovery Lifecycle capability
    When the player has an unidentified find acquired from map-cell entry
    Then it should specify unidentified card state, hold-to-reveal interaction, reveal theater, deterministic trait results, and Pack state updates

  Scenario: Fauna discovery requires Identification before species is known
    Given Discovery has acquired an unidentified fauna find
    When the player continues the discovery reward
    Then the find should be visible in Pack as unidentified
    And Pack search should not reveal the species name before Identification
    And Identification should be required before the specimen becomes a known fauna find

  Scenario: Owned unidentified find is the only valid identification input
    Given the player has an eligible unidentified find in Pack
    When the player starts identification
    Then the unidentified find should enter the unknown-to-known reveal path
    And the reveal should keep the same owned item identity rather than creating a second Pack item

  @action.identify-unidentified-find
  Scenario: Player identifies an unidentified find
    Given the player has an eligible unidentified find
    When the player starts identification
    Then the unidentified find should enter the unknown-to-known reveal path

  @action.reveal-identification
  Scenario: Player reveals an identification
    Given an identification reveal is ready
    When the player reveals the identification
    Then the deterministic identification result, traits, and known-state transition should be committed
