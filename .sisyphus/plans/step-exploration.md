# Step-Based Cell Exploration

## TL;DR

> **Quick Summary**: Players spend accumulated pedometer steps (500 per cell) to explore adjacent cells by tapping on the map. Steps accumulate passively while the app is closed via the OS pedometer. Hop-based frontier expansion — can only tap cells adjacent to any previously visited cell.
> 
> **Deliverables**:
> - Step persistence (DB columns + repository + hydration wiring)
> - `FogStateResolver.visitCellRemotely()` — visit a cell without moving the player
> - `PlayerNotifier.spendSteps()` — step spending with balance validation
> - Map tap handler → cell selection → bottom sheet → "Explore" button
> - Cha-ching animation (shows steps gained while app was closed)
> - Web keyboard speed reduced 5x (both keyboard + D-pad)
> 
> **Estimated Effort**: Medium
> **Parallel Execution**: YES — 4 waves
> **Critical Path**: T3 (DB migration) → T5 (persistence wiring) → T6 (step hydration) → T8 (exploration flow)

---

## Context

### Original Request
"I want to be able to explore while the app is closed." After discussion, this became: use passively accumulated pedometer steps as currency to explore cells by tapping on them on the map.

### Interview Summary
**Key Discussions**:
- Background GPS tracking was considered and rejected — too complex, too many permissions, battery drain
- Steps-as-currency is elegant: pedometer already exists in the codebase, works while app is closed, no new permissions needed
- Hop-based frontier expansion chosen: can tap any cell adjacent to any previously visited cell (the entire exploration frontier, not just cells next to current position)
- Full visit effect: spending steps = same as physically walking into a cell (fog reveal + species discovery)
- 500 steps per cell: restrictive — steps feel precious. Cells are ~180m, real stride is ~0.7m, so 500 steps is ~2x the walking distance
- TDD approach for all new code

**Research Findings**:
- Step system exists but is incomplete: StepService + StepNotifier exist but are NOT wired, steps NOT persisted to DB
- FogStateResolver.onLocationUpdate() conflates moving player AND visiting cell — needs a new `visitCellRemotely()` method (Metis critical finding)
- MapLibre has onEvent callback but it's empty — no tap handler exists. Must use CellService.getCellId(lat, lon) for tap-to-cell resolution
- `explorationFrontier` already maintained in FogStateResolver — tracks all cells adjacent to any visited cell
- Web keyboard speed hardcoded in two files: keyboard_location_web.dart + dpad_controls.dart

### Metis Review
**Identified Gaps** (addressed):
- `visitCellRemotely()` method needed on FogStateResolver — conflated move+visit is a breaking issue
- Discovery integration: `visitCellRemotely()` must emit on `onVisitedCellAdded` stream so DiscoveryService reacts
- DB migration v10 needed for step columns (totalSteps, lastKnownStepCount)
- Stale seed guard should apply to step spending too (cell visited, no species roll)
- D-pad controls have duplicate speed constants — extract to shared/constants.dart
- Edge cases: rapid tapping, GPS visit while bottom sheet open, empty frontier at game start

---

## Work Objectives

### Core Objective
Enable players to spend passively accumulated pedometer steps to explore adjacent cells by tapping on the map, with the same effect as physically walking into the cell.

### Concrete Deliverables
- `FogStateResolver.visitCellRemotely(String cellId)` method
- `PlayerNotifier.spendSteps(int amount)` method with balance validation
- DB migration v10: `totalSteps` + `lastKnownStepCount` columns on `LocalPlayerProfileTable`
- Step persistence wiring in `ProfileRepository` + `_persistProfileState`
- StepNotifier hydration + live stream wiring in `gameCoordinatorProvider`
- Map tap handler → cell selection → cell info bottom sheet → "Explore (500 steps)" button
- Cha-ching animation UI showing steps gained while app was closed
- `kStepCostPerCell = 500` + `kWebKeyboardStepMeters` + `kWebKeyboardTickIntervalMs` in constants
- Web keyboard + D-pad speed reduced 5x

### Definition of Done
- [ ] `LD_LIBRARY_PATH=. flutter test` — all existing tests pass + new tests pass
- [ ] `flutter analyze` — no new errors or warnings
- [ ] Player can tap a frontier cell on the map, spend 500 steps, and see fog reveal + species discovery
- [ ] Steps persist across app restarts (write to DB, restore on hydration)
- [ ] Cha-ching animation shows steps gained while app was closed
- [ ] Web keyboard movement is 5x slower than current

### Must Have
- Frontier validation: can ONLY explore cells adjacent to any previously visited cell
- Balance validation: cannot spend more steps than available
- Full visit effect: fog reveal + species discovery (deterministic seed)
- Step persistence across app restarts
- Stale seed guard: if daily seed is stale, cell is visited but no species roll (same as GPS behavior)

### Must NOT Have (Guardrails)
- **MUST NOT** call `fogResolver.onLocationUpdate()` with tapped cell coords (moves player context)
- **MUST NOT** allow spending on already-visited cells or non-frontier cells
- **MUST NOT** add step UI to web platform (web has no pedometer)
- **MUST NOT** add new map layers (frontier glow, highlight effects) — existing fog system is sufficient
- **MUST NOT** add new Drift tables — only add columns to existing `LocalPlayerProfileTable`
- **MUST NOT** persist fog state (core design decision — only visitedCellIds are persisted)
- **MUST NOT** modify DiscoveryService — it already listens to `onVisitedCellAdded` stream
- **MUST NOT** add sound effects, multi-cell batch selection, or step gifting
- **MUST NOT** add species previews, habitat info, or restoration level to the cell info bottom sheet
- **MUST NOT** touch the rubber-band controller, camera system, or marker system

---

## Verification Strategy (MANDATORY)

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: YES (1,373 passing tests)
- **Automated tests**: TDD (RED → GREEN → REFACTOR)
- **Framework**: `flutter_test` only (no mockito/mocktail, hand-written mocks)
- **Run command**: `LD_LIBRARY_PATH=. flutter test`

### QA Policy
Every task MUST include agent-executed QA scenarios.
Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

- **Core logic**: Use Bash (`LD_LIBRARY_PATH=. flutter test <path>`) — run tests, assert pass/fail
- **UI widgets**: Use `testWidgets()` — render, tap, assert widget tree
- **DB migration**: Use integration tests with `NativeDatabase.memory()` — round-trip data
- **Web speed**: Use unit tests — verify constant values and speed calculations

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Foundation — 4 parallel, all independent):
├── Task 1: FogStateResolver.visitCellRemotely (TDD) [deep]
├── Task 2: PlayerNotifier.spendSteps (TDD) [quick]
├── Task 3: DB migration v10 — step columns + codegen [quick]
└── Task 4: Extract web keyboard speed constants + 5x reduction [quick]

Wave 2 (Wiring — 3 parallel, depend on Wave 1):
├── Task 5: Step persistence (ProfileRepo + _persistProfileState) (depends: T3) [unspecified-high]
├── Task 6: StepNotifier hydration + live stream wiring (depends: T3, T5) [unspecified-high]
└── Task 7: Map tap handler + cell selection state (depends: T1) [unspecified-high]

Wave 3 (UI + Integration — 2 parallel, depend on Wave 2):
├── Task 8: Cell info bottom sheet + exploration flow (depends: T1, T2, T5, T7) [visual-engineering]
└── Task 9: Cha-ching animation UI (depends: T6) [visual-engineering]

Wave 4 (End-to-end verification — 1 task):
└── Task 10: Integration tests — step persistence + frontier exploration round-trip (depends: all) [deep]

Wave FINAL (After ALL tasks — 4 parallel review agents):
├── Task F1: Plan compliance audit (oracle)
├── Task F2: Code quality review (unspecified-high)
├── Task F3: Real manual QA (unspecified-high)
└── Task F4: Scope fidelity check (deep)

