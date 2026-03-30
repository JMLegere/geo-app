# District Hierarchy Design

> Replaces the ad-hoc `LocationNode` system with a first-class geographic hierarchy. Districts are the core game concept — exploration progress, detection zones, and the hierarchy view system all build on this.

## Status: Design Document (not yet implemented)

---

## 1. Core Concept

The game world is organized into a 5-level geographic hierarchy:

| Level | Source | Approx rows | Example |
|-------|--------|-------------|---------|
| **District** | GeoNames / Who's On First | ~500K | Downtown Victoria |
| **City** | GeoNames / Who's On First | ~50K | Victoria |
| **State** | GeoNames / Who's On First | ~5K | British Columbia |
| **Country** | Natural Earth (bundled) | ~200 | Canada |
| **World** | Static | 1 | Earth |

Districts are the fundamental unit of exploration. The detection zone, cell assignment, and exploration progress are all district-scoped.

---

## 2. Data Sources

### Initial Import (one-time global)

| Level | Primary Source | Fallback | Data needed |
|-------|---------------|----------|-------------|
| Districts | Who's On First (neighbourhood level) | GeoNames populated places | name, centroid lat/lon, city assignment |
| Cities | Who's On First (locality level) | GeoNames cities | name, centroid, state assignment |
| States | Who's On First (region level) | GeoNames admin1 | name, centroid, country assignment |
| Countries | Natural Earth 1:110m (bundled) | — | name, centroid, continent, boundary polygon |

### District Boundaries

Districts DO NOT use OSM admin boundary polygons. District shapes are derived from a **two-level Voronoi tessellation**:

1. **Macro Voronoi:** All district centroids within a city are Voronoi seeds. The Voronoi partition of these centroids defines district boundaries. Clean shapes, no gaps, no overlaps.
2. **Micro Voronoi:** The existing ~180m cell tessellation. Each cell belongs to the district whose centroid is nearest.

District `boundary_json` = the Voronoi polygon of that district's centroid among its city's districts. Computed once during global import. Stored as simplified GeoJSON.

City `boundary_json` = union of its district Voronoi polygons.
State `boundary_json` = union of its city boundaries (or simplified).
Country `boundary_json` = Natural Earth polygons (pre-existing).

---

## 3. Data Model

### Supabase Tables (4 new tables, replacing `location_nodes`)

```sql
-- Countries (pre-populated from Natural Earth)
CREATE TABLE countries (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  centroid_lat DOUBLE PRECISION NOT NULL,
  centroid_lon DOUBLE PRECISION NOT NULL,
  continent TEXT NOT NULL,
  boundary_json TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- States / Provinces / Regions
CREATE TABLE states (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  centroid_lat DOUBLE PRECISION NOT NULL,
  centroid_lon DOUBLE PRECISION NOT NULL,
  country_id TEXT NOT NULL REFERENCES countries(id),
  boundary_json TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Cities / Localities
CREATE TABLE cities (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  centroid_lat DOUBLE PRECISION NOT NULL,
  centroid_lon DOUBLE PRECISION NOT NULL,
  state_id TEXT NOT NULL REFERENCES states(id),
  boundary_json TEXT,
  cells_total INT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Districts / Neighbourhoods
CREATE TABLE districts (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  centroid_lat DOUBLE PRECISION NOT NULL,
  centroid_lon DOUBLE PRECISION NOT NULL,
  city_id TEXT NOT NULL REFERENCES cities(id),
  boundary_json TEXT,
  cells_total INT,
  source TEXT NOT NULL DEFAULT 'whosonfirst',
  source_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_districts_city ON districts(city_id);
CREATE INDEX idx_districts_centroid ON districts(centroid_lat, centroid_lon);
CREATE INDEX idx_cities_state ON cities(state_id);
CREATE INDEX idx_states_country ON states(country_id);
```

### Cell Linkage

```sql
-- cell_properties.district_id replaces cell_properties.location_id
ALTER TABLE cell_properties ADD COLUMN district_id TEXT REFERENCES districts(id);
```

FK chain: `cell_properties.district_id → districts → cities → states → countries`

### Client-Side (Drift)

Corresponding Drift tables mirror the Supabase schema. Hydrated on Supabase sync.

### Exploration Stats

