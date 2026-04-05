# EarthNova — Diagram Catalog

> Complete system specification through diagrams. Detailed enough that a contractor
> making zero decisions could build the entire app.
>
> All diagrams are `.mmd` (Mermaid) — renderable, diffable, version-controlled.

---

## Game Model

### 5 Skills (1 per item type)

| Skill | Item Type | Post-ID Activity | Level Unlocks (examples) |
|-------|-----------|------------------|--------------------------|
| **Zoology** | Fauna | Care, breed, feed → orbs | L3: Breed. L5: Rare breed. L8: CR breed. |
| **Botany** | Flora | Cultivate, harvest → food | L3: Cultivate. L5: Rare plants. |
| **Geology** | Minerals | Cut, craft → materials | L3: Gem cutting. L5: Advanced craft. |
| **Paleontology** | Fossils | Reconstruct → displays | L3: Reconstruct. L5: Complex assemblies. |
| **Archaeology** | Artifacts | Restore → history | L3: Restore. L5: Rare artifacts. |

### 13 Activities

**Fully designed (Phase 1-6):**

| # | Activity | Skills Fed | Inputs | Outputs |
|---|----------|-----------|--------|---------|
| 1 | Explore a cell | All (by type found) | GPS, daily seed | Unidentified specimens, cell visit |
| 2 | Discover a specimen | Matching item type | Cell encounter | Unidentified item in pack |
| 3 | Identify a specimen | Matching item type | Enriched item, UUID seed | Identified item (stats, art, affixes) |
| 4 | Donate to collection | Matching item type | Identified item | Collection slot filled |
| 5 | Feed sanctuary animal | Zoology | Food item, placed animal | Orbs (habitat + class + climate) |
| 6 | Review recap | None | 6h+ absence | Summary cards |

**Stubbed (framework only, mechanics TBD):**

| # | Activity | Skill | Gating | Inputs | Outputs |
|---|----------|-------|--------|--------|---------|
| 7 | Breed specimens | Zoology | L3 | 2 identified fauna | Offspring with combined traits |
| 8 | Cultivate flora | Botany | L3 | Identified flora + plot | Growing flora instance |
| 9 | Harvest from flora | Botany | L3 | Mature cultivated flora | Food items |
| 10 | Craft with minerals | Geology | L3 | Minerals + orbs | Lures, cosmetics, materials |
| 11 | Reconstruct fossil | Paleontology | L3 | Fossil fragments | Assembled display |
| 12 | Restore artifact | Archaeology | L3 | Damaged artifact | Restored artifact |
| 13 | Trade with player | Any | Deferred | Item + recipient | Transferred item |

### Resource Flow

```
EXPLORATION → unidentified specimens (all types) + food
IDENTIFICATION → identified specimens (stats, art, affixes)
SANCTUARY → collection slots filled + orbs (from fed animals)
CRAFTING → lures, cosmetics, breeding materials (from orbs + minerals)
```

---

## Diagram Catalog

### Problem Space — JTBD Canvases (29)

4-level hierarchy: L0 (aspirational) → L1 (core) → L2 (job areas) → L3 (specific tasks).
Each canvas contains both the JTBD problem map AND the system spec.
See [`problem/AGENTS.md`](problem/AGENTS.md) for full guidance.

#### L0–L1: Aspirational & Core (2)

| # | File | Focus Job |
|---|------|-----------|
| L0 | [`problem/l0-become-explorer.mmd`](problem/l0-become-explorer.mmd) | Become an explorer who discovers and cares about the natural world |
| L1 | [`problem/l1-build-wildlife-world.mmd`](problem/l1-build-wildlife-world.mmd) | Build and grow my personal wildlife world |

#### L2: Major Job Areas (7)

