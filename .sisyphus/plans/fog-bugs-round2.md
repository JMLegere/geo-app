# Fog Visual Bugs Round 2: Player Marker + Cell Transition Flash

## TL;DR

> **Quick Summary**: Fix two remaining fog-of-war visual bugs on Flutter web: invisible player marker on initial load, and adjacent cells flashing when transitioning from unexplored→concealed.
> 
> **Deliverables**:
> - Player marker visible immediately after fog init reveal
> - No flash when cells transition between fog states
> - All existing tests updated and passing
> 
> **Estimated Effort**: Short
> **Parallel Execution**: YES - 2 waves
> **Critical Path**: Task 1 → Task 2 → Task 3 (deploy) → F1-F4

---

## Context

### Original Request
"the map currently loads before the fog, revealing the entire map. can we make sure that the fog implementation is tight so that we're not accidentally revealing the map on initial load or during cell transitions"

### Interview Summary
**Key Discussions**:
- Initial load flash was fixed via CSS injection (`.maplibregl-map { opacity: 0 }` until fog init)
- Two new bugs emerged from the fix and from existing fog architecture
- User clarified: "it is only the adjacent cells to the current cell which seem to flash on transition from unexplored to concealed"
- User confirmed: "the player marker is invisible on app initial load"

**Research Findings**:
- `updateGeoJsonSource` on web wraps synchronous JS calls in async — `setData()` and `parse()` are synchronous. But MapLibre JS internally queues tile processing asynchronously, so 3 source updates via `Future.wait` may render on different animation frames.
- The WidgetLayer is a Flutter `Stack` sibling to the `HtmlElementView`, NOT a DOM child — but Flutter web's platform view compositing creates HTML overlay elements that ARE children of the platform view's DOM container, so CSS `opacity: 0` inheritance may still apply.
- Concealed density is 0.95 — a 5% opacity difference from unexplored (1.0) on near-black `#161620`. Almost certainly imperceptible. The visual differentiation comes from cell borders (0.25 opacity for concealed vs 0.4 for unexplored), not the fill.

### Metis Review
**Identified Gaps** (addressed):
- The null-toggle pattern for ValueNotifier is fragile — use `addPostFrameCallback` instead
- Bug 2 fix changes test assertions in `fog_geojson_builder_test.dart` — must update as part of same task
- Need to verify DOM ancestry before committing to Bug 1 fix strategy (added as investigation step)
- `_processGameLogic` doesn't await `_updateFogSources()` — noted as pre-existing tech debt, not in scope

---

## Work Objectives

### Core Objective
Eliminate two visual rendering bugs in the fog-of-war map overlay on Flutter web so the map never accidentally reveals tiles or hides the player marker.

### Concrete Deliverables
- Modified `map_screen.dart`: post-reveal marker refresh
- Modified `fog_geojson_builder.dart`: concealed cells excluded from base fog holes and mid fog polygons
- Modified `fog_geojson_builder_test.dart`: updated assertions for new concealed behavior
- All 1002+ tests passing, 0 analyzer issues
- Deployed to Railway and visually verified

### Definition of Done
- [ ] Player marker visible on initial load (Playwright screenshot verification)
- [ ] No cell flash when moving between cells (Playwright video/screenshot series)
- [ ] `LD_LIBRARY_PATH=. flutter test` → all pass
- [ ] `flutter analyze` → 0 issues

### Must Have
- Player marker appears immediately after fog reveal completes
- Adjacent cells do not flash when transitioning unexplored→concealed
- Cell borders still differentiate concealed (0.25 opacity) from unexplored (0.4 opacity)
- Existing fog behavior for observed, hidden, unexplored, undetected states unchanged

