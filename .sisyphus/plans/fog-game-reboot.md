# Fog-of-War Nature Exploration Game — Full Reboot

## TL;DR

> **Quick Summary**: Replace the Unity geo-app with a greenfield Flutter mobile game — iNaturalist × Stardew Valley × Pokemon Go. Players explore the real world via GPS, clear fog-of-war to reveal the map, discover procedurally-seeded species, collect them in a journal, build a sanctuary, and restore habitats. Clean/modern UI with watercolor nature illustrations.
>
> **Deliverables**:
> - Flutter mobile app (iOS + Android) with MapLibre map, fog-of-war shader overlay, GPS tracking
> - 5-state fog system (Undetected → Unexplored → Hidden → Concealed → Observed)
> - Procedural species placement (30 species, 5 biomes, 3 rarity tiers)
> - Collection journal, sanctuary screen, restoration visuals, seasonal hints, daily streak
> - Supabase backend (auth, cloud save, species seed API, seasonal events)
> - TDD test suite for all core game logic
>
> **Estimated Effort**: XL (greenfield app with multiple game systems)
> **Parallel Execution**: YES — 6 waves
> **Critical Path**: Scaffolding → MapLibre+Fog Spike → Cell System → Fog State Machine → Map Screen → Species Discovery → Integration QA

---

## Context

### Original Request
User wants to trash the existing Unity/C# geo-app repo and start fresh. The current project has tile rendering failures, architectural coupling (monolithic bootstrap, scattered geospatial math), and the game design needs fundamental rethinking from "fog that reveals map tiles" to a full nature/conservation exploration game.

### Interview Summary
**Key Discussions**:
- **Tech stack**: Evaluated React Native, Flutter, and Godot. Flutter won for its Impeller shader support (atmospheric fog), MapLibre integration, compiled performance, and single codebase.
- **Game concept**: Evolved from simple fog-of-war to iNaturalist × Stardew Valley × Pokemon Go — real species discovery, sanctuary building, habitat restoration, seasonal cycles.
- **Visual style**: Clean/modern minimal UI + watercolor/illustrated nature elements. "Apple Maps meets nature journal."
- **Cell system**: Will spike both H3 hexagons and Voronoi, decide based on look/feel.
- **Fog model**: 5 awareness states (Undetected → Unexplored → Hidden → Concealed → Observed) with smooth density gradient.
- **MVP scope**: "The whole vision (lite)" — all systems present but shallow. Breadth over depth.
- **Backend**: Supabase (Postgres, auth, edge functions). Local-first architecture — SQLite is truth, Supabase syncs.
- **Test strategy**: TDD with Flutter's built-in test framework.

**Research Findings**:
- **MapLibre Flutter**: Two packages exist — `maplibre_gl` (mature, platform views) and `maplibre` by josxha (newer, Flutter-native children API). Need spike to decide.
- **Impeller shaders**: Stable in Flutter 3.41+, pre-compiled GLSL, no jank. `CustomPaint` + `FragmentProgram` pattern for fog overlay.
- **H3 hexagons**: 3+ maintained Dart packages. Deterministic, O(1) neighbors, built-in k-ring. Pokemon Go uses S2 (same family).
- **GPS**: `flutter_background_geolocation` v5.0.5 mature. Motion-detection reduces battery to 2-5%/hr.
- **Biome data**: ESA WorldCover — 10m resolution, 11 land cover classes, free, global, CC-BY-4.0.
- **Supabase offline**: Not built-in. Design local-first with SQLite, sync on demand.

### Metis Review
**Identified Gaps** (addressed):
- **Map-to-shader camera sync risk**: Added Week 1 rendering spike (Task 9) before any other implementation.
- **MapLibre package fork**: Added comparison spike (Task 7).
- **Content production bottleneck**: Locked species count at 30 for MVP with placeholder art. Content pipeline is v2.
- **"Shallow" needs numbers**: Defined hard scope ceilings per system (see Scope Ceilings table).
- **Fog transition triggers undefined**: Defaulted to proximity + distance walked (overridable).
- **Offline-first not designed**: Made SQLite the source of truth; Supabase sync is layered on top.
- **iOS "Always" location risk**: Design for "When In Use" first; background tracking is nice-to-have.
- **No monolithic bootstrap**: Architecture uses Riverpod providers with clear module boundaries.

---

## Work Objectives

### Core Objective
Build a greenfield Flutter mobile game that replaces the Unity geo-app, implementing all core game systems (fog-of-war, species collection, sanctuary, restoration, seasonal cycles, caretaking) at MVP depth, with a Supabase backend for auth and cloud save.

### Concrete Deliverables
- Flutter project replacing Unity code in this repo
- MapLibre-based map screen with atmospheric fog-of-war shader overlay
- GPS-driven exploration with 5-state fog progression
- 30 procedurally-seeded species across 5 biomes
- Collection journal screen
- Sanctuary screen (view-only gallery)
- Per-cell habitat restoration visual
- Seasonal species swap (summer/winter)
- Daily visit streak counter
- Supabase backend: auth, user progress sync, species seed API
- AGENTS.md with architecture decisions and debugging guidance
- TDD test suite covering all core game logic

### Definition of Done
- [ ] `flutter test` — all unit/widget tests pass
- [ ] `flutter build apk --release` — Android build succeeds
- [ ] `flutter build ios --release` — iOS build succeeds (on macOS)
- [ ] App launches, renders map with fog overlay, tracks GPS location
- [ ] Walking clears fog, species appear in cleared cells
- [ ] Journal shows collected species, sanctuary shows gallery
- [ ] Supabase auth works (email signup/login), progress syncs

### Must Have
- Map rendering with fog-of-war shader overlay (not blank tiles like Unity)
- GPS tracking that works in foreground ("When In Use" permission)
- All 5 fog states with visual density gradient
- Procedural species placement (deterministic per cell + biome)
- Local persistence (works fully offline)
- Supabase auth and manual cloud save
- TDD tests for cell system, fog state machine, species placement

### Must NOT Have (Guardrails)
- Camera/AI species identification (explicitly future feature)
- Multiplayer, social features, leaderboards, trading
- Real-time Supabase sync (manual "sync now" only for MVP)
- Push notifications
- More than 30 species / 5 biomes
- Particle effects at fog edges (v2 visual polish)
- More than 2 texture samplers in fog shader
- Monolithic bootstrap class (lesson from Unity's FogOfWorldMvp.cs)
- Placeholder/mock implementations for core systems that never get replaced
- `as any` / `@ts-ignore` equivalents — no type-safety bypasses
- Console.log spam in production — structured logging only

---

## Verification Strategy

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: NO (greenfield project)
- **Automated tests**: TDD (write failing test → implement → refactor)
- **Framework**: Flutter's built-in `test` package (unit + widget tests)
- **Setup**: Task 1 includes test infrastructure configuration

### QA Policy
Every task MUST include agent-executed QA scenarios.
Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

- **Frontend/UI**: Use Playwright (playwright skill) — run Flutter app, navigate, screenshot, assert
- **Game Logic**: Use Bash (`flutter test`) — unit tests for state machines, algorithms, data models
- **Backend/API**: Use Bash (curl) — hit Supabase endpoints, assert responses
- **Device Testing**: Use tmux — `flutter run` on device/emulator, interact, capture logs

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Foundation — scaffolding + data models, 6 parallel):
├── Task 1: Flutter project scaffolding + wipe Unity [quick]
├── Task 2: AGENTS.md + project documentation [quick]
├── Task 3: Core data models + type definitions [quick]
├── Task 4: Supabase project setup + schema [quick]
├── Task 5: Riverpod state management scaffolding [quick]
├── Task 6: Local persistence layer (Drift/SQLite) [quick]

Wave 2 (Spikes + Core — validate assumptions, 5 parallel):
├── Task 7: MapLibre package comparison spike (depends: 1) [deep]
├── Task 8: Cell system spike — H3 vs Voronoi (depends: 3) [deep]
├── Task 9: Fog shader proof-of-concept (depends: 1, 7) [deep]
├── Task 10: GPS integration + simulation mode (depends: 1, 5) [unspecified-high]
├── Task 11: Biome data integration — ESA WorldCover (depends: 3) [unspecified-high]

Wave 3 (Core Game Loop — primary systems, 5 parallel):
├── Task 12: Cell system implementation — spike winner (depends: 8) [deep]
├── Task 13: Fog state machine — 5 levels + transitions (depends: 3, 5, 12) [deep]
├── Task 14: Map screen — MapLibre + fog overlay + player marker (depends: 7, 9, 10) [visual-engineering]
├── Task 15: Species data model + procedural seeding (depends: 3, 11, 12) [deep]
├── Task 16: Supabase auth + user profile (depends: 4, 5) [unspecified-high]

Wave 4 (Features — game systems, 5 parallel):
├── Task 17: Species discovery mechanic (depends: 13, 14, 15) [deep]
├── Task 18: Collection journal UI (depends: 15, 16) [visual-engineering]
├── Task 19: Sanctuary screen — view-only gallery (depends: 15, 18) [visual-engineering]
├── Task 20: Habitat restoration — per-cell visual tint (depends: 13, 14) [unspecified-high]
├── Task 21: Seasonal system — summer/winter species swap (depends: 15) [unspecified-high]

Wave 5 (Integration + Polish — connecting systems, 4 parallel):
├── Task 22: Caretaking — daily visit streak counter (depends: 16, 19) [quick]
├── Task 23: Backend sync — manual cloud save (depends: 6, 16) [unspecified-high]
├── Task 24: Offline mode verification + resilience (depends: 6, 13, 17) [deep]
├── Task 25: Achievement/milestone system (depends: 13, 17) [unspecified-high]

Wave FINAL (Verification — 4 parallel):
├── F1: Plan compliance audit [oracle]
├── F2: Code quality review [unspecified-high]
├── F3: Real device QA [unspecified-high]
├── F4: Scope fidelity check [deep]

