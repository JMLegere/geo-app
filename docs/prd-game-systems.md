# EarthNova — Game Systems PRD

> Product Requirements Document for post-MVP game systems.
> All decisions in this document are settled through first-principles design sessions.
> This is a planning document — it does NOT replace `design.md`. When implementation
> begins, each system should be spec'd into `design.md` at full detail before coding.

---

## 1. Core Feel

Three emotional pillars, in priority order:

| Priority | Feeling | Reference | What it means |
|----------|---------|-----------|---------------|
| **Primary** | "My little world is growing" | Stardew Valley, Animal Crossing, Cozy Grove | The default register. Opening the app feels good. Your pack, your sanctuary, your discoveries — they're yours and they're growing. |
| **Secondary** | "This one could be the one" | Path of Exile, Balatro | The spice, not the meal. Surfaces in specific moments — identification reveals, rare finds, exceptional stat rolls. Punctuation marks in a cozy sentence. |
| **Tertiary** | "We're doing this together" | Helldivers 2, Journey, OSRS | You're not alone. Other players are exploring the same world. Shared milestones, ambient presence, cooperative goals. |

### Design Principles

**Warm/Electric Balance.** 95% of the time, the app is warm — gentle springs, breathing animations, soft shadows. 5% of the time, it's electric — particle bursts, hard springs, haptic pulses, screen glow. The coziness makes the dopamine spikes hit harder BECAUSE the baseline is calm.

**Craggy Depth.** Simple on the surface, surprisingly deep underneath. Players discover complexity over time, never get it dumped on them. Four layers:

| Layer | What's visible | Who notices |
|-------|---------------|-------------|
| 1 | Art, name, rarity badge | Everyone, immediately |
| 2 | Habitat icons, region icons, taxonomic group | Naturalists, after a few sessions |
| 3 | Brawn/wit/speed bars, size, weight | Collectors, after comparing specimens |
| 4 | Affixes, color identity, sanctuary placement strategy, breeding implications | Deep players, after weeks |

**No Onboarding.** Balatro approach. Drop the player in. Let them figure it out. Recap skipped on first-ever login. No tutorials, no tooltip tours, no "tap here to continue."

---

## 2. Game Loop

```
EXPLORE (walk into unexplored cell)
    → encounter ANY species from the full 32,752 catalog (enriched or not)
    → modal announcement: "You found something!"
    → unidentified item lands in pack
    ↓
IDENTIFY (hold card ~1.2s, Balatro dopamine)
    → ONLY works if species is fully enriched
    → if unenriched: card quietly doesn't respond to hold
    → stats rolled client-side from SHA-256(instance UUID) — deterministic
    → full TCG card reveal: art, name, scientific name, stats, affixes
    → IF first eligible for new collection: "New wing unlocked!"
    → fire-and-forget write to Supabase
    ↓
DECIDE
    → keep in pack (for trading, comparing, waiting for better roll)
    → donate to sanctuary (permanent, fills a bundle slot)
    → which collection? (if eligible for multiple)
    ↓
SANCTUARY GROWS ("my little world")
    → bundles fill up over time
    → complete bundle → reward
    → your sanctuary reflects YOUR exploration journey
    ↓
RETURN (6h+ later)
    → recap: personal → city → state → country
    → community stats, pending items, what's new
    → dismiss → back to exploring
```

### Multiple Timescales of Satisfaction

| Timescale | Action | Feeling |
|-----------|--------|---------|
| Minutes | Identify a specimen, see stats roll | Dopamine |
| Hours | Find something in a new area | Curiosity satisfied |
| Days | Complete a tiny collection (2/2) | Achievement |
| Weeks | Make visible progress on a small collection | Growth |
| Months | Approach completion on a medium collection | Pride |
| Forever | Chip away at the massive collections | Purpose |

---

## 3. Item Lifecycle & Identification

### Three Item States

```
UNIDENTIFIED + UNENRICHED  → silhouette, rarity glow visible, can't identify (locked)
UNIDENTIFIED + ENRICHED    → silhouette, rarity glow visible, CAN identify (hold to reveal)
IDENTIFIED                 → full TCG card, stats, art, affixes, everything
```