- `districts.cells_total` — global, stored on district row. Same for all players.
- Per-user progress — cached client-side:
  - `Map<String, ({int cellsExplored, int speciesCount})>` keyed by district_id
  - Cache busts when user visits a new cell (recompute only that cell's district)
  - Higher levels aggregate from district cache (city = sum of its districts)

---

## 4. Camera Integration

The camera system drives transitions between the player map and the hierarchy views:

```
z16 (close) ←→ z15 (widest) ──pinch out──→ District Screen ──pinch/tap──→ City ──→ State ──→ Country ──→ World
                                ←──pinch in──                 ←──────────────────────────────────────────────
```

### Player Mode (z15–z16)
- Camera always locked to player. No panning.
- `moveCamera(playerPos, currentZoom)` on rubber-band tick
- Pan gestures disabled via `MapGestures(pan: false)`
- Pinch out past z15 → smooth fade transition to District Screen

### Zoom Transition
- Map stays at z15, fades as visual effect (no actual camera zoom to z14)
- Full-screen replacement when fade completes
- Pinch back in → parallax fade (map appearing behind) + "Back to map" button (C+D pattern)
- Gameplay not paused during hierarchy views — toast notifications still fire

---

## 5. Hierarchy Screens

Each level is a full-screen infographic — NOT a MapLibre view.

### District Screen (built first)

- Dark background (district Voronoi boundary filled dark)
- Explored cells rendered as light polygons (same color as live map "present" state)
- Binary: explored (light) or unexplored (dark). No intermediate states.
- Only render explored cell polygons (~300 out of ~6000) — Option F
- "You are here" marker showing player position within district
- Stats: X% explored, Y species found
- Navigation: pinch in → Player map, pinch out → City view, tap → cell detail?

### City / State / Country / World (stubs)

- Full-screen infographic layout
- Shows sub-regions colored by exploration percentage
- Tap sub-region to drill in
- Pinch to navigate up/down hierarchy
- Built as stubs initially — "Coming soon" with basic stats

### Rendering

All hierarchy screens use Flutter `CustomPainter`, not MapLibre:
- District boundary from `boundary_json` (Voronoi polygon)
- Cell polygons from `getCellBoundary()` (existing Voronoi cell service)
- Simple Mercator projection scaled to fit screen (no tile loading)
- Same fog color scheme as live map (design consistency)

---

## 6. Migration

### From LocationNode to new tables

The existing `location_nodes` table (107 rows) and `LocationNode` Drift table need to be migrated to the new 4-table structure. This includes:

- Mapping existing location_nodes to the appropriate level-specific table
- Updating `cell_properties.location_id` → `cell_properties.district_id`
- Updating all code references (game_coordinator_provider, enrichment pipeline, fog overlay controller, territory border builder)
- Dropping `location_nodes` table after migration

### Global Data Import

One-time batch import pipeline:
1. Download Who's On First / GeoNames datasets
2. Parse and normalize into countries / states / cities / districts
3. Compute Voronoi partition of district centroids per city → `boundary_json`
4. Import into Supabase (~500K districts, ~50K cities, ~5K states, ~200 countries)
5. Compute `cells_total` per district (count of Voronoi cells whose center falls within district boundary)

---

## 7. What Gets Deleted

| Component | Reason |
|-----------|--------|
| `LocationNode` model | Replaced by Country/State/City/District models |
| `LocalLocationNodeTable` (Drift) | Replaced by 4 level-specific Drift tables |
| `location_nodes` (Supabase) | Replaced by 4 Supabase tables |
| `LocationNodeRepository` | Replaced by level-specific repositories |
| `locationNodeRepositoryProvider` | Replaced |
| `AdminLevel` enum | Implicit in table structure |
| `CameraMode` enum | Only following mode — no enum needed |
| `RecenterFab` | No free mode to recenter from |
| `CameraBoundsController` + provider | No bounds — camera locked to player |
| `resolve-admin-boundaries` Edge Function | Replaced by pre-populated district data |
| Territory border builder (Nominatim-dependent parts) | Rebuilt using district `boundary_json` |

---

## 8. Implementation Phases

| Phase | What | Depends on |
|-------|------|-----------|
| **Phase 1** | Camera simplification (locked follow, z15-z16, no pan, delete free/overview/recenter) | Nothing |
| **Phase 2** | Global data import pipeline (Who's On First → Supabase tables) | Nothing |
| **Phase 3** | New data model (4 tables, Drift schemas, migration from LocationNode) | Phase 2 |
| **Phase 4** | Cell assignment migration (location_id → district_id) | Phase 3 |
| **Phase 5** | Exploration stats cache (client-side, cell-visit bust) | Phase 3 |
| **Phase 6** | District infographic screen (CustomPainter, cell polygons, pinch transition) | Phase 3, 5 |
| **Phase 7** | Hierarchy navigation (pinch/tap between levels, stub screens) | Phase 6 |
| **Phase 8** | City/State/Country/World screens (un-stub) | Phase 7 |

Phase 1 ships independently. Phases 2-3 can run in parallel with Phase 1.
