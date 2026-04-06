# Task: 03-tdd-identification-feature--full-switchover

## Feature: clean-architecture-migration

## Dependencies

- **2. tdd-auth-feature--repositories-use-cases-presentation** (02-tdd-auth-feature--repositories-use-cases-presentation)

## Plan Section

### 3. TDD: Identification feature + full switchover

**Depends on**: 2

**Files:**
- Test: `test/features/identification/domain/use_cases/fetch_items_test.dart`
- Test: `test/features/identification/domain/entities/pack_filter_state_test.dart`
- Test: `test/features/identification/data/repositories/mock_item_repository_test.dart`
- Create: `lib/features/identification/domain/repositories/item_repository.dart`
- Create: `lib/features/identification/domain/use_cases/fetch_items.dart`
- Create: `lib/features/identification/domain/entities/pack_filter_state.dart`
- Create: `lib/features/identification/data/repositories/supabase_item_repository.dart`
- Create: `lib/features/identification/data/repositories/mock_item_repository.dart`
- Create: `lib/features/identification/presentation/providers/items_provider.dart`
- Create: `lib/features/identification/presentation/screens/pack_screen.dart`
- Create: `lib/features/identification/presentation/widgets/species_card.dart`
- Create: `lib/core/observability/observable_notifier.dart`
- Create: `lib/core/observability/observability_service.dart`
- Create: `lib/core/supabase/supabase_bootstrap.dart`
- Create: `lib/features/profile/presentation/screens/settings_screen.dart`
- Create: `lib/shared/theme/app_theme.dart`
- Create: `lib/shared/theme/design_tokens.dart`
- Create: `lib/shared/constants.dart`
- Create: `lib/shared/widgets/loading_dots.dart`
- Create: `lib/shared/widgets/tab_shell.dart`
- Create: `lib/shared/widgets/stub_screen.dart`
- Modify: `lib/main.dart`
- Delete: ALL old `lib/models/`, `lib/services/`, `lib/providers/`, `lib/screens/`, `lib/widgets/` files and directories
- Migrate: ALL old test files to new locations
- Delete: ALL old `test/models/`, `test/services/`, `test/providers/`, `test/screens/`, `test/widgets/`, `test/shared/` files

**What to do:**

- Step 1: **RED** — Write `test/features/identification/domain/use_cases/fetch_items_test.dart`:
  ```dart
  void main() {
    group('FetchItems', () {
      test('delegates to repository and returns items', () async {
        final repo = FakeItemRepository(items: [_testItem()]);
        final useCase = FetchItems(repo);
        final result = await useCase.call('user-1');
        expect(result, hasLength(1));
        expect(result.first.id, 'item-1');
      });

      test('propagates repository exceptions', () async {
        final repo = FakeItemRepository(shouldThrow: true);
        final useCase = FetchItems(repo);
        expect(() => useCase.call('user-1'), throwsException);
      });
    });
  }
  ```
  - Run: → FAIL

- Step 2: **GREEN** — Create `lib/features/identification/domain/repositories/item_repository.dart` (abstract `ItemRepository`: `fetchItems(userId) → Future<List<Item>>`). Create `lib/features/identification/domain/use_cases/fetch_items.dart`.
  - Run: → PASS

- Step 3: **RED/GREEN** — Write test for `PackFilterState` in new location (import core domain enums), then move `pack_filter_state.dart` with updated imports.

- Step 4: **RED** — Write `test/features/identification/data/repositories/mock_item_repository_test.dart`: test returns configured items, test throws when configured.
  - Run: → FAIL

- Step 5: **GREEN** — Create `mock_item_repository.dart` and `supabase_item_repository.dart` (uses `ItemDto`).
  - Run: → PASS

- Step 6: Create identification presentation (moved/refactored from existing):
  - `items_provider.dart` — `ItemsNotifier` calls `FetchItems` use case. `ItemsState` stays here.
  - Copy `pack_screen.dart`, `species_card.dart` with updated imports.

- Step 7: Move core infrastructure:
  - `providers/observable_notifier.dart` → `core/observability/observable_notifier.dart`
  - `services/observability_service.dart` → `core/observability/observability_service.dart`
  - `services/supabase_bootstrap.dart` → `core/supabase/supabase_bootstrap.dart`

- Step 8: Move remaining files to new locations:
  - `settings_screen.dart` → `features/profile/presentation/screens/`
  - `app_theme.dart` → `shared/theme/`
  - `design_tokens.dart` → `shared/theme/`
  - `constants.dart` → `shared/`
  - `loading_dots.dart` → `shared/widgets/`
  - `tab_shell.dart` → `shared/widgets/`
  - `stub_screen.dart` → `shared/widgets/`

- Step 9: Update `lib/main.dart` — all imports point to new paths. Wire repository providers and use case providers.

- Step 10: Delete ALL old source files:
  ```bash
  rm -rf lib/models lib/providers lib/screens lib/widgets
  rm lib/shared/iconography.dart lib/shared/app_theme.dart lib/shared/design_tokens.dart lib/shared/constants.dart
  rmdir lib/shared 2>/dev/null || true  # may have subdirs now
  ```

- Step 11: Migrate ALL old test files to new locations (update imports):
  - `test/models/*_test.dart` → covered by new tests from Task 1
  - `test/services/*_test.dart` → `test/features/auth/data/repositories/`, `test/core/observability/`
  - `test/providers/*_test.dart` → `test/features/*/presentation/providers/`, `test/core/observability/`
  - `test/screens/*_test.dart` → `test/features/*/presentation/screens/`
  - `test/widgets/*_test.dart` → `test/features/*/presentation/widgets/`, `test/shared/widgets/`
  - `test/shared/*_test.dart` → `test/shared/theme/`, `test/shared/extensions/`
  - `test/services/mock_supabase_client.dart` → `test/shared/helpers/mock_supabase_client.dart`
  - Update `test/app_test.dart` imports

- Step 12: Delete ALL old test files:
  ```bash
  rm -rf test/models test/services test/providers test/screens test/widgets test/shared/app_theme_test.dart test/shared/iconography_test.dart
  ```

- Step 13: Final verification:
  - Run: `flutter analyze` → 0 issues
  - Run: `flutter test` → ALL pass
  - Run: `grep -r "lib/models/" lib/ test/` → no matches
  - Run: `grep -r "lib/services/" lib/ test/` → no matches
  - Run: `grep -r "lib/providers/" lib/ test/` → no matches

**Must NOT do:**
- Write use case code before its test
- Leave any import pointing to old paths after switchover
- Delete old files before new files are complete and compiling
- Change business logic — pure structural migration
- Skip migrating any test file

**References:**
- `lib/services/item_service.dart` — Source for ItemRepository interface
- `lib/providers/items_provider.dart` — Source for ItemsNotifier refactoring
- `lib/main.dart` — Entry point rewiring

**Verify:**
- [ ] Run: `flutter analyze` → 0 issues
- [ ] Run: `flutter test` → ALL pass, 0 failures
- [ ] Run: `grep -r "lib/models/" lib/ test/` → no matches
- [ ] Run: `grep -r "lib/services/" lib/ test/` → no matches
- [ ] Run: `grep -r "lib/providers/" lib/ test/` → no matches
- [ ] Run: `grep -r "lib/screens/" lib/ test/` → no matches (except screen files inside features)
- [ ] Run: `grep -r "import.*package:flutter" lib/core/domain/` → no matches
- [ ] Run: `ls lib/models lib/providers lib/screens lib/widgets 2>&1` → "No such file or directory" for each
- [ ] Every use case has at least one test
- [ ] Every DTO has a round-trip test

---

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
