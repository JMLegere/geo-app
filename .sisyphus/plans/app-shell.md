# Initiative 1: Core Navigation & App Shell

## TL;DR

> **Quick Summary**: Transition EarthNova from a single-screen map app to a 4-tab experience (Map | Home | Town | Pack). Wire existing screens into tabs, rename Journal→Pack, add themed Town placeholder, add Achievement access from Home tab.
> 
> **Deliverables**:
> - 4-tab bottom navigation with `IndexedStack` keep-alive
> - Pack tab (renamed from Journal — same UI)
> - Home tab (SanctuaryScreen + Achievement entry point)
> - Town tab (themed "Coming Soon" placeholder)
> - Tab persistence across app restarts via SharedPreferences
> - MapScreen bottom widgets adjusted to clear nav bar
> - Web: MapLibre HtmlElementView visibility wired to tab switches
> - Tests for all new components
> 
> **Estimated Effort**: Medium
> **Parallel Execution**: YES — 3 waves
> **Critical Path**: Task 1 (rename) → Task 2 (shell) → Tasks 3-6 (wiring) → Task 7 (integration) → Final verification

---

## Context

### Original Request
"Can you plan the initial app shell, what initiative does that map to?" — maps to Initiative 1 in `docs/roadmap.md`.

### Interview Summary
**Key Discussions**:
- Scope: Full Initiative 1 (Projects 1.1-1.4), excluding inventory redesign (Initiative 2)
- Map lifecycle: Keep alive when switching tabs — no GPS interruption
- Achievement access: Inside Home tab (trophy shelf in home base)
- Pack rename: Mechanical rename only — keep current catalog UI
- Town tab: Themed "Coming Soon" placeholder using EmptyStateWidget

**Research Findings**:
- `main.dart:69` — injection point: `AuthStatus.authenticated || AuthStatus.guest => const MapScreen()`
- MapScreen (908 lines) has 3 stream subscriptions, 60fps Ticker, MapLibre controller
- JournalScreen, SanctuaryScreen, AchievementScreen all standalone ConsumerWidgets
- AchievementScreen is currently dead — never imported/navigated to from anywhere
- `BottomNavigationBarThemeData` already configured in `app_theme.dart:139-145,249-255`
- SharedPreferences already a dependency, pattern established in `onboarding_provider.dart`
- Journal→Pack rename blast radius: 5 lib files + 6 test files + 1 integration test = 12 files
- MapScreen bottom widgets at lines 760 (bottom:72), 811 (bottom:80), 824 (bottom:16), 834 (bottom:16) — will be obscured by nav bar

### Metis Review
**Identified Gaps** (addressed):
- MapLibre HtmlElementView z-order on web — must wire `MapVisibility.hideMapContainer()`/`revealMapContainer()` to tab switches
- MapScreen bottom widgets obscured by nav bar — adjusted offsets in Task 5
- AchievementScreen is dead code — wired via IconButton in SanctuaryScreen AppBar (Task 4)
- SanctuaryScreen `recordVisit()` only fires on first mount with IndexedStack — acceptable (caretaking guards same-day duplicates)
- Discovery/achievement notifications invisible on non-Map tabs — deferred to v2, noted as known limitation
- NavigationBar (M3) vs BottomNavigationBar (M2) — use M2 to match existing theme data
- Settings/gear icon — placeholder SnackBar "Coming soon" for v1

---

## Work Objectives

### Core Objective
Ship the 4-tab app shell that transforms EarthNova from a single-screen map app into a multi-tab experience, unblocking all downstream features (Museum, Pack inventory, NPCs, quests).

### Concrete Deliverables
- `lib/features/navigation/` — new feature module with TabShell widget + tab index provider
- `lib/features/pack/` — renamed from `lib/features/journal/` (all classes, providers, imports)
- `test/features/pack/` — renamed from `test/features/journal/`
- `lib/features/navigation/screens/town_placeholder_screen.dart` — themed empty state
- Modified `main.dart` — routes to TabShell instead of MapScreen
- Modified `sanctuary_screen.dart` — adds Achievement entry point IconButton
- Modified `map_screen.dart` — bottom widget offsets adjusted, keep-alive mixin
- New tests for TabShell, tab index provider, navigation integration
- Updated `docs/roadmap.md` — Initiative 1 projects marked Done
- Updated `AGENTS.md` files — new navigation feature documented

### Definition of Done
- [ ] `LD_LIBRARY_PATH=. flutter test` — all tests pass (existing + new)
- [ ] `flutter analyze` — 0 issues
- [ ] `grep -ri "journal" lib/ test/ --include="*.dart"` — 0 matches
- [ ] App launches with 4-tab bottom bar
- [ ] Switching tabs preserves map state (GPS continues, fog intact)
- [ ] Tab selection persists across app restart
- [ ] Achievement screen accessible from Home tab
- [ ] Web: MapLibre container hidden when on non-Map tabs

### Must Have
- IndexedStack-based tab body (all children mounted, only active one painted)
- BottomNavigationBar (M2) matching existing theme data
- Tab index persistence via SharedPreferences
- MapScreen bottom widgets cleared above nav bar
- Web: MapVisibility integration with tab switches
- Zero "journal" references remaining after rename

### Must NOT Have (Guardrails)
- **No MapScreen refactoring** — only add keep-alive mixin + adjust bottom offsets. Zero logic changes.
- **No UI/behavior changes during Pack rename** — pure mechanical refactoring. Widget structure, filters, layout untouched.
- **No new packages** — no GoRouter, auto_route, or navigation framework. SharedPreferences already available.
- **No real Settings screen** — gear icon shows SnackBar "Coming soon" or is deferred.
- **No notification migration** — discovery/achievement toasts stay in MapScreen overlay. Moving to shell level is v2.
- **No custom tab bar** — use stock BottomNavigationBar with existing theme data. No animations or custom indicators.
- **No Ticker pause/resume optimization** — MapScreen's 60fps RubberBand Ticker runs in background. Optimization is v2.
- **No keyboard/DPad scoping** — arrow keys may still drive movement on non-Map tabs. Known limitation, v2.

