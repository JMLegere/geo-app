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

### Problem Space — JTBD Job Canvases (7)

Each canvas contains both the JTBD problem map AND the system spec.

| # | File | Focus Job | Resolves |
|---|------|-----------|----------|
| J1 | [`problem/j1-explore-discover.mmd`](problem/j1-explore-discover.mmd) | Discover wildlife through real-world exploration | 4.1 |
| J2 | [`problem/j2-identify-understand.mmd`](problem/j2-identify-understand.mmd) | Identify and understand my collected specimens | 2.1, 2.3, 2.4 |
| J3 | [`problem/j3-curate-sanctuary.mmd`](problem/j3-curate-sanctuary.mmd) | Build a sanctuary that reflects my journey | 3.3, 3.4 |
| J4 | [`problem/j4-return-reconnect.mmd`](problem/j4-return-reconnect.mmd) | Stay connected to my growing world | 3.1, 3.2 |
| J5 | [`problem/j5-manage-identity.mmd`](problem/j5-manage-identity.mmd) | Maintain my explorer identity | — |
| J6 | [`problem/j6-system-enrichment.mmd`](problem/j6-system-enrichment.mmd) | [System] Make every species identifiable | 2.2, 2.3 |
| J7 | [`problem/j7-system-sync.mmd`](problem/j7-system-sync.mmd) | [System] Keep player data safe and consistent | 2.4 |

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
