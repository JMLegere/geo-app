# Fog of World — Architectural Refactor

## TL;DR

> **Quick Summary**: Clean up architectural debt in an otherwise well-structured Flutter fog-of-war game. Fix the auth↔sync circular dependency, eliminate 60fps full-widget rebuilds in map_screen, wrap global mutable state in providers, wire orphaned season providers, and document conventions.
> 
> **Deliverables**:
> - auth↔sync circular dependency broken (bootstrap moved to core/)
> - Global mutable `supabaseInitialized`/`supabaseReady` wrapped in a Riverpod provider
> - map_screen marker position decoupled from full widget rebuild (ValueNotifier)
> - `ref.watch(locationProvider)` removed from top-level build (scoped to specific consumers)
> - Season providers wired into discovery service
> - Shared layer documented
> - Repository race conditions fixed (transactions + batch delete)
> 
> **Estimated Effort**: Medium (3–5 days)
> **Parallel Execution**: YES — 4 waves
> **Critical Path**: Task 1 → Task 2 → Task 5 → Task 7 → Final Verification

---

## Context

### Original Request
"can you do a deep review and plan a clean refactor of the entire app. prioritize architectural rigour and codebase organization."

### Interview Summary
**Key Findings from 6 Explore Agents + Oracle + Metis**:
- **Provider topology is CLEAN**: 25 providers, zero circular deps, clean DAG, all coupling justified
- **Feature boundaries are GOOD**: 6 of 13 features fully isolated, only 1 circular dep (auth↔sync)
- **map_screen is a MODERATE god-widget**: 861 lines, 8 responsibilities, but only 60fps setState is critical
- **Test suite is HEALTHY**: 981 tests, zero anti-patterns, excellent mock quality
- **Persistence layer is SCAFFOLDING**: Repos exist but are never used in production — intentional MVP stage
- **Sync is PLACEHOLDER**: Write-through only, `syncNow()` is no-op — don't over-engineer

**Oracle Assessment**: "This codebase is genuinely well-architected. The refactoring scope is smaller than it might appear."

**Metis Findings**:
- Repos are orphaned (never instantiated in lib/) — Phases touching repos should be scoped carefully
- Dual rebuild path in map_screen: both `setState()` at 60fps AND `ref.watch(locationProvider)` trigger rebuilds
- Ticker lifecycle must stay in MapScreen even after marker extraction
- `supabase_bootstrap` Provider should be synchronous `Provider<SupabaseBootstrap>`, not `FutureProvider`

### Research Findings
- **Feature coupling**: map(3 deps, highest), discovery(4 dependents, hub), auth↔sync(circular)
- **map_screen**: 60fps setState triggers full tree rebuild; `ref.watch(locationProvider)` adds redundant rebuild trigger
- **Persistence**: All 3 repos complete but unused. Web DB is `NativeDatabase.memory()` — no persistence by design
- **Global state violation**: `supabaseInitialized` and `supabaseReady` are top-level mutable variables — the single AGENTS.md violation in the codebase

---

## Work Objectives

### Core Objective
Fix architectural debt (circular deps, global state, rebuild churn, orphaned providers) while preserving all existing behavior and test health.

### Concrete Deliverables
- `lib/core/config/supabase_bootstrap.dart` (moved from features/sync/services/)
- `SupabaseBootstrap` class wrapping global mutable state in a provider
- `_PlayerMarkerLayer` widget with `ValueNotifier` for 60fps marker updates
- `lib/shared/AGENTS.md` documenting shared layer conventions
- Season providers wired to discovery service
- Repo methods using Drift transactions

### Definition of Done
- [ ] `flutter analyze` → 0 issues
- [ ] `LD_LIBRARY_PATH=. flutter test` → all tests pass (≥981)
- [ ] `grep -r 'features/sync' lib/features/auth/ | wc -l` → 0 (no sync imports in auth)
- [ ] `grep -r 'bool supabaseInitialized' lib/ | wc -l` → 0 (no global mutable bool)
- [ ] map_screen `build()` does NOT contain `setState` for marker position
- [ ] map_screen `build()` does NOT contain top-level `ref.watch(locationProvider)`

### Must Have
- auth/ imports zero files from sync/ (circular dep broken)
- Global mutable `supabaseInitialized`/`supabaseReady` wrapped in a class + provider
- Marker position updates don't trigger full MapScreen rebuild
- Season service wired into discovery (seasonal species filtering works)
- All existing 981 tests pass after every change

### Must NOT Have (Guardrails)
- Do NOT split map_screen into 5+ widgets — only extract marker position path
- Do NOT move discovery models to core/ — coupling is through provider, not models
- Do NOT build sync queue, conflict resolution, or retry logic
- Do NOT wire repos into state notifiers (repos are intentional scaffolding)
- Do NOT implement startup hydration from database
- Do NOT add new seasonal behavior or season UI — only wire the provider
- Do NOT merge or restructure feature directories
- Do NOT change any model classes in `lib/core/models/`
- Do NOT change species encounter logic (deterministic seeding)
- Do NOT touch the onboarding feature
- Do NOT add inline JSDoc everywhere or create a docs/ folder
- Do NOT refactor sync service or move SupabasePersistence
- Do NOT delete orphaned repos (they're intentional forward scaffolding)

---

## Verification Strategy (MANDATORY)

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: YES (flutter_test, 81 test files)
- **Automated tests**: YES (Tests-after — add targeted tests for changed code)
- **Framework**: flutter_test (hand-written mocks, no mockito/mocktail)

### QA Policy
Every task MUST include agent-executed QA scenarios.
Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

- **Dart analysis**: `flutter analyze` → 0 issues
- **Test suite**: `LD_LIBRARY_PATH=. flutter test` → all pass
- **Import verification**: `grep` commands for cross-feature imports
- **UI verification**: Playwright for web deployment smoke test

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately — safety net + independent fixes):
├── Task 1: Safety net tests for bootstrap + auth init [quick]
├── Task 2: Document shared layer conventions [writing]
├── Task 3: Fix repository race conditions (transactions + batch delete) [quick]
└── Task 4: Wire season providers into discovery [quick]