---

## Verification Strategy

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: YES (1004+ tests, `flutter_test`)
- **Automated tests**: Tests-after (new tests for new components, verify existing tests still pass)
- **Framework**: `flutter_test` (no mockito/mocktail — hand-written mocks)

### QA Policy
Every task MUST include agent-executed QA scenarios.
Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

- **Widget tests**: `flutter test` with `testWidgets()` — pump TabShell, verify tab switching
- **Unit tests**: `flutter test` — tab index provider persistence
- **CLI verification**: `grep`, `flutter analyze`, `flutter test`
- **Web verification**: Playwright — navigate tabs, verify MapLibre visibility

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately — mechanical rename):
└── Task 1: Journal→Pack rename [quick]

Wave 2 (After Wave 1 — build shell + wire screens, MAX PARALLEL):
├── Task 2: Tab shell scaffold + tab index provider [unspecified-high]
├── Task 3: Town placeholder screen [quick]
├── Task 4: Achievement entry point in SanctuaryScreen [quick]

Wave 3 (After Wave 2 — integration + adjustments):
├── Task 5: MapScreen bottom offset adjustments [quick]
├── Task 6: Web MapVisibility integration with tab switches [unspecified-high]
├── Task 7: Wire TabShell into main.dart + integration tests [unspecified-high]

Wave 4 (After Wave 3 — docs + verification):
├── Task 8: Update docs + AGENTS.md [quick]

Wave FINAL (After ALL tasks — independent review, 4 parallel):
├── Task F1: Plan compliance audit (oracle)
├── Task F2: Code quality review (unspecified-high)
├── Task F3: Real manual QA (unspecified-high)
└── Task F4: Scope fidelity check (deep)