### Must NOT Have (Guardrails)
- Do NOT change `FogStateResolver` logic — fog computation is an architectural invariant
- Do NOT merge the 3-layer fog architecture into fewer layers
- Do NOT change fog density enum values in `FogState`
- Do NOT add transition animations for fog state changes (that's a feature, not a bugfix)
- Do NOT refactor `_processGameLogic` throttling or rubber-band controller
- Do NOT touch `MapVisibility.hideMapContainer()` or the CSS injection approach (it works)
- Do NOT change `PlayerMarkerLayer` or `PlayerMarkerWidget` internal structure
- Do NOT add new packages/dependencies

---

## Verification Strategy (MANDATORY)

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: YES
- **Automated tests**: Tests-after (update existing tests)
- **Framework**: flutter_test (existing)

### QA Policy
Every task MUST include agent-executed QA scenarios.
Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

- **Frontend/UI**: Use Playwright (playwright skill) — Navigate, interact, assert DOM, screenshot
- **Unit tests**: Use Bash (flutter test) — Run specific test files, assert pass

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately — independent bug fixes):
├── Task 1: Fix adjacent cell flash (fog_geojson_builder.dart + tests) [quick]
├── Task 2: Fix player marker invisible on load (map_screen.dart) [quick]

Wave 2 (After Wave 1 — verification + deploy):
├── Task 3: Deploy and visual QA via Playwright [unspecified-high]

Wave FINAL (After ALL tasks — independent review):
├── Task F1: Plan compliance audit [deep]
├── Task F2: Code quality review [quick]
├── Task F3: Real manual QA via Playwright [unspecified-high]
├── Task F4: Scope fidelity check [quick]