Wave 2 (After Task 1 — depends on safety net):
├── Task 5: Break auth↔sync circular dependency [deep]
└── Task 6: Wrap supabase globals in provider [deep]

Wave 3 (After Wave 2 — depends on bootstrap refactor):
└── Task 7: Fix 60fps setState in map_screen [deep]

Wave FINAL (After ALL tasks — independent review, 4 parallel):
├── Task F1: Plan compliance audit [oracle]
├── Task F2: Code quality review [unspecified-high]
├── Task F3: Real QA — Playwright smoke test [unspecified-high]
└── Task F4: Scope fidelity check [deep]

Critical Path: Task 1 → Task 5 → Task 6 → Task 7 → Final Verification
Parallel Speedup: ~50% faster than sequential
Max Concurrent: 4 (Wave 1)
```

### Dependency Matrix

| Task | Depends On | Blocks | Wave |
|------|-----------|--------|------|
| 1 | — | 5, 6 | 1 |
| 2 | — | — | 1 |
| 3 | — | — | 1 |
| 4 | — | — | 1 |
| 5 | 1 | 6 | 2 |
| 6 | 5 | 7 | 2 |
| 7 | 6 | F1-F4 | 3 |
| F1-F4 | 7 | — | FINAL |

### Agent Dispatch Summary

- **Wave 1**: 4 tasks — T1→`quick`, T2→`writing`, T3→`quick`, T4→`quick`
- **Wave 2**: 2 tasks — T5→`deep`, T6→`deep`
- **Wave 3**: 1 task — T7→`deep`
- **FINAL**: 4 tasks — F1→`oracle`, F2→`unspecified-high`, F3→`unspecified-high`, F4→`deep`

---

## TODOs

- [ ] 1. Safety Net Tests for Bootstrap + Auth Init

  **What to do**:
  - Create `test/features/sync/services/supabase_bootstrap_test.dart` with tests for:
    - `initializeSupabase()` sets `supabaseInitialized = true` on success
    - `initializeSupabase()` sets `supabaseInitialized = false` when credentials missing
    - `supabaseReady` Future resolves immediately when no credentials
    - `supabaseReady` Future resolves after successful init
  - Create `test/features/auth/providers/auth_provider_init_test.dart` with tests for:
    - `AuthNotifier.build()` returns `AuthState.initial()` immediately
    - After init, falls back to `MockAuthService` when Supabase not configured
    - Auth state transitions: initial → authenticated (mock path)
  - Run full test suite to verify no regressions

  **Must NOT do**:
  - Don't test map_screen (too complex, not changing enough in this refactor)
  - Don't backfill all 29 HIGH-risk untested files
  - Don't use mockito/mocktail — use hand-written mocks per project convention

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Well-scoped test writing, clear inputs/outputs, <1hr work
  - **Skills**: []
    - No special skills needed — standard Flutter test writing
  - **Skills Evaluated but Omitted**:
    - `playwright`: Not needed for unit tests

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2, 3, 4)
  - **Blocks**: Tasks 5, 6 (auth/bootstrap changes need safety net first)
  - **Blocked By**: None (can start immediately)

  **References**:

  **Pattern References** (existing code to follow):
  - `test/features/auth/providers/auth_provider_test.dart` — Existing auth provider test structure, ProviderContainer setup pattern, hand-written mock for AuthService
  - `test/integration/offline_game_loop_test.dart:1-50` — Integration test pattern showing setUp/tearDown with NativeDatabase.memory()
  - `test/core/fog/fog_state_resolver_test.dart:1-30` — MockCellService example showing how to write production-quality hand-written mocks

  **API/Type References** (contracts to test against):
  - `lib/features/sync/services/supabase_bootstrap.dart:12-60` — The `supabaseInitialized` global, `supabaseReady` Future, and `initializeSupabase()` function that need test coverage
  - `lib/features/auth/providers/auth_provider.dart:30-55` — `AuthNotifier._initializeAuth()` method that awaits `supabaseReady` and creates auth service
  - `lib/features/auth/models/auth_state.dart` — AuthState class with `initial()`, `authenticated()`, `error()` factories

  **WHY Each Reference Matters**:
  - `auth_provider_test.dart` shows the exact ProviderContainer + addTearDown pattern used in this project — follow it exactly
  - `supabase_bootstrap.dart` is the file being tested — need to understand the global state pattern to mock it
  - `auth_provider.dart` shows the fire-and-forget async init pattern — tests must handle async completion

  **Acceptance Criteria**:
  - [ ] `test/features/sync/services/supabase_bootstrap_test.dart` exists with ≥3 tests
  - [ ] `test/features/auth/providers/auth_provider_init_test.dart` exists with ≥3 tests
  - [ ] `LD_LIBRARY_PATH=. flutter test` → all pass (≥981 + new tests)
  - [ ] `flutter analyze` → 0 issues

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: New bootstrap tests pass
    Tool: Bash
    Preconditions: Flutter SDK available via mise
    Steps:
      1. Run: eval "$(~/.local/bin/mise activate bash)" && LD_LIBRARY_PATH=. flutter test test/features/sync/services/supabase_bootstrap_test.dart
      2. Assert: exit code 0, output contains "All tests passed"
    Expected Result: All bootstrap tests pass
    Failure Indicators: Any test failure or compile error
    Evidence: .sisyphus/evidence/task-1-bootstrap-tests.txt

  Scenario: New auth init tests pass
    Tool: Bash
    Preconditions: Flutter SDK available via mise
    Steps:
      1. Run: eval "$(~/.local/bin/mise activate bash)" && LD_LIBRARY_PATH=. flutter test test/features/auth/providers/auth_provider_init_test.dart
      2. Assert: exit code 0, output contains "All tests passed"
    Expected Result: All auth init tests pass
    Failure Indicators: Any test failure or compile error
    Evidence: .sisyphus/evidence/task-1-auth-init-tests.txt

  Scenario: Full test suite still passes
    Tool: Bash
    Preconditions: Flutter SDK available via mise
    Steps:
      1. Run: eval "$(~/.local/bin/mise activate bash)" && LD_LIBRARY_PATH=. flutter test 2>&1 | tail -5
      2. Assert: "All tests passed" and count ≥ 984 (981 + 3 new minimum)
    Expected Result: No regressions, test count increased
    Failure Indicators: Any test failure, test count decreased
    Evidence: .sisyphus/evidence/task-1-full-suite.txt
  ```

  **Commit**: YES
  - Message: `✅ test(bootstrap): add safety net tests for supabase bootstrap and auth init`
  - Files: `test/features/sync/services/supabase_bootstrap_test.dart`, `test/features/auth/providers/auth_provider_init_test.dart`
  - Pre-commit: `LD_LIBRARY_PATH=. flutter test`

