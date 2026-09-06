# Issue #596 finish plan

**Status:** Proposed delivery plan, prepared 2026-09-06 from the approved issue
contract and draft implementation checkpoint. This document does not itself
authorize implementation, accept artwork, prove behavior, or authorize a
production deployment.

## 1. Source snapshot

Plan against these immutable inputs rather than the moving heads of the draft
pull requests:

- Issue [#596](https://github.com/JMLegere/geo-app/issues/596), including its
  normative execution-slice continuation and the 2026-09-06 implementation
  checkpoint comment.
- Target-specification draft PR
  [#597](https://github.com/JMLegere/geo-app/pull/597) at
  `63a5ecb48b0c2cdfb8fa7b102aa726578923c2f9`.
- Implementation draft PR
  [#598](https://github.com/JMLegere/geo-app/pull/598) at
  `4d99525e34ad4b33517e1bf4f1fb6e9d7abf7e74`, based on
  `f96a841b4eba5468ee9c0958b36c52d67c60b3b7`.

At that checkpoint, PR #598 reports 150 traced decisions, 34 partially
assessed decisions, 116 unassessed decisions, no fully verified decisions, 93
presentation-debt occurrences, and pending actual-iPhone acceptance. Its four
Flutter renders are useful review evidence, but are not real-device evidence.
The target scenarios remain parsed specifications rather than executed target
acceptance.

## 2. Delivery strategy

Use the issue's S01-S09 order as the product sequence, but finish it as small,
reviewable vertical slices instead of allowing draft PR #598 to become one
indefinitely growing app-wide change.

1. **Stabilize and land the checkpoint.** Rebase PR #598 on current `main`,
   resolve whether PR #597 is superseded by the specification copy already in
   #598, and make the checkpoint independently mergeable as foundation plus
   Pack browsing. Do not claim that this closes #596.
2. **Deliver one follow-up PR per exit criterion.** A follow-up may cover part
   of one numbered slice when that is the smallest complete player-verifiable
   change. Every PR updates the decision matrix, execution status, report,
   surface inventory, native contracts, tests, and rendered evidence together.
3. **Keep only one visual authority.** Continue the pinned Shad default ->
   EarthNova semantic override -> shared recipe -> feature composition chain.
   Do not add screen-local styling or a competing component library to move a
   slice faster.
4. **Do not convert evidence into acceptance.** `partial`, `unassessed`, and
   `verified` must be based on the evidence required by each decision. Parsing
   Gherkin, resolving a path, rendering a workbench example, or passing a
   registry test is never enough by itself.
5. **Preserve domain and state boundaries.** UI work may project existing
   Item, Base Item, Identification, Discovery, Discipline, Encounter, Map,
   readiness, and working-set state; it must not invent rarity, currency,
   universal Player level, Orb behavior, Home Modules, or new command support.

## 3. Immediate gates and decisions

### Gate A — checkpoint integrity

Before adding more implementation to PR #598:

- Rebase its three commits onto current `main` and run the complete local gate
  from a clean checkout.
- Confirm hosted CI for checkpoint `4d99525e...`; the report only establishes
  hosted CI for its earlier foundation parent.
- Diff PRs #597 and #598. If #598 contains the complete reviewed specification,
  close #597 as superseded after preserving attribution/history. Otherwise,
  merge the specification first and rebase #598 on that commit. Never land two
  divergent copies of the UI596 decision manifest.
- Review the current 34 `partial` classifications one by one and downgrade any
  entry whose evidence proves only ownership, parsing, or a fixture rather than
  its required behavior/visual contract.
- Confirm the checkpoint contains no schema migration, production mutation,
  deployment trigger, dependency upgrade, or broadened offline-command policy.

### Gate B — creative-director artwork approval

PRD D003 and S04 require Jeremy to approve a representative art direction
before routine production art is created. Present the existing candidate at
actual intended sizes together with:

- 12px and 16px logical-pixel Fauna trials in the five-column iPhone Pack;
- known and Unknown renderings made from the same recognizable shape;
- at least two visually similar species and one non-Fauna category;
- normal and 200% text layouts, light/dark contrast checks as applicable, and
  the fallback state; and
- an explicit note that the candidate Orb is visual research, not approved Orb
  behavior.

Record approval or requested changes in issue #596. Until approval, proceed on
non-art work but do not generate the routine production asset set or mark the
ART decisions verified.

### Gate C — category property mapping

Inventory the immutable Base Item Version schemas and current Pack projections,
then propose a typed, category-by-category table for Fauna, Flora, Mineral,
Fossil, Artifact, Food, and Orb. Each row must name the existing source field,
knowledge/Identification visibility rule, short label, units/format, missing
applicability, and fixture coverage. An absent schema is `not applicable` or a
documented blocker—not permission to invent a property. Obtain product approval
for any choice among multiple scientifically valid existing properties before
coding it.

## 4. Ordered implementation waves

### Wave 0 — land the foundation/Pack checkpoint (S01, S02/S03/S05 partial)

**Scope**

- Complete Gates A and the review of the existing Pack fixture matrix.
- Fix only checkpoint blockers: public API/contract parity, semantics,
  responsive overflow, knowledge-safe search/filter behavior, state retention,
  refresh recovery, or test/CI reproducibility.
- Update execution status to describe exactly what the checkpoint proves and
  leave the rest pending.

**Exit evidence**

- The same semantic recipe affects a real Pack consumer and workbench case.
- Intentional untouched Shad behavior demonstrably keeps its pinned default.
- Illegal feature styling and invalid token references fail enforcement.
- Pack logic preserves exact Item selection, five standard-iPhone columns,
  hidden visual names, explicit search scope, per-category browsing context,
  Unknown knowledge boundaries, and usable loaded content during refresh.
- Hosted CI passes the exact merge candidate SHA.

### Wave 1 — finish shared primitives and shell (S02-S03)

**Scope**

- Finish calibrated raised/inset/overlay materials, typography, metrics, symbol
  and information/legend primitives.
- Finish primary, secondary, unavailable-with-reason, busy, cost, progress,
  outcome, and reward states without creating conditional mechanics that do not
  exist.
- Integrate one real authoritative action and prove no duplicate submission.
- Integrate title ribbon, current navigation, contextual Help, settings entry,
  safe areas, and only currently applicable Discipline/resource counters.

**Exit evidence**

- Pointer, touch, keyboard, focus, semantics, unavailable explanations, rapid
  interruption, and stable busy geometry are tested at real consumers.
- Navigation keeps route/selection state; Help has accessible names and remains
  until dismissal or destination selection.
- Compact and expanded layouts are rendered with long numbers and 200% text.
- Representative press/release and frame-budget traces are captured on the
  actual iPhone; no placeholder is presented as a real balance or progression.

### Wave 2 — art delivery, presentation adapters, and final cards (S04)

**Dependency:** Gate B approval for routine art; Gate C for card properties.

**Scope**

- Turn approved exemplars into original, versioned production assets and a
  stable semantic manifest with art revision, size variant, optical bounds,
  silhouette reference, attribution/license metadata, and fallback key.
- Implement bounded loading/caching and safe failure behavior in the existing
  Asset Delivery boundary.
- Add the minimum owner-bound projection needed to determine Player x stable
  Base Item Unknown state without exposing hidden identity or metadata.
- Complete typed Item presentation adapters and all applicable category
  property mappings. Reuse Base Item art across Item copies while keeping each
  Item's permanent property values distinct.
- Finalize card framing, Unknown ribbon, category/property symbols, property
  strip, selection state, and crowding priority.

**Exit evidence**

- Known and Unknown use the same actual silhouette; API payloads, semantics,
  search, filter membership, logs, and fallback resources do not leak withheld
  data.
- First inspection clears the one Base-Item Unknown state for owned and future
  copies; it creates no per-copy New lifecycle and does not falsely award
  Discovery or XP.
- Scientific and visual review covers representative similar species and every
  applicable category at actual card sizes.

### Wave 3 — complete Pack and inspection (S05-S06)

**Scope**

- Apply final tokens/assets/property mappings to the real Pack and complete any
  remaining header/counter/retrieval calibration.
- Build inspection from the same card grammar: exact selected Item, knowledge-
  safe header, single-line shrinking name exception, wrapping metadata,
  category-ordered three-column stats, effects, contextual legend, and full
  glossary route.
- Keep Close and action footer reachable for long content, reserve bottom
  padding, allow reversible backdrop dismissal, and restore Pack category,
  query, filters, sort, selection, and scroll.

**Exit evidence**

- Test longest names, labels, values, units, metadata, effects, Unknown and
  inapplicable fields, crowded badges, empty/error/loading/no-match states, 200%
  text, reduced motion, and compact/expanded widths.
- Opening/closing never changes the selected Item. Dismissing presentation does
  not cancel a command already submitted to its authoritative owner.
- Production-like fixture measurements meet the <=100ms first meaningful local
  response target after readiness.

### Wave 4 — authoritative outcomes and living feedback (S07)

**Scope**

- Connect shared pending/success/failure/retry presentation to real
  Identification, acquisition, and Encounter result boundaries.
- Preserve the existing supported durable command list, exact version binding,
  Villager Service ownership, cancellation-before-commit, atomic commit, and
  idempotent replay.
- Highlight newly revealed properties only after confirmed Identification;
  attach the small first-Discovery badge only when the authoritative result says
  Discovery occurred.
- Add enabled outcome-only audio with lifecycle deduplication. Add subtle,
  staggered idle art for only a few visible Items, suspend it offscreen, and
  provide a static reduced-motion path.
- Keep new Encounters on Map as user-opened opportunities rather than automatic
  takeovers.

**Exit evidence**

- Tests distinguish pending, preparation failure, commit failure, retry,
  response-loss replay, success without first Discovery, and success with first
  Discovery. Rebuild/replay cannot duplicate sound or visual outcome feedback.
- Device traces show scrolling and primary input remain responsive while idle
  motion is active.

### Wave 5 — app-wide adoption and recovery (S08)

Migrate one surface family at a time, completing each before starting the next:

1. root/readiness/auth/loading/recovery;
2. Map chrome, Encounter and Cell detail, then territory routes;
3. Town, Venue detail and Home identity;
4. settings and every current stub/empty route.

For each family, first add a failing boundary or widget test, replace direct
style/raw Shad usage with the public shared adapter, update its native design
contract and inventory, render compact/expanded/200%-text/error states, and
remove its presentation-debt entries. Preserve Map topology, fog/knowledge,
GPS trust, navigation, readiness, degraded-session, Retry/Sign-out, account
isolation, and all current gameplay semantics.

**Exit evidence**

- The presentation-debt count reaches zero for ordinary player-facing code.
  Any remaining renderer/infrastructure exception is narrow, documented, and
  enforced.
- No current player-facing surface is unowned or listed as “migrate later.”
- Working-set and recovery tests prove usable retained content is not replaced
  unnecessarily and account/environment boundaries remain intact.

### Wave 6 — verification and release closure (S09)

**Scope**

- Audit Q001-Q111, A001-A027, and D001-D012 individually against their named
  consumer and required behavioral, visual, contract, knowledge, motion, audio,
  performance, and/or real-device evidence.
- Execute target acceptance at real Flutter boundaries; do not leave the 59
  target scenarios as parser-only evidence.
- Resolve every provisional token, 12px/16px trial, conditional mechanic,
  property mapping, and surface exception. `not applicable` requires a reason
  and test where drift could later make it applicable.
- Reproduce generated outputs (if the approved narrow token projection is
  used), lockfiles, assets, and review builds from a clean checkout.

**Exit evidence**

- Decision audit totals exactly 150 with every applicable record verified and
  every omission explicitly justified; partial and unassessed totals are zero.
- Actual-iPhone review is recorded by Jeremy for shared exemplars and named
  exceptions; static workbench screenshots are supplementary.
- Full local and hosted gates pass on the exact merge SHA.
- Merge to `main` only after human approval. Under ADR 0011, verify that CI
  deploys that exact green SHA automatically, run the production smoke and
  telemetry checks from the runbook, then update/close issue #596 with links to
  evidence. Use manual exact-SHA dispatch only as the documented recovery path.

## 5. Required test and evidence matrix

Every implementation PR selects the applicable rows below and records exact
commands/results in its report.

| Concern | Minimum evidence |
| --- | --- |
| Domain/application behavior | Focused pure Dart and Flutter tests written red-first; repository/use-case boundary tests for knowledge and mutation rules |
| Shared component behavior | `flutter_test` coverage for touch, keyboard, focus, semantics, loading, unavailable explanations, interruption and reduced motion |
| Product behavior | Executed SuperBDD scenarios at real adapters where feasible, plus focused integration/widget tests; parser success alone is insufficient |
| Design ownership | Public barrel, registry parity, native EAC contract, surface inventory and illegal-import/style checks |
| Visual quality | Deterministic real-screen renders at 320, 390, 390 with 200% text, and expanded width; state-specific review rather than gallery-only examples |
| Knowledge safety | Owner/account isolation, Unknown payload/search/filter/semantics/fallback tests and no hidden-data telemetry |
| Performance | Measured first meaningful local response after readiness and actual-iPhone frame traces for scroll, transition and motion cases |
| Delivery | Clean-checkout reproduction, full Flutter/analyzer/EAC/specification gates, hosted CI on exact SHA, then runbook production verification after merge |

Baseline commands, adjusted with focused paths while developing:

```bash
eval "$(~/.local/bin/mise activate bash)"
mise exec -- flutter test --no-pub test/shared/design
mise exec -- flutter test --no-pub
mise exec -- flutter analyze
npm run spec:ui596:check
npm run superbdd:cucumber
mise exec -- eac check
git diff --check
```

Use the repository's coverage command, not an ad hoc denominator, for the
required >=95% CI-filtered coverage gate. Asset and screenshot checks must also
validate format, dimensions, provenance/license metadata, and deterministic
manifest references.

## 6. Pull-request and status discipline

Each follow-up PR must state:

- the issue slice and exact decision IDs it attempts to complete;
- the player-visible vertical slice and real consumers changed;
- the red tests observed before implementation;
- evidence paths and their type, with no unsupported `verified` claim;
- schema, dependency, data, command-policy, deployment, and domain impact;
- presentation-debt count before and after;
- remaining blockers and the next smallest slice; and
- explicit wording that merge/deployment/issue closure require human approval.

Update `execution-status.yaml` monotonically from evidence: use `pending`,
`implementing`, `implemented_unverified`, `blocked` with a named external gate,
and `verified` only when the slice exit criteria are met. Keep the issue open
until Wave 6; a merged intermediate PR is a checkpoint, not completion.

## 7. Critical path

The shortest safe critical path is:

`checkpoint integrity -> foundation/Pack merge -> art approval + property
mapping -> production art/cards -> inspection -> authoritative feedback ->
remaining surfaces -> 150-decision audit -> iPhone acceptance -> exact-SHA
green merge/deploy verification`.

S02/S03 calibration, inventory reconciliation, inspection test scaffolding,
and non-art surface ownership work can proceed while art review is pending.
Production asset generation and final S04/S05/S06 visual acceptance cannot.
