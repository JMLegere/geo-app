@capability.motivation @feature.achievements
Feature: Achievements
  Motivation needs a concrete achievements feature for milestone recognition,
  achievement diaries, unlock presentation, and progress tracking.

  Scenario: Achievements define their app section
    Given Achievements belong to the Motivation capability
    When the feature is expanded beyond this stub
    Then it should specify achievement list, achievement diary, achievement unlock toast, and achievement progress model

  @action.view-achievements
  Scenario: Player views achievements
    Given the player has access to achievements
    When the player views achievements
    Then achievement lists and milestone progress should be visible without mutating unlock state

  @action.inspect-achievement
  Scenario: Player inspects an achievement
    Given an achievement exists
    When the player inspects the achievement
    Then requirements, progress, diary context, and unlock history should be visible without claiming rewards
