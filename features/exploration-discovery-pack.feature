@capability.exploration-discovery-lifecycle @feature.pack
Feature: Pack
  The Exploration-Discovery Lifecycle needs a concrete pack feature for owned-find
  inventory, mystery cards, domain filters, find cards, details, and acquisition
  history.

  Scenario: Pack defines its app section
    Given Pack belongs to the Exploration-Discovery Lifecycle capability
    When the feature is expanded beyond this stub
    Then it should specify the pack grid, filter bar, find card, find detail sheet, and find ownership model

  @action.collect-find
  Scenario: Player collects a find
    Given a discovery result contains an eligible find
    When the player collects the find
    Then the find should be added to the player's owned Pack state

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
