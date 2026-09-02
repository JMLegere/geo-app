> **Role: HISTORICAL-EVIDENCE.** This report records the 2026-09-01 Phase 5 acceptance run. Current behavior remains governed by `AGENTS.md`, `CONTEXT.md`, accepted ADRs, and live repository/runtime evidence.

# Shadcn UI reset — Phase 5 Pack and knowledge QA

**Date:** 2026-09-01  
**Scope:** Pack, Species Card, Identification Service, Town, Venue detail/marker, and identity-only Home.  
**Outcome Contract:** `docs/prd-shadcn-ui-reset.md` Phase 5 and acceptance matrix.  
**Issue:** #580  
**Deployment:** Not authorized.

## Preserved behavior

- Pack keeps category/search/filter/sort, 3/4/6-column breakpoints, pagination, edge navigation, loading, fallback, initial-empty, filtered-zero, and error/retry behavior.
- Species Card keeps safe unexamined, examined/unidentified, and identified disclosure; exact current Item identity; native labeled media fallback; Identification handoff; and text-backed conservation meaning.
- Identification keeps prepare, start, hold-to-reveal, commit, success, failure, exact Item checks, and action telemetry.
- Town and Venue keep known-provenance disclosure, introduced Villagers, current Services, safe empty states, marker routes, and no speculative Visit trigger.
- Home is identity-only; the speculative Modules panel is absent.
- No routes, tabs, providers, domain entities, persistence, schema, dependencies, backend behavior, or deployment changed.

## Rendered acceptance matrix

| Surface/state | Viewport | Evidence |
|---|---:|---|
| Pack populated | 390×844 | `assets/shadcn-phase-5/pack/populated-390x844.png` |
| Pack populated | 1440×900 | `assets/shadcn-phase-5/pack/populated-1440x900.png` |
| Pack initial empty | 390×844 | `assets/shadcn-phase-5/pack/initial-empty-390x844.png` |
| Pack filtered zero | 390×844 | `assets/shadcn-phase-5/pack/filtered-zero-390x844.png` |
| Pack error/retry | 390×844 | `assets/shadcn-phase-5/pack/error-retry-390x844.png` |
| Species unexamined | 390×844 | `assets/shadcn-phase-5/species/unexamined-390x844.png` |
| Species examined/unidentified | 390×844 | `assets/shadcn-phase-5/species/examined-unidentified-390x844.png` |
| Species identified | 390×844 | `assets/shadcn-phase-5/species/identified-390x844.png` |
| Identification prepared | 390×844 | `assets/shadcn-phase-5/identification/mobile-prepared.png` |
| Identification hold | 390×844 | `assets/shadcn-phase-5/identification/mobile-start-hold.png` |
| Identification committing | 390×844 | `assets/shadcn-phase-5/identification/mobile-committing.png` |
| Identification success | 390×844 | `assets/shadcn-phase-5/identification/mobile-identified-success.png` |
| Identification failure | 390×844 | `assets/shadcn-phase-5/identification/mobile-preparation-failure.png` |
| Identification prepared | 1440×900 | `assets/shadcn-phase-5/identification/desktop-prepared.png` |
| Identification 200% text/reduced motion | 390×844 | `assets/shadcn-phase-5/identification/mobile-prepared-text-200-reduced-motion.png` |
| Town populated | 390×844 | `assets/shadcn-phase-5/places/town-populated-390x844.png` |
| Town populated | 1440×900 | `assets/shadcn-phase-5/places/town-populated-1440x900.png` |
| Town empty | 390×844 | `assets/shadcn-phase-5/places/town-empty-390x844.png` |
| Town error/retry | 390×844 | `assets/shadcn-phase-5/places/town-error-retry-390x844.png` |
| Venue detail | 390×844 | `assets/shadcn-phase-5/places/venue-detail-introduced-390x844.png` |
| Venue detail | 1440×900 | `assets/shadcn-phase-5/places/venue-detail-introduced-1440x900.png` |
| Home identity | 390×844 | `assets/shadcn-phase-5/home/home-identity-390x844.png` |
| Home identity | 1440×900 | `assets/shadcn-phase-5/home/home-identity-1440x900.png` |
| Home error/retry | 390×844 | `assets/shadcn-phase-5/home/home-error-retry-390x844.png` |

All 24 files were validated as non-empty PNGs at their exact dimensions. Captures use the production dark-zinc Shad/Material theme, Geist text, the bundled Material Icons font, DPR 1, and disabled animations.

## Visual and accessibility review

**PASS.** Final image inspection confirmed:

- Pack shows all seven category controls without clipping, 3 mobile and 6 desktop columns, recognizable category icons, and distinct initial-empty, filtered-zero, and error states.
- Species states remain visibly distinct with passive safe disclosure, a labeled native media fallback, Examination-versus-Identification copy, player-facing Map provenance, and text-backed IUCN meaning.
- Identification prepared, hold, committing, success, failure, desktop, and 200%-text states are distinct, readable, and unclipped.
- Town/Venue/Home use readable production-dark contrast, correct singular grammar, current-context copy, first-known evidence without raw IDs, no Venue Visit CTA, and no Home Modules panel.
- No captured surface shows TCG framing, rarity mechanics, glow/foil treatment, emoji fallback controls, hue-only status meaning, overlap, or unintended overflow.

Static PNGs do not prove runtime hitboxes, focus traversal, gesture behavior, or motion execution; focused widget/contract tests cover those behaviors.

## Verification

- Phase 5 focused behavior/contract suite: **90 passed**.
- `flutter analyze`: **passed**.
- Full `flutter test --concurrency=1 --reporter compact`: **1,579 passed, 36 opt-in tests skipped**.
- `npm run eac:check`: **passed**, no diagnostics.
- `flutter test test/documentation/authority_contract_test.dart`: **3 passed**.
- Default visual fixture suite: **2 passed, 24 opt-in capture cases skipped**.
- `git diff --check`: **passed**.

The opt-in capture tests write valid PNGs and then linger during Flutter test finalization in this environment. Each capture was therefore run as a bounded single named case; exit 124 was accepted only after validating the newly written PNG header, dimensions, and non-zero bytes. Default CI execution skips those capture cases and passes normally.
