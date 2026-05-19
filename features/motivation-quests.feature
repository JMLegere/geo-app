@capability.motivation @feature.quests
Feature: Quests
  Motivation needs a concrete quests feature for science quest boards, quest
  details, progress state, and directed field-goal rewards.

  Scenario: Quests define their app section
    Given Quests belong to the Motivation capability
    When the feature is expanded beyond this stub
    Then it should specify science quest board, quest detail page, quest progress model, and quest reward model

  @action.open-quest-board
  Scenario: Player opens the quest board
    Given the player has access to quests
    When the player opens the quest board
    Then directed field goals should be visible without changing quest progress

  @action.inspect-quest
  Scenario: Player inspects a quest
    Given a quest is available
    When the player inspects the quest
    Then quest requirements, progress, science intent, and rewards should be visible without claiming anything

  @action.claim-quest-reward
  Scenario: Player claims a quest reward
    Given the player has an eligible completed quest
    When the player claims the quest reward
    Then the reward should be committed exactly once
