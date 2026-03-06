# Species Community Definition System

> The first 50 players to discover a species collectively define its identity — stats, color, and art. Crowdsourcing is a core game mechanic. Design jam decision (2026-03-06).

---

## Core Concept

Every species starts as a blank slate. No predetermined stats, no art, no color. The community creates the species identity through play:

1. **Stats + Color** — triangle picker (barycentric coordinates → RGB)
2. **Art** — player-submitted illustrations + 1 AI-generated watercolor default
3. **Badges** — instance-level markers for pioneers, founders, artists

After 50 unique players have discovered and defined a species, its stats and color lock forever. Art locks when 51% of all instances select the same piece at a daily reset.

---

## Triangle Stat Picker

### Math

The picker is an equilateral triangle with three corners mapped to stats:

```
        Speed (green)
           /\
          /  \
         /    \
        / tap  \
       /   ·    \
      /          \
     /____________\
Brawn (red)    Wit (blue)
```

Any point inside the triangle decomposes into **barycentric coordinates** `(α, β, γ)` where `α + β + γ = 1.0`:

| Coordinate | Stat | Color channel |
|-----------|------|--------------|
| α | Brawn | Red (R = α × 255) |
| β | Wit | Blue (B = β × 255) |
| γ | Speed | Green (G = γ × 255) |

**Stats**: `brawn = round(α × 90)`, `wit = round(β × 90)`, `speed = round(γ × 90)`. Always sum to 90.

**Color**: `RGB(α × 255, γ × 255, β × 255)` — the species' canonical color identity.

### UX Flow

1. Player discovers a species (creates an instance)
2. Instance created with `stats: null`, `needsStatPick: true`
3. Prompt: *"You've discovered a brand new species! Coordinate with others to determine its nature."*
4. Triangle picker appears — player taps a point
5. Pick recorded as:
   - **Instance stats** — this instance's brawn/wit/speed (no variance)
   - **Canonical vote** — feeds the running median
6. Flag cleared: `needsStatPick: false`

### Running Median

The species' current base stats = **component-wise median** of all triangle picks so far.

```
votes so far:  [(30, 20, 40), (25, 25, 40), (35, 15, 40)]
running median: (30, 20, 40)  ← median of each component independently
running color:  RGB(85, 113, 57)
```

The running median is visible to all players as the species' "current" stats and color. It updates with each new vote and converges as more players contribute.

At the **50th unique player's vote**, the median locks permanently as the canonical base.

---

## Instance Stats Model

| Instance # | Base stats source | Variance | Triangle picker? |
|-----------|------------------|----------|-----------------|
| 1–50 | Player's own triangle pick | None — pick IS the stats | Yes (mandatory) |
| 51+ | Canonical median (locked) | ±30% per-instance (SHA-256 deterministic) | No |

**First 50 instances are hand-crafted.** Each reflects the discoverer's personal intuition about the species. These are collectors' items — never reproducible after canonicalization.

**Post-canonical instances** use the locked median as base, with ±30% per-instance variance applied via SHA-256 of `"$scientificName:$instanceId"` (same portable determinism as current system, but applied to crowdsourced base instead of hash-derived base).

---

## Art Crowdsourcing

### Submission

- First 50 discoverers can upload art (camera roll, gallery, or in-app creation)
- **AI watercolor** auto-generated via Gemini API as the default option for every species
  - Prompt: watercolor illustration in the style of full-art Pokémon cards
  - Generated once per species via background job queue (Supabase Edge Function)
  - Stored in Supabase Storage
- **Moderation**: AI pre-filter (Gemini content safety) + community flagging post-upload

### Art Selection

Every instance owner chooses which art their instance displays. This is a personal choice — your Red Fox can show a different illustration than someone else's Red Fox.

Before 50 owners: all submitted art + AI default are available. No canonical vote counting yet.

### Art Voting

After 50 unique players own the species:

