# Task: 04-update-agentsmd-and-solution-diagrams

## Feature: clean-architecture-migration

## Dependencies

- **3. tdd-identification-feature--full-switchover** (03-tdd-identification-feature--full-switchover)

## Plan Section

### 4. Update AGENTS.md and solution diagrams

**Depends on**: 3

**Files:**
- Modify: `AGENTS.md`
- Modify: `docs/diagrams/solution/3-3-client-layers.mmd`
- Modify: `docs/diagrams/solution/3-4-provider-graph.mmd`

**What to do:**

- Step 1: Update `AGENTS.md`:
  - Add "Clean Architecture" to Key Decisions table: "Clean Architecture with feature modules — strict layering (domain ← data ← presentation), one use case per operation, domain entities pure Dart" / "Long-term extensibility for 10 feature domains (A-I + S), offline readiness, testability"
  - Update Naming Conventions table:
    - Add: Repository `FooRepository` / `SupabaseFooRepository` — data access interface + implementation
    - Add: Use Case `VerbNoun` e.g. `SignInWithPhone`, `FetchItems` — one operation, one class
    - Add: DTO `FooDto` — JSON serialization in data layer
    - Update: Service → "Reserved for domain services with cross-entity logic (not data access)"
  - Update Forbidden Patterns:
    - Add: "`import 'package:flutter'` in `core/domain/` or `features/*/domain/`" — domain is pure Dart
    - Add: "Notifiers calling repositories directly" — use cases are the API
    - Add: "`fromJson`/`toJson` on domain entities" — use DTOs in data layer
    - Add: "`AuthService` / `ItemService`" — renamed to `AuthRepository` / `ItemRepository`
    - Add: "Emoji or Color on domain enums" — use shared/extensions

- Step 2: Update `docs/diagrams/solution/3-3-client-layers.mmd`:
  - Rename ServiceLayer to DataLayer
  - Add UseCaseLayer between StateLayer and DataLayer
  - Add DomainLayer as innermost layer containing entities + repository interfaces

- Step 3: Update `docs/diagrams/solution/3-4-provider-graph.mmd`:
  - `authServiceProvider` → `authRepositoryProvider`
  - `itemServiceProvider` → `itemRepositoryProvider`
  - Add use case provider nodes: `signInWithPhoneProvider`, `fetchItemsProvider`, etc.

- Step 4: Verify docs consistency
  - Read AGENTS.md, confirm no contradictions
  - Run: `flutter analyze` → still 0 issues

**Must NOT do:**
- Remove any existing Key Decisions
- Change Supabase/auth/no-codegen decisions

**Verify:**
- [ ] AGENTS.md Key Decisions includes "Clean Architecture"
- [ ] Naming Conventions includes Repository, Use Case, DTO
- [ ] Forbidden Patterns includes domain purity rules
- [ ] `flutter analyze` → 0 issues

## Task Type

modification

## Context

## migration-decisions

# Clean Architecture Migration — Decisions

## User Decisions (confirmed via question())
1. **Architecture**: Clean Architecture / Hexagonal — strict layering with dependency inversion
2. **Use case granularity**: One class per operation (verbose is correct)
3. **Shared entities**: Core domain entities in `core/domain/entities/`, used across features
4. **Per-feature DTOs**: Shared domain entities in core, per-feature DTOs in data layers (option A+C)
5. **Naming**: Service → Repository (standard Clean Architecture)
6. **IucnStatus**: Split — pure enum in domain, Color mapping via extension in shared
7. **Item serialization**: Extract ItemDto — Item becomes pure domain entity
8. **Game enums**: Split — pure enums in core/domain, emoji mapping via extensions in shared

## Codebase Inventory (25 source files, 17 test files)

### Models (4 files)
- `models/auth_state.dart` — AuthState, AuthStatus, UserProfile (116 lines)
- `models/item.dart` — Item, ItemCategory, ItemStatus, TaxonomicGroup refs (224 lines)
- `models/iucn_status.dart` — IucnStatus enum with Flutter Color (103 lines)
- `models/pack_filter_state.dart` — PackFilterState with filter logic (150 lines)