Critical Path: Task 1+2 (parallel) → Task 3 → F1-F4
Max Concurrent: 2 (Wave 1)
```

### Dependency Matrix

| Task | Depends On | Blocks |
|------|-----------|--------|
| 1 | — | 3, F1-F4 |
| 2 | — | 3, F1-F4 |
| 3 | 1, 2 | F1-F4 |
| F1-F4 | 3 | — |

### Agent Dispatch Summary

- **Wave 1**: **2** — T1 → `quick`, T2 → `quick`
- **Wave 2**: **1** — T3 → `unspecified-high`
- **FINAL**: **4** — F1 → `deep`, F2 → `quick`, F3 → `unspecified-high` (+ playwright skill), F4 → `quick`

---

## TODOs

- [x] 1. Fix adjacent cell flash: exclude concealed from base/mid fog layers ✅ COMPLETE

  **What to do**:
  - In `lib/features/map/utils/fog_geojson_builder.dart`, method `buildBaseFog` (line 51): change the skip condition from `if (state == FogState.undetected || state == FogState.unexplored)` to ALSO skip `FogState.concealed`. Concealed cells remain under the fully opaque base fog instead of getting a hole punched + semi-transparent overlay. This eliminates the flash because there's no longer a two-step render operation for concealed cells.
  - In `buildMidFog` (line 93): change the include condition from `if (state != FogState.hidden && state != FogState.concealed) continue` to `if (state != FogState.hidden) continue`. Only hidden cells get mid-fog polygons now.
  - **Do NOT touch `buildCellBorders`** — concealed cells still get border outlines at 0.25 opacity. This is how they're visually differentiated from unexplored (0.4 opacity borders).
  - Update tests in `test/features/map/utils/fog_geojson_builder_test.dart`:
    - Test at line 136 "with concealed cell punches a hole": change to assert NO hole is punched (coordinates.length == 1)
    - Test at line 171 "multiple cells produce multiple holes": remove the concealed cell from the test data, or adjust expected hole count from 4 to 3 (exterior + 2 holes for observed + hidden only)
    - Test at line 251 "includes concealed cells with density 0.95": change to assert concealed cells are EXCLUDED (features is empty)
    - Test at line 291 "multiple cells produce multiple features": change expected count from 2 to 1 (only hidden)
    - Test at line 318 "mixed states only includes hidden and concealed": change expected count from 2 to 1, remove 0.95 from expected densities
  - Run `LD_LIBRARY_PATH=. flutter test test/features/map/utils/fog_geojson_builder_test.dart` to verify
  - Run `flutter analyze` to verify 0 issues

  **Must NOT do**:
  - Do NOT change `FogState.concealed` density value (0.95)
  - Do NOT change `buildCellBorders` behavior
  - Do NOT change `FogStateResolver` logic
  - Do NOT change `buildRestorationOverlay` behavior

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Two small code changes (skip conditions) + test updates in one file each. No architectural change.
  - **Skills**: []
    - No special skills needed — straightforward Dart code edits.

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Task 2)
  - **Blocks**: Task 3
  - **Blocked By**: None (can start immediately)

  **References** (CRITICAL):

  **Pattern References**:
  - `lib/features/map/utils/fog_geojson_builder.dart:51` — Current `buildBaseFog` skip condition: `if (state == FogState.undetected || state == FogState.unexplored)`. Add `|| state == FogState.concealed` here.
  - `lib/features/map/utils/fog_geojson_builder.dart:93` — Current `buildMidFog` include condition: `if (state != FogState.hidden && state != FogState.concealed) continue`. Change to `if (state != FogState.hidden) continue`.
  - `lib/features/map/utils/fog_geojson_builder.dart:164-200` — `buildCellBorders` — do NOT modify this. Concealed cells still get borders here.

  **Test References**:
  - `test/features/map/utils/fog_geojson_builder_test.dart:136-145` — "with concealed cell punches a hole" → change to assert NO hole
  - `test/features/map/utils/fog_geojson_builder_test.dart:171-185` — "multiple cells produce multiple holes" → adjust count
  - `test/features/map/utils/fog_geojson_builder_test.dart:251-262` — "includes concealed cells with density 0.95" → change to assert excluded
  - `test/features/map/utils/fog_geojson_builder_test.dart:291-302` — "multiple cells produce multiple features" → adjust count
  - `test/features/map/utils/fog_geojson_builder_test.dart:318-337` — "mixed states only includes hidden and concealed" → adjust assertions

  **WHY Each Reference Matters**:
  - The `buildBaseFog` line 51 is the EXACT condition to change — adding `concealed` to the skip list
  - The `buildMidFog` line 93 is the EXACT include condition to simplify
  - Test file lines give the EXACT test names and line numbers for each assertion to update
  - `buildCellBorders` is referenced as a DO-NOT-TOUCH to prevent accidental scope creep

  **Acceptance Criteria**:

  **Unit Tests:**
  - [ ] `LD_LIBRARY_PATH=. flutter test test/features/map/utils/fog_geojson_builder_test.dart` → ALL PASS
  - [ ] `flutter analyze` → 0 issues

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Concealed cells no longer get base fog holes
    Tool: Bash (flutter test)
    Preconditions: Test file updated with new assertions
    Steps:
      1. Run: LD_LIBRARY_PATH=. flutter test test/features/map/utils/fog_geojson_builder_test.dart --name "with concealed cell"
      2. Assert: test passes, concealed cell does NOT produce a hole (coordinates.length == 1)
    Expected Result: Test passes — concealed stays under opaque base
    Failure Indicators: Test fails with "Expected: 1, Actual: 2"
    Evidence: .sisyphus/evidence/task-1-concealed-no-hole.txt

  Scenario: Concealed cells excluded from mid fog
    Tool: Bash (flutter test)
    Preconditions: Test file updated
    Steps:
      1. Run: LD_LIBRARY_PATH=. flutter test test/features/map/utils/fog_geojson_builder_test.dart --name "concealed"
      2. Assert: all concealed-related mid fog tests pass with exclusion behavior
    Expected Result: Concealed cells produce 0 mid-fog features
    Failure Indicators: features.length > 0 for concealed
    Evidence: .sisyphus/evidence/task-1-concealed-no-midfog.txt

  Scenario: Hidden cells still work correctly (regression)
    Tool: Bash (flutter test)
    Preconditions: No changes to hidden cell logic
    Steps:
      1. Run: LD_LIBRARY_PATH=. flutter test test/features/map/utils/fog_geojson_builder_test.dart --name "hidden"
      2. Assert: all hidden cell tests pass unchanged
    Expected Result: Hidden cells still get base fog holes and mid-fog polygons with density 0.5
    Failure Indicators: Any hidden-related test fails
    Evidence: .sisyphus/evidence/task-1-hidden-regression.txt

  Scenario: Full test suite passes
    Tool: Bash (flutter test)
    Preconditions: All changes applied
    Steps:
      1. Run: LD_LIBRARY_PATH=. flutter test
      2. Assert: 0 failures
    Expected Result: All 1002+ tests pass
    Failure Indicators: Any test failure
    Evidence: .sisyphus/evidence/task-1-full-suite.txt
  ```

  **Commit**: YES
  - Message: `🐛 fix(map): exclude concealed cells from base/mid fog layers to prevent transition flash`
  - Files: `lib/features/map/utils/fog_geojson_builder.dart`, `test/features/map/utils/fog_geojson_builder_test.dart`
  - Pre-commit: `LD_LIBRARY_PATH=. flutter test test/features/map/utils/fog_geojson_builder_test.dart`

