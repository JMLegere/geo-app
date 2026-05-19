@capability.progression-permanence @feature.lineage
Feature: Lineage
  Progression-Permanence needs a concrete lineage feature for ancestry,
  generation-to-generation variation, breeding outcomes, and inherited traits.

  Scenario: Lineage defines its game system
    Given Lineage belongs to the Progression-Permanence capability
    When the feature is expanded beyond this stub
    Then it should specify family trees, breeding pairing flow, offspring result model, inherited traits, and lineage rarity

  @action.pair-lineage
  Scenario: Player pairs lineage candidates
    Given the player has eligible lineage candidates
    When the player pairs the candidates
    Then the breeding pair should be committed and offspring result resolution should start

  @action.inspect-lineage-offspring
  Scenario: Player inspects lineage offspring
    Given lineage offspring exists
    When the player inspects the offspring
    Then inherited traits, variation, and family-tree context should be visible without starting a new pairing