Critical Path: T3 → T5 → T6 → T9 (cha-ching) AND T1 → T7 → T8 (exploration)
Parallel Speedup: ~60% faster than sequential
Max Concurrent: 4 (Wave 1)
```

### Dependency Matrix

| Task | Depends On | Blocks | Wave |
|------|-----------|--------|------|
| T1 | — | T7, T8 | 1 |
| T2 | — | T8 | 1 |
| T3 | — | T5, T6 | 1 |
| T4 | — | — | 1 |
| T5 | T3 | T6, T8 | 2 |
| T6 | T3, T5 | T9 | 2 |
| T7 | T1 | T8 | 2 |
| T8 | T1, T2, T5, T7 | T10 | 3 |
| T9 | T6 | T10 | 3 |
| T10 | all | F1-F4 | 4 |

### Agent Dispatch Summary

- **Wave 1**: 4 tasks — T1 → `deep`, T2 → `quick`, T3 → `quick`, T4 → `quick`
- **Wave 2**: 3 tasks — T5 → `unspecified-high`, T6 → `unspecified-high`, T7 → `unspecified-high`
- **Wave 3**: 2 tasks — T8 → `visual-engineering`, T9 → `visual-engineering`
- **Wave 4**: 1 task — T10 → `deep`
- **FINAL**: 4 tasks — F1 → `oracle`, F2 → `unspecified-high`, F3 → `unspecified-high`, F4 → `deep`

---

## TODOs

> Implementation + Test = ONE Task. Never separate.
> EVERY task MUST have: Recommended Agent Profile + Parallelization info + QA Scenarios.
> **A task WITHOUT QA Scenarios is INCOMPLETE. No exceptions.**

- [x] 1. FogStateResolver.visitCellRemotely (TDD)

  **What to do**:
  - RED: Write tests for a new `visitCellRemotely(String cellId)` method on `FogStateResolver` that:
    - Adds cellId to `_visitedCellIds`
    - Removes cellId from `_explorationFrontier`
    - Adds cellId's unvisited neighbors to `_explorationFrontier`
    - Emits `FogStateChangedEvent(cellId: cellId, oldState: <computed>, newState: FogState.hidden)` on `onVisitedCellAdded`
      - Note: newState is `hidden` (not `observed`) because the player is NOT physically there
    - Does NOT modify `_currentCellId`, `_currentNeighborIds`, `_playerLat`, or `_playerLon`
    - Silently no-ops if cellId is already in `_visitedCellIds`
    - Throws `ArgumentError` if cellId is NOT in `_explorationFrontier` (frontier validation)
  - GREEN: Implement `visitCellRemotely()` following the pattern of `onLocationUpdate()` lines 133–164 but WITHOUT the player position assignment (lines 134–139) and using `FogState.hidden` instead of `FogState.observed`
  - REFACTOR: Extract shared cell-visit logic into a private `_markCellVisited(String cellId, FogState newState)` helper used by both `onLocationUpdate()` and `visitCellRemotely()`
  - Test that `DiscoveryService` would receive the event — verify `onVisitedCellAdded` stream emits for remote visits (this is the integration point that triggers species discovery)

  **Must NOT do**:
  - MUST NOT modify `_currentCellId` or `_currentNeighborIds` (player hasn't moved)
  - MUST NOT change `_playerLat` / `_playerLon`
  - MUST NOT emit `FogState.observed` — remote visits are `FogState.hidden`
  - MUST NOT modify existing `onLocationUpdate()` behavior (only refactor shared logic out)

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Core game logic with subtle state machine semantics, stream emission ordering, and shared-logic refactoring. Needs careful reasoning about fog state transitions.
  - **Skills**: []
    - No specialized skills needed — pure Dart logic and flutter_test
  - **Skills Evaluated but Omitted**:
    - `playwright`: No browser interaction — pure unit tests

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2, 3, 4)
  - **Blocks**: T7, T8
  - **Blocked By**: None (can start immediately)

  **References**:

  **Pattern References** (existing code to follow):
  - `lib/core/fog/fog_state_resolver.dart:133-164` — `onLocationUpdate()` — the pattern to follow. Lines 141-163 are the cell-visit logic to extract into `_markCellVisited()`. The key difference: `visitCellRemotely()` skips lines 134-139 (position assignment) and uses `FogState.hidden` at line 157 instead of `FogState.observed`.
  - `lib/core/fog/fog_state_resolver.dart:172-193` — `loadVisitedCells()` — shows how frontier is rebuilt from scratch. The incremental frontier update in `onLocationUpdate()` (lines 150-154) is the pattern for `visitCellRemotely()`.
  - `lib/core/fog/fog_state_resolver.dart:78-79` — `onVisitedCellAdded` stream getter — remote visits MUST emit on this same stream so DiscoveryService picks them up without modification.

  **API/Type References**:
  - `lib/core/fog/fog_event.dart` — `FogStateChangedEvent(cellId, oldState, newState)` — the event type to emit
  - `lib/core/models/fog_state.dart` — `FogState` enum — use `FogState.hidden` for remote visits

  **Test References**:
  - `test/core/fog/fog_state_resolver_test.dart:1-60` — MockCellService pattern (deterministic grid-based cells, `cell_{lat}_{lon}` IDs, Chebyshev neighbors). Reuse this exact mock for new tests.
  - `test/core/fog/fog_state_resolver_test.dart` — existing test structure uses `group('FogStateResolver', ...)` with `setUp()` creating fresh resolver + mock service

  **WHY Each Reference Matters**:
  - `onLocationUpdate()` is the ONLY existing code path that adds to visitedCellIds — the new method must produce identical side effects (frontier update, event emission) minus the position mutation
  - `FogStateChangedEvent` is what DiscoveryService listens to — getting the event shape wrong breaks discovery
  - MockCellService determines test cell topology — using a different mock would make tests inconsistent

  **Acceptance Criteria**:

  - [ ] Test file created: `test/core/fog/fog_state_resolver_test.dart` (added tests within existing file)
  - [ ] `LD_LIBRARY_PATH=. flutter test test/core/fog/` → PASS (existing + new tests)
  - [ ] `visitCellRemotely('frontier_cell')` adds to visitedCellIds, updates frontier, emits event
  - [ ] `visitCellRemotely('already_visited')` is a silent no-op (no event, no state change)
  - [ ] `visitCellRemotely('non_frontier_cell')` throws ArgumentError
  - [ ] `onVisitedCellAdded` stream fires with `newState: FogState.hidden` (not observed)
  - [ ] `_currentCellId` and `_currentNeighborIds` are unchanged after remote visit
  - [ ] Existing `onLocationUpdate()` tests still pass (behavior unchanged)

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Remote visit to frontier cell succeeds
    Tool: Bash (LD_LIBRARY_PATH=. flutter test test/core/fog/)
    Preconditions: FogStateResolver with MockCellService, player at cell_0_0, cell_1_0 is in frontier
    Steps:
      1. Call visitCellRemotely('cell_1_0')
      2. Assert visitedCellIds contains 'cell_1_0'
      3. Assert explorationFrontier does NOT contain 'cell_1_0'
      4. Assert explorationFrontier contains cell_1_0's unvisited neighbors
      5. Assert stream emitted FogStateChangedEvent(cellId: 'cell_1_0', oldState: FogState.unexplored, newState: FogState.hidden)
      6. Assert currentCellId is still 'cell_0_0' (unchanged)
    Expected Result: All assertions pass. Cell visited remotely without moving player.
    Failure Indicators: currentCellId changed, event has FogState.observed, frontier not updated
    Evidence: .sisyphus/evidence/task-1-remote-visit-frontier.txt

  Scenario: Remote visit to non-frontier cell throws
    Tool: Bash (LD_LIBRARY_PATH=. flutter test test/core/fog/)
    Preconditions: FogStateResolver with MockCellService, player at cell_0_0
    Steps:
      1. Call visitCellRemotely('cell_99_99') — a cell far from any visited cell
      2. Assert ArgumentError is thrown
      3. Assert visitedCellIds is unchanged
      4. Assert no event emitted on onVisitedCellAdded
    Expected Result: ArgumentError thrown, no state mutation
    Failure Indicators: No error thrown, cell added to visited, event emitted
    Evidence: .sisyphus/evidence/task-1-remote-visit-non-frontier.txt

  Scenario: Remote visit to already-visited cell is no-op
    Tool: Bash (LD_LIBRARY_PATH=. flutter test test/core/fog/)
    Preconditions: FogStateResolver with cell_0_0 already visited
    Steps:
      1. Call visitCellRemotely('cell_0_0')
      2. Assert no event emitted
      3. Assert visitedCellIds size unchanged
    Expected Result: Silent no-op, no event, no error
    Failure Indicators: Event emitted, error thrown
    Evidence: .sisyphus/evidence/task-1-remote-visit-already-visited.txt
  ```

  **Evidence to Capture:**
  - [ ] task-1-remote-visit-frontier.txt — test output showing remote visit works
  - [ ] task-1-remote-visit-non-frontier.txt — test output showing validation
  - [ ] task-1-remote-visit-already-visited.txt — test output showing no-op

  **Commit**: YES
  - Message: `✨ feat(fog): add visitCellRemotely for step-based exploration`
  - Files: `lib/core/fog/fog_state_resolver.dart`, `test/core/fog/fog_state_resolver_test.dart`
  - Pre-commit: `LD_LIBRARY_PATH=. flutter test test/core/fog/`