- **Selecting art for your instance = casting a vote**
- **Vote weight = instance count.** If you own 3 Red Foxes all showing Art B, that's 3 votes for Art B.
- **You can change your vote anytime** (swap art on your instance)
- **Threshold**: one image reaches **51% of all instances** of that species
- **Lock**: at the next **daily reset** (midnight GMT) after threshold is met, art locks permanently
- **Winning artist** credited on the species card forever

The daily reset prevents coordinated spikes — the 51% must hold through the reset window.

### Art for Common vs Rare Species

- **Common species** (LC, thousands of instances) → harder to reach 51% → more democratic, takes longer
- **Rare species** (CR/EX, handful of instances) → faster consensus → smaller circle decides
- A player with 3 of 5 total EX instances can unilaterally pick the art — they earned it

---

## Species Card UI System

Every species instance renders as a card. The card is a composable layer stack:

```
┌─────────────────────────────────┐
│          [FRAME]                │ ← rarity + badge-driven border
│  ┌───────────────────────────┐  │
│  │                           │  │
│  │         [ART]             │  │ ← community/AI illustration
│  │                           │  │
│  │                    [BADGES]│  │ ← icon overlays (top-right cluster)
│  └───────────────────────────┘  │
│  [NAME]          [COLOR DOT]    │ ← species name + RGB identity
│  [STAT BARS]                    │ ← brawn(R) / wit(B) / speed(G)
│  [RARITY BADGE]                 │ ← IUCN status pill
└─────────────────────────────────┘
```

### Layer 1: Frame

The outermost border/treatment. Driven by **rarity** as the base, upgraded by **badges**.

| Rarity | Frame style |
|--------|------------|
| LC | Simple thin border |
| NT | Subtle inner glow |
| VU | Double border |
| EN | Metallic edge |
| CR | Holographic / foil edge |
| EX | Animated / prismatic edge |

Badge upgrades overlay the rarity frame:

| Badge | Frame modification |
|-------|-------------------|
| First Discovery | Gold trim added to rarity frame |
| Pioneer | Silver accent on rarity frame |
| Artist | Art palette watermark in corner of frame |
| Beta | Retro/distressed texture overlay on frame |

Badges **stack** — a First Discovery + Beta instance gets both the gold trim and the retro texture on top of its rarity frame.

### Layer 2: Art

The species illustration fills the card interior.

