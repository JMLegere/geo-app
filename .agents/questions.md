# Open Questions

**Role: CURRENT-SCOPED.** This registry contains only deliberately open product, architecture, implementation, or operational decisions. `CONTEXT.md` and accepted `docs/adr/` govern anything already resolved.

## Product and Domain Gates

### Encounter authoring

- **Encounter rates and weights:** What production Selector weights should control explicit None versus each eligible Encounter Definition?
- **Additional Outcome kinds:** Which typed Outcome kinds, beyond Generate Item and Reveal Venue, should enter the closed set?
- **Concrete Condition leaves:** Which first leaf predicates are approved beyond the compatibility rules needed to preserve current behavior?
- **Condition precedence:** If owning content, Options, and Selector candidates all have Conditions, what evaluation/diagnostic precedence should the player and authoring tools expose?

### Item knowledge and progression

- **Discipline tuning:** What XP amount does each completed automatic or explicit Identification grant, and what thresholds derive each visible numeric Level?
- **Orb behavior:** What, if anything, may an Orb do? Currency, crafting, stacking, production, and consumption remain intentionally unassigned.

### Living world and Home

- **Venue Visit trigger:** What exact physical event creates a Venue Visit: entering the Venue's Cell, satisfying a proximity boundary, or an explicit check-in while eligible?
- **Home Module behavior:** What Module kinds, limits, installation rules, and lifecycle are approved?

### Architecture

- **Final bounded-context map:** After the first vertical slices expose real coupling, which module boundaries should become durable context boundaries?

### Map acceptance follow-ups

- **Beyond-radius presentation:** Should Cells outside the fetch/render radius be absent, fully hidden, or represented by a softened edge fade?
- **Qualitative visual bar:** What repeatable screenshot rubric distinguishes a sufficiently magical map from a debug artifact after the objective R1–R8 checks pass?

## Operational Gates

- **Production migration secret:** Verify whether `SUPABASE_PRODUCTION_DB_PASSWORD` is configured before any production migration workflow is approved.
- **Production API compatibility:** A production-connected Desktop Mode smoke on 2026-08-18 received HTTP 404 for `fetch_v3_pack_items` and `fetch_v3_player_cell_states`; `fetch_nearby_cells` and the Cell Visit query returned HTTP 200. Apply the pending production migrations through the human-authorized `deploy-prod.yml` path before treating production App Readiness as operational.
- **Legacy Railway beta service cleanup:** Re-verify the unused sibling service and available deletion permissions before requesting manual removal.

## Resolved or Superseded Questions

Resolved items are retained in `.agents/decisions.md`, dated `.agents/context.md`, and historical design/QA artifacts rather than duplicated here.
- The `main` auto-deploy ambiguity is resolved by ADR 0011 and the Issue #592 amendment: successful push-triggered `main` CI deploys its exact SHA automatically; manual exact-SHA dispatch remains for rollback and recovery. Beta remains retired.

- Cell entry creates **zero or one** Encounter through one Selector; the old three-slot question is superseded by `CONTEXT.md`.
- Identification resolves Version-owned Variable Properties into permanent Item Property Values; the old generic stat/affix model is superseded.
- Identification persistence must be explicit and atomic with its Property Values, first Discovery, and Discipline XP event; fire-and-forget is rejected.
- EarthNova uses **State**, not Province.
- Sanctuary, breeding, museum bundles, Orb crafting, and release-reward assumptions are not active rules merely because old plans mentioned them.