- [x] 2. PlayerNotifier.spendSteps (TDD)

  **What to do**:
  - RED: Write tests for a new `spendSteps(int amount)` method on `PlayerNotifier` that:
    - Subtracts `amount` from `state.totalSteps`
    - Returns `true` on success
    - Returns `false` (and does NOT mutate state) if `amount > state.totalSteps`
    - Returns `false` if `amount <= 0`
  - GREEN: Implement `spendSteps()` in `PlayerNotifier` following the pattern of `addSteps()` at line 83-87
  - Test edge cases: spend exact balance (→ 0 remaining), spend more than balance (→ rejected), spend 0 (→ rejected), spend negative (→ rejected)

  **Must NOT do**:
  - MUST NOT allow spending more than available (overdraft)
  - MUST NOT modify any other PlayerState fields
  - MUST NOT add step spending to web platform handling (web steps are always 0)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple method addition with straightforward boolean logic. ~15 lines of implementation + ~50 lines of tests.
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - None — trivially simple task

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 3, 4)
  - **Blocks**: T8
  - **Blocked By**: None (can start immediately)

  **References**:

  **Pattern References**:
  - `lib/core/state/player_provider.dart:83-87` — `addSteps(int delta)` — exact pattern to follow, but subtract instead of add, with balance guard
  - `lib/core/state/player_provider.dart:73-78` — `setStreak()` — shows immutable state update via `copyWith()`

  **API/Type References**:
  - `lib/core/state/player_provider.dart` — `PlayerState` class (need `totalSteps` field), `PlayerNotifier` class

  **Test References**:
  - `test/core/state/player_provider_test.dart` — existing test file with ProviderContainer pattern, `addTearDown(container.dispose)`. Add new tests in a `group('spendSteps', ...)` block.

  **WHY Each Reference Matters**:
  - `addSteps()` is the inverse operation — `spendSteps()` mirrors it with a guard
  - PlayerState is immutable — must use `copyWith()` pattern, not field mutation

  **Acceptance Criteria**:

  - [ ] Test file updated: `test/core/state/player_provider_test.dart` (new group)
  - [ ] `LD_LIBRARY_PATH=. flutter test test/core/state/` → PASS
  - [ ] `spendSteps(500)` when totalSteps=1000 → true, totalSteps=500
  - [ ] `spendSteps(500)` when totalSteps=500 → true, totalSteps=0
  - [ ] `spendSteps(500)` when totalSteps=499 → false, totalSteps=499 (unchanged)
  - [ ] `spendSteps(0)` → false
  - [ ] `spendSteps(-1)` → false

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Spend steps with sufficient balance
    Tool: Bash (LD_LIBRARY_PATH=. flutter test test/core/state/)
    Preconditions: PlayerNotifier with totalSteps=1000 via ProviderContainer
    Steps:
      1. Call spendSteps(500)
      2. Assert returns true
      3. Assert container.read(playerProvider).totalSteps == 500
    Expected Result: true returned, balance reduced by 500
    Failure Indicators: Returns false, balance unchanged, balance negative
    Evidence: .sisyphus/evidence/task-2-spend-sufficient.txt

  Scenario: Spend steps with insufficient balance rejected
    Tool: Bash (LD_LIBRARY_PATH=. flutter test test/core/state/)
    Preconditions: PlayerNotifier with totalSteps=499
    Steps:
      1. Call spendSteps(500)
      2. Assert returns false
      3. Assert container.read(playerProvider).totalSteps == 499 (unchanged)
    Expected Result: false returned, no state mutation
    Failure Indicators: Returns true, balance changed, throws error
    Evidence: .sisyphus/evidence/task-2-spend-insufficient.txt
  ```

  **Evidence to Capture:**
  - [ ] task-2-spend-sufficient.txt
  - [ ] task-2-spend-insufficient.txt

  **Commit**: YES
  - Message: `✨ feat(player): add spendSteps with balance validation`
  - Files: `lib/core/state/player_provider.dart`, `test/core/state/player_provider_test.dart`
  - Pre-commit: `LD_LIBRARY_PATH=. flutter test test/core/state/`

- [x] 3. DB migration v10 — step columns + codegen

  **What to do**:
  - Add two columns to `LocalPlayerProfileTable`:
    - `IntColumn get totalSteps => integer().withDefault(const Constant(0))();`
    - `IntColumn get lastKnownStepCount => integer().withDefault(const Constant(0))();`
  - Bump `schemaVersion` from 9 to 10
  - Add migration block: `if (from < 10) { await m.addColumn(...totalSteps...); await m.addColumn(...lastKnownStepCount...); }`
  - Run `dart run build_runner build --delete-conflicting-outputs` to regenerate `app_database.g.dart`
  - Write a migration test: create v9 DB in memory, run migration to v10, verify columns exist with default 0 values
  - Verify existing integration tests still pass (they use `NativeDatabase.memory()` which creates fresh schema)

  **Must NOT do**:
  - MUST NOT add new tables — only add columns to existing `LocalPlayerProfileTable`
  - MUST NOT change any existing column types or defaults
  - MUST NOT forget to run build_runner (the generated file must be committed)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Mechanical schema change + codegen. Well-documented migration pattern exists (v8→v9 at line 243).
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - None — Drift migration is a known pattern in this codebase

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2, 4)
  - **Blocks**: T5, T6
  - **Blocked By**: None (can start immediately)

  **References**:

  **Pattern References**:
  - `lib/core/database/app_database.dart:168-188` — `LocalPlayerProfileTable` — add new columns after `lastLon` (line 182), before `createdAt` (line 183)
  - `lib/core/database/app_database.dart:206` — `schemaVersion => 9` — change to 10
  - `lib/core/database/app_database.dart:238-244` — v8→v9 migration pattern (`if (from < 9) { await m.addColumn(...); }`) — follow this exact pattern for v10

  **API/Type References**:
  - `lib/core/database/app_database.dart:170` — `@DataClassName('LocalPlayerProfile')` — the generated class will gain `totalSteps` and `lastKnownStepCount` int fields after codegen

  **Test References**:
  - `test/core/persistence/test_helpers.dart` — `createTestDatabase()` — uses `NativeDatabase.memory()` which creates fresh schema (migration test needs explicit v9 setup)

  **External References**:
  - Drift migration docs: `https://drift.simonbinder.eu/docs/advanced-features/migrations/` — `m.addColumn()` syntax

  **WHY Each Reference Matters**:
  - v8→v9 migration is the exact pattern to copy — same `if (from < N)` guard with `m.addColumn()`
  - `LocalPlayerProfileTable` definition determines where columns are added
  - Generated file MUST be committed — without codegen the `LocalPlayerProfile` dataclass won't have the new fields

  **Acceptance Criteria**:

  - [ ] `LocalPlayerProfileTable` has `totalSteps` (int, default 0) and `lastKnownStepCount` (int, default 0) columns
  - [ ] `schemaVersion` is 10
  - [ ] Migration from v9→v10 adds both columns via `m.addColumn()`
  - [ ] `app_database.g.dart` regenerated and committed
  - [ ] `LD_LIBRARY_PATH=. flutter test` → all existing tests pass
  - [ ] Migration test: v9 DB → v10 migration → columns readable with default 0

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Fresh database has step columns with defaults
    Tool: Bash (LD_LIBRARY_PATH=. flutter test test/core/database/)
    Preconditions: NativeDatabase.memory() with schema v10
    Steps:
      1. Create AppDatabase with in-memory executor
      2. Insert a player profile with only required fields (id, displayName)
      3. Read the profile back
      4. Assert totalSteps == 0
      5. Assert lastKnownStepCount == 0
    Expected Result: Default values present on new profiles
    Failure Indicators: Column not found error, null values, non-zero defaults
    Evidence: .sisyphus/evidence/task-3-fresh-db-defaults.txt

  Scenario: Existing tests pass after migration
    Tool: Bash (LD_LIBRARY_PATH=. flutter test)
    Preconditions: All code changes applied, codegen complete
    Steps:
      1. Run full test suite
      2. Assert all 1449+ tests pass
    Expected Result: Zero regressions
    Failure Indicators: Any test failure
    Evidence: .sisyphus/evidence/task-3-all-tests-pass.txt
  ```

  **Evidence to Capture:**
  - [ ] task-3-fresh-db-defaults.txt
  - [ ] task-3-all-tests-pass.txt

  **Commit**: YES
  - Message: `🗃️ feat(db): add step columns to player profile (v10 migration)`
  - Files: `lib/core/database/app_database.dart`, `lib/core/database/app_database.g.dart`, test file
  - Pre-commit: `LD_LIBRARY_PATH=. flutter test`

- [x] 4. Extract web keyboard speed constants + 5x reduction

  **What to do**:
  - Add 3 new constants to `lib/shared/constants.dart`:
    - `const double kWebKeyboardStepMeters = 2.0;` (was 10.0, now 5x slower)
    - `const int kWebKeyboardTickIntervalMs = 100;` (unchanged, but centralized)
    - `const double kEarthRadiusMeters = 6371000.0;` (was duplicated in both files)
  - Update `lib/features/location/services/keyboard_location_web.dart`:
    - Replace `static const _stepMeters = 10.0;` → `import constants.dart` and use `kWebKeyboardStepMeters`
    - Replace `static const _earthRadius = 6371000.0;` → use `kEarthRadiusMeters`
    - Replace `static const _tickInterval = Duration(milliseconds: 100);` → use `Duration(milliseconds: kWebKeyboardTickIntervalMs)`
  - Update `lib/features/map/widgets/dpad_controls.dart`:
    - Replace `static const _stepMeters = 10.0;` → use `kWebKeyboardStepMeters`
    - Replace `static const _earthRadius = 6371000.0;` → use `kEarthRadiusMeters`
    - Replace `static const _tickInterval = Duration(milliseconds: 100);` → use `Duration(milliseconds: kWebKeyboardTickIntervalMs)`
  - Write a test verifying the constant values (kWebKeyboardStepMeters == 2.0, etc.)
  - Remove the `static const` declarations from both source files after replacing with imports

  **Must NOT do**:
  - MUST NOT change tick interval (100ms is fine, just centralize it)
  - MUST NOT change any other behavior in keyboard or dpad
  - MUST NOT add step spending or step UI to web platform

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Mechanical extraction of 3 constants across 3 files. No logic changes.
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - None — trivial refactor

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2, 3)
  - **Blocks**: None (terminal task in its chain)
  - **Blocked By**: None (can start immediately)

  **References**:

  **Pattern References**:
  - `lib/features/location/services/keyboard_location_web.dart:15-17` — the 3 hardcoded constants to extract: `_stepMeters = 10.0`, `_earthRadius = 6371000.0`, `_tickInterval = Duration(milliseconds: 100)`
  - `lib/features/map/widgets/dpad_controls.dart:32-34` — duplicate constants: `_stepMeters = 10.0`, `_earthRadius = 6371000.0`, `_tickInterval = Duration(milliseconds: 100)`
  - `lib/shared/constants.dart` — where all game-balance constants live. Add after line 258 (kUpgradePromptDelaySeconds) or in a new "// Web Simulation" section

  **WHY Each Reference Matters**:
  - Both files have identical magic numbers — classic DRY violation. Centralizing prevents future drift.
  - `_stepMeters = 10.0` → `kWebKeyboardStepMeters = 2.0` is the actual 5x speed reduction

  **Acceptance Criteria**:

  - [ ] `kWebKeyboardStepMeters = 2.0` in `constants.dart`
  - [ ] `kWebKeyboardTickIntervalMs = 100` in `constants.dart`
  - [ ] `kEarthRadiusMeters = 6371000.0` in `constants.dart`
  - [ ] `keyboard_location_web.dart` uses imported constants (no local `static const`)
  - [ ] `dpad_controls.dart` uses imported constants (no local `static const`)
  - [ ] `LD_LIBRARY_PATH=. flutter test` → all tests pass
  - [ ] `flutter analyze` → no new warnings

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Constants have correct values
    Tool: Bash (LD_LIBRARY_PATH=. flutter test test/shared/)
    Preconditions: Constants defined in constants.dart
    Steps:
      1. Import constants.dart in test
      2. Assert kWebKeyboardStepMeters == 2.0
      3. Assert kWebKeyboardTickIntervalMs == 100
      4. Assert kEarthRadiusMeters == 6371000.0
    Expected Result: All values match spec
    Failure Indicators: Wrong values, import errors
    Evidence: .sisyphus/evidence/task-4-constants-values.txt

  Scenario: No hardcoded speed constants remain in source files
    Tool: Bash (grep -rn '_stepMeters\|_earthRadius\|_tickInterval' lib/features/location/services/keyboard_location_web.dart lib/features/map/widgets/dpad_controls.dart)
    Preconditions: Refactoring complete
    Steps:
      1. Grep for old static const declarations in both files
      2. Assert zero matches for `static const _stepMeters`
      3. Assert zero matches for `static const _earthRadius`
    Expected Result: No hardcoded constants remain
    Failure Indicators: Any grep match found
    Evidence: .sisyphus/evidence/task-4-no-hardcoded-constants.txt
  ```

  **Evidence to Capture:**
  - [ ] task-4-constants-values.txt
  - [ ] task-4-no-hardcoded-constants.txt

  **Commit**: YES
  - Message: `♻️ refactor(location): extract web keyboard speed to constants, reduce 5x`
  - Files: `lib/shared/constants.dart`, `lib/features/location/services/keyboard_location_web.dart`, `lib/features/map/widgets/dpad_controls.dart`, test file
  - Pre-commit: `LD_LIBRARY_PATH=. flutter test`