Critical Path: Task 1 → Task 2 → Task 7 → F1-F4
Parallel Speedup: ~50% faster than sequential
Max Concurrent: 3 (Wave 2)
```

### Dependency Matrix

| Task | Depends On | Blocks |
|------|-----------|--------|
| 1 | — | 2, 3, 4, 5, 6, 7 |
| 2 | 1 | 5, 6, 7 |
| 3 | 1 | 7 |
| 4 | 1 | 7 |
| 5 | 2 | 7 |
| 6 | 2 | 7 |
| 7 | 2, 3, 4, 5, 6 | 8 |
| 8 | 7 | F1-F4 |
| F1-F4 | 8 | — |

### Agent Dispatch Summary

- **Wave 1**: **1 task** — T1 → `quick`
- **Wave 2**: **3 tasks** — T2 → `unspecified-high`, T3 → `quick`, T4 → `quick`
- **Wave 3**: **3 tasks** — T5 → `quick`, T6 → `unspecified-high`, T7 → `unspecified-high`
- **Wave 4**: **1 task** — T8 → `quick`
- **FINAL**: **4 tasks** — F1 → `oracle`, F2 → `unspecified-high`, F3 → `unspecified-high`, F4 → `deep`

---

## TODOs

- [ ] 1. Journal → Pack Rename (Mechanical Refactoring)

  **What to do**:
  - Rename directory `lib/features/journal/` → `lib/features/pack/`
  - Rename directory `test/features/journal/` → `test/features/pack/`
  - Rename all classes: `JournalScreen` → `PackScreen`, `JournalFilterBar` → `PackFilterBar`, `JournalProgressBar` → `PackProgressBar`, `JournalProvider`/`JournalNotifier`/`JournalState` → `PackProvider`/`PackNotifier`/`PackState`, `CollectionFilter` stays (it's generic)
  - Rename all files: `journal_screen.dart` → `pack_screen.dart`, `journal_filter_bar.dart` → `pack_filter_bar.dart`, `journal_progress_bar.dart` → `pack_progress_bar.dart`, `journal_provider.dart` → `pack_provider.dart`
  - Update all imports across source and test files (12 files total)
  - Update string literal "Journal" → "Pack" in AppBar title and any user-facing text
  - Update `lib/shared/app_theme.dart` if it references journal
  - Update `test/integration/offline_audit_test.dart` journal references
  - Verify zero remaining "journal" references in `lib/` and `test/`

  **Must NOT do**:
  - Change any widget layout, rendering, or behavior
  - Modify filter logic, grid layout, or species card design
  - Add new imports or dependencies
  - Touch any file outside the journal→pack rename scope

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Mechanical find-and-replace refactoring across a bounded set of files
  - **Skills**: []
    - No special skills needed — standard file operations and lsp_rename
  - **Skills Evaluated but Omitted**:
    - `git-master`: Not needed — straightforward rename, no history manipulation

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 1 (solo — must complete before anything else)
  - **Blocks**: Tasks 2, 3, 4, 5, 6, 7
  - **Blocked By**: None (can start immediately)

  **References**:

  **Pattern References** (existing code to follow):
  - `lib/features/journal/` — Full directory listing: `providers/journal_provider.dart`, `screens/journal_screen.dart`, `widgets/journal_filter_bar.dart`, `widgets/journal_progress_bar.dart`, `widgets/species_card.dart`, `widgets/species_detail_sheet.dart`
  - `test/features/journal/` — Full directory listing: `providers/journal_provider_test.dart`, `screens/journal_screen_test.dart`, `widgets/journal_filter_bar_test.dart`, `widgets/journal_progress_bar_test.dart`, `widgets/species_card_test.dart`

  **Files to modify** (exhaustive list):
  - `lib/features/journal/providers/journal_provider.dart` → rename to `pack_provider.dart`, rename classes
  - `lib/features/journal/screens/journal_screen.dart` → rename to `pack_screen.dart`, rename class
  - `lib/features/journal/widgets/journal_filter_bar.dart` → rename to `pack_filter_bar.dart`, rename class
  - `lib/features/journal/widgets/journal_progress_bar.dart` → rename to `pack_progress_bar.dart`, rename class
  - `lib/features/journal/widgets/species_card.dart` → update import path (no class rename needed — it's `SpeciesCard`)
  - `lib/features/journal/widgets/species_detail_sheet.dart` → update import path (no class rename — it's `SpeciesDetailSheet`)
  - `lib/shared/app_theme.dart` — has `journal` reference in comment (line ~varies)
  - `test/features/journal/providers/journal_provider_test.dart` → rename, update imports
  - `test/features/journal/screens/journal_screen_test.dart` → rename, update imports
  - `test/features/journal/widgets/journal_filter_bar_test.dart` → rename, update imports
  - `test/features/journal/widgets/journal_progress_bar_test.dart` → rename, update imports
  - `test/features/journal/widgets/species_card_test.dart` → update imports
  - `test/integration/offline_audit_test.dart` — update journal references

  **Tool recommendations**:
  - Use `lsp_rename` for class renames (JournalScreen→PackScreen, etc.) — safe automated refactoring
  - Use `ast_grep_search` to verify zero remaining "journal"/"Journal" references after rename
  - Manual file move for directory/file renames (lsp_rename doesn't rename files)

  **Acceptance Criteria**:
  - [ ] `flutter analyze` → 0 issues
  - [ ] `LD_LIBRARY_PATH=. flutter test` → all tests pass
  - [ ] `grep -ri "journal" lib/ test/ --include="*.dart" | wc -l` → 0
  - [ ] `ls lib/features/pack/` → providers/, screens/, widgets/
  - [ ] `ls test/features/pack/` → providers/, screens/, widgets/
  - [ ] `ls lib/features/journal/ 2>/dev/null` → "No such file or directory"

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Pack rename is complete and zero Journal references remain
    Tool: Bash
    Preconditions: Rename task completed
    Steps:
      1. Run `grep -ri "journal" lib/ test/ --include="*.dart"`
      2. Assert: output is empty (0 matches)
      3. Run `grep -ri "Journal" lib/ test/ --include="*.dart"`
      4. Assert: output is empty (0 matches)
      5. Run `ls lib/features/pack/providers/pack_provider.dart`
      6. Assert: file exists
      7. Run `ls lib/features/journal/ 2>&1`
      8. Assert: "No such file or directory"
    Expected Result: Zero journal references, all pack files exist, journal directory gone
    Failure Indicators: Any grep match, missing pack file, journal directory still exists
    Evidence: .sisyphus/evidence/task-1-rename-verify.txt

  Scenario: All tests pass after rename
    Tool: Bash
    Preconditions: Rename task completed
    Steps:
      1. Run `flutter analyze`
      2. Assert: exit code 0, "No issues found"
      3. Run `LD_LIBRARY_PATH=. flutter test`
      4. Assert: exit code 0, all tests pass
    Expected Result: 0 analysis issues, all 1004+ tests pass
    Failure Indicators: Any analysis issue, any test failure
    Evidence: .sisyphus/evidence/task-1-tests-pass.txt
  ```

  **Commit**: YES
  - Message: `♻️ refactor(pack): rename Journal→Pack throughout codebase`
  - Files: All journal→pack renames in lib/ and test/
  - Pre-commit: `flutter analyze && LD_LIBRARY_PATH=. flutter test`

