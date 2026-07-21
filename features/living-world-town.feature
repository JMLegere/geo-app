@capability.living-world @feature.town @feature.npc-venues
Feature: Town terminology and legacy venue evidence
  Status: The retained npc-venues feature tag and action identifiers are legacy
  evidence only. They do not establish placement, unlock, or binding behavior.
  The approved target uses Venues, Villagers, and Services.

  Scenario: Town is the index of known world relationships
    Given a Venue is known to the Player
    When the target Town surface is described
    Then Town indexes the known Venue, its known Villagers, and their Services
    And a Venue becomes known through a Reveal Venue Outcome
    And Villager introduction belongs to Venue Visits, not Encounter resolution

  @action.discover-npc-venue
  Scenario: Legacy venue-reveal identifier is preserved as evidence
    Given the legacy action identifier is still cataloged
    When its catalog entry is read
    Then it must not imply that Cell entry, NPC discovery, or Item acquisition is current target behavior

  @action.open-town
  Scenario: Town uses approved player-facing language
    Given Town has known entries
    When the player opens Town
    Then the entries are Venues, Villagers, and Services

  @action.open-npc-led-feature
  @action.open-npc-venue-detail
  Scenario: Legacy action identifiers do not redefine target language
    Given the retained action identifiers support existing evidence
    When their surfaces are described
    Then target language remains Service, Venue, and Villager