- [ ] 5. Step persistence — ProfileRepository + _persistProfileState wiring

  **What to do**:
  - Update `ProfileRepository.create()` to accept `totalSteps` and `lastKnownStepCount` parameters (with defaults of 0)
  - Update `ProfileRepository.update()` to accept `totalSteps` and `lastKnownStepCount` optional parameters
  - Update `_persistProfileState()` in `game_coordinator_provider.dart` to include `totalSteps` and `lastKnownStepCount` from `PlayerState` in both the SQLite write (lines 638-661) and the Supabase sync payload (lines 668-685)
  - Update `rehydrateData()` in `game_coordinator_provider.dart` (lines 335-343) to restore `totalSteps` and `lastKnownStepCount` from the profile row into `PlayerNotifier.loadProfile()`
  - Update `PlayerNotifier.loadProfile()` to accept and set `totalSteps` and `lastKnownStepCount` parameters
  - Write tests: persist steps → kill → rehydrate → verify steps restored

  **Must NOT do**:
  - MUST NOT add new tables — only use existing profile table with new columns from T3
  - MUST NOT change the hydration order (inventory → cells → profile) in rehydrateData
  - MUST NOT remove any existing parameters from _persistProfileState or rehydrateData

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Touches 3 files (profile_repository, game_coordinator_provider, player_provider) with careful wiring. Needs to understand the persistence flow.
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `playwright`: No browser needed

  **Parallelization**:
  - **Can Run In Parallel**: YES (with T6, T7 — but T5 must finish before T6)
  - **Parallel Group**: Wave 2
  - **Blocks**: T6, T8
  - **Blocked By**: T3 (needs DB columns to exist)

  **References**:

  **Pattern References**:
  - `lib/core/persistence/profile_repository.dart:11-36` — `create()` method — add `totalSteps` and `lastKnownStepCount` params, pass to `LocalPlayerProfile` constructor
  - `lib/core/persistence/profile_repository.dart:48-79` — `update()` method — add optional params, include in `copyWith()` chain
  - `lib/core/state/game_coordinator_provider.dart:624-689` — `_persistProfileState()` — add `playerState.totalSteps` and `playerState.lastKnownStepCount` to both SQLite write (line 638-661) and Supabase payload (line 668-685)
  - `lib/core/state/game_coordinator_provider.dart:335-343` — `rehydrateData()` profile hydration — add `totalSteps: profile.totalSteps, lastKnownStepCount: profile.lastKnownStepCount` to `loadProfile()` call

  **API/Type References**:
  - `lib/core/state/player_provider.dart:109+` — `loadProfile()` method — needs new `totalSteps` and `lastKnownStepCount` optional parameters

  **Test References**:
  - `test/core/persistence/profile_repository_test.dart` — existing profile repository tests, add step persistence round-trip
  - `test/core/persistence/test_helpers.dart` — `createTestDatabase()` for in-memory Drift

  **WHY Each Reference Matters**:
  - `_persistProfileState()` is the single write-through path for all profile state — if steps aren't included here, they'll be lost on app restart
  - `rehydrateData()` is the single restore path — if steps aren't read here, they won't be available after restart
  - `loadProfile()` is how rehydrated data reaches PlayerState — needs the new fields

  **Acceptance Criteria**:

  - [ ] `ProfileRepository.create()` accepts and persists `totalSteps` and `lastKnownStepCount`
  - [ ] `ProfileRepository.update()` accepts and persists step fields
  - [ ] `_persistProfileState()` writes `totalSteps` and `lastKnownStepCount` to SQLite + Supabase payload
  - [ ] `rehydrateData()` restores step fields from profile row to PlayerNotifier
  - [ ] `PlayerNotifier.loadProfile()` accepts and sets step fields
  - [ ] Round-trip test: set steps → persist → create new PlayerNotifier → rehydrate → assert steps match

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Steps round-trip through SQLite
    Tool: Bash (LD_LIBRARY_PATH=. flutter test test/core/persistence/)
    Preconditions: In-memory Drift database (v10), ProfileRepository
    Steps:
      1. Create profile with totalSteps=1500, lastKnownStepCount=42000
      2. Read profile back
      3. Assert totalSteps == 1500
      4. Assert lastKnownStepCount == 42000
      5. Update profile with totalSteps=2000
      6. Read again, assert totalSteps == 2000
    Expected Result: Step values persist and restore correctly
    Failure Indicators: Null values, zero values, column not found
    Evidence: .sisyphus/evidence/task-5-step-roundtrip.txt

  Scenario: Steps included in Supabase sync payload
    Tool: Bash (LD_LIBRARY_PATH=. flutter test test/core/state/)
    Preconditions: Mock or capture the jsonEncode payload in _persistProfileState
    Steps:
      1. Trigger _persistProfileState with playerState.totalSteps=1500
      2. Verify the JSON payload includes 'total_steps': 1500
      3. Verify the JSON payload includes 'last_known_step_count': value
    Expected Result: Sync payload includes step data
    Failure Indicators: Keys missing from payload
    Evidence: .sisyphus/evidence/task-5-sync-payload.txt
  ```

  **Evidence to Capture:**
  - [ ] task-5-step-roundtrip.txt
  - [ ] task-5-sync-payload.txt

  **Commit**: YES
  - Message: `🔧 chore(persistence): wire step persistence in profile repository`
  - Files: `lib/core/persistence/profile_repository.dart`, `lib/core/state/game_coordinator_provider.dart`, `lib/core/state/player_provider.dart`, tests
  - Pre-commit: `LD_LIBRARY_PATH=. flutter test`

- [ ] 6. StepNotifier hydration + live stream wiring in gameCoordinatorProvider

  **What to do**:
  - Import `step_provider.dart` in `game_coordinator_provider.dart`
  - In `rehydrateData()`, after profile hydration (line ~358), add step hydration:
    ```dart
    // 4. Hydrate step counter
    if (!kIsWeb) {
      final stepNotifier = ref.read(stepProvider.notifier);
      await stepNotifier.hydrate(
        lastKnownStepCount: profile?.lastKnownStepCount ?? 0,
        totalSteps: ref.read(playerProvider).totalSteps,
      );
    }
    ```
  - In `hydrateAndStart()`, after `startLoop()` call, add live stream start:
    ```dart
    if (!kIsWeb) {
      ref.read(stepProvider.notifier).startLiveStream();
    }
    ```
  - Add `ref.listen(stepProvider, ...)` or integrate step changes into the existing `ref.listen(playerProvider, ...)` write-through — the step deltas from StepNotifier already flow through `PlayerNotifier.addSteps()`, so the existing `playerProvider` listener should pick up step changes automatically. Verify this.
  - Add step lastKnownStepCount update: when StepNotifier updates OS baseline (after hydrate), ensure `PlayerNotifier.updateLastKnownStepCount()` is called, so the next persist captures the new baseline
  - Gate ALL step code with `if (!kIsWeb)` since web has no pedometer (StepService web stub returns 0)
  - Write test: mock StepService → hydrate → verify loginDelta computed → verify totalSteps updated

  **Must NOT do**:
  - MUST NOT call step hydration on web platform
  - MUST NOT change the existing hydration order (inventory → cells → profile → then steps)
  - MUST NOT block game loop start on step hydration failure
  - MUST NOT add a new provider listener — leverage the existing playerProvider write-through

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Wiring task that touches the coordinator provider (the most complex file at 1114 lines). Needs understanding of the hydration flow and platform-gating.
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `playwright`: No browser needed

  **Parallelization**:
  - **Can Run In Parallel**: YES (in Wave 2 group, but depends on T5 completing first for step persistence)
  - **Parallel Group**: Wave 2 (sequential dependency: T3 → T5 → T6)
  - **Blocks**: T9
  - **Blocked By**: T3, T5

  **References**:

  **Pattern References**:
  - `lib/core/state/game_coordinator_provider.dart:280-362` — `rehydrateData()` — add step hydration after line 358 (`lastPersistedProfile = ref.read(playerProvider);`). Guard with `if (!kIsWeb)`.
  - `lib/core/state/game_coordinator_provider.dart:364-400` — `hydrateAndStart()` — add `startLiveStream()` call after game loop starts (after line ~399)
  - `lib/features/steps/providers/step_provider.dart:79-107` — `hydrate()` method — takes `lastKnownStepCount` and `totalSteps`, computes login delta, calls `playerProvider.notifier.addSteps(delta)`
  - `lib/features/steps/providers/step_provider.dart:112-123` — `startLiveStream()` — subscribes to pedometer, forwards increments to `playerProvider`

  **API/Type References**:
  - `lib/features/steps/providers/step_provider.dart:138-139` — `stepProvider` declaration
  - `lib/core/state/player_provider.dart:83-92` — `addSteps()` and `updateLastKnownStepCount()` — already called by StepNotifier

  **Test References**:
  - Test with ProviderContainer + overridden StepService mock that returns deterministic step counts

  **WHY Each Reference Matters**:
  - `rehydrateData()` is the ONLY place profile data is restored — steps must be hydrated HERE so the login delta is computed from the persisted baseline
  - `startLiveStream()` must happen AFTER hydration (so `_lastStreamValue` is set correctly) and AFTER game loop starts
  - Platform gating (`!kIsWeb`) prevents crashes from the web StepService stub

  **Acceptance Criteria**:

  - [ ] `stepNotifier.hydrate()` called during `rehydrateData()` with persisted step values (native only)
  - [ ] `stepNotifier.startLiveStream()` called after game loop starts (native only)
  - [ ] Step changes flow through to `_persistProfileState()` via existing playerProvider listener
  - [ ] Web: no step code executes (guarded by `!kIsWeb`)
  - [ ] Login delta computed correctly: `currentOsSteps - lastKnownStepCount`
  - [ ] `LD_LIBRARY_PATH=. flutter test` → all tests pass

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Step hydration computes login delta on native
    Tool: Bash (LD_LIBRARY_PATH=. flutter test test/features/steps/)
    Preconditions: ProviderContainer with mocked StepService returning currentOsSteps=5000, persisted lastKnownStepCount=4500
    Steps:
      1. Trigger rehydrateData flow
      2. Assert stepProvider.loginDelta == 500
      3. Assert playerProvider.totalSteps increased by 500
      4. Assert stepProvider.isAnimating == true (cha-ching should play)
    Expected Result: Login delta correctly computed, player steps updated
    Failure Indicators: Delta is 0, steps not updated, hydrate not called
    Evidence: .sisyphus/evidence/task-6-hydration-delta.txt

  Scenario: Step hydration skipped on web
    Tool: Bash (LD_LIBRARY_PATH=. flutter test)
    Preconditions: kIsWeb == true context
    Steps:
      1. Run rehydrateData
      2. Assert stepProvider.notifier.hydrate() was NOT called
      3. Assert stepProvider.loginDelta == 0
    Expected Result: No step hydration on web
    Failure Indicators: Hydrate called, non-zero delta
    Evidence: .sisyphus/evidence/task-6-web-skip.txt
  ```

  **Evidence to Capture:**
  - [ ] task-6-hydration-delta.txt
  - [ ] task-6-web-skip.txt

  **Commit**: YES
  - Message: `🔧 chore(steps): wire StepNotifier hydration in gameCoordinatorProvider`
  - Files: `lib/core/state/game_coordinator_provider.dart`, test files
  - Pre-commit: `LD_LIBRARY_PATH=. flutter test`

