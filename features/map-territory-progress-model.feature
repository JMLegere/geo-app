@capability.map @feature.territory-progress-model
Feature: Territory Progress Model
  The territory progress model turns entered map cells into a larger sense of world
  growth. It is how a small walk becomes district, city, state, country, and
  world progress.

  Scenario: Map cell visits roll up into territory progress
    Given a visited map cell belongs to district, city, state, country, and world scopes
    When the visit is recorded
    Then each territory scope should be able to update its explored footprint and progress metrics
    And those rollups should be derived from visits rather than manually entered progress

  Scenario: Progress deltas make walking feel permanent
    Given the player has just crossed a border into a first-visit map cell
    When territory progress is recomputed
    Then the Map should be able to show what changed at the relevant territory scopes
    And the delta should help the player feel that a small movement made their world larger

  Scenario: Territory progress remains browseable while movement is paused
    Given exploration is paused because location is untrusted
    When the player opens district, city, state, country, or world scope
    Then existing territory progress should remain inspectable
    But no new progress should be recorded until exploration becomes eligible again

  @action.browse-territory-progress
  Scenario: Player browses territory progress
    Given the player is viewing a territory scope
    When the player browses progress at that scope
    Then the Map should show rolled-up exploration progress without changing visit history