- [x] 2. Fix player marker invisible on initial load ✅ COMPLETE

  **What to do**:
  - First, investigate the DOM structure to understand the root cause. Use Playwright (or browser DevTools via Bash) to inspect the DOM after map load — determine whether the Flutter WidgetLayer overlay elements are DOM descendants of `.maplibregl-map` (CSS opacity inheritance) or Flutter canvas siblings.
  - In `lib/features/map/map_screen.dart`, in `_initFogAndReveal()` method (around line 605-607), after the call to `_mapVisibility.revealMapContainer()`, add a `WidgetsBinding.instance.addPostFrameCallback` that forces the player marker to re-render. Inside the callback: check `if (!mounted) return;`, then check `if (_markerPosition.value != null)`, then save the current value, set to null, set back to saved value. This forces `ValueListenableBuilder` to rebuild, which makes MapLibre recalculate the marker's screen position after the container is visible.
  - The `addPostFrameCallback` ensures the DOM has processed the opacity change before the marker refresh. This is more reliable than the immediate null-toggle because the CSS transition needs at least one frame to start.
  - Guard with `if (!mounted) return` inside the callback since it runs async.
  - Run `flutter analyze` to verify 0 issues
  - Run `LD_LIBRARY_PATH=. flutter test` to verify no regressions

  **Must NOT do**:
  - Do NOT change `PlayerMarkerLayer` or `PlayerMarkerWidget`
  - Do NOT change `MapVisibility.hideMapContainer()`
  - Do NOT remove the CSS injection approach
  - Do NOT change the rubber-band controller

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single method change in one file. Small, focused fix.
  - **Skills**: []
    - No special skills needed — straightforward Dart code edit.

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Task 1)
  - **Blocks**: Task 3
  - **Blocked By**: None (can start immediately)

  **References** (CRITICAL):

  **Pattern References**:
  - `lib/features/map/map_screen.dart:574-608` — `_initFogAndReveal()` method. The reveal happens at line 606 (`_mapVisibility.revealMapContainer()`). Insert the `addPostFrameCallback` marker refresh AFTER this line and BEFORE `MapLogger.fogInitComplete()`.
  - `lib/features/map/map_screen.dart:136` — `_markerPosition = ValueNotifier(null)` — initial state is null, becomes non-null when rubber band fires first update.
  - `lib/features/map/map_screen.dart:478` — `_markerPosition.value = (lat: lat, lon: lon)` — where the value gets set on each 60fps frame.
  - `lib/features/map/widgets/player_marker_layer.dart:30` — `if (pos == null) return const SizedBox.shrink()` — the null check that hides the marker when position is unknown.

  **External References**:
  - `WidgetsBinding.instance.addPostFrameCallback` — Flutter API for scheduling work after the next frame paint. Import from `package:flutter/widgets.dart` (already imported in map_screen.dart).

  **WHY Each Reference Matters**:
  - Line 574-608 is the EXACT method to modify — insert after reveal, before log
  - Line 136 shows the ValueNotifier starts null — null check needed in the callback
  - Line 30 of player_marker_layer.dart shows why null-toggle triggers a rebuild (null → SizedBox.shrink, value → WidgetLayer)
  - `addPostFrameCallback` ensures the DOM has started the CSS opacity transition before we force the marker rebuild

  **Acceptance Criteria**:

  **Unit Tests:**
  - [ ] `LD_LIBRARY_PATH=. flutter test` → ALL PASS (no regressions)
  - [ ] `flutter analyze` → 0 issues

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Player marker visible after initial load
    Tool: Playwright (playwright skill)
    Preconditions: App deployed to Railway or running locally
    Steps:
      1. Navigate to app URL
      2. Wait for fog initialization to complete (wait for map to become visible, ~2s)
      3. Wait an additional 1s for CSS transition + postFrameCallback
      4. Take screenshot of center of viewport
      5. Analyze screenshot: look for blue pixels (player marker color #4FC3F7 or #1A73E8) in the center area
    Expected Result: Blue player marker dot visible in the center area of the map
    Failure Indicators: No blue pixels in center area, or only dark fog color pixels
    Evidence: .sisyphus/evidence/task-2-marker-visible.png

  Scenario: Player marker persists after movement (regression)
    Tool: Playwright (playwright skill)
    Preconditions: App loaded, marker visible
    Steps:
      1. After initial load screenshot, press arrow key to move player
      2. Wait 500ms for rubber-band interpolation
      3. Take screenshot
      4. Assert blue marker pixels still present
    Expected Result: Marker remains visible and follows player movement
    Failure Indicators: Marker disappears after movement
    Evidence: .sisyphus/evidence/task-2-marker-after-move.png

  Scenario: Full test suite passes (regression)
    Tool: Bash (flutter test)
    Preconditions: Change applied
    Steps:
      1. Run: LD_LIBRARY_PATH=. flutter test
      2. Assert: 0 failures
    Expected Result: All tests pass
    Failure Indicators: Any failure
    Evidence: .sisyphus/evidence/task-2-full-suite.txt
  ```

  **Commit**: YES
  - Message: `🐛 fix(map): force player marker repaint after fog reveal on web`
  - Files: `lib/features/map/map_screen.dart`
  - Pre-commit: `LD_LIBRARY_PATH=. flutter test`

- [ ] 3. Deploy to Railway and run visual QA

  **What to do**:
  - Activate Flutter/mise: `eval "$(~/.local/bin/mise activate bash)"`
  - Run full test suite: `LD_LIBRARY_PATH=. flutter test` — must pass
  - Run analyzer: `flutter analyze` — must be 0 issues
  - Commit both fixes if not already committed
  - Deploy: `railway up --ci` (waits for build completion)
  - Verify deployment at `https://fog-of-world-production.up.railway.app`
  - Use Playwright to capture visual evidence of both fixes working

  **Must NOT do**:
  - Do NOT deploy if tests fail
  - Do NOT deploy if analyzer has issues

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Deployment + Playwright visual QA requires multiple tools and careful verification.
  - **Skills**: [`playwright`]
    - `playwright`: Needed for browser-based visual verification of the deployed app.

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 2 (sequential after Wave 1)
  - **Blocks**: F1-F4
  - **Blocked By**: Task 1, Task 2

  **References**:
  - Railway project: `fog-of-world`, domain: `https://fog-of-world-production.up.railway.app`
  - Deploy command: `railway up --ci` (shows build logs and waits)
  - Flutter activation: `eval "$(~/.local/bin/mise activate bash)"`

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Player marker visible on deployed app
    Tool: Playwright (playwright skill)
    Preconditions: App deployed to Railway
    Steps:
      1. Navigate to https://fog-of-world-production.up.railway.app
      2. Wait 5s for full initialization (fog init + CSS transition + marker)
      3. Take full-page screenshot
      4. Verify blue marker pixels present in center viewport
    Expected Result: Player marker dot visible on the map
    Failure Indicators: No blue pixels in expected area
    Evidence: .sisyphus/evidence/task-3-deployed-marker.png

  Scenario: No cell flash on movement
    Tool: Playwright (playwright skill)
    Preconditions: App loaded on deployed URL
    Steps:
      1. Load app, wait for initialization
      2. Press and hold right arrow key for 3 seconds (move through multiple cells)
      3. Take screenshots at 200ms intervals during movement (15 frames)
      4. Analyze frames: no frame should show fully transparent cells adjacent to current cell
    Expected Result: All frames show consistent fog coverage — no flash/flicker
    Failure Indicators: Any frame shows transparent/light area where fog should be opaque
    Evidence: .sisyphus/evidence/task-3-no-flash-frame-*.png
  ```

  **Commit**: YES (if any deployment config changes needed)
  - Message: `🚀 ci(deploy): deploy fog bug fixes round 2`
  - Pre-commit: `LD_LIBRARY_PATH=. flutter test`

---

## Final Verification Wave (MANDATORY — after ALL implementation tasks)

> 4 review agents run in PARALLEL. ALL must APPROVE. Rejection → fix → re-run.

- [ ] F1. **Plan Compliance Audit** — `deep`
  Read the plan end-to-end. For each "Must Have": verify implementation exists (read file, run command). For each "Must NOT Have": search codebase for forbidden patterns — reject with file:line if found. Check evidence files exist in .sisyphus/evidence/. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `quick`
  Run `flutter analyze`. Review all changed files for: unused imports, TODO comments without tickets, inconsistent style. Check that the fog_geojson_builder changes are minimal and surgical — only the skip/include conditions changed, not the GeoJSON generation logic.
  Output: `Analyze [PASS/FAIL] | Tests [N pass/N fail] | Files [N clean/N issues] | VERDICT`

- [ ] F3. **Real Manual QA** — `unspecified-high` (+ `playwright` skill)
  Start from clean browser state. Load deployed app. Verify player marker visible. Move through cells in all 4 directions. Capture screenshots every 200ms during movement. Verify no flash or visual glitch in any frame. Test edge case: reload the page and verify marker appears again.
  Output: `Scenarios [N/N pass] | Integration [N/N] | Edge Cases [N tested] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `quick`
  For each task: read "What to do", read actual diff (git diff). Verify 1:1 — everything in spec was built, nothing beyond spec was built. Specifically verify: FogStateResolver NOT touched, PlayerMarkerLayer NOT touched, MapVisibility.hideMapContainer NOT touched, density enum values NOT changed.
  Output: `Tasks [N/N compliant] | Contamination [CLEAN/N issues] | Unaccounted [CLEAN/N files] | VERDICT`

---

## Commit Strategy

| Task | Commit Message | Files |
|------|---------------|-------|
| 1 | `🐛 fix(map): exclude concealed cells from base/mid fog layers to prevent transition flash` | `fog_geojson_builder.dart`, `fog_geojson_builder_test.dart` |
| 2 | `🐛 fix(map): force player marker repaint after fog reveal on web` | `map_screen.dart` |
| 3 | `🚀 ci(deploy): deploy fog bug fixes round 2` | (if needed) |

---

## Success Criteria

### Verification Commands
```bash
eval "$(~/.local/bin/mise activate bash)"
LD_LIBRARY_PATH=. flutter test                    # Expected: All tests pass
flutter analyze                                     # Expected: 0 issues
LD_LIBRARY_PATH=. flutter test test/features/map/utils/fog_geojson_builder_test.dart  # Expected: All pass
```

### Final Checklist
- [ ] Player marker visible on initial load (Playwright evidence)
- [ ] No cell flash on transitions (Playwright evidence)
- [ ] All "Must Have" items present
- [ ] All "Must NOT Have" items absent
- [ ] All tests pass
- [ ] Deployed and verified on Railway
