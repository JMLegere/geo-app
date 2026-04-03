# Bootstrap & Initialization Documentation Index

**Generated:** 2026-04-02  
**Total Documentation:** 65KB across 3 files  
**Scope:** Complete app initialization from `main()` to first interactive frame

---

## Document Overview

### 1. **BOOTSTRAP_QUICK_REFERENCE.md** (12KB)
**Start here.** Condensed checklist and reference guide.

**Contains:**
- TL;DR (3 phases, ~3-5 seconds)
- Key files (5 critical files)
- Initialization checklist (5 phases)
- Loading screen gates (4 gates)
- Eager vs lazy initialization
- Critical races & prevention
- Hydration order (12 steps)
- Error recovery matrix
- Startup beacons
- Performance targets
- Debugging checklist
- Key invariants & guarantees
- Callback wiring summary
- Navigation structure
- One-liner summary

**Best for:** Quick lookup, debugging, understanding the big picture.

---

### 2. **BOOTSTRAP_SEQUENCE_DIAGRAM.md** (24KB)
**Visual learner?** Detailed ASCII diagrams and timelines.

**Contains:**
- Timeline: main() → Interactive Map (with timestamps)
- Parallel initialization streams (5 concurrent streams)
- Loading screen gate logic (decision tree)
- Hydration sequence (detailed tree)
- Provider initialization order (9 steps)
- Error recovery paths (3 branches)
- Callback wiring diagram (6 callbacks)
- State mutation timeline (15 state changes)
- Critical path analysis (ideal vs typical vs worst case)

**Best for:** Understanding flow, visualizing dependencies, tracing execution.

---

### 3. **BOOTSTRAP_INITIALIZATION_REPORT.md** (29KB)
**Deep dive.** Comprehensive technical reference.

**Contains:**
- 13 major sections:
  1. Initialization Timeline (8 phases, 0-3000ms)
  2. Eager vs Lazy Initialization (11 eager, 8 lazy)
  3. Provider Dependency Graph (visual + rules)
  4. Hydration Sequence (detailed, 4a-4c)
  5. Race Conditions & Ordering Dependencies (5 races, 8 dependencies)
  6. Loading Screen Gates (3 gates, 4 gates, timeout fallback)
  7. Error Boundaries & Fallback Behavior (3 sections)
  8. Navigation Structure (3 levels)
  9. Startup Beacons (11 checkpoints)
  10. Performance Characteristics (timeline + memory)
  11. Key Invariants & Guarantees (7 invariants, 5 guarantees)
  12. Debugging Checklist (11 items)
  13. Summary (3 phases, design principles, critical path)

**Best for:** Understanding internals, debugging complex issues, architectural decisions.

---

## How to Use These Documents

### Scenario 1: "The app is stuck on the loading screen"
1. Read **BOOTSTRAP_QUICK_REFERENCE.md** → Debugging Checklist
2. Check which gate is not settling (hydrated, zone, located, permission)
3. Read **BOOTSTRAP_INITIALIZATION_REPORT.md** → Section 6 (Loading Screen Gates)
4. Trace the specific gate in **BOOTSTRAP_SEQUENCE_DIAGRAM.md** → Parallel Streams

### Scenario 2: "I need to understand the startup flow"
1. Start with **BOOTSTRAP_QUICK_REFERENCE.md** → TL;DR
2. Read **BOOTSTRAP_SEQUENCE_DIAGRAM.md** → Timeline
3. Deep dive into **BOOTSTRAP_INITIALIZATION_REPORT.md** → Section 1 (Initialization Timeline)

### Scenario 3: "A discovery is being lost during startup"
1. Read **BOOTSTRAP_QUICK_REFERENCE.md** → Critical Races & Prevention
2. Check **BOOTSTRAP_INITIALIZATION_REPORT.md** → Section 5a (Critical Races)
3. Trace hydration order in **BOOTSTRAP_SEQUENCE_DIAGRAM.md** → Hydration Sequence

### Scenario 4: "I'm adding a new provider, where does it fit?"
1. Read **BOOTSTRAP_QUICK_REFERENCE.md** → Eager vs Lazy Initialization
2. Check **BOOTSTRAP_SEQUENCE_DIAGRAM.md** → Provider Initialization Order
3. Review **BOOTSTRAP_INITIALIZATION_REPORT.md** → Section 3 (Provider Dependency Graph)

