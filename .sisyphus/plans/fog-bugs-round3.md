# Fog Bugs Round 3 — Fix Marker Visibility + Restore Concealed Layer

## TL;DR

> **Quick Summary**: Fix two regressions from round 2: player marker invisible on initial load (broadcast stream race condition) and concealed cell layer accidentally removed (over-aggressive flash fix). Both are surgical, low-risk changes.
>
> **Deliverables**:
> - Player marker visible immediately on app load without user interaction
> - Concealed cells visually differentiated from unexplored cells, with no flash on transition
> - All 910+ tests passing, 0 analysis issues
>
> **Estimated Effort**: Quick
> **Parallel Execution**: YES — 2 waves
> **Critical Path**: Task 1 + Task 2 (parallel) → Task 3 (deploy + verify)

---

## Context

### Original Request
Fix two regressions introduced by fog bug fixes in round 2:
1. Player marker is invisible on initial load — only appears after first arrow key press
2. Adjacent (concealed) cells lost all visual differentiation — look identical to unexplored cells

### Interview Summary
**Key Discussions**:
- **Bug A root cause**: Metis identified a broadcast stream race condition in `map_screen.dart`. `_locationService.start()` is called BEFORE subscribing to `filteredLocationStream`. Since the keyboard location service emits the initial position synchronously during `start()`, and `filteredLocationStream` is a broadcast stream, the initial event is lost. The rubber-band controller never receives its first target, so `_markerPosition` stays null.
- **Bug B approach**: User proposed pre-rendering all unexplored cells with concealed-density (0.95) mid-fog polygons, hidden behind the opaque base fog. When a cell transitions to concealed, only the base fog hole is punched — the mid-fog polygon is already there. Single source update = no flash.

**Research Findings**:
- `location_service.dart` lines 84-91 have an explicit comment: *"Subscribe BEFORE start() — start() emits an initial position synchronously on a broadcast stream. Subscribing after would lose it."* — `map_screen.dart` does the opposite.
- `rubber_band_controller.dart` lines 89-97: First `setTarget` DOES call `onDisplayUpdate` immediately, which sets `_markerPosition.value`. The problem is `setTarget` is never called because the initial position event is lost.
- `fog_overlay_controller.dart` line 180: Only `FogState.undetected` is filtered from cellStates. Unexplored cells ARE in the map passed to `buildMidFog` — confirming the pre-render approach is viable.
- `FogState.concealed.density` = 0.95, `FogState.unexplored.density` = 1.0. Pre-rendered unexplored cells in mid-fog should use 0.95 (concealed density) so the polygon is already correct when the transition happens.

### Metis Review
**Identified Gaps** (addressed):
- Broadcast stream race as true root cause for Bug A — confirmed by reading `location_service.dart` internal subscribe-before-start pattern
- Need to validate unexplored cells ARE present in cellStates passed to builder — confirmed via `fog_overlay_controller.dart` line 180
- Test assertions need updating for both buildBaseFog and buildMidFog — mapped all 6 affected tests

---

## Work Objectives

### Core Objective
Fix two regressions so the player marker is visible on load and concealed cells are visually distinct without flash artifacts.

### Concrete Deliverables
- `lib/features/map/map_screen.dart` — reordered `start()` / `listen()` lines
- `lib/features/map/utils/fog_geojson_builder.dart` — reverted buildBaseFog, expanded buildMidFog
- `test/features/map/utils/fog_geojson_builder_test.dart` — updated 6 test assertions + 2 new tests
- Deployed to Railway at `https://fog-of-world-production.up.railway.app`

### Definition of Done
- [ ] `LD_LIBRARY_PATH=. flutter test` → all tests pass (910+)
- [ ] `flutter analyze` → 0 issues
- [ ] Player marker visible on page load in browser without any keypress
- [ ] Concealed cells visually lighter than unexplored cells
- [ ] No flash when cells transition from unexplored → concealed

### Must Have
- Player marker visible on initial load (no user interaction required)
- Concealed cells render at 0.95 density (lighter than fully opaque unexplored)
- No flash artifacts during unexplored → concealed transition
- All existing tests updated to match new behavior
- Zero regressions in test suite