- [ ] 2. Tab Shell Scaffold + Tab Index Provider

  **What to do**:
  - Create `lib/features/navigation/` directory with standard feature module structure
  - Create `lib/features/navigation/providers/tab_index_provider.dart`:
    - `TabIndexNotifier extends Notifier<int>` following `onboarding_provider.dart` pattern
    - `build()` returns 0 (Map tab), async loads from SharedPreferences
    - `setTab(int index)` updates state and persists to SharedPreferences
    - `tabIndexProvider = NotifierProvider<TabIndexNotifier, int>`
    - Key: `'selected_tab_index'`
  - Create `lib/features/navigation/screens/tab_shell.dart`:
    - `TabShell extends ConsumerWidget`
    - Uses `IndexedStack` with `ref.watch(tabIndexProvider)` as index
    - 4 children: MapScreen, SanctuaryScreen (Home), TownPlaceholderScreen, PackScreen
    - `BottomNavigationBar` with 4 tabs: Map (explore icon), Home (home icon), Town (people icon), Pack (backpack icon)
    - `onTap` calls `ref.read(tabIndexProvider.notifier).setTab(index)`
    - Gear icon in AppBar (or floating) — shows SnackBar "Settings coming soon"
  - Create `test/features/navigation/providers/tab_index_provider_test.dart`:
    - Test: initial state is 0 (Map tab)
    - Test: `setTab(2)` updates state to 2
    - Test: persists to SharedPreferences (mock or real SharedPreferences with `setMockInitialValues`)
    - Test: restores from SharedPreferences on rebuild
  - Create `test/features/navigation/screens/tab_shell_test.dart`:
    - Test: renders 4 tab icons in BottomNavigationBar
    - Test: tapping tab changes selected index
    - Test: IndexedStack shows correct child per tab index
    - NOTE: MapScreen can't be tested in widget tests (needs MapLibre) — mock it or use a placeholder

  **Must NOT do**:
  - Add navigation framework packages (GoRouter, auto_route)
  - Build a real Settings screen
  - Create custom tab bar animations or indicators
  - Modify any existing screen's internal layout

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: New feature module with provider, widget, and test creation — moderate complexity
  - **Skills**: []
    - No special skills needed
  - **Skills Evaluated but Omitted**:
    - `frontend-ui-ux`: Not needed — using stock BottomNavigationBar with existing theme

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 3, 4 in Wave 2)
  - **Parallel Group**: Wave 2 (with Tasks 3, 4)
  - **Blocks**: Tasks 5, 6, 7
  - **Blocked By**: Task 1 (Pack rename — needs PackScreen import)

  **References**:

  **Pattern References** (existing code to follow):
  - `lib/features/onboarding/providers/onboarding_provider.dart` — SharedPreferences persistence pattern for tab index provider (NotifierProvider, async load in build(), guard with ref.mounted)
  - `lib/features/auth/screens/login_screen.dart` — ConsumerWidget screen pattern
  - `lib/main.dart:37-73` — FogOfWorldApp ConsumerWidget that resolves home screen (injection point)

  **API/Type References** (contracts to implement against):
  - `lib/features/map/map_screen.dart` — MapScreen constructor (const, no params)
  - `lib/features/sanctuary/screens/sanctuary_screen.dart` — SanctuaryScreen constructor (const, no params)
  - `lib/features/pack/screens/pack_screen.dart` — PackScreen constructor (const, no params — after rename)

  **Theme References** (tab bar styling):
  - `lib/shared/app_theme.dart:139-145` — BottomNavigationBarThemeData dark mode config
  - `lib/shared/app_theme.dart:249-255` — BottomNavigationBarThemeData light mode config

  **Test References** (testing patterns to follow):
  - `test/features/onboarding/providers/onboarding_provider_test.dart` — SharedPreferences provider testing pattern (if exists)
  - `test/AGENTS.md` — ProviderContainer + addTearDown pattern, testWidgets with MaterialApp wrapper

  **Acceptance Criteria**:
  - [ ] `lib/features/navigation/providers/tab_index_provider.dart` exists and compiles
  - [ ] `lib/features/navigation/screens/tab_shell.dart` exists and compiles
  - [ ] `flutter analyze` → 0 issues
  - [ ] Tab index provider test: initial state, set tab, persistence
  - [ ] Tab shell widget test: renders 4 tabs, switching works

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Tab index provider persists selection to SharedPreferences
    Tool: Bash (flutter test)
    Preconditions: Provider test file created
    Steps:
      1. Run `LD_LIBRARY_PATH=. flutter test test/features/navigation/providers/tab_index_provider_test.dart`
      2. Assert: all tests pass
    Expected Result: Tests verify initial state = 0, setTab updates state, value persists and restores
    Failure Indicators: Any test failure
    Evidence: .sisyphus/evidence/task-2-provider-tests.txt

  Scenario: TabShell renders 4 tabs and switches correctly
    Tool: Bash (flutter test)
    Preconditions: Widget test file created
    Steps:
      1. Run `LD_LIBRARY_PATH=. flutter test test/features/navigation/screens/tab_shell_test.dart`
      2. Assert: all tests pass
    Expected Result: Tests verify 4 tab icons visible, tapping changes index, correct child shown per index
    Failure Indicators: Any test failure
    Evidence: .sisyphus/evidence/task-2-shell-tests.txt
  ```

  **Commit**: YES (groups with Tasks 3, 4)
  - Message: `✨ feat(navigation): add 4-tab app shell with tab persistence`
  - Files: `lib/features/navigation/`, `test/features/navigation/`, town placeholder, sanctuary achievement button
  - Pre-commit: `flutter analyze && LD_LIBRARY_PATH=. flutter test`

- [ ] 3. Town Placeholder Screen

  **What to do**:
  - Create `lib/features/navigation/screens/town_placeholder_screen.dart`:
    - `TownPlaceholderScreen extends StatelessWidget`
    - Uses `Scaffold` with themed background (no AppBar — TabShell may have one, or screen owns it)
    - Body: `EmptyStateWidget` with town-appropriate emoji (🏘️), title "Town — Coming Soon", subtitle "Discover NPCs while exploring the map. They'll gather here.", no action button
    - Uses design system tokens: `Theme.of(context).colorScheme.*`, `Spacing.*`
  - Create `test/features/navigation/screens/town_placeholder_screen_test.dart`:
    - Test: renders EmptyStateWidget with expected emoji and text
    - Test: no interactive elements (buttons, taps)

  **Must NOT do**:
  - Add NPC data models or providers
  - Create custom illustrations or animations
  - Add interactive elements

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single file creation with trivial content — EmptyStateWidget wrapper
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `frontend-ui-ux`: Overkill — this is a static placeholder

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 2, 4 in Wave 2)
  - **Parallel Group**: Wave 2 (with Tasks 2, 4)
  - **Blocks**: Task 7
  - **Blocked By**: Task 1 (needs clean codebase after rename)

  **References**:

  **Pattern References**:
  - `lib/shared/widgets/empty_state_widget.dart` — EmptyStateWidget API (emoji, title, subtitle, optional action)
  - `lib/features/onboarding/screens/onboarding_screen.dart` — Design system token usage pattern

  **Acceptance Criteria**:
  - [ ] `lib/features/navigation/screens/town_placeholder_screen.dart` exists
  - [ ] Widget test passes
  - [ ] `flutter analyze` → 0 issues
  - [ ] EmptyStateWidget renders with correct copy

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Town placeholder renders correctly
    Tool: Bash (flutter test)
    Preconditions: Screen and test file created
    Steps:
      1. Run `LD_LIBRARY_PATH=. flutter test test/features/navigation/screens/town_placeholder_screen_test.dart`
      2. Assert: all tests pass
    Expected Result: EmptyStateWidget renders with town emoji and "Coming Soon" text
    Failure Indicators: Test failure, missing widget
    Evidence: .sisyphus/evidence/task-3-town-test.txt
  ```

  **Commit**: NO (groups with Task 2)