- [ ] 7. Map tap handler + cell selection state

  **What to do**:
  - Implement `_onMapEvent()` in `map_screen.dart` (currently empty at line 622) to handle `MapEventClick`:
    ```dart
    void _onMapEvent(MapEvent event) {
      if (event is MapEventClick) {
        final lat = event.point.lat;
        final lon = event.point.lng;
        final cellId = cellService.getCellId(lat, lon);
        _onCellTapped(cellId);
      }
    }
    ```
  - Create `_onCellTapped(String cellId)` method that sets selected cell state (could be a simple `StatefulWidget` state variable or a lightweight Riverpod provider)
  - Create a new file `lib/features/map/providers/cell_selection_provider.dart` with a simple `StateProvider<String?>` for the selected cell ID (or use local StatefulWidget state if simpler)
  - The tap handler resolves screen coordinates → geographic position → cell ID using `CellService.getCellId(lat, lon)`
  - Wire `cellService` access in map_screen (already available via `ref.read(cellServiceProvider)`)
  - Do NOT show the bottom sheet yet (that's T8) — just set the selection state and log the cell ID
  - Write tests for the tap-to-cell resolution logic

  **Must NOT do**:
  - MUST NOT add a GestureDetector — use MapLibre's `onEvent` callback (already wired at line 677)
  - MUST NOT add fog highlighting, frontier glow, or cell outline effects
  - MUST NOT show UI yet — just the selection state. Bottom sheet is T8.
  - MUST NOT touch the rubber-band controller or camera system

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: MapLibre integration with coordinate conversion, needs to understand the existing event handler and map screen structure.
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `playwright`: Not useful for Dart/Flutter map event testing

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with T5, T6)
  - **Blocks**: T8
  - **Blocked By**: T1 (needs visitCellRemotely to exist for the full flow, but T7 only does tap→selection, not exploration)

  **References**:

  **Pattern References**:
  - `lib/features/map/map_screen.dart:622-632` — empty `_onMapEvent()` handler — this is where to add MapEventClick handling
  - `lib/features/map/map_screen.dart:677` — `onEvent: _onMapEvent` — already wired in the MapLibre widget builder
  - `lib/core/cells/cell_service.dart` — `getCellId(double lat, double lon)` — converts geographic position to cell ID

  **API/Type References**:
  - MapLibre `MapEventClick` — provides `point` as `Position(lng, lat)` — note longitude first! Access lat via `event.point.lat`, lon via `event.point.lng`
  - `lib/core/state/fog_resolver_provider.dart` — `fogResolverProvider` — access `fogResolver.visitedCellIds`, `fogResolver.explorationFrontier` for cell status
  - `lib/core/cells/cell_service.dart` — `getCellCenter(cellId)` returns `Geographic(lat:, lon:)` — useful for bottom sheet in T8

  **Test References**:
  - Unit test the cell resolution logic: given (lat, lon) → assert correct cellId returned via MockCellService
  - Widget test if using provider: set selection state → assert provider value

  **WHY Each Reference Matters**:
  - `MapEventClick` is the only way to detect user taps on the map — there's no `queryRenderedFeatures` in Dart MapLibre
  - `CellService.getCellId()` is the tap-to-cell resolution — no GeoJSON feature detection needed
  - `Position(lng, lat)` — longitude first is a critical gotcha

  **Acceptance Criteria**:

  - [ ] `_onMapEvent()` handles `MapEventClick` and resolves to cell ID
  - [ ] Selected cell ID stored in state (provider or local StatefulWidget state)
  - [ ] `MapEventClick.point` correctly parsed (lng first, lat second)
  - [ ] Cell selection testable in isolation (unit test for coordinate → cellId)
  - [ ] No UI changes visible yet (bottom sheet is T8)
  - [ ] `LD_LIBRARY_PATH=. flutter test` → all tests pass

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Map tap resolves to correct cell ID
    Tool: Bash (LD_LIBRARY_PATH=. flutter test test/features/map/)
    Preconditions: MockCellService that returns deterministic cellId for given lat/lon
    Steps:
      1. Simulate MapEventClick at Position(-66.6431, 45.9636) (Fredericton)
      2. Assert getCellId called with lat=45.9636, lon=-66.6431
      3. Assert selected cell ID matches expected value
    Expected Result: Correct cell ID resolved from map tap
    Failure Indicators: lat/lon swapped (common with Position(lng, lat)), wrong cell ID
    Evidence: .sisyphus/evidence/task-7-tap-cell-resolution.txt

  Scenario: Non-click map events are ignored
    Tool: Bash (LD_LIBRARY_PATH=. flutter test test/features/map/)
    Preconditions: Map event handler wired
    Steps:
      1. Send MapEventMoveCamera event
      2. Assert no cell selection changed
      3. Assert no getCellId call made
    Expected Result: Only MapEventClick triggers cell selection
    Failure Indicators: Selection changed on camera move
    Evidence: .sisyphus/evidence/task-7-non-click-ignored.txt
  ```

  **Evidence to Capture:**
  - [ ] task-7-tap-cell-resolution.txt
  - [ ] task-7-non-click-ignored.txt

  **Commit**: YES
  - Message: `✨ feat(map): add tap-to-cell selection handler`
  - Files: `lib/features/map/map_screen.dart`, `lib/features/map/providers/cell_selection_provider.dart` (if created), test files
  - Pre-commit: `LD_LIBRARY_PATH=. flutter test`

- [ ] 8. Cell info bottom sheet + exploration flow

  **What to do**:
  - Create `lib/features/map/widgets/cell_info_sheet.dart` — a modal bottom sheet shown when a frontier cell is tapped:
    ```dart
    class CellInfoSheet extends ConsumerWidget {
      final String cellId;
      const CellInfoSheet({required this.cellId, super.key});
      // Shows: cell ID label, cell status (frontier/visited/non-frontier),
      // step cost (kStepCostPerCell), current balance, "Explore" button
    }
    ```
  - Add constant `kStepCostPerCell = 500` to `lib/shared/constants.dart` (after line 258)
  - The bottom sheet reads:
    - `ref.watch(playerProvider).totalSteps` for current balance
    - `ref.read(fogResolverProvider).explorationFrontier.contains(cellId)` for frontier check
    - `ref.read(fogResolverProvider).visitedCellIds.contains(cellId)` for visited check
  - "Explore" button logic (in order):
    1. Check `totalSteps >= kStepCostPerCell` — if not, show disabled button with "Not enough steps (need 500)"
    2. Check `explorationFrontier.contains(cellId)` — if not frontier, show "Already explored" or "Not adjacent to explored area"
    3. Call `ref.read(playerProvider.notifier).spendSteps(kStepCostPerCell)` (from T2)
    4. Call `ref.read(fogResolverProvider).visitCellRemotely(cellId)` (from T1) — this triggers fog reveal + species discovery via `onVisitedCellAdded` stream
    5. Close bottom sheet
    6. (Discovery toast will fire automatically via DiscoveryService subscription to `onVisitedCellAdded`)
  - Wire the bottom sheet in `_onCellTapped(String cellId)` in `map_screen.dart` (from T7):
    ```dart
    void _onCellTapped(String cellId) {
      // Only show sheet for frontier cells or already visited cells (for info)
      showModalBottomSheet(
        context: context,
        builder: (ctx) => CellInfoSheet(cellId: cellId),
      );
    }
    ```
  - Stale seed guard: If `ref.read(dailySeedServiceProvider).isDiscoveryPaused`, still allow exploration (fog reveals) but show a warning: "Species discoveries paused — seed refreshing…". The `visitCellRemotely()` method handles this internally (cell gets visited, DiscoveryService checks seed before rolling species).
  - Edge case: if user is physically standing in the tapped cell (currentCellId == cellId), show "You're here!" instead of explore button
  - Edge case: rapid tapping — disable button after tap until sheet closes (use a local `_isExploring` flag)
  - Edge case: GPS visit while bottom sheet is open — if `fogResolver.visitedCellIds` changes to include the displayed cellId, update the sheet to show "Already explored"
  - Platform guard: On web, do NOT show step cost or explore button (web has no pedometer, totalSteps is always 0). Show cell info only. Check `kIsWeb` from `package:flutter/foundation.dart`.
  - Write TDD tests:
    - RED: Test that `CellInfoSheet` renders explore button for frontier cell with sufficient steps
    - GREEN: Implement the widget
    - RED: Test that explore button is disabled when steps < 500
    - GREEN: Add balance check
    - RED: Test that tapping explore calls spendSteps + visitCellRemotely
    - GREEN: Wire button action
    - RED: Test that non-frontier cell shows "Not adjacent" message
    - GREEN: Add frontier check
    - RED: Test that web platform hides explore button
    - GREEN: Add kIsWeb guard

  **Must NOT do**:
  - MUST NOT call `fogResolver.onLocationUpdate()` — use `visitCellRemotely()` only
  - MUST NOT modify DiscoveryService or its subscription mechanism
  - MUST NOT add cell outline/highlight/glow effects (visual polish is out of scope)
  - MUST NOT allow exploring non-frontier cells
  - MUST NOT allow exploring with insufficient steps (must check BEFORE calling spendSteps)
  - MUST NOT persist fog state directly (visitCellRemotely handles visitedCellIds, which are persisted via cell progress)
  - MUST NOT add haptics, sound effects, or particle effects

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: Bottom sheet UI with conditional rendering, button states, platform-aware layout. Requires Flutter widget knowledge and Riverpod consumer patterns.
  - **Skills**: [`frontend-ui-ux`]
    - `frontend-ui-ux`: Bottom sheet design, disabled/enabled button states, responsive layout for mobile/web
  - **Skills Evaluated but Omitted**:
    - `playwright`: Not applicable to Flutter widget tests

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with T9)
  - **Blocks**: T10
  - **Blocked By**: T1 (visitCellRemotely), T2 (spendSteps), T5 (step persistence so balance is real), T7 (tap handler + cell selection)

  **References**:

  **Pattern References**:
  - `lib/features/map/map_screen.dart:622-632` — `_onMapEvent()` from T7 — wire bottom sheet call in `_onCellTapped`
  - `lib/features/sanctuary/screens/sanctuary_screen.dart` — example of `showModalBottomSheet` usage in the codebase
  - `lib/features/discovery/widgets/discovery_toast.dart` — toast notification pattern (will fire automatically when `onVisitedCellAdded` emits)

  **API/Type References**:
  - `lib/core/fog/fog_state_resolver.dart:94` — `explorationFrontier` getter — the `Set<String>` of frontier cell IDs to check tapped cell against
  - `lib/core/fog/fog_state_resolver.dart:196-199` — `visitedCellIds` getter — to check if cell already visited
  - `lib/core/state/player_provider.dart:83-87` — `addSteps()` pattern — `spendSteps()` will follow same pattern (from T2)
  - `lib/features/steps/providers/step_provider.dart:14-41` — `StepState` — `loginDelta`, `isAnimating` for cha-ching context
  - `lib/core/services/daily_seed_service.dart` — `isDiscoveryPaused` — check before showing species warning

  **Test References**:
  - `test/core/fog/fog_state_resolver_test.dart:21-55` — `MockCellService` pattern for widget tests
  - `test/integration/offline_hydration_test.dart:32` — `makeInMemoryDb()` pattern for provider container setup

  **WHY Each Reference Matters**:
  - `explorationFrontier` is the gatekeeper — only frontier cells can be explored via steps
  - `visitCellRemotely()` must be called (not `onLocationUpdate`) — this is the Metis critical finding
  - `spendSteps()` must be called BEFORE `visitCellRemotely()` — spend first, explore second (optimistic but ordered)
  - `isDiscoveryPaused` determines whether to show "species paused" warning (stale seed)
  - MockCellService needed to deterministically control which cells are frontier vs visited in widget tests

  **Acceptance Criteria**:

  - [ ] `kStepCostPerCell = 500` constant added to `lib/shared/constants.dart`
  - [ ] `CellInfoSheet` widget created at `lib/features/map/widgets/cell_info_sheet.dart`
  - [ ] Bottom sheet shows cell ID, status, step cost, current balance
  - [ ] "Explore" button enabled only when: frontier cell AND steps >= 500 AND not web platform
  - [ ] Tapping "Explore" calls `spendSteps(500)` then `visitCellRemotely(cellId)`
  - [ ] Bottom sheet closes after successful exploration
  - [ ] Discovery toast fires automatically (via existing DiscoveryService subscription)
  - [ ] Disabled button shows reason: "Not enough steps" or "Not adjacent" or "Already explored"
  - [ ] Web platform shows cell info only, no explore button
  - [ ] Stale seed shows warning text but exploration still works (fog reveals, no species)
  - [ ] Rapid tap protection: button disabled after first tap
  - [ ] `LD_LIBRARY_PATH=. flutter test` → all tests pass

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Explore frontier cell with sufficient steps
    Tool: Bash (LD_LIBRARY_PATH=. flutter test test/features/map/widgets/)
    Preconditions: ProviderContainer with playerProvider (totalSteps=1000), fogResolver with cellId in explorationFrontier
    Steps:
      1. Render CellInfoSheet(cellId: 'v_10_10') inside MaterialApp
      2. Find ElevatedButton with text containing "Explore"
      3. Assert button is enabled
      4. Tap the button
      5. Assert playerProvider.totalSteps == 500 (1000 - 500)
      6. Assert fogResolver.visitCellRemotely was called with 'v_10_10'
    Expected Result: Steps deducted, cell visited, sheet closes
    Failure Indicators: Button disabled when it should be enabled, steps not deducted, visitCellRemotely not called
    Evidence: .sisyphus/evidence/task-8-explore-frontier.txt

  Scenario: Explore button disabled with insufficient steps
    Tool: Bash (LD_LIBRARY_PATH=. flutter test test/features/map/widgets/)
    Preconditions: ProviderContainer with playerProvider (totalSteps=200), cellId in explorationFrontier
    Steps:
      1. Render CellInfoSheet(cellId: 'v_10_10')
      2. Find button — assert it is disabled (onPressed == null)
      3. Find text containing "Not enough steps" or "need 500"
    Expected Result: Button disabled, reason text shown
    Failure Indicators: Button enabled with insufficient steps, no reason text
    Evidence: .sisyphus/evidence/task-8-insufficient-steps.txt

  Scenario: Non-frontier cell shows appropriate status
    Tool: Bash (LD_LIBRARY_PATH=. flutter test test/features/map/widgets/)
    Preconditions: ProviderContainer with cellId NOT in explorationFrontier and NOT in visitedCellIds
    Steps:
      1. Render CellInfoSheet(cellId: 'v_99_99')
      2. Assert no "Explore" button present (or button disabled)
      3. Find text indicating "Not adjacent to explored area"
    Expected Result: Cannot explore non-adjacent cells
    Failure Indicators: Explore button enabled for non-frontier cell
    Evidence: .sisyphus/evidence/task-8-non-frontier.txt

  Scenario: Web platform hides explore functionality
    Tool: Bash (LD_LIBRARY_PATH=. flutter test test/features/map/widgets/)
    Preconditions: Test simulates kIsWeb = true (or test verifies the conditional rendering logic)
    Steps:
      1. Render CellInfoSheet with kIsWeb guard active
      2. Assert no "Explore" button rendered
      3. Assert cell info (ID, status) still shown
    Expected Result: Web shows info only, no step spending
    Failure Indicators: Explore button visible on web
    Evidence: .sisyphus/evidence/task-8-web-no-explore.txt
  ```

  **Evidence to Capture:**
  - [ ] task-8-explore-frontier.txt
  - [ ] task-8-insufficient-steps.txt
  - [ ] task-8-non-frontier.txt
  - [ ] task-8-web-no-explore.txt

  **Commit**: YES
  - Message: `✨ feat(map): add cell info bottom sheet with step-based exploration`
  - Files: `lib/features/map/widgets/cell_info_sheet.dart`, `lib/features/map/map_screen.dart`, `lib/shared/constants.dart`, test files
  - Pre-commit: `LD_LIBRARY_PATH=. flutter test`