### Must NOT Have (Guardrails)
- Do NOT change `RubberBandController` internals
- Do NOT change `PlayerMarkerLayer` or `PlayerMarkerWidget` internal structure
- Do NOT change `MapVisibility` / CSS injection approach
- Do NOT change `FogStateResolver` logic — fog computation is an architectural invariant
- Do NOT merge the 3-layer fog architecture into fewer layers
- Do NOT change `FogState` density enum values
- Do NOT change `buildCellBorders` — border styling is correct
- Do NOT change `buildRestorationOverlay` — not related
- Do NOT change `FogOverlayController._buildGeoJson` — cell filtering is correct
- Do NOT add MapLibre resize/invalidate API calls as workaround for Bug A
- Do NOT refactor `_processGameLogic` throttling or rubber-band controller
- Do NOT remove the post-frame callback at lines 612-619 (keep as defensive safeguard)

---

## Verification Strategy

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: YES
- **Automated tests**: Tests-after (update existing tests to match new behavior, add new coverage)
- **Framework**: `flutter_test` (hand-written mocks, no mockito/mocktail)

### QA Policy
Every task MUST include agent-executed QA scenarios.
Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

- **Unit tests**: Use Bash — `LD_LIBRARY_PATH=. flutter test <path> --name "<pattern>"`
- **Browser QA**: Use Playwright (playwright skill) — Navigate to Railway URL, verify marker and fog visuals
- **Analysis**: Use Bash — `flutter analyze`

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately — both bug fixes are independent):
├── Task 1: Fix player marker broadcast stream race [quick]
└── Task 2: Restore concealed layer with pre-rendered mid-fog [quick]

Wave 2 (After Wave 1 — deploy + verify):
└── Task 3: Deploy and browser verification [quick]

Wave FINAL (After ALL tasks — independent review):
├── Task F1: Plan compliance audit (oracle)
├── Task F2: Code quality review (unspecified-high)
├── Task F3: Real browser QA (unspecified-high + playwright)
└── Task F4: Scope fidelity check (deep)