### Ghosted Enrichment Gate

The distinction between "unenriched" and "enriched" is invisible to the player. No UI communicates this. No "locked" icon, no "pending research" label, no "lab" concept. Items that can't be identified simply don't respond to the hold gesture. The recap says "X unidentified specimens" without distinguishing why some can be identified and others can't.

This means:
- No additional UI to design or explain
- No player frustration about a visible gate ("why can't I open this?")
- When enrichment catches up, items silently become identifiable
- The player just notices that some of their mystery items now respond to hold

### Identification Interaction

- **Hold on the card itself** (~1.2s total)
- "Hold to identify" prompt appears gently if the card is on screen too long without interaction
- Everything is local at identification time — no server call in the critical path
- The species data (art, name, taxonomy, habitats) was fetched when the item entered the pack
- Stats are rolled client-side from the UUID seed
- Server write (mark `identified = true`, persist rolled stats) is fire-and-forget after the animation
- **PoE-snappy** — the data is already on the device, the hold is pure dopamine theater

### Stat Rolling

Deterministic from instance UUID. Reproducible, no server call needed.

| Stat | Source | Mechanic |
|------|--------|----------|
| brawn, wit, speed | `SHA-256(instance UUID)` seed | Sum = 90, distributed around species canonical baseline ± instance variance |
| size | Species size band | Random within band (fine/diminutive/tiny/small/medium/large/huge/gargantuan/colossal) |
| weight | Species size band | Random grams within size category range |
| prefix | Rarity-gated | CR = 2 affixes, EN = 1-2, VU = 0-1, NT/LC = 0 |
| suffix | Rarity-gated | Same depth gating as prefix |

**Stats are personality, not just numbers.** A high-speed fox is "a sprinter." A high-brawn bear is "a bruiser." Flavor text derives from stat distribution. The numbers exist (Layer 3) but the personality is what most players see.

### Affixes

Per-instance prefix/suffix. Depth (how many affixes) gated by rarity.

| Rarity | Max affixes | Example |
|--------|-------------|---------|
| CR | 2 (prefix + suffix) | "Fierce Red Fox of the Deep" |
| EN | 1-2 | "Hardy Bald Eagle" |
| VU | 0-1 | "Red Fox of the Frost" or just "Red Fox" |
| NT | 0 | "Red Fox" |
| LC | 0 | "Red Fox" |

### Color Identity

Derived from stats: R = brawn/90, G = speed/90, B = wit/90. A brawn-heavy animal is red-tinted. A balanced animal is neutral gray. This is Layer 4 depth — discoverable, never explained. Used for card background tint, sanctuary display, trading value assessment.

---

## 4. Enrichment Pipeline

### Role

Background content pipeline. NOT player-facing. Grows the world steadily.

### Current State

- 1 species per 5-min cron tick (~288 attempts/day)
- Actual throughput much lower due to pipeline failures
- 68 species fully enriched out of 32,752
- Pipeline keeps breaking — **fixing reliability is the priority, not speed**

### "Fully Enriched" Definition

A species is identifiable when ALL of these exist:
- LLM classification (animal_class, food_preference, climate, size, brawn/wit/speed)
- Icon prompt + icon image (128×128 sprite)
- Art prompt + art image (512×512 watercolor)

### No Planned Rate Changes

Current rate is acceptable. Full catalog enriches over months. The world grows slowly and that's the design. The trickle of newly-identifiable species creates a natural retention rhythm.

### Interaction with Items

When the pipeline enriches a species:
- All item instances of that species (across ALL players) become identifiable
- No push notification — items silently become "ready"
- Player discovers this organically ("oh, this one responds to hold now")
- Recap captures it indirectly ("X unidentified specimens")

---

## 5. Animation System

### Philosophy

Inspired by Balatro's card feel and the 10 Principles of Fluid UI (Karl Koch). The animation system serves the core feel — warm by default, electric in rare moments.

### Two Registers

