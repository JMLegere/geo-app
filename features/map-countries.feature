@capability.map @feature.countries
Feature: Countries
  Countries are the national passport layer. They make long-term exploration feel
  coherent across states or provinces while staying rooted in real visited map cells.

  Scenario: Countries roll up regional progress
    Given the player has explored map cells across states or provinces in a country
    When they view the country scope
    Then the country should show regional rollups and national explored progress
    And it should make the player's broad travel footprint readable

  Scenario: Countries contextualize rare travel moments
    Given the player explores a new state, province, or distant city
    When country progress changes
    Then the country view should be able to frame that change as national exploration growth
    And the progress should feel earned by movement rather than abstract completion
