@capability.living-world @feature.town @feature.npc-venues
Feature: Town and NPC-led services
  Living World makes major EarthNova systems feel grounded in places and people.
  NPC venues are discovered on the Map, unlock Town entries, and bind feature
  surfaces to the nearest eligible local NPC instead of exposing unexplained menus.

  Scenario: Living World defines its app surfaces
    Given major game systems should be introduced through NPCs
    When the Living World capability is expanded beyond navigation stubs
    Then it should specify NPC venue placement, venue discovery, Town entries, and NPC-led feature binding

  Scenario: NPC venues are sparse and city-scoped
    Given a city-level location node has eligible POIs and authored NPC functions
    When NPC venues are placed for that city
    Then each NPC type should appear at most once in the city
    And each map cell should contain at most one NPC venue
    And each venue should anchor to the most popular eligible POI in its chosen cell

  Scenario: NPC function is authored before generated flavor
    Given the game needs a specific authored NPC-led feature
    When an NPC venue is generated
    Then the NPC type, feature function, unlock rules, and feature binding should be authored by the game
    And generated identity details should be limited to name, portrait seed, affiliation, voice, intro copy, and cosmetic local flavor

  @action.discover-npc-venue
  Scenario: Player discovers an NPC venue by entering its map cell
    Given the player enters a map cell that hosts an undiscovered NPC venue
    When the venue discovery is resolved
    Then the NPC venue should become visible on the Map and unlocked in Town
    And the discovery should not grant items, identify species, or bypass normal Discovery and Identification gates

  @action.open-town
  Scenario: Player opens Town
    Given the player is authenticated
    When the player opens Town
    Then Town should show unlocked NPC-led feature entries
    And if no NPC-led features are unlocked, Town should show an empty state that points back to Map exploration

  @action.open-npc-led-feature
  Scenario: Player opens an unlocked NPC-led feature
    Given Town lists an unlocked NPC-led feature type
    When the player opens that feature from Town
    Then the feature UI should bind to the nearest eligible NPC of that type relative to the player's current location
    And the binding should respect one NPC type per city, one NPC venue per cell, and POI-anchored venue placement

  Scenario: First concrete NPC loop remains intentionally unchosen
    Given Living World has venue, Town, and binding rules
    When the first concrete NPC-led loop is selected later
    Then the selected NPC and loop should be captured in SuperBDD before implementation
    And the selection should not default to a service-vendor, task-board, or MMO daily-request shape
