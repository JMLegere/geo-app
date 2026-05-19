# EarthNova — Map System Design

> Source of truth for the map system. Supersedes any conflicting specs in
> `design.md`, `prd-game-systems.md`, or `docs/diagrams/solution/a-*.mmd`.
>
> Updated with the 2026-05-19 Map SuperBDD design pass.

---

## 1. Core Principles

The map serves three player questions:

1. **Where am I?** (orientation)
2. **Where have I been?** (progress / footprint)
3. **Where should I go?** (planning / motivation)

The primary emotional register is **cozy accumulation** — "my little world is growing."

### Map Capability Contract

The map is not just a map screen. It is the **Map** capability: a
player-facing game system where the real world becomes readable, revealable, and
worth crossing.

Terminology at this level is technical:

- **Map** is the capability/surface. Do not use "board" for first-slice contracts.
- **Voronoi map cell** is the generated playable polygon.
- **Map cell** is the shorthand for a Voronoi map cell.
- **Place** is reserved for future semantic geography such as POIs, parks,
  landmarks, named areas, or social claims layered on top of map cells.


The capability promise:

> The real world becomes a readable map that grows as I move.
The player should feel:

| Reward | Meaning | Primary features |
|--------|---------|------------------|
| **Orientation** | I know where I am. | Map Frame, Player Marker + Accuracy Ring |
| **Trust** | The game will not turn bad GPS into fake progress. | Player Marker + Accuracy Ring, Exploration Eligibility State |
| **Reveal** | The world opens because I moved. | Cell Border Crossing Model, Fog State Model, Fog Overlay |
| **Meaning** | I crossed a border into a Voronoi map cell, not just a polygon. | Cell Border Crossing Model, Map Cell Detail Sheet |
| **Pull** | I can see something nearby worth walking toward. | Nearby Opportunity Layer, World Event Cue Layer |
| **Scale** | My little footprint rolls up into a larger world. | Territory Navigation, Territory Progress Model |

Core loop:

```text
open map
→ orient on self
→ read present / explored / frontier
→ move physically
→ cross Voronoi map cell border
→ reveal or update footprint
→ acknowledge the map cell
→ optionally inspect, follow a cue, or zoom out
```

Design anti-goals:

- No debug-grid feeling.
- No raw GPS mechanics exposed as gameplay.
- No free rewards from unreliable position data.
- No random polygon crossing pretending to be named place semantics.
- No forced discovery popup before the player understands which map cell changed.
- No chore-map that turns nearby opportunities into obligations.

### First Playable Map Slice

The first playable slice should make one walk feel coherent before broader
systems arrive. It is intentionally not the full map fantasy.

| Included | Purpose | Not yet |
|----------|---------|---------|
| Map Frame | Open to a steady, trusted GPS-level map | Full territory dashboard polish |
| Map Debug Controls | Developer-only harness for marker movement and gesture testing | Player-facing debug UI or reward bypass |
| Player Marker + Accuracy Ring | Show gameplay position and pause bad-GPS exploration | Advanced marker personality/skins |
| Exploration Eligibility State | Gate mutations behind trusted movement | Anti-cheat scoring beyond basic validation hooks |
| Cell Border Crossing Model | Turn border crossing into one technical event | Rich POI naming or social place claims |
| Fog State Model + Fog Overlay | Make movement visibly reveal footprint | Full habitat art direction and animated biome treatment |
| Map Cell Detail Sheet | Explain which map cell changed and what the player can do next | Full Discovery/Pack/Field Guide reward reveal |


Map Debug Controls are supporting test infrastructure, not part of the
player-facing fantasy. They exist so the first playable slice can be exercised
with deterministic on-screen movement and gesture buttons before, during, and
after real walking QA.
First-slice success means:

1. The player opens the map and understands where they are.
2. The marker feels trustworthy or clearly paused by GPS uncertainty.
3. Moving across a Voronoi map cell border produces exactly one understandable
   cell-entry event.
4. Fog reveal visibly changes the map.
5. The map cell detail sheet explains the entry without forcing downstream reward
   logic.
6. Repeating the walk does not spam rewards or make the player distrust the map.

### First-Slice Moment Choreography

This is the implementation-ready player loop for the first slice.

| Moment | Trigger | Player sees | System commits |
|--------|---------|-------------|----------------|
| Map enters | Player opens Map tab | Spinning-world readiness cover, then GPS-level map | Starts/continues location, cell fetch, visit fetch, overlay readiness |
| Map steadies | Map, cells, location, and overlay are coherent | Marker/ring, current map cell, fog relationships | Emits steady/ready lifecycle state |
| Trust resolves | GPS is trusted or not trusted | Marker if trusted; ring/pause affordance if untrusted | Sets exploration eligibility to eligible or browse-only |
| Player moves | Marker moves within same map cell | Smooth marker movement, no reward spam | Updates marker state only |
| Border crossed | Eligible marker crosses a border into a different map cell | One cell entry moment | Records visit, emits one border crossing identity, recomputes fog |
| First entry | Entered map cell was unvisited | Fog reveal + medium acknowledgement | Marks map cell as visited; makes downstream handoff available if any |
| Re-entry | Entered map cell was already explored | Low-intensity continuity feedback | Records visit count; does not replay first-entry reward |
| Detail opened | Player taps current/entered map cell or entry affordance | Map cell detail sheet with context first | No downstream reward mutation unless player chooses handoff later |
| Trust lost | GPS diverges or accuracy degrades | Marker yields to ring; paused explanation | Stops visits, fog clearing, and discovery handoff |
| Trust recovered | GPS stabilizes | Ring tightens back into marker | Resumes eligibility without replaying stale border crossings |

### First-Slice State Contracts

The first slice should be designed around explicit contracts that tests and
observability can later enforce.

| Contract | Minimum fields / states | User-facing requirement |
|----------|-------------------------|-------------------------|
| `MapReadiness` | map created, style loaded, cells fetched, visits fetched, overlay painted, failure reason | Never show raw fog-free or empty-overlay gameplay as if ready |
| `MapDebugControlState` | developer mode, overlay visibility, simulated-location flag, last control, source | Let testers drive marker movement and gestures without exposing debug behavior as gameplay |
| `MarkerTrust` | locating, trusted, uncertain, ring, recovered; accuracy meters; marker/GPS gap | Explain whether walking can count without exposing raw GPS internals |
| `ExplorationEligibility` | eligible, browse-only, paused; reason; changed-at | Only eligible movement may record visits, reveal fog, or expose discovery handoff |
| `CellBorderCrossingEvent` | border_crossing_id, previous map cell, entered map cell, first/revisit, timestamp | All first-entry feedback for one border crossing shares one identity |
| `FogRelationship` | present, explored, frontier, beyond; computed source inputs | Fog state is reproducible from marker, nearby cells, and visit history |
| `CellEntryFeedback` | none, first-entry, revisit, suppressed; intensity | Reward level matches player action and avoids replaying first-entry treatment on revisits |
| `MapCellDetailState` | current map cell, territory context, visit status/count, available handoffs | Explain where before what; handoffs are secondary |

### First-Slice Transition Rules

These rules define when state is allowed to move and which side effects are legal.

