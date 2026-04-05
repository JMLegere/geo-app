# Adversarial Review — `prd-game-systems.md`

> Critical review of `docs/prd-game-systems.md` against the current codebase,
> schema, and `docs/design.md`.
>
> This document is intentionally skeptical. Its purpose is to identify
> contradictions, hidden complexity, under-specified systems, and execution risk
> before the PRD is used to drive implementation.

---

## 1. Executive Verdict

The PRD is **strong as a design-intent brief, but risky as an execution document**. It contains a coherent emotional vision and a compelling top-level game loop, but it overstates how settled the system is. Several mechanics described as if they are implementation-ready still depend on unresolved foundational decisions, especially around stat generation, enrichment propagation, collection rewards, and identification persistence. Most critically, the PRD assumes an enrichment-driven item lifecycle that the current code and pipeline do not support yet.

If treated as inspiration, it is valuable. If treated as a build-ready PRD, it is likely to create rework.

---

## 2. Critical Issues

### 2.1 Per-instance stat rolling conflicts with the current enrichment model

- **Issue**
  The PRD says item stats are rolled per instance from `SHA-256(instance UUID)` and distributed around a species baseline. The current enrichment pipeline generates `brawn`, `wit`, and `speed` at the **species** level and validates that they sum to 90 before writing them to `species`.
- **Why it matters**
  These are two fundamentally different models. If not resolved, implementation will fork into incompatible assumptions about where truth lives.
- **Evidence**
  - `docs/prd-game-systems.md:114-118`
  - `supabase/functions/process-enrichment-queue/index.ts:358-372`
  - `supabase/migrations/019_species_table.sql:18-20`
  - `lib/models/item.dart:48-65`
- **Recommended correction**
  Decide explicitly between:
  1. **Species-truth model** — all instances of a species share the same stats
  2. **Species-baseline + instance variance model** — species defines the center, item UUID defines the deviation

  If option 2 is chosen, the PRD must include the exact rolling algorithm and at least one deterministic test vector.

### 2.2 The enrichment pipeline does not update `v3_items`

- **Issue**
  The PRD assumes species enrichment will quietly make player-owned items identifiable. The current enrichment denormalization path targets the old `item_instances` table, not `v3_items`.
- **Why it matters**
  The proposed ghosted enrichment gate cannot work if enriched data never reaches the table the client actually reads.
- **Evidence**
  - `docs/prd-game-systems.md:97-100`
  - `supabase/functions/process-enrichment-queue/index.ts:1033`
  - `supabase/migrations/032_v3_schema.sql:40-55`
  - `supabase/migrations/035_v3_items_filter_columns.sql:1-17`
- **Recommended correction**
  Add one of these to the PRD before implementation:
  1. Extend the enrichment pipeline to update `v3_items`
  2. Add a trigger/function to propagate species enrichment changes into `v3_items`
  3. Change the client fetch path to join/read enrichment state directly from `species`

### 2.3 “Fully enriched” is under-specified

- **Issue**
  The PRD defines fully enriched in product terms, but not in schema terms. The current pipeline is stage-based and there is no explicit `is_fully_enriched` flag.
- **Why it matters**
  The client cannot reliably decide whether a specimen should respond to hold-to-identify without an exact predicate.
- **Evidence**
  - `docs/prd-game-systems.md:159-163`
  - `supabase/functions/process-enrichment-queue/index.ts:256-289`
  - `supabase/functions/process-enrichment-queue/index.ts:737`
- **Recommended correction**
  Define one exact rule in the PRD, e.g.:
  - `animal_class IS NOT NULL AND climate IS NOT NULL AND brawn IS NOT NULL AND wit IS NOT NULL AND speed IS NOT NULL AND size IS NOT NULL AND icon_url IS NOT NULL AND art_url IS NOT NULL`

  Better: add a computed/materialized `is_fully_enriched` field or a DB view.

### 2.4 Fire-and-forget identification writes are unsafe

- **Issue**
  The PRD treats identification persistence as fire-and-forget after the reveal animation.
- **Why it matters**
  If the write fails, the client and server diverge. The player believes the specimen is identified; on next fetch it may revert.
- **Evidence**
  - `docs/prd-game-systems.md:109`
  - `lib/providers/items_provider.dart:71-95`
  - `supabase/migrations/032_v3_schema.sql:124-132`
- **Recommended correction**
  Replace fire-and-forget with:
  - optimistic local state
  - retryable persistence using `v3_write_queue`
  - idempotent writes (`WHERE identified = false`)

---

## 3. Major Risks

### 3.1 The ghosted enrichment gate may create player confusion

- **Issue**
  The PRD assumes hidden readiness is elegant: some unidentified cards respond to hold, others do not, with no visible explanation.
- **Why it matters**
  A player with many mystery cards may reasonably conclude the gesture is broken or inconsistent.
- **Evidence**
  - `docs/prd-game-systems.md:93-101`
  - `docs/prd-game-systems.md:374`
- **Recommended correction**
  Reframe this as a hypothesis, not a settled decision. Add a fallback plan:
  - recap can show “X specimens are ready to identify”
  - or add a subtle ready-state cue if playtests show confusion

