# Clean Architecture Migration (TDD)

## Discovery

### Original Request
- "i want 3 [Clean Architecture]. i think it's clean"
- "i think verbosity is the right play"
- "core makes sense [for shared entities]"
- "do a full migration now"
- "use tdd for it"

### Interview Summary
- **Architecture**: Clean Architecture / Hexagonal with strict layering
- **Use case granularity**: One class per operation
- **Shared entities**: Pure Dart domain entities in `core/domain/entities/`
- **DTOs**: Per-feature DTOs in `features/*/data/dtos/`
- **Naming**: Service → Repository (standard Clean Architecture)
- **IucnStatus**: Split — pure enum in domain, Color mapping via extension
- **Item serialization**: Extract ItemDto with fromJson/toJson
- **Game enums**: Split — pure enums in domain, emoji via extensions
- **Migration scope**: Full migration now, all files
- **Approach**: TDD — every new file gets a failing test first

### Research Findings
- `lib/services/auth_service.dart:12` — AuthService already abstract, rename to AuthRepository
- `lib/services/item_service.dart:5` — ItemService already abstract, same
- `lib/services/supabase_auth_service.dart:152-162` — Phone→email derivation is business logic, belongs in use case
- `lib/models/item.dart:93-110` — fromJson/toJson must extract to ItemDto
- `lib/models/iucn_status.dart:1` — Imports flutter/material.dart for Color, must split
- `lib/shared/iconography.dart:71-220` — TaxonomicGroup, Habitat, GameRegion defined with emoji, must split
- `lib/models/item.dart:8-9` — ItemCategory references AppIcons, must decouple
- `lib/providers/auth_provider.dart:66-69` — AuthNotifier uses raw `state =` in catch blocks (violates ObservableNotifier contract)
- Codebase: 25 source files, 17 test files — small enough for atomic migration

---

## Non-Goals
- Adding new features — migration only, no new functionality
- Offline support / Drift — future concern, architecture just makes room for it
- Changing any business logic — pure structural refactor
- Adding new dependencies — no new packages

---

## Design Summary

Restructure flat `lib/{models,services,providers,screens,widgets,shared}/` into Clean Architecture with feature modules. **Every new file gets a failing test first.**

```
lib/
├── core/                          # Shared kernel
│   ├── domain/entities/           # Pure Dart entities (no Flutter, no JSON)
│   ├── observability/             # ObservableNotifier + ObservabilityService
│   └── supabase/                  # Bootstrap
├── features/
│   ├── auth/                      # domain/ → data/ → presentation/
│   ├── identification/            # domain/ → data/ → presentation/
│   └── profile/                   # presentation/ only (thin)
└── shared/                        # Theme, extensions, widgets
```

**Dependency rule:** Domain ← Data ← Presentation. Domain has zero Flutter imports. Notifiers call use cases, never repositories directly.