| Contract | From → To | Trigger | Required side effects | Forbidden side effects |
|----------|-----------|---------|------------------------|------------------------|
| `MapReadiness` | not ready → ready | map created, style loaded, location ready, cells ready, visits ready, overlay painted | steady-state lifecycle event; GPS-level map can be shown as playable | visit mutation, fog mutation, or handoff exposure before ready |
| `MapReadiness` | any → failed | required dependency fails or times out | observable failure reason; non-playable fallback | pretending the map is ready |
| `MarkerTrust` | locating/uncertain → trusted | accuracy and marker/GPS gap are inside playable tolerance | marker shown as gameplay truth | retroactive visit/fog mutation for time spent untrusted |
| `MarkerTrust` | trusted → ring | gap or accuracy leaves playable tolerance | ring shown; pause explanation available | continue recording visits or revealing fog |
| `MarkerTrust` | ring → recovered → trusted | gap converges back inside tolerance | exploration may resume from current trusted state | replaying stale border crossings from while trust was lost |
| `ExplorationEligibility` | browse-only/paused → eligible | readiness is playable and marker trust is trusted | movement may mutate visits/fog and expose handoffs | hidden paused state |
| `ExplorationEligibility` | eligible → paused | trust is lost after being eligible | stop visit/fog/handoff mutation immediately | finishing an in-flight border crossing without re-validation |
| `CellBorderCrossingEvent` | none → emitted | eligible marker crosses from one map cell into another | one `border_crossing_id`; visit intent; fog recompute input | same-cell movement or untrusted movement pretending to be a crossing |
| `CellEntryFeedback` | none → first-entry/re-entry | border crossing event resolves plus visit result known | one intensity-appropriate acknowledgement | high-intensity discovery reward owned by Map |
| `CellEntryFeedback` | any → suppressed | event was no-op/untrusted | optional observability only | visible reward spam |


### Map Cell Detail Sheet Anatomy

The first-slice sheet is a field-note card, not a loot reveal modal.

1. **Map cell heading** — best available map cell label or fallback map cell identity.
2. **Status pill** — `Here now`, `First time here`, `Visited before`, or `Paused`.
3. **Territory context** — district/city/state/country when available.
4. **Visit facts** — first visit time, visit count, current presence.
5. **Fog/progress note** — what changed because of this entry.
6. **Secondary handoffs** — disabled/teased placeholders for Discovery, Pack,
   Field Guide, or World Events until those systems own real rewards.

The sheet should be dismissible and should never block continued walking unless a
downstream system later chooses to present a high-intensity reveal.

### First-Slice Payload Shapes

These are product/design contracts, not final Dart APIs. They define the minimum
information the first slice needs so implementation can stay testable and
observable.

| Payload | Required fields | Must not include yet |
|---------|-----------------|----------------------|
| `MapReadiness` | `map_created`, `style_loaded`, `location_ready`, `cells_ready`, `visits_ready`, `overlay_painted`, `ready`, `failure_reason` | Discovery/pack readiness |
| `MarkerTrust` | `state`, `gps_position`, `marker_position`, `accuracy_meters`, `gap_meters`, `reason` | Raw provider/plugin internals |
| `MapDebugControlState` | `developer_mode_enabled`, `overlay_visible`, `simulated_location_enabled`, `simulated_position`, `last_control`, `source`, `updated_at` | Production reward privileges or hidden bypass flags |
| `ExplorationEligibility` | `state`, `reason`, `can_record_visit`, `can_clear_fog`, `can_offer_handoff` | Anti-cheat score |
| `CellBorderCrossingEvent` | `border_crossing_id`, `previous_cell_id`, `entered_cell_id`, `border_crossing_type`, `is_first_visit`, `occurred_at` | Species/item reward results |
| `FogRelationshipSet` | `present_cell_id`, `explored_cell_ids`, `frontier_cell_ids`, `unknown_cell_ids`, `beyond_reason`, `computed_from_visit_count` | Persisted fog snapshot id |
| `CellEntryFeedback` | `border_crossing_id`, `kind`, `intensity`, `message`, `haptic_level`, `sound_key`, `suppressed_reason` | Loot/reward payload |
| `MapCellDetailState` | `cell_id`, `display_name`, `status`, `territory_context`, `visit_count`, `first_visit_at`, `current_relationship`, `available_handoffs` | Owned pack/field-guide mutations |


### First-Slice Field Schemas

Use snake_case for wire payloads, logs, fixtures, and SuperBDD examples. Dart
models can wrap these in typed value objects, but tests should still assert the
same field meaning.

Primitive contracts:

| Name | Shape | Notes |
|------|-------|-------|
| `GeoPoint` | `{ lat: double, lng: double }` | Coordinates are WGS84. Clamp latitude and longitude at the location-source boundary. |
| `MapCellId` | string | Stable server cell id such as `v_22982_-33321`; never parse gameplay meaning from it in the UI. |
| `BorderCrossingId` | string | Stable identity for one accepted border crossing decision. Reused by feedback and observability. |
| `TerritoryContext` | `{ district_id?, city_id?, state_id?, country_id?, labels? }` | Optional labels are display-only; ids drive rollups. |

| Model | Field | Type / values | Source | Critical rule |
|-------|-------|---------------|--------|---------------|
| `MapReadiness` | `map_created`, `style_loaded`, `location_ready`, `cells_ready`, `visits_ready`, `overlay_painted` | bool | owning adapters/widgets | All must be true before playable state. |
| `MapReadiness` | `ready` | derived bool | readiness coordinator | True only when every required input is coherent and no failure reason exists. |
| `MapReadiness` | `waiting_for` | string[] | readiness coordinator | Names missing dependencies for logs and loading copy. |
| `MapReadiness` | `failure_reason` | string? | dependency owner | Failing dependency must produce an observable reason. |
| `MapDebugControlState` | `developer_mode_enabled`, `overlay_visible` | bool | debug mode + tab shell | Debug controls are impossible to reach in normal player UI. |
| `MapDebugControlState` | `simulated_location_enabled` | bool | location provider | True means real GPS stream is paused for debug movement. |
| `MapDebugControlState` | `simulated_position` | `GeoPoint?` | debug movement control | Starts from current active location or beta fixture location. |
| `MapDebugControlState` | `last_control` | `move_north`, `move_south`, `move_west`, `move_east`, `gps_resume`, `pinch`, `spread`, `swipe_up`, `swipe_down`, `swipe_left`, `swipe_right` | debug overlay | Used for QA traces only; never drives rewards directly. |
| `MapDebugControlState` | `source` | `debug_controls` | constant | Required in telemetry for every debug-driven movement. |
| `MarkerTrust` | `state` | `locating`, `trusted`, `uncertain`, `ring`, `recovered` | marker coordinator | Only `trusted` may make exploration eligible. |
| `MarkerTrust` | `gps_position`, `marker_position` | `GeoPoint` | GPS source + marker spline | Marker position is gameplay truth; raw GPS is not player-facing gameplay. |
| `MarkerTrust` | `accuracy_meters`, `gap_meters` | double | GPS + spline | Crossing thresholds moves the player into ring/browse-only state. |
| `MarkerTrust` | `reason` | `gps_unavailable`, `accuracy_low`, `gap_too_large`, `trusted`, `recovered` | marker coordinator | Copy should explain playability, not plugin internals. |
| `ExplorationEligibility` | `state` | `eligible`, `browse_only`, `paused` | readiness + trust | This is the gate for every gameplay-significant mutation. |
| `ExplorationEligibility` | `can_record_visit`, `can_clear_fog`, `can_offer_handoff` | bool | derived flags | All false unless state is `eligible`. |
| `ExplorationEligibility` | `reason` | `not_ready`, `locating`, `gps_untrusted`, `ring_state`, `eligible`, `debug_simulated` | coordinator | Debug simulation can explain source, but does not bypass gates. |
| `CellBorderCrossingEvent` | `border_crossing_id` | `BorderCrossingId` | border crossing coordinator | One id per accepted crossing; no id for same-cell movement. |
| `CellBorderCrossingEvent` | `previous_cell_id`, `entered_cell_id` | `MapCellId?`, `MapCellId` | cell detection | Previous can be null only for first known cell. |
| `CellBorderCrossingEvent` | `border_crossing_type` | `first_entry`, `re_entry`, `invalid_untrusted` | crossing resolver | Only accepted `first_entry` / `re_entry` may produce visible entry feedback. |
| `CellBorderCrossingEvent` | `is_first_visit`, `occurred_at` | bool, timestamp | visit result + crossing clock | Accepted crossings may mutate visits/fog; invalid crossings do not. |
| `FogRelationshipSet` | `present_cell_id` | `MapCellId?` | current marker cell | Present overrides explored/frontier for rendering. |
| `FogRelationshipSet` | `explored_cell_ids`, `frontier_cell_ids`, `unknown_cell_ids` | `MapCellId[]` | visits + nearby cell geometry | Frontier requires a shared border with present/explored cells; fetched unvisited cells without a revealed shared border are unknown. Point-touching corners do not count. |
| `FogRelationshipSet` | `beyond_reason` | `outside_render_distance`, `not_fetched` | cell fetch/fog service | Beyond is a rendering/performance boundary, not a fetched-cell relationship state. |
| `FogRelationshipSet` | `computed_from_visit_count` | int | visits | Lets tests prove fog followed the same visit inputs. |
| `CellEntryFeedback` | `border_crossing_id` | `BorderCrossingId` | crossing event | Feedback identity must match the crossing identity. |
| `CellEntryFeedback` | `kind` | `none`, `first_entry`, `re_entry`, `suppressed` | feedback presenter | Map never emits downstream discovery reward payloads. |
| `CellEntryFeedback` | `intensity` | `none`, `low`, `medium` | feedback presenter | First entry is medium; re-entry is low. |
| `CellEntryFeedback` | `message`, `haptic_level`, `sound_key`, `suppressed_reason` | display/feedback fields | feedback presenter | Suppressed feedback can be silent but must be explainable in tests/logs. |
| `MapCellDetailState` | `cell_id`, `display_name`, `status` | `MapCellId`, string?, `here_now`, `first_time_here`, `visited_before`, `paused` | current cell + visits | Explain the map cell before any downstream reward. |
| `MapCellDetailState` | `territory_context`, `visit_count`, `first_visit_at`, `current_relationship` | context fields | hierarchy + visits + fog | Inspection is read-only for progression. |
| `MapCellDetailState` | `available_handoffs` | `discovery`, `pack`, `field_guide`, `world_event`[] | downstream capability availability | Handoff availability is not reward ownership. |

