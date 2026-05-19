@capability.progression-permanence @feature.collections
Feature: Collections
  Progression-Permanence needs a concrete collections feature for collection
  catalog, collection details, bundle slots, donation or commit flow,
  cross-domain sets, and completion rewards.

  Scenario: Collections define their app section
    Given Collections belong to the Progression-Permanence capability
    When the feature is expanded beyond this stub
    Then it should specify collection catalog, collection detail pages, bundle slots, commit flow, and completion rewards

  @action.open-collections
  Scenario: Player opens Collections
    Given the player has access to Collections
    When the player opens Collections
    Then the collection catalog and set progress should be visible without changing collection membership

  @action.add-find-to-collection
  Scenario: Player adds a find to a collection
    Given the player owns a find eligible for a collection slot
    When the player adds the find to the collection
    Then the owned find should be committed into the collection slot, bundle, or set