### Scenario 5: "Performance is slow, where's the bottleneck?"
1. Read **BOOTSTRAP_QUICK_REFERENCE.md** → Performance Targets
2. Check **BOOTSTRAP_SEQUENCE_DIAGRAM.md** → Critical Path Analysis
3. Review **BOOTSTRAP_INITIALIZATION_REPORT.md** → Section 10 (Performance Characteristics)

---

## Key Concepts

### Three Phases
1. **Pre-Flutter (0-700ms):** Supabase init, auth service, error handlers
2. **Widget Tree (700-1000ms):** EarthNovaApp mounts, gameCoordinatorProvider eagerly initialized
3. **Hydration & Game Loop (1000-3000ms):** SQLite loads, game loop runs, loading gates settle

### Four Loading Screen Gates
```
allReady = playerState.isHydrated 
        && zoneReadyProvider 
        && playerLocatedProvider 
        && gpsPermissionState != unknown
```

### Critical Path
```
Auth settles → Hydration → Game loop → Zone resolves → GPS converges → Map visible
```

### Typical Timeline
- **Ideal:** ~1300ms (cached session, small inventory, fast GPS)
- **Typical:** ~3000-5000ms (network-dependent)
- **Worst case:** ~15000ms (timeout fallback)

---

## File References

### Core Files
- `lib/main.dart` (554 lines) — Entry point, error handlers, routing
- `lib/core/state/game_coordinator_provider.dart` (1384 lines) — Central orchestrator
- `lib/core/state/player_provider.dart` (172 lines) — Player state, hydration
- `lib/features/auth/providers/auth_provider.dart` (136 lines) — Auth state
- `lib/shared/widgets/tab_shell.dart` (338 lines) — Navigation shell

### Related Documentation
- `AGENTS.md` (root) — Design decisions, forbidden patterns
- `lib/core/AGENTS.md` — Core subsystem patterns
- `lib/core/state/` — 29 provider files
- `lib/features/auth/` — Auth flow
- `lib/features/onboarding/` — First-run flow

---

## Startup Beacons (Observability Checkpoints)

```
supabase_init
  ↓
session_restore
  ↓
session_restore_done
  ↓
provider_init
  ↓
hydration_start
  ↓
hydration_complete
  ↓
run_app
  ↓
resolve_home
  ↓
loading_dismissed
```

---

## Critical Ordering Dependencies

1. **`loadItems()` before `startLoop()`** — Replaces inventory state
2. **`markHydrated()` after all data loads** — Gates loading screen
3. **`lastPersistedProfile` capture after mutations** — Guards write-through listener
4. **`coordinator.start()` after `coordinator.subscribe()`** — Keyboard mode emits sync
5. **`locationService.start()` after `coordinator.start()`** — Coordinator must be ready
6. **Biome data load before zone resolution** — Cells need real habitats
7. **Species cache warmUp before discoveries** — Cache miss = 0 species

---

## Error Recovery Paths

| Failure | Behavior |
|---------|----------|
| Supabase not configured | Use MockAuthService, offline-only |
| Session restore fails | Show LoginScreen |
| SQLite hydration fails | Start loop with empty state |
| Supabase hydration fails | Continue with SQLite-only data |
| Database corruption (web) | Wipe databases, reload page |
| Zone resolution timeout (15s) | Dismiss loading screen anyway |
| GPS permission denied | Show map, no tracking |
| Biome data load fails | Use {plains} fallback, re-resolve later |

---

## Performance Targets

| Phase | Duration | Bottleneck |
|-------|----------|-----------|
| Pre-Flutter | ~50ms | Image cache config |
| Auth service | ~50ms | Supabase init |
| Session restore | ~100-500ms | Network |
| Widget tree | ~300ms | Build |
| Game coordinator | ~500ms | Infrastructure |
| SQLite hydration | ~200-500ms | Database |
| **Loading screen visible** | ~1000-2000ms | Waiting for gates |
| Zone resolution | ~3-8s | Nominatim API |
| Rubber-band convergence | ~5-10s | GPS accuracy |
| **Map interactive** | ~3000-5000ms | All gates settled |
| Supabase hydration (bg) | ~500-2000ms | Network |

---

## Debugging Checklist

