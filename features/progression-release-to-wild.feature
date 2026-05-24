@capability.living-world @capability.progression-permanence @feature.release-to-wild
Feature: Release to Wild
  Release to Wild is the first concrete NPC-led conservation loop. A Wildlife
  Rehabilitation Center run by a Wildlife Rehabilitator accepts real owned animal
  instances from the player. Base one-off release is always available, while
  optional local programs offer extra rewards for authored trait requests.

  Scenario: Release to Wild defines its game system
    Given Release to Wild belongs to the Progression-Permanence capability
    When the feature is expanded beyond its first design pass
    Then it should specify rehabilitation-center context, base one-off release, optional local programs, slot eligibility, irreversible release commits, reward grants, and preserved release history

  @action.open-release-to-wild
  Scenario: Player opens Release to Wild
    Given the player has discovered a Wildlife Rehabilitation Center NPC venue
    When the player opens Release to Wild
    Then the center's available release slots and local programs should be visible without changing animal ownership
    And the feature should be bound to the nearest eligible Wildlife Rehabilitator

  @action.inspect-release-bundle
  Scenario: Player inspects a local release program
    Given a local release program is available
    When the player inspects the local release program
    Then the visible contribution slots, requested habitat/type/trait predicates, release consequences, and extra rewards should be visible before any animal is committed

  @action.release-animal-to-wild
  Scenario: Player performs a base one-off release
    Given the player owns an active identified fauna find that is eligible for release
    When the player releases that animal to the wild
    Then the owned animal should leave the active Pack exactly once
    And the released animal should appear in the center's release ledger/history
    And Field Guide knowledge should remain available after release
    And the player should gain the flat base Orb item-stack reward for releasing any eligible fauna

  @action.release-animal-to-wild
  Scenario: Player contributes to a local trait-request program
    Given the player owns an active identified fauna find matching a requested habitat, animal type, or other current authored trait/tag for an open local program slot
    When the player releases that animal through the program
    Then the release should count toward the visible local program slots
    And the released animal should still be recorded in release history
    And any completed local program should grant its fixed bonus Orb item-stack reward exactly once

  Scenario: Release eligibility protects player state
    Given the player owns a fauna find
    When Release to Wild evaluates the find for release
    Then unidentified animals should be ineligible
    And animals serving as an active buddy, placed at Home, or already committed elsewhere should require those states to be cleared first
    And already released animals should be ineligible
    And otherwise any owned fauna may use the base one-off release slot

  Scenario: Base release and programs use different structure
    Given the center uses visible slot-filling as its core visual language
    When the player opens Release to Wild
    Then a simple always-open generic release slot should exist for any eligible fauna
    And optional local programs should add extra visible slots with tighter requirements for bonus rewards

  Scenario: Local release programs are durable and center-owned
    Given a city has one Wildlife Rehabilitation Center venue
    When that center offers a local "look for this trait" program
    Then the program should belong to that specific NPC and POI
    And incomplete program slots should preserve their committed releases over time
    And completed one-time programs should not reset as daily chores
