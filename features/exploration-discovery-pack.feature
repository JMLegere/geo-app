@capability.exploration-discovery-lifecycle @feature.pack
Feature: Pack
  Pack is the owned unidentified and identified find inventory and verification
  surface. Discovery may resolve a result, but Pack proves whether the player
  actually owns the unidentified find before Identification reveals it.

  Scenario: Pack defines its app section
    Given Pack belongs to the Exploration-Discovery Lifecycle capability
    When the player opens the Pack
    Then it should show owned unidentified finds, identified finds, domain filters, find cards, details, and acquisition history
    And opening or reading the Pack should not mutate ownership state

  Scenario: Acquired Discovery unidentified find appears in Pack
    Given Discovery has committed an owned unidentified find for a map-cell entry
    When the player opens the Pack after the result
    Then the owned unidentified find should be visible without a reload-only dependency
    And the unidentified find should carry its category, rarity, acquisition time, and acquisition map cell
    But it should not reveal the species display name before Identification

  Scenario: Pack search does not leak pre-identification species names
    Given the player acquired an unidentified fauna find from Discovery
    When the player searches the Pack for the hidden species name
    Then that species name should not appear before Identification
    And the unidentified find should remain searchable only by allowed unidentified-facing fields

  Scenario: Pack detail shows acquisition provenance
    Given an owned unidentified find or identified find is visible in the Pack
    When the player inspects the Pack item
    Then the detail should show acquisition history and current identification state
    And the detail should identify the map cell or place where the item was acquired when available
    And inspection should not duplicate the item or replay the discovery result

  @action.collect-find
  Scenario: Player collects a find
    Given a discovery result contains an eligible unidentified find
    When the player collects the find
    Then the unidentified find should be added to the player's owned Pack state exactly once

  @action.open-pack
  Scenario: Player opens the Pack
    Given the player has access to the Pack
    When the player opens the Pack
    Then owned unidentified finds and identified finds should be visible without changing find state

  @action.inspect-pack-find
  Scenario: Player inspects a Pack find
    Given an owned unidentified find or identified find is visible in the Pack
    When the player inspects the Pack item
    Then the Pack should show details, acquisition history, identification state, and available handoffs