### First-Slice Mutation Matrix

| Trigger / action | Marker state | Visit rows | Fog state | Detail state | Handoff availability | Observability |
|------------------|-------------|------------|-----------|--------------|----------------------|---------------|
| Map becomes ready | maybe initialize | no | compute from existing visits | maybe seed current cell context | no | yes |
| Same-cell movement | update | no | no change except current-position recompute | no change | no | optional |
| Eligible border crossing into unvisited cell | update | yes | reveal + recompute | first-entry/current cell context | maybe yes | yes |
| Eligible border crossing into explored cell | update | yes | recompute without first-entry reveal | re-entry/current cell context | maybe yes if downstream says so | yes |
| Trust loss / ring state | update to ring | no | no new reveal | paused status allowed | no | yes |
| Trust recovery | update to trusted | no implicit replay | recompute current state only | maybe clear paused status | no implicit replay | yes |
| Opening map cell detail sheet | no change | no | no | open/detail state only | maybe expose existing handoffs | yes |
| Dismissing map cell detail sheet | no change | no | no | close/detail state only | no change | optional |
| Debug player movement | update from simulated location | only through normal eligible border crossing | only through normal fog rules | same as real movement | same as real movement | yes, source debug controls |
| Debug GPS resume | reload from real GPS | no implicit replay | recompute current state only | maybe clear paused/debug status | no implicit replay | yes |
| Debug gesture injection | no direct change unless normal gesture path changes state | no | no direct mutation | no direct mutation | no | yes, source debug controls |

### First-Slice Invariants

The first slice should be implementation-safe under noisy movement and partial
readiness.

1. **No ready-before-ready** — no playable map state until all readiness inputs are coherent.
2. **No same-cell mutation** — moving within one map cell must not record visits, clear fog, or emit entry feedback.
3. **No border-crossing replay** — trust recovery must not replay crossings that were invalid while paused.
4. **No reward payload leakage** — border crossing payloads stay reward-clean; downstream systems attach reward data later.
5. **No inspection mutation** — opening or reading the map cell detail sheet does not mutate progression by itself.
6. **No fake progress while paused** — browse-only/paused states may show context, but they must not imply that movement currently counts.
7. **No debug leakage** — debug controls must be visible only in developer mode and every debug-driven movement must be source-marked.
8. **No debug bypass** — debug movement and gesture buttons use the same readiness, trust, eligibility, border crossing, fog, and reward-clean gates as real input.

### First-Slice Component Responsibilities

The first slice should stay split by responsibility so future systems can attach
without turning the map into a god screen.

| Component / model | Owns | Does not own |
|-------------------|------|--------------|
| Map frame | Readiness, GPS-level framing, top-level composition | Border crossing rules or reward decisions |
| Map debug controls | Developer-mode marker movement, GPS resume, and gesture injection as test inputs | Player rewards, production UI, or bypassing map gates |
| Marker/ring layer | Position trust display and pause explanation | Visit recording |
| Cell/fog overlay | Geometry projection through MapLibre screen coordinates plus relationship visuals | Map cell labels or detail text |
| Border crossing coordinator | One border crossing identity and visit intent | UI animation style |
| Entry feedback presenter | First-entry/revisit copy, intensity, haptics/sound keys | Species/item reveal |
| Map cell detail sheet | Map cell context, current cell state, visit facts, handoff affordances | Downstream reward ownership |
| Observability hooks | Lifecycle and gameplay traceability | Product state source of truth |

### First-Slice Implementation Boundaries

These boundaries translate the product contracts into clean-architecture seams.
Existing classes can evolve toward these names; do not rename working code just
to match this table unless the rename clarifies a tested boundary.

| Boundary | Existing anchor / likely home | Owns | Reads | Emits | Must not |
|----------|-------------------------------|------|-------|-------|----------|
| Location source | `LocationNotifier`, `LocationRepository`, debug location methods | Real GPS, permission/error states, simulated debug location, GPS resume | Platform location adapter, debug controls | location state + `map.gps_*` / `map.debug_location_*` events | Detect cells, record visits, clear fog, or grant rewards |
| Marker trust | `PlayerMarkerNotifier`, marker domain config | Gameplay marker position, smoothing, ring transition, marker/GPS gap | Location source | `MarkerTrust` / marker state + GPS degradation/restoration events | Persist visits or decide discovery |
| Map readiness | Map frame + explicit readiness coordinator | Coherent playable/not-playable state across map style, cells, visits, location, overlay paint | Map widget lifecycle, location, cell fetch, visit fetch, overlay paint | `MapReadiness`, `waiting_for`, failure reason | Show playable fog/cell state before dependencies are ready |
| Cell data source | `MapNotifier`, `FetchNearbyCells`, `GetVisitedCells`, `CellRepository` | Nearby map cell geometry, hierarchy ids, visited set hydration | Location, auth/user id, Supabase read paths | fetched cells, visited ids, diagnostics | Compute fog snapshots, entry feedback, or rewards |
| Exploration eligibility | `ExplorationEligibility` provider/model | Whether movement may mutate visits/fog/handoffs | Readiness, marker trust, location/debug source | `ExplorationEligibility` + state-change telemetry | Mutate visits/fog itself |
| Cell border crossing coordinator | current `DetectCellEntry` plus future crossing resolver | Current cell detection, previous/entered cell comparison, one crossing identity, jitter/no-op decisions | Marker position, visible cells, eligibility, last accepted crossing | `CellBorderCrossingEvent` or no-op reason | Persist visits, play feedback, or expose reward payloads |
| Visit recorder | `RecordCellVisit`, `VisitQueueProvider`, cell visit port/repository | Append visit rows, optimistic visited set, failed-write queue | Accepted border crossing event, user id | visit result, visit count/source telemetry | Decide visual fog treatment or downstream rewards |
| Fog relationship service | `FogStateService` | Present/explored/frontier/beyond relationship set | Current marker cell, nearby cells, visit history | `FogRelationshipSet` | Persist redundant fog snapshots |
| Entry feedback presenter | presentation presenter/widget state | First-entry/re-entry/suppressed feedback copy, intensity, haptics/sound keys | Crossing event, visit result, fog relationship | `CellEntryFeedback` + acknowledgement telemetry | Reveal species/items/pack/field-guide rewards |
| Map cell detail state builder | detail sheet presenter/state | Field-note sheet state, status, visit facts, territory context, available handoffs | Current cell, territory hierarchy, visits, fog, downstream availability | `MapCellDetailState` | Mutate progression by inspection |
| Map debug controls | `DebugGestureOverlay`, tab shell callbacks | Developer-only marker movement, GPS resume, gesture injection | Developer mode, current location, gesture target | debug input events and normal downstream map events | Become production gameplay UI or bypass map gates |

