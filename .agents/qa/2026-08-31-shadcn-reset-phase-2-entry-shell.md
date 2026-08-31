# Shadcn Reset Phase 2 Entry and Shell — Rendered QA

> **HISTORICAL-EVIDENCE** — Rendered evidence for the Phase 2 entry and shell migration on 2026-08-31. Current requirements remain in `docs/prd-shadcn-ui-reset.md`.

## Scope

- Source base: `a7d4bab1` plus the Phase 2 working changes for Issue #580.
- Release-mode Flutter web fixture using the actual Login, Loading, App Readiness, Tab Shell, and Settings widgets through the production `ShadApp.custom → MaterialApp → ShadAppBuilder` composition.
- Chromium viewports: 390×844 and 1440×900 at device scale 1.
- Deterministic local providers and placeholder Map/Pack content isolate the Phase 2 shell; no authentication, backend mutation, production deployment, or Phase 3 feature-screen migration occurred.

## Evidence

| Surface | Mobile | Desktop |
|---|---|---|
| Login, idle | [390×844](assets/shadcn-phase-2/entry/login-390x844.png) | [1440×900](assets/shadcn-phase-2/entry/login-1440x900.png) |
| Loading | [390×844](assets/shadcn-phase-2/entry/loading-390x844.png) | — |
| Readiness, hydrating with checkpoints | [390×844](assets/shadcn-phase-2/entry/readiness-hydrating-390x844.png) | — |
| Readiness, failed with actionable error | [390×844](assets/shadcn-phase-2/entry/readiness-failed-390x844.png) | — |
| Map shell selected | [390×844](assets/shadcn-phase-2/shell/shell-map-390x844.png) | [1440×900](assets/shadcn-phase-2/shell/shell-map-1440x900.png) |
| Pack shell selected | [390×844](assets/shadcn-phase-2/shell/shell-pack-390x844.png) | — |
| Settings | [390×844](assets/shadcn-phase-2/shell/settings-390x844.png) | [1440×900](assets/shadcn-phase-2/shell/settings-1440x900.png) |

![Login mobile](assets/shadcn-phase-2/entry/login-390x844.png)

![Login desktop](assets/shadcn-phase-2/entry/login-1440x900.png)

![Loading mobile](assets/shadcn-phase-2/entry/loading-390x844.png)

![Readiness hydrating mobile](assets/shadcn-phase-2/entry/readiness-hydrating-390x844.png)

![Readiness failed mobile](assets/shadcn-phase-2/entry/readiness-failed-390x844.png)

![Map shell mobile](assets/shadcn-phase-2/shell/shell-map-390x844.png)

![Pack shell mobile](assets/shadcn-phase-2/shell/shell-pack-390x844.png)

![Map shell desktop](assets/shadcn-phase-2/shell/shell-map-1440x900.png)

![Settings mobile](assets/shadcn-phase-2/shell/settings-390x844.png)

![Settings desktop](assets/shadcn-phase-2/shell/settings-1440x900.png)

## Findings

- All ten final PNGs have their named pixel dimensions at device scale 1. Full-resolution inspection found no clipping, overflow, render failure, or unreadable hierarchy.
- Login renders the neutral card, a 44px-minimum phone field, idle Continue action, compact reserved error space, and responsive centering at both viewports.
- Loading and readiness share the neutral entry grammar. The hydrating state exposes progress plus delayed checkpoint details; the failure state keeps the safe actionable error visible with primary Retry and secondary Sign out actions.
- The custom shell remains exactly Map and Pack at mobile and desktop widths. Each capture shows a persistent non-color selected indicator, Settings access, and no navigation rail.
- Pack selection was activated through the rendered Flutter semantics control before capture, proving the real shell interaction rather than a static approximation.
- Settings keeps the route app bar, one neutral card, conventional left-to-right labeled `ShadSwitch` rows, execution-environment copy, and a full-width destructive Sign Out action. The initial right-positioned switch-label composition was visually ambiguous; it was corrected and re-rendered.
- Independent accessibility review found and then cleared five regressions: switch labels/touch targets, readiness purge feedback, login large-text wrapping, validation wording, and live readiness progress announcements. Focused regression tests pass for each correction.

## Limits

- Map and Pack bodies are deterministic placeholders because their feature-screen migration belongs to Phase 3+. The captures accept only the Phase 2 shell chrome and selection behavior.
- Readiness states use deterministic local providers; persistence, telemetry, retry, purge, and sign-out behavior are covered by widget/notifier tests rather than external services in this visual fixture.
- These screenshots are local acceptance evidence, not deployment authorization. Phase 3+ and production deployment remain paused.
