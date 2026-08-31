# Shadcn reset Phase 0 baseline

> **HISTORICAL-EVIDENCE:** These images record the pre-reset UI only as a behavior and information reference. They are not style acceptance, a visual target, or authorization to implement, migrate, restyle, deploy, or mutate data.

- Captured: 2026-08-31
- Source commit: `50d1fa714ce13a832e567e92cd9634a527984785`
- Capture path: local Flutter web previews rendered in Chromium; the login preview used the real app root and the existing local env file read-only as `--dart-define-from-file` input. No env values are recorded here.

## Logged-out Login

### 390 × 844

![Logged-out Login at 390 by 844](assets/shadcn-phase-0/login-390x844.png)

Visible information/actions: EarthNova; “Explore. Discover. Reveal.”; phone-number field showing “(555) 123-4567”; Continue action. Purpose: preserve the logged-out entry surface's information and action contract at the mobile viewport. Chromium inspection found no clipped text or controls.

### 1440 × 900

![Logged-out Login at 1440 by 900](assets/shadcn-phase-0/login-1440x900.png)

Visible information/actions: the same brand, tagline, phone-number field, and Continue action in the wider layout. Purpose: preserve the logged-out entry surface's information and action contract at the desktop viewport. Chromium inspection found no clipped text or controls.

## `DesignLibraryExample` catalog

The catalog was rendered through a temporary local-only fixture entrypoint; that fixture was removed after capture.

### 390 × 844

![DesignLibraryExample at 390 by 844](assets/shadcn-phase-0/design-library-390x844.png)

Visible information/actions: canonical/mobile-first tags, world icon, Design system heading, Usability contract notice, Map cell detail field row with surface tag, touch/source stats, and disabled Continue example. Purpose: inventory the current catalog's information hierarchy and represented component behavior at the mobile viewport. Chromium inspection found no clipping, overflow, or failed rendering.

### 1440 × 900

![DesignLibraryExample at 1440 by 900](assets/shadcn-phase-0/design-library-1440x900.png)

Visible information/actions: the same catalog heading, tags/icon, notice, field row, stats, and disabled Continue example in the wider layout. Purpose: inventory the current catalog's information hierarchy and represented component behavior at the desktop viewport. Chromium inspection found no clipping, overflow, or failed rendering.

## Limitations

- This unauthenticated capture intentionally excludes authenticated Map and Pack surfaces; no authentication or production action was performed.
- Static PNGs do not prove interaction, focus, hover, screen-reader, or dynamic-state behavior.
- Phase 7 still requires the full rendered acceptance matrix and human review after migration.
- These files record baseline evidence only and grant no implementation or deployment authorization.
