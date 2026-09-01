# Shadcn Reset Phase 3 Map Chrome — Rendered QA

> **HISTORICAL-EVIDENCE** — Rendered acceptance evidence for PRD Phase 3 on 2026-08-31. Current requirements remain in `docs/prd-shadcn-ui-reset.md` and the approved Map visual requirements.

## Scope

- Source base: `2c7bb0e7` plus the Phase 3 working changes for Issue #580.
- Release-mode Flutter web fixtures rendered the actual `MapScreen`, `PendingEncounterLayer`, `CellDetailSheet`, hierarchy screens, and their changed neutral chrome through the production `ShadApp.custom → MaterialApp → ShadAppBuilder` composition.
- Deterministic local providers/entities isolate the required states without backend writes or production deployment.
- Chromium viewports are exact 390×844 and 1440×900 at device scale 1. Files ending in `-200pct` use `TextScaler.linear(2)`.

## Evidence

| Surface | Evidence |
|---|---|
| Map ready, mobile | [390×844](assets/shadcn-phase-3/map/map-ready-390x844.png) |
| Map ready, desktop | [1440×900](assets/shadcn-phase-3/map/map-ready-1440x900.png) |
| Map paused, 200% text | [390×844](assets/shadcn-phase-3/map/map-paused-390x844-200pct.png) |
| Retained-context Map error, 200% text | [390×844](assets/shadcn-phase-3/map/map-error-390x844-200pct.png) |
| Discovery reward modal | [390×844](assets/shadcn-phase-3/map/map-reward-390x844.png) |
| Pending Encounter ready | [390×844](assets/shadcn-phase-3/detail/encounter-ready-390x844.png) |
| Pending Encounter failed + degraded, 200% text | [390×844](assets/shadcn-phase-3/detail/encounter-failed-degraded-390x844-200pct.png) |
| Shrouded Cell sheet | [390×844](assets/shadcn-phase-3/detail/cell-shrouded-390x844.png) |
| Informed Cell sheet | [390×844](assets/shadcn-phase-3/detail/cell-informed-390x844.png) |
| Present Cell sheet with known Venue | [390×844](assets/shadcn-phase-3/detail/cell-present-390x844.png) |
| State hierarchy, mobile | [390×844](assets/shadcn-phase-3/hierarchy/hierarchy-state-390x844.png) |
| State hierarchy, 200% text | [390×844](assets/shadcn-phase-3/hierarchy/hierarchy-state-390x844-200pct.png) |
| State hierarchy, desktop | [1440×900](assets/shadcn-phase-3/hierarchy/hierarchy-state-1440x900.png) |
| World hierarchy, mobile | [390×844](assets/shadcn-phase-3/hierarchy/hierarchy-world-390x844.png) |

![Map ready mobile](assets/shadcn-phase-3/map/map-ready-390x844.png)

![Map paused at 200 percent text](assets/shadcn-phase-3/map/map-paused-390x844-200pct.png)

![Map error at 200 percent text](assets/shadcn-phase-3/map/map-error-390x844-200pct.png)

![Discovery reward modal](assets/shadcn-phase-3/map/map-reward-390x844.png)

![Pending Encounter ready](assets/shadcn-phase-3/detail/encounter-ready-390x844.png)

![Pending Encounter failed and degraded at 200 percent text](assets/shadcn-phase-3/detail/encounter-failed-degraded-390x844-200pct.png)

![Shrouded Cell sheet](assets/shadcn-phase-3/detail/cell-shrouded-390x844.png)

![Informed Cell sheet](assets/shadcn-phase-3/detail/cell-informed-390x844.png)

![Present Cell sheet](assets/shadcn-phase-3/detail/cell-present-390x844.png)

![State hierarchy mobile](assets/shadcn-phase-3/hierarchy/hierarchy-state-390x844.png)

![State hierarchy at 200 percent text](assets/shadcn-phase-3/hierarchy/hierarchy-state-390x844-200pct.png)

![World hierarchy mobile](assets/shadcn-phase-3/hierarchy/hierarchy-world-390x844.png)

## Findings and corrections

- All fourteen final PNGs have their named dimensions at device scale 1. Full-resolution inspection found no final Flutter error screen, clipping, Map notice/HUD/system-control overlap, unreadable retained-context notice, wrong player-facing Province terminology, or missing primary action in the normal-scale states.
- Initial rendered inspection exposed a reward-modal Semantics assertion (`scopesRoute` without explicit child nodes), transparent error/paused alerts over variable map content, and MapLibre info-control collisions at 200% text. The modal semantics, opaque surfaces, and measured 80px HUD control inset were corrected, regression-tested, rebuilt, and re-rendered before these final files were retained.
- Map ready keeps edge-to-edge dominance, neutral HUD and four-state legend, one trusted player marker, and the current semantic renderer baseline. Paused/error states keep retained map context while presenting fully opaque, readable, live status surfaces without legend collision.
- The discovery reward overlay is an actual modal surface with readable neutral card hierarchy, live reward announcement, autofocus, Escape/Return to Map parity, and no legacy glow, rarity pill, or gradient treatment.
- The Encounter ready card retains the authored option and Resolve action. At 200% text the failed/degraded fixture intentionally requires internal scrolling; the screenshot records the top state while focused widget coverage proves the long content can scroll to the reachable 44px `Sync required` action without overflow.
- Cell disclosure remained exact: Shrouded is generic only; Informed exposes one category and no exact Encounter/fauna/outcome/reward details; Present exposes visit/provenance context and the known Venue action. Both the explicit Open button and the prior title/summary row activation navigate after sheet dismissal.
- State hierarchy uses title-case `State`, `Explored`, and `Rank`, native semantic icons rather than emoji, active hierarchy map content, and 44px keyboard-focusable lower/upper scale controls. The actual 390×844 State screen remains contained at 200% text.

## Limits

- Deterministic fixtures use local map/provider data and a placeholder map host where only a standalone public overlay is under review. Persistence, telemetry, route, queue, keyboard, scroll, retry, and action payload behavior are covered by focused tests.
- Existing fog/cell/marker/hierarchy renderer colors and geometry are visible only as the preserved baseline. Their semantic calibration belongs to Phase 4 and was not changed or accepted by this Phase 3 evidence.
- No backend, schema, dependency, generated-data, or deployment surface was exercised. Phase 4+ and production deployment remain paused pending explicit authorization.
