# Fix Fog-of-War Flash on Load and Transitions

## TL;DR

> **Quick Summary**: Prevent the base map from flashing through before fog layers initialize on load, and eliminate any potential transition flicker during cell state changes.
> 
> **Deliverables**:
> - Loading cover widget that hides the map until fog is composited
> - Restructured `_onStyleLoaded()` to eliminate async gap before fog init
> - Reordered initialization so `markReady()` fires after fog layers exist
> - Cleaned up double `_updateFogSources()` call in initial load path
> 
> **Estimated Effort**: Short
> **Parallel Execution**: NO — sequential (single file, interdependent changes)
> **Critical Path**: Task 1 → Task 2 → Task 3

---

## Context

### Original Request
"The map currently loads before the fog, revealing the entire map. Can we make sure that the fog implementation is tight so that we're not accidentally revealing the map on initial load or during cell transitions?"

### Interview Summary
**Key Discussions**:
- Root cause analysis traced the initial load flash to `_onStyleLoaded()` calling `markReady()` immediately, then deferring fog init to `addPostFrameCallback` — leaving 1+ frames with a visible, unfrogged map
- The transition flash was hypothesized to come from `Future.wait` reordering, but Metis analysis revealed that on web `setData()` is synchronous within one microtask — reordering `Future.wait` has no effect
- A double-fire of `_updateFogSources()` in `_onStyleLoaded` (once via `onBatchReady` callback, once after `updateAsync`) could contribute to initial load flicker

**Research Findings**:
- `updateGeoJsonSource` is synchronous on web (all three `setData()` calls execute in one microtask)
- `updateGeoJsonSource` is truly async on Android (`runOnPlatformThread` with JNI)
- `MapState.isReady` only has 2 consumers: `_processGameLogic()` (gates fog updates) and `DebugHud` (displays status text)
- Delaying `markReady()` is low-risk and actually correct — gates fog updates until layers exist

### Metis Review
**Identified Gaps** (addressed):
- `Future.wait` reordering is a no-op on web — **removed from plan**; kept as-is since web is synchronous and Android dispatches all three before any complete
- Double `_updateFogSources()` call (line 574 callback + line 579 direct) — **addressed in Task 1**: remove the redundant `onBatchReady` callback
- Cover widget needs `IgnorePointer` during fade-out — **addressed in Task 1**
- `mounted` guard needed after async gap when `addPostFrameCallback` is removed — **addressed in Task 1**
- Cover widget must be last child in Stack (on top of everything) — **addressed in Task 1**

---

## Work Objectives

### Core Objective
Ensure the base map tiles are never visible without fog composited on top, both during initial load and during gameplay fog state transitions.

### Concrete Deliverables
- Modified `lib/features/map/map_screen.dart` with loading cover + restructured init

### Definition of Done
- [ ] `LD_LIBRARY_PATH=. flutter test` — all 910+ tests pass
- [ ] `flutter analyze` — 0 issues
- [ ] On web: map loads with solid `#161620` cover, fog appears, cover fades out — no tile flash visible
- [ ] During gameplay: fog transitions between cell states with no visible tile flash

### Must Have
- Opaque loading cover that blocks map visibility until fog is initialized AND first data applied
- `markReady()` called only AFTER fog layers are initialized
- No `addPostFrameCallback` delay in fog initialization path
- `mounted` guards on all `setState` calls after async gaps
- `IgnorePointer` wrapper on cover widget during fade-out
- Cover color exactly matches fog color: `Color(0xFF161620)`

### Must NOT Have (Guardrails)
- DO NOT modify `MapState`, `MapStateNotifier`, or `map_state_provider.dart`
- DO NOT modify `_initFogLayers()` internals — only its call site changes
- DO NOT modify `_updateFogSources()` ordering or change from `Future.wait` to sequential
- DO NOT modify `FogOverlayController` or `fog_overlay_controller.dart`
- DO NOT add a new Riverpod provider for `_fogReady` — it's local widget state
- DO NOT add loading indicators (spinners, progress bars) to the cover
- DO NOT refactor `_onStyleLoaded` beyond the specified changes
- DO NOT touch `_processGameLogic()` or the 10Hz throttling
- DO NOT change fog color values (`#161620`)
- DO NOT add new imports (everything needed is already imported)

---

