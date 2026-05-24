@capability.living-world @capability.progression-permanence @feature.release-to-wild
Feature: Release to Wild
  Release to Wild is the first concrete NPC-led conservation loop. A zoo owner
  offers durable release bundles where players release owned animals to the wild
  in exchange for rewards. Releasing is an intentional irreversible commitment,
  not a daily task-board chore.

  Scenario: Release to Wild defines its game system
    Given Release to Wild belongs to the Progression-Permanence capability
    When the feature is expanded beyond its first design pass
    Then it should specify zoo-owner context, release bundles, slot eligibility, irreversible release commits, reward grants, and preserved release history

  @action.open-release-to-wild
  Scenario: Player opens Release to Wild
    Given the player has discovered a zoo owner NPC venue
    When the player opens Release to Wild
    Then the zoo owner's available release bundles should be visible without changing animal ownership
    And the feature should be bound to the nearest eligible zoo owner NPC

  @action.inspect-release-bundle
  Scenario: Player inspects a release bundle
    Given a release bundle is available
    When the player inspects the release bundle
    Then the bundle slots, accepted animal requirements, release consequences, and rewards should be visible before any animal is committed

  @action.release-animal-to-wild
  Scenario: Player releases an animal to the wild
    Given the player owns an active identified fauna find that matches an open release bundle slot
    When the player releases that animal to the wild
    Then the owned animal should leave the active Pack exactly once
    And release history should preserve the animal, source item identity, bundle, zoo owner, place, and timestamp
    And Field Guide knowledge should remain available after release
    And any completed bundle reward should be granted exactly once

  Scenario: Release eligibility protects player state
    Given the player owns a fauna find
    When Release to Wild evaluates the find for a bundle slot
    Then unidentified animals should be ineligible
    And locked, active buddy, Home-placed, already released, or otherwise committed animals should be ineligible
    And eligible animals should match the slot's authored species, taxonomic class, habitat, rarity, region, or conservation criteria

  Scenario: Release bundles are durable programs, not daily tasks
    Given the zoo owner offers release bundles
    When the player returns on another day
    Then incomplete bundles should preserve their committed releases and remaining slots
    And completed one-time bundles should not reset as daily chores
    And repeatable bundles, if added later, should use explicit season or program rules rather than implicit daily refresh