Critical Path: T1 → T7 → T9 → T14 → T17 → T24 → F1-F4
Parallel Speedup: ~65% faster than sequential
Max Concurrent: 6 (Wave 1)
```

### Dependency Matrix

| Task | Depends On | Blocks | Wave |
|------|-----------|--------|------|
| 1-6 | — | 7-16 | 1 |
| 7 | 1 | 9, 14 | 2 |
| 8 | 3 | 12 | 2 |
| 9 | 1, 7 | 14 | 2 |
| 10 | 1, 5 | 14 | 2 |
| 11 | 3 | 15 | 2 |
| 12 | 8 | 13, 15 | 3 |
| 13 | 3, 5, 12 | 17, 20, 24, 25 | 3 |
| 14 | 7, 9, 10 | 17, 20 | 3 |
| 15 | 3, 11, 12 | 17, 18, 21 | 3 |
| 16 | 4, 5 | 18, 22, 23 | 3 |
| 17 | 13, 14, 15 | 24, 25 | 4 |
| 18 | 15, 16 | 19 | 4 |
| 19 | 15, 18 | 22 | 4 |
| 20 | 13, 14 | — | 4 |
| 21 | 15 | — | 4 |
| 22 | 16, 19 | — | 5 |
| 23 | 6, 16 | — | 5 |
| 24 | 6, 13, 17 | — | 5 |
| 25 | 13, 17 | — | 5 |
| F1-F4 | ALL | — | FINAL |

### Agent Dispatch Summary

- **Wave 1 (6 tasks)**: T1-T6 → `quick` (scaffolding, types, config)
- **Wave 2 (5 tasks)**: T7-T9 → `deep` (spikes), T10-T11 → `unspecified-high`
- **Wave 3 (5 tasks)**: T12-T13, T15 → `deep`, T14 → `visual-engineering`, T16 → `unspecified-high`
- **Wave 4 (5 tasks)**: T17 → `deep`, T18-T19 → `visual-engineering`, T20-T21 → `unspecified-high`
- **Wave 5 (4 tasks)**: T22 → `quick`, T23, T25 → `unspecified-high`, T24 → `deep`
- **FINAL (4 tasks)**: F1 → `oracle`, F2-F3 → `unspecified-high`, F4 → `deep`

### Scope Ceilings (Hard Limits — Metis Mandated)

| System | MVP Ceiling | NOT in MVP |
|--------|------------|------------|
| Species | 30 total, 5 biomes, 6 per biome, 3 rarity tiers | Real photos, AI identification, camera capture |
| Sanctuary | View-only gallery of collected species | Placement, interaction, decoration, customization |
| Restoration | Per-cell visual tint change (green overlay intensity) | Animation, before/after, ecosystem simulation |
| Seasonal | 2 seasons (summer/winter), swap 20% of species pool | Full 4-season rotation, timed events, seasonal UI |
| Caretaking | Visit sanctuary daily → streak counter | Virtual pet mechanics, feeding, watering, decay |
| Fog levels | 5 discrete states mapped to density (0.0, 0.25, 0.5, 0.75, 1.0) | Per-pixel gradient, particles, animated transitions |
| Backend | Auth + manual cloud save + species seed API | Real-time sync, push notifications, social features |
| Art | Placeholder colored shapes for species, polished fog/UI | Commissioned illustrations, photo-real assets |

---

## TODOs

- [ ] 1. Flutter Project Scaffolding + Wipe Unity

  **What to do**:
  - Archive or remove all Unity-specific files (Assets/, Library/, ProjectSettings/, *.csproj, *.sln, etc.) — keep .git history, .sisyphus/, AGENTS.md
  - Run `flutter create --org com.fogofworld --project-name fog_of_world .` (or appropriate org name)
  - Configure `pubspec.yaml` with initial dependencies:
    - `maplibre_gl` AND `maplibre` (both — for spike comparison in Task 7)
    - `flutter_riverpod` (state management)
    - `drift` + `sqlite3_flutter_libs` (local persistence)
    - `supabase_flutter` (backend)
    - `flutter_background_geolocation` (GPS)
    - `geobase` (geospatial utilities)
    - `h3_flutter_plus` (H3 hex — for spike in Task 8)
  - Set up directory structure:
    ```
    lib/
      core/          # Data models, state, persistence, location
      features/      # map/, journal/, sanctuary/, discovery/, auth/
      shared/        # Widgets, themes, utilities
    test/
      core/
      features/
      integration/
    ```
  - Configure `analysis_options.yaml` with strict linting
  - Verify `flutter test` runs (even with zero tests)
  - Verify `flutter analyze` passes
  - Configure `.gitignore` for Flutter (remove Unity ignores)

  **Must NOT do**:
  - Do not delete `.git/` — preserve history
  - Do not create any game logic — scaffolding only
  - Do not pick between MapLibre packages yet (include both for spike)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Scaffolding is straightforward Flutter CLI + file ops
  - **Skills**: []
    - No special skills needed for project setup
  - **Skills Evaluated but Omitted**:
    - `playwright`: Not needed — no UI to test yet

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2, 3, 4, 5, 6)
  - **Blocks**: Tasks 7, 9, 10, 14
  - **Blocked By**: None (can start immediately)

  **References**:

  **Pattern References**:
  - Current `.gitignore` — review what Unity-specific patterns to remove, keep general patterns
  - Current `AGENTS.md` — preserve this file (will be rewritten in Task 2 but keep as reference)

  **External References**:
  - Flutter project structure best practices: https://docs.flutter.dev/resources/architectural-overview
  - `flutter create` CLI: https://docs.flutter.dev/reference/flutter-cli

  **WHY Each Reference Matters**:
  - `.gitignore`: Must be converted from Unity to Flutter patterns — wrong ignores will bloat the repo
  - `AGENTS.md`: Contains lessons learned from Unity (monolithic bootstrap, scattered geospatial math) that inform Flutter architecture

  **Acceptance Criteria**:

  **TDD**:
  - [ ] `flutter analyze` → 0 issues
  - [ ] `flutter test` → passes (0 tests is fine, framework runs)
  - [ ] `flutter build apk --debug` → succeeds

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Flutter project compiles and runs
    Tool: Bash
    Preconditions: Flutter SDK installed
    Steps:
      1. Run `flutter analyze` — expect 0 issues
      2. Run `flutter test` — expect exit code 0
      3. Run `flutter build apk --debug` — expect BUILD SUCCESSFUL
      4. Verify lib/ directory structure exists: core/, features/, shared/
      5. Verify pubspec.yaml contains all required dependencies
      6. Verify no Unity files remain (no *.csproj, no Assets/, no Library/)
    Expected Result: Clean Flutter project with all dependencies, correct structure, no Unity remnants
    Failure Indicators: flutter analyze errors, missing directories, Unity files still present
    Evidence: .sisyphus/evidence/task-1-flutter-scaffold.txt

  Scenario: Git history preserved after Unity cleanup
    Tool: Bash
    Preconditions: Git repo exists
    Steps:
      1. Run `git log --oneline -5` — expect previous Unity commits visible
      2. Run `git status` — expect clean or staged Flutter files
      3. Verify `.git/` directory exists and is valid
    Expected Result: Git history intact, new Flutter files tracked
    Failure Indicators: Missing .git/, empty git log
    Evidence: .sisyphus/evidence/task-1-git-preserved.txt
  ```

  **Commit**: YES
  - Message: `✨ feat: scaffold Flutter project, replace Unity codebase`
  - Files: All new Flutter files, removed Unity files
  - Pre-commit: `flutter analyze`

- [ ] 2. AGENTS.md + Project Documentation

  **What to do**:
  - Rewrite `AGENTS.md` for the Flutter project, incorporating:
    - Architecture decisions from this plan (Flutter + MapLibre + Impeller + Supabase + Riverpod)
    - Directory structure and module boundaries
    - Key patterns: Riverpod providers, local-first persistence, event-driven state transitions
    - Debugging guidance: high-signal logging conventions (from Unity project's AGENTS.md)
    - Constraints: scope ceilings, forbidden patterns (no monolithic bootstrap, no type-safety bypasses)
    - Known risks: camera sync, platform view composition, GPS accuracy under canopy
  - Create `lib/shared/constants.dart` with game constants:
    - `kMaxSpecies = 30`, `kBiomeCount = 5`, `kSpeciesPerBiome = 6`
    - `kFogLevels = 5`, fog density values `[1.0, 0.75, 0.5, 0.25, 0.0]`
    - `kRarityTiers = 3` (common, uncommon, rare)
    - `kSeasons = ['summer', 'winter']`

  **Must NOT do**:
  - Do not include Unity-specific guidance
  - Do not document systems that don't exist yet — document decisions and constraints

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Documentation + constants file, no complex logic
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `writing`: Quick task, standard technical docs

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 3, 4, 5, 6)
  - **Blocks**: None directly (but all tasks reference AGENTS.md)
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - Current `AGENTS.md` — extract the debugging notes pattern, high-signal logging conventions, and architecture documentation style. Port these patterns to Flutter context.

  **WHY Each Reference Matters**:
  - Current AGENTS.md has battle-tested debugging patterns (log HTTP status/bytes, verify MeshRenderer enabled, etc.) that should be adapted for Flutter (log widget tree issues, verify CustomPaint rendering, etc.)

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: AGENTS.md contains required sections
    Tool: Bash
    Preconditions: Task 1 completed (Flutter project exists)
    Steps:
      1. Read AGENTS.md — verify sections exist: Architecture, Directory Structure, Patterns, Debugging, Constraints, Risks
      2. Verify no Unity references remain
      3. Read lib/shared/constants.dart — verify kMaxSpecies=30, kBiomeCount=5, kFogLevels=5
      4. Run `flutter analyze` — expect 0 issues (constants file is valid Dart)
    Expected Result: Complete documentation with all architecture decisions and game constants
    Failure Indicators: Missing sections, Unity references, invalid Dart in constants
    Evidence: .sisyphus/evidence/task-2-agents-md.txt
  ```

  **Commit**: YES
  - Message: `📝 docs: add AGENTS.md with architecture decisions`
  - Files: `AGENTS.md`, `lib/shared/constants.dart`
  - Pre-commit: `flutter analyze`

- [ ] 3. Core Data Models + Type Definitions

  **What to do**:
  - Create `lib/core/models/` with all game data types (TDD — write tests first):
    - `fog_state.dart`: Enum with 5 states `{undetected, unexplored, hidden, concealed, observed}` + density mapping `{1.0, 0.75, 0.5, 0.25, 0.0}` + transition logic (can only progress forward, never regress)
    - `cell_data.dart`: `CellData` class — `id` (String), `center` (LatLng), `fogState` (FogState), `speciesIds` (List<String>), `restorationLevel` (double 0.0-1.0), `distanceWalked` (double meters), `visitCount` (int), `lastVisited` (DateTime?)
    - `species.dart`: `Species` class — `id` (String), `name` (String), `biome` (Biome), `rarity` (Rarity enum: common/uncommon/rare), `description` (String), `isCollected` (bool), `collectedAt` (DateTime?)
    - `biome.dart`: `Biome` enum — `{forest, grassland, wetland, urban, coastal}` with display names and color associations
    - `player_progress.dart`: `PlayerProgress` — `userId` (String), `cellsObserved` (int), `speciesCollected` (int), `currentStreak` (int), `longestStreak` (int), `totalDistanceKm` (double)
    - `season.dart`: `Season` enum — `{summer, winter}` with date range logic
  - All models must be immutable (use `@freezed` or manual `copyWith`)
  - All models must have `toJson` / `fromJson` for persistence
  - Include `equatable` or `==` override for value comparison

  **Must NOT do**:
  - No persistence logic in models — that's Task 6
  - No Riverpod providers — that's Task 5
  - No UI widgets — pure data layer

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Data classes with serialization — well-defined, no complex logic
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `ultrabrain`: Models are straightforward, no complex logic

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2, 4, 5, 6)
  - **Blocks**: Tasks 8, 11, 13, 15
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - Unity `CellState.cs` / `CellData.cs` — the 4-state model and cell data shape are the starting point. Port to Dart, expand to 5 states, add species/restoration fields.

  **External References**:
  - Freezed package (if used): https://pub.dev/packages/freezed
  - Dart data classes best practices: https://dart.dev/language/classes

  **WHY Each Reference Matters**:
  - Unity cell model had the right shape (id, center, polygon, neighbors, state) — extend it with fogDensity, speciesIds, restorationLevel, distanceWalked

  **Acceptance Criteria**:

  **TDD**:
  - [ ] Test file: `test/core/models/fog_state_test.dart` — 5 states exist, density mapping correct, transitions only progress forward
  - [ ] Test file: `test/core/models/cell_data_test.dart` — construction, copyWith, JSON round-trip
  - [ ] Test file: `test/core/models/species_test.dart` — construction, rarity tiers, JSON round-trip
  - [ ] `flutter test test/core/models/` → all pass

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: FogState transitions are strictly forward-only
    Tool: Bash
    Preconditions: Models implemented
    Steps:
      1. Run `flutter test test/core/models/fog_state_test.dart`
      2. Verify: undetected → unexplored ✓, unexplored → hidden ✓, ..., observed → observed (no-op) ✓
      3. Verify: observed → hidden REJECTED, concealed → unexplored REJECTED
    Expected Result: All tests pass — fog states can only progress, never regress
    Failure Indicators: Test failures on regression prevention
    Evidence: .sisyphus/evidence/task-3-fog-state-tests.txt

  Scenario: All models serialize to/from JSON correctly
    Tool: Bash
    Preconditions: Models implemented
    Steps:
      1. Run `flutter test test/core/models/` — all model serialization tests
      2. Verify CellData round-trips through JSON without data loss
      3. Verify Species round-trips through JSON without data loss
    Expected Result: All serialization tests pass
    Failure Indicators: JSON round-trip failures, missing fields
    Evidence: .sisyphus/evidence/task-3-model-serialization.txt
  ```

  **Commit**: YES
  - Message: `✨ feat(core): add data models and type definitions`
  - Files: `lib/core/models/*.dart`, `test/core/models/*.dart`
  - Pre-commit: `flutter test test/core/models/`

