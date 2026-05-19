@capability.motivation @feature.recap
Feature: Recap
  Motivation needs a concrete recap feature for returning context, progress
  deltas, world changes, and dismissal state.

  Scenario: Recap defines its app surface
    Given Recap belongs to the Motivation capability
    When the feature is expanded beyond this stub
    Then it should specify return recap card stack, progress delta summary, world changes summary, and recap dismissal model

  @action.view-recap
  Scenario: Player views recap
    Given a return recap is available
    When the player views the recap
    Then progress deltas, world changes, and reasons to return should be visible without applying new progress

  @action.dismiss-recap
  Scenario: Player dismisses recap
    Given the player has seen a recap item
    When the player dismisses the recap
    Then that recap item should not replay later as new information
