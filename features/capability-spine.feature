@capability.map @capability.zoology @capability.botany @capability.mycology @capability.geology @capability.paleontology @capability.genetics @capability.archaeology @capability.exploration-discovery-lifecycle @capability.living-world @capability.progression-permanence @capability.motivation @capability.multiplayer
Feature: EarthNova capability spine
  EarthNova's top-level capabilities describe the major player-facing areas of
  the app before concrete feature sections, scenarios, actions, and checks are authored.

  Scenario: The real world becomes the map
    Given EarthNova is organized around real-world movement
    When the capability spine is read at the top level
    Then Map owns map framing, trusted position, fog, cell border crossing, territories, and world event cues

  Scenario: Natural sciences organize Index knowledge and Discipline progress
    Given Identified Items can grant Discipline XP
    When the capability spine is read at the top level
    Then Zoology, Botany, Geology, Paleontology, and Archaeology are the resolved Disciplines
    And Index presents Base Items the player has Discovered
    And Discipline tuning remains open

  Scenario: Exploration has a precise Item lifecycle
    Given a Player explores the world by entering Cells
    When the capability spine is read at the top level
    Then Exploration records Cell Visits
    And a Cell Visit resolves a Selector to None or one Encounter
    And Encounter Outcomes may generate Items in Pack
    And Identification may record Discovery and populate Index

  Scenario: Town uses the approved people and place language
    Given the player knows a Venue
    When the capability spine is read at the top level
    Then Town indexes known Venues, Villagers, and Services
    And legacy NPC, place, and feature wording is not current target terminology

  Scenario: Durable progress remains scoped to approved and open rules
    Given persistent player progress needs a home
    When the capability spine is read at the top level
    Then every Player has one Home
    And Home Module behavior, Orb behavior, and other unresolved rules remain open

  Scenario: The player has reasons to return
    Given EarthNova should support purpose, pride, and continuity
    When the capability spine is read at the top level
    Then Motivation owns quests, achievements, recaps, goals, and return loops

  Scenario: Solo exploration contributes to a shared world
    Given EarthNova should feel friendly and social without breaking solo play
    When the capability spine is read at the top level
    Then Multiplayer owns community progress, community events, trading, and shared world meaning