- [ ] 4. Achievement Entry Point in SanctuaryScreen

  **What to do**:
  - Modify `lib/features/sanctuary/screens/sanctuary_screen.dart`:
    - Add an `IconButton` to the AppBar `actions` list
    - Icon: `Icons.emoji_events` (trophy) or `Icons.military_tech`
    - Color: `Theme.of(context).colorScheme.primary`
    - onPressed: `Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AchievementScreen()))`
    - Import `lib/features/achievements/screens/achievement_screen.dart`
  - Create or update `test/features/sanctuary/screens/sanctuary_screen_test.dart`:
    - Test: AppBar has trophy icon button
    - Test: tapping trophy icon pushes AchievementScreen (verify finder finds AchievementScreen after tap)

  **Must NOT do**:
  - Embed achievement preview widget in sanctuary body
  - Modify AchievementScreen itself
  - Add custom transitions or animations
  - Change SanctuaryScreen layout beyond adding the AppBar action

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single-line addition to AppBar actions + one import + test update
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `frontend-ui-ux`: Not needed — single IconButton addition

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 2, 3 in Wave 2)
  - **Parallel Group**: Wave 2 (with Tasks 2, 3)
  - **Blocks**: Task 7
  - **Blocked By**: Task 1 (needs clean codebase after rename)

  **References**:

  **Pattern References**:
  - `lib/features/sanctuary/screens/sanctuary_screen.dart:20-30` — Existing SanctuaryScreen with AppBar
  - `lib/features/achievements/screens/achievement_screen.dart` — AchievementScreen constructor

  **Design References**:
  - `lib/shared/earth_nova_theme.dart` — Use `Theme.of(context).colorScheme.primary` for icon color

  **Acceptance Criteria**:
  - [ ] Trophy icon visible in SanctuaryScreen AppBar
  - [ ] Tapping trophy navigates to AchievementScreen
  - [ ] `flutter analyze` → 0 issues
  - [ ] Widget test covers icon presence and navigation

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Achievement icon in SanctuaryScreen navigates to AchievementScreen
    Tool: Bash (flutter test)
    Preconditions: Sanctuary screen modified, test file created/updated
    Steps:
      1. Run `LD_LIBRARY_PATH=. flutter test test/features/sanctuary/screens/`
      2. Assert: all tests pass, including trophy icon + navigation tests
    Expected Result: Trophy icon renders in AppBar, tapping pushes AchievementScreen route
    Failure Indicators: Icon not found, navigation doesn't push AchievementScreen
    Evidence: .sisyphus/evidence/task-4-achievement-entry.txt

  Scenario: AchievementScreen is no longer dead code
    Tool: Bash (grep)
    Preconditions: Sanctuary screen modified
    Steps:
      1. Run `grep -r "AchievementScreen" lib/ --include="*.dart"`
      2. Assert: at least 2 matches (definition in achievement_screen.dart + import in sanctuary_screen.dart)
    Expected Result: AchievementScreen is imported and used
    Failure Indicators: Only 1 match (definition only — still dead code)
    Evidence: .sisyphus/evidence/task-4-dead-code-check.txt
  ```

  **Commit**: NO (groups with Task 2)

- [ ] 5. MapScreen Bottom Widget Offset Adjustments

  **What to do**:
  - Modify `lib/features/map/map_screen.dart`:
    - Define a constant for nav bar clearance: `static const _kNavBarHeight = 80.0;` (BottomNavigationBar is ~56px + safe area)
    - Adjust bottom-positioned widgets:
      - Line 760: `bottom: 72` → `bottom: 72 + _kNavBarHeight`
      - Line 811: `bottom: 80` → `bottom: 80 + _kNavBarHeight`
      - Line 824: `bottom: 16` → `bottom: 16 + _kNavBarHeight` (DPad controls)
      - Line 834: `bottom: 16` → `bottom: 16 + _kNavBarHeight` (MapControls)
    - Alternatively, use `MediaQuery.of(context).padding.bottom` if the nav bar injects padding — investigate which approach works with TabShell's Scaffold
  - Note: the `_kNavBarHeight` approach is simpler and more predictable. If TabShell uses `Scaffold(bottomNavigationBar: ...)`, the child body already excludes the nav bar area — in which case offsets don't need adjustment. **Test both approaches and use whichever is correct.**

  **Must NOT do**:
  - Refactor MapScreen's Stack layout
  - Extract sub-widgets
  - Modify fog overlay, camera, or GPS logic
  - Change any behavior — only visual positioning

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: 4 numerical constants adjusted in one file
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `frontend-ui-ux`: Not needed — numerical offset changes only

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 6 in Wave 3)
  - **Parallel Group**: Wave 3 (with Tasks 6, 7)
  - **Blocks**: Task 7
  - **Blocked By**: Task 2 (needs TabShell to test against)

  **References**:

  **Pattern References**:
  - `lib/features/map/map_screen.dart:760` — Low accuracy indicator `Positioned(bottom: 72)`
  - `lib/features/map/map_screen.dart:811` — Debug HUD `Positioned(bottom: 80)`
  - `lib/features/map/map_screen.dart:824` — DPad controls `Positioned(bottom: 16)`
  - `lib/features/map/map_screen.dart:834` — MapControls `Positioned(bottom: 16)`

  **Important**: If TabShell wraps the tab body in a `Scaffold(bottomNavigationBar: ...)`, the body area is already inset by the nav bar height — meaning these offsets may NOT need adjustment. The agent must render the TabShell with MapScreen and visually verify whether controls are obscured before making changes. If they're fine as-is, skip the adjustment and note why.

  **Acceptance Criteria**:
  - [ ] MapControls and DPad not obscured by BottomNavigationBar
  - [ ] `flutter analyze` → 0 issues
  - [ ] All existing MapScreen tests pass

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: MapScreen bottom controls not obscured by nav bar
    Tool: Playwright (web)
    Preconditions: TabShell wired with MapScreen, app running
    Steps:
      1. Navigate to app URL
      2. Verify BottomNavigationBar is visible at bottom
      3. Verify MapControls FABs are visible above the nav bar
      4. Take screenshot
    Expected Result: All map controls visible and not overlapping with nav bar
    Failure Indicators: Controls hidden behind or overlapping nav bar
    Evidence: .sisyphus/evidence/task-5-bottom-controls.png

  Scenario: No behavior change in MapScreen after offset adjustment
    Tool: Bash (flutter test)
    Preconditions: Offsets adjusted (if needed)
    Steps:
      1. Run `LD_LIBRARY_PATH=. flutter test test/features/map/`
      2. Assert: all map tests pass
    Expected Result: Zero test failures in map feature
    Failure Indicators: Any test failure
    Evidence: .sisyphus/evidence/task-5-map-tests.txt
  ```

  **Commit**: NO (groups with Tasks 6, 7)

