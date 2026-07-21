@capability.exploration-discovery-lifecycle @feature.pack
Feature: Pack
  Pack is the player-facing collection of owned Items. The reward-card and
  find wording below is preserved legacy executable evidence only; it does not
  make Cell entry or Item acquisition Discovery. Index projects Discovered
  Base Items separately from Pack.

  Scenario: Pack defines its player-facing collection
    Given Pack belongs to the Exploration-Discovery Lifecycle capability
    When the player opens the Pack
    Then it should show owned unidentified Items, identified Items, filters, Item cards, details, and acquisition history
    And opening or reading the Pack should not mutate ownership state

  Scenario: Legacy reward evidence lands an unidentified Item in Pack
    Given Discovery has committed an owned unidentified find for a map-cell entry
    And the Discovery reward card has landed on the Pack target
    When the player opens the Pack after the reward
    Then the owned unidentified find should be visible without a reload-only dependency
    And the legacy Item should carry its category, acquisition time, and acquisition Cell
    But it should not reveal the specimen display name before Identification

  Scenario: Pack search does not leak pre-identification species names
    Given the player acquired an unidentified living specimen find from Discovery
    When the player searches the Pack for the hidden specimen name
    Then that specimen name should not appear before Identification
    And the unidentified find should remain searchable only by allowed unidentified-facing fields

  Scenario: Pack target reacts to discovery reward landing
    Given a Discovery living specimen reward card is flying toward the Pack target
    When the reward card lands on the Pack target
    Then the Pack target should perform a small impact shake
    And the app should not force-open the Pack tab
    And the player should return to live map control

  Scenario: Pack detail shows acquisition provenance
    Given an owned unidentified find or identified find is visible in the Pack
    When the player inspects the Pack item
    Then the detail should show acquisition history and current identification state
    And the detail should identify the map cell or place where the item was acquired when available
    And inspection should not duplicate the item or replay the discovery reward

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