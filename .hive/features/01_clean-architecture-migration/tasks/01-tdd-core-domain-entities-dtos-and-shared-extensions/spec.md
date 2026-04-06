# Task: 01-tdd-core-domain-entities-dtos-and-shared-extensions

## Feature: clean-architecture-migration

## Dependencies

_None_

## Plan Section

### 1. TDD: Core domain entities, DTOs, and shared extensions

**Depends on**: none

**Files:**
- Test: `test/core/domain/entities/user_profile_test.dart`
- Create: `lib/core/domain/entities/user_profile.dart`
- Test: `test/core/domain/entities/auth_state_test.dart`
- Create: `lib/core/domain/entities/auth_state.dart`
- Test: `test/core/domain/entities/iucn_status_test.dart`
- Create: `lib/core/domain/entities/iucn_status.dart`
- Test: `test/core/domain/entities/taxonomic_group_test.dart`
- Create: `lib/core/domain/entities/taxonomic_group.dart`
- Test: `test/core/domain/entities/habitat_test.dart`
- Create: `lib/core/domain/entities/habitat.dart`
- Test: `test/core/domain/entities/game_region_test.dart`
- Create: `lib/core/domain/entities/game_region.dart`
- Test: `test/core/domain/entities/item_test.dart`
- Create: `lib/core/domain/entities/item.dart`
- Test: `test/features/auth/data/dtos/user_profile_dto_test.dart`
- Create: `lib/features/auth/data/dtos/user_profile_dto.dart`
- Test: `test/features/identification/data/dtos/item_dto_test.dart`
- Create: `lib/features/identification/data/dtos/item_dto.dart`
- Test: `test/shared/extensions/iucn_status_theme_test.dart`
- Create: `lib/shared/extensions/iucn_status_theme.dart`
- Test: `test/shared/extensions/iconography_test.dart`
- Create: `lib/shared/extensions/iconography.dart`

**What to do:**

- Step 1: Create all target directories under both `lib/` and `test/`:
  ```bash
  mkdir -p lib/core/domain/entities lib/core/observability lib/core/supabase
  mkdir -p lib/features/auth/{domain/{repositories,use_cases},data/{repositories,dtos},presentation/{providers,screens}}
  mkdir -p lib/features/identification/{domain/{entities,repositories,use_cases},data/{repositories,dtos},presentation/{providers,screens,widgets}}
  mkdir -p lib/features/profile/presentation/screens
  mkdir -p lib/shared/{extensions,theme,widgets}
  mkdir -p test/core/domain/entities test/core/observability
  mkdir -p test/features/auth/{domain/use_cases,data/{repositories,dtos},presentation/{providers,screens}}
  mkdir -p test/features/identification/{domain/{entities,use_cases},data/{repositories,dtos},presentation/{providers,screens,widgets}}
  mkdir -p test/shared/{extensions,theme,widgets,helpers}
  ```

- Step 2: **RED** — Write `test/core/domain/entities/user_profile_test.dart`:
  ```dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:earth_nova/core/domain/entities/user_profile.dart';

  void main() {
    group('UserProfile', () {
      test('constructs with required fields', () {
        final profile = UserProfile(id: '1', phone: '5551234567', createdAt: DateTime(2026));
        expect(profile.id, '1');
        expect(profile.phone, '5551234567');
        expect(profile.displayName, isNull);
        expect(profile.createdAt, DateTime(2026));
      });

      test('copyWith returns new instance with overridden fields', () {
        final original = UserProfile(id: '1', phone: '555', createdAt: DateTime(2026));
        final copied = original.copyWith(displayName: 'Explorer');
        expect(copied.displayName, 'Explorer');
        expect(copied.id, '1'); // unchanged
      });

      test('value equality', () {
        final a = UserProfile(id: '1', phone: '555', createdAt: DateTime(2026));
        final b = UserProfile(id: '1', phone: '555', createdAt: DateTime(2026));
        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });

      test('has no fromJson or toJson method', () {
        // UserProfile is a pure domain entity — serialization lives in UserProfileDto.
        // This test documents the design intent.
        expect(UserProfile(id: '1', phone: '555', createdAt: DateTime(2026)), isA<UserProfile>());
      });
    });
  }
  ```
  - Run: `flutter test test/core/domain/entities/user_profile_test.dart`
  - Expected: **FAIL** — `Target of URI doesn't exist: 'package:earth_nova/core/domain/entities/user_profile.dart'`

- Step 3: **GREEN** — Create `lib/core/domain/entities/user_profile.dart`: pure Dart class with `id`, `phone`, `displayName`, `createdAt`, `copyWith`, `==`, `hashCode`. No `fromJson`/`toJson`. No Flutter imports.
  - Run: `flutter test test/core/domain/entities/user_profile_test.dart`
  - Expected: **PASS**

- Step 4: **RED** — Write `test/core/domain/entities/auth_state_test.dart`: test all 4 constructors (`loading`, `unauthenticated`, `authenticated`, `error`), test `when<T>` exhaustive matching, test value equality.
  - Run: `flutter test test/core/domain/entities/auth_state_test.dart` → FAIL

- Step 5: **GREEN** — Create `lib/core/domain/entities/auth_state.dart`: `AuthState`, `AuthStatus`. Imports `UserProfile` from `core/domain/entities/user_profile.dart`. Same logic as current `models/auth_state.dart` minus `UserProfile` class.
  - Run: → PASS

- Step 6: **RED** — Write `test/core/domain/entities/iucn_status_test.dart`: test `fromString` for all codes (`'LC'`, `'leastConcern'`, `'EN'`), null returns null, unknown returns null. Test that the enum has no `color` property (documents the split).
  - Run: → FAIL

