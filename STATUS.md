# Fog of World — Project Status

Last updated: 2026-03-03

## What's Built

The full MVP game loop is implemented and tested. A player can:

1. **Authenticate** (mock auth — email/password, guest mode)
2. **See a map** (MapLibre GL with vector tiles)
3. **Move around** (GPS or simulated location)
4. **Reveal fog** (Civilization-style fog-of-war clears as you explore — 50 km detection radius)
5. **Discover species** (deterministic encounters seeded by cell ID from 32,752 real IUCN species)
6. **Build a collection** (journal with habitat/rarity/collection filters)
7. **Restore habitats** (3 unique species per cell = fully restored)
8. **Maintain a sanctuary** (species grouped by habitat, visit streaks tracked)
9. **Earn achievements** (toast notifications on milestones)
10. **Sync to cloud** (Supabase write-through when credentials configured, offline-only otherwise)

### By the Numbers

| Metric | Value |
|--------|-------|
| Dart source files | 189 (105 lib + 84 test) |
| Lines of code | ~30,000 |
| Tests passing | 910 |
| Analysis issues | 0 |
| Features | 13 modules |
| Species in dataset | 32,752 |

---

## What's Left for Production

### Must Have (Blocks Launch)

| # | Item | Effort | Notes |
|---|------|--------|-------|
| 1 | **Real GPS plugin** | Medium | Currently using `LocationSimulator`. Need `geolocator` or equivalent with permission handling for iOS + Android. `location_service.dart:53` has a TODO. |
| 2 | ~~Live Supabase backend~~ | ~~Medium~~ | **DONE** — `SupabaseAuthService` with anonymous sign-in, `SupabasePersistence` write-through, conditional init in `main.dart`. |
| 3 | **Map tile provider** | Medium | Need a real tile source (Mapbox, MapTiler, or self-hosted MBTiles). Currently renders whatever MapLibre's default provides. |
| 4 | **App icons + splash screen** | Small | Standard Flutter asset setup. |
| 5 | **Hardcoded coords → dynamic** | Small | `map_screen.dart` has SF coordinates and Voronoi grid bounds baked in. Need to derive from player's actual location. |
| 6 | **Service injection cleanup** | Medium | `map_screen.dart` instantiates services in `initState()` instead of via Riverpod providers. Other providers use `ref.read()` in `build()` where `ref.watch()` is correct. See Known Tech Debt in `AGENTS.md`. |

### Should Have (Before Public Beta)

| # | Item | Effort | Notes |
|---|------|--------|-------|
| 7 | **Biome detection from real data** | Medium | `BiomeService` maps ESA land cover codes to habitats, but needs a real data source (API or bundled dataset) for the player's actual location. |
| 8 | **Onboarding flow** | Medium | First-run tutorial explaining fog, species, and sanctuary. |
| 9 | **App theming + polish** | Medium | Current UI is functional Material 3. Needs visual identity, custom illustrations, habitat-specific color palettes. |
| 10 | **Error handling + edge cases** | Small | Network failures, GPS permission denial, empty states, low storage. |
| 11 | **Performance profiling** | Small | Test with full 33k species dataset on low-end devices. Fog overlay rendering at high cell counts. |

### Nice to Have (Post-Launch)

| # | Item | Effort | Notes |
|---|------|--------|-------|
| 12 | Camera/AI species identification | Large | Photo → species match |
| 13 | Multiplayer + social | Large | Leaderboards, trading, shared sanctuaries |
| 14 | Real-time sync | Medium | Replace manual "sync now" with live Supabase subscriptions |
| 15 | Push notifications | Small | Seasonal events, streak reminders |
| 16 | Fog edge particle effects | Small | Visual polish for v2 |
| 17 | Analytics + engagement | Medium | Player behavior tracking |

---

## Architecture Health

**Good shape.** The codebase is well-structured and thoroughly tested. Key strengths:

- **Offline-first** — SQLite is source of truth, sync is additive. Won't break if network is flaky.
- **Swappable backends** — Mock → real Supabase is a provider override, not a rewrite.
- **Deterministic game logic** — Species encounters are reproducible (SHA-256 seeded). Good for debugging and fairness.
- **910 tests** — High coverage across unit, widget, and integration layers.

**Known debt** is documented in `AGENTS.md` under "Known Tech Debt" — mostly `map_screen.dart` lifecycle management and a few provider anti-patterns. Nothing architectural.

---

## Repo Layout

```
AGENTS.md              # Agent guidance (architecture, patterns, constraints)
COMMITS.md             # Git commit convention and scope catalogue
STATUS.md              # This file
lib/core/              # Domain logic, models, persistence (has its own AGENTS.md)
lib/features/          # 13 feature modules
lib/features/map/      # Map rendering (has its own AGENTS.md)
lib/shared/            # Game-balance constants
test/                  # 84 test files mirroring lib/
assets/                # species_data.json (33k IUCN records)
```