## Verification Strategy (MANDATORY)

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: YES
- **Automated tests**: Tests-after (verify no regressions)
- **Framework**: flutter_test
- **No new unit tests needed**: The changes are in widget lifecycle/render code that MapLibre platform views can't be unit-tested in headless mode. Verification is via existing regression suite + agent QA.

### QA Policy
Every task MUST include agent-executed QA scenarios.
Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

- **Code verification**: Read modified file, verify structure matches spec
- **Regression**: Run full test suite + analyzer
- **Deployment**: Build and deploy to Railway, verify in browser via Playwright

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Sequential — all changes are in one file, interdependent):
├── Task 1: Implement fog loading cover + restructure _onStyleLoaded [deep]
├── Task 2: Run tests + analyze to verify no regressions [quick]
└── Task 3: Deploy and verify in browser [quick]

Wave FINAL (After ALL tasks):
└── Task F1: Visual QA via Playwright [unspecified-high]

Critical Path: Task 1 → Task 2 → Task 3 → F1
Parallel Speedup: N/A (sequential, single file)
Max Concurrent: 1
```

### Dependency Matrix

| Task | Depends On | Blocks |
|------|-----------|--------|
| 1 | — | 2, 3 |
| 2 | 1 | 3 |
| 3 | 2 | F1 |
| F1 | 3 | — |

### Agent Dispatch Summary

- **Wave 1**: T1 → `deep`, T2 → `quick`, T3 → `quick`
- **FINAL**: F1 → `unspecified-high` (+ `playwright` skill)

---

## TODOs

- [x] 1. Implement fog loading cover + restructure `_onStyleLoaded`

  **What to do**:

  All changes are in `lib/features/map/map_screen.dart`. There are 4 modifications:

  **A. Add `_fogReady` state field** (near line 114, after `_fogLayersInitialized`):
  ```dart
  /// Whether fog layers are initialized AND first fog data has been applied.
  /// Until true, an opaque cover hides the map to prevent tile flash.
  bool _fogReady = false;
  ```

  **B. Restructure `_onStyleLoaded()` (line 552)**:
  
  Current code (REMOVE):
  ```dart
  void _onStyleLoaded() {
    MapLogger.styleLoaded();
    _removeTextLabels();
    ref.read(mapStateProvider.notifier).markReady();

    final viewportSize = MediaQuery.of(context).size;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _mapController == null) return;

      await _initFogLayers();

      final fogOverlayController = ref.read(fogOverlayControllerProvider);
      final camera = _mapController!.getCamera();

      await fogOverlayController.updateAsync(
        cameraLat: camera.center.lat.toDouble(),
        cameraLon: camera.center.lng.toDouble(),
        zoom: camera.zoom,
        viewportSize: viewportSize,
        onBatchReady: () {
          if (mounted) _updateFogSources();
        },
      );

      if (mounted) {
        await _updateFogSources();
      }
    });
  }
  ```

  Replace with:
  ```dart
  void _onStyleLoaded() {
    MapLogger.styleLoaded();
    _removeTextLabels();
    // NOTE: markReady() is deliberately NOT called here.
    // It moves to _after_ fog initialization below, so that
    // _processGameLogic() doesn't try to update fog sources
    // before the layers exist.

    _initFogAndReveal();
  }

  /// Initializes fog layers, computes initial fog state, updates sources,
  /// then marks the map ready and reveals it by fading out the cover.
  ///
  /// Extracted from [_onStyleLoaded] so the async flow is explicit.
  Future<void> _initFogAndReveal() async {
    // Capture viewport size synchronously before any async gap.
    final viewportSize = MediaQuery.of(context).size;

    await _initFogLayers();
    if (!mounted || _mapController == null) return;

    final fogOverlayController = ref.read(fogOverlayControllerProvider);
    final camera = _mapController!.getCamera();

    // Compute initial fog state. Skip onBatchReady callback — we call
    // _updateFogSources() once after updateAsync completes, avoiding the
    // previous double-fire that could flash partial fog data.
    await fogOverlayController.updateAsync(
      cameraLat: camera.center.lat.toDouble(),
      cameraLon: camera.center.lng.toDouble(),
      zoom: camera.zoom,
      viewportSize: viewportSize,
    );
    if (!mounted) return;

    await _updateFogSources();
    if (!mounted) return;

    // NOW mark the map ready (gates _processGameLogic fog updates)
    // and reveal the map by fading out the cover.
    ref.read(mapStateProvider.notifier).markReady();
    setState(() => _fogReady = true);
  }
  ```

  Key changes vs. current code:
  1. `markReady()` moved from top of `_onStyleLoaded` to AFTER fog init + first data applied
  2. `addPostFrameCallback` removed — `_initFogAndReveal()` called directly (fire-and-forget async)
  3. `onBatchReady` callback removed — single `_updateFogSources()` call after `updateAsync` completes (eliminates double-fire)
  4. `mounted` guards after every async gap
  5. `setState(() => _fogReady = true)` at the end triggers cover fade-out

  **C. Add loading cover widget to the `build()` method Stack**:

  Add as the **LAST child** of the Stack (line 811, after the MapControls `Positioned` widget, before the closing `]`):
  ```dart
  // ── Layer 6: Fog loading cover ──────────────────────────────────────
  // Opaque cover matching the fog color. Prevents base map tiles from
  // flashing through before fog layers are initialized. Fades out once
  // fog is ready, then becomes hit-test invisible.
  IgnorePointer(
    ignoring: _fogReady,
    child: AnimatedOpacity(
      opacity: _fogReady ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(color: const Color(0xFF161620)),
    ),
  ),
  ```

  This sits on top of ALL other layers (map, status bar, controls) during load. Once `_fogReady` flips to `true`:
  - `AnimatedOpacity` fades it out over 300ms
  - `IgnorePointer(ignoring: true)` passes through all touch events immediately

  **D. Verify `fogOverlayController.updateAsync` signature supports omitting `onBatchReady`**:

  Read `lib/features/map/controllers/fog_overlay_controller.dart` to confirm `onBatchReady` is an optional parameter. If it's required, pass `null` or an empty callback instead of omitting it.

  **Must NOT do**:
  - Do not modify `_initFogLayers()` internals
  - Do not modify `_updateFogSources()` internals or ordering
  - Do not modify `map_state_provider.dart`
  - Do not add new imports
  - Do not add spinners or progress indicators
  - Do not introduce a new Riverpod provider for `_fogReady`
  - Do not change fog color values

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Async lifecycle orchestration in a StatefulWidget requires careful reasoning about mount guards and execution order
  - **Skills**: []
    - No special skills needed — pure Dart/Flutter widget code
  - **Skills Evaluated but Omitted**:
    - `playwright`: Not needed for code changes — only for final QA
    - `frontend-ui-ux`: Not a design task — purely structural

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 1 (sequential)
  - **Blocks**: Task 2 (testing), Task 3 (deploy)
  - **Blocked By**: None

  **References** (CRITICAL):

  **Pattern References** (existing code to follow):
  - `lib/features/map/map_screen.dart:113-114` — `_fogLayersInitialized` flag pattern — follow the same bool flag pattern for `_fogReady`
  - `lib/features/map/map_screen.dart:552-587` — Current `_onStyleLoaded()` — this is the code being replaced
  - `lib/features/map/map_screen.dart:195-248` — `_initFogLayers()` — called from the new `_initFogAndReveal()`, do NOT modify
  - `lib/features/map/map_screen.dart:255-281` — `_updateFogSources()` — called from the new `_initFogAndReveal()`, do NOT modify
  - `lib/features/map/map_screen.dart:654-812` — Build method Stack — add cover widget as last child before closing `]`

  **API/Type References** (contracts to implement against):
  - `lib/features/map/providers/map_state_provider.dart:71-73` — `markReady()` method — call site moves, method unchanged
  - `lib/features/map/controllers/fog_overlay_controller.dart` — `updateAsync()` signature — verify `onBatchReady` is optional

  **Why Each Reference Matters**:
  - Line 113-114: Shows the exact pattern for declaring local bool state flags in this widget
  - Line 552-587: The code being replaced — executor must read this to understand current structure
  - Line 654-812: The Stack children list — executor must find the right insertion point for the cover widget
  - `map_state_provider.dart`: Confirms `markReady()` is a simple setter, safe to move

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Verify _fogReady flag exists and defaults to false
    Tool: Bash (grep)
    Preconditions: Task 1 changes applied
    Steps:
      1. grep -n '_fogReady' lib/features/map/map_screen.dart
      2. Verify: field declaration with `bool _fogReady = false`
      3. Verify: `setState(() => _fogReady = true)` exists after `_updateFogSources()`
      4. Verify: `_fogReady` is used in AnimatedOpacity and IgnorePointer
    Expected Result: _fogReady declared as false, set to true after fog init, used in cover widget
    Evidence: .sisyphus/evidence/task-1-fogready-grep.txt

  Scenario: Verify markReady() is NOT called before fog init
    Tool: Bash (grep)
    Preconditions: Task 1 changes applied
    Steps:
      1. grep -n 'markReady' lib/features/map/map_screen.dart
      2. Verify markReady() appears ONLY inside _initFogAndReveal(), AFTER _updateFogSources()
      3. Verify markReady() does NOT appear in _onStyleLoaded()
    Expected Result: Single markReady() call, positioned after fog sources are updated
    Evidence: .sisyphus/evidence/task-1-markready-position.txt

  Scenario: Verify addPostFrameCallback is removed from _onStyleLoaded
    Tool: Bash (grep)
    Preconditions: Task 1 changes applied
    Steps:
      1. grep -n 'addPostFrameCallback' lib/features/map/map_screen.dart
      2. Verify: zero matches (removed entirely)
    Expected Result: No addPostFrameCallback in the file
    Evidence: .sisyphus/evidence/task-1-no-postframe.txt

  Scenario: Verify cover widget is in Stack as last child
    Tool: Bash (grep + read)
    Preconditions: Task 1 changes applied
    Steps:
      1. Read the build() method
      2. Verify IgnorePointer with AnimatedOpacity is the last child before Stack closing bracket
      3. Verify Container color is Color(0xFF161620)
      4. Verify AnimatedOpacity duration is 300 milliseconds
    Expected Result: Cover widget is last Stack child with correct color and duration
    Evidence: .sisyphus/evidence/task-1-cover-widget.txt

  Scenario: Verify mounted guards exist after all async gaps
    Tool: Bash (grep)
    Preconditions: Task 1 changes applied
    Steps:
      1. Read _initFogAndReveal() method
      2. Count `await` statements
      3. Verify each `await` is followed by `if (!mounted) return;`
    Expected Result: Every async gap has a mounted guard
    Evidence: .sisyphus/evidence/task-1-mounted-guards.txt

  Scenario: Verify onBatchReady double-fire is eliminated
    Tool: Bash (grep)
    Preconditions: Task 1 changes applied
    Steps:
      1. grep -n 'onBatchReady' lib/features/map/map_screen.dart
      2. Verify: zero matches in _initFogAndReveal / _onStyleLoaded
    Expected Result: onBatchReady callback not used in initial load path
    Evidence: .sisyphus/evidence/task-1-no-batchready.txt
  ```

  **Commit**: YES
  - Message: `🐛 fix(map): prevent fog-of-war flash on initial load`
  - Files: `lib/features/map/map_screen.dart`
  - Pre-commit: `LD_LIBRARY_PATH=. flutter test && flutter analyze`