| Register | When (%) | Motion language | Examples |
|----------|----------|----------------|----------|
| **Warm** | 95% | Gentle springs, breathing wobble, soft shadows | Browsing pack, donating, exploring, recap |
| **Electric** | 5% | Hard springs, particles, haptic, glow pulse | CR discovery, identification reveal, collection completion |

### Spring Physics

All interactive animation uses spring dynamics — never fixed-duration easing curves for user-triggered motion. A spring with the same configuration produces different motion depending on initial velocity and start position. This is how Balatro cards feel alive.

```
Spring tokens (values TBD during implementation):
  snappy  — quick responsive: chip select, toggle, layout shift
  bouncy  — playful: card flick, reveal pop, collection unlock
  gentle  — calm settling: release snap-back, deselect, dismiss
  heavy   — weighty commitment: drag, hold cancel, placement
```

Non-interactive animation (idle wobble, loading dots, sprite frames) stays time-based.

### Idle Wobble

Every card in the pack grid breathes. Subtle sine oscillation at rest.

| Property | Value |
|----------|-------|
| Position Y | ±0.5px sine |
| Rotation | ±0.2° sine |
| Period | ~2s |
| Phase offset | Per card (`definitionId.hashCode`) — cards never breathe in sync |

One shared AnimationController per grid, not one per card.

### Hold-to-Reveal Choreography

| Time | Event | Visual |
|------|-------|--------|
| 0ms | Press registered | Card lifts (scale 1.05×), shadow deepens, tilts toward finger |
| 300ms | Charge threshold | Particles spawn at card edges, converge inward |
| 300–1200ms | Charging | Particles drift toward center, haptic at 50%/75% |
| 1200ms | Reveal | Particles converge at center → burst → full TCG card appears |
| Release before 1200ms | Cancel | Particles scatter outward, card springs back to rest |

**Everything is interruptible.** Release mid-charge → spring snap-back from current state. No "finish animating then respond."

### Particle System

Widget-based (not custom painter). Lightweight — max 24 particles (CR rarity).

| Rarity | Particle count | Color |
|--------|---------------|-------|
| LC | 6 | Gray `#ADB5BD` |
| NT | 8 | Green `#4CAF50` |
| VU | 12 | Blue `#2196F3` |
| EN | 18 | Gold `#FFD700` |
| CR | 24 | Purple `#9C27B0` |

### Rarity-Scaled Effects

`IucnStatus.glowAlpha` drives visual intensity across the app:

| Status | glowAlpha | Effects |
|--------|-----------|---------|
| LC | 0.0 | Static — no glow, no particles, no shimmer |
| NT | 0.0 | Static |
| VU | 0.15 | Faint glow pulse |
| EN | 0.25 | Steady glow, holographic tint on card |
| CR | 0.35 | Strong glow pulse, full holographic shimmer, dense particles |

### Reduced Motion

Respect `MediaQuery.disableAnimations`. Replace spatial animation (scale, translate, rotate) with opacity. Springs become instant state changes. Particles disabled. Idle wobble disabled. Card reveal becomes a simple fade. Information is never removed — just the movement.

---

## 6. TCG Species Card

### Presentation

Centered modal dialog (NOT bottom sheet). Appears with scale+fade animation (`easeOutBack` — "placed on table" feel). Dismissible by tapping outside, swiping down, or × button.

### Card Layout

```
┌──────────────────────────────────┐
│ [CR] ◆            🦊         ✕  │  ← art overlay: rarity pill, category, close
│                                  │
│         [species art]            │  ← 68% of card height
│                                  │
│         gradient fade ↓          │
├══════════════════════════════════┤  ← 4px rarity color stripe
│ Red Fox                          │
│ Vulpes vulpes                    │  ← info zone
│                                  │
│ [EN · Endangered]  [🦁 Mammals]  │  ← badge pills
│                                  │
│ 🌲 🏔️              🌍 🌎        │  ← habitat + region emoji rows
│                                  │
│ 📅 Jan 3, 2026 · 📍 Cell v_45  │  ← discovery footer
└──────────────────────────────────┘
```