Provider graph for the first playable slice:

```text
Location source
  ├─> Marker trust ─┐
  ├─> Cell data source ─┐
  └─> Map readiness ────┼─> Exploration eligibility
                         │
Marker trust + Cell data + Eligibility
  └─> Cell border crossing coordinator
        ├─> Visit recorder
        ├─> Fog relationship service
        ├─> Entry feedback presenter
        └─> Map cell detail state builder

Map debug controls
  ├─> Location source through simulated movement / GPS resume
  └─> Normal gesture path through injected pointer gestures
```

### First-Slice Build Order

The implementation order should preserve vertical-slice testability:

1. **Readiness gate** — prove the map cannot become playable until style, cells,
   visits, location, and overlay paint are coherent.
2. **Marker trust gate** — prove trusted/ring transitions are explicit and
   observable.
3. **Exploration eligibility** — derive one gate that every mutation must check.
4. **Cell border crossing identity** — emit one event for entering a new map
   cell and no event for same-cell or paused movement.
5. **Visit result** — append/queue visits only from accepted crossings.
6. **Fog relationship recompute** — derive present/explored/frontier/unknown/beyond from
   marker + cells + visits + shared-border geometry.
7. **Entry feedback + detail state** — explain the map cell and entry result
   without downstream rewards.
8. **Debug harness coverage** — use P↑/P↓/P←/P→ and gesture buttons to exercise
   the same path without requiring a real walk for every regression test.

### First-Slice Acceptance Matrix

| Case | Given | Expected outcome |
|------|-------|------------------|
| Cold open, trusted GPS | Cells, visits, style, and location become ready | Steady map frames marker, computes fog, and allows exploration |
| Cold open, bad GPS | Location is inaccurate or divergent | Ring/browse-only state appears; no visit/fog/discovery mutation can occur |
| Same-cell movement | Marker moves without crossing a boundary | Marker animates; no entry feedback or visit record fires |
| First border crossing | Eligible marker crosses a border into an unvisited map cell | One `border_crossing_id` records visit, reveals fog, and opens/queues first-entry feedback |
| Re-entry border crossing | Eligible marker crosses a border into an explored map cell | Visit count updates; feedback is low-intensity and does not replay first-entry reveal |
| Detail inspection | Player opens current/entered map cell detail sheet | Sheet explains cell/status/context before any downstream handoff |
| Trust loss mid-walk | GPS enters ring state after movement | Eligibility pauses immediately; stale border crossings are not replayed on recovery |
| Trust recovery | GPS stabilizes after ring state | Marker reforms and exploration resumes from current trusted state |
| Debug player movement | Developer mode overlay is visible | P↑/P↓/P←/P→ moves simulated location through the normal map pipeline with debug source telemetry |
| Debug gesture button | Developer mode overlay is visible | Pinch/Spread/swipe buttons inject the matching pointer gesture and exercise normal gesture handling |
| Debug GPS resume | Simulated location is active | GPS button exits simulation, restarts GPS, and does not replay stale debug crossings |


---
## Strategy Cascade Roadmap

### North Star

Make the map feel like: **"my little world is being revealed as I move through the real world."**

The first map release succeeds when a player can open the Map tab, see where they are, move into cells, and watch fog change from unknown/nearby to present/explored.

### Initiative 1 — Map Data Reality

**Strategic intent:** The app must render real cells, not placeholders or empty overlays.

#### Project 1.1 — Production cell fetch path

**Outcome:** Nearby cells load from Supabase with geometry and hierarchy intact.

**Work:**
- Use `fetch_nearby_cells(lat, lng, radius)` as the production fetch path.
- Stop reading raw `cell_properties` for render data when that path loses geometry.
- Hydrate `cell_id`, `habitats`, `polygon`, `district_id`, `city_id`, `state_id`, and `country_id`.

**JTBD user stories:**
- When I open the map, I want nearby cells to appear around my real position, so I know the world is divided into explorable map cells.
- When I move to a new area, I want the map to fetch the cells around me, so the visible world follows my exploration.
- When the app draws cells, I want them to have real polygon shapes, so the fog feels spatial instead of abstract.

#### Project 1.2 — Cell geometry contract

**Outcome:** The client and backend agree on one cell payload shape.

**Work:**
- Formalize `CellDto`.
- Test polygon decoding, empty polygon handling, hierarchy IDs, and habitat parsing.
- Exclude or safely ignore cells with unusable geometry.

**JTBD user stories:**
- When backend data changes, I want the client contract to fail loudly in tests, so the map does not silently render no fog.
- When a cell has missing geometry, I want it excluded or treated safely, so broken data does not crash the map.
- When a cell has multiple habitats, I want those habitats preserved, so the map can communicate terrain identity later.

### Initiative 2 — Gameplay Position Truth

**Strategic intent:** Exploration should be based on the custom marker, not raw GPS.

#### Project 2.1 — GPS input layer

**Outcome:** The app has a stable source of GPS state.

**Work:**
- Handle permission, active, loading, paused, denied, and error states.
- Preserve fallback/mock location support.
- Avoid blank map states during GPS startup or recovery.

**JTBD user stories:**
- When I launch the app, I want it to request/use location clearly, so I understand why the map needs GPS.
- When GPS is unavailable, I want a clear state, so I do not think the app is broken.
- When GPS recovers, I want the map to resume automatically, so I can keep walking without restarting.

#### Project 2.2 — Custom marker as gameplay truth

**Outcome:** The player marker controls exploration eligibility.

**Work:**
- Spline the marker toward GPS.
- Enter ring state when marker/GPS gap is too large.
- Pause exploration while ring state is active.
- Hide or conflict-check the native MapLibre GPS dot.

**JTBD user stories:**
- When GPS jumps, I want the marker to move smoothly instead of teleporting, so the map feels trustworthy.
- When GPS is inaccurate, I want discovery to pause visibly, so I know why walking is not revealing cells.
- When GPS stabilizes, I want the marker to reform and exploration to resume, so the game feels fair.

#### Project 2.3 — Fast smoothed camera follow

**Outcome:** The map camera follows raw GPS without visible jitter.

**Work:**
- Keep raw GPS as the camera target.
- Smooth the camera separately from the gameplay marker, with a faster catch-up curve.
- Preserve the custom player marker as exploration truth; camera smoothing must never record visits or affect discovery eligibility.
- Keep the native MapLibre GPS puck hidden so there is no second confusing dot.