- Step 7: **GREEN** — Create `lib/core/domain/entities/iucn_status.dart`: enum with `code`, `displayName`, `fromString()`. No Color. No Flutter.
  - Run: → PASS

- Step 8: **RED** — Write `test/core/domain/entities/taxonomic_group_test.dart`: test `fromTaxonomicClass` for key mappings: `'MAMMALIA'` → mammals, `'AVES'` → birds, `'ACTINOPTERYGII'` → fish, `'INSECTA'` → invertebrates, `null` → other, `''` → other, unknown → other.
  - Run: → FAIL

- Step 9: **GREEN** — Create `lib/core/domain/entities/taxonomic_group.dart`: pure enum with `label` (no `icon`), full `fromTaxonomicClass` switch logic from current `iconography.dart:102-136`.
  - Run: → PASS

- Step 10: **RED/GREEN** — Same pattern for `habitat.dart` (test `fromString`) and `game_region.dart` (test `fromString` including `'North America'` → `northAmerica`).

- Step 11: **RED** — Write `test/core/domain/entities/item_test.dart`: test `Item` construction, `copyWith`, value equality, `taxonomicGroup` getter (returns correct `TaxonomicGroup` for given `taxonomicClass`). Test that `ItemCategory` has `label` but no `emoji`/`icon` field. Test `ItemStatus.fromString`.
  - Run: → FAIL

- Step 12: **GREEN** — Create `lib/core/domain/entities/item.dart`: `Item`, `ItemCategory`, `ItemStatus`. `ItemCategory` has `label` only (no emoji). `Item` has no `fromJson`/`toJson`. `taxonomicGroup` getter imports from `core/domain/entities/taxonomic_group.dart`.
  - Run: → PASS

- Step 13: **RED** — Write `test/features/auth/data/dtos/user_profile_dto_test.dart`: test `fromJson` → `toDomain()` round-trip, test `fromDomain` → `toJson()` round-trip, test null `display_name` handling.
  - Run: → FAIL

- Step 14: **GREEN** — Create `lib/features/auth/data/dtos/user_profile_dto.dart`: `UserProfileDto` with `fromJson`, `toJson`, `toDomain()`, `fromDomain()`.
  - Run: → PASS

- Step 15: **RED** — Write `test/features/identification/data/dtos/item_dto_test.dart`: test `fromJson` → `toDomain()` round-trip (all fields), test null optional fields, test `_parseJsonArray` edge cases (`null`, `'[]'`, `'["Forest","Mountain"]'`, malformed JSON), test `fromDomain` → `toJson`.
  - Run: → FAIL

- Step 16: **GREEN** — Create `lib/features/identification/data/dtos/item_dto.dart`: `ItemDto` with `fromJson`, `toJson`, `toDomain()`, `fromDomain()`. Absorbs `_parseJsonArray` as private helper.
  - Run: → PASS

- Step 17: **RED** — Write `test/shared/extensions/iucn_status_theme_test.dart`: test that each `IucnStatus` value has a non-null `color`, `fgColor`, `borderAlpha`, `glowAlpha` via the extension. Test specific values: `IucnStatus.criticallyEndangered.color` == `Color(0xFF9C27B0)`.
  - Run: → FAIL

- Step 18: **GREEN** — Create `lib/shared/extensions/iucn_status_theme.dart`: extension on `IucnStatus` adding `color`, `fgColor`, `borderAlpha`, `glowAlpha` with exact values from current `models/iucn_status.dart`.
  - Run: → PASS

- Step 19: **RED** — Write `test/shared/extensions/iconography_test.dart`: test that each domain enum has an `icon` extension getter returning a non-empty string. Test specific: `TaxonomicGroup.mammals.icon == '🦁'`. Test `ItemCategory.fauna.emoji == '🦊'` (extension adds `emoji` getter). Test `PackSortMode` enum exists in iconography with icon+label.
  - Run: → FAIL

- Step 20: **GREEN** — Create `lib/shared/extensions/iconography.dart`: keep `AppIcons` class. Add extension methods on `TaxonomicGroup`, `Habitat`, `GameRegion`, `ItemCategory` providing `icon`/`emoji` getters. Move `PackSortMode` enum here (it's a UI concern).
  - Run: → PASS

- Step 21: Verify all new tests pass, all old tests still pass:
  - Run: `flutter test` → ALL PASS
  - Run: `flutter analyze` → 0 issues (old files still exist, no conflicts)

**Must NOT do:**
- Write implementation before the test for that file
- Modify any existing files
- Import Flutter in any `core/domain/` file
- Put fromJson/toJson on domain entities
- Put emoji/Color on domain enums

**References:**
- `lib/models/auth_state.dart` — Source for AuthState/UserProfile extraction
- `lib/models/item.dart` — Source for Item/ItemCategory/ItemStatus extraction
- `lib/models/iucn_status.dart` — Source for IucnStatus splitting
- `lib/shared/iconography.dart` — Source for enum splitting + AppIcons

**Verify:**
- [ ] Run: `flutter test test/core/` → all pass
- [ ] Run: `flutter test test/features/auth/data/dtos/` → all pass
- [ ] Run: `flutter test test/features/identification/data/dtos/` → all pass
- [ ] Run: `flutter test test/shared/extensions/` → all pass
- [ ] Run: `flutter test` → ALL tests pass (old + new)
- [ ] Run: `flutter analyze` → 0 issues
- [ ] No `import 'package:flutter` in any `core/domain/` file
- [ ] Every new `.dart` file in `lib/` has a corresponding test file

---

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

