# Shadcn Reset Phase 1 Foundation — Rendered QA

> **HISTORICAL-EVIDENCE** — Rendered evidence for the Phase 1 foundation on 2026-08-31. Current requirements remain in `docs/prd-shadcn-ui-reset.md`.

## Scope

- Source base: `2dd1167` plus the Phase 1 working changes for Issue #580.
- Real logged-out app root and local-only `DesignLibraryExample` fixture.
- Chromium viewports: 390×844 and 1440×900 at device scale 1.
- No authentication, backend mutation, production deployment, or Phase 2 surface migration.

## Evidence

| Surface | Mobile | Desktop |
|---|---|---|
| Login through the real `ShadApp.custom` root | [390×844](assets/shadcn-phase-1/login-390x844.png) | [1440×900](assets/shadcn-phase-1/login-1440x900.png) |
| Canonical App component catalog | [390×844](assets/shadcn-phase-1/design-library-390x844.png) | [1440×900](assets/shadcn-phase-1/design-library-1440x900.png) |

![Login mobile](assets/shadcn-phase-1/login-390x844.png)

![Login desktop](assets/shadcn-phase-1/login-1440x900.png)

![Design library mobile](assets/shadcn-phase-1/design-library-390x844.png)

![Design library desktop](assets/shadcn-phase-1/design-library-1440x900.png)

## Findings

- Login preserves the Phase 0 information and action set: EarthNova identity, exploration tagline, phone input, and disabled Continue action. Nothing clips or overlaps at either viewport.
- Login still visibly carries its legacy dark-blue screen styling, which masks much of the neutral root theme. That screen-level reset belongs to the separately authorized Phase 2 wave.
- The catalog renders the canonical neutral-zinc hierarchy with AppCard, AppBadge, AppNotice, AppFieldRow, AppStatGrid, AppEmptyState, AppErrorState, LoadingDots, and AppButton.
- The stat grid stacks to one column at 390px and uses two columns at 1440px. Text wraps inside its bounds, controls remain within the viewport, and the 44px action contract is independently covered by widget tests.
- The first catalog render exposed child/footer clipping from using one tall outer ShadCard. The catalog was split into discrete component sections and re-rendered; final mobile and desktop captures have no component overlap or non-viewport clipping.
- Neutral primary text has strong visible contrast; muted copy and subtle borders remain readable. Exact WCAG ratios are enforced later per the PRD acceptance matrix.
- Companion widget evidence verifies one owned button semantics label, keyboard focus/Enter activation, disabled loading behavior, and the static reduced-motion LoadingDots fallback.

## Limits

- Authenticated readiness, Map, Pack, and secondary routes were not captured because Phase 1 does not migrate those surfaces.
- The mobile catalog image is the initial scroll viewport; the error state continues normally below the fold.
- Phase 2 and later remain paused. These screenshots are comparison evidence, not approval to preserve legacy styling.