**JTBD user stories:**
- When GPS jitters, I want the camera to ease rather than snap, so the map feels stable while I walk.
- When I ask “where am I,” I want the green dot to mean my gameplay marker, not a hidden raw GPS point.

### Initiative 3 — Fog State Engine

**Strategic intent:** Fog must be computed from visits and current position, not manually stored.

#### Project 3.1 — Current cell detection

**Outcome:** The app knows which cell the marker is currently inside.

**Work:**
- Add/keep a pure `CellDetectionService`.
- Cover point-in-polygon behavior, boundary behavior, and previous/current cell transition detection.

**JTBD user stories:**
- When I cross a cell boundary, I want the app to know I entered a new map cell, so exploration progresses with movement.
- When I stand near an edge, I want the app to choose a cell consistently, so visits are not random or duplicated.
- When no cell contains me, I want the app to fail safely, so it does not record bogus exploration.

#### Project 3.2 — Visit recording

**Outcome:** Eligible cell entries append to `v3_cell_visits`.

**Work:**
- Record only when the marker is not in ring state.
- Maintain an optimistic local visited set.
- Insert visits into the backend.
- Queue failed writes.
- Preserve every visit, not only unique visits.

**JTBD user stories:**
- When I enter a new cell with good GPS, I want the app to record that visit, so my explored world grows.
- When I revisit a cell, I want the visit to be remembered, so future streaks/counts can work.
- When the network fails, I want my visit to be queued, so exploration does not feel lost.

#### Project 3.3 — Fog relationship computation

**Outcome:** Every visible cell gets the right relationship state.

**Work:**
- Add/keep a pure `FogStateService`.
- Compute `present` for the cell containing the marker.
- Compute `explored` for visited but non-present cells.
- Compute `frontier` for fetched unvisited cells that share a border with a present or explored cell.
- Compute `unknown` for fetched unvisited cells that do not share a revealed border.
- Do not render unfetched/beyond cells as inspectable map cells.

**JTBD user stories:**
- When I am standing in a cell, I want that cell to look fully present, so I know where I am.
- When I have already visited a cell, I want it to remain revealed, so I can see my footprint.
- When a cell borders my revealed footprint but is unvisited, I want it partially obscured, so I feel pulled to explore.
- When a cell is fetched but does not border my revealed footprint, I want it fully hidden, so the world still feels mysterious.

### Initiative 4 — Fog Rendering Experience

**Strategic intent:** The computed fog state must become visible and understandable.

#### Project 4.1 — Cell overlay rendering

**Outcome:** The overlay visibly renders present/explored/nearby cells.

**Work:**
- Render Voronoi polygons with `CellOverlayPainter`.
- Prefer MapLibre's exact `toScreenLocationBatch` projection for marker, cell vertices, and cell centers so the overlay stays pinned to streets, rivers, and landmarks while the base map moves.
- Fall back to the synchronous Mercator projector only before exact screen coordinates are available.
- Fill by fog relationship.
- Border by revealed-cell relationship.
- Render no beyond/unavailable cells.
- Show loading shimmer while cells fetch.
**JTBD user stories:**
- When I open the map, I want nearby fog to be visible immediately, so the game map feels alive.
- When I walk into a cell, I want its visual state to change, so I feel progress.
- When I look around me, I want visited and unvisited cells to differ, so I can choose where to go next.

#### Project 4.2 — Cell detail interaction

**Outcome:** Tapping a cell explains what the color/shape means.

**Work:**
- Ensure the overlay can receive taps.
- Show `CellDetailSheet`.
- List habitats as text.
- Show visit count / first-visit status.
- Avoid color-only information.

**JTBD user stories:**
- When I tap a cell, I want to know what kind of map cell it is, so the map is readable.
- When habitat color is ambiguous, I want text labels, so I am not relying only on color.
- When I revisit a cell, I want to see that it has history, so my map feels personal.

### Initiative 5 — Map Acceptance and Safety

**Strategic intent:** Map correctness should be testable without walking around manually.

#### Project 5.1 — Pure domain tests

**Outcome:** Core map logic is covered outside Flutter UI.

**Work:**
- Test cell DTOs, cell detection, fog state, marker/ring behavior, and visit eligibility.

**JTBD user stories:**
- When a developer changes map logic, I want tests to catch broken fog behavior, so the map does not regress silently.
- When backend shape changes, I want DTO tests to fail, so empty fog does not ship.
- When GPS confidence logic changes, I want ring-state tests, so exploration remains fair.

#### Project 5.2 — Integration acceptance tests

**Outcome:** The slice proves the whole map loop.

**Work:**
- Use a fake location stream, fake cell query port, and fake visit port.
- Simulate movement across cells.
- Assert rendered state model and visit writes.

**JTBD user stories:**
- When location changes from cell A to B, I want the system to record B, so movement creates progress.
- When location is ring-state, I want no visit recorded, so bad GPS does not cheat exploration.
- When visits already exist, I want fog to render explored cells, so returning players see their footprint.

### Initiative 6 — Deferred Discovery Gameplay

**Strategic intent:** Do not attach species discovery until fog is real.

#### Project 6.1 — Encounter boundary

**Outcome:** The map exposes clean hooks for discovery later.

**Work:**
- Emit first-visit events.
- Do not build the full species reveal yet.
- Do not add the daily seed dependency yet.
- Do not add loot repopulation yet.

**JTBD user stories:**
- When I first visit a cell, I want the system to know it was first-time, so future discovery can trigger correctly.
- When discovery is added later, I want it to subscribe to map events, so map logic does not get tangled with species logic.

### Recommended sequence

#### Slice 1 — Map Data + Fog Correctness

1. Production cell fetch path
2. Cell geometry contract
3. Current cell detection
4. Visit recording
5. Fog relationship computation
6. Fog overlay rendering
7. Cell detail interaction
8. Acceptance tests

#### Slice 2 — GPS Trust and UX Polish

1. Permission/error states
2. Marker/ring refinement
3. Native GPS marker conflict removal
4. Discovery paused UX
5. Wake lock / battery behavior

#### Slice 3 — Map Progression Hooks

1. First-visit event boundary
2. Visit count display
3. Status bar real stats
4. Encounter hook, no species reveal yet

#### Slice 4 — Discovery Gameplay

1. Daily seed
2. Deterministic encounter
3. First-visit reveal
4. Revisit loot
5. Server validation

### Immediate roadmap item

**Initiative:** Fog-of-war map foundation

**Project:** Map Data + Fog Correctness

**JTBD target:** When I walk through the real world, I want the map to reveal cells around my true gameplay position, so I can see my personal exploration footprint growing.

**Build target:** A player can open Map, see real nearby cells, enter a cell, have that visit recorded, see that cell become present/explored, and tap cells for habitat/detail info.

---


## 2. Map Entry Point

The player taps the Map tab and lands on their **GPS position** — the street-level
cell view. This is the intimate, GPS-first framing. Zoom-out levels (District →
City → State → Country → World) are reached by pinch-close gesture.

There is **no manual pan or zoom** at the GPS level. The camera is always locked to
the player's GPS position. The only way to change what you see is to physically
move (GPS level) or pinch to change zoom levels.

### GPS-Level Interaction Stack

At GPS level, the player experiences one map composed of ordered layers:

| Layer | Purpose | Design rule |
|-------|---------|-------------|
| Readiness cover | Prevent raw loading/fog-free flashes | Uses the shared spinning-world loader and disappears only when map, cells, location, and overlay are coherent |
| Base map | Real-world orientation | Supports orientation but should not visually overpower fog state |
| Cell geometry | Playable map cells | Organic Voronoi cells represent crossable map cells, not debug geometry |
| Fog overlay | Reveal/progress reward | Present/explored/frontier/beyond must be legible at a glance |
| Opportunity/event cues | Soft pull | Suggest nearby possibility without creating chores or spoilers |
| Marker/ring | Position trust | Player marker is gameplay truth; ring explains uncertainty |
| Cell entry feedback | Semantic crossing | First-entry/revisit feedback answers "what changed?" |
| Map cell detail sheet | Inspectable meaning | Gives map cell context and handoffs without owning downstream rewards |
| Debug controls (developer only) | Deterministic QA input | Visible only in developer mode; feeds normal gesture/location paths and never bypasses gates |

### Map State Machines

The design should be state-first. Screens render state; they should not invent
gameplay meaning locally.

| State model | States | Why it exists |
|-------------|--------|---------------|
| Marker trust | locating, trusted, uncertain, ring, recovered | Prevents GPS noise from becoming fake gameplay |
| Exploration eligibility | eligible, browse-only, paused, resumed | Gates visits, fog clearing, and discovery handoff |
| Cell border crossing | same map cell, crossing, first visit, revisit | Makes movement semantic and prevents same-cell spam |
| Fog relationship | present, explored, frontier, beyond | Separates "where I am" from "where I have been" |
| Cell entry feedback | none, first-entry, revisit, detail-open | Controls reward intensity at crossing time |
| Territory scope | GPS, District, City, State, Country, World | Makes small movement accumulate into larger progress |
| Event visibility | inactive, hinted, inspected, expired | Keeps world events optional and secondary |
| Debug controls | hidden, visible, simulated-location, gps-resuming | Makes map movement and gesture testing deterministic without production leakage |
| Global map state | daily, weekly, season, permanent periods; active/expired | Keeps map-cell opportunities shared by world time instead of private player rolls |

### Reward Intensity Ladder

Map rewards should be paced by what the player actually did:

| Moment | Intensity | Treatment |
|--------|-----------|-----------|
| Marker stabilizes | Low | Quiet confidence, no celebration |
| Map cell re-entry | Low | Subtle tick, visit history/details available |
| First map cell border crossed | Medium | Fog reveal, map cell acknowledgement, stronger haptic/sound |
| Nearby opportunity noticed | Low-medium | Spatial tease, optional inspect |
| Territory progress delta | Medium | Small rollup/progress acknowledgement |
| Downstream discovery | High | Owned by Discovery/Identification/Pack, not the Map itself |

### Visual Grammar

The GPS-level map should feel organic and legible, not technical.

| Element | Visual intent | Jank to avoid |
|---------|---------------|---------------|
| Base map | Quiet real-world grounding | Bright cartographic clutter competing with fog |
| Present map cell | Bright, alive, immediately readable | Over-saturated debug highlight |
| Explored footprint | Warm muted permanence with individually countable cells | One continuous pale blob or grey dead-zone |
| Frontier | Dark translucent tease with minimal seams | Grid wall, spoiler detail, or harsh cutoff |
| Unknown / beyond render distance | Fully opaque fog unless explicitly frontier | Base-map details leaking through unreachable or unloaded cells |
| Cell borders | Thin dark neutral revealed-cell mosaic seams; hidden in frontier/unknown | Universal debug grid, heavy outlines, or invisible explored/explored boundaries |
| Opportunity cue | Small spatial promise | Quest marker/chore icon |
| World event cue | Unusual but optional disturbance | Alarm state or mandatory diversion |
| Map cell detail sheet | Cozy field-note card | Modal popup that blocks walking momentum |

The key visual hierarchy is:

```text
marker/ring > current map cell > fog relationship > cell cue > base map detail
```

If the player cannot tell whether they are present, explored, frontier, or paused,
the visual design has failed even if the geometry is correct.

---

## 3. Cell System

### Generation

- **Server-seeded Voronoi cells** stored in Supabase
- Variable density, **~100m average** cell size everywhere
- Pre-computed during a cell generation pipeline
- **Every point on Earth is a cell**, including oceans — no gaps


### Current Beta Geometry Source

The active beta source after the May 2026 visual-correctness pass is
`organic-voronoi-beta-v1`. It preserves existing `v_<x>_<y>` cell IDs and visit
history, but no longer uses the encoded lattice centers as Voronoi sites.
Instead, Supabase stages deterministic jittered centroids, generates true
PostGIS Voronoi polygons, clips them to the existing beta coverage footprint,
validates topology, and publishes through the immutable `cell_geometry_*`
source-version flow.

Traceability:

- staging function: `stage_cell_geometry_from_organic_centroids(...)`
- centroid dataset version: `earthnova-organic-centroids-beta-v1`
- generation mode: `db-deterministic-jittered-centroid-voronoi`
- geometry contract: `true-voronoi-clipped-to-lattice-coverage`
- validation/publish audit: `cell_geometry_validation_runs`,
  `cell_geometry_validation_issues`, `cell_geometry_publish_events`

### Cell ID

Implementation-defined. Must be deterministic and support the encounter formula
`SHA-256(seed + "_" + cellId)`.

### Cell Properties

Each cell has:

| Property | Type | Source |
|----------|------|--------|
| Habitats | Multi-select from 7 types | Pre-computed from real-world geodata (OSM land-use, satellite classification, etc.) |
| Neighborhood / District | Persistent | Geographic hierarchy lookup |
| City | Persistent | Geographic hierarchy lookup |
| State | Persistent | Geographic hierarchy lookup |
| Country | Persistent | Geographic hierarchy lookup |
| Active encounters | Temporary | Seed-based computation |

### Global Map State

Daily map-cell opportunity is **global map state**, not a private per-player roll.
The same Voronoi map cell on the same GMT day resolves to the same active map
state for every player. Player-specific systems still own personal fog, visit
history, claims, pack contents, and downstream reward ownership.

Design rules:

- The server/DB owns the GMT period clock; client-local time cannot create,
  extend, or replay daily opportunities.
- The daily seed refreshes at midnight GMT. If a player misses a map cell's daily
  state, they miss that specific opportunity.
- Do not bank missed daily loot, leave catch-up residue, or stack unclaimed daily
  rewards for later harvesting.
- Weekly, seasonal, and permanent seeds may layer on top of the daily seed, but
  they are also shared map-world state unless explicitly designed otherwise.
- Global map state can support social discovery ("this cell is active today")
  while claims/rewards remain personal and auditable.

Hybrid resolution contract:

This architecture is selected by `features/map-global-map-state-model.feature`.
The BDD requirements rule out a fully personalized resolver, because two players
must see the same map-cell daily state, and they rule out a full daily
materialization job, because GMT rollover must activate a period without writing
every map cell. The persistence requirements come from claim auditability, manual
overrides, world event instances, and intentional debug/cache snapshots.

- Canonical current state is resolved on demand from
  `map_cell_id + period_id + global_seed + resolver_version`.
- Persist global period records: daily, weekly, season, and permanent seed
  identities plus resolver/version metadata.
- Persist player-specific facts: visits, fog inputs, claims, pack acquisitions, and
  claim/audit records.
- Persist globally authored or operational facts: special world event instances,
  manual overrides, event windows, and cache/snapshot rows that have an explicit
  audit/debug purpose.
- Do **not** materialize daily rows for every map cell at GMT rollover. The
  rollover changes the active period; the resolver computes map-cell state when
  the app needs it.

BDD-derived resolver payloads:

| Payload | Required fields | Must not include |
|---------|-----------------|------------------|
| `GlobalMapCellState` | `global_state_id`, `map_cell_id`, `active_periods`, `active_window`, `resolver_version`, `activity_tier`, `cue_kinds`, `handoff_kinds`, `event_instance_ids`, `resolution_input_hash` | `user_id`, visit counts, claim status, owned pack items, species/item reward results, raw seed values |
| `PlayerMapCellStateView` | `global_state`, `personal_overlay` with fog relationship, visit status, claim status, and eligible player actions | Mutation results from downstream Discovery, Pack, Identification, or Field Guide |