| State | What shows |
|-------|-----------|
| No art submitted yet | AI watercolor (or placeholder if AI hasn't generated yet) |
| Art available, pre-canonical | Player's selected art from available gallery |
| Art canonical (51% locked) | Canonical art for all instances |

Pre-canonical: player picks art per instance. Post-canonical: all instances show locked art (frame and badges still vary per instance).

### Layer 3: Badges

Small icons overlaid on the card (top-right corner cluster). Each badge is an icon, not a frame change — multiple can display simultaneously.

| Badge | Icon | Condition | Scope |
|-------|------|-----------|-------|
| **First Discovery** | ★ (gold star) | Instance #1 of this species globally | Instance |
| **Pioneer** | 🏔 (mountain/flag) | Instance #2–50 of this species | Instance |
| **Founder** | △ (triangle) | Player used the triangle picker (first 50) | Instance |
| **Artist** | 🎨 (palette) | Player's art won the canonical vote | Instance |
| **Beta** | β (beta symbol) | Instance acquired during beta period | Instance |

All badges are **instance-level** — attached to the specific ItemInstance, not the player. Your Pioneer Red Fox #7 has the badge forever. A Red Fox you find later as #340 does not.

### Layer 4: Stats Display

Three horizontal bars or a compact stat row, color-coded:

| Stat | Color | Bar |
|------|-------|-----|
| Brawn | Red (#FF0000 → species R value) | `████████░░` (73/100) |
| Wit | Blue (#0000FF → species B value) | `███░░░░░░░` (28/100) |
| Speed | Green (#00FF00 → species G value) | `██████░░░░` (59/100) |

For first-50 instances: bars show the player's triangle pick (exact values).
For post-canonical instances: bars show rolled values (canonical base ± variance).

### Layer 5: Color Identity

The species' RGB color (derived from canonical stats) appears as:
- A subtle background tint on the card
- A color dot next to the species name
- Border accent color on the frame

Pre-canonical: running median color (updates as votes come in).
Post-canonical: locked color forever.

### Layer 6: Name Plate

- **Common name** (large): "Red Fox"
- **Scientific name** (small, italic): *Vulpes vulpes*
- **Rarity badge**: existing `RarityBadge` pill (LC/NT/VU/EN/CR/EX)

---

## Badge & Frame Catalog

### Instance Badges (Full List)

| Badge | ID | Condition | Visual | Rarity of badge |
|-------|----|-----------|--------|----------------|
| First Discovery | `first_discovery` | Global instance #1 of species | Gold star icon, gold frame trim | 1 per species ever |
| Pioneer | `pioneer` | Global instance #2–50 of species | Flag icon, silver frame accent | 49 per species ever |
| Founder | `founder` | Player submitted triangle pick (first 50) | Triangle icon | Same 50 as Pioneer + First Discovery |
| Artist | `artist` | Player's submitted art won canonical vote | Palette icon | 1 per species ever |
| Beta | `beta` | Instance acquired during beta period | β symbol, retro frame texture | Time-limited |

**Note:** First Discovery always has both `first_discovery` AND `founder` (they used the triangle). Pioneer always has `founder` too. These stack.

### Frame Priority

When multiple badge frame modifications apply, they layer bottom-to-top:

1. **Base**: Rarity frame (always present)
2. **Beta**: Retro texture overlay (if applicable)
3. **Pioneer**: Silver accent (if applicable)
4. **Artist**: Palette watermark (if applicable)
5. **First Discovery**: Gold trim (if applicable, always on top)

---

## Reward System

### Proximity Reward (Stats)

After the 50th triangle vote locks the canonical stats, every voter in the first 50 receives a reward scaled by how close their pick was to the final median.

```
canonical = median of 50 barycentric coordinates → (α_c, β_c, γ_c)
yourPick  = (α, β, γ)

distance  = |α - α_c| + |β - β_c| + |γ - γ_c|
            // Manhattan distance in barycentric space
            // Max possible = 2.0 (opposite corner)

accuracy  = 1.0 - (distance / 2.0)   // 1.0 = perfect match, 0.0 = worst

reward    = baseReward × accuracy
```

**Reward type**: TBD (XP, cosmetic, currency, special item). The formula is fixed; the reward content is a game-balance decision.

**Incentive design**: This creates a **Schelling focal point** game. Players are rewarded for guessing what the consensus will be, not for personal preference. Trolling (picking extreme corners) is self-punishing — your reward is near zero.

### Artist Reward

The player whose art wins the canonical vote receives:
- **Artist badge** on all their instances of that species
- **Credit** on the species card (artist name displayed)
- Additional reward TBD (XP, cosmetic, title)

---

## Species Lifecycle (Complete)

```
UNDISCOVERED
  Species exists in IUCN dataset but no player has found it yet.
  No stats, no color, no art.
     │
     ▼
INSTANCE #1 — FIRST DISCOVERY
  Player finds species → instance created (stats: null, needsStatPick: true)
  Prompt: "You've discovered a brand new species!"
  Triangle picker → stats set, vote recorded
  AI watercolor generation job queued (background)
  Badges: first_discovery + founder
  Species stats = this player's pick (running median of 1)
     │
     ▼
INSTANCES #2–50 — CONTRIBUTION PHASE
  Each new unique player gets triangle picker + can upload art
  Instance stats = their triangle pick (no variance)
  Running median updates with each vote
  All submitted art available for per-instance selection
  Badges: pioneer + founder
     │
     ▼
INSTANCE #50 — CANONICALIZATION
  Stats lock: component-wise median of 50 picks
  Color locks: RGB derived from canonical stats
  Proximity rewards calculated and distributed to all 50 voters
  Art voting begins counting (instance selection = vote)
     │
     ▼
INSTANCES #51+ — POST-CANONICAL
  Base stats = canonical median (locked)
  Per-instance variance: ±30% via SHA-256
  No triangle picker — stats are automatic
  Player still selects art per instance (= vote)
  No special badges (standard instance)
     │
     ▼
ART CANONICAL — 51% THRESHOLD
  One art piece selected by ≥51% of all instances
  Locks at next daily reset (midnight GMT)
  Winning artist gets artist badge + credit
  All instances display canonical art
  Species is fully defined: stats + color + art
```

---

## Data Model (New Tables)

### Supabase Tables

```sql
-- Species canonical data (populated after 50 votes or art lock)
species_canonical (
  species_id TEXT PRIMARY KEY,          -- e.g. "fauna_vulpes_vulpes"
  base_brawn INT,                       -- canonical stat (0-90)
  base_wit INT,                         -- canonical stat (0-90)
  base_speed INT,                       -- canonical stat (0-90)
  color_r INT,                          -- 0-255
  color_g INT,                          -- 0-255
  color_b INT,                          -- 0-255
  stats_locked_at TIMESTAMPTZ,          -- when 50th vote landed
  canonical_art_id UUID,                -- FK → species_art.id (null until art locks)
  art_locked_at TIMESTAMPTZ,            -- when 51% threshold met at daily reset
  total_instances INT DEFAULT 0,        -- running count of all instances
  total_voters INT DEFAULT 0,           -- unique players who used triangle (max meaningful = 50)
  created_at TIMESTAMPTZ DEFAULT now()
)

-- Individual triangle votes (first 50 per species)
species_stat_votes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  species_id TEXT NOT NULL,             -- FK → species_canonical
  user_id UUID NOT NULL,                -- FK → auth.users
  instance_id UUID NOT NULL,            -- FK → item_instances
  alpha REAL NOT NULL,                  -- barycentric α (brawn)
  beta REAL NOT NULL,                   -- barycentric β (wit)
  gamma REAL NOT NULL,                  -- barycentric γ (speed)
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(species_id, user_id)           -- one vote per player per species
)

-- Submitted art for species
species_art (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  species_id TEXT NOT NULL,             -- FK → species_canonical
  submitted_by UUID,                    -- FK → auth.users (null for AI-generated)
  storage_path TEXT NOT NULL,           -- Supabase Storage path
  is_ai_generated BOOLEAN DEFAULT false,
  moderation_status TEXT DEFAULT 'pending',  -- pending, approved, rejected, flagged
  flag_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
)

-- Art selection per instance (= vote)
instance_art_selection (
  instance_id UUID PRIMARY KEY,         -- FK → item_instances
  art_id UUID NOT NULL,                 -- FK → species_art
  selected_at TIMESTAMPTZ DEFAULT now()
)

-- Instance badges
instance_badges (
  instance_id UUID NOT NULL,            -- FK → item_instances
  badge_id TEXT NOT NULL,               -- 'first_discovery', 'pioneer', 'founder', 'artist', 'beta'
  awarded_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (instance_id, badge_id)
)
```

### Local Cache (Drift/SQLite additions)

```
-- Cache of species canonical data (synced from server)
LocalSpeciesCanonicalTable
  speciesId TEXT PK
  baseBrawn INT
  baseWit INT
  baseSpeed INT
  colorR INT
  colorG INT
  colorB INT
  statsLocked BOOLEAN
  canonicalArtPath TEXT (local file path, nullable)
  artLocked BOOLEAN

-- Cache of available art for species in contribution phase
LocalSpeciesArtTable
  id TEXT PK
  speciesId TEXT
  localPath TEXT
  isAiGenerated BOOLEAN
  moderationStatus TEXT
```

### ItemInstance Changes

Add to existing `ItemInstance` model:

```dart
class ItemInstance {
  // ... existing fields ...
  final bool needsStatPick;          // true until player uses triangle
  final int? globalInstanceNumber;   // which # instance this is (for badge logic)
}
```

Add to existing `LocalItemInstanceTable`:

```sql
needs_stat_pick BOOLEAN DEFAULT true
global_instance_number INT
selected_art_id TEXT              -- FK → species_art.id
```

---

## Server Architecture

### Background Job Queue

AI watercolor generation and moderation run as background jobs via a **generalized external service queue**:

```
Discovery of new species
    → INSERT into job_queue (type: 'ai_watercolor', species_id: X)
    → Supabase Database Webhook fires
    → Edge Function processes job:
        1. Call Gemini API (image generation)
        2. Store result in Supabase Storage
        3. INSERT into species_art (is_ai_generated: true)
        4. UPDATE job status → completed
    → On failure: exponential backoff, max 3 retries
```

**Rate limiting**: Gemini free tier = 500 images/day. Job queue respects this via token bucket in Edge Function. At 500/day, all 33k species get AI art in ~66 days.

**Art moderation** runs as a separate job type in the same queue:
```
Art uploaded → INSERT into job_queue (type: 'moderate_art', art_id: X)
    → Edge Function calls Gemini content safety API
    → UPDATE species_art.moderation_status
```

### Daily Reset Job

A `pg_cron` job runs at midnight GMT:

```sql
-- Check for art that hit 51% threshold, lock it
SELECT species_id, art_id, vote_percentage
FROM art_vote_tallies  -- (view that computes instance-weighted percentages)
WHERE vote_percentage >= 0.51
  AND species_id NOT IN (SELECT species_id FROM species_canonical WHERE art_locked_at IS NOT NULL);

-- For each qualifying species: lock the art
UPDATE species_canonical
SET canonical_art_id = :winning_art_id,
    art_locked_at = now()
WHERE species_id = :species_id;
```

### Realtime Subscriptions

Flutter client subscribes to:
- `species_canonical` changes (stats lock, art lock)
- `species_art` inserts (new art available for selection)
- Running median updates (computed server-side, pushed via Realtime)

---

## Migration from Current System

| Current | Change | New |
|---------|--------|-----|
| `StatsService.deriveBaseStats()` (SHA-256) | Remove for base stats | Triangle picker → running median → canonical |
| `StatsService.rollIntrinsicAffix()` | Keep variance mechanism only | Apply ±30% SHA-256 variance to canonical base (instances 51+) |
| `kStatMin/Max/Range` constants | Keep | Still used for variance clamping |
| `kStatVariance` constant | Keep | Still ±30% |
| `kIntrinsicAffixId` constant | Keep | Affix still stored as intrinsic, just base source changes |
| No species color | Add | RGB from canonical stats |
| No species art | Add | Community + AI art pipeline |
| No badges | Add | Instance-level badge system |
| No `needsStatPick` flag | Add | New field on ItemInstance |

**PR #28 (`StatsService`) is partially superseded.** The SHA-256 base stat derivation is removed. The per-instance variance mechanism (`_rollStat`) survives but applies to crowdsourced base instead of hash-derived base.

---

## Open Questions

| Question | Impact | Notes |
|----------|--------|-------|
| Proximity reward type | Game economy | XP? Currency? Cosmetic? Special item? |
| Artist reward type | Incentive balance | Same question |
| In-app art creation tools? | Scope | Camera roll only? Drawing tools? Filters? |
| Art resolution/format requirements | Storage, display | Max dimensions, file types, size limits |
| Can new art be submitted after canonical lock? | Community engagement | Allow "challenger" art seasons? Or locked forever? |
| Moderation appeal process | Trust & safety | Rejected art → appeal? Or final? |
| Species with <50 discoverers long-term | Edge case | Running median is fine, but stats never formally "lock" |
| How to display "needs stat pick" in inventory | UX | Badge? Glow? Notification dot? |