- [ ] 4. Supabase Project Setup + Schema

  **What to do**:
  - Create Supabase project (or configure existing one) via Supabase CLI or dashboard
  - Define database schema:
    ```sql
    -- Users (handled by Supabase Auth, extend with profile)
    CREATE TABLE profiles (
      id UUID REFERENCES auth.users PRIMARY KEY,
      display_name TEXT,
      current_streak INT DEFAULT 0,
      longest_streak INT DEFAULT 0,
      total_distance_km DOUBLE PRECISION DEFAULT 0,
      current_season TEXT DEFAULT 'summer',
      created_at TIMESTAMPTZ DEFAULT now(),
      updated_at TIMESTAMPTZ DEFAULT now()
    );

    -- Cell progress per user
    CREATE TABLE cell_progress (
      id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
      user_id UUID REFERENCES auth.users NOT NULL,
      cell_id TEXT NOT NULL,
      fog_state TEXT NOT NULL DEFAULT 'undetected',
      distance_walked DOUBLE PRECISION DEFAULT 0,
      visit_count INT DEFAULT 0,
      restoration_level DOUBLE PRECISION DEFAULT 0,
      last_visited TIMESTAMPTZ,
      created_at TIMESTAMPTZ DEFAULT now(),
      updated_at TIMESTAMPTZ DEFAULT now(),
      UNIQUE(user_id, cell_id)
    );

    -- Species catalog (seeded, not user-generated)
    CREATE TABLE species (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      biome TEXT NOT NULL,
      rarity TEXT NOT NULL,
      description TEXT,
      season_availability TEXT[] DEFAULT '{summer,winter}',
      created_at TIMESTAMPTZ DEFAULT now()
    );

    -- User's collected species
    CREATE TABLE collected_species (
      id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
      user_id UUID REFERENCES auth.users NOT NULL,
      species_id TEXT REFERENCES species NOT NULL,
      cell_id TEXT NOT NULL,
      collected_at TIMESTAMPTZ DEFAULT now(),
      UNIQUE(user_id, species_id)
    );
    ```
  - Enable Row Level Security (RLS) on all tables — users can only read/write their own data
  - Seed `species` table with 30 placeholder species (5 biomes × 6 species, 3 rarity tiers)
  - Create Edge Function: `generate-species-for-cell` (input: cell_id, biome → output: species list)
  - Configure `supabase_flutter` in the Flutter project with project URL and anon key
  - Store Supabase credentials in environment config (NOT hardcoded)

  **Must NOT do**:
  - No real-time subscriptions (manual sync only)
  - No push notification setup
  - No social features tables

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: SQL schema + Supabase config is well-defined
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `playwright`: No browser UI to test

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2, 3, 5, 6)
  - **Blocks**: Task 16
  - **Blocked By**: None

  **References**:

  **External References**:
  - Supabase Flutter SDK: https://supabase.com/docs/reference/dart/introduction
  - Supabase RLS guide: https://supabase.com/docs/guides/auth/row-level-security
  - Supabase Edge Functions: https://supabase.com/docs/guides/functions

  **WHY Each Reference Matters**:
  - RLS is critical for multi-user data isolation — without it, any user could read/modify other users' cell progress
  - Edge Functions documentation needed for the species generation function

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Supabase schema is correctly configured
    Tool: Bash (curl)
    Preconditions: Supabase project created
    Steps:
      1. curl GET /rest/v1/species with anon key — expect 200, 30 species returned
      2. curl GET /rest/v1/cell_progress with anon key — expect 200, empty array (RLS blocks unauthenticated)
      3. curl POST /rest/v1/profiles without auth — expect 401 (RLS enforced)
    Expected Result: Species table seeded with 30 entries, RLS blocks unauthorized access
    Failure Indicators: 401 on species (should be public read), 200 on cell_progress without auth (RLS not enabled)
    Evidence: .sisyphus/evidence/task-4-supabase-schema.txt

  Scenario: Edge Function returns species for a cell
    Tool: Bash (curl)
    Preconditions: Edge Function deployed
    Steps:
      1. curl POST /functions/v1/generate-species-for-cell with body {"cell_id": "test_cell_001", "biome": "forest"}
      2. Verify response contains species array with correct biome
      3. Verify same input returns same output (deterministic)
    Expected Result: Deterministic species list for given cell + biome
    Failure Indicators: Non-deterministic results, wrong biome species
    Evidence: .sisyphus/evidence/task-4-edge-function.txt
  ```

  **Commit**: YES
  - Message: `🔧 chore(backend): configure Supabase project and schema`
  - Files: `supabase/` directory, `.env.example`, `lib/core/config/supabase_config.dart`
  - Pre-commit: curl health check

- [ ] 5. Riverpod State Management Scaffolding

  **What to do**:
  - Set up `flutter_riverpod` (v3.x) with `ProviderScope` in `main.dart`
  - Create provider structure (TDD):
    - `lib/core/state/location_provider.dart` — GPS state (current LatLng, accuracy, isTracking)
    - `lib/core/state/fog_provider.dart` — cell fog states (Map<String, FogState>), transitions
    - `lib/core/state/collection_provider.dart` — collected species list, collection events
    - `lib/core/state/player_provider.dart` — player progress (streak, distance, stats)
    - `lib/core/state/season_provider.dart` — current season, season-based species filtering
  - Providers should be `Notifier` classes (Riverpod 3.0 pattern)
  - Each provider has clear inputs/outputs, no side effects in constructors
  - Add `riverpod_lint` for Riverpod-specific static analysis

  **Must NOT do**:
  - No actual GPS calls (Task 10)
  - No actual persistence reads (Task 6)
  - Providers should work with injected/mock data

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Provider scaffolding with clear interfaces
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `ultrabrain`: Riverpod setup is well-documented, not complex

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2, 3, 4, 6)
  - **Blocks**: Tasks 10, 13, 16
  - **Blocked By**: None

  **References**:

  **External References**:
  - Riverpod 3.0 docs: https://riverpod.dev/docs/introduction/getting-started
  - Riverpod Notifier pattern: https://riverpod.dev/docs/concepts/notifiers

  **WHY Each Reference Matters**:
  - Riverpod 3.0 has a different API from 2.x — must use `Notifier` classes, not `StateNotifier`

  **Acceptance Criteria**:

  **TDD**:
  - [ ] Test file: `test/core/state/fog_provider_test.dart` — fog transitions via provider update correctly
  - [ ] Test file: `test/core/state/collection_provider_test.dart` — adding species works
  - [ ] `flutter test test/core/state/` → all pass

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Riverpod providers initialize without errors
    Tool: Bash
    Preconditions: Providers implemented
    Steps:
      1. Run `flutter test test/core/state/` — all provider tests
      2. Verify fog_provider starts with empty state
      3. Verify collection_provider starts with empty collection
      4. Verify season_provider defaults to current season
    Expected Result: All providers initialize cleanly, tests pass
    Failure Indicators: Provider initialization errors, missing overrides
    Evidence: .sisyphus/evidence/task-5-riverpod-scaffold.txt
  ```

  **Commit**: YES
  - Message: `✨ feat(core): add Riverpod state management scaffolding`
  - Files: `lib/core/state/*.dart`, `test/core/state/*.dart`
  - Pre-commit: `flutter test test/core/state/`