| # | File | Focus Job | Resolves |
|---|------|-----------|----------|
| A | [`problem/a-discover-wildlife.mmd`](problem/a-discover-wildlife.mmd) | Discover wildlife while exploring the real world | 4.1 |
| B | [`problem/b-identify-specimens.mmd`](problem/b-identify-specimens.mmd) | Identify specimens in my collection | 2.1, 2.3, 2.4 |
| C | [`problem/c-curate-sanctuary.mmd`](problem/c-curate-sanctuary.mmd) | Curate a sanctuary through donations | 3.3, 3.4 |
| D | [`problem/d-reconnect-return.mmd`](problem/d-reconnect-return.mmd) | Reconnect with progress on return | 3.1, 3.2 |
| E | [`problem/e-share-world.mmd`](problem/e-share-world.mmd) | Share my world with other explorers (DEFERRED) | — |
| F | [`problem/f-manage-identity.mmd`](problem/f-manage-identity.mmd) | Manage my explorer identity | — |
| S | [`problem/s-system-growing.mmd`](problem/s-system-growing.mmd) | [System] Keep the world growing | 2.2, 2.3, 2.4 |

#### L3: Specific Tasks (20)

| # | File | Focus Job | Parent |
|---|------|-----------|--------|
| A.1 | [`problem/a1-navigate-map.mmd`](problem/a1-navigate-map.mmd) | Navigate the real-world map | A |
| A.2 | [`problem/a2-reveal-fog.mmd`](problem/a2-reveal-fog.mmd) | Reveal fog-of-war by visiting cells | A |
| A.3 | [`problem/a3-encounter-collect.mmd`](problem/a3-encounter-collect.mmd) | Encounter and collect species | A |
| B.1 | [`problem/b1-browse-pack.mmd`](problem/b1-browse-pack.mmd) | Browse and organize my pack | B |
| B.2 | [`problem/b2-hold-to-identify.mmd`](problem/b2-hold-to-identify.mmd) | Reveal specimen identity (hold-to-identify) | B |
| B.3 | [`problem/b3-understand-stats.mmd`](problem/b3-understand-stats.mmd) | Understand specimen stats and traits | B |
| C.1 | [`problem/c1-browse-collections.mmd`](problem/c1-browse-collections.mmd) | Discover and browse collections | C |
| C.2 | [`problem/c2-donate-specimens.mmd`](problem/c2-donate-specimens.mmd) | Donate specimens to fill collection slots | C |
| C.3 | [`problem/c3-complete-bundles.mmd`](problem/c3-complete-bundles.mmd) | Complete collection bundles | C |
| D.1 | [`problem/d1-review-recap.mmd`](problem/d1-review-recap.mmd) | Review personal progress (recap) | D |
| D.2 | [`problem/d2-community-milestones.mmd`](problem/d2-community-milestones.mmd) | See community milestones | D |
| E.1 | [`problem/e1-trade-specimens.mmd`](problem/e1-trade-specimens.mmd) | Trade specimens (DEFERRED) | E |
| E.2 | [`problem/e2-compare-sanctuaries.mmd`](problem/e2-compare-sanctuaries.mmd) | Compare sanctuaries (DEFERRED) | E |
| E.3 | [`problem/e3-community-goals.mmd`](problem/e3-community-goals.mmd) | Participate in community goals (DEFERRED) | E |
| F.1 | [`problem/f1-create-sign-in.mmd`](problem/f1-create-sign-in.mmd) | Create account and sign in | F |
| F.2 | [`problem/f2-customize-profile.mmd`](problem/f2-customize-profile.mmd) | Customize profile (DEFERRED) | F |
| F.3 | [`problem/f3-manage-settings.mmd`](problem/f3-manage-settings.mmd) | Manage account settings | F |
| S.1 | [`problem/s1-enrich-species.mmd`](problem/s1-enrich-species.mmd) | Enrich species for identification | S |
| S.2 | [`problem/s2-sync-data.mmd`](problem/s2-sync-data.mmd) | Sync data between device and server | S |
| S.3 | [`problem/s3-persist-progress.mmd`](problem/s3-persist-progress.mmd) | Persist progress reliably | S |

### Solution Space — Technical Diagrams (33)

#### Tier 0: Game Overview (3)

| # | File | Type | Description |
|---|------|------|-------------|
| 0.1 | [`solution/0-1-core-game-loop.mmd`](solution/0-1-core-game-loop.mmd) | Flowchart | Explore → Discover → Identify → Decide → Sanctuary → Return |
| 0.2 | [`solution/0-2-activity-skill-matrix.mmd`](solution/0-2-activity-skill-matrix.mmd) | Graph | Which activities feed which skills |
| 0.3 | [`solution/0-3-resource-flow.mmd`](solution/0-3-resource-flow.mmd) | Flowchart | Items, food, orbs between activities |