- [ ] 2. Document Shared Layer Conventions

  **What to do**:
  - Create `lib/shared/AGENTS.md` (≤100 lines) documenting:
    - Purpose of shared/ directory (UI utilities shared across features)
    - Allowed dependency: shared/ MAY import from core/models/ for enums used in theming
    - File inventory: constants.dart (game balance), app_theme.dart (Material theme + IUCN colors), habitat_colors.dart (habitat color palette), error_boundary.dart (error widget), empty_state_widget.dart (placeholder)
    - Convention: shared/ must NOT import from features/
    - Convention: features/ may import from shared/
  - Keep concise — this is a reference, not documentation

  **Must NOT do**:
  - Don't add inline JSDoc to every file
  - Don't create a docs/ folder
  - Don't document more than 100 lines
  - Don't move any files

  **Recommended Agent Profile**:
  - **Category**: `writing`
    - Reason: Documentation task, requires clear technical writing
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - All skills omitted — pure documentation task

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 3, 4)
  - **Blocks**: None
  - **Blocked By**: None (can start immediately)

  **References**:

  **Pattern References**:
  - `lib/core/AGENTS.md` — Existing AGENTS.md for core/ — follow same structure and tone
  - `lib/features/map/AGENTS.md` — Existing AGENTS.md for map feature — follow same conventions

  **API/Type References**:
  - `lib/shared/constants.dart` — Game balance constants (kDetectionRadiusMeters, etc.)
  - `lib/shared/app_theme.dart:2` — Imports `core/models/iucn_status.dart` (the allowed violation)
  - `lib/shared/habitat_colors.dart:2` — Imports `core/models/habitat.dart` (the allowed violation)
  - `lib/shared/widgets/error_boundary.dart` — Error boundary widget
  - `lib/shared/widgets/empty_state_widget.dart` — Empty state placeholder

  **WHY Each Reference Matters**:
  - Core AGENTS.md and map AGENTS.md show the documentation style — match it
  - The two files that import from core/ are the reason this doc exists — document WHY it's allowed
  - Each shared file needs a 1-line description for the inventory

  **Acceptance Criteria**:
  - [ ] `lib/shared/AGENTS.md` exists
  - [ ] File is ≤100 lines
  - [ ] Documents allowed core/ imports with rationale
  - [ ] Lists all shared/ files with purpose
  - [ ] `flutter analyze` → 0 issues (no Dart changes)

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: AGENTS.md exists and is within size limit
    Tool: Bash
    Preconditions: None
    Steps:
      1. Run: test -f lib/shared/AGENTS.md && wc -l lib/shared/AGENTS.md
      2. Assert: file exists, line count ≤ 100
    Expected Result: File exists with ≤100 lines
    Failure Indicators: File missing or exceeds 100 lines
    Evidence: .sisyphus/evidence/task-2-agents-md.txt

  Scenario: Document covers required topics
    Tool: Bash
    Preconditions: AGENTS.md exists
    Steps:
      1. Run: grep -c 'core/models' lib/shared/AGENTS.md
      2. Assert: count ≥ 1 (mentions the allowed import)
      3. Run: grep -c 'constants.dart\|app_theme.dart\|habitat_colors.dart' lib/shared/AGENTS.md
      4. Assert: count ≥ 3 (mentions key files)
    Expected Result: All required topics documented
    Failure Indicators: Missing coverage of key topics
    Evidence: .sisyphus/evidence/task-2-content-check.txt
  ```

  **Commit**: YES
  - Message: `📝 docs(shared): document shared layer conventions and allowed core imports`
  - Files: `lib/shared/AGENTS.md`
  - Pre-commit: `flutter analyze`

- [ ] 3. Fix Repository Race Conditions (Transactions + Batch Delete)

  **What to do**:
  - In `lib/core/persistence/cell_progress_repository.dart`:
    - Wrap `addDistance()` in `_db.transaction(() async { ... })`
    - Wrap `incrementVisitCount()` in `_db.transaction(() async { ... })`
    - Replace `getCellsByFogState()` in-memory filter with Drift WHERE clause: `..where((t) => t.fogState.equals(fogState.name))`
    - Replace `getCellCountByFogState()` in-memory count with WHERE clause + `.get().length` or Drift count expression
  - In `lib/core/persistence/collection_repository.dart`:
    - Replace `clearUserCollections()` load-all-then-loop-delete with single `DELETE FROM collected_species WHERE user_id = ?` using `(_db.delete(_db.localCollectedSpeciesTable)..where((t) => t.userId.equals(userId))).go()`
  - In `lib/core/persistence/profile_repository.dart`:
    - Wrap `incrementCurrentStreak()` in `_db.transaction(() async { ... })`
    - Wrap `addDistance()` in `_db.transaction(() async { ... })`
  - Add/update tests for the changed methods
  - Run `flutter analyze` and full test suite

  **Must NOT do**:
  - Don't add optimistic locking or retry logic
  - Don't refactor the repository API (keep same method signatures)
  - Don't wire repos into state notifiers (they're scaffolding)
  - Don't add input validation (separate concern)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Well-scoped changes to existing code, clear patterns, <2hr work
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - All omitted — standard Drift ORM changes

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2, 4)
  - **Blocks**: None
  - **Blocked By**: None (can start immediately)

  **References**:

  **Pattern References**:
  - `lib/core/persistence/cell_progress_repository.dart:85-105` — Current `addDistance()` read-modify-write pattern that needs transaction wrapping
  - `lib/core/persistence/collection_repository.dart:70-82` — Current `clearUserCollections()` loop-delete pattern that needs batch replacement
  - `test/core/persistence/cell_progress_repository_test.dart` — Existing tests to extend

  **API/Type References**:
  - `lib/core/database/app_database.dart:80-90` — `AppDatabase` class showing Drift table definitions
  - Drift docs: `https://drift.simonbinder.eu/docs/getting-started/writing_queries/#updates-and-deletes` — Drift transaction and batch delete API

  **WHY Each Reference Matters**:
  - `cell_progress_repository.dart:85-105` shows the exact read-modify-write pattern — wrap it, don't rewrite it
  - `collection_repository.dart:70-82` shows the loop-delete anti-pattern — replace with single DELETE WHERE
  - Drift docs show the `transaction()` API syntax and `delete()..where()` pattern

  **Acceptance Criteria**:
  - [ ] `addDistance()` in both repos wrapped in `_db.transaction()`
  - [ ] `incrementVisitCount()` wrapped in `_db.transaction()`
  - [ ] `incrementCurrentStreak()` wrapped in `_db.transaction()`
  - [ ] `clearUserCollections()` uses single DELETE WHERE (no loop)
  - [ ] `getCellsByFogState()` uses Drift WHERE clause (no in-memory filter)
  - [ ] `LD_LIBRARY_PATH=. flutter test` → all pass
  - [ ] `flutter analyze` → 0 issues

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Repository tests pass after transaction changes
    Tool: Bash
    Preconditions: Flutter SDK available
    Steps:
      1. Run: eval "$(~/.local/bin/mise activate bash)" && LD_LIBRARY_PATH=. flutter test test/core/persistence/
      2. Assert: exit code 0, all persistence tests pass
    Expected Result: All repository tests pass
    Failure Indicators: Test failures from changed transaction patterns
    Evidence: .sisyphus/evidence/task-3-repo-tests.txt

  Scenario: No in-memory filtering in getCellsByFogState
    Tool: Bash
    Preconditions: Changes applied
    Steps:
      1. Run: grep -A 10 'getCellsByFogState' lib/core/persistence/cell_progress_repository.dart
      2. Assert: contains `.where(` (Drift WHERE clause), does NOT contain `.where((cell) =>` (in-memory)
    Expected Result: Drift WHERE clause used instead of in-memory filter
    Failure Indicators: Still using in-memory `.where((cell) =>` pattern
    Evidence: .sisyphus/evidence/task-3-where-clause.txt

  Scenario: clearUserCollections uses batch delete
    Tool: Bash
    Preconditions: Changes applied
    Steps:
      1. Run: grep -A 10 'clearUserCollections' lib/core/persistence/collection_repository.dart
      2. Assert: contains `delete(` or `go()`, does NOT contain `for (` or `forEach(`
    Expected Result: Single DELETE WHERE, no loop
    Failure Indicators: Still loops over records
    Evidence: .sisyphus/evidence/task-3-batch-delete.txt
  ```

  **Commit**: YES
  - Message: `🐛 fix(persistence): add transactions and batch delete to repositories`
  - Files: `lib/core/persistence/cell_progress_repository.dart`, `lib/core/persistence/collection_repository.dart`, `lib/core/persistence/profile_repository.dart`
  - Pre-commit: `LD_LIBRARY_PATH=. flutter test`

- [ ] 4. Wire Season Providers into Discovery Service

  **What to do**:
  - Modify `lib/features/map/providers/discovery_service_provider.dart` to:
    - `ref.watch(seasonServiceProvider)` to get SeasonService
    - Pass SeasonService to DiscoveryService constructor or method
  - Modify `lib/features/discovery/services/species_service.dart` (or DiscoveryService — check which handles species filtering):
    - Accept SeasonService as a parameter
    - Use it to filter species by current season during encounter generation
    - Check `Species.seasonalAvailability` field against current season
  - Add test: species encounters respect seasonal availability
  - Verify `seasonProvider` is no longer orphaned (used transitively via seasonServiceProvider → discoveryServiceProvider)

  **Must NOT do**:
  - Don't add new seasonal behavior beyond filtering
  - Don't add season UI (season display, transition animations)
  - Don't modify the Season enum or seasonal model
  - Don't change the species data JSON

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Small wiring change + one test, <1hr work
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - All omitted — standard Riverpod wiring

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2, 3)
  - **Blocks**: None
  - **Blocked By**: None (can start immediately)

  **References**:

  **Pattern References**:
  - `lib/features/map/providers/discovery_service_provider.dart` — Current provider that already watches 4 other providers — add seasonServiceProvider as 5th
  - `lib/features/seasonal/providers/season_service_provider.dart` — The orphaned provider to wire in
  - `lib/features/seasonal/services/season_service.dart` — SeasonService API: `isAvailable(species, season)` or similar

  **API/Type References**:
  - `lib/core/models/season.dart` — Season enum (summer/winter)
  - `lib/features/discovery/services/species_service.dart` — SpeciesService that generates encounters — check if it already accepts season
  - `lib/core/species/loot_table.dart` — Loot table logic that may need season filter

  **WHY Each Reference Matters**:
  - `discovery_service_provider.dart` shows the existing watch pattern to follow
  - `season_service.dart` is the API being wired — understand its method signatures
  - `species_service.dart` or `loot_table.dart` is where the filter needs to be applied

  **Acceptance Criteria**:
  - [ ] `discoveryServiceProvider` watches `seasonServiceProvider`
  - [ ] Species encounter generation filters by current season
  - [ ] Test exists verifying seasonal filtering works
  - [ ] `grep -r 'seasonServiceProvider' lib/features/ | grep -v test | wc -l` ≥ 1
  - [ ] `LD_LIBRARY_PATH=. flutter test` → all pass
  - [ ] `flutter analyze` → 0 issues

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Season provider is wired into discovery
    Tool: Bash
    Preconditions: Changes applied
    Steps:
      1. Run: grep 'seasonServiceProvider' lib/features/map/providers/discovery_service_provider.dart
      2. Assert: contains `ref.watch(seasonServiceProvider)` or `ref.read(seasonServiceProvider)`
    Expected Result: Season service provider is consumed by discovery
    Failure Indicators: No reference to seasonServiceProvider
    Evidence: .sisyphus/evidence/task-4-wiring.txt

  Scenario: Full test suite passes with seasonal wiring
    Tool: Bash
    Preconditions: Flutter SDK available
    Steps:
      1. Run: eval "$(~/.local/bin/mise activate bash)" && LD_LIBRARY_PATH=. flutter test
      2. Assert: exit code 0, all tests pass
    Expected Result: No regressions from wiring change
    Failure Indicators: Test failures
    Evidence: .sisyphus/evidence/task-4-tests.txt
  ```

  **Commit**: YES
  - Message: `✨ feat(seasonal): wire season service into discovery for species filtering`
  - Files: `lib/features/map/providers/discovery_service_provider.dart`, `lib/features/discovery/services/species_service.dart`
  - Pre-commit: `LD_LIBRARY_PATH=. flutter test`

