# Task: 02-tdd-auth-feature--repositories-use-cases-presentation

## Feature: clean-architecture-migration

## Dependencies

- **1. tdd-core-domain-entities-dtos-and-shared-extensions** (01-tdd-core-domain-entities-dtos-and-shared-extensions)

## Plan Section

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
