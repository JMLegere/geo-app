# PRD: Stability & Architecture Improvements

> **Status:** Draft
> **Date:** 2026-03-27
> **Goal:** Reduce crash rate and improve perceived reliability across all device tiers.

---

## Problem Statement

EarthNova crashes frequently in production. Players on lower-end devices experience OOM kills, startup hangs, and UI freezes. Even on capable devices, the app occasionally deadlocks during hydration or drops sync data silently. These issues erode trust in a game that relies on long-term engagement (streaks, collections, sanctuary building).

The root causes are not architectural — the core/feature/shared layering is sound. The instability comes from six specific implementation patterns that compound under real-world conditions (slow networks, low RAM, cold starts, backgrounded apps).

---

## Success Metrics

| Metric | Current (estimated) | Target |
|--------|-------------------|--------|
| Crash-free session rate | ~92% | ≥99% |
| Cold start to interactive map | 4-12s (device-dependent) | ≤2s on mid-tier, ≤4s on low-tier |
| OOM kills per 1K sessions | ~30 (low-end devices) | <5 |
| Silent sync data loss | Unknown (no monitoring) | 0 with alerting |
| Frames >16ms during gameplay | ~8% | <2% |

---

## Non-Goals

- Full ECS rewrite of game loop (future initiative, not required for stability)
- Multiplayer / real-time sync (separate initiative)
- New gameplay features (this is infrastructure-only)
- UI/UX redesign

---

## Feature 1: Phased Startup

### Problem

`GameCoordinator` is a `FutureProvider` that blocks on loading ~32K species (6.1 MB JSON), biome index (28 MB JSON), and full cell progress from SQLite. The UI cannot render until all three complete. On cold start with a large collection, this takes 4-12s. If any step fails or is slow, the app appears hung.

`main.dart:250-253` eagerly reads the coordinator before checking hydration state, creating a race between the loading screen and the tab shell.

### Solution

Split startup into four progressive phases. Each phase unlocks more functionality. The app is usable at Phase 1.

| Phase | What loads | What's available | Target time |
|-------|-----------|-----------------|-------------|
| **1 — Map shell** | MapLibre tiles, player marker, camera | Pan/zoom map, see position | <500ms |
| **2 — Fog & cells** | SQLite cell progress, fog resolver | Fog-of-war renders, cells visible | <2s |
| **3 — Discovery** | Species index, biome index (background isolate) | Species encounters activate | <4s |
| **4 — Sync** | Supabase auth, write queue | Cloud sync, enrichment | <6s |

### Requirements

- **P1-1:** `GameCoordinator` must not block the provider tree. Convert from `FutureProvider` to a `Notifier` that starts in an `initializing` state and emits `ready` per-phase.
- **P1-2:** `MapScreen` renders with an empty fog layer at Phase 1. Fog populates when Phase 2 completes. No loading spinner on the map — the map is always interactive.
- **P1-3:** Species and biome JSON parsing runs in `Isolate.run()` on native (already designed in `performance-plan.md` A1). On web, use chunked async parse yielding every 500 records.
- **P1-4:** Discovery encounters are suppressed until Phase 3 completes. Player movement still tracks during Phase 1-2 so no data is lost — discoveries are retroactively evaluated once the species index is available.
- **P1-5:** If Phase 3 takes >10s, show a non-blocking toast: "Loading species data..." — not a blocking modal.
- **P1-6:** Supabase init is fire-and-forget (Phase 4). Offline mode is the default. Auth upgrade prompts appear only after Phase 4 completes.

### Acceptance Criteria

- App shows interactive map within 500ms of launch on a Pixel 6.
- Full game loop active within 4s on 4G connection.
- No `FutureProvider` in the `GameCoordinator` initialization path.
- Existing test suite passes with no new test failures.

---

## Feature 2: Device-Aware Resource Budgets

### Problem

Image cache is hardcoded to 200 MB / 500 images (`main.dart:35-36`). On devices with <1 GB available RAM, this causes the OS to kill the app (OOM). The species grid in the Pack tab can load 293+ thumbnails during scroll, which fills the cache rapidly.

### Solution

Query available device memory at startup and set cache limits proportionally.

### Requirements

- **P2-1:** Classify devices into three tiers at startup:
  - **Low** (<2 GB total RAM): 50 MB cache, 150 images
  - **Mid** (2-4 GB): 100 MB cache, 300 images
  - **High** (>4 GB): 200 MB cache, 500 images
- **P2-2:** Use `device_info_plus` (or equivalent) to read total/available memory. Fall back to **Mid** tier if the query fails.
- **P2-3:** Log the selected tier and cache limits to `DebugLogBuffer` on startup for diagnostics.
- **P2-4:** On web, default to **Mid** tier (browser memory APIs are unreliable).
- **P2-5:** If available memory drops below 100 MB during gameplay (monitored via periodic check), evict the image cache down to 50% of its current size and log a warning.

