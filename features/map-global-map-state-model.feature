@capability.map @feature.global-map-state-model
Feature: Global Map State Model
  The global map state model is the BDD source for how daily map state is
  produced. These scenarios select a hybrid architecture: deterministic
  on-demand resolution for ordinary global map state, with persisted facts for
  claims, audits, special event instances, overrides, and intentional caches.

  Scenario: Daily state is shared for the same map cell
    Given two players can evaluate the same Voronoi map cell during the same GMT day
    When global map state resolves that cell's daily seed
    Then both players should receive the same map cell daily state identity
    And each player should keep separate visit history, fog state, claims, and inventory

  Scenario: The GMT rollover replaces missed daily state
    Given a Voronoi map cell had global daily state for yesterday
    And a player did not enter that map cell yesterday
    When the GMT day rolls over
    Then the map cell should resolve from today's global daily seed
    And yesterday's missed daily opportunity should not remain claimable as banked loot

  Scenario: Server time owns the daily refresh
    Given a client is in any local timezone
    When the client requests current map cell state
    Then the server-owned GMT period should decide the active daily seed
    And client-local time should not create, extend, or replay a daily opportunity

  Scenario: GMT rollover does not materialize every map cell
    Given the world contains more Voronoi map cells than should be written every day
    When the GMT day rolls over
    Then the system should create or activate the global period seed
    But it should not precompute daily opportunity rows for every map cell

  Scenario: Ordinary map state resolves from bounded demand
    Given the map frame needs current state for visible or nearby Voronoi map cells
    When the global map state model evaluates those bounded candidates
    Then each candidate should resolve deterministically from map cell id, period id, global seed, and resolver version
    And unobserved map cells should not require stored daily state

  Scenario: Map rendering needs a reward-clean global payload
    Given the map frame needs daily state for a visible or nearby Voronoi map cell
    When it resolves `GlobalMapCellState`
    Then the global payload should include:
      | field                 | purpose |
      | global_state_id       | shared identity for this map cell and active periods |
      | map_cell_id           | link to the Voronoi map cell geometry |
      | active_periods        | daily, weekly, season, and permanent period ids used by the resolver |
      | active_window         | GMT start and expiry for the shortest active period |
      | resolver_version      | versioned algorithm boundary for audit and cache invalidation |
      | activity_tier         | map-safe intensity for rendering cues |
      | cue_kinds             | map-safe cue categories without hidden reward details |
      | handoff_kinds         | downstream systems that may inspect after entry |
      | event_instance_ids    | persisted global events or overrides participating in state |
      | resolution_input_hash | debug/audit fingerprint without exposing raw seed values |
    And the global payload should not include user id, visit count, claim status, pack items, or species/item reward results

  Scenario: Player-facing state wraps global state with a personal overlay
    Given the same `GlobalMapCellState` is visible to multiple players
    When the app builds a player-facing map cell state view
    Then the view should keep the global payload unchanged
    And it should add a personal overlay for fog relationship, visit status, claim status, and eligible player actions
    But personal overlay fields should not change the shared `global_state_id`

  Scenario: Claims and audits persist after resolution
    Given a player receives a claimable handoff from resolved global map state
    When the player claims the result
    Then the claim should persist player id, map cell id, period id, global state id, handoff kind, and resolver version
    And the audit trail should explain why that claim was available
    But the map-state payload should not pre-own the final species, item, pack, or field-guide mutation

  Scenario: Special global events can override the deterministic baseline
    Given a globally authored event or manual override affects a map cell or territory
    When global map state resolves that location during the event window
    Then the persisted event instance or override should participate in the resolved state
    And the event identity should remain inspectable after the deterministic daily seed expires

  Scenario: Shared state supports social discovery without shared claims
    Given a global daily map state makes a map cell unusually active today
    When multiple players visit that map cell
    Then the map cell should feel like the same active world for everyone
    But each player should still earn only their own allowed visits, claims, and downstream rewards
