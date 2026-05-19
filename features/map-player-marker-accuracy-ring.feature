@capability.map @feature.player-marker-accuracy-ring
Feature: Player Marker + Accuracy Ring
  The Map marker is gameplay truth. Raw GPS stays internal; the player sees
  a marker and accuracy ring that explain trust without turning technical noise
  into bad gameplay.

  Scenario: Trusted marker state supports exploration
    Given raw GPS is accurate enough for play
    When the gameplay marker follows the player's movement
    Then the marker should move smoothly instead of teleporting
    And exploration should be eligible to record map cell visits and reveal fog

  Scenario: Trusted marker movement is speed bounded
    Given raw GPS moves to a nearby accurate point within the playable trust radius
    When the marker follows the updated location
    Then the marker should travel toward the point over multiple frames
    And its speed should scale with the current marker-to-geolocation gap, such as 100m/s at 100m away and 50m/s at 50m away
    And it should not cover most of the gap in a single visual jump


  Scenario: Distance gap enters ring state
    Given the geolocation fix is more than 100 meters away from the gameplay marker
    When the marker can no longer represent precise play
    Then the solid marker should dissolve or defer into an accuracy ring
    And the gameplay marker should still drag toward the geolocation fix
    And exploration should be paused so no visits, reveals, or discoveries fire from bad position data

  Scenario: Trust recovery resumes play
    Given the player is in ring state because location was unreliable
    When GPS stabilizes and the marker can converge again
    Then the ring should tighten back into the gameplay marker
    And exploration eligibility should resume from the recovered marker position

  Scenario: Ring state explains browse-only play
    Given the player is in ring state during the first playable slice
    When they look at the map
    Then the ring should communicate that they can inspect known map cells but walking will not count yet
    And the map should not show opportunity, cell entry, or discovery handoff cues as currently actionable

  Scenario: Same-cell movement is quiet
    Given the gameplay marker is trusted and remains inside the same map cell
    When the player walks without crossing a map cell border
    Then the marker should animate movement smoothly
    And the Map should not emit entry feedback, fog reveal, or visit mutation

  @action.move-in-real-world
  Scenario: Player movement drives marker state
    Given the player has a trusted or paused location state
    When the player physically moves with the app open
    Then the Map should update location, camera, and marker state through trust gates
