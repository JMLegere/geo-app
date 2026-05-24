@capability.map @capability.zoology @capability.botany @capability.mycology @capability.geology @capability.paleontology @capability.genetics @capability.archaeology @capability.exploration-discovery-lifecycle @capability.living-world @capability.progression-permanence @capability.motivation @capability.multiplayer
Feature: EarthNova capability spine
  EarthNova's top-level capabilities describe the major player-facing areas of
  the app before concrete feature sections, scenarios, actions, and checks are authored.

  Scenario: The real world becomes the map
    Given EarthNova is organized around real-world movement
    When the capability spine is read at the top level
    Then Map owns map framing, trusted position, fog, cell border crossing, territories, and world event cues

  Scenario: Natural sciences organize discovery meaning
    Given discoveries need disciplinary meaning rather than raw item taxonomy
    When the capability spine is read at the top level
    Then Zoology, Botany, Mycology, Geology, Paleontology, Genetics, and Archaeology own the science lenses that the Field Guide feature presents

  Scenario: Walking becomes discovery and find ownership
    Given movement should produce finds that players can keep and understand
    When the capability spine is read at the top level
    Then Exploration-Discovery Lifecycle owns discovery, pack ownership, identification, and find stories

  Scenario: The world has local NPC-led services
    Given major features should feel grounded in discovered places
    When the capability spine is read at the top level
    Then Living World owns NPC venue discovery, Town entries, local feature binding, and authored NPC functions

  Scenario: Discoveries become permanent progress
    Given found things need personal meaning over time
    When the capability spine is read at the top level
    Then Progression-Permanence owns the Field Guide, collections, sanctuary, buddy, lineage, and stewardship loops

  Scenario: The player has reasons to return
    Given EarthNova should support purpose, pride, and continuity
    When the capability spine is read at the top level
    Then Motivation owns quests, achievements, recaps, goals, and return loops

  Scenario: Solo exploration contributes to a shared world
    Given EarthNova should feel friendly and social without breaking solo play
    When the capability spine is read at the top level
    Then Multiplayer owns community progress, community events, trading, and shared world meaning