**TDD cycle per file:** Write test → RED (fails because file doesn't exist) → Create file → GREEN → Refactor.

**Migration strategy:** 4 sequential tasks. Tasks 1-3 are TDD: write tests first, then implement. Each task leaves the codebase compiling with all tests green. Task 4 updates documentation.

---

## Tasks

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

### 2. TDD: Auth feature — repositories, use cases, presentation

**Depends on**: 1

**Files:**
- Test: `test/features/auth/domain/use_cases/sign_in_with_phone_test.dart`
- Test: `test/features/auth/domain/use_cases/sign_out_test.dart`
- Test: `test/features/auth/domain/use_cases/restore_session_test.dart`
- Test: `test/features/auth/domain/use_cases/get_current_user_test.dart`
- Create: `lib/features/auth/domain/repositories/auth_repository.dart`
- Create: `lib/features/auth/domain/use_cases/sign_in_with_phone.dart`
- Create: `lib/features/auth/domain/use_cases/sign_out.dart`
- Create: `lib/features/auth/domain/use_cases/restore_session.dart`
- Create: `lib/features/auth/domain/use_cases/get_current_user.dart`
- Test: `test/features/auth/data/repositories/mock_auth_repository_test.dart`
- Create: `lib/features/auth/data/repositories/supabase_auth_repository.dart`
- Create: `lib/features/auth/data/repositories/mock_auth_repository.dart`
- Create: `lib/features/auth/presentation/providers/auth_provider.dart`
- Create: `lib/features/auth/presentation/screens/login_screen.dart`
- Create: `lib/features/auth/presentation/screens/loading_screen.dart`

**What to do:**

- Step 1: **RED** — Write `test/features/auth/domain/use_cases/sign_in_with_phone_test.dart`:
  ```dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:earth_nova/features/auth/domain/repositories/auth_repository.dart';
  import 'package:earth_nova/features/auth/domain/use_cases/sign_in_with_phone.dart';
  import 'package:earth_nova/core/domain/entities/user_profile.dart';

  // Fake repository for testing use case logic
  class FakeAuthRepository implements AuthRepository {
    UserProfile? userToReturn;
    bool signInCalled = false;
    bool signUpCalled = false;
    String? lastEmail;
    String? lastPassword;
    bool shouldThrowOnSignIn = false;

    @override
    Future<UserProfile> signInWithEmail(String email, String password) async {
      signInCalled = true;
      lastEmail = email;
      lastPassword = password;
      if (shouldThrowOnSignIn) throw const AuthException('Invalid login credentials');
      return userToReturn!;
    }

    @override
    Future<UserProfile> signUpWithEmail(String email, String password, {Map<String, dynamic>? metadata}) async {
      signUpCalled = true;
      return userToReturn!;
    }
    // ... other stubs
  }

  void main() {
    group('SignInWithPhone', () {
      test('derives email as digits@earthnova.app', () async {
        final repo = FakeAuthRepository()..userToReturn = _testUser();
        final useCase = SignInWithPhone(repo);
        await useCase.call('(555) 123-4567');
        expect(repo.lastEmail, '5551234567@earthnova.app');
      });

      test('derives password as SHA-256 of phone:earthnova-beta-2026', () async {
        final repo = FakeAuthRepository()..userToReturn = _testUser();
        final useCase = SignInWithPhone(repo);
        await useCase.call('5551234567');
        // Password is SHA-256 of '5551234567:earthnova-beta-2026'
        expect(repo.lastPassword, isNotEmpty);
        expect(repo.lastPassword!.length, 64); // SHA-256 hex length
      });

      test('falls back to signUp when signIn throws invalid credentials', () async {
        final repo = FakeAuthRepository()
          ..shouldThrowOnSignIn = true
          ..userToReturn = _testUser();
        final useCase = SignInWithPhone(repo);
        final result = await useCase.call('5551234567');
        expect(repo.signInCalled, isTrue);
        expect(repo.signUpCalled, isTrue);
        expect(result.id, _testUser().id);
      });

      test('rethrows non-credential AuthExceptions', () async {
        final repo = FakeAuthRepository()..shouldThrowOnSignIn = true;
        // Override to throw a different message
        final useCase = SignInWithPhone(repo);
        // When signIn throws 'Invalid login credentials', it falls back to signUp.
        // If signUp also fails, it should throw.
      });
    });
  }

  UserProfile _testUser() => UserProfile(id: 'u1', phone: '5551234567', createdAt: DateTime(2026));
  ```
  - Run: `flutter test test/features/auth/domain/use_cases/sign_in_with_phone_test.dart` → **FAIL**

- Step 2: **GREEN** — Create `lib/features/auth/domain/repositories/auth_repository.dart`:
  - Abstract `AuthRepository` with: `signInWithEmail`, `signUpWithEmail`, `signOut`, `getCurrentUser`, `restoreSession`, `authStateChanges`
  - `AuthException`, `AuthEvent` sealed class, `AuthStateChanged`, `AuthSessionExpired`, `AuthExternalSignOut`

  Then create `lib/features/auth/domain/use_cases/sign_in_with_phone.dart`:
  ```dart
  class SignInWithPhone {
    const SignInWithPhone(this._repository);
    final AuthRepository _repository;

    Future<UserProfile> call(String phone) async {
      final email = _deriveEmail(phone);
      final password = _derivePassword(phone);
      try {
        return await _repository.signInWithEmail(email, password);
      } on AuthException catch (e) {
        if (e.message.contains('Invalid login credentials')) {
          return await _repository.signUpWithEmail(email, password, metadata: {'phone_number': phone});
        }
        rethrow;
      }
    }

    static String _deriveEmail(String phone) {
      final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
      return '$digits@earthnova.app';
    }

    static String _derivePassword(String phone) {
      final bytes = utf8.encode('$phone:earthnova-beta-2026');
      return sha256.convert(bytes).toString();
    }
  }
  ```
  - Run: → **PASS**

- Step 3: **RED/GREEN** — Same TDD cycle for `SignOut`, `RestoreSession`, `GetCurrentUser` use cases. Each gets a test with a `FakeAuthRepository`, then minimal implementation.
  - `SignOut` — test it calls `repository.signOut()` and emits event
  - `RestoreSession` — test: returns `true` + user when session valid, returns `false` when no session, returns `false` and signs out when anonymous user, handles expired session refresh
  - `GetCurrentUser` — test it delegates to repository

- Step 4: **RED** — Write `test/features/auth/data/repositories/mock_auth_repository_test.dart`: test `MockAuthRepository` accepts 10-digit phone, rejects short phone, sign out clears user.
  - Run: → FAIL

- Step 5: **GREEN** — Create `lib/features/auth/data/repositories/mock_auth_repository.dart` (from current `mock_auth_service.dart`, renamed). Create `lib/features/auth/data/repositories/supabase_auth_repository.dart` (from current `supabase_auth_service.dart`, simplified: raw Supabase calls, uses `UserProfileDto`, phone derivation removed).
  - Run: → PASS

- Step 6: Create auth presentation files — these are moved/refactored from existing, not new behavior:
  - `lib/features/auth/presentation/providers/auth_provider.dart` — `AuthNotifier` calls use cases. Provider declarations: `authRepositoryProvider`, `observabilityProvider`, `signInWithPhoneProvider`, `signOutProvider`, `restoreSessionProvider`. **Fix `state =` → `transition()`** in catch blocks (lines 66-69 of current file).
  - Copy `login_screen.dart`, `loading_screen.dart` with updated imports.

- Step 7: Verify auth feature compiles standalone:
  - Run: `flutter analyze lib/features/auth/` → 0 issues
  - Run: `flutter test test/features/auth/` → all pass

**Must NOT do:**
- Write use case code before its test
- Keep phone→email derivation in repository (it's domain logic)
- Leave `state =` violations in AuthNotifier
- Import Flutter in domain or data layers (except data repos importing supabase_flutter)

**References:**
- `lib/services/auth_service.dart` — Source for AuthRepository interface
- `lib/services/supabase_auth_service.dart:29-58` — Sign-in-or-signup logic moving to use case
- `lib/services/supabase_auth_service.dart:152-162` — `_deriveEmail`/`_derivePassword` moving to use case
- `lib/providers/auth_provider.dart:66-69` — `state =` violations to fix

**Verify:**
- [ ] Run: `flutter test test/features/auth/` → all pass
- [ ] Use case tests: SignInWithPhone (derivation + fallback), SignOut, RestoreSession, GetCurrentUser
- [ ] Phone derivation tested: `(555) 123-4567` → `5551234567@earthnova.app`
- [ ] SHA-256 password derivation produces 64-char hex string
- [ ] Sign-in-or-signup fallback tested with FakeAuthRepository
- [ ] No `state =` in auth_provider.dart (all `transition()`)
- [ ] Run: `flutter analyze lib/features/auth/` → 0 issues

---

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