- [ ] 6. Web MapVisibility Integration with Tab Switches

  **What to do**:
  - Investigate: does `IndexedStack` automatically hide the MapLibre `HtmlElementView` on web when another tab is selected? The existing `MapVisibility` utility (`lib/features/map/utils/map_visibility.dart`) uses CSS injection to control the HTML container's opacity because Flutter's `Offstage`/`Visibility` doesn't work with platform views on web.
  - If MapLibre container bleeds through on web when switching tabs:
    - Wire `MapVisibility.hideMapContainer()` when switching away from Map tab (index != 0)
    - Wire `MapVisibility.revealMapContainer()` when switching back to Map tab (index == 0)
    - This could be done in TabShell via `ref.listen(tabIndexProvider, ...)` or via a `didChangeDependencies` override
  - If IndexedStack handles it correctly (unlikely based on existing MapVisibility workaround):
    - Skip this task, document why in a comment
  - Write test verifying the integration (web-specific behavior is hard to test in flutter_test — may need Playwright)

  **Must NOT do**:
  - Modify MapVisibility's internal CSS logic
  - Change how MapLibre renders
  - Add new web-specific packages

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Web platform view visibility is tricky — needs investigation + correct solution
  - **Skills**: [`playwright`]
    - `playwright`: Needed to verify MapLibre visibility on web
  - **Skills Evaluated but Omitted**:
    - `dev-browser`: Playwright skill covers browser testing

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Task 5 in Wave 3)
  - **Parallel Group**: Wave 3 (with Tasks 5, 7)
  - **Blocks**: Task 7
  - **Blocked By**: Task 2 (needs TabShell with IndexedStack)

  **References**:

  **Pattern References**:
  - `lib/features/map/utils/map_visibility.dart` — Existing CSS-based MapLibre container visibility control
  - `lib/features/map/AGENTS.md` → "CSS-based MapLibre container visibility control for web" section

  **External References**:
  - Flutter web platform views use `HtmlElementView` which renders in a separate HTML layer above Flutter widgets
  - `Offstage` and `Visibility` don't affect platform views on web — that's why MapVisibility exists

  **Acceptance Criteria**:
  - [ ] Switching away from Map tab hides MapLibre container on web
  - [ ] Switching back to Map tab reveals MapLibre container
  - [ ] No visual glitches during tab transitions
  - [ ] `flutter analyze` → 0 issues

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: MapLibre container hidden when switching to Pack tab on web
    Tool: Playwright (web)
    Preconditions: App running in browser, on Map tab
    Steps:
      1. Navigate to app URL
      2. Verify map is visible (MapLibre canvas element visible)
      3. Click Pack tab in bottom nav
      4. Assert: Pack screen content visible
      5. Assert: MapLibre canvas element is NOT visible (check CSS opacity or display)
      6. Take screenshot
    Expected Result: Map container hidden, Pack content fully visible without map bleeding through
    Failure Indicators: Map canvas visible behind/above Pack content
    Evidence: .sisyphus/evidence/task-6-map-hidden.png

  Scenario: MapLibre container reappears when returning to Map tab
    Tool: Playwright (web)
    Preconditions: On Pack tab (map hidden)
    Steps:
      1. Click Map tab in bottom nav
      2. Assert: MapLibre canvas element is visible
      3. Assert: Map renders correctly (fog overlay present)
      4. Take screenshot
    Expected Result: Map container visible, fog overlay renders
    Failure Indicators: Map container stays hidden, blank screen
    Evidence: .sisyphus/evidence/task-6-map-restored.png
  ```

  **Commit**: NO (groups with Tasks 5, 7)

- [ ] 7. Wire TabShell into main.dart + Integration Tests

  **What to do**:
  - Modify `lib/main.dart`:
    - Replace `const MapScreen()` on line 69 with `const TabShell()`
    - Add import for `lib/features/navigation/screens/tab_shell.dart`
    - Keep all other routing logic (onboarding, auth, loading splash) unchanged
  - Verify the full app flow:
    - Cold start → splash → onboarding (if first launch) → auth → TabShell with 4 tabs
    - Tab switching works, map preserves state, all screens render
  - Write integration test `test/features/navigation/integration/tab_navigation_test.dart`:
    - Test: TabShell renders inside MaterialApp with providers
    - Test: Switching from Map to Pack shows PackScreen content
    - Test: Switching from Pack to Home shows SanctuaryScreen content
    - Test: Switching to Town shows EmptyStateWidget placeholder
    - Test: Switching back to Map shows MapScreen (or placeholder for test)
    - Test: MapScreen stays mounted across tab switches (IndexedStack verification)
  - Verify: `_LoadingSplash` and splash scaffold still work correctly with TabShell routing

  **Must NOT do**:
  - Add named routes or route framework
  - Modify onboarding or auth flow
  - Change _LoadingSplash
  - Modify any screen internals

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Integration wiring with multiple provider dependencies + comprehensive test suite
  - **Skills**: [`playwright`]
    - `playwright`: Web E2E verification of full tab navigation flow
  - **Skills Evaluated but Omitted**:
    - `git-master`: Not needed for implementation

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3 (sequential — depends on Tasks 2-6)
  - **Blocks**: Task 8
  - **Blocked By**: Tasks 2, 3, 4, 5, 6

  **References**:

  **Pattern References**:
  - `lib/main.dart:37-73` — FogOfWorldApp routing logic (injection point)
  - `lib/main.dart:68-69` — Exact line to modify: `AuthStatus.authenticated || AuthStatus.guest => const MapScreen()`
  - `test/integration/offline_audit_test.dart` — Integration test pattern with ProviderContainer

  **API/Type References**:
  - `lib/features/navigation/screens/tab_shell.dart` — TabShell constructor (from Task 2)
  - `lib/features/auth/models/auth_state.dart` — AuthStatus enum

  **Acceptance Criteria**:
  - [ ] `main.dart` routes to `TabShell()` instead of `MapScreen()` after auth
  - [ ] Full test suite passes: `LD_LIBRARY_PATH=. flutter test` → all pass
  - [ ] `flutter analyze` → 0 issues
  - [ ] Integration test covers tab switching and screen rendering
  - [ ] App launches correctly with 4-tab navigation

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: App launches with 4-tab bottom navigation
    Tool: Playwright (web)
    Preconditions: App deployed to localhost or dev server
    Steps:
      1. Navigate to app URL
      2. Wait for app to load (past splash screen)
      3. Assert: BottomNavigationBar visible with 4 tab icons
      4. Assert: Map tab is selected by default (index 0)
      5. Assert: Map is visible (MapLibre canvas rendering)
      6. Take screenshot
    Expected Result: 4-tab bottom nav visible, Map tab active, map rendering
    Failure Indicators: No bottom nav, single-screen map (old behavior), crash
    Evidence: .sisyphus/evidence/task-7-app-launch.png

  Scenario: Tab switching preserves map state
    Tool: Playwright (web)
    Preconditions: App loaded with Map tab active
    Steps:
      1. Note current map position/zoom
      2. Click Pack tab
      3. Assert: Pack screen content visible
      4. Click Map tab
      5. Assert: Map renders at same position/zoom (not reset to default)
      6. Take screenshot of map after returning
    Expected Result: Map state preserved — same position, same zoom, fog intact
    Failure Indicators: Map resets to default position, fog reloads, GPS restarts
    Evidence: .sisyphus/evidence/task-7-map-preserved.png

  Scenario: All 4 tabs render correct content
    Tool: Playwright (web)
    Preconditions: App loaded
    Steps:
      1. Click Map tab → Assert: map visible
      2. Click Home tab → Assert: "Sanctuary" text visible
      3. Click Town tab → Assert: "Coming Soon" text visible
      4. Click Pack tab → Assert: "Pack" text visible
      5. Take screenshot of each tab
    Expected Result: Each tab renders its designated screen
    Failure Indicators: Wrong screen on wrong tab, blank screen, crash
    Evidence: .sisyphus/evidence/task-7-all-tabs.png

  Scenario: Integration tests pass
    Tool: Bash (flutter test)
    Preconditions: Integration test file created
    Steps:
      1. Run `LD_LIBRARY_PATH=. flutter test test/features/navigation/`
      2. Assert: all tests pass
    Expected Result: All navigation tests pass
    Failure Indicators: Any test failure
    Evidence: .sisyphus/evidence/task-7-integration-tests.txt
  ```

  **Commit**: YES
  - Message: `✨ feat(navigation): wire TabShell into app + map adjustments`
  - Files: main.dart, map_screen.dart, map_visibility integration, integration tests
  - Pre-commit: `flutter analyze && LD_LIBRARY_PATH=. flutter test`