### Rarity Visual Treatment

| Rarity | Card background | Border width | Glow | Art overlay |
|--------|----------------|-------------|------|-------------|
| CR | `#150A24` (deep purple) | 2.5px | Strong purple glow | Diamond ◆ accent in rarity pill |
| EN | `#1A1200` (deep gold) | 2.5px | Gold glow | Diamond ◆ accent |
| VU | `#06142A` (deep blue) | 2.5px | Faint blue glow | — |
| NT | surfaceContainer | 1.5px | — | — |
| LC | surfaceContainer | 1.5px | — | — |

### Unidentified Card (silhouette state)

- Same card shape and rarity border/glow
- Art zone shows a dark silhouette or category emoji
- No name, no stats, no info — just the rarity glow and category icon
- If enriched: responds to hold gesture (identification)
- If unenriched: does not respond to hold

---

## 7. Sanctuary & Collections

### Model: Stardew Valley Community Center Bundles

Each unique permutation of **Region × Habitat × Taxonomic Class** is a collection (bundle). Each collection has one slot per eligible species. Filling a slot requires permanently donating an identified item instance.

### Dimensions

| Dimension | Values | Source |
|-----------|--------|--------|
| Region | Africa, Asia, Europe, N. America, S. America, Oceania | `continents_json` on species |
| Habitat | Forest, Plains, Freshwater, Saltwater, Swamp, Mountain, Desert | `habitats_json` on species |
| Taxonomic Class | 25 IUCN classes → 7 user-facing groups (Mammals, Birds, Reptiles, Amphibians, Fish, Invertebrates, Other) | `taxonomic_class` on species |
| Climate (planned) | Tropic, Temperate, Boreal, Frigid | `climate` on species (651/32,752 have data) |

### Real Data

- **513 real collections** exist in current data (3-dimension permutations with at least 1 species)
- Smallest: 1 species. Largest: 2,615 species (Asia · Saltwater · Fish)
- Median: 20 species per collection
- Adding climate as 4th dimension will expand to ~800-1,000 collections

### Collection Sizes Create Natural Timescales

| Size | Count | Feel |
|------|-------|------|
| Tiny (1-5) | 147 | Trophy cases — achievable, special |
| Small (6-50) | 180 | Projects — weeks of real exploration |
| Medium (51-200) | 107 | Long-term goals — never quite done |
| Large (200+) | 79 | Lifetime pursuits — infinite horizon |

### Rules

- **Collections unlock** on first identification of an eligible species. Before that, the collection is invisible.
- **One instance per slot.** If a species is eligible for multiple collections (e.g., a Red Fox for both "NA · Forest · Mammals" and "Europe · Forest · Mammals"), you need separate specimens for each.
- **Donation is permanent.** The item leaves your pack and lives in the sanctuary forever. Item status changes to `donated`.
- **Can't donate unidentified items.** Must be identified first.
- **Only show non-empty permutations.** No empty placeholder collections.

### Decision Point: Choosing What to Donate

This is where "this one could be the one" connects to the sanctuary:
- You have 5 Red Foxes with different stats
- Which one goes in the sanctuary? The best one? Or save it for trading?
- Once donated, it's permanent — no take-backs
- The decision to donate is the tension point between loot (secondary) and world-building (primary)

---

## 8. Recap System

### Trigger

First app open after 6+ hours since last recap dismissal. Server-side timestamp per account. Skipped on first-ever login.

### Presentation

Swipeable card stack (everything is cards in this game). Dismissable at any point — tap to skip, swipe through at your pace. Never blocks gameplay.

### Pages

| Page | Content | Feel |
|------|---------|------|
| **What's New** | New personal discoveries since last session | Curiosity |
| **Your Progress** | Stats, streaks, collection progress bars | Cozy accumulation |
| **Community** | City → state → country aggregate stats | Together |
| **Pending** | "X unidentified specimens" (no enriched/unenriched distinction) | Loot anticipation |

### Geographic Context

Layered: personal → city → state → country. Player geography derived from cell visit history (reverse geocoded, not GPS at recap time).

