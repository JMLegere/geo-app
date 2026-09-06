@issue596 @target_specification @capability.exploration-discovery-lifecycle
Feature: Reference-derived EarthNova presentation
  Target acceptance specification from issue 596.
  Step definitions are not implemented by this specification-only change.
  Visual review and calibration scenarios require real rendering evidence.

  @visual_review @UI596-001 @A011 @A026
  Scenario: [UI596-001] Shared surfaces use the approved palette and depth
    Given a Pack or Item inspection surface is rendered
    When the Player views the surface at normal iPhone scale
    Then its presentation should use these shared semantic treatments:
      | element        | treatment                                               |
      | panel surface  | deep forest green role with subtle close-view texture     |
      | panel edges    | strong sculpted bevels and small rounded corners          |
      | outer outline  | thin dark outline                                        |
      | primary text   | warm cream role                                          |
      | emphasis       | gold role                                                |
      | information    | blue role                                                |
      | disabled       | neutral surface and muted text roles                     |
    And feature screens should not introduce independent color values
    And the artwork should be original EarthNova artwork rather than copied reference assets

  @visual_review @UI596-002 @A025
  Scenario: [UI596-002] Pack title uses a clean illustrated ribbon
    Given the Player opens Pack
    When the title is visible
    Then "Pack" should appear on a light ribbon with dark bold rounded lettering
    And the ribbon should span roughly half the viewport width
    And the ribbon should have folded ends with smooth clean edges and no wear
    And the lettering should have no prominent outline

  @visual_review @UI596-003 @Q001 @Q002 @Q003 @Q004 @Q006 @Q010 @Q011 @Q012 @Q014 @A027
  Scenario: [UI596-003] Retrieval controls follow the reference vocabulary
    Given the Player is browsing Pack
    When the retrieval toolbar is rendered
    Then search, sorting, sort direction, and filters should be grouped above the grid
    And the controls should have these treatments:
      | control        | treatment                                              |
      | search field   | light inset surface with dark bold text                 |
      | search icon    | magnifying glass at the right edge                      |
      | search width   | usable width after compact sorting and filter controls  |
      | sort property  | active property displayed as text                       |
      | sort direction | separate button containing a filled direction triangle  |
      | filter icon    | illustrated adjustment sliders                          |
    And the toolbar should remain usable without reducing interactive targets below 44 logical pixels

  @visual_review @UI596-004 @Q020 @Q021 @Q022 @Q023 @Q024 @Q026 @Q027 @Q044 @Q045 @Q046 @A001 @A002
  Scenario: [UI596-004] Cards allocate space to artwork and consistent properties
    Given an identified Item has an applicable configured category property
    When its card is rendered in the five-column iPhone Pack
    Then it should be a portrait card with these treatments:
      | region           | treatment                                                |
      | outside          | shared-scale gutters and tight consistent card gaps       |
      | corners          | small rounded corners                                    |
      | frame            | clear thin raised frame and small shadow                  |
      | artwork field    | quiet shaded background                                  |
      | property strip   | one compact bold line using a short label and value       |
      | strip contrast   | related to an applicable tier frame while remaining legible |
    And its Item name should not be visually printed in the grid
    And all owned active Items should remain browsable

  @visual_review @UI596-005 @Q025 @Q037 @Q039 @Q041 @Q042 @Q043 @Q050 @A002
  Scenario: [UI596-005] Card state cues have distinct meanings
    Given the Pack contains known and Unknown Items
    And a fixture Item has an already-defined rarity or tier
    When the Player scans and selects cards
    Then an applicable rarity or tier should own the strongest persistent card accent
    And a card without a defined tier should use a neutral frame
    And Unknown should use a ribbon overlapping the upper-left edge
    And the category symbol should have a consistent lower artwork-corner position
    And selection should remain distinguishable from the persistent tier through a surface or edge cue
    And lower-priority badges should move into inspection before the artwork is shrunk
    And no separate "New" badge should be shown

  @visual_review @UI596-006 @Q051 @Q052 @Q053 @Q055 @Q061 @Q062 @Q063 @Q064 @Q065 @Q066 @A007
  Scenario: [UI596-006] Category controls and navigation share the illustrated button grammar
    Given Pack is open with a selected category and destination
    When category controls and main navigation are rendered
    Then category controls should appear directly above the grid near retrieval controls
    And category and navigation controls should use beveled illustrated icon buttons
    And active controls should use a brighter face and a selection border
    And navigation illustrations should occupy most of their buttons
    And category counts should be secondary information revealed with Help labels
    And the Help control should be at an end of the navigation area
    And temporary destination labels should appear beneath their icons
    And any attention badge should represent an outstanding defined state
    And animal artwork trial sizes should not resize navigation icons

  @visual_review @UI596-007 @Q068 @Q069 @Q070 @Q071 @Q074 @Q075 @A012
  Scenario: [UI596-007] Balance counters are compact and preserve precise values
    Given the Player has applicable existing balances and Discipline progression
    When the Pack top strip is displayed
    Then a compact consistent set should remain visible inside the device safe area
    And counters should use dark capsules and bold readable numerals
    And each resource icon should follow its amount
    And full digits without grouping separators should be the default numeric display
    And an applicable numeric level badge should use a faceted hexagonal treatment
    And if a balance must be abbreviated to fit then its exact value should be available in its details
    And the strip should not reproduce unused space from the reference screenshot

  @visual_review @UI596-008 @Q076 @Q078 @Q079 @Q080 @A003 @A012 @A013
  Scenario: [UI596-008] Inspection retains the Item card beside its name
    Given the Player opens an Item inspection
    When the inspection header is rendered
    Then the panel should occupy almost the full viewport width with narrow side margins
    And the panel should cast a strong soft outer shadow
    And the reused Pack card should appear on the left with its badges and property strip
    And the name and concise identity details should appear on the right
    And the artwork card should start near one-quarter of the panel inner width
    And content should have generous outer padding and tighter spacing within related sections
    And Close should be a large dark "×" directly on the panel without a visible button frame
    And the Close control should retain a touch target of at least 44 logical pixels

  @visual_review @UI596-009 @A014
  Scenario: [UI596-009] Long Item names stay complete on one line
    Given an Item has a name longer than its available inspection title width
    When its inspection title is rendered
    Then the title should use rounded slightly playful extra-bold warm-cream-role lettering
    And the title should have a clearly visible dark outline
    And its initial size should be roughly twice the stat-value size
    And the title should shrink until the complete name fits on one line
    And it should not wrap, truncate, or scroll
    And the full allowed name should remain available to assistive technology
    And the long-name review should record the readability cost of the accepted shrinking exception

  @visual_review @UI596-010 @Q089 @A015 @A016
  Scenario: [UI596-010] Stat cells keep labels icons and values aligned
    Given an Item has four allowed properties to display
    When its inspection stat grid is rendered
    Then the first row should contain three stat cells and the fourth should start another row
    And each label should use the emphasis role above its dark inset bar
    And labels should align with the value area after the icon
    And bars should have small rounded corners
    And a large shaded miniature-object icon should overlap each bar's left edge
    And the cream-role value should be centered in the remaining bar space
    And comparable numeric values should use tabular numerals

  @visual_review @UI596-011 @Q090 @Q091 @A017 @A018 @A019
  Scenario: [UI596-011] Descriptions use one readable inset panel
    Given an inspected Item has allowed descriptions and effects
    When its detailed-description panel is rendered
    Then descriptions and effects should share one dark inset panel
    And headings and key numbers should use the emphasis role
    And body text should be bold primary-text-role lettering with a subtle dark shadow
    And spacing should be tight within a section and generous between sections
    And each effect should use a small round bullet
    And recurring property or effect names should use inline icons slightly taller than the letters
    And line height should prevent icon or text collisions
    And the panel-level information control should be a raised circular information-role button
    And its cream "i" should overlap the panel's upper-right border

  @visual_review @UI596-012 @Q094 @Q095 @Q096 @Q097 @Q098 @A020 @A021 @A022 @A023 @A024
  Scenario: [UI596-012] Progress outcome and action surfaces use the agreed hierarchy
    Given an existing Item action has a defined resource requirement and known outcome
    When its controls are rendered
    Then progress should use a wide shallow bar with small rounded corners
    And its glossy fill should have a bright upper edge
    And a large resource icon should overlap the left end
    And the current amount and requirement should be centered inside the bar
    And completion should retain a full bar and completed fraction without starting another action
    And the outcome preview should be a separate raised beveled panel with positive emphasis
    And main action buttons should have strong bevels and a thick lower edge
    And button labels should be extra-bold rounded lettering with a dark outline
    And the cost should appear inside the button below the label at roughly two-thirds its size
    And the cost resource icon should follow the amount
    And two actions should have equal-width side-by-side buttons with a quieter secondary fill
    And a known reward should appear directly beneath its associated button