### Acceptance Criteria

- App does not OOM on a device with 1 GB total RAM running the Pack tab species grid.
- Cache limits are logged on every startup.
- Existing tests pass; no new image-related flicker or missing thumbnails.

---

## Feature 3: Stream Subscription Safety

### Problem

`MapScreen.initState()` creates multiple stream subscriptions sequentially (`_enrichmentSubscription`, `_adminBoundarySubscription`, plus GameCoordinator streams). If an exception occurs partway through `initState()`, `dispose()` only cancels subscriptions that were already assigned. Unassigned subscriptions leak, causing updates to fire on a disposed widget — which crashes.

This pattern repeats anywhere `StatefulWidget` subscribes to streams in `initState()`.

### Solution

Guarantee cleanup of all subscriptions regardless of where `initState()` fails.

### Requirements

- **P3-1:** Wrap all stream subscription setup in `MapScreen.initState()` in a try-catch. On exception, cancel any subscriptions that were already assigned, then rethrow.
- **P3-2:** Audit all `StatefulWidget` subclasses in `lib/features/` that subscribe to streams in `initState()`. Apply the same guard pattern.
- **P3-3:** Where possible, migrate stream subscriptions from `initState()`/`dispose()` to `ref.listen()` or `ref.onDispose()` in `ConsumerStatefulWidget`. Riverpod's lifecycle management handles cleanup automatically, eliminating the leak class entirely.
- **P3-4:** Add a lint rule or code review checklist item: "No raw `StreamSubscription` fields in widgets — use `ref.listen()` instead."

### Acceptance Criteria

- No `StreamSubscription` fields remain in `MapScreen`. All stream consumption uses `ref.listen()` or equivalent.
- A widget test verifies that disposing `MapScreen` mid-`initState()` does not leak subscriptions.
- Zero `setState() called after dispose()` errors in debug mode during normal gameplay.

---

## Feature 4: Fog Rendering Throttle

### Problem

Fog-of-war GeoJSON is regenerated at ~10 Hz (every 6th frame of the 60 fps interpolation loop). Each regeneration queries all cells in the fog ring, builds a GeoJSON polygon collection from 200+ cells, and uploads it to the MapLibre native layer. On mid/low-tier devices, this causes frame drops (>16ms frames) and perceived stuttering.

### Solution

Reduce fog update frequency and scope.

### Requirements