### Implementation

Pre-computed async. Cron job builds recap snapshots every hour. Login reads the pre-built snapshot — no expensive queries on the login critical path.

---

## 9. Community (Vision — Built Later)

Core mechanic, deferred implementation. Architecture should have hooks from day 1.

### Four Models

| Model | Feel | Implementation timing |
|-------|------|-----------------------|
| **Cooperative milestone** | "We're all pulling together" | Phase 1 — simple aggregate counters |
| **Ambient presence** | "Others are here, I feel less alone" | Phase 2 — requires location sharing |
| **Trading economy** | "I have something you need" | Phase 3 — requires item transfer system |
| **Friendly competition** | "Best conservationist" — pride, not dominance | Phase 2-3 — leaderboards by collection completion |

### Friendly Competition

Not "who's strongest." Competition is about:
- Most complete sanctuary
- Most species identified
- Most collections unlocked
- Best conservationist score (engagement with IUCN species)
- "Look what I built" — pride in your world, not dominance over others

### Integration with Existing Systems

- **Recap** shows community stats from day 1 (even before social features exist)
- **Enrichment** is a community milestone ("500 new species identifiable this week!")
- **Sanctuary** completion is the friendly competition metric
- **Trading** enables "I have something you need" — donors needed for rare collection slots

---

## 10. Orbs (Design TBD)

PoE2-style crafting currency. Hooks only — no implementation spec yet.

### What We Know

- 46 types planned: 7 habitat + ~35 class + 4 climate
- Crafting currency, not consumables
- Part of the game economy (earned and spent)
- `orb` exists as an `ItemCategory` value already

### What We Don't Know

- What orbs are spent on (crafting what?)
- How orbs are earned (sanctuary production? exploration? identification?)
- Orb rarity/value tiers
- Relationship to other currencies (if any)

### Architecture Hooks

- `ItemCategory.orb` already exists in the enum
- Orb type enum should be added when designed (habitat × class × climate)
- Sanctuary should be designed to produce orbs (but the mechanic is TBD)

---

## 11. Data Model Changes Required

### v3_items — New Columns

| Column | Type | Default | Purpose |
|--------|------|---------|---------|
| `identified` | BOOLEAN | FALSE | Whether the item has been identified |
| `identified_at` | TIMESTAMPTZ | NULL | When identification happened |
| `brawn` | SMALLINT | NULL | Rolled stat (null until identified) |
| `wit` | SMALLINT | NULL | Rolled stat |
| `speed` | SMALLINT | NULL | Rolled stat |
| `size_category` | TEXT | NULL | e.g. "medium" — from species size band |
| `weight_grams` | INT | NULL | Rolled from species size band |
| `prefix` | TEXT | NULL | Rolled affix |
| `suffix` | TEXT | NULL | Rolled affix |

### New Table: v3_sanctuary_donations

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| user_id | UUID FK | → auth.users |
| item_id | UUID FK | → v3_items (the donated item) |
| collection_key | TEXT | e.g. "africa_forest_mammalia" |
| donated_at | TIMESTAMPTZ | |

### New Table: v3_recap_snapshots

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| user_id | UUID FK | → auth.users |
| snapshot_data | JSONB | Pre-computed recap content |
| created_at | TIMESTAMPTZ | |
| dismissed_at | TIMESTAMPTZ | NULL until player dismisses |

### Species Table — Ensure All Required Fields

The enrichment pipeline already populates these, but confirm presence:
- `climate` TEXT (only 651/32,752 populated — enrichment will fill the rest)
- `brawn`, `wit`, `speed` SMALLINT (canonical species baselines)
- `size` TEXT (canonical size category)
- `icon_url`, `icon_url_frame2`, `art_url` TEXT (generated art)

---

## 12. Observability Events (New)