#### Tier 2: Skills & Progression (2)

| # | File | Type | Description |
|---|------|------|-------------|
| 2.1 | [`solution/2-1-progression-framework.mmd`](solution/2-1-progression-framework.mmd) | Flowchart | Accumulation → levels → unlocks |
| 2.2 | [`solution/2-2-discipline-thresholds.mmd`](solution/2-2-discipline-thresholds.mmd) | Table | Per-skill level thresholds and unlocks |

#### Tier 3: Architecture (4)

| # | File | Type | Description |
|---|------|------|-------------|
| 3.1 | [`solution/3-1-system-context.mmd`](solution/3-1-system-context.mmd) | C4 Context | External actors and system boundaries |
| 3.2 | [`solution/3-2-infrastructure-topology.mmd`](solution/3-2-infrastructure-topology.mmd) | Deployment | Where things run |
| 3.3 | [`solution/3-3-client-layers.mmd`](solution/3-3-client-layers.mmd) | Layers | UI → Providers → Services → Data |
| 3.4 | [`solution/3-4-provider-graph.mmd`](solution/3-4-provider-graph.mmd) | DAG | Riverpod provider dependency wiring |

#### Tier 4: Data Model (5)

| # | File | Type | Description |
|---|------|------|-------------|
| 4.1 | [`solution/4-1-supabase-er.mmd`](solution/4-1-supabase-er.mmd) | ER | All tables, columns, FKs, indices |
| 4.2 | [`solution/4-2-drift-schema.mmd`](solution/4-2-drift-schema.mmd) | ER | Client-side local cache tables (post-MVP) |
| 4.3 | [`solution/4-3-dart-models.mmd`](solution/4-3-dart-models.mmd) | Class | Dart model class relationships |
| 4.4 | [`solution/4-4-data-residency.mmd`](solution/4-4-data-residency.mmd) | Matrix | Where each datum is mastered vs cached |
| 4.5 | [`solution/4-5-enrichment-lifecycle.mmd`](solution/4-5-enrichment-lifecycle.mmd) | Swimlane | NULL → pipeline → species → sync → local → UI |

#### Tier 5: State Machines (4)

| # | File | Type | Description |
|---|------|------|-------------|
| 5.1 | [`solution/5-1-item-lifecycle.mmd`](solution/5-1-item-lifecycle.mmd) | States | Unidentified → enriched → identified → donated |
| 5.2 | [`solution/5-2-enrichment-stages.mmd`](solution/5-2-enrichment-stages.mmd) | States | 5-stage pipeline with failure/retry |
| 5.3 | [`solution/5-3-session-lifecycle.mmd`](solution/5-3-session-lifecycle.mmd) | States | Cold start → hydration → active → background → recap |
| 5.4 | [`solution/5-4-write-queue-states.mmd`](solution/5-4-write-queue-states.mmd) | States | Optimistic → pending → confirmed/failed |

#### Tier 6: Data Flows (7)

| # | File | Type | Description |
|---|------|------|-------------|
| 6.1 | [`solution/6-1-discovery-to-pack.mmd`](solution/6-1-discovery-to-pack.mmd) | Sequence | GPS → cell → encounter → item → pack |
| 6.2 | [`solution/6-2-enrichment-pipeline.mmd`](solution/6-2-enrichment-pipeline.mmd) | Sequence | pg_cron → LLM → images → storage → species |
| 6.3 | [`solution/6-3-enrichment-to-client.mmd`](solution/6-3-enrichment-to-client.mmd) | Sequence | species UPDATE → delta-sync → LocalSpeciesTable |
| 6.4 | [`solution/6-4-identification-flow.mmd`](solution/6-4-identification-flow.mmd) | Sequence | Hold → reveal → stat roll → write queue → confirm |
| 6.5 | [`solution/6-5-sanctuary-donation.mmd`](solution/6-5-sanctuary-donation.mmd) | Sequence | Select → confirm → queue → persist |
| 6.6 | [`solution/6-6-recap-flow.mmd`](solution/6-6-recap-flow.mmd) | Sequence | App open → 6h → compute → cards → dismiss |
| 6.7 | [`solution/6-7-auth-hydration.mmd`](solution/6-7-auth-hydration.mmd) | Sequence | App start → session → hydrate → ready |

