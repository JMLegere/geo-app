# EarthNova — Map System Design

> Source of truth for the map system. Supersedes any conflicting specs in
> `design.md`, `prd-game-systems.md`, or `docs/diagrams/solution/a-*.mmd`.
>
> All decisions made during the 2026-04-06 design jam session.

---

## 1. Core Principles

The map serves three player questions:

1. **Where am I?** (orientation)
2. **Where have I been?** (progress / footprint)
3. **Where should I go?** (planning / motivation)

The primary emotional register is **cozy accumulation** — "my little world is growing."

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
- When I open the map, I want nearby cells to appear around my real position, so I know the world is divided into explorable places.
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

### Initiative 3 — Fog State Engine

**Strategic intent:** Fog must be computed from visits and current position, not manually stored.

#### Project 3.1 — Current cell detection

**Outcome:** The app knows which cell the marker is currently inside.

**Work:**
- Add/keep a pure `CellDetectionService`.
- Cover point-in-polygon behavior, boundary behavior, and previous/current cell transition detection.

**JTBD user stories:**
- When I cross a cell boundary, I want the app to know I entered a new place, so exploration progresses with movement.
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
- Compute `nearby` for fetched but unvisited cells.
- Do not render unfetched/beyond cells.

**JTBD user stories:**
- When I am standing in a cell, I want that cell to look fully present, so I know where I am.
- When I have already visited a cell, I want it to remain revealed, so I can see my footprint.
- When a cell is near but unvisited, I want it partially obscured, so I feel pulled to explore.
- When a cell is too far away, I want it hidden, so the world still feels mysterious.

### Initiative 4 — Fog Rendering Experience

**Strategic intent:** The computed fog state must become visible and understandable.

#### Project 4.1 — Cell overlay rendering

**Outcome:** The overlay visibly renders present/explored/nearby cells.

**Work:**
- Render Voronoi polygons with `CellOverlayPainter`.
- Fill by fog relationship.
- Border by blended habitat color.
- Render no beyond/unavailable cells.
- Show loading shimmer while cells fetch.

**JTBD user stories:**
- When I open the map, I want nearby fog to be visible immediately, so the game board feels alive.
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
- When I tap a cell, I want to know what kind of place it is, so the map is readable.
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

---

## 3. Cell System

### Generation

- **Server-seeded Voronoi cells** stored in Supabase
- Variable density, **~100m average** cell size everywhere
- Pre-computed during a cell generation pipeline
- **Every point on Earth is a cell**, including oceans — no gaps

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
| **Explored** | Noticeably muted, real map tiles dimmed | Species found, visit count, loot icon if repopulated |
| **Nearby** | Light fog, details hidden | Habitat border visible (dimmed), encounter types, "something's here" tease |
| **Beyond render distance** | Not rendered (black void) | Nothing |

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
colors, producing a single solid blended color.

- Single-habitat cells have pure colors
- Multi-habitat cells produce unique blended hues
- Swamp (grey) acts as a desaturator in blends

### Cell Interior

Neutral fill. Brightness controlled by relationship state. The interior is NOT
habitat-colored — habitat is communicated only through the border.

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

- **Instant on cell boundary crossing** — when the player marker enters a new cell
- The marker must **not be in ring state** (GPS must be confident)
- No dwell time, no speed limit check

### Recording

- **Every visit is recorded** in `v3_cell_visits` (no UNIQUE constraint)
- **First visit is special**: clears fog + triggers species encounter
- Subsequent visits: recorded but encounters only if loot has repopulated

### Offline

- **Optimistic** — cell visits are credited immediately on the client
- Background sync confirms with Supabase
- **Server-side clawback** if validation detects cheating (impossible distances,
  speed, timestamps)
- The honest player never notices a hiccup

---

## 8. Encounters & Loot

### First Visit Encounter

When a player visits a cell for the first time:

1. Seeded species encounter computed from `SHA-256(seed + "_" + cellId)`
2. **Full TCG pack-opening popup** — species reveal animation, stats, dramatic
3. Player **must dismiss** the popup (forced attention — this is the dopamine spike)
4. Species auto-collected to pack after dismissal

### Revisit Loot

When a player revisits a cell that has repopulated loot:

1. **Toast notification** + animated icon showing loot going into pack
2. No popup, no forced interaction — **passive collection**
3. Keep walking momentum

### Repopulation — Multi-Tier Seeds

| Seed | Resets | Controls | Feel |
|------|--------|----------|------|
| **Daily** | Every day | Loot drops (resources, critters) | "I should walk today" |
| **Weekly** | Every week | Different loot pool, rarer items | Weekly variety |
| **Monthly** | Every month | Larger rotation | Monthly freshness |
| **Quarterly** | Every quarter | Animal/species encounters reset | Major rediscovery wave |

### Event Response System

| Event | UI Response | Player Action |
|-------|------------|---------------|
| New species (first visit or quarterly reset) | Full TCG popup — Balatro-level juice (screen punch, haptic burst, dramatic sound) | Must dismiss |
| Critter/loot pickup (daily/weekly/monthly) | Toast + animated loot-to-pack icon | None — passive |
| Cell visit, nothing new | Silent | None |

---

## 9. Sound & Haptics

**Balatro principle** — every interaction has juice. Screen shake, haptic punch,
satisfying sounds, exaggerated animations.

| Interaction | Sound | Haptics |
|-------------|-------|---------|
| Cell entry | Soft sound | Subtle tick |
| Fog clear (first visit) | Satisfying "reveal" sound | Stronger haptic |
| Species encounter (TCG popup) | Dramatic reveal sound | Full haptic burst + screen punch |
| Critter/loot pickup | Cheerful collect sound | Light haptic |
| Zoom level transition | Smooth transition sound | Feedback as levels change |

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

**Shimmer / skeleton cells** while cell data is being fetched. Cell shapes appear
as grey shimmering placeholders, fill in with real data as it arrives.

---

## 13. Observability Events

All map state transitions must log through `ObservabilityService`.

| Event | Trigger | Key Data |
|-------|---------|----------|
| `map.cell_entered` | Marker crosses cell boundary | cell_id, is_first_visit |
| `map.cell_visited` | Visit recorded (marker not ring) | cell_id, user_id, visit_count |
| `map.encounter_triggered` | Species/loot encounter | cell_id, encounter_type, species_id |
| `map.encounter_dismissed` | Player clears popup | cell_id, duration_shown |
| `map.fog_cleared` | First visit reveals cell | cell_id, district_id |
| `map.zoom_changed` | Level transition | from_level, to_level |
| `map.gps_accuracy_degraded` | Marker → ring | accuracy_meters, gap_meters |
| `map.gps_accuracy_restored` | Ring → marker | time_in_ring_ms |
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
