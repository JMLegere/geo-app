# E2E Production Proof Report

**Date:** 2026-03-09
**Environment:** Railway production (`geo-app-production-47b0.up.railway.app`)
**Supabase project:** `bfaczcsrpfcbijoaeckb`
**Branch at test time:** `main` (commit `e9181ea`, PR #63 squash-merged)
**Build version:** v2026-03-09-0250

---

## Summary

Full end-to-end production test of the EarthNova web app deployed on Railway with Supabase backend. Two test sessions conducted (Session 1: PR #63 verification, Session 2: comprehensive E2E). All core systems verified working: map rendering, fog-of-war, GPS simulation, species discovery, AI enrichment pipeline, 4-tab navigation, auth flows (sign out, re-login, page refresh), and network health.

**Verdict: PASS** — All Phase 1–4 systems operational in production. Zero failed network requests. Zero console errors.

---

## Test Results Summary

| Test | Status | Key Finding |
|------|--------|-------------|
| 1. Fresh load — map render | ✅ PASS | Map renders on first visit, fog init in ~1112ms |
| 2. Login flow (guest) | ✅ PASS | "Continue as Guest" creates new anonymous session via Supabase |
| 3. Console errors | ✅ PASS | 0 errors across entire session; 5–9 warnings (all benign) |
| 4. Tab navigation (all 4 tabs) | ✅ PASS | Map, Home/Sanctuary, Town, Pack all render correctly |
| 5. Logout → Login cycle | ✅ PASS | Sign out resets progress (by design), shows login screen, guest re-entry works |
| 6. Page refresh | ✅ PASS | Session persists across F5, map re-renders, no blank screen |
| 7. Network requests | ✅ PASS | 69 requests, ALL 200/204, zero failures |

---

## Systems Verified

### 1. Web Build & Deployment ✅

- Flutter web build compiles and serves via Railway
- App boots to Home (Sanctuary) screen on initial load
- After sign-out → re-login, boots to Sanctuary
- Title: "EarthNova"
- Version badge: v2026-03-09-0250

### 2. Supabase Authentication ✅

- Anonymous sign-in succeeds automatically on app start
- Console: `[GameCoordinator] auth identity changed: null → <user-id>`
- User shown as "Explorer / Guest account" in Settings
- Sign Out button shows destructive-action confirmation dialog
- After sign out, app shows login screen with phone number input + "Continue as Guest"
- Supabase auth endpoints confirmed: token refresh, logout (204), signup all succeed

### 3. Map Rendering & Fog-of-War ✅

- MapLibre map renders with Voronoi cell grid overlay
- Fog-of-war covers unexplored cells (dark)
- Visited cells reveal underlying map tiles
- Player position dot (blue circle) visible on map
- HUD shows cell count and streak days
- D-pad navigation controls + zoom/recenter buttons visible
- Fog initialization: 3 sources + 3 layers in ~1112–1275ms
- Map renders immediately on page load — no extra refresh needed

### 4. GPS Simulation & Movement ✅

- Simulated GPS at (45.9636, -66.6431) — Fredericton, NB area
- RubberBand interpolation active at ~60fps tick rate
- Camera follows player position

### 5. Species Discovery & Enrichment ✅

- Species discovered on cell entry (deterministic from daily seed)
- Daily seed fetched via RPC: `ensure_daily_seed` → 200 OK
- First species: *Smilisca baudinii* (Saltwater, LC)
- AI enrichment pipeline fires via Edge Function: `enrich-species` → 200 OK
- Enrichment result: `enriched fauna_smilisca_baudinii`

### 6. Tab Navigation ✅

| Tab | Status | Content |
|-----|--------|---------|
| Map | ✅ | Fog overlay, Voronoi cells, player dot, HUD, controls |
| Home (Sanctuary) | ✅ | Sanctuary progress (0%), streak, species count, 7 habitat sections |
| Town | ✅ | "Coming Soon" placeholder with NPC teaser |
| Pack | ✅ | Collection viewer (lands on this tab by default on first load) |

### 7. Sign Out → Login Cycle ✅

**Test flow:**

| Step | Action | Result |
|------|--------|--------|
| 1 | Pre-test state | 1/30669 species, Day 1 streak, 1 Forest fauna |
| 2 | Settings → Sign Out | Confirmation: "You will lose all progress. This cannot be undone." |
| 3 | "Sign Out Anyway" | Dialog dismissed, app navigates to login screen |
| 4 | Login screen visible | Phone input (+1), disabled Continue, "Continue as Guest" button |
| 5 | Click "Continue as Guest" | New anonymous session created, Sanctuary shows empty state |
| 6 | Post-login state | 0/30669 species, "Start your streak!", empty sanctuary |

**Key findings:**
- ✅ Sign out properly shows destructive-action confirmation
- ✅ After sign out, app navigates to login/welcome screen (not stuck on settings)
- ✅ "Continue as Guest" creates fresh session with new UUID
- ✅ Progress correctly reset — new user has clean state
- ✅ Console: `[GameCoordinator] auth identity changed` — proper identity handoff
- ✅ 0 console errors during entire logout→login flow

### 8. Page Refresh (Session Persistence) ✅

**Test:** Full F5 page reload while on Map tab.

**Result:**
- Map rendered immediately after refresh (no blank screen, no extra reload needed)
- Session persisted — guest account maintained through browser refresh
- Cell exploration state preserved (1 cell visible)
- All UI elements rendered correctly
- Fog init completed in 1275ms post-refresh
- 0 console errors

### 9. Network Requests ✅

**69 total requests — ALL succeeded (200/204).**

| Category | Count | Status |
|----------|-------|--------|
| Flutter assets (canvaskit, fonts, species_data.json, biome_features.json, sqlite3.wasm) | ~20 | All 200 |
| Supabase Auth (token refresh, logout, signup) | 3 | 200/204 |
| Supabase Data (profiles, cell_progress, item_instances, species_enrichment) | 4 | All 200 |
| Supabase RPC (ensure_daily_seed ×2) | 2 | All 200 |
| Supabase Edge Function (enrich-species) | 1 | 200 |
| Map tiles (openfreemap.org) | ~30 | All 200 |
| Google Fonts (Roboto, Noto Color Emoji) | ~10 | All 200 |

**Zero failed requests. Zero 4xx/5xx responses.**

---

## Console Health

| Metric | Value |
|--------|-------|
| Errors | **0** (across entire test session) |
| Warnings | **5–9** (all pre-existing, non-critical) |

### Warnings (pre-existing, non-critical):
1. `Expected value to be of type number, but found null instead` × 4 — MapLibre blob (style rendering)
2. `Could not find a set of Noto fonts to display all missing characters` × 1 — Flutter font fallback

---

## Test Environment

- **Browser:** Chromium (Playwright MCP)
- **Viewport:** 1260×1083
- **Test runner:** Playwright MCP (manual orchestration by Sisyphus agent)
- **Accessibility:** Enabled mid-session for button interaction (Flutter canvas → semantics tree)
- **Total tests:** 9 scenarios
- **All passed**