- [ ] 6. Local Persistence Layer (Drift/SQLite)

  **What to do**:
  - Set up `drift` (SQLite ORM for Dart/Flutter) with code generation
  - Create local database schema mirroring Supabase tables:
    - `local_cell_progress` — same fields as Supabase `cell_progress`
    - `local_collected_species` — same fields as Supabase `collected_species`
    - `local_player_profile` — same fields as Supabase `profiles`
    - `sync_queue` — pending changes to sync to Supabase (action, table, data, timestamp)
  - Implement repository pattern (TDD):
    - `CellProgressRepository` — CRUD for cell fog states
    - `CollectionRepository` — CRUD for collected species
    - `ProfileRepository` — CRUD for player profile
    - `SyncQueueRepository` — queue changes for later sync
  - All repositories work fully offline — SQLite is the source of truth
  - Include migration support for future schema changes

  **Must NOT do**:
  - No Supabase sync logic (Task 23)
  - No actual GPS data writing (Task 10)
  - Repositories should be injectable via Riverpod

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Drift setup is well-documented, standard ORM patterns
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `ultrabrain`: ORM setup is straightforward

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2, 3, 4, 5)
  - **Blocks**: Tasks 23, 24
  - **Blocked By**: None

  **References**:

  **External References**:
  - Drift documentation: https://drift.simonbinder.eu/docs/getting-started/
  - Drift migrations: https://drift.simonbinder.eu/docs/advanced-features/migrations/

  **WHY Each Reference Matters**:
  - Drift has specific code generation setup (build_runner) that must be configured correctly
  - Migration support is needed from day 1 to avoid schema change pain later

  **Acceptance Criteria**:

  **TDD**:
  - [ ] Test file: `test/core/persistence/cell_progress_repo_test.dart` — CRUD operations round-trip
  - [ ] Test file: `test/core/persistence/collection_repo_test.dart` — add/remove/query species
  - [ ] `flutter test test/core/persistence/` → all pass

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Persistence round-trip works offline
    Tool: Bash
    Preconditions: Drift database configured
    Steps:
      1. Run `flutter test test/core/persistence/`
      2. Verify: write cell progress → read back → data matches
      3. Verify: write collected species → query by biome → correct results
      4. Verify: sync queue records pending changes
    Expected Result: All CRUD operations work, data persists across test runs
    Failure Indicators: Data loss on read-back, empty query results
    Evidence: .sisyphus/evidence/task-6-persistence-tests.txt

  Scenario: Database handles concurrent writes
    Tool: Bash
    Preconditions: Drift database configured
    Steps:
      1. Run test that writes 100 cell progress records in parallel
      2. Verify all 100 records are persisted
      3. Verify no database lock errors
    Expected Result: Concurrent writes succeed without errors
    Failure Indicators: SQLite lock errors, missing records
    Evidence: .sisyphus/evidence/task-6-concurrent-writes.txt
  ```

  **Commit**: YES
  - Message: `✨ feat(core): add local persistence layer with Drift`
  - Files: `lib/core/persistence/*.dart`, `test/core/persistence/*.dart`
  - Pre-commit: `flutter test test/core/persistence/`

- [ ] 7. MapLibre Package Comparison Spike

  **What to do**:
  - Build two minimal map screens — one with `maplibre_gl`, one with `maplibre` (josxha)
  - For EACH package, test:
    1. Basic map renders with a free tile source (MapTiler free tier or OpenFreeMap)
    2. Overlay a semi-transparent fill layer (GeoJSON polygon) on the map
    3. Overlay a Flutter `CustomPaint` widget on top of the map (Stack approach)
    4. Camera state access — can you read center, zoom, bearing in real-time during gestures?
    5. Performance on Android emulator — is panning smooth at 60fps?
    6. Offline region download capability
  - Write a comparison document in `.sisyphus/drafts/maplibre-spike-results.md`
  - **Make a recommendation** based on: overlay compatibility, camera state access, API ergonomics, offline support
  - The winner becomes the sole MapLibre dependency going forward

  **Must NOT do**:
  - No fog shader implementation (Task 9)
  - No GPS integration
  - This is a comparison spike — minimal code, maximum learning

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Requires evaluating two competing libraries, testing edge cases, making architectural recommendation
  - **Skills**: [`playwright`]
    - `playwright`: Take screenshots of map rendering for comparison evidence
  - **Skills Evaluated but Omitted**:
    - `frontend-ui-ux`: Not about design — about technical capability comparison

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 8, 10, 11)
  - **Blocks**: Tasks 9, 14
  - **Blocked By**: Task 1 (Flutter project must exist)

  **References**:

  **External References**:
  - `maplibre_gl` package: https://pub.dev/packages/maplibre_gl — platform view approach, mature API
  - `maplibre` by josxha: https://pub.dev/packages/maplibre — children-based API, WidgetLayer support, higher benchmark score
  - MapLibre style spec: https://maplibre.org/maplibre-style-spec/ — layer types (fill, line, symbol)

  **WHY Each Reference Matters**:
  - The two packages have fundamentally different APIs — `maplibre_gl` uses platform views (native), `maplibre` uses Flutter composition. This affects whether CustomPaint overlays work smoothly.
  - Style spec defines how fill layers work — needed for polygon overlay test

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Both packages render a map with polygon overlay
    Tool: Playwright + Bash
    Preconditions: Both packages added to pubspec.yaml
    Steps:
      1. Run Flutter app with maplibre_gl screen — take screenshot showing map + polygon overlay
      2. Run Flutter app with maplibre screen — take screenshot showing map + polygon overlay
      3. Compare: Which renders the polygon correctly? Which handles CustomPaint overlay?
      4. Test camera panning — does the overlay stay aligned during gestures?
    Expected Result: Both render maps; comparison doc explains which is better for overlay composition
    Failure Indicators: Map doesn't render, polygon misaligned, overlay flickers during pan
    Evidence: .sisyphus/evidence/task-7-maplibre-gl-screenshot.png, .sisyphus/evidence/task-7-maplibre-josxha-screenshot.png

  Scenario: Spike document has clear recommendation
    Tool: Bash
    Preconditions: Spike completed
    Steps:
      1. Read `.sisyphus/drafts/maplibre-spike-results.md`
      2. Verify it contains: overlay compat comparison, camera access comparison, recommendation
    Expected Result: Clear winner identified with evidence
    Failure Indicators: Inconclusive results, no recommendation
    Evidence: .sisyphus/evidence/task-7-spike-doc.txt
  ```

  **Commit**: YES
  - Message: `📝 docs: MapLibre package comparison spike results`
  - Files: `.sisyphus/drafts/maplibre-spike-results.md`, spike test files
  - Pre-commit: —

- [ ] 8. Cell System Spike — H3 vs Voronoi

  **What to do**:
  - Build two minimal cell grid implementations:
    - **H3**: Use `h3_flutter_plus` package. Given a center LatLng + radius, generate H3 cells at resolution 8 (~460m edge) and resolution 9 (~174m edge). Render as polygons on a test canvas.
    - **Voronoi**: Implement or port a basic Voronoi tessellation. Given random seed points in a bounding box, generate Voronoi cells. Render as polygons on a test canvas.
  - For EACH, evaluate:
    1. Visual appeal — do the cells look good on a map? (screenshot comparison)
    2. Performance — generate 500 cells, measure time
    3. Neighbor lookup — how fast is finding adjacent cells?
    4. Determinism — same input always produces same cells?
    5. Point-in-cell — given a GPS coordinate, which cell is it in? How fast?
    6. Dart ecosystem quality — package stability, API ergonomics
  - Write comparison in `.sisyphus/drafts/cell-system-spike-results.md`
  - **Make a recommendation** — the winner is used in Task 12

  **Must NOT do**:
  - No fog rendering
  - No MapLibre integration (separate spike)
  - No species placement logic

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Comparing two spatial indexing approaches, performance benchmarking, architectural decision
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `playwright`: Cell rendering is in test canvas, not browser

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 7, 9, 10, 11)
  - **Blocks**: Task 12
  - **Blocked By**: Task 3 (data models — CellData type needed)

  **References**:

  **Pattern References**:
  - Unity `CellStateSystem.cs` and `MockVoronoiBuilder.cs` — reference for what the old Voronoi approach looked like and its limitations

  **External References**:
  - H3 documentation: https://h3geo.org/docs/ — resolution table, k-ring, cell-to-boundary
  - `h3_flutter_plus`: https://pub.dev/packages/h3_flutter_plus — Dart/Flutter H3 bindings
  - Voronoi tessellation algorithm: Fortune's algorithm or Bowyer-Watson (Delaunay → Voronoi dual)

  **WHY Each Reference Matters**:
  - H3 resolution table tells us exactly what cell size each resolution gives — need ~200m cells, so resolution 8 or 9
  - Unity's MockVoronoiBuilder shows why the previous approach was problematic (hardcoded seeds, never upgraded)

  **Acceptance Criteria**:

  **TDD**:
  - [ ] Test: H3 cell generation is deterministic (same LatLng → same cell ID, always)
  - [ ] Test: H3 k-ring returns correct number of neighbors
  - [ ] Test: Point-in-cell lookup returns correct cell for known coordinates

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Visual comparison of H3 vs Voronoi cells
    Tool: Bash + screenshots
    Preconditions: Both implementations working
    Steps:
      1. Generate 100 H3 cells around a test coordinate, render to image
      2. Generate 100 Voronoi cells in same area, render to image
      3. Compare visual appeal, regularity, edge behavior
      4. Benchmark: generate 500 cells each, log time in ms
    Expected Result: Comparison doc with screenshots, performance numbers, clear recommendation
    Failure Indicators: Either system crashes at 500 cells, non-deterministic output
    Evidence: .sisyphus/evidence/task-8-h3-cells.png, .sisyphus/evidence/task-8-voronoi-cells.png

  Scenario: Point-in-cell lookup is fast and correct
    Tool: Bash
    Preconditions: Both implementations working
    Steps:
      1. For H3: latLng → cell ID → verify cell contains original latLng (1000 iterations, log avg time)
      2. For Voronoi: latLng → find containing cell → verify (1000 iterations, log avg time)
    Expected Result: Both correct; H3 expected to be faster (O(1) vs O(n) scan)
    Failure Indicators: Wrong cell returned, >1ms per lookup
    Evidence: .sisyphus/evidence/task-8-point-in-cell-benchmark.txt
  ```

  **Commit**: YES
  - Message: `📝 docs: H3 vs Voronoi cell system spike results`
  - Files: `.sisyphus/drafts/cell-system-spike-results.md`, spike test files
  - Pre-commit: —

- [ ] 9. Fog Shader Proof-of-Concept

  **What to do**:
  - **THIS IS THE HIGHEST-RISK TASK. If this fails, the rendering architecture needs rethinking.**
  - Build a minimal Flutter screen: MapLibre map + `CustomPaint` overlay with a GLSL fragment shader
  - The shader should:
    1. Receive map camera state as uniforms: `uMapCenter` (vec2), `uZoom` (float), `uViewportSize` (vec2)
    2. Render a dark overlay across the entire screen
    3. Cut a circular "clear" region around a hardcoded player position
    4. Use `smoothstep` for soft fog edges (not hard circle cutoff)
  - Test camera sync: when user pans/zooms the map, the fog hole must track the player's screen-space position exactly
  - Test on Android emulator — must maintain 60fps during panning
  - If camera sync is janky (fog "floats" during gestures):
    - **Fallback plan**: Use MapLibre's built-in `FillLayer` with opacity for fog (no custom shader)
    - Document which approach works and why
  - Write results in `.sisyphus/drafts/fog-shader-spike-results.md`

  **Must NOT do**:
  - No cell system integration (just one hardcoded clear region)
  - No species or game logic
  - No polished visuals — prove the camera sync works, everything else is secondary

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Highest-risk technical spike — GLSL shader + platform interop + real-time camera sync
  - **Skills**: [`playwright`]
    - `playwright`: Screenshot evidence of fog rendering + capture visual artifacts if any
  - **Skills Evaluated but Omitted**:
    - `visual-engineering`: This is about technical feasibility, not visual design

  **Parallelization**:
  - **Can Run In Parallel**: YES (after Task 7 completes — needs MapLibre package decision)
  - **Parallel Group**: Wave 2 (with Tasks 8, 10, 11 — but starts after Task 7)
  - **Blocks**: Task 14
  - **Blocked By**: Tasks 1, 7 (need Flutter project + MapLibre package winner)

  **References**:

  **External References**:
  - Flutter FragmentProgram API: https://docs.flutter.dev/ui/design/graphics/fragment-shaders
  - GLSL smoothstep reference: https://registry.khronos.org/OpenGL-Refpages/gl4/html/smoothstep.xhtml
  - Impeller architecture: https://docs.flutter.dev/perf/impeller

  **WHY Each Reference Matters**:
  - FragmentProgram API is the exact API for loading GLSL shaders in Flutter — must follow its compilation and uniform-passing patterns
  - smoothstep is the core function for soft fog edges — must understand parameters

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Fog shader renders over map without visual artifacts
    Tool: Playwright + Bash
    Preconditions: MapLibre package selected (Task 7), Flutter project exists
    Steps:
      1. Launch Flutter app with fog spike screen
      2. Take screenshot — verify dark overlay visible with clear circular region
      3. Pan the map left/right — verify fog hole stays at correct screen position
      4. Zoom in/out — verify fog hole scales appropriately
      5. Check frame rate during pan (via flutter run --profile, look for jank)
    Expected Result: Fog renders correctly, stays aligned during pan/zoom, 60fps maintained
    Failure Indicators: Fog "floats" during pan, visible tearing, <30fps
    Evidence: .sisyphus/evidence/task-9-fog-static.png, .sisyphus/evidence/task-9-fog-pan.png

  Scenario: Fallback assessment if shader approach fails
    Tool: Bash
    Preconditions: Shader approach tested
    Steps:
      1. If camera sync fails: implement MapLibre FillLayer with opacity as fog fallback
      2. Compare visual quality and performance
      3. Document findings in spike results
    Expected Result: Either shader works (proceed) or fallback documented (pivot plan available)
    Failure Indicators: Neither approach works — escalate for architecture review
    Evidence: .sisyphus/evidence/task-9-fallback-assessment.txt
  ```

  **Commit**: YES
  - Message: `✨ feat(map): fog shader proof-of-concept with MapLibre`
  - Files: fog shader GLSL file, spike screen, `.sisyphus/drafts/fog-shader-spike-results.md`
  - Pre-commit: `flutter test test/features/map/`

- [ ] 10. GPS Integration + Simulation Mode

  **What to do**:
  - Implement `LocationService` (TDD) with two modes:
    - **Real GPS**: Use `flutter_background_geolocation` — request "When In Use" permission, receive location stream
    - **Simulation**: Provide mock location stream (configurable start point, walk speed, random walk, waypoint path)
  - Integrate with Riverpod `locationProvider` (Task 5)
  - Implement GPS filtering:
    - Kalman filter or exponential moving average for noisy readings
    - Discard readings with accuracy > 50m
    - Cell boundary hysteresis: require player to be 20m inside a new cell before triggering transition
  - Add simulation controls (dev-only UI): speed slider, teleport to coordinates, toggle real/sim mode
  - Default to simulation mode in debug builds, real GPS in release

  **Must NOT do**:
  - No "Always" background location permission (foreground only for MVP)
  - No cell state transitions (that's Task 13)
  - No map rendering (that's Task 14)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: GPS integration with filtering, platform permissions, simulation system
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `playwright`: No UI to test — this is a service layer

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 7, 8, 9, 11)
  - **Blocks**: Task 14
  - **Blocked By**: Tasks 1, 5 (Flutter project + Riverpod providers)

  **References**:

  **Pattern References**:
  - Unity `PlayerLocationTracker.cs` — had GPS init with fallback simulation, random-walk idle, configurable speeds/start. Port the simulation logic pattern to Dart.

  **External References**:
  - `flutter_background_geolocation` docs: https://pub.dev/packages/flutter_background_geolocation
  - Kalman filter for GPS: search for Dart implementations or port from existing

  **WHY Each Reference Matters**:
  - Unity's PlayerLocationTracker had a good simulation model (random walk, configurable speed) — worth porting
  - flutter_background_geolocation's motion-detection system helps reduce battery drain

  **Acceptance Criteria**:

  **TDD**:
  - [ ] Test: simulation mode produces location updates at expected interval
  - [ ] Test: GPS filter rejects readings with accuracy > 50m
  - [ ] Test: cell boundary hysteresis prevents rapid toggling
  - [ ] `flutter test test/core/location/` → all pass

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Simulation mode produces continuous location updates
    Tool: Bash
    Preconditions: LocationService implemented
    Steps:
      1. Run test that starts simulation mode at known coordinates
      2. Collect 20 location updates
      3. Verify each update has valid lat/lon within expected range
      4. Verify updates arrive at configured interval (±50ms)
    Expected Result: Continuous, valid location stream from simulator
    Failure Indicators: Missing updates, out-of-range coordinates, irregular timing
    Evidence: .sisyphus/evidence/task-10-simulation-updates.txt

  Scenario: GPS filter rejects bad readings
    Tool: Bash
    Preconditions: GPS filter implemented
    Steps:
      1. Feed location updates with accuracy values: 5m, 100m, 10m, 200m, 3m
      2. Verify filtered output contains only updates with accuracy ≤50m (5m, 10m, 3m)
    Expected Result: Bad accuracy readings discarded
    Failure Indicators: High-accuracy readings pass through, valid readings dropped
    Evidence: .sisyphus/evidence/task-10-gps-filter.txt
  ```

  **Commit**: YES
  - Message: `✨ feat(core): GPS integration with simulation mode`
  - Files: `lib/core/location/*.dart`, `test/core/location/*.dart`
  - Pre-commit: `flutter test test/core/location/`

- [ ] 11. Biome Data Integration — ESA WorldCover

  **What to do**:
  - Implement `BiomeService` (TDD) that classifies a LatLng into one of 5 game biomes:
    - Map ESA WorldCover's 11 land cover classes → 5 game biomes:
      - Tree cover → forest
      - Shrubland, grassland, moss/lichen → grassland
      - Wetland, mangroves → wetland
      - Built-up → urban
      - Water, bare/sparse, cropland → coastal (or urban fallback)
    - Snow/ice → grassland fallback
  - Download strategy: pre-package a lookup table or small tile set for the player's region
  - For MVP: can use a simplified approach — reverse geocoding to get rough land cover, or pre-computed biome grid at coarse resolution (~1km)
  - Fallback: if no biome data available for a location, default to "grassland" (most generic)
  - The biome determines which species pool a cell draws from

  **Must NOT do**:
  - No species placement logic (Task 15)
  - No real-time GeoTIFF processing on device (too heavy)
  - No custom biome boundaries

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Geospatial data integration, classification logic, offline data strategy
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `ultrabrain`: Classification mapping is straightforward lookup, not complex logic

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 7, 8, 9, 10)
  - **Blocks**: Task 15
  - **Blocked By**: Task 3 (Biome enum defined in data models)

  **References**:

  **External References**:
  - ESA WorldCover: https://worldcover2021.esa.int/ — 10m resolution, 11 classes, CC-BY-4.0
  - ESA WorldCover class definitions: https://worldcover2021.esa.int/data/docs/WorldCover_PUM_V2.0.pdf

  **WHY Each Reference Matters**:
  - The 11→5 class mapping is the core logic — ESA's class definitions document tells us exactly what each class means

  **Acceptance Criteria**:

  **TDD**:
  - [ ] Test: known coordinates return expected biome (e.g., NYC Central Park → forest/urban)
  - [ ] Test: fallback returns grassland when no data available
  - [ ] Test: all 11 ESA classes map to exactly one of 5 biomes
  - [ ] `flutter test test/core/biome/` → all pass

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Biome classification returns correct results
    Tool: Bash
    Preconditions: BiomeService implemented with test data
    Steps:
      1. Run `flutter test test/core/biome/`
      2. Verify: lat/lon of a known forest → Biome.forest
      3. Verify: lat/lon of a known city center → Biome.urban
      4. Verify: lat/lon with no data → Biome.grassland (fallback)
    Expected Result: All biome classifications correct, fallback works
    Failure Indicators: Wrong biome returned, crash on missing data
    Evidence: .sisyphus/evidence/task-11-biome-classification.txt
  ```

  **Commit**: YES
  - Message: `✨ feat(core): biome classification with ESA WorldCover`
  - Files: `lib/core/biome/*.dart`, `test/core/biome/*.dart`
  - Pre-commit: `flutter test test/core/biome/`

- [ ] 12. Cell System Implementation (Spike Winner)

  **What to do**:
  - Implement the cell system based on Task 8's spike recommendation (H3 or Voronoi)
  - Create `CellService` (TDD):
    - `getCellForLocation(LatLng)` → CellData (the cell containing this point)
    - `getNeighbors(cellId)` → List<CellData> (adjacent cells)
    - `getCellsInRadius(LatLng, radiusMeters)` → List<CellData> (all cells within radius)
    - `getCellBoundary(cellId)` → List<LatLng> (polygon vertices for rendering)
  - Integrate with `CellData` model from Task 3
  - Cell resolution: ~200m diameter (H3 res 9 = ~174m edge, or equivalent Voronoi density)
  - All operations must be client-side (no server calls)
  - Include caching: once a cell is computed, store in memory map

  **Must NOT do**:
  - No fog state logic (Task 13)
  - No species placement (Task 15)
  - No map rendering (Task 14)

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Core spatial system, performance-critical, must be correct and fast
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `ultrabrain`: Deep is sufficient — algorithm is well-defined from spike

  **Parallelization**:
  - **Can Run In Parallel**: YES (first in Wave 3)
  - **Parallel Group**: Wave 3 (with Tasks 13, 14, 15, 16)
  - **Blocks**: Tasks 13, 15
  - **Blocked By**: Task 8 (spike must complete to know which system)

  **References**:

  **Pattern References**:
  - Task 8 spike results (`.sisyphus/drafts/cell-system-spike-results.md`) — the recommended approach and its API

  **External References**:
  - H3 resolution table: https://h3geo.org/docs/core-library/restable — cell sizes per resolution
  - `h3_flutter_plus` or winning package API docs

  **WHY Each Reference Matters**:
  - Spike results contain the specific API patterns, performance benchmarks, and decision rationale that inform implementation

  **Acceptance Criteria**:

  **TDD**:
  - [ ] Test: `getCellForLocation` is deterministic (same LatLng → same cell ID, 1000 iterations)
  - [ ] Test: `getNeighbors` returns expected count (6 for hex, variable for Voronoi)
  - [ ] Test: `getCellsInRadius` returns correct count for known radius
  - [ ] Test: `getCellBoundary` returns valid polygon (closed, >3 vertices)
  - [ ] `flutter test test/core/cells/` → all pass

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Cell lookups are fast enough for real-time GPS updates
    Tool: Bash
    Preconditions: CellService implemented
    Steps:
      1. Benchmark: 1000 getCellForLocation calls, measure avg time
      2. Benchmark: 1000 getNeighbors calls, measure avg time
      3. Verify avg < 1ms per call (needed for real-time GPS at 1Hz)
    Expected Result: Sub-millisecond cell lookups
    Failure Indicators: >5ms per call, memory growth over iterations
    Evidence: .sisyphus/evidence/task-12-cell-benchmark.txt
  ```

  **Commit**: YES
  - Message: `✨ feat(core): cell system implementation`
  - Files: `lib/core/cells/*.dart`, `test/core/cells/*.dart`
  - Pre-commit: `flutter test test/core/cells/`

- [ ] 13. Fog State Machine — 5 Levels + Transitions

  **What to do**:
  - Implement `FogStateMachine` (TDD) that manages fog state per cell:
    - States: Undetected (1.0) → Unexplored (0.75) → Hidden (0.5) → Concealed (0.25) → Observed (0.0)
    - Transition triggers:
      - **Proximity**: cells within k-ring radius of player move from Undetected → Unexplored
      - **Entry**: stepping into a cell moves it from Unexplored → Hidden
      - **Distance walked**: walking X meters in a cell progresses Hidden → Concealed → Observed
      - Thresholds: Hidden→Concealed at 100m walked, Concealed→Observed at 300m walked (configurable)
    - States NEVER regress (observed → concealed is forbidden)
  - Integrate with:
    - `CellService` (Task 12) — know which cell player is in
    - `locationProvider` (Task 5) — receive GPS updates
    - `fogProvider` (Task 5) — update fog state for cells
    - `CellProgressRepository` (Task 6) — persist fog state to SQLite
  - Fire events on state transitions: `onFogStateChanged(cellId, oldState, newState)`
  - Track distance walked per cell using cumulative GPS displacement

  **Must NOT do**:
  - No map rendering (Task 14)
  - No species discovery logic (Task 17 — triggered separately by fog reaching Observed)
  - No restoration mechanics (Task 20)

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Core state machine with multiple transition rules, persistence integration, event system
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `ultrabrain`: Deep is sufficient for state machine logic

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 12, 14, 15, 16)
  - **Blocks**: Tasks 17, 20, 24, 25
  - **Blocked By**: Tasks 3, 5, 12 (models, providers, cell system)

  **References**:

  **Pattern References**:
  - Unity `CellStateSystem.cs` lines 72-94 — event-driven state transition logic. Port the pattern (not the code) to Dart with Riverpod notifiers.

  **WHY Each Reference Matters**:
  - Unity's state transition logic worked conceptually. The event-driven pattern (listen for location → compute cell → check transition → fire event) should carry forward.

  **Acceptance Criteria**:

  **TDD**:
  - [ ] Test: proximity reveal — cells within k-ring move to Unexplored
  - [ ] Test: entry — stepping into Unexplored cell moves to Hidden
  - [ ] Test: distance thresholds — walking 100m moves Hidden→Concealed, 300m moves Concealed→Observed
  - [ ] Test: regression forbidden — attempting Observed→Hidden throws or no-ops
  - [ ] Test: persistence — fog state survives app restart (via mock repository)
  - [ ] `flutter test test/core/fog/` → all pass

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Complete fog lifecycle from Undetected to Observed
    Tool: Bash
    Preconditions: FogStateMachine + CellService + mock LocationService
    Steps:
      1. Start with all cells Undetected
      2. Simulate player at position P — verify nearby cells (k-ring) become Unexplored
      3. Simulate player entering cell C — verify C becomes Hidden
      4. Simulate walking 100m in cell C — verify C becomes Concealed
      5. Simulate walking 200m more in cell C (total 300m) — verify C becomes Observed
      6. Verify C stays Observed when player leaves and returns
    Expected Result: Full 5-state lifecycle works correctly
    Failure Indicators: Wrong state at any step, regression occurs
    Evidence: .sisyphus/evidence/task-13-fog-lifecycle.txt

  Scenario: Fog states persist across app restart
    Tool: Bash
    Preconditions: Persistence layer (Task 6) integrated
    Steps:
      1. Progress 3 cells to various states (Unexplored, Hidden, Observed)
      2. Simulate "app restart" (reinitialize FogStateMachine from repository)
      3. Verify all 3 cells retain their states
    Expected Result: States survive restart
    Failure Indicators: States reset to Undetected after restart
    Evidence: .sisyphus/evidence/task-13-fog-persistence.txt
  ```

  **Commit**: YES
  - Message: `✨ feat(core): fog state machine with 5-level transitions`
  - Files: `lib/core/fog/*.dart`, `test/core/fog/*.dart`
  - Pre-commit: `flutter test test/core/fog/`

- [ ] 14. Map Screen — MapLibre + Fog Overlay + Player Marker

  **What to do**:
  - Build the main map screen using the MapLibre package winner from Task 7
  - Integrate the fog shader from Task 9 (or fallback FillLayer approach)
  - Layer structure (Stack):
    1. MapLibre map (base) — free vector tiles, north-up
    2. Fog overlay (CustomPaint or FillLayer) — reads fog state per cell from `fogProvider`
    3. Player marker — current GPS position from `locationProvider`
    4. Cell boundaries (optional, toggle-able) — debug visualization of cell grid
  - Camera: follow player position, configurable zoom level, smooth animation
  - Fog rendering: for each visible cell, render opacity based on fog state density value
  - The fog must update in real-time as `fogProvider` state changes
  - Handle map gestures: allow user to pan/zoom freely, "re-center" button to snap back to player
  - Clean/modern minimal UI: thin status bar at top (species count, distance today, streak)

  **Must NOT do**:
  - No species markers on map (Task 17)
  - No sanctuary navigation
  - No detailed cell interaction (tap cell for info)
  - No particle effects at fog edges

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: Primary UI screen with shader rendering, map integration, real-time updates
  - **Skills**: [`playwright`, `frontend-ui-ux`]
    - `playwright`: Screenshot testing of map rendering, visual regression
    - `frontend-ui-ux`: Clean/modern minimal UI design for status bar and controls
  - **Skills Evaluated but Omitted**:
    - `dev-browser`: Flutter app, not web app

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 12, 13, 15, 16)
  - **Blocks**: Tasks 17, 20
  - **Blocked By**: Tasks 7, 9, 10 (MapLibre choice, fog shader spike, GPS integration)

  **References**:

  **Pattern References**:
  - Task 7 spike results — MapLibre package winner and its specific API patterns
  - Task 9 spike results — fog shader approach (CustomPaint or FillLayer fallback)

  **External References**:
  - MapLibre style spec for fill layers: https://maplibre.org/maplibre-style-spec/layers/#fill
  - Flutter Stack widget: https://api.flutter.dev/flutter/widgets/Stack-class.html

  **WHY Each Reference Matters**:
  - The spike results determine which exact API to use — critical for correct implementation
  - Fill layer spec needed if using FillLayer fallback for fog

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Map renders with fog overlay and player marker
    Tool: Playwright
    Preconditions: MapLibre + fog + GPS integrated
    Steps:
      1. Launch app in simulation mode (debug build)
      2. Wait for map to load (tiles visible)
      3. Screenshot — verify: map tiles visible, fog overlay visible (dark areas), player marker visible
      4. Verify fog is NOT blank/all-dark — some cells should be cleared based on player position
      5. Verify player marker is at center of cleared fog region
    Expected Result: Map + fog + marker all render correctly in composition
    Failure Indicators: Blank map, no fog visible, marker missing, fog covering player position
    Evidence: .sisyphus/evidence/task-14-map-screen.png

  Scenario: Fog updates in real-time as player moves
    Tool: Playwright
    Preconditions: Simulation mode active
    Steps:
      1. Screenshot initial state
      2. Wait 10 seconds (simulation moves player)
      3. Screenshot — verify fog has cleared in new area
      4. Compare screenshots — new clear region visible
    Expected Result: Fog visually changes as player explores
    Failure Indicators: Fog unchanged between screenshots, UI frozen
    Evidence: .sisyphus/evidence/task-14-fog-update-before.png, .sisyphus/evidence/task-14-fog-update-after.png

  Scenario: Re-center button snaps camera to player
    Tool: Playwright
    Preconditions: Map screen with pan gesture support
    Steps:
      1. Pan map away from player marker
      2. Tap re-center button
      3. Verify camera animates back to player position
    Expected Result: Camera smoothly returns to player
    Failure Indicators: Button missing, camera doesn't move, jarring snap instead of animation
    Evidence: .sisyphus/evidence/task-14-recenter.png
  ```

  **Commit**: YES
  - Message: `🎨 feat(ui): map screen with fog overlay and player marker`
  - Files: `lib/features/map/*.dart`, `test/features/map/*.dart`, shader files
  - Pre-commit: `flutter test test/features/map/`

- [ ] 15. Species Data Model + Procedural Seeding Algorithm

  **What to do**:
  - Implement `SpeciesService` (TDD):
    - Load 30 species from local seed data (JSON bundled with app, mirroring Supabase `species` table)
    - `getSpeciesForCell(cellId, biome)` → List<Species> — deterministic seeding:
      - Hash: `sha256(cellId + biome)` → seed → select species from biome pool
      - Each cell gets 1-3 species (based on seed modulo)
      - Rarity distribution: 60% common, 30% uncommon, 10% rare
      - Same cell+biome ALWAYS returns same species (deterministic)
    - `getSpeciesBySeason(species, season)` → bool — whether species is available this season
  - Create seed data file: `assets/species_seed.json` with 30 species:
    - 6 per biome × 5 biomes
    - 3 rarity tiers per biome (3 common, 2 uncommon, 1 rare)
    - Each species: id, name (real species names), biome, rarity, description (1-2 sentences), seasons (array)
    - For winter-only species: mark 6 species (20% of 30) as winter-available
  - Species names should be real (e.g., "Eastern Bluebird", "White Oak", "Red Fox") for the nature/conservation feel

  **Must NOT do**:
  - No species art/images (placeholder colored shapes by biome)
  - No collection logic (Task 17)
  - No AI identification

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Deterministic hashing algorithm, seed data creation, rarity distribution system
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `writing`: Species descriptions are 1-2 sentences, not full content

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 12, 13, 14, 16)
  - **Blocks**: Tasks 17, 18, 21
  - **Blocked By**: Tasks 3, 11, 12 (models, biome service, cell system)

  **References**:

  **External References**:
  - iNaturalist species database (for real species names): https://www.inaturalist.org/
  - SHA-256 in Dart: `crypto` package

  **WHY Each Reference Matters**:
  - Real species names from iNaturalist give the conservation theme authenticity
  - Deterministic hashing is the core algorithm — must use a well-tested hash function

  **Acceptance Criteria**:

  **TDD**:
  - [ ] Test: same cell_id + biome always returns identical species list (100 iterations)
  - [ ] Test: rarity distribution across 100 cells ≈ 60/30/10 (±10%)
  - [ ] Test: each biome has exactly 6 species in seed data
  - [ ] Test: seasonal filtering excludes winter-only species in summer
  - [ ] `flutter test test/core/species/` → all pass

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Species seeding is deterministic
    Tool: Bash
    Preconditions: SpeciesService implemented + seed data loaded
    Steps:
      1. Call getSpeciesForCell("test_cell_001", Biome.forest) 100 times
      2. Verify all 100 calls return identical species list
      3. Call with different cell_id — verify different species returned
    Expected Result: Perfect determinism — same input → same output, always
    Failure Indicators: Any variation between calls
    Evidence: .sisyphus/evidence/task-15-deterministic-seeding.txt

  Scenario: Seed data contains exactly 30 valid species
    Tool: Bash
    Preconditions: species_seed.json created
    Steps:
      1. Parse assets/species_seed.json
      2. Verify exactly 30 entries
      3. Verify 6 per biome (forest=6, grassland=6, wetland=6, urban=6, coastal=6)
      4. Verify rarity distribution per biome: 3 common, 2 uncommon, 1 rare
      5. Verify all species have: id, name, biome, rarity, description, seasons
    Expected Result: Complete, valid seed data
    Failure Indicators: Wrong count, missing fields, biome imbalance
    Evidence: .sisyphus/evidence/task-15-seed-data-validation.txt
  ```

  **Commit**: YES
  - Message: `✨ feat(core): procedural species seeding algorithm`
  - Files: `lib/core/species/*.dart`, `test/core/species/*.dart`, `assets/species_seed.json`
  - Pre-commit: `flutter test test/core/species/`

- [ ] 16. Supabase Auth + User Profile

  **What to do**:
  - Implement authentication flow using `supabase_flutter`:
    - Email/password signup and login
    - Auto-create `profiles` row on first signup (via Supabase trigger or client-side)
    - Session persistence (stay logged in across app restarts)
    - Logout functionality
  - Build minimal auth UI:
    - Login screen (email + password fields, login button, "create account" link)
    - Signup screen (email + password + display name, create button)
    - Clean/modern minimal style matching the app aesthetic
  - Integrate with Riverpod `playerProvider` — load profile on auth, clear on logout
  - Handle auth errors gracefully: invalid credentials, network failure, duplicate email
  - Guest mode: allow playing without auth (local only, no sync)

  **Must NOT do**:
  - No social login (Google/Apple) — email only for MVP
  - No password reset flow (v2)
  - No avatar upload

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Auth flow with Supabase, UI screens, error handling, session management
  - **Skills**: [`frontend-ui-ux`]
    - `frontend-ui-ux`: Login/signup screens should match the clean/modern aesthetic
  - **Skills Evaluated but Omitted**:
    - `playwright`: Auth testing better done via unit tests and curl

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 12, 13, 14, 15)
  - **Blocks**: Tasks 18, 22, 23
  - **Blocked By**: Tasks 4, 5 (Supabase project, Riverpod)

  **References**:

  **External References**:
  - Supabase Flutter Auth: https://supabase.com/docs/guides/auth/quickstarts/flutter
  - Supabase Auth helpers: https://pub.dev/packages/supabase_auth_ui

  **WHY Each Reference Matters**:
  - Supabase Flutter auth has specific patterns for session persistence and token refresh that must be followed

  **Acceptance Criteria**:

  **TDD**:
  - [ ] Test: signup creates account + profile (mock Supabase client)
  - [ ] Test: login returns valid session
  - [ ] Test: invalid credentials return appropriate error
  - [ ] Test: guest mode works without auth
  - [ ] `flutter test test/features/auth/` → all pass

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Complete signup → login → session persistence flow
    Tool: Bash (curl) + Playwright
    Preconditions: Supabase project running
    Steps:
      1. curl POST /auth/v1/signup with test email + password — expect 200 + user object
      2. curl POST /auth/v1/token?grant_type=password with same credentials — expect access_token
      3. Launch app, enter credentials on login screen, tap login
      4. Verify app navigates to map screen
      5. Kill and relaunch app — verify still logged in (session persisted)
    Expected Result: Full auth lifecycle works, session survives restart
    Failure Indicators: Signup fails, login returns 401, session lost on restart
    Evidence: .sisyphus/evidence/task-16-auth-flow.txt

  Scenario: Guest mode allows playing without auth
    Tool: Playwright
    Preconditions: App launched
    Steps:
      1. On login screen, tap "Play as Guest" (or equivalent)
      2. Verify app navigates to map screen
      3. Verify exploration works (fog clears, species discoverable)
      4. Verify sync/save features are disabled or show "login to save" prompt
    Expected Result: Full game loop works without auth, sync features gated
    Failure Indicators: Guest blocked from gameplay, crash without auth
    Evidence: .sisyphus/evidence/task-16-guest-mode.png
  ```

  **Commit**: YES
  - Message: `🔐 feat(auth): Supabase authentication and user profile`
  - Files: `lib/features/auth/*.dart`, `test/features/auth/*.dart`
  - Pre-commit: `flutter test test/features/auth/`

- [ ] 17. Species Discovery Mechanic

  **What to do**:
  - Implement the core discovery loop (TDD):
    - When a cell reaches **Observed** fog state → trigger species reveal for that cell
    - Show a discovery notification/animation: "You discovered [Species Name]!"
    - Add species to player's collection (via `collectionProvider`)
    - Persist to SQLite via `CollectionRepository`
    - Species that are already collected → show "Already in your journal" (no duplicate)
    - Seasonal gate: if species is winter-only and it's summer → skip, leave for winter
  - Integrate with:
    - `FogStateMachine` (Task 13) — listen for `onFogStateChanged` → Observed
    - `SpeciesService` (Task 15) — get species for the observed cell
    - `collectionProvider` (Task 5) — update collection state
    - Map screen (Task 14) — show discovery UI overlay
  - Discovery animation: simple fade-in card with species name, rarity badge, biome icon
  - Sound: optional tap/chime sound effect on discovery (or skip for MVP)

  **Must NOT do**:
  - No camera/photo capture
  - No detailed species info screen (just name + rarity in notification)
  - No species markers on map (keep map clean)

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Core game mechanic integrating fog, species, collection, and UI systems
  - **Skills**: [`frontend-ui-ux`]
    - `frontend-ui-ux`: Discovery notification needs to feel rewarding — animation and design matter
  - **Skills Evaluated but Omitted**:
    - `playwright`: Discovery is triggered by game state, hard to test in browser

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 18, 19, 20, 21)
  - **Blocks**: Tasks 24, 25
  - **Blocked By**: Tasks 13, 14, 15 (fog state machine, map screen, species service)

  **References**:

  **Pattern References**:
  - Unity `CellStateSystem.cs` `OnCellStateChanged` event pattern — same event-driven approach for triggering discovery

  **WHY Each Reference Matters**:
  - The event-driven pattern (fog state change → trigger discovery) is proven from Unity implementation

  **Acceptance Criteria**:

  **TDD**:
  - [ ] Test: cell reaching Observed triggers species discovery
  - [ ] Test: already-collected species shows "already collected" (no duplicate)
  - [ ] Test: winter-only species not discoverable in summer
  - [ ] Test: discovery persists to repository
  - [ ] `flutter test test/features/discovery/` → all pass

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Walking into a new area discovers species
    Tool: Playwright
    Preconditions: Simulation mode, app running, at least one cell approaching Observed
    Steps:
      1. Wait for simulation to walk enough distance to trigger Observed state on a cell
      2. Verify discovery notification appears with species name and rarity
      3. Dismiss notification
      4. Verify species count in status bar incremented
    Expected Result: Discovery triggers, notification shows, collection updates
    Failure Indicators: No notification on Observed, wrong species shown, count unchanged
    Evidence: .sisyphus/evidence/task-17-species-discovery.png

  Scenario: Duplicate species not re-discovered
    Tool: Bash
    Preconditions: Species already in collection
    Steps:
      1. Simulate cell reaching Observed with species player already has
      2. Verify "Already in your journal" message (not full discovery)
      3. Verify collection count unchanged
    Expected Result: No duplicate, appropriate feedback
    Failure Indicators: Duplicate added, full discovery animation for known species
    Evidence: .sisyphus/evidence/task-17-no-duplicate.txt
  ```

  **Commit**: YES
  - Message: `✨ feat(gameplay): species discovery mechanic`
  - Files: `lib/features/discovery/*.dart`, `test/features/discovery/*.dart`
  - Pre-commit: `flutter test test/features/discovery/`

- [ ] 18. Collection Journal UI

  **What to do**:
  - Build the journal screen — a browsable catalog of all species (TDD for logic, visual for UI):
    - Grid or list view showing all 30 species
    - Collected species: show name, biome icon, rarity badge, colored placeholder art
    - Uncollected species: show silhouette/shadow with "???" — player knows something exists but not what
    - Filter by: biome, rarity, collected/uncollected
    - Sort by: recently collected, rarity, biome
    - Progress indicator: "12/30 species collected" with progress bar
  - Species detail card (tap to expand):
    - Name, description (1-2 sentences), biome, rarity
    - "Collected on [date] at [location name]" if collected
    - Placeholder art (colored shape by biome + rarity border)
  - Navigation: accessible from main map screen via bottom nav or floating button
  - Clean/modern minimal + watercolor aesthetic for species cards

  **Must NOT do**:
  - No real species photos or illustrations (placeholder shapes)
  - No sharing functionality
  - No species comparison or trading

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: Primary UI screen with grid layout, filtering, animations, watercolor aesthetic
  - **Skills**: [`frontend-ui-ux`]
    - `frontend-ui-ux`: Journal is a major UI surface — needs to feel beautiful and polished
  - **Skills Evaluated but Omitted**:
    - `playwright`: Use for final screenshot verification

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 17, 19, 20, 21)
  - **Blocks**: Task 19
  - **Blocked By**: Tasks 15, 16 (species data, auth for user context)

  **References**:

  **External References**:
  - Flutter GridView: https://api.flutter.dev/flutter/widgets/GridView-class.html
  - iNaturalist species cards (for UX inspiration, not for copying)

  **WHY Each Reference Matters**:
  - iNaturalist's species card design is the gold standard for nature app UX — study the information hierarchy

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Journal shows collected and uncollected species
    Tool: Playwright
    Preconditions: Player has collected 5 of 30 species
    Steps:
      1. Navigate to journal screen
      2. Verify 5 species show full details (name, rarity, biome)
      3. Verify 25 species show silhouette with "???"
      4. Verify progress bar shows "5/30"
      5. Filter by "collected" — verify only 5 shown
      6. Filter by biome "forest" — verify only forest species shown
    Expected Result: Journal correctly shows collection state, filters work
    Failure Indicators: Wrong counts, filter broken, uncollected species revealed
    Evidence: .sisyphus/evidence/task-18-journal-overview.png, .sisyphus/evidence/task-18-journal-filtered.png

  Scenario: Species detail card shows correct info
    Tool: Playwright
    Preconditions: At least one collected species
    Steps:
      1. Tap on a collected species in journal
      2. Verify detail card shows: name, description, biome, rarity, collection date
      3. Tap on an uncollected species
      4. Verify detail card shows: "???" name, biome hint, "Not yet discovered"
    Expected Result: Detail cards show appropriate info based on collection state
    Failure Indicators: Missing fields, uncollected species reveal name
    Evidence: .sisyphus/evidence/task-18-species-detail.png
  ```

  **Commit**: YES
  - Message: `🎨 feat(ui): collection journal screen`
  - Files: `lib/features/journal/*.dart`, `test/features/journal/*.dart`
  - Pre-commit: `flutter test test/features/journal/`

- [ ] 19. Sanctuary Screen — View-Only Gallery

  **What to do**:
  - Build the sanctuary screen — a beautiful gallery of collected species:
    - Grid layout showing collected species in a "nature scene" arrangement
    - Each species displayed as its placeholder art (colored shape) with name label
    - Grouped by biome (forest section, wetland section, etc.)
    - Empty biome sections show "Explore [biome] areas to discover species"
    - Overall sanctuary "health" indicator based on collection completeness
    - Ambient feel — this should feel like visiting a peaceful garden, not a data grid
  - Navigation: accessible from bottom nav alongside map and journal
  - Streak display: show current daily visit streak prominently ("Day 5 🔥")
  - Clean/modern watercolor aesthetic — cards with soft edges, nature-themed colors

  **Must NOT do**:
  - No species placement or arrangement by player (view-only for MVP)
  - No interaction with individual species (no feeding, watering)
  - No sanctuary decoration or customization
  - No 3D or isometric view

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: Ambient, beautiful gallery screen — visual design is the primary challenge
  - **Skills**: [`frontend-ui-ux`]
    - `frontend-ui-ux`: Sanctuary must feel cozy and peaceful — UX/atmosphere matters more than features
  - **Skills Evaluated but Omitted**:
    - `playwright`: Use for screenshot verification

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 17, 18, 20, 21)
  - **Blocks**: Task 22
  - **Blocked By**: Tasks 15, 18 (species data, journal navigation pattern)

  **References**:

  **External References**:
  - Stardew Valley museum/collection screen (UX inspiration for how a collection gallery feels cozy)

  **WHY Each Reference Matters**:
  - Stardew's museum shows how to make a collection display feel rewarding and alive, not like a database

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Sanctuary displays collected species by biome
    Tool: Playwright
    Preconditions: Player has species from at least 2 biomes
    Steps:
      1. Navigate to sanctuary screen
      2. Verify biome sections are visible (at least 2 with species)
      3. Verify empty biome sections show placeholder message
      4. Verify streak counter is displayed
      5. Screenshot — verify ambient/peaceful aesthetic
    Expected Result: Species grouped by biome, empty sections handled gracefully
    Failure Indicators: Species ungrouped, missing biomes, streak counter absent
    Evidence: .sisyphus/evidence/task-19-sanctuary-overview.png
  ```

  **Commit**: YES
  - Message: `🎨 feat(ui): sanctuary gallery screen`
  - Files: `lib/features/sanctuary/*.dart`, `test/features/sanctuary/*.dart`
  - Pre-commit: `flutter test test/features/sanctuary/`

- [ ] 20. Habitat Restoration — Per-Cell Visual Tint

  **What to do**:
  - Implement restoration mechanic (TDD):
    - Once a cell reaches **Observed**, it becomes eligible for restoration
    - Restoration level: 0.0 → 1.0 (float)
    - Trigger: collecting species in a cell increases restoration level
      - Each species collected in cell: +0.33 restoration (3 species = fully restored)
    - Visual effect: observed cells gain a green tint overlay whose intensity = restoration level
    - Fog overlay blending: cells go from "clear" (observed, no restoration) to "lush" (observed + restored)
  - Integrate with:
    - `fogProvider` — restoration level per cell
    - Map screen fog shader/overlay — green tint layer
    - `CellProgressRepository` — persist restoration level
  - This is the visual payoff for exploration — the map "heals" as you discover

  **Must NOT do**:
  - No animation or before/after comparison
  - No ecosystem simulation
  - No player action beyond collecting species (automatic restoration)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Visual overlay system + game mechanic integration
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `visual-engineering`: The visual is a simple tint overlay, not complex design work

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 17, 18, 19, 21)
  - **Blocks**: None
  - **Blocked By**: Tasks 13, 14 (fog state machine, map screen)

  **References**:

  **Pattern References**:
  - Task 14 fog overlay implementation — restoration is an additional layer using the same rendering approach

  **WHY Each Reference Matters**:
  - Restoration tint uses the same overlay mechanism as fog — extend, don't duplicate

  **Acceptance Criteria**:

  **TDD**:
  - [ ] Test: collecting species in observed cell increases restoration level
  - [ ] Test: restoration capped at 1.0
  - [ ] Test: restoration persists across restart
  - [ ] `flutter test test/features/restoration/` → all pass

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Collecting species in a cell adds green tint
    Tool: Playwright
    Preconditions: Cell at Observed state, species collectible
    Steps:
      1. Screenshot cell at Observed state (clear, no green)
      2. Collect a species in that cell
      3. Screenshot — verify subtle green tint visible
      4. Collect remaining species in cell
      5. Screenshot — verify stronger green tint (fully restored)
    Expected Result: Progressive green tint matching restoration level
    Failure Indicators: No visual change, tint too strong/weak, wrong color
    Evidence: .sisyphus/evidence/task-20-restoration-before.png, .sisyphus/evidence/task-20-restoration-after.png
  ```

  **Commit**: YES
  - Message: `✨ feat(gameplay): habitat restoration visuals`
  - Files: `lib/features/restoration/*.dart`, `test/features/restoration/*.dart`
  - Pre-commit: `flutter test test/features/restoration/`

- [ ] 21. Seasonal System — Summer/Winter Species Swap

  **What to do**:
  - Implement `SeasonService` (TDD):
    - Determine current season based on real date:
      - Northern hemisphere: Jun-Aug = summer, Dec-Feb = winter (simplification for MVP)
      - All other months = summer (default)
    - Filter species availability by season:
      - 24/30 species available year-round
      - 6 species (20%) are season-specific (3 summer-only, 3 winter-only)
    - Update `seasonProvider` when season changes
    - Re-evaluate discoverable species when season transitions
  - Integrate with:
    - `SpeciesService` (Task 15) — filter by season when computing cell species
    - Journal (Task 18) — show seasonal badge on season-specific species
    - Discovery (Task 17) — skip out-of-season species
  - Add UI hint: somewhere on map or journal, show "Summer" or "Winter" with season icon

  **Must NOT do**:
  - No full 4-season rotation (summer/winter only)
  - No seasonal events or timed content
  - No seasonal visual changes on map (e.g., snow)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Date logic + species filtering + cross-system integration
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `deep`: Logic is straightforward, just needs careful integration

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 17, 18, 19, 20)
  - **Blocks**: None
  - **Blocked By**: Task 15 (species service)

  **References**:

  **External References**:
  - Dart DateTime API: https://api.dart.dev/stable/dart-core/DateTime-class.html

  **WHY Each Reference Matters**:
  - Season determination depends on month — straightforward DateTime.now().month logic

  **Acceptance Criteria**:

  **TDD**:
  - [ ] Test: June date → summer season
  - [ ] Test: January date → winter season
  - [ ] Test: summer-only species filtered out in winter
  - [ ] Test: year-round species available in both seasons
  - [ ] `flutter test test/features/seasonal/` → all pass

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Season-specific species correctly filtered
    Tool: Bash
    Preconditions: SeasonService implemented
    Steps:
      1. Mock date as July (summer)
      2. Get species for a cell — verify summer-only species included, winter-only excluded
      3. Mock date as January (winter)
      4. Get species for same cell — verify winter-only included, summer-only excluded
      5. Verify year-round species present in both
    Expected Result: Seasonal filtering works correctly
    Failure Indicators: Wrong species in wrong season, all species always available
    Evidence: .sisyphus/evidence/task-21-seasonal-filter.txt
  ```

  **Commit**: YES
  - Message: `✨ feat(gameplay): seasonal species swap system`
  - Files: `lib/features/seasonal/*.dart`, `test/features/seasonal/*.dart`
  - Pre-commit: `flutter test test/features/seasonal/`

- [ ] 22. Caretaking — Daily Visit Streak Counter

  **What to do**:
  - Implement streak system (TDD):
    - "Visit" = open the sanctuary screen (simple, low-friction daily action)
    - Track: last visit date, current streak, longest streak
    - If player visits sanctuary today AND yesterday: streak increments
    - If player misses a day: streak resets to 0 (but longest streak preserved)
    - Persist to local SQLite + sync to Supabase profile
  - Display on sanctuary screen: "Day N 🔥" (or clean icon equivalent)
  - Display on map screen status bar: small streak indicator
  - Optional: gentle notification hint if player hasn't visited today (NOT push notification — in-app only)

  **Must NOT do**:
  - No virtual pet mechanics (feeding, watering)
  - No decay of collected species from missing days
  - No push notifications

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple date comparison + counter logic + UI display
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `visual-engineering`: Streak display is a small widget, not complex UI

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 5 (with Tasks 23, 24, 25)
  - **Blocks**: None
  - **Blocked By**: Tasks 16, 19 (auth for persistence, sanctuary screen for trigger)

  **References**:

  **External References**:
  - Duolingo streak mechanic (UX inspiration for streak gamification)

  **WHY Each Reference Matters**:
  - Duolingo's streak is the gold standard for daily engagement through simple counters

  **Acceptance Criteria**:

  **TDD**:
  - [ ] Test: first visit starts streak at 1
  - [ ] Test: visit on consecutive day increments streak
  - [ ] Test: missed day resets streak to 0
  - [ ] Test: longest streak preserved even when current resets
  - [ ] `flutter test test/features/caretaking/` → all pass

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Streak increments on consecutive days
    Tool: Bash
    Preconditions: Streak system implemented
    Steps:
      1. Simulate sanctuary visit on Day 1 — streak = 1
      2. Simulate sanctuary visit on Day 2 — streak = 2
      3. Simulate NO visit on Day 3
      4. Simulate sanctuary visit on Day 4 — streak = 1 (reset), longest = 2
    Expected Result: Streak logic correct for consecutive and missed days
    Failure Indicators: Streak doesn't increment, doesn't reset, longest not preserved
    Evidence: .sisyphus/evidence/task-22-streak-logic.txt
  ```

  **Commit**: YES
  - Message: `✨ feat(gameplay): daily visit streak counter`
  - Files: `lib/features/caretaking/*.dart`, `test/features/caretaking/*.dart`
  - Pre-commit: `flutter test test/features/caretaking/`

- [ ] 23. Backend Sync — Manual Cloud Save

  **What to do**:
  - Implement manual sync between SQLite (source of truth) and Supabase:
    - "Sync Now" button in settings or profile screen
    - Upload flow: read from `sync_queue` → batch upsert to Supabase tables → clear queue
    - Download flow: fetch user's data from Supabase → merge into SQLite (server wins on conflict)
    - Sync status indicator: "Last synced: [timestamp]" or "Not synced"
    - Handle network errors gracefully: retry once, then show error with "try again" option
  - Sync covers:
    - `cell_progress` — fog states, distance walked, restoration levels
    - `collected_species` — which species collected when
    - `profiles` — streak, total distance, stats
  - Auto-sync on login (pull server data to local)
  - Auto-sync on app background (push local changes if network available)

  **Must NOT do**:
  - No real-time sync (no WebSocket subscriptions)
  - No conflict resolution beyond "server wins on download, client wins on upload"
  - No offline queue retry daemon

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Data sync between SQLite and Supabase with queue processing and error handling
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `deep`: Sync logic is well-defined, not algorithmically complex

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 5 (with Tasks 22, 24, 25)
  - **Blocks**: None
  - **Blocked By**: Tasks 6, 16 (persistence layer, auth)

  **References**:

  **External References**:
  - Supabase Dart client upsert: https://supabase.com/docs/reference/dart/upsert
  - Drift queries: https://drift.simonbinder.eu/docs/getting-started/queries/

  **WHY Each Reference Matters**:
  - Supabase upsert is the correct operation for sync (insert or update based on primary key)
  - Drift queries needed for reading sync queue and merging downloaded data

  **Acceptance Criteria**:

  **TDD**:
  - [ ] Test: sync queue records changes correctly
  - [ ] Test: upload flushes queue to Supabase (mock client)
  - [ ] Test: download merges server data into local
  - [ ] Test: network error shows appropriate message (not crash)
  - [ ] `flutter test test/features/sync/` → all pass

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Manual sync uploads local progress to Supabase
    Tool: Bash (curl) + Playwright
    Preconditions: User logged in, has explored cells and collected species locally
    Steps:
      1. Tap "Sync Now" button
      2. Wait for sync to complete
      3. curl GET /rest/v1/cell_progress?user_id=eq.{userId} — verify data matches local
      4. curl GET /rest/v1/collected_species?user_id=eq.{userId} — verify species match
    Expected Result: Server data matches local data after sync
    Failure Indicators: Missing data on server, sync hangs, error without retry option
    Evidence: .sisyphus/evidence/task-23-sync-upload.txt

  Scenario: Sync handles network failure gracefully
    Tool: Bash
    Preconditions: Device has no internet (airplane mode or mock)
    Steps:
      1. Attempt "Sync Now"
      2. Verify error message displayed (not crash)
      3. Verify "Try Again" option available
      4. Verify local data unchanged (no corruption)
    Expected Result: Graceful failure, no data loss
    Failure Indicators: App crash, data corruption, no error message
    Evidence: .sisyphus/evidence/task-23-sync-offline-error.txt
  ```

  **Commit**: YES
  - Message: `🔌 feat(api): manual cloud save via Supabase`
  - Files: `lib/features/sync/*.dart`, `test/features/sync/*.dart`
  - Pre-commit: `flutter test test/features/sync/`

- [ ] 24. Offline Mode Verification + Resilience

  **What to do**:
  - Build an integration test suite that verifies the entire app works offline:
    - Exploration: fog clears, cells transition states — no network needed
    - Species discovery: procedural seeding works locally — no API call needed
    - Journal: all data from SQLite — no server required
    - Sanctuary: renders from local data
    - Persistence: all progress saved locally
  - Test edge cases:
    - App starts in airplane mode from cold launch
    - Network drops during gameplay
    - Network restored after being offline
    - GPS available but no internet
  - Verify no uncaught network errors crash the app
  - Ensure all Supabase calls have try/catch with appropriate fallback

  **Must NOT do**:
  - No offline map tiles (MapLibre handles tile caching internally for recently viewed areas)
  - No offline biome data (should be bundled with app already)

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Integration testing across all systems, edge case coverage, resilience verification
  - **Skills**: [`playwright`]
    - `playwright`: End-to-end testing of app in offline mode
  - **Skills Evaluated but Omitted**:
    - `visual-engineering`: Not about visuals — about system resilience

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 5 (with Tasks 22, 23, 25)
  - **Blocks**: None
  - **Blocked By**: Tasks 6, 13, 17 (persistence, fog, discovery must all work)

  **References**:

  **Pattern References**:
  - All core services (CellService, SpeciesService, BiomeService) should already be local-only — this task verifies that assumption

  **WHY Each Reference Matters**:
  - This is a verification task — references are all the services it tests, confirming they don't secretly depend on network

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Full gameplay works in airplane mode
    Tool: Playwright + tmux
    Preconditions: App installed, device/emulator in airplane mode
    Steps:
      1. Enable airplane mode
      2. Cold launch app (guest mode)
      3. Verify map loads (cached tiles or placeholder)
      4. Wait for simulation to move player — verify fog clears
      5. Wait for cell to reach Observed — verify species discovery works
      6. Navigate to journal — verify collected species shown
      7. Navigate to sanctuary — verify gallery renders
    Expected Result: Complete game loop works offline
    Failure Indicators: Crash on launch, fog frozen, discovery fails, blank screens
    Evidence: .sisyphus/evidence/task-24-offline-gameplay.txt

  Scenario: Network drop during gameplay doesn't crash
    Tool: Playwright + tmux
    Preconditions: App running with network, then toggle airplane mode
    Steps:
      1. Start app with network (logged in)
      2. Play for 30 seconds
      3. Toggle airplane mode ON
      4. Continue playing for 30 seconds
      5. Verify no crash, no error dialogs, gameplay continues
      6. Toggle airplane mode OFF
      7. Verify app recovers (sync available again)
    Expected Result: Seamless transition between online and offline
    Failure Indicators: Crash, error spam, frozen UI
    Evidence: .sisyphus/evidence/task-24-network-drop.txt
  ```

  **Commit**: YES
  - Message: `✅ test: offline mode verification suite`
  - Files: `test/integration/offline_*.dart`
  - Pre-commit: `flutter test test/integration/`

- [ ] 25. Achievement / Milestone System

  **What to do**:
  - Implement achievement system (TDD):
    - Define 10-15 achievements for MVP:
      - "First Steps" — observe your first cell
      - "Explorer" — observe 10 cells
      - "Cartographer" — observe 50 cells
      - "Naturalist" — collect 5 species
      - "Biologist" — collect 15 species
      - "Completionist" — collect all 30 species
      - "Forest Friend" — collect all forest species
      - (repeat for each biome)
      - "Dedicated" — 7-day visit streak
      - "Devoted" — 30-day visit streak
      - "Marathon" — walk 10km total
      - "Restorer" — fully restore 5 cells
    - Achievement checking: run after each state change (fog transition, species collected, streak update)
    - Notification: toast/snackbar when achievement unlocked
    - Achievement screen: list all achievements, unlocked with date, locked with progress bar
  - Persist to SQLite, sync with Supabase via Task 23's sync mechanism

  **Must NOT do**:
  - No social sharing of achievements
  - No leaderboards
  - No rewards beyond the achievement itself (no XP, no unlocks)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Achievement system with multiple triggers, progress tracking, UI
  - **Skills**: [`frontend-ui-ux`]
    - `frontend-ui-ux`: Achievement screen and unlock notifications should feel rewarding
  - **Skills Evaluated but Omitted**:
    - `deep`: Achievement logic is condition checking, not algorithmically complex

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 5 (with Tasks 22, 23, 24)
  - **Blocks**: None
  - **Blocked By**: Tasks 13, 17 (fog + discovery — achievement triggers)

  **References**:

  **External References**:
  - Pokemon Go achievement/medal system (UX inspiration for milestone badges)

  **WHY Each Reference Matters**:
  - Pokemon Go's medal system shows how to make exploration achievements feel rewarding with simple design

  **Acceptance Criteria**:

  **TDD**:
  - [ ] Test: "First Steps" unlocks on first cell observed
  - [ ] Test: "Naturalist" unlocks at exactly 5 species collected
  - [ ] Test: "Dedicated" unlocks at exactly 7-day streak
  - [ ] Test: achievement doesn't re-trigger once unlocked
  - [ ] Test: progress tracking correct (e.g., 3/10 cells for "Explorer")
  - [ ] `flutter test test/features/achievements/` → all pass

  **QA Scenarios (MANDATORY)**:

  ```
  Scenario: Achievement unlocks with notification
    Tool: Playwright
    Preconditions: Fresh game state, simulation mode
    Steps:
      1. Start playing (simulation mode)
      2. Wait for first cell to reach Observed
      3. Verify "First Steps" achievement notification appears
      4. Navigate to achievements screen
      5. Verify "First Steps" shown as unlocked with date
      6. Verify "Explorer" shows progress (1/10)
    Expected Result: Achievement unlocks correctly, notification shown, progress tracked
    Failure Indicators: No notification, achievement not marked, wrong progress count
    Evidence: .sisyphus/evidence/task-25-achievement-unlock.png
  ```

  **Commit**: YES
  - Message: `✨ feat(gameplay): achievement and milestone system`
  - Files: `lib/features/achievements/*.dart`, `test/features/achievements/*.dart`
  - Pre-commit: `flutter test test/features/achievements/`

---

## Final Verification Wave (MANDATORY — after ALL implementation tasks)

> 4 review agents run in PARALLEL. ALL must APPROVE. Rejection → fix → re-run.

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists (read file, run flutter test, curl Supabase endpoint). For each "Must NOT Have": search codebase for forbidden patterns (camera integration, multiplayer, real-time sync, monolithic bootstrap). Check evidence files exist in `.sisyphus/evidence/`. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run `flutter analyze` + `flutter test`. Review all Dart files for: dynamic types without justification, empty catches, print() in production code, commented-out code, unused imports. Check for AI slop: excessive comments, over-abstraction, generic variable names (data/result/item/temp). Verify Riverpod providers are properly scoped. Verify no monolithic files >300 lines.
  Output: `Analyze [PASS/FAIL] | Tests [N pass/N fail] | Files [N clean/N issues] | VERDICT`

- [ ] F3. **Real Device QA** — `unspecified-high` (+ `playwright` skill)
  Start from clean state. Launch app on emulator/device. Execute EVERY QA scenario from EVERY task — follow exact steps, capture evidence. Test cross-system integration (explore → discover species → check journal → visit sanctuary). Test edge cases: airplane mode, GPS disabled, rapid app switching. Save to `.sisyphus/evidence/final-qa/`.
  Output: `Scenarios [N/N pass] | Integration [N/N] | Edge Cases [N tested] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", read actual code. Verify 1:1 — everything in spec was built (no missing), nothing beyond spec was built (no creep). Check scope ceilings: count species (must be ≤30), check for camera/social/multiplayer code (must be absent). Check "Must NOT do" compliance. Flag any unaccounted files.
  Output: `Tasks [N/N compliant] | Scope Ceilings [N/N respected] | Unaccounted [CLEAN/N files] | VERDICT`

---

## Commit Strategy

| Task(s) | Commit Message | Pre-commit Check |
|---------|---------------|------------------|
| 1 | `✨ feat: scaffold Flutter project, replace Unity codebase` | `flutter analyze` |
| 2 | `📝 docs: add AGENTS.md with architecture decisions` | — |
| 3 | `✨ feat(core): add data models and type definitions` | `flutter test test/core/models/` |
| 4 | `🔧 chore(backend): configure Supabase project and schema` | curl health check |
| 5 | `✨ feat(core): add Riverpod state management scaffolding` | `flutter test test/core/state/` |
| 6 | `✨ feat(core): add local persistence layer with Drift` | `flutter test test/core/persistence/` |
| 7 | `📝 docs: MapLibre package comparison spike results` | — |
| 8 | `📝 docs: H3 vs Voronoi cell system spike results` | — |
| 9 | `✨ feat(map): fog shader proof-of-concept with MapLibre` | `flutter test test/features/map/` |
| 10 | `✨ feat(core): GPS integration with simulation mode` | `flutter test test/core/location/` |
| 11 | `✨ feat(core): biome classification with ESA WorldCover` | `flutter test test/core/biome/` |
| 12 | `✨ feat(core): cell system implementation` | `flutter test test/core/cells/` |
| 13 | `✨ feat(core): fog state machine with 5-level transitions` | `flutter test test/core/fog/` |
| 14 | `🎨 feat(ui): map screen with fog overlay and player marker` | `flutter test test/features/map/` |
| 15 | `✨ feat(core): procedural species seeding algorithm` | `flutter test test/core/species/` |
| 16 | `🔐 feat(auth): Supabase authentication and user profile` | `flutter test test/features/auth/` |
| 17 | `✨ feat(gameplay): species discovery mechanic` | `flutter test test/features/discovery/` |
| 18 | `🎨 feat(ui): collection journal screen` | `flutter test test/features/journal/` |
| 19 | `🎨 feat(ui): sanctuary gallery screen` | `flutter test test/features/sanctuary/` |
| 20 | `✨ feat(gameplay): habitat restoration visuals` | `flutter test test/features/restoration/` |
| 21 | `✨ feat(gameplay): seasonal species swap system` | `flutter test test/features/seasonal/` |
| 22 | `✨ feat(gameplay): daily visit streak counter` | `flutter test test/features/caretaking/` |
| 23 | `🔌 feat(api): manual cloud save via Supabase` | `flutter test test/features/sync/` |
| 24 | `✅ test: offline mode verification suite` | `flutter test test/integration/` |
| 25 | `✨ feat(gameplay): achievement and milestone system` | `flutter test test/features/achievements/` |

---

## Success Criteria

### Verification Commands
```bash
flutter analyze                    # Expected: No issues found
flutter test                       # Expected: All tests pass (100+ tests)
flutter build apk --release        # Expected: Build succeeds
flutter build ios --release         # Expected: Build succeeds (macOS only)
curl -s https://<project>.supabase.co/rest/v1/species -H "apikey: <key>" | jq length  # Expected: 30
```

### Final Checklist
- [ ] All "Must Have" items present and verified
- [ ] All "Must NOT Have" items absent (no camera, multiplayer, real-time sync)
- [ ] All scope ceilings respected (≤30 species, ≤5 biomes, etc.)
- [ ] All tests pass (`flutter test`)
- [ ] Both platform builds succeed
- [ ] App works fully offline
- [ ] Fog shader renders at 60fps on mid-range device
- [ ] AGENTS.md accurately reflects final architecture
