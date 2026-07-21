@capability.genetics @feature.genetics
Feature: Genetics legacy evidence
  Status: Genetics is not a resolved Discipline or settled target model. This
  retained Index scenario evidence is historical.

  Scenario: Genetics defines its data model
    Given Genetics is surfaced through the Index feature
    When the feature is expanded beyond this stub
    Then it should specify trait profiles, variation models, inheritance rules, and links to Lineage

  @action.view-genetics-guide
  Scenario: Player views Genetics guide
    Given the Index has a Genetics section
    When the player opens the Genetics guide
    Then trait and inheritance knowledge should be organized around variation and generations

  @action.inspect-trait-inheritance
  Scenario: Player inspects trait inheritance
    Given trait inheritance context is available
    When the player inspects trait inheritance
    Then Genetics should show inherited traits, variation, and lineage implications without starting a pairing