| Event | Category | Data | Trigger |
|-------|----------|------|---------|
| `discovery.encounter` | discovery | `{species_id, cell_id, rarity}` | Cell entry triggers encounter |
| `discovery.item_acquired` | discovery | `{item_id, species_id, is_enriched}` | Unidentified item added to pack |
| `identify.started` | identify | `{item_id}` | Hold gesture begins |
| `identify.completed` | identify | `{item_id, brawn, wit, speed, prefix, suffix}` | Item identified, stats rolled |
| `identify.cancelled` | identify | `{item_id, charge_pct}` | Hold released before completion |
| `sanctuary.donation` | sanctuary | `{item_id, collection_key}` | Item donated to collection |
| `sanctuary.collection_unlocked` | sanctuary | `{collection_key, species_count}` | New collection appeared |
| `recap.shown` | recap | `{hours_away, pending_count}` | Recap triggered |
| `recap.dismissed` | recap | `{pages_viewed}` | Recap swiped away |

---

## 13. Implementation Priority

These systems should be built in this order. Each depends on the one before it.

| Phase | System | Depends on | Effort |
|-------|--------|------------|--------|
| 0 | **Fix enrichment pipeline reliability** | Nothing | Small — debugging existing code |
| 1 | **Item states + identification UI** | Phase 0 (need enriched species) | Medium — 3-state model, hold gesture, stat rolling |
| 2 | **TCG card redesign** | Phase 1 (card shows identified data) | Medium — already partially built |
| 3 | **Animation system** | Phase 1-2 (animations need cards to animate) | Medium — spring tokens, idle wobble, particles |
| 4 | **Discovery + encounters** | Phase 1 (items need states) | Large — cell system, GPS, map |
| 5 | **Sanctuary** | Phase 1 + 4 (need identified items from discovered cells) | Medium — collection queries, donation UI |
| 6 | **Recap** | Phase 4-5 (need activity to recap) | Medium — snapshot cron, swipeable cards |
| 7 | **Community** | Phase 5-6 (need sanctuary + recap as foundation) | Large — multiplayer, aggregation, social |

---

## 14. Design Doc Updates Required

When each phase is implemented, `docs/design.md` needs these updates:

| Section | Update needed |
|---------|--------------|
| §1 Product Vision | Add Core Feel subsection (3 pillars, warm/electric, craggy depth) |
| §3 Architecture | Fix file structure, add identification data flow |
| §5 Data Model | Add new columns, tables, model fields |
| §6 Observability | Add new event catalog entries |
| §8 Performance | Add hold-to-reveal budgets |
| §9 Design System | Fix LC/EX colors, add Spring tokens, add Iconography subsection |
| §10 Screen Designs | Update SpeciesCard (centered modal), add item states to Pack |
| §11 Acceptance Criteria | Add criteria for each new system |

### Known Discrepancies to Fix

| Issue | design.md says | Code says | Fix to |
|-------|---------------|-----------|--------|
| LC color | `#FFFFFF` | `#CDD5DB` | Code value |
| EX color | `#FFC107` | `#757575` | Code value |
| SpeciesCard | "bottom sheet" | centered modal | Settled design |
| `earth_nova_theme.dart` | Listed | Doesn't exist | Remove |
| `iconography.dart` | Not listed | Exists | Add |
| `pack_filter_state.dart` | Not listed | Exists | Add |

---

## 15. Open Questions

| Question | Context | When to decide |
|----------|---------|----------------|
| Climate data enrichment | Only 651/32,752 species have climate. Pipeline needs to fill this. | Before sanctuary implementation |
| Affix vocabulary | What are the actual prefix/suffix words? | Before identification implementation |
| Collection completion rewards | What do you get for completing a bundle? Orbs? Cosmetics? Title? | Before sanctuary implementation |
| Orb economy | What are orbs spent on? How are they earned? | Separate design session |
| Stat baselines per species | Use enrichment pipeline values, or define canonical baselines separately? | Before identification implementation |
| Duplicate species value | Beyond sanctuary donation, what's the value of a 5th Red Fox? | Before trading implementation |
| "Hold to identify" prompt timing | How long before the gentle prompt appears? 3s? 5s? | During animation implementation |
| Encounter rate per cell | How many species per cell visit? 1? 3? Variable? | Before discovery implementation |