#### Tier 7: Game Logic (4)

| # | File | Type | Description |
|---|------|------|-------------|
| 7.1 | [`solution/7-1-stat-rolling.mmd`](solution/7-1-stat-rolling.mmd) | Pseudocode | SHA-256 → seed → baseline ± variance → sum=90 |
| 7.2 | [`solution/7-2-fully-enriched-predicate.mmd`](solution/7-2-fully-enriched-predicate.mmd) | Decision tree | 8-column NOT NULL check |
| 7.3 | [`solution/7-3-collection-membership.mmd`](solution/7-3-collection-membership.mmd) | Logic | habitats × continents × class → collections |
| 7.4 | [`solution/7-4-encounter-selection.mmd`](solution/7-4-encounter-selection.mmd) | Logic | SHA-256(seed+cell) → species list, 3 per cell |

#### Tier 8: UI & Navigation (2)

| # | File | Type | Description |
|---|------|------|-------------|
| 8.1 | [`solution/8-1-screen-navigation.mmd`](solution/8-1-screen-navigation.mmd) | Graph | Tab shell + modals + flows |
| 8.2 | [`solution/8-2-identification-ui-states.mmd`](solution/8-2-identification-ui-states.mmd) | States | idle → pressing → charging → revealing → revealed |

#### Tier 9: Infrastructure (2)

| # | File | Type | Description |
|---|------|------|-------------|
| 9.1 | [`solution/9-1-pg-cron-jobs.mmd`](solution/9-1-pg-cron-jobs.mmd) | Table | All cron schedules and targets |
| 9.2 | [`solution/9-2-rls-policies.mmd`](solution/9-2-rls-policies.mmd) | Matrix | Tables × operations → access rules |

#### Tier 10: Observability (1)

| # | File | Type | Description |
|---|------|------|-------------|
| 10.1 | [`solution/10-1-event-catalog.mmd`](solution/10-1-event-catalog.mmd) | Table | New game events extending design.md §6 |

---

## Critique Resolution Map

| # | Issue | Resolution | Diagram |
|---|-------|-----------|---------|
| 2.1 | Stat model conflict | Species baseline ± 30% instance variance, sum=90, SHA-256 deterministic | 7.1 |
| 2.2 | Enrichment → v3_items gap | Delta-sync on app start: species → LocalSpeciesTable | 6.3, 4.4, 4.5 |
| 2.3 | "Fully enriched" undefined | 8-column NOT NULL predicate | 7.2, 5.1 |
| 2.4 | Fire-and-forget unsafe | Optimistic + write queue + retry + idempotent WHERE guards | 6.4, 5.4 |
| 3.1 | Ghosted gate confusion | Recap says "X unidentified." Fallback cue if needed. | J4 |
| 3.2 | Recap over-engineered | On-demand at login, no cron | 6.6 |
| 3.3 | Farming grind | Separate specimens per slot, cap displayed collections | 7.3 |
| 3.4 | No sanctuary reward | Deferred. Ceremony placeholder. | J3 |
| 4.1 | Encounter rate | 3 per cell | 7.4 |
| 4.2 | Affixes undefined | Deferred | — |
| 4.3 | Color identity | Deferred | — |
| 4.4 | Community vague | Deferred | — |

---

## Cross-References

| Existing Doc | What it covers | Not duplicated here |
|-------------|---------------|---------------------|
| `docs/design.md` | MVP spec, auth state machine, data flow, screen designs, acceptance criteria | Auth states, pack screen layout, design tokens |
| `docs/prd-game-systems.md` | Core feel, game loop, animation system, TCG card design, sanctuary collections | Hold-to-reveal choreography, rarity scaling, card layout |
| `docs/runbook.md` | Deploy, Supabase ops, incident response | CI/CD pipeline, migration procedures |
| `AGENTS.md` | Agent guidance, key decisions, forbidden patterns | Coding conventions, toolchain |