- [ ] 9. Cha-ching animation UI

  **What to do**:
  - Create `lib/features/steps/widgets/step_cha_ching.dart` — an overlay or inline widget that plays a count-up animation showing steps gained while the app was closed:
    ```dart
    class StepChaChing extends ConsumerWidget {
      // Watches stepProvider.loginDelta and stepProvider.isAnimating
      // When isAnimating == true: plays count-up from 0 → loginDelta
      // When animation completes: calls stepNotifier.markAnimationComplete()
    }
    ```
  - Animation spec:
    - Count-up from 0 to `loginDelta` over ~2 seconds
    - Use `AnimationController` + `Tween<int>` in a `ConsumerStatefulWidget` (needs StatefulWidget for animation controller)
    - Large centered number with a "+" prefix: "+1,234 steps"
    - Use `NumberFormat` from `intl` for comma formatting (check if already a dependency)
    - Frosted glass background using `FrostedGlassContainer` from `lib/shared/widgets/frosted_glass_container.dart`
    - Fade in → count up → hold 1s → fade out
    - Duration constants: `kChaChinCountUpDuration` (2s), `kChaChinHoldDuration` (1s), `kChaChinFadeDuration` (500ms) — add to `lib/shared/constants.dart`
  - Placement: Overlay in the map screen or tab shell, shown above everything. Should not block map interaction after animation completes.
  - Trigger: `ref.listen(stepProvider, ...)` — when `isAnimating` transitions from `false` to `true`, show the overlay
  - After animation completes: call `ref.read(stepProvider.notifier).markAnimationComplete()` — this sets `isAnimating = false` and `hasAnimated = true`
  - Skip animation if `loginDelta == 0` (no steps gained) — `isAnimating` will be false from hydration
  - Write TDD tests:
    - RED: Test that widget shows "+0" when loginDelta is 0
    - GREEN: Implement basic rendering
    - RED: Test that widget starts count-up when isAnimating is true
    - GREEN: Add animation controller
    - RED: Test that markAnimationComplete is called when animation finishes
    - GREEN: Wire completion callback
    - RED: Test that widget is not visible when hasAnimated is true
    - GREEN: Add visibility guard

  **Must NOT do**:
  - MUST NOT add sound effects or haptics
  - MUST NOT block map interaction during animation (overlay should ignore pointer after fade-out begins)
  - MUST NOT show animation on web (web steps are always 0, loginDelta will be 0, isAnimating will be false — naturally handled)
  - MUST NOT modify StepNotifier or StepState (those are from T6)
  - MUST NOT use third-party animation libraries (Flutter built-in AnimationController is sufficient)
  - MUST NOT show negative values or handle spend during animation (steps are only added during hydration)

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: Animation controller, overlay positioning, frosted glass styling, count-up number formatting — this is a pure UI/animation task.
  - **Skills**: [`frontend-ui-ux`]
    - `frontend-ui-ux`: Animation timing curves, overlay composition, visual polish
  - **Skills Evaluated but Omitted**:
    - `playwright`: Not applicable to Flutter widget animation tests

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with T8)
  - **Blocks**: T10
  - **Blocked By**: T6 (StepNotifier hydration + live stream — provides loginDelta and isAnimating state)

  **References**:

  **Pattern References**:
  - `lib/features/steps/providers/step_provider.dart:14-41` — `StepState` with `loginDelta`, `isAnimating`, `hasAnimated` — the state this widget reads
  - `lib/features/steps/providers/step_provider.dart:126-131` — `markAnimationComplete()` — called when animation finishes
  - `lib/shared/widgets/frosted_glass_container.dart` — frosted glass backdrop pattern — use for the cha-ching overlay background
  - `lib/shared/design_tokens.dart` — `Durations`, `AppCurves` — use existing animation tokens where possible

  **API/Type References**:
  - `lib/features/steps/providers/step_provider.dart:138-139` — `stepProvider` — the provider to `ref.watch()` and `ref.listen()`
  - `lib/shared/constants.dart` — where to add `kChaChinCountUpDuration`, `kChaChinHoldDuration`, `kChaChinFadeDuration`

  **Test References**:
  - `testWidgets()` with `tester.pumpAndSettle()` for animation tests
  - `ProviderScope(overrides: [...])` to inject test state for stepProvider

  **WHY Each Reference Matters**:
  - `StepState.isAnimating` is the animation trigger — widget must react to this transitioning to true
  - `markAnimationComplete()` must be called exactly once when animation ends — prevents re-triggering
  - `FrostedGlassContainer` maintains visual consistency with the rest of the app (frosted glass is the design language)
  - Design tokens ensure animation timings match the app's existing motion language

  **Acceptance Criteria**:

  - [ ] `StepChaChing` widget created at `lib/features/steps/widgets/step_cha_ching.dart`
  - [ ] Duration constants added to `lib/shared/constants.dart`: `kChaChinCountUpDuration`, `kChaChinHoldDuration`, `kChaChinFadeDuration`
  - [ ] Count-up animates from 0 → loginDelta over ~2 seconds
  - [ ] Number formatted with commas (e.g., "+1,234 steps")
  - [ ] Uses `FrostedGlassContainer` for backdrop
  - [ ] Fades in, counts up, holds, fades out
  - [ ] Calls `markAnimationComplete()` when animation finishes
  - [ ] Not shown when `loginDelta == 0` or `hasAnimated == true`
  - [ ] Does not block map interaction after fade-out
  - [ ] `LD_LIBRARY_PATH=. flutter test` → all tests pass

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Cha-ching animation plays on login with steps gained
    Tool: Bash (LD_LIBRARY_PATH=. flutter test test/features/steps/widgets/)
    Preconditions: ProviderContainer with stepProvider overridden to StepState(loginDelta: 1234, isAnimating: true, hasAnimated: false)
    Steps:
      1. Render StepChaChing inside MaterialApp with ProviderScope override
      2. Assert widget is visible (opacity > 0)
      3. Pump for 2.5 seconds (count-up + partial hold)
      4. Assert text contains "+1,234" (comma-formatted)
      5. Pump for remaining duration until animation completes
      6. Assert markAnimationComplete() was called on stepProvider.notifier
    Expected Result: Full count-up animation plays, completion callback fires
    Failure Indicators: Widget not visible, wrong number, markAnimationComplete not called
    Evidence: .sisyphus/evidence/task-9-chaaching-plays.txt

  Scenario: Cha-ching not shown when loginDelta is zero
    Tool: Bash (LD_LIBRARY_PATH=. flutter test test/features/steps/widgets/)
    Preconditions: ProviderContainer with stepProvider overridden to StepState(loginDelta: 0, isAnimating: false, hasAnimated: false)
    Steps:
      1. Render StepChaChing
      2. Assert widget is not visible (no text found, or opacity == 0)
    Expected Result: Nothing displayed — no animation for 0 steps
    Failure Indicators: Widget visible with "+0 steps"
    Evidence: .sisyphus/evidence/task-9-chaaching-zero.txt

  Scenario: Cha-ching not re-shown after animation completes
    Tool: Bash (LD_LIBRARY_PATH=. flutter test test/features/steps/widgets/)
    Preconditions: ProviderContainer with stepProvider at StepState(loginDelta: 500, isAnimating: false, hasAnimated: true)
    Steps:
      1. Render StepChaChing
      2. Assert widget is not visible
    Expected Result: Animation only plays once per session
    Failure Indicators: Animation re-triggers
    Evidence: .sisyphus/evidence/task-9-chaaching-no-replay.txt
  ```

  **Evidence to Capture:**
  - [ ] task-9-chaaching-plays.txt
  - [ ] task-9-chaaching-zero.txt
  - [ ] task-9-chaaching-no-replay.txt

  **Commit**: YES
  - Message: `✨ feat(steps): add cha-ching step count-up animation on app resume`
  - Files: `lib/features/steps/widgets/step_cha_ching.dart`, `lib/shared/constants.dart`, test files
  - Pre-commit: `LD_LIBRARY_PATH=. flutter test`

- [ ] 10. Integration tests — step persistence + frontier exploration round-trip

  **What to do**:
  - Create `test/integration/step_exploration_test.dart` — end-to-end integration tests that verify the complete step-based exploration pipeline:
  - **Test 1: Step persistence round-trip**
    1. Create in-memory `AppDatabase` (migration v10 with step columns)
    2. Create `ProfileRepository` + `PlayerNotifier`
    3. Set `totalSteps = 1500`, `lastKnownStepCount = 5000`
    4. Persist via `ProfileRepository.upsertProfile()`
    5. Read back from DB — assert `totalSteps == 1500`, `lastKnownStepCount == 5000`
    6. Simulate app restart: create new `ProfileRepository` from same DB
    7. Read profile — assert steps survived restart
  - **Test 2: Frontier exploration with step spending**
    1. Set up: `FogStateResolver` with `MockCellService`, load 3 visited cells, verify frontier computed
    2. `PlayerNotifier` with `totalSteps = 1000`
    3. Pick a frontier cell ID from `fogResolver.explorationFrontier`
    4. Call `playerNotifier.spendSteps(500)` — assert `totalSteps == 500`
    5. Call `fogResolver.visitCellRemotely(cellId)` — assert cell now in `visitedCellIds`
    6. Assert cell no longer in `explorationFrontier`
    7. Assert frontier expanded (new neighbors of explored cell added)
    8. Verify `onVisitedCellAdded` stream emitted event for the cell
  - **Test 3: Step spending rejected when insufficient balance**
    1. `PlayerNotifier` with `totalSteps = 300`
    2. Call `spendSteps(500)` — assert returns false (or throws)
    3. Assert `totalSteps` unchanged at 300
  - **Test 4: Frontier exploration with discovery integration**
    1. Set up `FogStateResolver` + `MockCellService` with frontier cell
    2. Set up `DiscoveryService` subscribed to `fogResolver.onVisitedCellAdded`
    3. Call `fogResolver.visitCellRemotely(frontierCellId)`
    4. Assert `onVisitedCellAdded` emitted
    5. Assert `DiscoveryService` received the event (species roll attempted)
    6. If daily seed is available: assert species encounter produced
  - **Test 5: Hydration → spend → persist round-trip**
    1. Seed DB with profile (totalSteps=2000, lastKnownStepCount=8000)
    2. Hydrate `PlayerNotifier` from DB via `ProfileRepository`
    3. Spend 500 steps via `spendSteps(500)`
    4. Assert `totalSteps == 1500`
    5. Persist to DB
    6. Read back — assert `totalSteps == 1500` persisted correctly
  - Follow the integration test patterns from `test/integration/offline_hydration_test.dart`:
    - `setUpAll(() { driftRuntimeOptions.dontWarnAboutMultipleDatabases = true; })`
    - `makeInMemoryDb()` for fresh DB per test
    - `ProviderContainer` with overrides for `appDatabaseProvider`
    - `addTearDown(container.dispose)` in each test

  **Must NOT do**:
  - MUST NOT mock the database — use real `NativeDatabase.memory()` for true integration testing
  - MUST NOT test UI widgets (that's in T8/T9 tests)
  - MUST NOT test the map tap handler (that's in T7 tests)
  - MUST NOT modify any production code — this task is test-only
  - MUST NOT require Supabase or network access — all tests use local SQLite only
  - MUST NOT test web-specific behavior (web step handling is a no-op)

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Integration tests require understanding the full data pipeline across multiple subsystems (DB ↔ Repository ↔ Provider ↔ FogResolver ↔ DiscoveryService). Needs careful setup of connected components.
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `playwright`: Not applicable — these are Dart integration tests, not browser tests

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 4 (solo — depends on all previous tasks)
  - **Blocks**: F1-F4 (final verification)
  - **Blocked By**: T1 (visitCellRemotely), T2 (spendSteps), T3 (DB migration), T5 (persistence wiring), T6 (step hydration), T7 (tap handler), T8 (exploration flow), T9 (cha-ching)

  **References**:

  **Pattern References**:
  - `test/integration/offline_hydration_test.dart:1-60` — integration test structure: setUpAll, makeInMemoryDb, ProviderContainer overrides, seedItem helpers
  - `test/integration/offline_persistence_test.dart` — SQLite round-trip test patterns (create → read → update → read back)
  - `test/integration/offline_discovery_test.dart` — DiscoveryService integration test pattern (species roll verification)
  - `test/integration/offline_fog_test.dart` — FogStateResolver integration patterns (loadVisitedCells, onLocationUpdate, state transitions)
  - `test/core/fog/fog_state_resolver_test.dart:21-55` — MockCellService pattern for deterministic cell geometry

  **API/Type References**:
  - `lib/core/fog/fog_state_resolver.dart` — `visitCellRemotely()` (from T1), `explorationFrontier`, `visitedCellIds`, `onVisitedCellAdded`
  - `lib/core/state/player_provider.dart` — `spendSteps()` (from T2), `addSteps()`, `totalSteps`
  - `lib/core/persistence/profile_repository.dart` — `upsertProfile()`, `getProfile()` — with step columns from T3/T5
  - `lib/core/database/app_database.dart` — migration v10 for step columns from T3
  - `test/core/persistence/test_helpers.dart:4-6` — `createTestDatabase()` helper

  **Test References**:
  - `test/integration/offline_hydration_test.dart:32` — `makeInMemoryDb()` factory
  - `test/integration/offline_hydration_test.dart:39-60` — `seedItem()` helper pattern — create similar `seedProfile()` for step data
  - `test/core/fog/fog_state_resolver_test.dart` — fog resolver test setup with MockCellService

  **WHY Each Reference Matters**:
  - `offline_hydration_test.dart` is the closest existing pattern — it tests the same pipeline (DB → repo → provider) for inventory; we replicate for steps
  - `offline_fog_test.dart` shows how to test fog state transitions end-to-end — we extend for `visitCellRemotely`
  - `MockCellService` is essential — we need deterministic cell geometry to set up frontier cells reliably
  - `driftRuntimeOptions.dontWarnAboutMultipleDatabases = true` is REQUIRED or tests will emit warnings

  **Acceptance Criteria**:

  - [ ] `test/integration/step_exploration_test.dart` created
  - [ ] Test 1: Step persistence survives DB round-trip (write → read → match)
  - [ ] Test 2: Frontier exploration deducts steps, visits cell, expands frontier, emits event
  - [ ] Test 3: Insufficient balance rejects spend (totalSteps unchanged)
  - [ ] Test 4: visitCellRemotely triggers DiscoveryService via onVisitedCellAdded
  - [ ] Test 5: Full hydrate → spend → persist → read round-trip
  - [ ] All tests use `NativeDatabase.memory()` (real SQLite, not mocks)
  - [ ] No Supabase or network access required
  - [ ] `setUpAll` includes `driftRuntimeOptions.dontWarnAboutMultipleDatabases = true`
  - [ ] `LD_LIBRARY_PATH=. flutter test test/integration/step_exploration_test.dart` → all tests pass
  - [ ] `LD_LIBRARY_PATH=. flutter test` → all tests pass (no regressions)

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: All step exploration integration tests pass
    Tool: Bash (LD_LIBRARY_PATH=. flutter test test/integration/step_exploration_test.dart)
    Preconditions: All prior tasks (T1-T9) completed and passing
    Steps:
      1. Run: LD_LIBRARY_PATH=. flutter test test/integration/step_exploration_test.dart --reporter expanded
      2. Assert exit code 0
      3. Assert all 5+ tests pass
      4. Capture full output
    Expected Result: All integration tests pass with 0 failures
    Failure Indicators: Any test failure, import errors (missing T1-T9 code), DB migration errors
    Evidence: .sisyphus/evidence/task-10-integration-all-pass.txt

  Scenario: Step persistence survives database round-trip
    Tool: Bash (LD_LIBRARY_PATH=. flutter test test/integration/step_exploration_test.dart --name "persistence")
    Preconditions: DB migration v10 applied (from T3)
    Steps:
      1. Run persistence-specific test
      2. Assert totalSteps and lastKnownStepCount survive write → read → new repo → read
    Expected Result: Step values identical before and after DB round-trip
    Failure Indicators: Null values, 0 values, migration errors
    Evidence: .sisyphus/evidence/task-10-persistence-roundtrip.txt

  Scenario: Full frontier exploration pipeline works end-to-end
    Tool: Bash (LD_LIBRARY_PATH=. flutter test test/integration/step_exploration_test.dart --name "frontier")
    Preconditions: FogStateResolver with visitCellRemotely (T1), PlayerNotifier with spendSteps (T2)
    Steps:
      1. Run frontier exploration test
      2. Assert: steps deducted → cell visited → frontier updated → event emitted → discovery triggered
    Expected Result: Complete pipeline from step spend to species discovery
    Failure Indicators: Event not emitted, frontier not updated, discovery not triggered
    Evidence: .sisyphus/evidence/task-10-frontier-pipeline.txt
  ```

  **Evidence to Capture:**
  - [ ] task-10-integration-all-pass.txt
  - [ ] task-10-persistence-roundtrip.txt
  - [ ] task-10-frontier-pipeline.txt

  **Commit**: YES
  - Message: `✅ test(integration): add step persistence + frontier exploration round-trip tests`
  - Files: `test/integration/step_exploration_test.dart`
  - Pre-commit: `LD_LIBRARY_PATH=. flutter test`

