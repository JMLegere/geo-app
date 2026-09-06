@issue596 @target_specification @capability.exploration-discovery-lifecycle
Feature: Immediate context-preserving Pack browsing
  Target acceptance specification from issue 596.
  Step definitions are not implemented by this specification-only change.
  Visual review and calibration scenarios require real rendering evidence.

  @behavior @UI596-013 @Q018 @Q019 @Q054 @Q060 @A001
  Scenario: [UI596-013] Category-first Pack preserves Item identity
    Given the Player owns multiple active Item instances across the seven canonical categories
    And some Items share the same Base Item
    When the Player opens Pack at standard iPhone text scale
    Then one category at a time should be displayed in five columns
    And every Item should retain its own selectable identity
    And empty categories should remain visible and openable
    And the result count below retrieval controls should count owned Item instances
    And default ordering should remain newest-first until explicitly changed
    And a second collection tab should appear only for a separately defined view
    And Pack should not become an Index completion view or acquire a Relics system

  @behavior @UI596-014 @Q005 @Q007 @Q008 @Q009
  Scenario: [UI596-014] Name search updates in place without changing scope
    Given the Player is browsing Flora with the search scope set to the current category
    And a known Item named "Garden Mint" is in Flora
    And a known Item named "Mint Beetle" is in Fauna
    When the Player types "Mint" in "Search Pack..."
    Then the Flora results should update from client-resident state without submission
    And "Garden Mint" should match
    And the scope should remain visibly set to Flora
    When the Player explicitly selects all-Pack search
    Then "Mint Beetle" should also match
    When the Player uses the in-field clear control
    Then the query should become empty without changing the chosen scope
    And none of these view changes should inspect or identify an Item

  @behavior @UI596-015
  Scenario: [UI596-015] Search does not disclose Unknown identity
    Given a Player has never inspected Base Item B
    And its hidden name would match a query
    When the Player searches or filters using that hidden name or hidden intrinsic metadata
    Then the Unknown Item should not reveal its name through a result, suggestion, count difference, or accessible label
    And only Player-permitted metadata should participate in search
    And an inspected Base Item name should remain searchable even though names are not printed on grid cards

  @behavior @UI596-016 @Q013
  Scenario: [UI596-016] Sort selection is immediately reversible
    Given a recognized Pack contains Items with distinct acquisition times and allowed names
    When the Player opens the anchored sort menu and selects Name
    Then the visible results should immediately use allowed-name order
    And the menu should retain the Pack context
    When the Player changes the sort direction
    Then the result order should reverse without an Apply or Done step
    And no Item or Base Item knowledge should change

  @behavior @UI596-017 @Q015 @Q016 @Q017
  Scenario: [UI596-017] Filters apply directly and expose their active state
    Given Pack has a current category, search query, and sort order
    When the Player opens filters
    Then the filters should appear in a bottom sheet over the current Pack
    When the Player changes an applicable filter
    Then the results should update immediately without an Apply step
    And the filter button should display an active-filter count
    And closing the sheet should retain the chosen filters, query, and sort order
    When the Player resets filters in the sheet
    Then the filter selections should clear without silently changing the category

  @behavior @UI596-018 @Q056
  Scenario: [UI596-018] Returning to a category restores browsing context
    Given the Player has scrolled within Flora and set a query, filters, and sort order
    When the Player opens and closes an Item inspection
    Then the same browsing context and scroll position should be restored
    When the Player visits Fauna and returns to Flora
    Then Flora's previous scroll position should be restored
    And navigating between categories should not implicitly reset the Player's deliberate view choices

  @behavior @UI596-019 @Q057 @Q058 @Q059
  Scenario: [UI596-019] Scrolling keeps important controls available
    Given the current Pack category contains more Items than fit onscreen
    When the Player scrolls the grid
    Then the compact balance/progression strip and main navigation should stay visible
    And compact retrieval and category access should remain available
    And the title ribbon may scroll out of view
    And a narrow track with a highlighted scrollbar thumb should indicate position
    And cards should clip cleanly at the viewport boundaries
    And fixed controls should not cover the final reachable Item

  @behavior @UI596-020
  Scenario: [UI596-020] View controls never clear Unknown
    Given a Player has never inspected a Base Item
    When the Player opens Pack, scrolls past its card, searches, filters, sorts, or opens Help
    Then that Base Item should remain Unknown to that Player
    And no examination, Identification, Discovery, or property-roll mutation should occur