Field meaning:

- `global_state_id` is the stable shared identity for one map cell and active
  period set. It must be identical for every player resolving the same map cell
  during the same GMT daily period.
- `active_periods` names the daily, weekly, season, and permanent periods used
  by the resolver; it references seed identities but does not expose raw seed
  values to the client.
- `active_window` carries GMT start and expiry. The daily window is the shortest
  active period and controls daily opportunity expiration.
- `activity_tier`, `cue_kinds`, and `handoff_kinds` are map-safe summaries. They
  may say that something is active or inspectable, but they do not own the final
  species/item/pack reward.
- `event_instance_ids` links persisted global events or manual overrides into
  the otherwise deterministic state.
- `resolution_input_hash` gives audit/debug reproducibility without leaking the
  raw global seed.

### Habitat Types & Colors

| Habitat | Color | Hex (TBD) |
|---------|-------|-----------|
| Forest | Green | — |
| Ocean | Purple | — |
| Freshwater | Blue | — |
| Swamp | Grey | — |
| Desert | Orange | — |
| Plains | Yellow | — |
| Mountain | Red | — |

---

## 4. Cell Visual Model

### Two Orthogonal Axes

**Axis 1 — Relationship** (how the player relates to the cell):

| State | Visual | Info Shown |
|-------|--------|------------|
| **Present** | Bright, full reveal, real map tiles visible | Everything: terrain, markers, species |
| **Explored** | Muted parchment veil, real map tiles dimmed | Species found, visit count, loot icon if repopulated |
| **Frontier / Nearby** | Translucent black reveal fog, interior details deemphasized, grid seams suppressed | Reachable unexplored territory, "something's here" tease |
| **Beyond render distance** | Not rendered / black void | Nothing |

