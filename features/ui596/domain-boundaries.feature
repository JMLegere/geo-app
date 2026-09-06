@issue596 @target_specification
Feature: Presentation preserves EarthNova domain boundaries
  Target acceptance specification from issue 596.
  Step definitions are not implemented by this specification-only change.
  Visual review and calibration scenarios require real rendering evidence.

  @behavior @UI596-050 @Q047 @Q048 @Q087 @Q088 @A002
  Scenario: [UI596-050] Category comparison uses defined natural differences
    Given each Item Category has its existing property definitions
    When the Pack comparison property is configured
    Then one consistent applicable property per category should communicate a meaningful natural difference
    And inspection should use a stable category-specific property order
    And an undefined property should be documented as unavailable rather than invented
    And hidden or unrolled values should not be exposed
    And no universal strongest-stat, power, monetary value, or quality score should be introduced
    And Food and Orb should not be forced into a Discipline or an invented natural measure

  @behavior @UI596-051 @Q025 @Q049 @Q060 @Q073
  Scenario: [UI596-051] Rarity styling does not relabel conservation status
    Given the current model contains scientific Conservation Status
    And a category has no separately defined game rarity or tier
    When its Pack card, filters, progression, and counters are styled
    Then Conservation Status should retain its scientific meaning
    And it should not be converted to rarity merely because a legacy field is named "rarity"
    And tier framing should remain neutral where no tier exists
    And card progress should appear only for an existing relevant requirement
    And the UI should not invent currencies, universal Player levels, Relics, or Orb behavior

  @behavior @UI596-052 @Q049 @Q072 @Q073 @Q094 @A021 @A023 @A024
  Scenario: [UI596-052] Costs rewards and counters reflect existing systems
    Given an Item action has no defined resource cost, reward, or progress requirement
    When the action and the Pack strip are composed
    Then no placeholder gameplay currency, cost, reward, or progress mechanic should be invented to match the reference
    And existing Discipline progress may appear only with its defined meaning
    And applicable count progress should use current amount and requirement
    And appropriate defined metrics should be used for other supported progress

  @specification @UI596-053 @A026
  Scenario: [UI596-053] The design system remains one shared component vocabulary
    Given a target Pack or inspection component is ready for implementation
    When it is introduced into the application
    Then reusable styling should belong to the shared design taxonomy
    And feature screens should consume the shared public design API
    And semantic variants should supply palette and state styling
    And matching native design contracts, registry entries, and surface evidence should remain aligned
    And these integrity records should not be treated as proof that visual or behavioral acceptance tests have passed