### 3.2 Recap snapshot cron is over-engineered at this stage

- **Issue**
  The PRD proposes hourly precomputed recap snapshots for every account.
- **Why it matters**
  This introduces infrastructure and data freshness complexity before there is evidence that on-demand recap queries are too slow.
- **Evidence**
  - `docs/prd-game-systems.md:381`
  - `docs/design.md:633-645`
- **Recommended correction**
  Default to computing recap on login behind the existing loading flow, then cache the result. Introduce cron only if profiling proves necessary.

### 3.3 Collection membership may become a farming grind

- **Issue**
  One species can belong to multiple collections because habitats and continents are arrays. The PRD requires one instance per slot.
- **Why it matters**
  A common species appearing in many collections can turn the cozy loop into repetitive farming.
- **Evidence**
  - `docs/prd-game-systems.md:311-341`
  - `supabase/migrations/019_species_table.sql:12-13`
- **Recommended correction**
  Add a design note acknowledging this tradeoff and define guardrails before implementation:
  - maximum intended collections per species
  - or whether one donation can satisfy multiple bundles in narrow cases

### 3.4 The sanctuary completion loop has no reward defined

- **Issue**
  The PRD references bundle completion rewards without specifying what they are.
- **Why it matters**
  Without payoff, the sanctuary is accumulation without closure.
- **Evidence**
  - `docs/prd-game-systems.md:59`
  - `docs/prd-game-systems.md:554`
- **Recommended correction**
  Either define placeholder rewards now or explicitly defer sanctuary implementation until reward design exists.

---

## 4. Ambiguities Hidden as Decisions

### 4.1 Encounter rate per cell is still open, but should not be

- **Issue**
  The PRD leaves encounter count per cell as an open question.
- **Why it matters**
  This is not a detail. It controls inventory growth, sanctuary pacing, recap usefulness, and identification backlog.
- **Evidence**
  - `docs/prd-game-systems.md:558`
  - `2026-04-03-backlog.md:25`
- **Recommended correction**
  Either explicitly adopt the backlog’s “3 encounter slots per cell visit” or mark the whole discovery loop as still exploratory.

### 4.2 Affixes are described as if implemented, but their vocabulary is undefined

- **Issue**
  Prefix/suffix behavior appears throughout the PRD, but the actual vocabulary and generation rules are missing.
- **Why it matters**
  This makes the identification system feel more settled than it is.
- **Evidence**
  - `docs/prd-game-systems.md:127-137`
  - `docs/prd-game-systems.md:554`
- **Recommended correction**
  Move affixes out of Phase 1 unless the PRD includes:
  - vocabulary set
  - generation rules
  - rarity gating table

### 4.3 Color identity is premature

- **Issue**
  The PRD derives RGB values from stats and implies UI usage.
- **Why it matters**
  This adds visual and implementation complexity without a clear near-term gameplay payoff.
- **Evidence**
  - `docs/prd-game-systems.md:140`
- **Recommended correction**
  Mark color identity as post-Phase-1 depth. Keep the idea, remove it from the near-term execution path.

### 4.4 Community is too vague to influence architecture yet

- **Issue**
  The PRD includes a meaningful community vision, but no concrete schema or first implementation slice.
- **Why it matters**
  It reads as committed scope while still being aspirational.
- **Evidence**
  - `docs/prd-game-systems.md:392-405`
- **Recommended correction**
  Reduce it to explicit architectural assumptions and defer the rest.

---

## 5. What to Cut or Defer

1. **Cut the Orbs section from the PRD.** It is acknowledged as undefined and adds phantom scope.
2. **Reduce Community to a short assumptions section.** Keep the emotional direction, cut the faux phase plan.
3. **Defer Affixes from initial identification implementation.** Keep the concept, remove it from the first buildable phase.
4. **Defer Color Identity.** It is decorative depth, not foundational gameplay.
5. **Defer `v3_sanctuary_donations` schema until sanctuary phase.** The PRD can mention it, but shouldn’t imply it’s ready for migration now.

---

## 6. What’s Strong

- The **core feel hierarchy** is genuinely coherent and useful.
- The **main game loop** is strong and emotionally aligned.
- The **hold-to-reveal choreography** is detailed enough to implement.
- The **collection size analysis** creates believable long-term progression.
- The **implementation ordering** correctly places enrichment reliability first.
- The **discrepancy callouts** between docs and code are one of the strongest parts of the PRD.

---

## 7. Revised Recommendation

To make the PRD safe to execute with minimal revision:

1. **Resolve the stat model first.** This is the foundational contradiction.
2. **Define the enrichment → `v3_items` propagation path.** Without this, the lifecycle cannot work.
3. **Define `fully enriched` as an exact predicate.**
4. **Replace fire-and-forget persistence with optimistic write + retry.**
5. **Cut or reduce Orbs and Community.** Keep the PRD focused on buildable systems.
6. **Move Affixes and Color Identity out of the first implementation phase.**
7. **Add a guardrail at the top of the PRD:**

> This document describes target state. Items marked TBD or listed in Open Questions must be resolved before the relevant phase begins. No phase should start with open questions in its critical path.

With those changes, the PRD becomes ambitious but safe instead of ambitious and misleading.