- [x] 2. Run tests + analyze to verify no regressions

  **What to do**:
  - Run the full test suite: `LD_LIBRARY_PATH=. flutter test`
  - Run the analyzer: `flutter analyze`
  - If any test fails, diagnose and fix (likely `mounted` guards or MapLibre mock issues)
  - If analyzer reports issues, fix them

  **Must NOT do**:
  - Do not skip failing tests — all must pass
  - Do not suppress analyzer warnings

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Running test commands and checking output
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - None relevant

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 1 (after Task 1)
  - **Blocks**: Task 3
  - **Blocked By**: Task 1

  **References**:
  - `test/` — Full test directory
  - `test/widget_test.dart` — Widget test that checks `find.byType(MapScreen)` — most likely to be affected

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Full test suite passes
    Tool: Bash
    Preconditions: Task 1 changes committed
    Steps:
      1. Run: LD_LIBRARY_PATH=. flutter test
      2. Verify: "All tests passed!" or "X tests passed, 0 failed"
      3. Capture test count (should be 910+)
    Expected Result: 910+ tests passing, 0 failures
    Evidence: .sisyphus/evidence/task-2-test-results.txt

  Scenario: Analyzer shows zero issues
    Tool: Bash
    Preconditions: Task 1 changes committed
    Steps:
      1. Run: flutter analyze
      2. Verify: "No issues found!" output
    Expected Result: 0 issues
    Evidence: .sisyphus/evidence/task-2-analyze-results.txt
  ```

  **Commit**: NO (testing only, commit was in Task 1)

- [ ] 3. Deploy to Railway and verify

  **What to do**:
  - Push to remote: `git push`
  - Deploy via Railway CLI: `eval "$(~/.local/bin/mise activate bash)" && railway up`
  - Monitor deployment logs for successful build
  - Verify the app loads at `https://fog-of-world-production.up.railway.app`

  **Must NOT do**:
  - Do not deploy if tests failed in Task 2

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Running deploy commands and monitoring output
  - **Skills**: [`playwright`]
    - `playwright`: Needed to navigate to deployed app and take verification screenshots
  - **Skills Evaluated but Omitted**:
    - None relevant

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 1 (after Task 2)
  - **Blocks**: Task F1
  - **Blocked By**: Task 2

  **References**:
  - `Dockerfile` — Railway deploy config (Flutter web build + nginx)
  - Railway domain: `https://fog-of-world-production.up.railway.app`

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Railway deployment succeeds
    Tool: Bash
    Preconditions: Tests pass, code pushed
    Steps:
      1. Run: eval "$(~/.local/bin/mise activate bash)" && railway up
      2. Monitor build output — verify "Build successful" or equivalent
      3. Wait for deployment to complete
    Expected Result: Deployment completes without errors
    Evidence: .sisyphus/evidence/task-3-deploy-log.txt

  Scenario: App loads in browser after deploy
    Tool: Playwright
    Preconditions: Deployment complete
    Steps:
      1. Navigate to https://fog-of-world-production.up.railway.app
      2. Wait for page to load (up to 30 seconds — Flutter web is slow to hydrate)
      3. Take screenshot
      4. Verify page contains the map view (dark fog overlay visible)
    Expected Result: App loads with fog overlay visible, no error screen
    Evidence: .sisyphus/evidence/task-3-app-loaded.png
  ```

  **Commit**: NO (deploy only)

---

## Final Verification Wave

- [ ] F1. **Visual QA via Playwright** — `unspecified-high` + `playwright` skill

  **What to do**:
  - Navigate to the deployed app at `https://fog-of-world-production.up.railway.app`
  - Observe initial load behavior — verify solid dark cover appears before any map tiles
  - Wait for fog to initialize and cover to fade out
  - Verify map is visible with fog overlay after cover fades
  - Take screenshots at key moments (cover visible, transition, fog visible)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: [`playwright`]

  **QA Scenarios**:

  ```
  Scenario: Initial load — no tile flash visible
    Tool: Playwright
    Preconditions: Fresh page load (no cache)
    Steps:
      1. Navigate to https://fog-of-world-production.up.railway.app
      2. Take screenshot immediately on page load (within 500ms)
      3. Wait 3 seconds for fog initialization
      4. Take screenshot after fog is initialized
      5. Verify first screenshot shows solid dark background (#161620), NOT map tiles
      6. Verify second screenshot shows fog overlay with revealed areas
    Expected Result: First screenshot is solid dark color, second shows fog-covered map
    Evidence: .sisyphus/evidence/task-F1-initial-load.png, .sisyphus/evidence/task-F1-fog-loaded.png

  Scenario: Page reload — no tile flash on subsequent loads
    Tool: Playwright
    Preconditions: App already loaded once
    Steps:
      1. Reload the page
      2. Take screenshot immediately on reload (within 500ms)
      3. Wait 3 seconds for fog re-initialization
      4. Verify screenshot shows solid dark background, not cached tiles
    Expected Result: Reload shows dark cover, not cached map tiles
    Evidence: .sisyphus/evidence/task-F1-reload-cover.png
  ```

  **Commit**: NO (verification only)

---

## Commit Strategy

| After Task | Message | Files | Pre-commit |
|-----------|---------|-------|------------|
| 1 + 2 | `🐛 fix(map): prevent fog-of-war flash on initial load` | `lib/features/map/map_screen.dart` | `LD_LIBRARY_PATH=. flutter test && flutter analyze` |

---

## Success Criteria

### Verification Commands
```bash
LD_LIBRARY_PATH=. flutter test   # Expected: All 910+ tests passing
flutter analyze                   # Expected: 0 issues
```

### Final Checklist
- [ ] All "Must Have" items present in implementation
- [ ] All "Must NOT Have" items absent from changes
- [ ] All 910+ tests pass
- [ ] `flutter analyze` shows 0 issues
- [ ] Deployed to Railway and visually verified — no tile flash on load
