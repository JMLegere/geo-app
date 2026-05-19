@capability.map @feature.fog-overlay
Feature: Fog Overlay
  The Map fog overlay is the primary visual reward for walking. It should
  feel like cozy accumulation, not a debug grid or a noisy technical mask.

  Scenario: First entry reveals the current map cell
    Given the fog state model marks a newly entered map cell as present
    When the overlay paints the next frame
    Then the current map cell should feel visibly revealed
    And the surrounding explored footprint should make the player's movement feel accumulated

  Scenario: Frontier teases without giving everything away
    Given there are unvisited map cells sharing a border with present or explored map cells
    When the fog overlay paints frontier territory
    Then frontier map cells should signal that something may be nearby
    But the overlay should deemphasize interior details until the player crosses their borders

  Scenario: Explored map cells remain visually distinct
    Given adjacent map cells share the explored fog relationship
    When the overlay paints their geometry
    Then each explored map cell should retain a visible dark neutral boundary
    And explored cells should not merge into one continuous explored blob


  Scenario: Unknown cells are opaque while frontier remains a tease
    Given unvisited map cells do not share a border with present or explored map cells
    When the overlay paints unknown territory
    Then unknown cells should fully hide the base map
    And frontier cells should remain translucent enough to suggest nearby possibility

  Scenario: Fetched geometry covers the visible GPS view
    Given a player has explored map cells near the edge of a wide GPS-level viewport
    When the map fetches geometry for the current position
    Then explored cells inside the visible viewport should have geometry available for rendering
    And unknown fog should not cover explored cells only because the fetch radius was too small

  Scenario: Overlay stays pinned to the base map
    Given the base map camera moves during GPS follow or debug movement
    When the fog overlay projects visible map cell geometry
    Then map cell borders should remain anchored to the same streets, rivers, and landmarks as the base map
    And the overlay should use the map renderer's screen-coordinate projection instead of an independent approximate camera model
    And any pre-projection fallback should use the same MapLibre world scale so cells do not resize between frames

  Scenario: Visual hierarchy keeps the map readable
    Given the marker, current map cell, fog states, cues, and base map are all visible
    When the overlay composes the GPS-level map
    Then marker or ring state should be easiest to read
    And present/explored/frontier relationship should be clearer than base-map detail
    And opportunity or event cues should not overpower the reveal state