**Axis 2 — Contents** (what's in the cell right now):

| State | Visual |
|-------|--------|
| Empty | No icon |
| Has loot / encounter | Small icon on cell interior |

The loot icon is the same visual regardless of relationship state — it appears
on Present, Explored, and Nearby cells. On Nearby cells it doubles as the
"something's here" signal.

### Cell Border

The cell border color is the **weighted RGB average** of all the cell's habitat
colors, producing a single solid blended color. In the current beta renderer,
that habitat seam is visible for Present and Explored cells only; Frontier and
Unknown seams are suppressed so unrevealed territory does not turn into a debug
grid.

- Single-habitat cells have pure colors
- Multi-habitat cells produce unique blended hues
- Swamp (grey) acts as a desaturator in blends

### Cell Interior

Neutral fill. Brightness/opacity is controlled by relationship state. The
interior is NOT habitat-colored — habitat is communicated only through the
border on revealed territory.

### Render Distance

- **~2km radius** from the player's GPS position
- **~1,200 cells** within the render boundary
- **Hard cutoff** — cells beyond render distance are simply not rendered (black void)
- Render distance is like Minecraft fog — a performance/design boundary, not a
  player-facing game state

---

## 5. Player Marker

### Visual

Abstract icon matching the EarthNova aesthetic. Not a literal avatar, not a plain
dot — something with personality.

### Movement (Spline Behavior)

The player marker is **separate from the GPS position**. GPS position is internal
and never shown to the player.

- The marker **smoothly splines toward the GPS position** at all times
- Spline speed is **proportional to the distance** from the GPS position:
  - Close (< 5m): nearly locked on
  - Walking distance (~10-20m): follows at walking pace
  - Driving/GPS jump (100m+): moves fast but visibly traveling
- The marker never teleports

### GPS Accuracy Ring

An accuracy radius ring is shown around the marker, reflecting GPS confidence.

### Ring State (GPS Divergence)

When the distance between the marker and GPS position becomes too large (the
marker can't meaningfully converge):

1. The solid marker **dissolves / animates into the accuracy ring**
2. The ring represents "you're somewhere in here"
3. **Exploration is suspended** — no cell visits recorded, no encounters triggered
4. The player can still interact with the map normally (browse, tap cells, check
   explored territory)

When GPS stabilizes and the gap shrinks:

1. The accuracy ring **tightens**
2. The solid marker **reforms out of the ring**
3. Exploration resumes

### Driving Filter

There is no explicit speed limit. Driving is filtered **naturally** by the spline
physics — at high speeds, the marker can't keep up with GPS, the gap grows, and
the marker dissolves into the ring. Ring state = no exploration.

### Camera

The camera and ring are **always centered on the GPS position** (the real one, not
the marker). When GPS jumps (e.g., air travel), the camera jumps with it.

---

## 6. Zoom-Out Levels

### Architecture

| Level | Renderer | Visual Style |
|-------|----------|-------------|
| **GPS (Cell)** | MapLibre + custom Voronoi overlay | Real map tiles + Voronoi cells |
| **District → World** | Flutter CustomPainter / Canvas | Stylized geo outlines on dark dashboard |

The pinch-close transition from GPS level **crosses a rendering boundary** — from
MapLibre into Flutter Canvas. This transition must be smooth and animated.

### Fog of World Passport Style

All zoom-out levels follow the [Fog of World](https://fogofworld.app/) passport
aesthetic:

- **Dark dashboard background**
- **Stylized geographic outlines** (silhouettes of regions) — colored by
  exploration percentage
- **Player stats header** — avatar, explored area, level
- **Sub-region labels** with territory counts (e.g., "Downtown 42/100 cells")
- **GPS mini-map** in corner — always shows real-world position as context
- **Region label** in large type (like "AS", "EU", "W" in Fog of World)
- **Breadcrumb** for hierarchy navigation (World > Canada > NS > Halifax)

### Level Hierarchy

| Level | Visual Unit | Shows |
|-------|-------------|-------|
| **District** | Cells grouped into district region | Cell-level exploration %, habitat composition |
| **City** | Districts as colored regions | Per-district %, species count |
| **State** | Cities as elements on state outline | Per-city exploration |
| **Country** | States as colored regions on country outline | Per-state exploration |
| **World** | Countries on world map | Per-country exploration |

### Transitions

- **Discrete levels** — the view is always at one specific level
- **Smooth animated transitions** triggered by pinch gestures
- **Pinch-close** = zoom out (GPS → District → City → ...)
- **Pinch-spread** = zoom in (... → City → District → GPS)

### Navigation

- **Region label** in large type at each level
- **Breadcrumb trail** for hierarchy context (World > Canada > Nova Scotia)
- Tapping a breadcrumb segment navigates directly to that level

### Geographic Boundary Data

Zoom-out levels require pre-computed, simplified vector paths for geographic
regions (country outlines, state shapes, city boundaries, district shapes). These
come from the geographic hierarchy tables with `boundary_json` columns.

---

## 7. Cell Visits

### Trigger

- **Instant on cell border crossing** — when the player marker enters a new cell
- The marker must **not be in ring state** (GPS must be confident)
- No dwell time, no speed limit check

### Recording

- **Every visit is recorded** in `v3_cell_visits` (no UNIQUE constraint)
- **First visit is special**: clears fog, creates a first-entry map cell event, and may hand off to Discovery when that downstream system is enabled
- Subsequent visits are recorded as continuity; they may produce quiet revisit feedback or downstream loot only when another system says something has repopulated

### Offline

- **Optimistic** — cell visits are credited immediately on the client
- Background sync confirms with Supabase
- **Server-side clawback** if validation detects cheating (impossible distances,
  speed, timestamps)
- The honest player never notices a hiccup

---

## 8. Discovery Handoff Boundary

The Map owns movement truth, fog reveal, map cell acknowledgement, and the
map-visible cues that make a player want to keep walking. It does **not** own the
full reward reveal for species, items, identification, pack ownership, or field
guide knowledge.

### First Visit Map Cell Moment

When a player visits a map cell for the first time:

1. The border crossing model emits one first-entry map cell event.
2. Fog state changes from frontier/unknown to present/explored.
3. The overlay gives a medium-intensity reveal treatment.
4. The map cell detail sheet can acknowledge the map cell and show territory context.
5. Discovery may later consume the event to produce finds, species, identification,
   or pack rewards.

This avoids reward jank: the player first understands **where** they arrived, then
downstream systems can explain **what** they found.

### Revisit Map Cell Moment

When a player revisits an already explored map cell:

1. The visit is still recorded.
2. The map gives low-intensity continuity feedback.
3. The map cell detail sheet can show visit history and current context.
4. Discovery/loot systems may react only if they have an explicit repopulated or
   event-driven reason.

### Event Response System

| Event | Map response | Downstream owner |
|-------|----------------------|------------------|
| First map cell visit | Fog reveal + map cell acknowledgement | Discovery decides finds/rewards |
| Map cell re-entry | Quiet continuity + visit history | Discovery/loot only if repopulated |
| Nearby opportunity | Spatial tease | Discovery/World Events decide details |
| World event cue | Optional inspectable map cue | Event-specific system decides rewards |
---

## 9. Sound & Haptics

Map feedback should be juicy but proportional. The map is cozy and
movement-first; feedback should explain state changes without interrupting the
walk unless a downstream system explicitly takes over.

| Interaction | Sound | Haptics |
|-------------|-------|---------|
| Marker trust restored | Quiet settle | Very light |
| Map cell re-entry | Soft tick | Subtle tick |
| Fog clear / first map cell visit | Satisfying reveal | Medium pulse |
| Nearby opportunity noticed | Light shimmer | Optional light |
| Territory progress delta | Warm progress chime | Medium pulse |
| Zoom level transition | Smooth transition sound | Feedback as levels change |
| Downstream discovery reveal | Owned by Discovery/Identification | Owned by downstream system |

---

## 10. Data Architecture

### Rendering Stack

| Level | Engine |
|-------|--------|
| GPS (Cell) | **MapLibre** (overrides AGENTS.md ban) — real-world vector tiles + custom Voronoi polygon overlay |
| District → World | **Flutter CustomPainter** — stylized geo outlines, no map tiles |

### GPS

- **Package**: `geolocator` (overrides AGENTS.md ban — add back now that map is being built)
- **Update frequency**: Adaptive (high while moving, low when stationary)
- **Accuracy threshold for ring state**: ~30-50m (half a cell)

### Data Fetching

- **Radius fetch + in-memory cache**
- On GPS update, fetch all cells within ~2km render distance
- Cache cell geometry and properties in memory
- Re-fetch when player approaches the cache boundary
- Cell geometry is static (doesn't change) — safe to cache aggressively
- Dynamic data (visit history, loot state) fetched separately, per-user

### Cell → Hierarchy Linkage

Each cell must map to: district → city → state → country. This mapping is
computed during cell generation and stored server-side. Required for zoom-out
level aggregation.

---

## 11. Edge Cases

| Case | Behavior |
|------|----------|
| **New player** | Natural state is enough. One bright cell + nearby cells visible + immediate first encounter. Achievements/tasks help later. |
| **Travel / teleportation** | Camera + ring always centered on GPS. GPS jumps → camera jumps. Marker in ring state until convergence at new location. New cell data fetched for new area. |
| **Ocean / Antarctica** | Everything is a cell. Ocean cells have "ocean" habitat (purple border). Players on boats explore ocean cells. |
| **Cell boundary edge** | Cell the marker is in gets the visit credit. Voronoi guarantees every point maps to exactly one cell. |
| **GPS permission denied** | Prompt on app launch. If denied, map tab shows a permission-required state. |
| **Perpetual bad GPS** | Ring state persists. Player can still browse map but can't explore. No special relaxation — GPS must actually improve. |

---

## 12. System Details

### Battery

Aggressive — full quality always. GPS + rendering + network at full rate. The game
is the primary activity while walking.

### GPS Permission

Requested on **app launch** (not deferred to first Map tab open).

### Tab State

Map state is **fully preserved** across tab switches (zoom level, loaded cells,
camera position). Uses `IndexedStack` or equivalent.

### Accessibility

Habitat information is color-only (border blend). **Color + label on tap** — tapping
any cell shows habitat names in text via bottom sheet.

### Loading States

**Spinning-world loader** while app, GPS, or map readiness is blocking play. The
shared loader cycles 🌍 → 🌎 → 🌏 instead of ellipses so loading still feels
EarthNova-native.

**Shimmer / skeleton cells** while cell data is being fetched. Cell shapes appear
as grey shimmering placeholders, fill in with real data as it arrives.

---

## 13. Observability Events

All map state transitions must log through `ObservabilityService`.

| Event | Trigger | Key Data |
|-------|---------|----------|
| `map.cell_entered` | Marker crosses a Voronoi map cell border | cell_id, is_first_visit |
| `map.cell_visited` | Visit recorded (marker not ring) | cell_id, user_id, visit_count |
| `map.cell_border_crossed` | Border crossing model emits a map cell event | previous_cell_id, entered_cell_id, border_crossing_type |
| `map.exploration_eligibility_changed` | Movement becomes eligible, paused, browse-only, or resumed | previous_state, next_state, reason |
| `map.cell_entry_acknowledged` | First-entry or revisit feedback is shown | cell_id, entry_type, district_id |
| `map.discovery_handoff_available` | Map exposes a downstream discovery/loot/event affordance | cell_id, handoff_type, owner |
| `map.fog_cleared` | First visit reveals map cell | cell_id, district_id |
| `map.zoom_changed` | Level transition | from_level, to_level |
| `map.gps_accuracy_degraded` | Marker → ring | accuracy_meters, gap_meters |
| `map.gps_accuracy_restored` | Ring → marker | time_in_ring_ms |
| `map.debug_location_updated` | Developer-mode movement button changes simulated location | direction, lat, lng, source, geo_location_enabled |
| `map.debug_location_disabled` | Developer-mode GPS button exits simulated location | source, geo_location_enabled |
| `map.debug_gesture_injected` | Developer-mode gesture button injects a pointer gesture | gesture_type, source, target |
| `map.data_fetch` | Cell data fetched | cell_count, radius, latency_ms |
| `map.render_frame` | Performance sample | cell_count_rendered, frame_time_ms |

---

## 14. AGENTS.md Overrides

This design overrides the following AGENTS.md restrictions:

| Restriction | Override | Reason |
|-------------|---------|--------|
| `maplibre` in forbidden patterns | **Allowed** — GPS-level map rendering | Required for real-world tiles under Voronoi cells |
| `geolocator` in removed packages | **Allowed** — GPS position provider | Required for player location |
| `h3_flutter_plus` in forbidden patterns | **Not overridden** — using server-seeded Voronoi instead of H3 hex grid | Design decision: organic Voronoi shapes preferred |

---

## 15. Cross-References

| Doc | Relationship |
|-----|-------------|
| `docs/design.md` | This doc supersedes MVP's "Map is a stub" — map is now being built |
| `docs/diagrams/problem/a-*.mmd` | JTBD canvases remain the source of truth for player intent |
| `docs/diagrams/solution/a-*.mmd` | Solution diagrams are **superseded** by this doc where they conflict |
| `docs/prd-game-systems.md` | Game systems PRD — encounter/seed mechanics align with this doc |
| `AGENTS.md` | See §14 for specific overrides |
