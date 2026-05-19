@capability.multiplayer @feature.economy
Feature: Economy
  Multiplayer needs a concrete economy feature for duplicate value, trading,
  market signals, and exchangeable surplus or resource value.

  Scenario: Economy defines its game system
    Given Economy belongs to the Multiplayer capability
    When the feature is expanded beyond this stub
    Then it should specify duplicate value, trade flow, market signal sections, and exchangeable resource models

  @action.open-economy
  Scenario: Player opens Economy
    Given the player has access to Economy
    When the player opens Economy
    Then duplicate value, trade surfaces, and market signals should be visible without changing ownership

  @action.offer-trade
  Scenario: Player offers a trade
    Given the player owns eligible surplus or duplicate value
    When the player offers a trade
    Then an eligible trade offer should be created or updated

  @action.accept-trade
  Scenario: Player accepts a trade
    Given an eligible trade offer is available
    When the player accepts the trade
    Then ownership should update exactly once for both sides of the exchange