- **P4-1:** Throttle fog GeoJSON regeneration to **2 Hz** (every 500ms) instead of ~10 Hz. Player movement interpolation continues at 60 fps — only the fog layer updates slower.
- **P4-2:** Implement **dirty-cell tracking**: maintain a set of cells whose fog state changed since the last render. On each fog tick, only rebuild GeoJSON for dirty cells and merge with the cached GeoJSON for clean cells.
- **P4-3:** If no cells are dirty (player hasn't moved to a new cell), skip the fog rebuild entirely — zero CPU cost.
- **P4-4:** Measure and log fog rebuild duration via `ObservabilityBuffer`. Alert if any single rebuild exceeds 8ms (half a frame budget).

### Acceptance Criteria

- Fog rendering CPU time drops by ≥60% in the performance test suite.
- No visible fog "pop-in" or lag when walking at normal speed (5 km/h).
- p90 frame time during active movement is <10ms.

---

## Feature 5: Write Queue Resilience

### Problem

`QueueProcessor.flush()` uses a boolean `_flushing` guard. If a flush is already running when the next auto-flush timer (10s) fires, the new flush is silently dropped — no log, no retry, no metric. Under slow network conditions, flushes can take >10s, meaning data accumulates locally and never syncs.

Additionally, there is no conflict resolution strategy. If a player uses two devices offline and both sync later, last-write-wins with no detection.

### Solution

Make the write queue observable, retriable, and conflict-aware.

### Requirements

- **P5-1:** When a flush is skipped due to `_flushing`, log it to `DebugLogBuffer` with the current queue depth.
- **P5-2:** Track consecutive skipped flushes. If ≥3 flushes are skipped in a row, increase the flush interval to 30s (backoff) and log a warning.
- **P5-3:** After a successful flush, reset the interval to the default (10s).
- **P5-4:** Add a `syncStatus` provider that exposes: `idle`, `syncing`, `backingOff(skippedCount)`, `error(message)`. Surface this in the UI as a subtle status indicator (e.g., cloud icon with state).
- **P5-5:** Add a `lastSyncedAt` timestamp to the sync status. If >5 minutes since last successful sync while online, show a non-blocking warning.
- **P5-6:** (Future — design only, do not implement yet) Design a conflict resolution strategy for multi-device sync. Document the approach in `docs/sync-conflict-strategy.md`. Recommend CRDT for collection state (items are append-only, deletions are rare) and last-write-wins for player stats.

### Acceptance Criteria

- Skipped flushes are visible in the debug log.
- Sync status is visible in the UI (cloud icon or equivalent).
- Under simulated slow network (500ms latency), no sync data is silently lost.
- Conflict resolution design doc exists and is reviewed.

---

## Feature 6: Crash Recovery & Resilience

### Problem

When the app crashes (OOM, unhandled exception, OS kill), it restarts from scratch — full hydration, full species parse, full fog rebuild. On a device that crashed due to low memory, this restart is likely to be slow (compounding the bad experience) or crash again (crash loop).

There is no crash-loop detection, no safe mode, and no checkpoint/resume.

### Solution

Add crash-loop detection and a lightweight safe mode.

### Requirements

- **P6-1:** On each successful startup, write a timestamp to `SharedPreferences` (`lastSuccessfulBoot`).
- **P6-2:** On each startup, check if the previous boot timestamp is <60s ago. If so, increment a `crashLoopCount` counter. If `crashLoopCount ≥ 3`, enter safe mode.
- **P6-3:** **Safe mode** disables: species parsing (no discovery), fog rendering (no GeoJSON churn), sync (no network). The app shows the map with the player marker and a banner: "Running in safe mode due to repeated crashes. [Tap to retry normal mode]."
- **P6-4:** "Retry normal mode" resets `crashLoopCount` to 0 and restarts the full boot sequence.
- **P6-5:** Add a periodic checkpoint (every 60s) that serializes critical `GameCoordinator` state to SQLite: current cell, fog state hash, last discovery timestamp. On restart, if a checkpoint exists and is <5 minutes old, skip re-deriving that state and load from checkpoint.
- **P6-6:** Log crash-loop events and safe-mode entries to `ObservabilityBuffer` for remote diagnostics (when sync is available).

### Acceptance Criteria

- After 3 simulated crashes in 60s, the app enters safe mode on 4th launch.
- Safe mode shows the map without crashing.
- "Retry normal mode" exits safe mode and boots normally.
- Checkpoint reduces restart time by ≥50% after a single crash.

---

## Implementation Priority

| Priority | Feature | Effort | Impact |
|----------|---------|--------|--------|
| **P0** | Feature 1: Phased Startup | L | Fixes deadlock + slow boot (most visible crash cause) |
| **P0** | Feature 2: Device-Aware Budgets | S | Fixes OOM kills on low-end devices |
| **P1** | Feature 3: Stream Subscription Safety | M | Fixes `setState after dispose` crashes |
| **P1** | Feature 4: Fog Rendering Throttle | M | Fixes frame drops and perceived freezing |
| **P2** | Feature 5: Write Queue Resilience | M | Fixes silent data loss (not a crash, but trust-eroding) |
| **P2** | Feature 6: Crash Recovery | L | Prevents crash loops (defensive, not root-cause) |

**Recommended order:** P0 features first (Features 1 & 2 in parallel), then P1 (Features 3 & 4), then P2 (Features 5 & 6).

---

## Dependencies & Risks

| Risk | Mitigation |
|------|-----------|
| Phased startup changes the provider dependency graph significantly | Feature-flag the new startup path; keep old path as fallback for one release |
| `Isolate.run()` not available on web | Already handled in `performance-plan.md` A1 — use chunked async parse on web |
| Device memory query may not work on all Android OEMs | Fall back to Mid tier if query fails (P2-2) |
| Fog throttle to 2Hz may cause visible lag at high speed (driving) | Test at 60 km/h; if visible, add speed-adaptive throttle (faster movement = higher Hz) |
| Crash-loop detection false positives (user intentionally restarts quickly) | Require 3 crashes in 60s, not just 3 restarts — distinguish clean exit from crash via a `cleanShutdown` flag |

---

## Open Questions

1. **Telemetry:** Do we have crash reporting (Sentry, Crashlytics) set up? If not, Feature 6 metrics are local-only and we're flying blind on production crash rates.
2. **Device distribution:** What % of our users are on low-end (<2 GB RAM) devices? This determines urgency of Feature 2.
3. **Fog rendering:** Has anyone profiled the actual GeoJSON rebuild cost? The 10 Hz estimate is from code analysis — real-world cost may be lower if MapLibre batches updates.
4. **Sync conflicts:** Has multi-device usage been observed in the wild yet, or is this purely preventive?
5. **Performance budget:** Should we add a CI performance gate (e.g., boot benchmark must complete in <4s on a reference device emulator)?