- [ ] 5. Break auth↔sync Circular Dependency

  **What to do**:
  - Move `lib/features/sync/services/supabase_bootstrap.dart` → `lib/core/config/supabase_bootstrap.dart`
  - Update ALL imports that reference the old path:
    - `lib/features/auth/providers/auth_provider.dart` (line 9)
    - `lib/features/sync/providers/sync_provider.dart` (line ~14)
    - `lib/main.dart` (line 10)
    - Any test files importing the old path
  - Verify the circular dependency is broken:
    - `grep -r 'features/sync' lib/features/auth/` → 0 results
    - auth/ imports from core/ and itself only
    - sync/ may still import from auth/ (one-directional is allowed)
  - Run full test suite

  **Must NOT do**:
  - Don't restructure the sync service
  - Don't move SupabasePersistence
  - Don't change the auth init flow
  - Don't refactor the global variables yet (that's Task 6)
  - Don't change any logic — purely mechanical file move + import update

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: File moves affect many imports — need careful grep + verify cycle
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `git-master`: Not needed — single commit, no complex git ops

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 2 (sequential after Wave 1)
  - **Blocks**: Task 6 (wrapping globals depends on bootstrap being in core/)
  - **Blocked By**: Task 1 (safety net tests must exist before modifying bootstrap)

  **References**:

  **Pattern References**:
  - `lib/features/sync/services/supabase_bootstrap.dart` — The file being moved (12-60 lines, contains globals + initializeSupabase())
  - `lib/core/config/supabase_config.dart` — Existing core/config file — confirms this is the right target directory

  **API/Type References**:
  - `lib/features/auth/providers/auth_provider.dart:9` — Current import: `import 'package:fog_of_world/features/sync/services/supabase_bootstrap.dart'`
  - `lib/features/sync/providers/sync_provider.dart:14` — Current import of supabaseInitialized
  - `lib/main.dart:10` — Current import of initializeSupabase

  **WHY Each Reference Matters**:
  - `supabase_bootstrap.dart` is the file being moved — understand its full API surface
  - `supabase_config.dart` confirms core/config/ exists and is the right location for Supabase infrastructure
  - The 3 import sites are the exact lines that need updating

  **Acceptance Criteria**:
  - [ ] `lib/core/config/supabase_bootstrap.dart` exists (moved from sync/)
  - [ ] `lib/features/sync/services/supabase_bootstrap.dart` does NOT exist (deleted)
  - [ ] `grep -r 'features/sync' lib/features/auth/ | wc -l` → 0
  - [ ] `grep -r 'features/auth' lib/features/sync/services/ | wc -l` → 0
  - [ ] `LD_LIBRARY_PATH=. flutter test` → all pass
  - [ ] `flutter analyze` → 0 issues

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Circular dependency is broken
    Tool: Bash
    Preconditions: File moved and imports updated
    Steps:
      1. Run: grep -r 'features/sync' lib/features/auth/
      2. Assert: 0 matches (auth does not import from sync)
      3. Run: grep -r 'features/auth' lib/features/sync/services/
      4. Assert: 0 matches (sync services don't import from auth)
    Expected Result: No cross-imports between auth↔sync at the service level
    Failure Indicators: Any grep match means circular dep still exists
    Evidence: .sisyphus/evidence/task-5-circular-dep.txt

  Scenario: Bootstrap file moved correctly
    Tool: Bash
    Preconditions: Changes applied
    Steps:
      1. Run: test -f lib/core/config/supabase_bootstrap.dart && echo "EXISTS" || echo "MISSING"
      2. Assert: "EXISTS"
      3. Run: test -f lib/features/sync/services/supabase_bootstrap.dart && echo "OLD EXISTS" || echo "OLD GONE"
      4. Assert: "OLD GONE"
    Expected Result: File exists at new path, removed from old path
    Failure Indicators: File missing at new path or still exists at old path
    Evidence: .sisyphus/evidence/task-5-file-move.txt

  Scenario: All tests pass after import changes
    Tool: Bash
    Preconditions: Flutter SDK available
    Steps:
      1. Run: eval "$(~/.local/bin/mise activate bash)" && flutter analyze
      2. Assert: 0 issues
      3. Run: eval "$(~/.local/bin/mise activate bash)" && LD_LIBRARY_PATH=. flutter test
      4. Assert: all pass
    Expected Result: Zero regressions
    Failure Indicators: Analyze errors or test failures
    Evidence: .sisyphus/evidence/task-5-tests.txt
  ```

  **Commit**: YES
  - Message: `♻️ refactor(auth): break auth↔sync circular dependency by moving bootstrap to core`
  - Files: `lib/core/config/supabase_bootstrap.dart`, `lib/features/auth/providers/auth_provider.dart`, `lib/features/sync/providers/sync_provider.dart`, `lib/main.dart`
  - Pre-commit: `flutter analyze && LD_LIBRARY_PATH=. flutter test`

- [ ] 6. Wrap Supabase Globals in SupabaseBootstrap Provider

  **What to do**:
  - Refactor `lib/core/config/supabase_bootstrap.dart` (moved in Task 5):
    - Create `SupabaseBootstrap` class that encapsulates:
      - `bool initialized` (was global `supabaseInitialized`)
      - `Future<void> ready` (was global `supabaseReady`)
      - `Future<void> initialize()` method (was global `initializeSupabase()`)
    - Remove the top-level mutable `supabaseInitialized` and `supabaseReady` variables
  - Create `lib/core/state/supabase_bootstrap_provider.dart`:
    - `final supabaseBootstrapProvider = Provider<SupabaseBootstrap>((ref) { ... });`
    - Use synchronous `Provider`, NOT `FutureProvider` — the class holds the Future internally
    - Wire `ref.onDispose()` for cleanup if needed
  - Update consumers:
    - `lib/features/auth/providers/auth_provider.dart` — `await ref.read(supabaseBootstrapProvider).ready` instead of `await supabaseReady`
    - `lib/features/sync/providers/sync_provider.dart` — `ref.read(supabaseBootstrapProvider).initialized` instead of `supabaseInitialized`
    - `lib/main.dart` — `ref.read(supabaseBootstrapProvider).initialize()` instead of `initializeSupabase()`
  - Update safety net tests from Task 1 to use new API
  - Run full test suite

  **Must NOT do**:
  - Don't use `FutureProvider` or `AsyncNotifierProvider` — synchronous Provider holding a Future
  - Don't change the auth init sequence (fire-and-forget async pattern must be preserved)
  - Don't restructure the sync service
  - Don't add retry logic or error handling beyond what exists

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Changes initialization flow — need careful verification of auth sequence
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - All omitted — standard Riverpod provider creation

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 2 (sequential, after Task 5)
  - **Blocks**: Task 7 (map_screen changes happen after bootstrap is stable)
  - **Blocked By**: Task 5 (bootstrap must be in core/ first)

  **References**:

  **Pattern References**:
  - `lib/core/config/supabase_bootstrap.dart` (after Task 5 move) — The file being refactored: global vars → class
  - `lib/core/state/cell_service_provider.dart` — Example of a synchronous `Provider<T>` wrapping a pure Dart class
  - `lib/features/auth/providers/auth_provider.dart:39-55` — Auth init flow that awaits `supabaseReady` — must work identically after refactor

  **API/Type References**:
  - `lib/core/config/supabase_config.dart` — `SupabaseConfig` class pattern to follow (pure Dart class, no Riverpod)
  - `lib/features/sync/providers/sync_provider.dart:14` — Uses `supabaseInitialized` to decide if persistence is available

  **WHY Each Reference Matters**:
  - `supabase_bootstrap.dart` shows the exact globals being wrapped — the class must preserve identical behavior
  - `cell_service_provider.dart` shows how to wrap a plain Dart class in a Provider (pattern to follow)
  - `auth_provider.dart:39-55` is the critical consumer — if the await pattern breaks, auth fails silently

  **Acceptance Criteria**:
  - [ ] `grep -r 'bool supabaseInitialized' lib/` → 0 results (no global mutable bool)
  - [ ] `SupabaseBootstrap` class exists with `initialized`, `ready`, `initialize()` API
  - [ ] `supabaseBootstrapProvider` exists as `Provider<SupabaseBootstrap>`
  - [ ] Auth provider uses `ref.read(supabaseBootstrapProvider).ready` for initialization
  - [ ] `LD_LIBRARY_PATH=. flutter test` → all pass
  - [ ] `flutter analyze` → 0 issues

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Global mutable state eliminated
    Tool: Bash
    Preconditions: Changes applied
    Steps:
      1. Run: grep -rn 'bool supabaseInitialized' lib/
      2. Assert: 0 matches
      3. Run: grep -rn 'Future<void> supabaseReady' lib/core/config/supabase_bootstrap.dart
      4. Assert: 0 matches for top-level var (should be class field now)
    Expected Result: No global mutable variables remain
    Failure Indicators: Global vars still present
    Evidence: .sisyphus/evidence/task-6-globals.txt

  Scenario: Provider exists and is accessible
    Tool: Bash
    Preconditions: Changes applied
    Steps:
      1. Run: grep 'supabaseBootstrapProvider' lib/core/state/supabase_bootstrap_provider.dart
      2. Assert: contains `Provider<SupabaseBootstrap>`
      3. Run: grep 'supabaseBootstrapProvider' lib/features/auth/providers/auth_provider.dart
      4. Assert: auth provider reads from the new provider
    Expected Result: Provider defined and consumed correctly
    Failure Indicators: Provider not found or not consumed
    Evidence: .sisyphus/evidence/task-6-provider.txt

  Scenario: App still boots correctly (full test suite)
    Tool: Bash
    Preconditions: Flutter SDK available
    Steps:
      1. Run: eval "$(~/.local/bin/mise activate bash)" && flutter analyze
      2. Assert: 0 issues
      3. Run: eval "$(~/.local/bin/mise activate bash)" && LD_LIBRARY_PATH=. flutter test
      4. Assert: all pass
    Expected Result: Auth init sequence preserved, zero regressions
    Failure Indicators: Auth tests fail, or supabase tests fail
    Evidence: .sisyphus/evidence/task-6-tests.txt
  ```

  **Commit**: YES
  - Message: `♻️ refactor(config): wrap supabase globals in SupabaseBootstrap provider`
  - Files: `lib/core/config/supabase_bootstrap.dart`, `lib/core/state/supabase_bootstrap_provider.dart`, `lib/features/auth/providers/auth_provider.dart`, `lib/features/sync/providers/sync_provider.dart`, `lib/main.dart`
  - Pre-commit: `flutter analyze && LD_LIBRARY_PATH=. flutter test`

- [ ] 7. Fix 60fps setState in map_screen — ValueNotifier for Marker Position

  **What to do**:
  - Create `lib/features/map/widgets/player_marker_layer.dart`:
    - `PlayerMarkerLayer` StatelessWidget that takes a `ValueNotifier<({double lat, double lon})?>` and builds a `ValueListenableBuilder`
    - Renders the player marker circle at the notifier's current position
    - Rebuilds ONLY when marker position changes — independent of parent MapScreen rebuilds
  - Refactor `lib/features/map/map_screen.dart`:
    - Add `ValueNotifier<({double lat, double lon})?>` field `_markerPosition`
    - In `_onDisplayPositionUpdate()`: update `_markerPosition.value` instead of calling `setState()` for `_displayLat`/`_displayLon`
    - Remove `_displayLat` and `_displayLon` state fields
    - Remove the `setState()` call at line ~467 that updates marker position
    - Replace inline marker rendering in `build()` with `PlayerMarkerLayer(position: _markerPosition)`
    - Remove top-level `ref.watch(locationProvider)` from `build()` — it was used for initial position fallback and low-accuracy indicator
    - Extract low-accuracy indicator to a `Consumer` widget that watches `locationProvider` independently
    - Camera updates continue via the same `_onDisplayPositionUpdate` callback (Ticker stays in MapScreen)
    - `_processGameLogic` continues at ~10Hz throttle (unchanged)
  - Keep `setState()` calls for `_showDebugHud` and `_zoomLevel` (these are infrequent UI toggles, fine to rebuild)
  - Run full test suite

  **Must NOT do**:
  - Don't extract fog layer management, zoom logic, or MapLibre callbacks
  - Don't move the Ticker or RubberBandController out of MapScreen
  - Don't create a Riverpod provider for display position (ValueNotifier is correct for 60fps single-widget)
  - Don't extract GameLogicThrottler (the _gameLogicFrame counter is fine inline)
  - Don't split map_screen beyond the marker + low-accuracy extraction

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Changes the core game loop rendering path — needs careful understanding of Flutter widget lifecycle and ValueNotifier
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `playwright`: Could be used for smoke test but QA scenario covers it via test suite
    - `frontend-ui-ux`: Not a visual change — pure performance refactor

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3 (after Wave 2)
  - **Blocks**: Final Verification (F1-F4)
  - **Blocked By**: Task 6 (bootstrap provider must be stable before touching map_screen)

  **References**:

  **Pattern References**:
  - `lib/features/map/map_screen.dart:460-475` — Current `_onDisplayPositionUpdate` that calls `setState()` — this is the hot path being fixed
  - `lib/features/map/map_screen.dart:640-820` — Current `build()` method with inline marker and `ref.watch(locationProvider)` — both need changes
  - `lib/features/map/controllers/rubber_band_controller.dart:85-100` — RubberBandController's `onDisplayUpdate` callback mechanism — it will write to ValueNotifier instead of calling parent method

  **API/Type References**:
  - Flutter `ValueNotifier<T>` — Lightweight observable for single-widget rebuilds
  - Flutter `ValueListenableBuilder<T>` — Builder that rebuilds only when ValueNotifier changes
  - `lib/features/map/map_screen.dart:180-195` — `_rubberBand` initialization in `initState()` — callback wiring point

  **WHY Each Reference Matters**:
  - `map_screen.dart:460-475` is the exact code being changed — understand the setState→camera→gameLogic chain
  - `map_screen.dart:640-820` build method shows where marker is rendered inline and where `ref.watch` is called — both extraction points
  - `rubber_band_controller.dart` callback mechanism determines how ValueNotifier gets updated — the controller calls `onDisplayUpdate(lat, lon)` which must now update the ValueNotifier

  **Acceptance Criteria**:
  - [ ] `lib/features/map/widgets/player_marker_layer.dart` exists
  - [ ] `PlayerMarkerLayer` uses `ValueListenableBuilder`
  - [ ] `_displayLat`/`_displayLon` removed from `_MapScreenState`
  - [ ] `setState` in `_onDisplayPositionUpdate` removed (no 60fps full rebuild)
  - [ ] Top-level `ref.watch(locationProvider)` removed from `build()`
  - [ ] Low-accuracy indicator uses scoped `Consumer` widget
  - [ ] `grep -c 'setState' lib/features/map/map_screen.dart` ≤ 2 (debug + zoom only)
  - [ ] `LD_LIBRARY_PATH=. flutter test` → all pass
  - [ ] `flutter analyze` → 0 issues

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: setState call count reduced
    Tool: Bash
    Preconditions: Changes applied
    Steps:
      1. Run: grep -c 'setState' lib/features/map/map_screen.dart
      2. Assert: count ≤ 2 (only debug toggle and zoom level)
    Expected Result: No setState for marker position
    Failure Indicators: count > 2 means marker still uses setState
    Evidence: .sisyphus/evidence/task-7-setstate-count.txt

  Scenario: ref.watch(locationProvider) removed from top-level build
    Tool: Bash
    Preconditions: Changes applied
    Steps:
      1. Run: grep -n 'ref.watch(locationProvider)' lib/features/map/map_screen.dart
      2. Assert: 0 matches at top-level build, OR only inside Consumer widgets
    Expected Result: locationProvider not watched at MapScreen level
    Failure Indicators: Top-level watch still present
    Evidence: .sisyphus/evidence/task-7-watch-removed.txt

  Scenario: PlayerMarkerLayer uses ValueListenableBuilder
    Tool: Bash
    Preconditions: New file exists
    Steps:
      1. Run: grep 'ValueListenableBuilder' lib/features/map/widgets/player_marker_layer.dart
      2. Assert: contains ValueListenableBuilder usage
    Expected Result: Marker rebuilds via ValueNotifier, not parent setState
    Failure Indicators: No ValueListenableBuilder found
    Evidence: .sisyphus/evidence/task-7-value-notifier.txt

  Scenario: Full test suite passes
    Tool: Bash
    Preconditions: Flutter SDK available
    Steps:
      1. Run: eval "$(~/.local/bin/mise activate bash)" && flutter analyze
      2. Assert: 0 issues
      3. Run: eval "$(~/.local/bin/mise activate bash)" && LD_LIBRARY_PATH=. flutter test
      4. Assert: all pass
    Expected Result: Zero regressions
    Failure Indicators: Any test failure or analyze error
    Evidence: .sisyphus/evidence/task-7-tests.txt

  Scenario: App renders and player moves (Playwright smoke test)
    Tool: Playwright
    Preconditions: Deploy to Railway, app is accessible
    Steps:
      1. Navigate to https://fog-of-world-production.up.railway.app/
      2. Wait for map to render (wait for canvas or MapLibre element)
      3. Press ArrowRight key 3 times with 500ms intervals
      4. Take screenshot
      5. Check browser console for errors
    Expected Result: Map loads, player marker visible, movement works, no errors
    Failure Indicators: Map doesn't load, marker missing, console errors
    Evidence: .sisyphus/evidence/task-7-playwright-smoke.png
  ```

  **Commit**: YES
  - Message: `⏱️ perf(map): decouple marker position from full widget rebuild via ValueNotifier`
  - Files: `lib/features/map/map_screen.dart`, `lib/features/map/widgets/player_marker_layer.dart`
  - Pre-commit: `flutter analyze && LD_LIBRARY_PATH=. flutter test`

---

## Final Verification Wave (MANDATORY — after ALL implementation tasks)

> 4 review agents run in PARALLEL. ALL must APPROVE. Rejection → fix → re-run.

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists (grep imports, read files). For each "Must NOT Have": search codebase for forbidden patterns — reject with file:line if found. Check evidence files exist in .sisyphus/evidence/. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run `flutter analyze`. Run `LD_LIBRARY_PATH=. flutter test`. Review all changed files for: unused imports, missing dispose calls, provider leaks, mutable state outside providers. Check AGENTS.md conventions are followed (Notifier not StateNotifier, no global state, etc.).
  Output: `Analyze [PASS/FAIL] | Tests [N pass/N fail] | Files [N clean/N issues] | VERDICT`

- [ ] F3. **Real QA — Playwright Smoke Test** — `unspecified-high` (+ `playwright` skill)
  Deploy to Railway. Navigate to https://fog-of-world-production.up.railway.app/. Wait for app load (no login screen — auto guest auth). Verify map renders. Press arrow keys — verify player moves. Take screenshot as evidence. Verify no console errors.
  Output: `Load [PASS/FAIL] | Map [PASS/FAIL] | Movement [PASS/FAIL] | Console [PASS/FAIL] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", read actual diff (git log/diff). Verify 1:1 — everything in spec was built (no missing), nothing beyond spec was built (no creep). Check "Must NOT do" compliance. Detect cross-task contamination: Task N touching Task M's files.
  Output: `Tasks [N/N compliant] | Contamination [CLEAN/N issues] | Unaccounted [CLEAN/N files] | VERDICT`

---

## Commit Strategy

| Task | Commit Message | Files |
|------|---------------|-------|
| 1 | ✅ test(bootstrap): add safety net tests for supabase bootstrap and auth init | test/features/sync/services/supabase_bootstrap_test.dart, test/features/auth/providers/auth_provider_test.dart |
| 2 | 📝 docs(shared): document shared layer conventions and allowed core imports | lib/shared/AGENTS.md |
| 3 | 🐛 fix(persistence): add transactions and batch delete to repositories | lib/core/persistence/*.dart, test/core/persistence/*_test.dart |
| 4 | ✨ feat(seasonal): wire season service into discovery for species filtering | lib/features/map/providers/discovery_service_provider.dart, lib/features/discovery/services/species_service.dart |
| 5 | ♻️ refactor(auth): break auth↔sync circular dependency by moving bootstrap to core | lib/core/config/supabase_bootstrap.dart, lib/features/auth/providers/auth_provider.dart, lib/features/sync/providers/sync_provider.dart, lib/main.dart |
| 6 | ♻️ refactor(config): wrap supabase globals in SupabaseBootstrap provider | lib/core/config/supabase_bootstrap.dart, lib/core/state/supabase_bootstrap_provider.dart |
| 7 | ⏱️ perf(map): decouple marker position from full widget rebuild via ValueNotifier | lib/features/map/map_screen.dart, lib/features/map/widgets/player_marker_layer.dart |

---

## Success Criteria

### Verification Commands
```bash
eval "$(~/.local/bin/mise activate bash)"
flutter analyze                           # Expected: 0 issues
LD_LIBRARY_PATH=. flutter test            # Expected: all pass (≥981)
grep -r 'features/sync' lib/features/auth/ | wc -l  # Expected: 0
grep -r 'bool supabaseInitialized' lib/   # Expected: 0 matches (no global mutable bool)
grep -c 'setState' lib/features/map/map_screen.dart  # Expected: ≤2 (debug + zoom only, not marker)
grep -c 'ref.watch(locationProvider)' lib/features/map/map_screen.dart  # Expected: 0 at top level
```

### Final Checklist
- [ ] All "Must Have" present
- [ ] All "Must NOT Have" absent
- [ ] All tests pass (≥981)
- [ ] flutter analyze → 0 issues
- [ ] App deploys and runs on Railway