- [ ] 8. Update Documentation

  **What to do**:
  - Update `docs/roadmap.md`:
    - Mark Project 1.1 (Tab Navigation System) as **Done**
    - Mark Project 1.2 tasks completed: rename Journal→Pack ✅, remaining tasks still Planned
    - Mark Project 1.3 (Home Tab) as **Done** (or partial — wired, not redesigned)
    - Mark Project 1.4 (Town Tab) tasks completed: scaffold ✅, NPC list/interaction still Planned
  - Update root `AGENTS.md`:
    - Update "Navigation" row in Current vs Target or similar section
    - Add `features/navigation/` to Architecture Overview directory tree
    - Update package name `fog_of_world` → mention Pack (not Journal) if referenced
  - Create `lib/features/navigation/AGENTS.md` (new feature module docs):
    - Directory structure, provider pattern, TabShell architecture
    - IndexedStack keep-alive strategy documented
    - MapVisibility web integration documented
    - Known limitations (notifications stay in MapScreen, Ticker runs in background)
  - Update `docs/architecture.md`:
    - Add navigation feature to architecture diagram
    - Document tab routing flow
  - Update `docs/state.md`:
    - Add `tabIndexProvider` to provider list
  - Update `docs/game-loop.md` if applicable (navigation doesn't change game loop)

  **Must NOT do**:
  - Rewrite docs from scratch
  - Add speculative future features
  - Change design decisions

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Documentation updates with known content — no investigation needed
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `writing`: Not needed — telegraphic doc updates, not prose

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 4 (solo — after all implementation)
  - **Blocks**: F1-F4
  - **Blocked By**: Task 7

  **References**:

  **Files to update**:
  - `docs/roadmap.md` — Initiative 1 section (lines 9-37)
  - `AGENTS.md` — Root architecture overview, Quick Reference
  - `docs/architecture.md` — Architecture diagram
  - `docs/state.md` — Provider list

  **Pattern References** (for new AGENTS.md):
  - `lib/features/map/AGENTS.md` — Exemplar feature-level AGENTS.md (structure, conventions)
  - `lib/features/discovery/AGENTS.md` — Simpler feature AGENTS.md pattern

  **Acceptance Criteria**:
  - [ ] `docs/roadmap.md` reflects Initiative 1 progress
  - [ ] `lib/features/navigation/AGENTS.md` exists with correct content
  - [ ] `docs/state.md` lists `tabIndexProvider`
  - [ ] Root `AGENTS.md` architecture tree includes `navigation/`
  - [ ] `flutter analyze` → 0 issues (no code changes, but verify)

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Documentation is accurate and complete
    Tool: Bash (grep + read)
    Preconditions: All docs updated
    Steps:
      1. Run `grep -c "tabIndexProvider" docs/state.md`
      2. Assert: count >= 1
      3. Run `grep -c "navigation" AGENTS.md`
      4. Assert: count >= 1
      5. Run `grep "Done" docs/roadmap.md | head -5`
      6. Assert: Initiative 1 projects marked appropriately
      7. Verify `lib/features/navigation/AGENTS.md` exists and is 30-80 lines
    Expected Result: All docs reference new navigation feature, roadmap updated
    Failure Indicators: Missing references, stale content
    Evidence: .sisyphus/evidence/task-8-docs-verify.txt
  ```

  **Commit**: YES
  - Message: `📝 docs: update roadmap and AGENTS.md for app shell`
  - Files: docs/, AGENTS.md, lib/features/navigation/AGENTS.md
  - Pre-commit: `flutter analyze`

---

## Final Verification Wave

> 4 review agents run in PARALLEL. ALL must APPROVE. Rejection → fix → re-run.

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists (read file, run command). For each "Must NOT Have": search codebase for forbidden patterns — reject with file:line if found. Check evidence files exist in .sisyphus/evidence/. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run `flutter analyze` + `LD_LIBRARY_PATH=. flutter test`. Review all changed files for: `as dynamic`, empty catches, `print()` in prod, commented-out code, unused imports. Check AI slop: excessive comments, over-abstraction, generic names (data/result/item/temp). Verify design system compliance: no hardcoded `Color()`, uses `Theme.of(context)` and design tokens.
  Output: `Analyze [PASS/FAIL] | Tests [N pass/N fail] | Files [N clean/N issues] | VERDICT`

- [ ] F3. **Real Manual QA** — `unspecified-high` (+ `playwright` skill for web)
  Start from clean state. Execute EVERY QA scenario from EVERY task — follow exact steps, capture evidence. Test cross-tab navigation (Map→Home→Town→Pack→Map). Test MapScreen preservation after tab switch. Verify web MapLibre visibility. Save to `.sisyphus/evidence/final-qa/`.
  Output: `Scenarios [N/N pass] | Integration [N/N] | Edge Cases [N tested] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", read actual diff (git log/diff). Verify 1:1 — everything in spec was built (no missing), nothing beyond spec was built (no creep). Check "Must NOT do" compliance. Detect cross-task contamination: Task N touching Task M's files. Flag unaccounted changes.
  Output: `Tasks [N/N compliant] | Contamination [CLEAN/N issues] | Unaccounted [CLEAN/N files] | VERDICT`

---

## Commit Strategy

| Step | Commit Message | Files | Pre-commit Check |
|------|---------------|-------|-----------------|
| 1 | `♻️ refactor(pack): rename Journal→Pack throughout codebase` | All journal→pack renames | `flutter analyze && LD_LIBRARY_PATH=. flutter test` |
| 2-4 | `✨ feat(navigation): add 4-tab app shell with tab persistence` | navigation/, town placeholder, sanctuary achievement button | `flutter analyze && LD_LIBRARY_PATH=. flutter test` |
| 5-7 | `✨ feat(navigation): wire TabShell into app + map adjustments` | main.dart, map_screen.dart, map_visibility integration | `flutter analyze && LD_LIBRARY_PATH=. flutter test` |
| 8 | `📝 docs: update roadmap and AGENTS.md for app shell` | docs/, AGENTS.md files | `flutter analyze` |

---

## Success Criteria

### Verification Commands
```bash
flutter analyze                                    # Expected: 0 issues
LD_LIBRARY_PATH=. flutter test                     # Expected: all tests pass
grep -ri "journal" lib/ test/ --include="*.dart"   # Expected: 0 matches
```

### Final Checklist
- [ ] All "Must Have" present
- [ ] All "Must NOT Have" absent
- [ ] All existing tests pass
- [ ] New tests cover TabShell, tab index provider, Pack rename
- [ ] App shell functional on web (Playwright verified)
- [ ] MapScreen GPS/fog preserved across tab switches
- [ ] Tab selection persists across restart
