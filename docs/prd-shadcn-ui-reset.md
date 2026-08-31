# EarthNova Pure `shadcn_ui` Reset PRD

> **Role: CURRENT-SCOPED.** This document defines the approved product requirements for GitHub Issue [#580](https://github.com/JMLegere/geo-app/issues/580). It is subordinate to `AGENTS.md`, `CONTEXT.md`, accepted ADRs, and `.agents/constraints.md`. It does not authorize implementation or deployment by itself.

| Field | Value |
|---|---|
| Status | **PHASE 2 COMPLETE — Phase 3+ implementation remains paused and requires explicit user authorization** |
| Version | 1.0 |
| Date | 2026-08-31 |
| Product | EarthNova Flutter client |
| Selected library | [`shadcn_ui` 0.56.2](https://pub.dev/packages/shadcn_ui/versions/0.56.2) |
| Outcome Contract | GitHub Issue #580 |
| Active environments | `local`, `prod` |
| Production deployment | Not authorized |

---

## 1. Executive Summary

EarthNova will replace its entire inherited application styling with the neutral defaults and components of the open-source Flutter package `shadcn_ui` 0.56.2. This is a clean visual-system cutover, not a reskin: the current Carbon styling, EarthNova theme palette, typography treatment, radii, panels, buttons, fields, tags, notices, navigation styling, glows, gradients, emoji-driven controls, and TCG presentation will be removed rather than translated.

The reset is presentation-only. It must preserve current product behavior, routes, the two-destination Map/Pack shell, Riverpod state, telemetry, accessibility, disclosure boundaries, MapLibre behavior, custom map rendering, and local/prod data semantics. Meaning-bearing visual distinctions remain where removing them would change comprehension: Map knowledge/fog state, GPS trust, conservation status, focus, success, warning, destructive, and error state.

The result should feel like a coherent neutral shadcn application—not a generic reconstruction of the old visual language and not a JavaScript/React rewrite.

---

## 2. Problem Statement

EarthNova currently contains multiple inherited styling systems:

1. a dark EarthNova palette and token layer;
2. shared `Earth*` components with bespoke typography, rounding, shadows, and semantic tones;
3. Carbon-derived shell styling;
4. feature-local Material controls and custom decorations;
5. historical mock styling that still influences some implementation language;
6. domain renderers whose semantic and decorative styling are mixed together.

This creates four product problems:

- **Inconsistency:** active surfaces do not share one visual grammar.
- **Maintenance cost:** styling decisions are spread across shared wrappers, feature files, painters, and one-off constants.
- **Ambiguous authority:** historical EarthNova, Carbon, Material, and mock patterns can each appear valid to an implementer.
- **Migration drag:** adapting existing wrappers would preserve the same system under different colors rather than establishing a clean baseline.

The user explicitly chose an **absolute pure shadcn reset**. The product requirement is therefore removal, not incremental visual compatibility.

---

## 3. Product Outcome

### 3.1 Primary outcome

Every active and canonical implemented player surface uses one neutral `shadcn_ui`-based visual system, with explicit technical exceptions only where the package has no equivalent.

### 3.2 User outcome

An Explorer can move between authentication, readiness, Map, Pack, examination, Identification, Town, Venue, Home, and Settings without encountering visibly competing design systems or changes to familiar product behavior.

### 3.3 Engineering outcome

A coding agent can determine where reusable presentation belongs, which components are approved, which native Flutter primitives may remain, and which semantic visual encodings must be preserved without re-investigating design intent.

### 3.4 Success definition

The reset succeeds when:

- every in-scope surface is migrated;
- no retired visual component or styling system remains reachable;
- behavioral, domain, accessibility, telemetry, and data contracts still pass;
- required screenshots pass human visual review;
- R1–R8 Map requirements remain true;
- no production or data mutation occurs as part of the UI work.

---

## 4. Users and Jobs to Be Done

### 4.1 Mobile Explorer

**Job:** Open EarthNova while moving through the real world, understand location/readiness state immediately, inspect the current Cell, resolve Encounters, and review acquired Items without UI ambiguity.

**Needs:**

- strong first-frame hierarchy;
- touch targets of at least 44 px;
- reliable bottom navigation;
- clear loading, paused, degraded, and error states;
- sheets and dialogs that remain usable at mobile widths and large text scales.

### 4.2 Desktop Explorer

**Job:** Use Desktop Traversal and keyboard navigation to explore, open Map/Pack/Settings, and operate dialogs, sheets, filters, and Identification without requiring a pointer.

**Needs:**

- visible focus;
- predictable tab order;
- Escape/dismiss behavior;
- keyboard-operable navigation and controls;
- responsive content that does not simply stretch mobile layouts.

### 4.3 Returning Collector

**Job:** Scan the Pack, filter and sort Items, distinguish examination from Identification, inspect conservation information, and resume prior work without losing collection context.

**Needs:**

- stable grid behavior;
- clear item lifecycle state;
- preserved disclosure boundaries;
- semantic conservation labels that do not rely only on color;
- predictable modal and route behavior.

### 4.4 QA and Operator

**Job:** Reproduce visual and interaction states without physical walking, compare screenshots, trace user actions, and prove that the reset did not alter gameplay or persistent state.

**Needs:**

- deterministic fixtures;
- simulated location;
- stable keys and semantics;
- observable action evidence;
- explicit screenshot matrix and go/no-go criteria.

---

## 5. Product Principles

1. **Reset, do not reinterpret.** Existing styling is deletion input, not inspiration.
2. **One visual substrate.** New shared visual components use `shadcn_ui`; no second UI framework is introduced.
3. **Behavior before appearance.** A visual change may not alter routing, state, gameplay, disclosure, persistence, or telemetry.
4. **Semantic exceptions are narrow.** Preserve visual distinctions only when they communicate product meaning.
5. **Map semantics outrank generic UI styling.** Component chrome resets; Map truth remains comprehensible.
6. **No historical resurrection.** Four-tab navigation, Province, Sanctuary, emoji controls, hue-heavy fog, rarity mechanics, and old mock styling do not return.
7. **Accessibility is part of parity.** A visually correct surface that loses semantics, focus, text scaling, or reduced-motion behavior is incomplete.
8. **No competing legacy layer.** Compatibility aliases may not retain styling-era components indefinitely.
9. **Evidence closes the work.** Tests supplement but do not replace rendered visual inspection.

---

## 6. Scope

### 6.1 In scope

#### Foundations and shared presentation

- Flutter root theme integration;
- shared design taxonomy, barrel, registry, and native contracts;
- buttons, badges, cards, notices, field rows, stat grids, empty/error states, loading composition;
- typography, spacing, radii, borders, elevation, focus, and interaction states;
- responsive and accessibility behavior.

#### Player-facing surfaces

- authenticated loading;
- login;
- App Readiness loading, failure, syncing, and degraded states;
- two-destination Map/Pack shell;
- mobile and desktop navigation treatment;
- Map HUD, status, errors, readiness cover, sheets, hints, rewards, Encounter layer, and hierarchy screens;
- Pack search, filters, sorting, grid, loading, empty, error, Item states, and paging/swipe behavior;
- Species Card;
- Identification Service;
- Town;
- Venue detail and marker;
- Home;
- Settings;
- shared error boundary, retry, stub, and loading surfaces.

#### Contracts and evidence

- public UI import boundary;
- component registry;
- surface inventory;
- native product design contracts;
- widget, interaction, accessibility, and rendered QA coverage;
- current-scoped project-memory updates after implementation evidence exists.

### 6.2 Out of scope

- React, Next.js, Vite, or JavaScript shadcn CLI migration;
- backend, schema, RPC, auth, data, gameplay, or Riverpod changes;
- new routes, tabs, features, or information architecture;
- changing MapLibre, geometry generation, projection, hit testing, or geolocation;
- redesigning the semantic meaning of Map state, GPS trust, conservation status, success, or error;
- resolving the frontier-edge authority conflict;
- light-mode product design;
- app-icon or brand redesign;
- debug-only tooling and overlays;
- historical beta mutation or active beta deployment;
- production deployment.

---

## 7. Preserved Product Invariants

The migration must preserve all of the following:

### 7.1 Navigation and routing

- exactly two active shell destinations: Map and Pack;
- current lazy materialization and state retention;
- current Settings route behavior;
- current Identification, Venue, hierarchy, and other imperative routes;
- existing navigation observer and telemetry;
- no four-tab historical shell.

### 7.2 State and data

- Riverpod 3 `Notifier` ownership;
- Supabase as source of truth;
- no new local database or cache architecture;
- current warm/cold readiness behavior;
- persisted plus eligible optimistic visit-footprint truth;
- existing local/prod semantics;
- exact-version and disclosure boundaries.

### 7.3 Exploration

- MapLibre remains mounted and stable across GPS ticks;
- one app-owned gameplay marker; no native puck;
- GPS trust/paused state remains visible;
- organic Cell geometry remains authoritative;
- initial occupancy and trust recovery do not silently become Visits;
- first crossing, revisit, queued/persistence failure, and degraded behavior remain unchanged.

### 7.4 Pack and knowledge

- Pack filtering, sorting, search, grid, loading, paging, and edge swipe remain behaviorally identical;
- Examination and Identification remain separate product actions;
- unidentified Items retain current disclosure boundaries;
- conservation status remains semantic and is never promoted into a new rarity mechanic;
- Town, Venue, Home, and Identification retain current domain terminology and route behavior.

### 7.5 Observability

- `ProductActionSurface` and observable interaction evidence remain intact;
- screen lifecycle and readiness outcomes remain traceable;
- migration does not rename stable telemetry without a separately approved identifier migration;
- safe outward errors remain safe.

---

## 8. Visual System Requirements

### VS-1 — Single neutral baseline

The application must use the neutral dark defaults of `ShadZincColorScheme.dark()` as its visual baseline for the initial cutover.

- No custom EarthNova brand palette is translated into the new scheme.
- No Carbon palette remains.
- No historical mock palette remains.
- No parallel light theme is introduced.

### VS-2 — Typography

- Use `shadcn_ui` theme typography as the default hierarchy.
- Remove custom EarthNova uppercase/monospace metadata treatment as a reusable system.
- Local monospace may remain only where the content itself is code, an identifier, or operational evidence.
- Do not introduce a new font dependency during the reset.

### VS-3 — Spacing and density

- Use shadcn component defaults and a small shared spacing vocabulary only where Flutter composition requires explicit layout.
- Remove old spacing/radius tokens that exist solely to recreate the retired design.
- Do not preserve old control geometry for visual compatibility.
- Preserve accessibility minimums even where package defaults are smaller.

### VS-4 — Surfaces

- Default bounded surfaces use `ShadCard` or a neutral equivalent.
- Avoid wrapping every section in a card.
- Remove glass, blur, bespoke gradients, glow borders, rarity glow, and inherited shadows.
- Map overlay contrast may use an opaque or translucent neutral surface only when necessary for legibility over tiles.

### VS-5 — Controls

Every interactive state must be visually defined:

- default;
- hover;
- focused;
- pressed;
- selected;
- disabled;
- loading;
- destructive;
- error.

Selection cannot rely only on color.

### VS-6 — Motion

- Preserve only motion that communicates state or continuity.
- All repeating or decorative motion must honor `MediaQuery.disableAnimationsOf`.
- Provide static loading/reward fallbacks.
- Do not add bounce, particle, glow, or brand motion as part of this reset.

### VS-7 — Imagery and iconography

- Keep real species assets and necessary category fallbacks.
- Remove emoji as primary navigation, filter, category, status, and action controls.
- Use native icons or package-supported icons with semantic labels.
- Do not create a replacement brand illustration system.

---

## 9. Semantic Visual Exceptions

These categories may retain or receive explicit semantic styling because removing the distinction would change comprehension.

### 9.1 Map knowledge and fog

The exact old hex values are not protected, but the product relationships are:

- Present/current is clearest and most immediate;
- Explored is visibly remembered but less immediate;
- Informed/frontier is reachable/known without appearing explored;
- Shrouded/unknown is most concealed;
- distinctions work in grayscale and do not rely only on hue;
- current Cell and marker remain visually connected.

### 9.2 GPS trust

- one marker system represents both position and trust state;
- low-confidence/paused state remains distinguishable without introducing a second marker;
- the marker cannot disappear merely to express low confidence.

### 9.3 Conservation status

- IUCN/conservation status may retain a semantic color mapping;
- every status must also have readable text or semantics;
- conservation color must not become selection weight, progression, or rarity mechanics.

### 9.4 General state

Focus, success, warning, destructive, and error states may use the corresponding shadcn semantic roles. They must not recreate the retired EarthNova theme.

### 9.5 Open Map edge conflict

The reset must preserve current frontier-edge behavior until the conflict between approved discovery and later rendering decisions is resolved by the authority owner. The UI project may not use styling work to decide it implicitly.

---

## 10. Component Architecture

### 10.1 Root integration

The root composition must be:

```text
ShadApp.custom
└── MaterialApp
    └── ShadAppBuilder
        └── existing auth-selected home
```

Required behavior:

- dark neutral `ShadThemeData`;
- Material theme derived from the enclosing shad theme;
- Shad, Material, Widgets, and Cupertino localization delegates;
- existing scroll behavior;
- existing navigation observer;
- existing auth-selected `home`;
- existing debug-banner behavior.

### 10.2 Approved public components

The public design barrel should expose a neutral product vocabulary:

| Public component | Implementation | Responsibility |
|---|---|---|
| `AppButton` | `ShadButton` | Shared action geometry, semantics, loading/disabled state where needed |
| `AppBadge` | `ShadBadge` | Compact semantic label, never a new mechanic |
| `AppCard` | `ShadCard` | Neutral bounded content surface |
| `AppNotice` | `ShadAlert` composition | Info/success/warning/error messaging and announcement semantics |
| `AppFieldRow` | Neutral Flutter/shadcn composition | Label/value/action alignment |
| `AppStatGrid` | Neutral Flutter/shadcn composition | Responsive metrics without old card styling |
| `AppEmptyState` | Shared pattern | Empty explanation and optional action |
| `AppErrorState` | Shared pattern | Safe error and retry |
| `LoadingDots` | Custom neutral composition | Branded behavior removed; static reduced-motion equivalent retained |

### 10.3 Retired public styling API

The implementation plan should remove styling-era `Earth*` visual components and tones rather than keeping permanent aliases. Product action IDs, telemetry, semantics, and route behavior remain at the owning composition or use case.

### 10.4 Explicit native exceptions

`shadcn_ui` 0.56.2 does not provide every Flutter infrastructure primitive. The following may remain:

- `MaterialApp`;
- `Scaffold` and `AppBar` where required structurally;
- `Navigator` and `MaterialPageRoute`;
- `IndexedStack`, `PageView`, scroll views, slivers, layout, gestures, semantics, and focus primitives;
- `RefreshIndicator` where behaviorally required;
- MapLibre and Flutter Canvas/painters;
- native icons;
- custom neutral loading because no `ShadSkeleton` exists;
- custom two-destination navigation because no shadcn navigation component exists.

These exceptions may not preserve legacy styling.

---

## 11. Surface Requirements

### 11.1 Authentication

#### AUTH-1 Loading

- Display one neutral loading composition and concise status.
- No legacy wordmark treatment, emoji spinner, glow, or custom gradient.
- Reduced motion remains informative.

#### AUTH-2 Login

- Preserve phone formatting and validation.
- Use shadcn input/button/error patterns.
- Show focus, invalid, submitting, disabled, and server-error states without layout jump.
- Maintain keyboard-safe mobile layout.
- Announce validation and auth errors accessibly.

### 11.2 App Readiness

#### READY-1 Cold start

- Show required progress without exposing raw Map or incomplete Pack state.
- Preserve current gating and checkpoint behavior.

#### READY-2 Warm start

- Permit current snapshot hydration and background refresh behavior.
- Do not make a warm start appear blocked when current behavior releases it.

#### READY-3 Failure

- Preserve Retry and Sign out.
- Safe error copy only.
- Details may appear only under the existing delayed/detail rules.

#### READY-4 Degraded/syncing

- Keep usable context visible.
- Distinguish degraded refresh from total unavailability.
- Do not falsely claim every mutation is blocked if current behavior permits it.

### 11.3 Primary shell

#### NAV-1 Destinations

- Exactly Map and Pack.
- Settings remains its current separate route.
- No Sanctuary, Home, Town, or Settings tab is added.

#### NAV-2 State

- Preserve lazy materialization, `IndexedStack`, selected state, wake lock, edge swipe, and telemetry.
- Selected state must be indicated through more than color.

#### NAV-3 Responsive behavior

- Keep bottom navigation unless a separate IA decision changes it.
- Do not invent a desktop rail during this reset.

### 11.4 Map shell and overlays

#### MAP-UI-1 Edge-to-edge map

- MapLibre remains the dominant surface.
- Component chrome may not turn the Map into a dashboard-card page.

#### MAP-UI-2 Readiness cover

- No raw, fog-free, or semantically incomplete Map frame may flash before readiness.

#### MAP-UI-3 Status and errors

- Replace bespoke frosted/status styling with neutral shadcn surfaces.
- Preserve paused, location, fetch, and Map-unavailable behavior.

#### MAP-UI-4 Cell detail

- Use a neutral sheet presentation.
- Preserve disclosure by knowledge state.
- Preserve dismissal, continued-walking behavior, and Venue route behavior.

#### MAP-UI-5 Encounter and reward feedback

- Use neutral dialog/card/notice patterns.
- Preserve pending choices, resolve/retry, disabled state, generated reward plurality, and action evidence.
- Remove historical rarity/glow/loot-modal styling.

#### MAP-UI-6 Hierarchy

- Preserve Map ↔ District ↔ City ↔ State ↔ Country ↔ World routes and current behavior.
- Use State, never Province.
- Reset headers, stats, hints, and surfaces without changing progress calculations.

### 11.5 Pack

#### PACK-1 Grid and controls

- Preserve current search, filter, sort, category, grid, paging, and edge-swipe behavior.
- Replace emoji and legacy controls with neutral shadcn controls.
- Retain current responsive column behavior unless live code evidence requires a correction.

#### PACK-2 Item lifecycle

- Unidentified Items remain opaque according to current contracts.
- Examination and Identification remain separate.
- Loading/busy state prevents duplicate actions.

#### PACK-3 Empty and error

- Distinguish initial empty, filtered-zero, and fetch failure.
- Retry appears only where current behavior supports it.

### 11.6 Species Card

- Replace the TCG-style modal, glow, and rarity decoration with a neutral dialog/card composition.
- Preserve media fallback, examined/unexamined disclosure, conservation label, Identification action, dismissal, and route behavior.
- Focus must be contained and Escape must dismiss where current behavior permits.

### 11.7 Identification

- Preserve preparation, plan, confirmation/hold, commit, success, and failure states.
- Preserve exact disclosure and action evidence.
- Reset all visual treatment to neutral shadcn composition.

### 11.8 Town and Venue

- Preserve known-provenance disclosure.
- Preserve authored current names/roles/services and immutable first-known evidence.
- Preserve Venue marker and route behavior.
- Reset panels, badges, lists, empty/error states, and details.

### 11.9 Home

- Preserve read-only identity-only scope.
- Do not add Modules, placement, capacity, upgrades, Item storage, or progression.
- Reset the implemented surface without changing its product role.

### 11.10 Settings

- Preserve current execution-client and production-data facts.
- Preserve actions, warnings, and route behavior.
- Reset controls, grouping, notices, and destructive treatment.

### 11.11 Fallbacks and stubs

- Use the same neutral loading, empty, error, and retry patterns.
- Keep observable boundaries and retry delegation.
- Do not turn “Coming Soon” stubs into implied active features.

---

## 12. Functional Requirements

| ID | Requirement |
|---|---|
| FR-1 | `shadcn_ui` is pinned to 0.56.2; no second UI framework is introduced. |
| FR-2 | The root uses `ShadApp.custom` around the existing `MaterialApp`. |
| FR-3 | All reusable visual UI enters through the public shared design barrel. |
| FR-4 | In-scope feature code does not import internal design taxonomy paths. |
| FR-5 | Retired Carbon/EarthNova/mock styling is removed from reachable surfaces. |
| FR-6 | Existing routes, tab count, state ownership, and user actions remain unchanged. |
| FR-7 | Existing telemetry/action surfaces and stable identifiers remain intact. |
| FR-8 | MapLibre, painters, projection, marker ownership, and geometry remain technically intact. |
| FR-9 | Semantic map, GPS trust, conservation, focus, success, warning, and error distinctions remain understandable without color alone. |
| FR-10 | Loading, empty, error, degraded, disabled, and busy states exist for every surface that currently supports them. |
| FR-11 | Dialogs and sheets preserve dismissal, focus, and disclosure behavior. |
| FR-12 | No schema, data, RPC, persistence, or production deployment changes are part of the migration. |
| FR-13 | Debug-only UI is excluded from the visual reset unless it shares a player-facing component. |
| FR-14 | The design inventory, native contracts, registry, and public exports remain synchronized. |

---

## 13. Accessibility Requirements

| ID | Requirement |
|---|---|
| A11Y-1 | Interactive targets are at least 44×44 logical pixels. |
| A11Y-2 | Primary actions retain a comfortably accessible height even when package defaults are smaller. |
| A11Y-3 | Keyboard users can reach every interactive control in logical order. |
| A11Y-4 | Focus is always visible and not represented by color alone. |
| A11Y-5 | Dialogs/sheets manage focus and support Escape where dismissal is allowed. |
| A11Y-6 | Loading, errors, degraded state, rewards, and important updates use appropriate semantics/live announcements. |
| A11Y-7 | 200% text scaling does not clip, overlap, or hide required actions. |
| A11Y-8 | Reduced motion disables repeating/decorative animation and provides an informative static state. |
| A11Y-9 | Semantic map-state labels remain available from custom painters. |
| A11Y-10 | No state relies only on hue, icon, or animation. |

---

## 14. Responsive Requirements

### Required viewports

- **Mobile:** 390×844
- **Desktop:** 1440×900

### Supplemental breakpoint verification

- narrow phone near the supported minimum;
- tablet/intermediate width around the Pack/grid breakpoints;
- 200% text at mobile and desktop widths.

### Rules

- Map stays edge-to-edge.
- Bottom navigation remains usable and safe-area aware.
- Sheets remain bounded and dismissible.
- Dialogs do not exceed the viewport.
- Pack cards and controls reflow without horizontal clipping.
- Desktop does not merely stretch mobile content to full width.
- No new desktop IA is introduced.

---

## 15. Observability and Analytics Requirements

The reset must preserve, not redesign, instrumentation.

Required evidence includes:

- auth submit outcome;
- readiness start, checkpoints, usable, failure, degraded, and retry;
- tab selection;
- Map inspection and Cell detail;
- boundary/Visit result feedback;
- Encounter resolve/retry;
- Pack Examination;
- Species Card open/dismiss;
- Identification prepare/commit/outcome;
- Settings and destructive actions;
- screen lifecycle terminal states.

No visual component should emit duplicate actions because both wrapper and caller log the same interaction.

---

## 16. Migration Strategy

### Phase 0 — Contract and regression baseline

- Freeze current behavior with focused tests.
- Capture pre-reset screenshots for comparison of information and behavior—not styling.
- Record the allowed native infrastructure list.
- Add failure-first contract checks for the selected dependency and root integration.

### Phase 1 — Foundation

- Add package/localizations.
- Integrate `ShadApp.custom`.
- Replace root visual authority.
- Establish `App*` public components and neutral unsupported-component compositions.
- Update registry, contracts, and surface inventory.

### Phase 2 — Shell and entry

- Login/loading.
- App Readiness.
- Map/Pack shell.
- Settings route chrome.

### Phase 3 — Map component chrome

- HUD/status/errors.
- readiness cover;
- Cell sheet;
- Encounter layer;
- reward/feedback;
- hierarchy headers and hints.

### Phase 4 — Map semantic renderer calibration

- remove nonsemantic legacy colors;
- retain one marker and trust state;
- prove grayscale reveal relationships;
- retain organic geometry, counts, and boundary feedback;
- leave frontier-edge conflict unchanged.

### Phase 5 — Pack and knowledge

- Pack controls/grid/states;
- Species Card;
- Identification;
- Town/Venue;
- Home.

### Phase 6 — Fallbacks and clean cutover

- shared fallback/stub/loading;
- delete old visual constants and aliases;
- enforce import/inventory/contracts;
- remove stale comments and test expectations.

### Phase 7 — Rendered acceptance

- run focused and full validation;
- capture required viewports/states;
- inspect screenshots;
- fix visual/accessibility regressions;
- record final evidence before merge.

---

## 17. Test Strategy

### 17.1 Contract tests

Prove:

- exact dependency and root integration;
- public barrel usage;
- no internal taxonomy imports;
- registry/native-contract parity;
- complete surface inventory;
- no retired visual components or palette constants;
- explicit native exception allowlist.

### 17.2 Widget tests

Cover:

- state transitions;
- loading/disabled/error behavior;
- semantics;
- keyboard focus and action;
- dismissal;
- text scale;
- reduced motion;
- responsive reflow.

### 17.3 Behavior regression tests

No expected behavior changes for:

- auth;
- readiness;
- tab navigation;
- Map/Pack state retention;
- GPS trust;
- Visit/Encounter flow;
- Pack examination;
- Identification;
- Town/Venue/Home;
- Settings;
- telemetry.

### 17.4 Rendered QA

Widget tests are not visual acceptance. The final app must be rendered and inspected in the closest real browser/runtime environment.

Map acceptance must carry forward the objective R1 and R2 gates:

- In a mocked-geolocation fixture containing current, explored, and reachable-unvisited Cells, a reviewer must classify all three within 10 seconds, without tapping, logs, or code knowledge; the states must remain distinct in grayscale and the current Cell must connect visually to the single gameplay marker.
- At normal gameplay zoom, no representative fixture may be dominated by an axis-aligned square lattice; at least 90% of visible, non-clipped Cells must have exterior rings with more than four unique vertices.
- Adjacent Cell boundaries must meet without visible gaps or overlaps.
- QA evidence must name the geometry source/version and generation mode and must not call square envelopes Voronoi.

---

## 18. Rendered Acceptance Matrix

| Surface | Required states | Viewports |
|---|---|---|
| Login | idle, focused valid, invalid, submitting, auth error | mobile, desktop |
| Global loading | active, reduced motion, timeout/error if reachable | mobile, desktop |
| App Readiness | cold loading, warm hydration, failure, retry, degraded/syncing | mobile, desktop |
| Shell | Map selected, Pack selected, keyboard focus | mobile, desktop |
| Map bootstrap | readiness cover before usable Map | mobile, desktop |
| Map ready | Present Cell, Explored, Informed/frontier, Shrouded, one marker | mobile, desktop |
| Map hierarchy | representative District, City, State, Country, and World routes with headers, stats, and hints | mobile, desktop |
| Map paused/degraded | trust ring/paused state, retained context, safe notice | mobile, desktop |
| Map hard failure | permission denied, GPS unavailable, Map unavailable | mobile, desktop |
| Cell detail | each permitted disclosure state, Venue action where eligible | mobile, desktop |
| Encounter | pending choice, resolving, failed/retry, completed | mobile, desktop |
| Boundary feedback | first eligible crossing, revisit, queued/persistence failure | mobile |
| Pack populated | representative categories, search/filter/sort, page state | mobile, desktop |
| Pack transitional | initial loading, image fallback, examination busy | mobile, desktop |
| Pack empty/error | collection empty, filtered zero, fetch failure/retry | mobile, desktop |
| Species Card | unidentified-safe, examined, identified/conservation state | mobile, desktop |
| Identification | prepare, confirmation/hold, committing, success, failure | mobile, desktop |
| Town/Venue | empty, populated, detail, known provenance | mobile, desktop |
| Venue marker | map marker, eligible action, and Venue route transition | mobile, desktop |
| Home | identity-only populated state | mobile, desktop |
| Settings | normal, warning, destructive confirmation if present | mobile, desktop |
| Fallback | retryable error, nonretryable error, Coming Soon | mobile, desktop |
| Accessibility | 200% text, keyboard-only, reduced motion, grayscale review | mobile, desktop |

---

## 19. Map Discovery Coverage

| Requirement | PRD coverage |
|---|---|
| R1 — first-ten-second readability | Timed, no-tap observer classification against a mocked fixture; grayscale and marker-connection gates |
| R2 — organic geometry | Non-square visual gate, >4-vertex 90% threshold, gap/overlap inspection, and named geometry source/mode |
| R3 — one trusted marker | GPS trust exception and one-marker regression coverage |
| R4 — reveal/opacity fog | Grayscale-safe semantic relationships; no hue-only state |
| R5 — persistent footprint truth | Preserved state/data invariants and union/count behavior tests |
| R6 — boundary feedback | Boundary feedback states and first/revisit/failure QA |
| R7 — testable without walking | QA/operator JTBD, simulated location, deterministic fixtures |
| R8 — preserve history | No data/schema mutation; historical continuity check only under authorized environments |

### Current-environment qualification

Historical beta is archival. The migration must not mutate or redeploy it. Objective R1–R7 verification should run against deterministic fixtures and authorized local/prod evidence. Any read-only archival beta validation requires separate authorization.

---

## 20. Success Metrics

### Required binary metrics

- 100% of in-scope inventoried surfaces migrated.
- 0 reachable retired Carbon/EarthNova visual components.
- 0 feature imports of internal shared-design taxonomy paths.
- 0 analyzer warnings/errors.
- 100% passing focused and full Flutter tests.
- 100% of required acceptance screenshots captured and reviewed.
- 0 unapproved behavior, route, schema, data, telemetry, or environment changes.

### Qualitative bar

A reviewer should be able to move through every required state and perceive one neutral, coherent shadcn application. They should not need repository history to explain why two controls, cards, dialogs, notices, or pages look as if they belong to different systems.

---

## 21. Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Visual work changes behavior | High | Failure-first behavioral tests; isolate presentation from state/use cases |
| Root shad integration breaks Material/MapLibre | High | Use documented `ShadApp.custom` nesting; retain native Material infrastructure |
| Old styling survives through wrappers | High | Clean-cutover contracts and no styling aliases |
| Feature code bypasses shared design | Medium | Public-barrel import contract |
| Map becomes visually generic or unreadable | High | Preserve R1–R4 semantics and run deterministic grayscale QA |
| Package lacks a required primitive | Medium | Explicit native/custom neutral exceptions; no second framework |
| Accessibility regresses | High | Keyboard, semantics, 200% text, target-size, reduced-motion gates |
| Huge all-at-once diff is hard to review | High | Staged commits and surface waves on one Outcome Contract branch |
| Historical mock influences implementation | Medium | Mark it historical; current runtime and PRD win |
| Frontier-edge conflict is accidentally decided | Medium | Preserve current behavior and track the question separately |
| Current branch/runtime evidence changes before execution | Medium | Re-ground live code and package source when implementation is explicitly resumed |

---

## 22. Dependencies and Preconditions

Before implementation starts:

1. the user explicitly unpauses Issue #580;
2. the implementation branch is based on current `origin/main`;
3. `shadcn_ui` 0.56.2 source/API remains available and compatible with the pinned Flutter version;
4. current design-contract and behavior tests are green or documented as pre-existing failures;
5. current UI screenshots are captured as behavioral/information reference only;
6. the active surface inventory is checked against live code;
7. no production deployment is bundled with the UI PR.

---

## 23. Open Questions

These do not block PRD approval but must be handled as stated:

1. **Frontier-edge rendering:** preserve current behavior; resolve separately through authority.
2. **Neutral theme updates:** pin 0.56.2 and do not silently adopt future package visual changes during the cutover.
3. **Canonical but inactive surfaces:** they remain in scope because the user requested the entire implemented app; they do not gain new navigation.
4. **Light mode:** out of scope. A future request needs a separate product and QA contract.
5. **Historical beta verification:** out unless separately authorized read-only access is needed.

---

## 24. Go/No-Go Checklist

### Go only when

- [ ] User explicitly says to resume implementation.
- [ ] Issue #580 remains the approved Outcome Contract.
- [ ] Branch is based on current `origin/main`.
- [ ] Failure-first contracts exist.
- [ ] Native exception list is encoded.
- [ ] Surface inventory is current.

### Merge only when

- [ ] All in-scope surfaces are migrated.
- [ ] Retired visual systems are absent.
- [ ] Focused and full validation pass.
- [ ] Required screenshots are captured and inspected.
- [ ] R1–R8 remain satisfied.
- [ ] Accessibility acceptance passes.
- [ ] Telemetry/action evidence remains intact.
- [ ] No schema/data/gameplay/environment drift exists.
- [ ] `.agents/` current memory is updated from verified evidence.

### Deployment

- [ ] Not included. Production deployment requires separate explicit authorization.

---

## 25. Traceability

| Source | How this PRD uses it |
|---|---|
| GitHub Issue #580 | Outcome, pure-reset choice, pause state, semantic exceptions, non-goals |
| `.agents/constraints.md` | Shared-design boundary, state/data/quality/environment invariants |
| `.agents/architecture.md` | Current Flutter/Riverpod/Supabase and UI/domain flow evidence |
| `.agents/decisions.md` | Current shell/rendering/observability decisions and supersessions |
| `.agents/questions.md` | Frontier-edge and other deliberately unresolved rules |
| `.agents/discovery/2026-05-03-earthnova-map-domain-visual-requirements.md` | R1–R8 Map requirements |
| `.agents/mocks/2026-04-07-map-experience.md` | Historical screen and interaction evidence only; styling/IA rejected |
| `product/design/**` | Canonical implemented surface/action contracts to update during migration |
| `lib/shared/design/surface_inventory.dart` | Complete canonical surface closure |
| Current code/tests | Implementation and regression evidence at execution time |

---

## 26. Decision Summary

The approved product direction is:

- Flutter remains the client framework.
- `shadcn_ui` 0.56.2 becomes the visual substrate.
- Existing styling is removed, not adapted.
- The shared design architecture remains, with a neutral public component vocabulary.
- Native Flutter/MapLibre infrastructure remains where required.
- Meaning-bearing semantic visualization remains understandable.
- Product behavior, domain language, state, data, telemetry, and IA do not change.
- Phase 2 is complete; Phase 3+ implementation remains paused until the user explicitly authorizes it.
