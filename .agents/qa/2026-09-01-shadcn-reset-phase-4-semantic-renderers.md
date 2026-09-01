# Phase 4 Semantic Renderer QA

> **HISTORICAL-EVIDENCE** — Rendered acceptance evidence for PRD Phase 4 on 2026-09-01. Current requirements remain in `docs/prd-shadcn-ui-reset.md`, accepted ADRs, and current project constraints.

## Scope

Issue #580 Phase 4 only: canonical Cell reveal treatment, informed category cue, one gameplay marker with trust/pause treatment, District footprint state, and State/World hierarchy progress. Geometry sources, persisted data, providers, eligibility, Visit/Encounter behavior, routes, schemas, dependencies, frontier-edge behavior, and deployment were intentionally unchanged.

## Rendered matrix

All captures use device-pixel ratio 1, `disableAnimations: true`, the packaged Geist font, production painters/widgets, and the deterministic fixture in `test/visual/phase_four_semantic_renderer_fixture_test.dart`.

| Surface | Normal | Grayscale |
|---|---|---|
| Map mobile | `assets/shadcn-phase-4/map/map-semantic-390x844.png` | `assets/shadcn-phase-4/map/map-semantic-390x844-grayscale.png` |
| Map desktop | `assets/shadcn-phase-4/map/map-semantic-1440x900.png` | `assets/shadcn-phase-4/map/map-semantic-1440x900-grayscale.png` |
| Marker trust | `assets/shadcn-phase-4/marker/marker-trust-rings-390x320.png` | `assets/shadcn-phase-4/marker/marker-trust-rings-390x320-grayscale.png` |
| District footprint | `assets/shadcn-phase-4/district/district-organic-390x844.png` | `assets/shadcn-phase-4/district/district-organic-390x844-grayscale.png` |
| State hierarchy | `assets/shadcn-phase-4/hierarchy/state-neutral-390x844.png` | `assets/shadcn-phase-4/hierarchy/state-neutral-390x844-grayscale.png` |
| World hierarchy | `assets/shadcn-phase-4/hierarchy/world-neutral-390x844.png` | `assets/shadcn-phase-4/hierarchy/world-neutral-390x844-grayscale.png` |

## Findings

- **R1 / R4 — pass.** The actual production legend identifies Present, Explored, Informed, and Shrouded in the Map captures. Unobstructed mobile grayscale samples order Present `0.408` > Explored `0.341` > Informed `0.275` > Shrouded `0.106`; Shrouded exposes no basemap detail. A rendered interior-pixel regression test protects the same order away from the informed cue.
- **R2 — pass.** Every visible fixture Cell uses a six-vertex organic exterior ring; adjoining fixture vertices are exact, and the rendered boundaries show no open seams or square Cell lattice. Diagonal bands are the representative basemap roads, not Cell geometry. Geometry source is the deterministic six-vertex production `Cell` fixture; no square envelope is described as Voronoi.
- **R3 — pass.** Each Map fixture mounts exactly one `PlayerMarker`. The separate informed-category cue and labeled legend sample are not gameplay markers. Trusted, low-confidence, paused, and distance-ring states retain the same center marker; the additive neutral ring has a contrasting edge on light, midtone, and dark substrates.
- **Hierarchy — pass with stated presentation boundary.** District captures preserve irregular production polygon topology and neutral context/unvisited/visited/current hierarchy. State/World captures preserve fixed 80×60 child-summary tiles, counts, and neutral progress. The mini-maps do not invent visible place-name labels; the current route owns surrounding headers/stats/hints. Per-cell/tile state, counts, progress, and player location are exposed through semantics.
- **Accessibility — pass.** State is not hue-only; normal and grayscale pairs remain equivalent. The 51+/<70% tile pair meets 4.5:1, informed cues and marker-ring edges meet their focused contrast gates, hierarchy state has explicit semantics, and reduced-motion marker trust changes update immediately without repeating animation.

## Verification

- Focused Phase 4 suite: `104` passed.
- Full `flutter analyze`: passed with no issues.
- Full Flutter suite: `1556` passed, `12` opt-in capture cases skipped by default.
- Documentation authority contract: `3` passed.
- `npm run eac:check`: no diagnostics.
- `git diff --check`: passed.
- Independent final correctness review: no merge blocker after knowledge-state diagnostics were separated from relationship-based frontier diagnostics.

## Capture note

The 12 screenshot cases are opt-in with `--dart-define=PHASE4_CAPTURE=true`; they are skipped during normal test runs. In this Linux test harness each selected case writes and validates its PNG, then the Flutter runner lingers during shutdown, so generation used a bounded 30-second process and accepted an exit only after the exact PNG, dimensions, and bytes were verified. This is a harness shutdown limitation, not a runtime animation or product behavior change.

## Decision

Phase 4 passes its scoped rendered acceptance. Phase 5 and later remain paused until separately authorized. Production deployment was not performed or authorized.
