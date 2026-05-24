# Open Questions

Unresolved questions and blockers.

<!-- Add questions as they arise, move to decisions.md when resolved -->

## Pending

### Backlog audit blockers — 2026-05-03

- **Map acceptance criteria**: `docs/map-design.md` is the active map source of
  truth, but the next execution pass should tighten testable criteria for map
  screen, GPS service, cell detection, visit recording, fog computation, and map
  observability before further implementation.
- **Discovery encounter count**: The old backlog specified 3 encounter slots per
  cell visit, while `docs/prd-game-systems.md` still leaves encounter rate open.
  Decide whether to adopt 3, use 1, or make count variable before implementing
  discovery progression.
- **Identification stat model**: Decide between species-truth stats and
  species-baseline plus per-instance variance. If instance variance is chosen,
  define the deterministic rolling algorithm and test vectors.
- **Enrichment to `v3_items` propagation**: Decide whether the enrichment pipeline
  writes denormalized fields to `v3_items`, a DB trigger/view exposes enrichment
  state, or the client joins/reads directly from `species`.
- **Fully enriched predicate**: Define the exact schema-level predicate or view that
  determines when an item can be identified.
- **Identification persistence**: Replace the PRD's fire-and-forget write with an
  optimistic, retryable, idempotent write path.
- **Affix vocabulary and rules**: Define prefix/suffix vocabulary, generation rules,
  and rarity gates before affixes are included in near-term identification work.
- **Color identity timing**: Confirm color identity is deferred from the first
  identification execution path.

### Sanctuary, economy, and long-term systems

- **Breeding mechanic design**: How does trait inheritance work? CryptoKitty model is
  referenced in design docs but no implementation spec exists. What is the MVP?
- **Museum bundle schema**: Stardew community center model referenced. What are the
  bundle compositions, donation rules, and rewards?
- **Sanctuary feeding MVP**: Infrastructure exists (CaretakingFeature, orb models) but
  no feeding loop. What is the minimum viable feeding interaction?
- **Art lock mechanism**: 51% of instances must select the same art at daily reset.
  How is this tracked server-side? What is the Supabase schema for art voting?
- **Orb spending**: Orbs are produced via sanctuary feeding but spend targets are TBD.
  Breeding? Lures? Cosmetics?
- **First NPC loop**: First concrete NPC type and interaction loop are unresolved. Jeremy rejected Naturalist Field Station and Field Survey/task-board framing as the wrong vision.

### Operations

- **Production migration secret**: `SUPABASE_PRODUCTION_DB_PASSWORD` is not configured,
  so production workflow migrations will skip until the secret is added.
- **Legacy Railway beta service cleanup**: unused sibling service `geo-app beta`
  still exists and may need manual dashboard deletion because API deletion returned
  403 with the available token.

## Resolved (2026-04-07, map-experience-execution)

- **GPS status indicator**: Resolved — no separate indicator. Marker/ring state
  communicates discovery state. See decisions.md.
- **Pack session grouping (R12)**: Resolved — out of scope for this execution.
  Post-MVP.
- **`state` vs `province` naming**: Resolved — keep `state` in code. See decisions.md.
- **0% child-region highlight overlays**: Resolved — not implemented. See decisions.md.