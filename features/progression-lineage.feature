@capability.progression-permanence @feature.lineage
Feature: Lineage legacy evidence
  Status: Pairing, offspring, and inherited-trait behavior remain open. This
  retained historical evidence does not establish a current target lifecycle,
  and rarity is not a current mechanic.

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