When startup hangs or crashes:

- [ ] Check `StartupBeacon` logs — which phase failed?
- [ ] Check `DebugLogBuffer` — any errors?
- [ ] Check `app_logs` table (Supabase) — observability events?
- [ ] Check `app_events` table (Supabase) — structured events?
- [ ] Is Supabase configured? (`SUPABASE_URL` + `SUPABASE_ANON_KEY`)
- [ ] Is session restore hanging? (Check network tab)
- [ ] Is SQLite hydration hanging? (Check database size)
- [ ] Is zone resolution hanging? (Check Nominatim API)
- [ ] Is GPS permission dialog blocking? (Check device settings)
- [ ] Is the 15s timeout being hit? (Check logs for "zone_ready_timeout")
- [ ] Is there a database corruption error? (Check for FormatException)

---

## Key Invariants

1. **Auth state is always settled** — Never `loading` after first frame
2. **Hydration is idempotent** — Can be called multiple times safely
3. **Game loop never starts before hydration** — Prevents race with discoveries
4. **Fog state is computed, never stored** — Only `visitedCellIds` persisted
5. **Species encounters are deterministic** — Same seed + cell = same species
6. **Write queue is durable** — Entries survive app restart
7. **Supabase is source of truth** — SQLite is cache + offline queue

---

## Key Guarantees

1. **User data is never lost** — Write queue persists until server confirms
2. **Discoveries are server-validated** — Offline rolls are re-derived on reconnect
3. **Onboarding is shown exactly once** — Flag persisted, never reset except on sign-out
4. **Loading screen dismisses within 15s** — Timeout fallback prevents infinite loading
5. **Map is always responsive** — Gestures work immediately after loading screen fades

---

## Quick Links

### By Role

**Product Manager:**
- BOOTSTRAP_QUICK_REFERENCE.md → Performance Targets
- BOOTSTRAP_SEQUENCE_DIAGRAM.md → Critical Path Analysis

**Frontend Engineer:**
- BOOTSTRAP_QUICK_REFERENCE.md → Initialization Checklist
- BOOTSTRAP_SEQUENCE_DIAGRAM.md → Parallel Streams
- BOOTSTRAP_INITIALIZATION_REPORT.md → Section 1 (Timeline)

**Backend Engineer:**
- BOOTSTRAP_INITIALIZATION_REPORT.md → Section 4 (Hydration)
- BOOTSTRAP_INITIALIZATION_REPORT.md → Section 5 (Race Conditions)

**QA / Debugger:**
- BOOTSTRAP_QUICK_REFERENCE.md → Debugging Checklist
- BOOTSTRAP_INITIALIZATION_REPORT.md → Section 12 (Debugging)

**Architect:**
- BOOTSTRAP_INITIALIZATION_REPORT.md → All sections
- BOOTSTRAP_SEQUENCE_DIAGRAM.md → All diagrams

---

## Summary

**EarthNova bootstrap is a three-phase orchestration:**

1. **Pre-Flutter setup** (0-700ms) — Supabase init, auth service, error handlers, zone setup
2. **Eager game coordinator initialization** (700-1000ms) — GameCoordinator starts immediately on auth
3. **Non-blocking SQLite hydration + background Supabase sync** (1000-3000ms+) — Game loop runs while data loads

**Four independent loading screen gates** (hydrated, zone ready, player located, GPS permission) **dismiss the overlay when all settle** (~3-5 seconds typical).

**Critical path:** Auth settles → Hydration → Game loop → Zone resolves → GPS converges → Map visible

---

## Document Statistics

| Document | Size | Sections | Tables | Diagrams |
|----------|------|----------|--------|----------|
| BOOTSTRAP_QUICK_REFERENCE.md | 12KB | 15 | 8 | 2 |
| BOOTSTRAP_SEQUENCE_DIAGRAM.md | 24KB | 9 | 2 | 7 |
| BOOTSTRAP_INITIALIZATION_REPORT.md | 29KB | 13 | 15 | 1 |
| **Total** | **65KB** | **37** | **25** | **10** |

---

## Last Updated

**2026-04-02** — Complete bootstrap and initialization analysis

**Scope:** EarthNova v0.1.0+1, Flutter 3.41.3, Riverpod 3.2.1

**Coverage:** 100% of startup path from `main()` to first interactive frame

