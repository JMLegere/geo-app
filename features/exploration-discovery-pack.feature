@capability.exploration-discovery-lifecycle @feature.pack
Feature: Pack
  Pack is the owned-find inventory and verification surface. Discovery may
  resolve a result, but Pack proves whether the player actually owns the find.

  Scenario: Pack defines its app section
    Given Pack belongs to the Exploration-Discovery Lifecycle capability
    When the player opens the Pack
    Then it should show owned finds, mystery cards, domain filters, find cards, details, and acquisition history
    And opening or reading the Pack should not mutate ownership state

  Scenario: Acquired Discovery result appears in Pack
    Given Discovery has committed an owned find for a map-cell entry
    When the player opens the Pack after the result
    Then the owned find should be visible without a reload-only dependency
    And the find should carry its display name, category, rarity, acquisition time, and acquisition map cell

  Scenario: Pack search verifies newly acquired finds
    Given the player acquired a find named Amberwing Warbler from Discovery
    When the player searches the Pack for amber
    Then Amberwing Warbler should appear in the results
    And the empty-results state should not be shown for that filter

  Scenario: Pack detail shows acquisition provenance
    Given an owned find is visible in the Pack
    When the player inspects the Pack find
    Then the detail should show discovery facts and acquisition history
    And the detail should identify the map cell or place where the find was acquired when available
    And inspection should not duplicate the find or replay the discovery result

  @action.collect-find
  Scenario: Player collects a find
    Given a discovery result contains an eligible find
    When the player collects the find
    Then the find should be added to the player's owned Pack state exactly once

  @action.open-pack
  Scenario: Player opens the Pack
    Given the player has access to the Pack
    When the player opens the Pack
    Then owned finds and mystery cards should be visible without changing find state

  @action.inspect-pack-find
  Scenario: Player inspects a Pack find
    Given an owned find is visible in the Pack
    When the player inspects the Pack find
    Then the Pack should show details, acquisition history, and available handoffs