### Services (6 files)
- `services/auth_service.dart` — Abstract AuthService + AuthEvent sealed class (48 lines)
- `services/supabase_auth_service.dart` — SupabaseAuthService impl (163 lines)
- `services/mock_auth_service.dart` — MockAuthService impl (53 lines)
- `services/item_service.dart` — Abstract ItemService + SupabaseItemService + MockItemService (44 lines)
- `services/observability_service.dart` — ObservabilityService + hashPhone (85 lines)
- `services/supabase_bootstrap.dart` — SupabaseBootstrap.initialize (14 lines)

### Providers (3 files)
- `providers/auth_provider.dart` — AuthNotifier, authServiceProvider, observabilityProvider (100 lines)
- `providers/items_provider.dart` — ItemsNotifier, ItemsState, itemServiceProvider (96 lines)
- `providers/observable_notifier.dart` — ObservableNotifier base class (36 lines)

### Screens (5 files)
- `screens/login_screen.dart`
- `screens/loading_screen.dart`
- `screens/pack_screen.dart`
- `screens/settings_screen.dart`
- `screens/stub_screen.dart`

### Shared (4 files)
- `shared/app_theme.dart`
- `shared/constants.dart`
- `shared/design_tokens.dart`
- `shared/iconography.dart` — Contains TaxonomicGroup, Habitat, GameRegion, AppIcons enums

### Widgets (3 files)
- `widgets/loading_dots.dart`
- `widgets/species_card.dart`
- `widgets/tab_shell.dart`

### Tests (17 files)
- `test/app_test.dart`
- `test/models/` — auth_state_test, item_test, pack_filter_state_test
- `test/providers/` — auth_provider_test, items_provider_test, observable_notifier_test
- `test/services/` — auth_service_test, item_service_test, mock_auth_service_test, mock_supabase_client, observability_service_test
- `test/screens/` — login_screen_test, pack_screen_test
- `test/widgets/` — loading_dots_test, species_card_test
- `test/shared/` — app_theme_test, iconography_test

## Key Observations
- AuthService is ALREADY an abstract interface — just needs renaming to AuthRepository
- ItemService is ALREADY abstract — same
- Phone→email derivation logic in SupabaseAuthService._deriveEmail/_derivePassword is business logic that should move to use case
- Item.fromJson/toJson needs extraction to ItemDto
- IucnStatus imports flutter/material.dart for Color — needs splitting
- TaxonomicGroup/Habitat/GameRegion defined in iconography.dart with emoji — need splitting
- ItemCategory in item.dart references AppIcons — needs decoupling


## Completed Tasks

- 01-tdd-core-domain-entities-dtos-and-shared-extensions: Created 11 new lib/ files and 11 matching test files via strict TDD (red→green for each). Core domain entities (UserProfile, AuthState, IucnStatus, TaxonomicGroup, Habitat, GameRegion, Item) are pure Dart with no Flutter imports. DTOs (UserProfileDto, ItemDto) handle serialization in the data layer. Shared extensions (IucnStatusTheme, iconography with AppIcons/PackSortMode) add Flutter/emoji concerns without polluting domain. All 276 tests pass, flutter analyze reports 0 issues.
- 02-tdd-auth-feature--repositories-use-cases-presentation: Created auth feature via strict TDD: AuthRepository interface + AuthException/AuthEvent sealed classes in domain; SignInWithPhone (phone→email derivation + sign-in-or-signup fallback), SignOut, RestoreSession, GetCurrentUser use cases each with failing tests first; MockAuthRepository and SupabaseAuthRepository in data layer; AuthNotifier presentation provider with all state = violations fixed to transition(). All 22 auth tests pass, flutter analyze lib/features/auth/ reports 0 issues.
- 03-tdd-identification-feature--full-switchover: Created identification feature domain (ItemRepository, FetchItems use case, PackFilterState entity) and data layer (MockItemRepository, SupabaseItemRepository) via strict TDD. Moved core infrastructure to lib/core/observability/ and lib/core/supabase/. Created all new presentation files (ItemsNotifier, PackScreen, SpeciesCard, TabShell, SettingsScreen, LoadingDots, StubScreen) in feature/shared paths with updated imports. Migrated all 17 old test files to new locations with updated imports. Deleted all old lib/models/, lib/services/, lib/providers/, lib/screens/, lib/widgets/ directories and old test directories. Updated main.dart to wire new repository providers. flutter analyze → 0 issues, flutter test → 207/207 pass.
