@issue596 @target_specification
Feature: Recognizable art accessible interaction and calibration
  Target acceptance specification from issue 596.
  Step definitions are not implemented by this specification-only change.
  Visual review and calibration scenarios require real rendering evidence.

  @visual_review @UI596-044 @Q028 @Q029 @Q030 @Q031 @Q032 @Q033 @Q034 @Q035 @A004
  Scenario: [UI596-044] Original small animal art emphasizes true identifying features
    Given two similar real animal species are represented in the approved reference-style art direction
    When their original EarthNova artwork is reviewed at Pack size
    Then simplified colors, clear outlines, and exaggerated real distinguishing features should preserve recognition
    And viewpoint and optical centering should favor the identifying shape and markings
    And shading and highlights should remain quiet enough not to erase those distinctions
    And imaginary anatomical traits should not be introduced for differentiation
    And stat icons should retain their separately approved shaded miniature-object treatment

  @calibration @UI596-045 @Q028 @Q033 @Q109 @Q110 @Q111 @A004
  Scenario: [UI596-045] The 12 and 16 pixel animal icons are trials not defaults
    Given the five-column iPhone Pack visual fixture includes similar animal species and crowded badges
    When 12-by-12 and 16-by-16 logical-pixel animal artwork trials are rendered at actual phone scale
    Then the review should record recognizability, outline legibility, and competition from badges for both sizes
    And the trial should preserve interactive targets of at least 44 logical pixels
    And neither trial should become the default merely because its image was rendered
    And the trial should not set navigation or all-category artwork sizes

  @visual_review @UI596-046 @Q106 @A005
  Scenario: [UI596-046] Idle motion is subtle staggered and interruptible
    Given visible Pack Items have suitable animation assets
    And the Player is not interacting
    When idle animation runs
    Then only a few visible Items should animate at the same time with staggered timing
    And animal breathing, plant sway, and highlight shimmer should remain subtle
    And property values and status badges should remain stable enough to scan
    And unavailable animation assets should retain static artwork
    And new input should never wait for an idle cycle to finish

  @behavior @UI596-047 @Q107 @A005
  Scenario: [UI596-047] Reduced motion keeps the same information
    Given the Player has requested reduced motion
    When Pack and an Item inspection are used
    Then artwork should remain still
    And decorative transforms and traveling highlights should be suppressed
    And essential pending/progress status should remain understandable
    And no information or action should require observing animation

  @visual_review @UI596-048 @Q108 @A007 @A013 @A014
  Scenario: [UI596-048] Larger text and tiny art do not shrink touch targets
    Given the Player uses larger system text on an iPhone review viewport
    When Pack, navigation, and inspection are rendered
    Then content should use additional height and scrolling while retaining touch targets of at least 44 logical pixels
    And the standard five-column Pack direction should not silently become a different density
    And navigation should have meaningful accessible destination names even when labels are hidden
    And allowed Item names should remain accessible in full
    And the accepted single-line shrinking rule should remain limited to inspection Item titles
    And a contrast review should include the dark Close control and black Unknown silhouette against the forest-green palette

  @calibration @UI596-049 @Q109 @Q110 @Q111 @A011 @A014 @A026
  Scenario: [UI596-049] Shared tokens are measured without inventing values
    Given the qualitative palette, bevel, radius, outline, typography, and motion directions are approved
    When candidate shared tokens are calibrated in actual-size iPhone fixtures
    Then spacing should begin from the existing shared vocabulary
    And border thickness, radii, shadow, text sizes, contrast, and transition durations should be recorded as measured candidate tokens
    And long names, multiple categories, mixed knowledge states, crowded badges, and unavailable actions should be included
    And no numeric value should be reported as an approved measurement before the review supplies evidence
    And the specification should not mandate a font family, animation library, or asset-production pipeline before solution-direction decisions