Critical Path: Task 1 + Task 2 (parallel) → Task 3 → F1-F4 (parallel)
Parallel Speedup: Tasks 1 and 2 are fully independent
Max Concurrent: 2 (Wave 1), then 4 (Final)
```

### Dependency Matrix

| Task | Depends On | Blocks |
|------|-----------|--------|
| 1 | — | 3 |
| 2 | — | 3 |
| 3 | 1, 2 | F1-F4 |
| F1-F4 | 3 | — |

### Agent Dispatch Summary

- **Wave 1**: **2** — T1 → `quick`, T2 → `quick`
- **Wave 2**: **1** — T3 → `quick` (+ `playwright` skill)
- **FINAL**: **4** — F1 → `oracle`, F2 → `unspecified-high`, F3 → `unspecified-high` (+ `playwright`), F4 → `deep`

---

## TODOs

- [x] 1. Fix player marker invisible on initial load (broadcast stream race)

  **What to do**:
  - In `lib/features/map/map_screen.dart`, reorder lines 143-146 in `initState()`: subscribe to `filteredLocationStream` BEFORE calling `_locationService.start()`.
  - Current (broken) order:
    ```dart
    _locationService = ref.read(locationServiceProvider);
    _locationService.start();                          // ← emits initial position, LOST
    _locationSubscription =
        _locationService.filteredLocationStream.listen(_onLocationUpdate);  // ← too late
    ```
  - Fixed order:
    ```dart
    _locationService = ref.read(locationServiceProvider);
    _locationSubscription =
        _locationService.filteredLocationStream.listen(_onLocationUpdate);  // ← subscribe FIRST
    _locationService.start();                          // ← initial position now captured
    ```
  - This matches the identical pattern already used inside `LocationService.start()` at lines 84-91, which has an explicit comment: *"Subscribe BEFORE start() — start() emits an initial position synchronously on a broadcast stream. Subscribing after would lose it."*
  - Do NOT remove the existing post-frame callback at lines 612-619 — keep it as a defensive safeguard.
  - Do NOT modify `RubberBandController`, `PlayerMarkerLayer`, `PlayerMarkerWidget`, or `MapVisibility`.

  **Must NOT do**:
  - Do NOT add MapLibre resize/invalidate API calls
  - Do NOT change the rubber-band controller
  - Do NOT change the CSS injection approach
  - Do NOT change the post-frame callback logic (keep as-is)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single file, 2-line reorder, no new logic
  - **Skills**: []
    - No special skills needed — pure Dart code change
  - **Skills Evaluated but Omitted**:
    - `playwright`: Not needed for implementation, only for verification in Task 3

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Task 2)
  - **Blocks**: Task 3
  - **Blocked By**: None (can start immediately)

  **References**:

  **Pattern References** (existing code to follow):
  - `lib/features/location/services/location_service.dart:82-91` — The CORRECT subscribe-before-start pattern with explanatory comment. Copy this exact pattern.
  - `lib/features/location/services/location_service.dart:47-50` — `_outputController` is `StreamController.broadcast()` — confirms broadcast stream semantics (events lost when no listeners).

  **API/Type References** (contracts to understand):
  - `lib/features/location/services/keyboard_location_web.dart:39-43` — `start()` emits initial position synchronously via `_controller.add()`. This is the event that gets lost.
  - `lib/features/map/map_screen.dart:136` — `_markerPosition = ValueNotifier(null)` — stays null because `_onLocationUpdate` is never called for the initial position.
  - `lib/features/map/map_screen.dart:448` — `_rubberBand.setTarget(loc.position.lat, loc.position.lon)` — this is where the initial position WOULD reach rubber-band if the subscription were active.
  - `lib/features/map/controllers/rubber_band_controller.dart:89-97` — First `setTarget` snaps display and calls `onDisplayUpdate` immediately — confirms the rubber-band is correct, it just never gets called.

  **WHY Each Reference Matters**:
  - `location_service.dart:82-91`: This IS the canonical pattern. The comment explicitly documents the broadcast stream race. Replicate it in `map_screen.dart`.
  - `keyboard_location_web.dart:39-43`: Confirms the initial emit is synchronous during `start()`, proving the race condition.
  - `rubber_band_controller.dart:89-97`: Confirms no changes needed to rubber-band — it already handles first-call correctly.

  **Acceptance Criteria**:

  - [ ] `_locationSubscription = ... .listen(...)` appears BEFORE `_locationService.start()` in `initState()`
  - [ ] Post-frame callback at lines 612-619 is UNCHANGED
  - [ ] `LD_LIBRARY_PATH=. flutter test` → all tests pass
  - [ ] `flutter analyze` → 0 issues

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Full test suite passes after reorder
    Tool: Bash
    Preconditions: Flutter SDK available via mise
    Steps:
      1. Run: eval "$(~/.local/bin/mise activate bash)" && LD_LIBRARY_PATH=. flutter test
      2. Assert exit code 0
      3. Assert output contains "All tests passed"
    Expected Result: 910+ tests pass, 0 failures
    Failure Indicators: Any test failure or non-zero exit code
    Evidence: .sisyphus/evidence/task-1-test-suite.txt

  Scenario: Static analysis clean
    Tool: Bash
    Preconditions: Flutter SDK available via mise
    Steps:
      1. Run: eval "$(~/.local/bin/mise activate bash)" && flutter analyze
      2. Assert output contains "No issues found"
    Expected Result: 0 issues
    Failure Indicators: Any analysis issue
    Evidence: .sisyphus/evidence/task-1-analyze.txt

  Scenario: Subscribe-before-start ordering verified in source
    Tool: Bash (grep)
    Preconditions: Task 1 changes applied
    Steps:
      1. Read lib/features/map/map_screen.dart initState method
      2. Verify `.listen(_onLocationUpdate)` line number is LOWER than `.start()` line number
    Expected Result: Subscription precedes start call
    Failure Indicators: start() appears before listen()
    Evidence: .sisyphus/evidence/task-1-ordering-check.txt
  ```

  **Commit**: YES
  - Message: `🐛 fix(map): subscribe to location stream before start to capture initial position`
  - Files: `lib/features/map/map_screen.dart`
  - Pre-commit: `LD_LIBRARY_PATH=. flutter test`