---

## Final Verification Wave (MANDATORY — after ALL implementation tasks)

> 4 review agents run in PARALLEL. ALL must APPROVE. Rejection → fix → re-run.

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists (read file, run test command). For each "Must NOT Have": search codebase for forbidden patterns — reject with file:line if found. Check evidence files exist in .sisyphus/evidence/. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run `flutter analyze` + `LD_LIBRARY_PATH=. flutter test`. Review all changed files for: `as dynamic`, unchecked casts, empty catches, console.log/debugPrint in prod paths, commented-out code, unused imports. Check that new Riverpod providers use Notifier pattern (NOT StateNotifier). Check that new constants are in shared/constants.dart.
  Output: `Analyze [PASS/FAIL] | Tests [N pass/N fail] | Files [N clean/N issues] | VERDICT`

- [ ] F3. **Real Manual QA** — `unspecified-high` (+ `playwright` skill if applicable)
  Start from clean state. Test: 1) Steps persist after restart (kill app, reopen, verify step count). 2) Tap frontier cell → bottom sheet → spend 500 steps → fog reveals → species discovered. 3) Tap non-frontier cell → explore button disabled. 4) Tap already-visited cell → no explore option. 5) Insufficient steps → explore button disabled. 6) Web keyboard movement is noticeably slower.
  Output: `Scenarios [N/N pass] | Edge Cases [N tested] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", read actual diff. Verify 1:1 — everything in spec was built (no missing), nothing beyond spec was built (no creep). Check "Must NOT do" compliance. Detect cross-task contamination: Task N touching Task M's files. Flag unaccounted changes.
  Output: `Tasks [N/N compliant] | Contamination [CLEAN/N issues] | Unaccounted [CLEAN/N files] | VERDICT`

---

## Commit Strategy

| Order | Message | Files | Pre-commit |
|-------|---------|-------|------------|
| 1 | `✨ feat(fog): add visitCellRemotely for step-based exploration` | fog_state_resolver.dart, fog_state_resolver_test.dart | `LD_LIBRARY_PATH=. flutter test test/core/fog/` |
| 2 | `✨ feat(player): add spendSteps with balance validation` | player_provider.dart, player_provider_test.dart | `LD_LIBRARY_PATH=. flutter test test/core/state/` |
| 3 | `🗃️ feat(db): add step columns to player profile (v10 migration)` | app_database.dart, app_database.g.dart, migration test | `LD_LIBRARY_PATH=. flutter test test/core/database/` |
| 4 | `♻️ refactor(location): extract web keyboard speed to constants, reduce 5x` | constants.dart, keyboard_location_web.dart, dpad_controls.dart | `LD_LIBRARY_PATH=. flutter test` |
| 5 | `🔧 chore(persistence): wire step persistence in profile repository` | profile_repository.dart, game_coordinator_provider.dart | `LD_LIBRARY_PATH=. flutter test` |
| 6 | `🔧 chore(steps): wire StepNotifier hydration in gameCoordinatorProvider` | game_coordinator_provider.dart, step_provider.dart | `LD_LIBRARY_PATH=. flutter test` |
| 7 | `✨ feat(map): add tap-to-cell selection with cell info bottom sheet` | map_screen.dart, cell_info_bottom_sheet.dart, cell_selection tests | `LD_LIBRARY_PATH=. flutter test` |
| 8 | `✨ feat(exploration): wire step-spending exploration flow` | exploration_service.dart (or inline), map_screen integration | `LD_LIBRARY_PATH=. flutter test` |
| 9 | `✨ feat(steps): add cha-ching animation for steps gained while away` | step animation widget, home/sanctuary screen integration | `LD_LIBRARY_PATH=. flutter test` |
| 10 | `✅ test(integration): add step persistence + frontier exploration round-trip` | integration test files | `LD_LIBRARY_PATH=. flutter test test/integration/` |

---

## Success Criteria

### Verification Commands
```bash
LD_LIBRARY_PATH=. flutter test                    # All tests pass (existing + new)
flutter analyze                                     # No new errors or warnings
LD_LIBRARY_PATH=. flutter test test/core/fog/       # visitCellRemotely tests pass
LD_LIBRARY_PATH=. flutter test test/core/state/     # spendSteps tests pass
LD_LIBRARY_PATH=. flutter test test/integration/    # Round-trip tests pass
```

### Final Checklist
- [ ] All "Must Have" present
- [ ] All "Must NOT Have" absent
- [ ] All tests pass (1,373 existing + new)
- [ ] `flutter analyze` clean
- [ ] Step persistence round-trip verified
- [ ] Frontier validation verified (frontier OK, non-frontier blocked, visited blocked)
- [ ] Web keyboard speed is 5x slower
