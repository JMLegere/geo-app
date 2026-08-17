@capability.exploration-discovery-lifecycle @proof.local-mvp-loop
Feature: Local exploration discovery MVP loop

  @action.resolve-present-encounter @action.continue-discovery-reward @action.examine-pack-item
  Scenario: Fresh Player keeps one committed discovery lineage through reload
    Given a fresh local-loop Player occupies a trusted Present Cell with one canonical pending Encounter
    And the local-loop Encounter has one authored canonical Option
    When the fresh local-loop Player resolves its canonical Encounter
    Then the local-loop resolution commits exactly one canonical Outcome and Item
    When the fresh local-loop Player continues the committed reward to Map
    Then the local-loop Pack begins with the same committed Item
    When the fresh local-loop Player taps that Pack Item for Examination
    Then the local-loop Examination recognizes the same Item exactly once
    When the fresh local-loop Player replays the resolution and Examination then reloads
    Then the local-loop reload preserves one linked entry-to-Examination lineage