- [x] 2. Restore concealed cell visual layer with pre-rendered mid-fog

  **What to do**:

  **Step A — Revert `buildBaseFog` concealed exclusion** (`fog_geojson_builder.dart` line 51):
  - Change from:
    ```dart
    if (state == FogState.undetected || state == FogState.unexplored || state == FogState.concealed) {
      continue;
    }
    ```
  - Change to:
    ```dart
    if (state == FogState.undetected || state == FogState.unexplored) {
      continue;
    }
    ```
  - This restores hole-punching for concealed cells (same as hidden and observed).

  **Step B — Expand `buildMidFog` to include unexplored + concealed cells** (`fog_geojson_builder.dart` lines 90-93):
  - Change from:
    ```dart
    // Only include hidden cells. Concealed stays under opaque fog.
    if (state != FogState.hidden) continue;
    ```
  - Change to:
    ```dart
    // Include unexplored (pre-rendered behind base fog), concealed, and hidden.
    // Undetected and observed are excluded.
    if (state == FogState.undetected || state == FogState.observed) continue;
    ```
  - Update the density property to use concealed density for unexplored cells (line 109):
    ```dart
    // Unexplored cells use concealed density (0.95) — pre-rendered behind
    // base fog so they're ready when the cell transitions to concealed.
    final density = state == FogState.unexplored
        ? FogState.concealed.density
        : state.density;
    ```
  - Change line 109 from `"density":${state.density}` to `"density":$density`

  **Step C — Update doc comments** in `fog_geojson_builder.dart`:
  - Line 35 buildBaseFog doc: Update to reflect that concealed cells now get holes
  - Line 50 inline comment: Update to explain new skip condition
  - Lines 73-82 buildMidFog doc: Update to reflect unexplored and concealed inclusion
  - Line 92 inline comment: Update to explain the pre-rendering strategy

  **Step D — Update tests** (`fog_geojson_builder_test.dart`):

  6 existing tests need updating:

  1. **Line 136**: `'with concealed cell does NOT punch a hole'` → Change to `'with concealed cell punches a hole'`. Assert `coordinates.length == 2` (exterior + 1 hole). Remove the "stays under opaque fog" reason.

  2. **Line 172-186**: `'multiple cells produce multiple holes'` → The test has observed + hidden + concealed. Currently expects 3 rings (exterior + 2 holes, concealed excluded). Now ALL THREE get holes, so expect 4 rings (exterior + 3 holes).

  3. **Line 252-261**: `'excludes concealed cells'` → Change to `'includes concealed cells with density 0.95'`. Assert features.length == 1, density == 0.95.

  4. **Line 281-288**: `'excludes unexplored cells'` → Change to `'includes unexplored cells with pre-rendered concealed density 0.95'`. Assert features.length == 1, density == 0.95.

  5. **Line 290-302**: `'multiple cells produce multiple features'` → Has hidden + concealed. Currently expects 1 feature (only hidden). Now expects 2 features (both included).

  6. **Line 318-338**: `'mixed states only includes hidden'` → Change name to `'mixed states includes unexplored, concealed, and hidden'`. Has observed + hidden + undetected + concealed + unexplored. Currently expects 1 feature. Now expects 3 features (hidden + concealed + unexplored). Update densities assertion to `{0.5, 0.95}`.

  2 new tests to add:

  7. **New**: `'unexplored cells use concealed density not their own'` — Verify that unexplored cells in mid-fog output have density 0.95 (not 1.0).

  8. **New**: `'pre-rendered unexplored mid-fog is invisible behind base fog'` — Verify that for an unexplored cell: buildBaseFog does NOT punch a hole (stays opaque) AND buildMidFog DOES include a polygon at 0.95 density. This proves the pre-rendering: polygon exists but is hidden behind opaque base.

  **Must NOT do**:
  - Do NOT change `buildCellBorders` — border styling is correct
  - Do NOT change `buildRestorationOverlay`
  - Do NOT change `FogState` density values
  - Do NOT change `FogOverlayController._buildGeoJson` cell filtering
  - Do NOT change the 3-layer fog architecture

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Two files, focused builder logic + test updates, well-defined assertions
  - **Skills**: []
    - No special skills needed — pure Dart logic and test updates
  - **Skills Evaluated but Omitted**:
    - `playwright`: Not needed for implementation, only for verification in Task 3

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Task 1)
  - **Blocks**: Task 3
  - **Blocked By**: None (can start immediately)

  **References**:

  **Pattern References** (existing code to follow):
  - `lib/features/map/utils/fog_geojson_builder.dart:36-71` — `buildBaseFog` current implementation. Focus on line 51 skip condition.
  - `lib/features/map/utils/fog_geojson_builder.dart:83-113` — `buildMidFog` current implementation. Focus on line 93 include condition and line 109 density property.
  - `lib/core/models/fog_state.dart:11-31` — FogState enum with density values. `concealed.density` = 0.95, `unexplored.density` = 1.0. Unexplored cells in mid-fog MUST use `FogState.concealed.density` (0.95), NOT `state.density` (1.0).

  **Test References** (testing patterns to follow):
  - `test/features/map/utils/fog_geojson_builder_test.dart:239-249` — Pattern for asserting mid-fog density values. Copy this pattern for new tests.
  - `test/features/map/utils/fog_geojson_builder_test.dart:113-123` — Pattern for asserting base-fog hole count. Use for concealed hole test update.

  **WHY Each Reference Matters**:
  - `fog_geojson_builder.dart:51`: This is the exact line to change for buildBaseFog — remove `|| state == FogState.concealed`.
  - `fog_geojson_builder.dart:93`: This is the exact condition to change for buildMidFog — expand from hidden-only to include unexplored+concealed.
  - `fog_state.dart:22`: Confirms `concealed.density` = 0.95 — the value to use for pre-rendered unexplored cells.
  - Test file lines: Each test that needs updating is listed with its line number and current assertion to change.

  **Acceptance Criteria**:

  - [ ] `buildBaseFog` punches holes for concealed cells (reverted)
  - [ ] `buildBaseFog` does NOT punch holes for unexplored or undetected cells (unchanged)
  - [ ] `buildMidFog` includes unexplored cells at density 0.95 (pre-rendered)
  - [ ] `buildMidFog` includes concealed cells at density 0.95
  - [ ] `buildMidFog` includes hidden cells at density 0.5 (unchanged)
  - [ ] `buildMidFog` excludes undetected and observed cells (unchanged)
  - [ ] All 6 updated tests pass with new assertions
  - [ ] Both new tests pass
  - [ ] `LD_LIBRARY_PATH=. flutter test test/features/map/utils/fog_geojson_builder_test.dart` → 0 failures
  - [ ] `flutter analyze` → 0 issues

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Fog builder tests all pass
    Tool: Bash
    Preconditions: Flutter SDK available via mise
    Steps:
      1. Run: eval "$(~/.local/bin/mise activate bash)" && LD_LIBRARY_PATH=. flutter test test/features/map/utils/fog_geojson_builder_test.dart
      2. Assert exit code 0
      3. Assert output shows 0 failures
    Expected Result: All fog builder tests pass including updated and new tests
    Failure Indicators: Any test failure
    Evidence: .sisyphus/evidence/task-2-fog-builder-tests.txt

  Scenario: Concealed cell gets base-fog hole (regression from round 2 fixed)
    Tool: Bash
    Preconditions: Task 2 changes applied
    Steps:
      1. Run: eval "$(~/.local/bin/mise activate bash)" && LD_LIBRARY_PATH=. flutter test test/features/map/utils/fog_geojson_builder_test.dart --name "concealed cell punches a hole"
      2. Assert exit code 0
    Expected Result: Test passes — concealed cells get holes in base fog again
    Failure Indicators: Test failure or test not found
    Evidence: .sisyphus/evidence/task-2-concealed-hole.txt

  Scenario: Unexplored cells pre-rendered in mid-fog at concealed density
    Tool: Bash
    Preconditions: Task 2 changes applied
    Steps:
      1. Run: eval "$(~/.local/bin/mise activate bash)" && LD_LIBRARY_PATH=. flutter test test/features/map/utils/fog_geojson_builder_test.dart --name "unexplored cells"
      2. Assert exit code 0
    Expected Result: Test passes — unexplored cells appear in mid-fog with density 0.95
    Failure Indicators: Test failure or density != 0.95
    Evidence: .sisyphus/evidence/task-2-unexplored-prerender.txt

  Scenario: Pre-rendered unexplored cell is invisible behind base fog
    Tool: Bash
    Preconditions: Task 2 changes applied
    Steps:
      1. Run: eval "$(~/.local/bin/mise activate bash)" && LD_LIBRARY_PATH=. flutter test test/features/map/utils/fog_geojson_builder_test.dart --name "invisible behind base fog"
      2. Assert exit code 0
    Expected Result: For unexplored cell: base fog has NO hole (opaque) AND mid-fog HAS polygon (pre-rendered)
    Failure Indicators: Test failure
    Evidence: .sisyphus/evidence/task-2-prerender-invisible.txt

  Scenario: Full test suite regression check
    Tool: Bash
    Preconditions: Flutter SDK available via mise
    Steps:
      1. Run: eval "$(~/.local/bin/mise activate bash)" && LD_LIBRARY_PATH=. flutter test
      2. Assert exit code 0
    Expected Result: 910+ tests pass, 0 failures
    Failure Indicators: Any test failure
    Evidence: .sisyphus/evidence/task-2-full-suite.txt

  Scenario: Static analysis clean
    Tool: Bash
    Preconditions: Flutter SDK available via mise
    Steps:
      1. Run: eval "$(~/.local/bin/mise activate bash)" && flutter analyze
      2. Assert output contains "No issues found"
    Expected Result: 0 issues
    Failure Indicators: Any analysis issue
    Evidence: .sisyphus/evidence/task-2-analyze.txt
  ```

  **Commit**: YES
  - Message: `🐛 fix(map): pre-render unexplored cells in mid-fog to prevent concealed transition flash`
  - Files: `lib/features/map/utils/fog_geojson_builder.dart`, `test/features/map/utils/fog_geojson_builder_test.dart`
  - Pre-commit: `LD_LIBRARY_PATH=. flutter test test/features/map/utils/fog_geojson_builder_test.dart`

- [x] 3. Deploy to Railway and verify in browser

  **What to do**:
  - Deploy the app to Railway: `eval "$(~/.local/bin/mise activate bash)" && railway up --ci`
  - Wait for deploy to complete
  - Open `https://fog-of-world-production.up.railway.app` in Playwright
  - Verify Bug A fix: player marker visible on page load without any keypress
  - Verify Bug B fix: concealed cells (adjacent to observed) are visually lighter than unexplored cells
  - Verify no flash during cell transitions

  **Must NOT do**:
  - Do NOT modify any source files in this task
  - Do NOT skip Playwright verification

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Deploy command + Playwright verification, no code changes
  - **Skills**: [`playwright`]
    - `playwright`: Required for browser-based visual verification of marker and fog rendering
  - **Skills Evaluated but Omitted**:
    - `git-master`: No git operations needed beyond what's already committed

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 2 (sequential after Wave 1)
  - **Blocks**: F1-F4
  - **Blocked By**: Task 1, Task 2

  **References**:

  **External References**:
  - Railway deploy URL: `https://fog-of-world-production.up.railway.app`
  - Deploy command: `eval "$(~/.local/bin/mise activate bash)" && railway up --ci`
  - Default player position: lat 45.9636, lon -66.6431 (from `keyboard_location_web.dart:19`)

  **WHY Each Reference Matters**:
  - Deploy URL: The exact URL to verify in Playwright
  - Default position: Where the player marker should appear on initial load

  **Acceptance Criteria**:

  - [ ] Railway deploy completes successfully
  - [ ] Player marker visible in screenshot taken before any user interaction
  - [ ] Concealed cells visually distinct from unexplored cells in fog rendering
  - [ ] No visible flash during cell state transitions

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Player marker visible on initial page load (Bug A verification)
    Tool: Playwright
    Preconditions: App deployed to Railway, fresh browser context
    Steps:
      1. Navigate to https://fog-of-world-production.up.railway.app
      2. Wait for map to fully load (wait for fog overlay to render, ~5 seconds)
      3. DO NOT press any keys or click
      4. Take screenshot of full page
      5. Assert: player marker element is visible (blue circle at center of map)
    Expected Result: Player marker is visible without any user interaction
    Failure Indicators: No marker visible, blank/empty center of map, marker at wrong position
    Evidence: .sisyphus/evidence/task-3-marker-on-load.png

  Scenario: Concealed cells visually differentiated from unexplored (Bug B verification)
    Tool: Playwright
    Preconditions: App deployed, marker visible on map
    Steps:
      1. Press arrow key to trigger movement and cell discovery
      2. Wait 2 seconds for fog state transitions to complete
      3. Take screenshot focused on cells adjacent to observed cell
      4. Visual assertion: concealed cells (immediately adjacent to player's observed cell) should appear slightly lighter than unexplored cells (farther away)
    Expected Result: Adjacent cells have visible fog differentiation (lighter than surrounding cells)
    Failure Indicators: All non-observed cells look identical, no visual difference between adjacent and distant cells
    Evidence: .sisyphus/evidence/task-3-concealed-differentiation.png

  Scenario: No flash during cell transition
    Tool: Playwright
    Preconditions: App deployed, marker visible
    Steps:
      1. Hold arrow key to move through cells continuously
      2. Observe adjacent cells transitioning from unexplored to concealed
      3. Take screenshot sequence during movement
      4. Assert: no frame shows uncovered map tiles in adjacent cells
    Expected Result: Smooth transition with no flash of underlying map
    Failure Indicators: Brief flash of map tiles visible during transition
    Evidence: .sisyphus/evidence/task-3-no-flash.png

  Scenario: Marker persists after movement (regression check)
    Tool: Playwright
    Preconditions: App deployed, marker visible on initial load
    Steps:
      1. Press arrow key once
      2. Wait 1 second
      3. Take screenshot
      4. Assert: player marker still visible at new position
    Expected Result: Marker visible both before and after first keypress
    Failure Indicators: Marker disappears on first keypress, or appears at wrong location
    Evidence: .sisyphus/evidence/task-3-marker-after-move.png
  ```

  **Commit**: YES
  - Message: `🚀 ci(deploy): deploy fog bug round 3 fixes to Railway`
  - Files: none (deploy only)

---

## Final Verification Wave (MANDATORY — after ALL implementation tasks)

> 4 review agents run in PARALLEL. ALL must APPROVE. Rejection → fix → re-run.

- [x] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists (read file, run command). For each "Must NOT Have": search codebase for forbidden patterns — reject with file:line if found. Check evidence files exist in `.sisyphus/evidence/`. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [x] F2. **Code Quality Review** — `unspecified-high`
  Run `flutter analyze` + `LD_LIBRARY_PATH=. flutter test`. Review all changed files for: unused imports, commented-out code, debug print statements left behind. Check that no unintended files were modified.
  Output: `Analyze [PASS/FAIL] | Tests [N pass/N fail] | Files [N clean/N issues] | VERDICT`

- [x] F3. **Real Browser QA** — `unspecified-high` (+ `playwright` skill)
  Navigate to `https://fog-of-world-production.up.railway.app`. Wait for map to load. Screenshot immediately (before any keypress) — verify player marker is visible. Screenshot fog cells — verify concealed cells are visually different from unexplored. Press arrow key — verify marker moves smoothly without disappearing. Save all screenshots to `.sisyphus/evidence/final-qa/`.
  Output: `Marker visible on load [YES/NO] | Concealed cells differentiated [YES/NO] | Movement smooth [YES/NO] | VERDICT`

- [x] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", read actual diff (`git diff HEAD~N`). Verify 1:1 — everything in spec was built (no missing), nothing beyond spec was built (no creep). Check "Must NOT do" compliance. Flag unaccounted changes.
  Output: `Tasks [N/N compliant] | Unaccounted [CLEAN/N files] | VERDICT`

---

## Commit Strategy

- **Commit 1** (after Task 1): `🐛 fix(map): subscribe to location stream before start to capture initial position`
  - Files: `lib/features/map/map_screen.dart`
  - Pre-commit: `LD_LIBRARY_PATH=. flutter test`

- **Commit 2** (after Task 2): `🐛 fix(map): pre-render unexplored cells in mid-fog to prevent concealed transition flash`
  - Files: `lib/features/map/utils/fog_geojson_builder.dart`, `test/features/map/utils/fog_geojson_builder_test.dart`
  - Pre-commit: `LD_LIBRARY_PATH=. flutter test test/features/map/utils/fog_geojson_builder_test.dart`

- **Commit 3** (after Task 3): `🚀 ci(deploy): deploy fog bug round 3 fixes to Railway`
  - Files: none (deploy only)

---

## Success Criteria

### Verification Commands
```bash
LD_LIBRARY_PATH=. flutter test                                    # All 910+ tests pass
flutter analyze                                                   # 0 issues
LD_LIBRARY_PATH=. flutter test test/features/map/utils/fog_geojson_builder_test.dart  # Fog builder tests pass
```

### Final Checklist
- [ ] Player marker visible on initial page load (no keypress needed)
- [ ] Concealed cells visually distinct from unexplored cells (0.95 vs 1.0 density)
- [ ] No flash on unexplored → concealed transition
- [ ] All "Must NOT Have" guardrails respected
- [ ] All tests pass, 0 analysis issues
- [ ] Deployed and verified on Railway
