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
