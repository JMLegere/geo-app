# EarthNova — Project Status

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
| Tests passing | 934 |
| Analysis issues | 0 |
| Features | 13 modules |
| Species in dataset | 32,752 |

---

## What's Left for Production

### Must Have (Blocks Launch)

| # | Item | Effort | Notes |
|---|------|--------|-------|
| 1 | ~~Real GPS plugin~~ | ~~Medium~~ | **DONE** — Integrated `geolocator` (MIT, stream-based). `RealGpsService` with permission handling. Default mode: `realGps` on mobile, `keyboard` on web, `simulation` for tests. iOS Info.plist + Android manifest configured. |
| 2 | ~~Live Supabase backend~~ | ~~Medium~~ | **DONE** — `SupabaseAuthService` with anonymous sign-in, `SupabasePersistence` write-through, conditional init in `main.dart`. |
| 3 | ~~Map tile provider~~ | ~~Medium~~ | **DONE** — OpenFreeMap (`https://tiles.openfreemap.org/styles/positron`). Free, no API key, unlimited requests. Already configured in map_screen.dart. |
| 4 | ~~App icons + splash screen~~ | ~~Small~~ | **DONE** — `flutter_launcher_icons` + `flutter_native_splash` configured. Custom nature-themed icon, gradient splash with app name. |
| 5 | ~~Hardcoded coords → dynamic~~ | ~~Small~~ | **DONE** — All map constants (default lat/lon, Voronoi grid bounds) moved to `constants.dart`. Map uses `kDefaultMapLat/Lon`, `kVoronoiMin/Max` constants. |
| 6 | ~~Service injection cleanup~~ | ~~Medium~~ | **DONE** — 6 new providers created (`cellServiceProvider`, `fogResolverProvider`, `cameraControllerProvider`, `fogOverlayControllerProvider`, `discoveryServiceProvider`, `locationServiceProvider`). `map_screen.dart` refactored — no more `late final` service fields or manual lifecycle. |

### Should Have (Before Public Beta)

| # | Item | Effort | Notes |
|---|------|--------|-------|
| 7 | ~~Biome detection from real data~~ | ~~Medium~~ | **DONE** — Multi-habitat detection using `BiomeFeatureIndex` (509KB bundled asset with 10k+ coastline, 1.5k+ river, 90 lake, 750+ mountain, 39 desert, 39 wetland, 88 forest features). Cells return `Set<Habitat>` based on real-world features within 5km. Species pools unioned across all habitats. |
| 8 | ~~Onboarding flow~~ | ~~Medium~~ | **DONE** — 4-page onboarding (fog, species, sanctuary, get started) with smooth transitions, skip button, SharedPreferences persistence. |
| 9 | ~~App theming + polish~~ | ~~Medium~~ | **DONE** — Dark/light Material 3 themes, nature-inspired color palette, rarity-specific colors, habitat color palettes, consistent typography and spacing. |
| 10 | ~~Error handling + edge cases~~ | ~~Small~~ | **DONE** — `ErrorBoundary` widget, `EmptyStateWidget`, GPS permission banner, `LocationError` enum, graceful degradation throughout. |
| 11 | ~~Performance profiling~~ | ~~Small~~ | **DONE** — 17 benchmark tests in `test/performance/performance_test.dart` covering all critical paths with time budgets. Full 33k species dataset parses in <5s, index builds in <3s, per-cell lookups <5ms. BiomeFeatureIndex loads 509KB in <2s, spatial queries <5ms cold / <1ms cached. Voronoi neighbor map (1600 cells) builds in <2s. End-to-end discovery pipeline <50ms per cell entry. |

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
