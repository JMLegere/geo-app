# Auth First Principles Rewrite

## TL;DR

> **Quick Summary**: Replace the fragile anonymous-first auth with a clean login-required architecture. Phone+OTP is the sole auth method. No anonymous play, no MockAuthService, no fire-and-forget async waterfall. Sequential boot: check session → login → hydrate → map.
> 
> **Deliverables**:
> - New sequential boot sequence (no races between auth, hydration, and map rendering)
> - Phone + OTP login flow (Supabase built-in phone auth)
> - New login screen + OTP verification screen (rebuilt from scratch)
> - Post-first-login onboarding flow
> - Removal of all anonymous auth, MockAuthService, and identity-migration code
> - Updated tests and documentation
> 
> **Estimated Effort**: Large
> **Parallel Execution**: YES — 5 waves
> **Critical Path**: Task 3 → Task 6 → Task 7 → Task 14 → Task 16 → F1-F4

---

## Context

### Original Request
Map doesn't load on first visit (requires refresh). Login resets user progress. Auth has been patched 3 times in 24h (49e17ca, 9738a2c, e9181ea) and is still broken. User wants to start from first principles.

### Interview Summary
**Key Discussions**:
- Current architecture uses fire-and-forget async waterfall in `gameCoordinatorProvider` — map races auth
- Every auth identity change triggers full wipe-and-reload (`loadItems([])`, `loadProfile(zeros)`)
- Anonymous → email creates new user ID, making old data invisible
- User decided: **login required before gameplay, phone+OTP only, no anonymous play**
- **Onboarding shown once after first login**, not before
- **MockAuthService removed entirely** — Supabase always required
- **Both web and mobile first-class**
- **Cached session for offline play** with stable user ID

**Research Findings**:
- `gameCoordinatorProvider` returns synchronously, fires `initializeAuth()` async (not awaited)
- MapScreen hidden (`opacity: 0`) until fog init completes — 10s timeout
- Auth listener on identity change calls `loadItems([])`, `loadProfile(zeros)` — full wipe
- Supabase session in localStorage (web), restored by SDK on init
- IndexedDB-backed SQLite for local cache (web), can be cleared by browser
- Existing OTP TODOs: `auth_service.dart:51`, `supabase_auth_service.dart:119`
- 1373 tests currently pass, many reference MockAuthService
- `onAuthStateChange` listener must be attached BEFORE `Supabase.initialize()` (not after)
- `initialize()` returns immediately without network — must check `session?.isExpired`
- Refresh token is single-use — consumed but response lost = unrecoverable session
- Test phone numbers: up to 10 in Supabase dashboard with predictable OTP (e.g., `000000`)
- E.164 phone format strictly required by Supabase

### Metis Review
**Identified Gaps** (addressed):
- Twilio/SMS provider configuration required as prerequisite (Task 1)
- `onAuthStateChange` must attach BEFORE `initialize()` — built into Task 7
- Session expiry check at boot — built into Task 7
- Refresh token loss edge case — handled in Task 15
- PKCE code verifier loss on web — handled in Task 15
- E.164 validation required client-side — built into Task 2
- Test phone numbers for dev testing — configured in Task 1
- Existing anonymous user data is abandoned (documented as guardrail)

---

## Work Objectives

### Core Objective
Replace the fragile anonymous-first auth architecture with a clean, sequential, login-required architecture using phone+OTP as the sole auth method, eliminating all race conditions between auth, hydration, and map rendering.

### Concrete Deliverables
- `lib/main.dart` — Sequential boot: check cached session → route to login or hydrate+map
- `lib/core/state/game_coordinator_provider.dart` — Remove fire-and-forget async, remove identity change listener, remove anonymous paths
- `lib/features/auth/services/supabase_auth_service.dart` — Phone OTP: send code, verify code, sign out, session restore
- `lib/features/auth/screens/phone_login_screen.dart` — New phone number input screen
- `lib/features/auth/screens/otp_verification_screen.dart` — New OTP code entry screen
- `lib/features/auth/screens/loading_screen.dart` — Hydration splash between login and map
- `lib/features/auth/screens/onboarding_screen.dart` — Post-first-login onboarding (once per account)
- Delete `lib/features/auth/services/mock_auth_service.dart`
- Updated tests, updated docs

### Definition of Done
- [ ] App opens → login screen (no anonymous play, no blank/dark map)
- [ ] Phone + OTP login works on web and mobile
- [ ] Returning user with cached session → straight to map (no login screen flash)
- [ ] First-time user sees onboarding once after login
- [ ] Offline play works with cached session
- [ ] No progress reset on any auth transition
- [ ] `LD_LIBRARY_PATH=. flutter test` passes
- [ ] `flutter analyze` has zero new warnings

### Must Have
- Login screen is the first screen for unauthenticated users
- Phone + OTP is the only auth method
- Sequential boot — no fire-and-forget async, each step gates the next
- Cached session for offline play with stable user ID
- Onboarding shown once per account after first login
- E.164 phone number validation client-side
- 60-second OTP resend cooldown
- Session expiry check at boot (non-null ≠ valid)

### Must NOT Have (Guardrails)
- **No anonymous auth** — remove `signInAnonymously()`, remove all anonymous code paths
- **No MockAuthService in production code** — delete from `lib/`, test doubles stay in `test/`
- **No fire-and-forget async** — every async operation that gates UI must be awaited
- **No identity change migration** — user ID assigned at login, never changes during session
- **No `AuthState.loading()` transitions that wipe game state** — loading is a UI concern, not a state-reset trigger
- **No conditional Supabase** — Supabase is always required (no "if configured" branches in production)
- **No existing anonymous user data migration** — anonymous sessions are abandoned (clean break)
- **No over-engineered error handling** — simple error messages, retry buttons, re-auth on unrecoverable errors

---

## Verification Strategy

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: YES (1373 tests, flutter_test)
- **Automated tests**: Tests-after (fix/update existing tests + add new ones for auth flow)
- **Framework**: flutter_test (hand-written mocks, no mockito/mocktail)

### QA Policy
Every task MUST include agent-executed QA scenarios.
Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

- **Auth flow**: Use Playwright (web) — navigate to login, enter phone, verify OTP, check map loads
- **Boot sequence**: Use Bash — read logs, verify sequential initialization order
- **Offline**: Use Playwright — disable network, verify cached session works
- **Tests**: Use Bash — `LD_LIBRARY_PATH=. flutter test`, verify pass count

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately — prerequisites + data layer):
├── Task 1: Configure Supabase phone auth + test phone numbers [quick]
├── Task 2: Phone number validation utility (E.164) [quick]
├── Task 3: Rewrite AuthState model (remove anonymous, add OTP states) [quick]
├── Task 4: Add hasCompletedOnboarding to player profile + DB migration [quick]
└── Task 5: Create test auth doubles in test/ (replace MockAuthService usage) [unspecified-high]

Wave 2 (After Wave 1 — core auth rewrite):
├── Task 6: Rewrite SupabaseAuthService (phone OTP flow) [deep]
├── Task 7: Rewrite boot sequence (main.dart + gameCoordinatorProvider) [deep]
├── Task 8: Rewrite AuthNotifier (phone-specific, remove anonymous) [quick]
└── Task 9: Remove anonymous auth paths + MockAuthService [quick]

Wave 3 (After Wave 2 — UI):
├── Task 10: Build phone login screen [visual-engineering]
├── Task 11: Build OTP verification screen [visual-engineering]
├── Task 12: Build hydration/loading screen [visual-engineering]
└── Task 13: Build post-login onboarding flow [visual-engineering]

Wave 4 (After Wave 3 — integration + edge cases):
├── Task 14: Wire full auth flow (login → OTP → onboarding → hydrate → map) [deep]
├── Task 15: Handle offline + edge cases (cached session, expired session, token loss) [deep]
└── Task 16: Fix map loading (gate on auth+hydration, remove fog race) [unspecified-high]

Wave 5 (After Wave 4 — cleanup):
├── Task 17: Update/fix tests [unspecified-high]
├── Task 18: Remove all dead code [quick]
└── Task 19: Update documentation [writing]

Wave FINAL (After ALL tasks — independent review, 4 parallel):
├── Task F1: Plan compliance audit (oracle)
├── Task F2: Code quality review (unspecified-high)
├── Task F3: Real QA — web + mobile (unspecified-high + playwright)
└── Task F4: Scope fidelity check (deep)

Critical Path: Task 3 → Task 6 → Task 7 → Task 14 → Task 16 → F1-F4
Parallel Speedup: ~65% faster than sequential
Max Concurrent: 5 (Wave 1)
```

### Dependency Matrix

| Task | Depends On | Blocks | Wave |
|------|-----------|--------|------|
| 1 | — | 6 | 1 |
| 2 | — | 10, 11 | 1 |
| 3 | — | 6, 7, 8, 9 | 1 |
| 4 | — | 13, 14 | 1 |
| 5 | — | 17 | 1 |
| 6 | 1, 3 | 7, 8, 14 | 2 |
| 7 | 3, 6 | 14, 15, 16 | 2 |
| 8 | 3, 6 | 10, 11, 14 | 2 |
| 9 | 3 | 18 | 2 |
| 10 | 2, 8 | 14 | 3 |
| 11 | 2, 8 | 14 | 3 |
| 12 | 7 | 14 | 3 |
| 13 | 4, 8 | 14 | 3 |
| 14 | 7, 8, 10, 11, 12, 13 | 16, 17 | 4 |
| 15 | 7 | 17 | 4 |
| 16 | 7, 14 | 17 | 4 |
| 17 | 5, 14, 15, 16 | F1-F4 | 5 |
| 18 | 9 | F1-F4 | 5 |
| 19 | 14 | F1-F4 | 5 |

### Agent Dispatch Summary

- **Wave 1**: 5 tasks — T1→`quick`, T2→`quick`, T3→`quick`, T4→`quick`, T5→`unspecified-high`
- **Wave 2**: 4 tasks — T6→`deep`, T7→`deep`, T8→`quick`, T9→`quick`
- **Wave 3**: 4 tasks — T10→`visual-engineering`, T11→`visual-engineering`, T12→`visual-engineering`, T13→`visual-engineering`
- **Wave 4**: 3 tasks — T14→`deep`, T15→`deep`, T16→`unspecified-high`
- **Wave 5**: 3 tasks — T17→`unspecified-high`, T18→`quick`, T19→`writing`
- **FINAL**: 4 tasks — F1→`oracle`, F2→`unspecified-high`, F3→`unspecified-high`, F4→`deep`

---

## TODOs

- [x] 1. Configure Supabase Phone Auth + Test Phone Numbers

  **What to do**:
  - This is a **configuration task**, not a code task. Document the required Supabase dashboard settings.
  - Create a setup script or checklist at `scripts/setup-supabase-phone-auth.md`:
    - Enable Phone auth provider in Supabase Dashboard → Authentication → Providers
    - Configure SMS provider (Twilio recommended: Account SID, Auth Token, Sender phone)
    - Add test phone numbers (up to 10) with predictable OTP (e.g., `+15555550100` → `000000`)
    - Note rate limits: 60s per user, 30 per project per 5min
  - Verify phone auth works via Supabase dashboard test tool or curl

  **Must NOT do**:
  - Do NOT write Dart code in this task — config only
  - Do NOT commit Twilio credentials to git

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2, 3, 4, 5)
  - **Blocks**: Task 6 (SupabaseAuthService needs phone auth enabled)
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - `lib/core/config/supabase_config.dart` — Current Supabase credential injection via `--dart-define`

  **External References**:
  - Supabase Phone Auth docs: https://supabase.com/docs/guides/auth/phone-login
  - Supabase test phone numbers: https://supabase.com/docs/guides/auth/phone-login#test-phone-numbers

  **Acceptance Criteria**:
  - [ ] `scripts/setup-supabase-phone-auth.md` exists with step-by-step instructions
  - [ ] At least 2 test phone numbers documented (with their predictable OTPs)
  - [ ] Phone auth provider enabled in project's Supabase dashboard

  **QA Scenarios**:

  ```
  Scenario: Setup script is complete and accurate
    Tool: Bash (read file)
    Preconditions: Task completed
    Steps:
      1. Read scripts/setup-supabase-phone-auth.md
      2. Verify it contains: Twilio config steps, test phone numbers, rate limit info
      3. Verify no credentials are hardcoded in any tracked file
    Expected Result: Script contains all required sections, no secrets in git
    Evidence: .sisyphus/evidence/task-1-setup-script-review.txt
  ```

  **Commit**: YES
  - Message: `🔧 chore(auth): add Supabase phone auth setup documentation`
  - Files: `scripts/setup-supabase-phone-auth.md`

- [x] 2. Phone Number Validation Utility (E.164)

  **What to do**:
  - Create `lib/features/auth/utils/phone_validation.dart`
  - Implement E.164 validation: must start with `+`, followed by 1-15 digits, no spaces/dashes
  - Function: `bool isValidE164(String phone)` — strict validation
  - Function: `String? normalizePhone(String input)` — strip spaces, dashes, parens; prepend `+` if missing country code; return null if unrecoverable
  - Add unit tests at `test/features/auth/utils/phone_validation_test.dart`
  - Test cases: valid E.164, missing `+`, with spaces, with dashes, too short, too long, letters, empty

  **Must NOT do**:
  - Do NOT add a country code picker widget (that's Task 10's concern)
  - Do NOT add any external package for phone validation — keep it pure Dart regex

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 3, 4, 5)
  - **Blocks**: Tasks 10, 11 (login/OTP screens use validation)
  - **Blocked By**: None

  **References**:

  **External References**:
  - E.164 format spec: `+` followed by up to 15 digits (ITU-T E.164)
  - Supabase requires strict E.164: https://supabase.com/docs/guides/auth/phone-login

  **Test References**:
  - `test/core/species/loot_table_test.dart` — Example of pure Dart unit test pattern in this codebase

  **Acceptance Criteria**:
  - [ ] `lib/features/auth/utils/phone_validation.dart` exists
  - [ ] `isValidE164('+15555550100')` returns true
  - [ ] `isValidE164('555-555-0100')` returns false
  - [ ] `normalizePhone('(555) 555-0100')` returns null (no country code, unrecoverable)
  - [ ] `normalizePhone('+1 555 555 0100')` returns `'+15555550100'`
  - [ ] `LD_LIBRARY_PATH=. flutter test test/features/auth/utils/phone_validation_test.dart` passes

  **QA Scenarios**:

  ```
  Scenario: Phone validation tests pass
    Tool: Bash
    Preconditions: Task completed
    Steps:
      1. Run: LD_LIBRARY_PATH=. flutter test test/features/auth/utils/phone_validation_test.dart
      2. Assert: All tests pass, 0 failures
    Expected Result: All phone validation tests pass
    Evidence: .sisyphus/evidence/task-2-phone-validation-tests.txt

  Scenario: Invalid phone numbers rejected
    Tool: Bash
    Preconditions: Task completed
    Steps:
      1. Run: LD_LIBRARY_PATH=. flutter test test/features/auth/utils/phone_validation_test.dart --name "invalid"
      2. Assert: Tests for invalid inputs pass (empty, letters, too short, too long)
    Expected Result: All invalid cases correctly rejected
    Evidence: .sisyphus/evidence/task-2-phone-validation-invalid.txt
  ```

  **Commit**: YES
  - Message: `✨ feat(auth): add E.164 phone number validation utility`
  - Files: `lib/features/auth/utils/phone_validation.dart`, `test/features/auth/utils/phone_validation_test.dart`

- [x] 3. Rewrite AuthState Model (Remove Anonymous, Add OTP States)

  **What to do**:
  - Rewrite `lib/features/auth/models/auth_state.dart`:
    - Remove `AuthState.initial()` (no longer needed — app starts at login or cached session)
    - Remove any anonymous-related states
    - Add OTP flow states: `AuthState.otpSent(phone)`, `AuthState.otpVerifying(phone, code)`
    - Keep: `AuthState.authenticated(user)`, `AuthState.unauthenticated()`, `AuthState.error(message)`
    - Add: `AuthState.loading()` — but ONLY for UI indication, NOT as a state that triggers game state reset
  - Update `AuthStatus` enum to match new states
  - Ensure `AuthState` is immutable with `copyWith()`
  - Update any imports/references in other files that use old states

  **Must NOT do**:
  - Do NOT touch `SupabaseAuthService` (that's Task 6)
  - Do NOT touch `gameCoordinatorProvider` (that's Task 7)
  - Do NOT add UI code

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2, 4, 5)
  - **Blocks**: Tasks 6, 7, 8, 9 (all downstream auth code depends on new model)
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - `lib/features/auth/models/auth_state.dart` — Current AuthState implementation to rewrite
  - `lib/core/models/player_state.dart` — Example of immutable state class with copyWith in this codebase

  **API/Type References**:
  - `lib/features/auth/models/auth_user.dart` — AuthUser model used by AuthState.authenticated

  **Acceptance Criteria**:
  - [ ] `AuthState` has states: `unauthenticated`, `otpSent(phone)`, `otpVerifying(phone, code)`, `authenticated(user)`, `loading()`, `error(message)`
  - [ ] No `AuthState.initial()` or anonymous-related states
  - [ ] `flutter analyze` passes on auth_state.dart

  **QA Scenarios**:

  ```
  Scenario: AuthState model compiles and analyze passes
    Tool: Bash
    Preconditions: Task completed
    Steps:
      1. Run: flutter analyze lib/features/auth/models/auth_state.dart
      2. Assert: No errors or warnings
    Expected Result: Clean analysis
    Evidence: .sisyphus/evidence/task-3-auth-state-analyze.txt

  Scenario: Old anonymous states removed
    Tool: Bash (grep)
    Preconditions: Task completed
    Steps:
      1. Search lib/features/auth/models/auth_state.dart for "anonymous", "initial()", "mock"
      2. Assert: No matches found
    Expected Result: Zero matches for removed states
    Evidence: .sisyphus/evidence/task-3-no-anonymous-states.txt
  ```

  **Commit**: YES
  - Message: `♻️ refactor(auth): rewrite AuthState model for phone-only login`
  - Files: `lib/features/auth/models/auth_state.dart`

- [x] 4. Add hasCompletedOnboarding to Player Profile + DB Migration

  **What to do**:
  - Add `bool hasCompletedOnboarding` field to `PlayerState` in `lib/core/models/player_state.dart` (default: `false`)
  - Update `copyWith()` to include new field
  - Add `hasCompletedOnboarding` column to `LocalPlayerProfileTable` in Drift schema
  - Create Drift schema migration (increment version, add column with default `false`)
  - Run `flutter pub run build_runner build` to regenerate Drift code
  - Update `ProfileRepository` to read/write the new field
  - Update `PlayerNotifier.loadProfile()` to include onboarding flag
  - Add unit test for the new field

  **Must NOT do**:
  - Do NOT build the onboarding UI (that's Task 13)
  - Do NOT touch auth code
  - Do NOT change the Supabase schema (Supabase migration is separate infrastructure concern)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2, 3, 5)
  - **Blocks**: Tasks 13, 14 (onboarding flow needs the flag)
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - `lib/core/models/player_state.dart` — PlayerState class to modify
  - `lib/core/database/app_database.dart` — Drift database with migration pattern
  - `lib/core/persistence/profile_repository.dart` — Repository to update
  - `lib/core/state/player_provider.dart` — PlayerNotifier.loadProfile() to update

  **API/Type References**:
  - `lib/core/database/tables/` — Existing table definitions for Drift column pattern

  **Acceptance Criteria**:
  - [ ] `PlayerState` has `hasCompletedOnboarding` field (default false)
  - [ ] Drift migration adds column to LocalPlayerProfileTable
  - [ ] `flutter pub run build_runner build` succeeds (generated code updated)
  - [ ] `ProfileRepository` can read/write onboarding flag
  - [ ] `LD_LIBRARY_PATH=. flutter test test/core/` passes

  **QA Scenarios**:

  ```
  Scenario: Drift code generation succeeds
    Tool: Bash
    Preconditions: Task completed
    Steps:
      1. Run: flutter pub run build_runner build --delete-conflicting-outputs
      2. Assert: Exit code 0, no errors
    Expected Result: Drift generated code updated successfully
    Evidence: .sisyphus/evidence/task-4-build-runner.txt

  Scenario: Player profile tests pass with new field
    Tool: Bash
    Preconditions: Task completed
    Steps:
      1. Run: LD_LIBRARY_PATH=. flutter test test/core/ --name "player"
      2. Assert: All player-related tests pass
    Expected Result: Tests pass with new onboarding field
    Evidence: .sisyphus/evidence/task-4-player-tests.txt
  ```

  **Commit**: YES
  - Message: `🗃️ feat(db): add hasCompletedOnboarding to player profile`
  - Files: `lib/core/models/player_state.dart`, `lib/core/database/app_database.dart`, `lib/core/database/app_database.g.dart`, `lib/core/persistence/profile_repository.dart`, `lib/core/state/player_provider.dart`
  - Pre-commit: `LD_LIBRARY_PATH=. flutter test test/core/`

- [x] 5. Create Test Auth Doubles in test/ (Replace MockAuthService Usage)

  **What to do**:
  - Create `test/fixtures/auth_test_doubles.dart` with:
    - `FakeAuthService implements AuthService` — returns predictable authenticated user, no Supabase dependency
    - `FakeAuthUser` — test user with stable ID, phone number
    - Helper: `makeAuthenticatedContainer()` — creates `ProviderContainer` with auth pre-configured as authenticated
  - Audit ALL test files that import `mock_auth_service.dart` — update imports to use new test doubles
  - Audit ALL test files that reference `MockAuthService` — replace with `FakeAuthService`
  - Ensure existing tests still compile after the switch (they may not pass yet if auth model changed — that's OK, Task 17 handles full test fixes)

  **Must NOT do**:
  - Do NOT delete MockAuthService yet (that's Task 9/18 — delete after all references removed)
  - Do NOT fix tests that fail for other reasons — only fix import/reference issues
  - Do NOT add Supabase dependency to test code

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Requires auditing many test files and creating test infrastructure
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2, 3, 4)
  - **Blocks**: Task 17 (test fixes use new doubles)
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - `lib/features/auth/services/mock_auth_service.dart` — Current mock to be replaced (study its interface)
  - `lib/features/auth/services/auth_service.dart` — AuthService interface that test doubles must implement
  - `test/fixtures/` — Existing test fixture directory and patterns

  **Test References**:
  - `test/core/state/game_coordinator_provider_test.dart` — Likely uses MockAuthService heavily
  - `test/features/auth/` — Auth-specific tests

  **Acceptance Criteria**:
  - [ ] `test/fixtures/auth_test_doubles.dart` exists
  - [ ] `FakeAuthService` implements `AuthService` interface
  - [ ] Zero test files import `mock_auth_service.dart` (search: `import.*mock_auth_service`)
  - [ ] `flutter analyze test/` passes (no unresolved imports)

  **QA Scenarios**:

  ```
  Scenario: No test files reference MockAuthService
    Tool: Bash (grep)
    Preconditions: Task completed
    Steps:
      1. Search test/ for "mock_auth_service" or "MockAuthService"
      2. Assert: Zero matches
    Expected Result: All references migrated to FakeAuthService
    Evidence: .sisyphus/evidence/task-5-no-mock-refs.txt

  Scenario: Test files compile after migration
    Tool: Bash
    Preconditions: Task completed
    Steps:
      1. Run: flutter analyze test/
      2. Assert: No import errors (warnings OK at this stage)
    Expected Result: All test files resolve imports correctly
    Evidence: .sisyphus/evidence/task-5-test-analyze.txt
  ```

  **Commit**: YES
  - Message: `✅ test(auth): create test auth doubles replacing MockAuthService`
  - Files: `test/fixtures/auth_test_doubles.dart`, all test files that referenced MockAuthService

- [ ] 6. Rewrite SupabaseAuthService (Phone OTP Flow)

  **What to do**:
  - Rewrite `lib/features/auth/services/supabase_auth_service.dart`:
    - Remove `signInAnonymously()` method
    - Remove any email/password methods
    - Implement `sendOtp(String phone)` — calls `supabase.auth.signInWithOtp(phone: phone)`, returns success/error
    - Implement `verifyOtp(String phone, String code)` — calls `supabase.auth.verifyOTP(phone: phone, token: code, type: OtpType.sms)`, returns AuthUser or error
    - Keep `signOut()` — calls `supabase.auth.signOut()`
    - Keep `getCurrentUser()` — reads current Supabase session
    - Keep `authStateChanges` stream — wraps `supabase.auth.onAuthStateChange`
    - Add `restoreSession()` — checks if cached session exists and is not expired
  - Update `AuthService` interface at `lib/features/auth/services/auth_service.dart` to match new methods
  - Handle errors: invalid phone, rate limited, invalid OTP, expired OTP, network error
  - E.164 validation before calling Supabase (use utility from Task 2)

  **Must NOT do**:
  - Do NOT implement UI (that's Tasks 10-11)
  - Do NOT touch gameCoordinatorProvider (that's Task 7)
  - Do NOT add Twilio SDK — Supabase handles SMS delivery server-side

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Core auth service with error handling, Supabase API integration, multiple methods
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Task 9, partially with 7 and 8)
  - **Parallel Group**: Wave 2
  - **Blocks**: Tasks 7, 8, 14 (boot sequence and provider depend on new service interface)
  - **Blocked By**: Tasks 1 (phone auth configured), 3 (AuthState model)

  **References**:

  **Pattern References**:
  - `lib/features/auth/services/supabase_auth_service.dart` — Current implementation to rewrite
  - `lib/features/auth/services/auth_service.dart` — Interface to update

  **API/Type References**:
  - `lib/features/auth/models/auth_state.dart` — New AuthState model (from Task 3)
  - `lib/features/auth/models/auth_user.dart` — AuthUser model

  **External References**:
  - Supabase Flutter phone OTP: https://supabase.com/docs/reference/dart/auth-signinwithotp
  - Supabase Flutter verify OTP: https://supabase.com/docs/reference/dart/auth-verifyotp

  **Acceptance Criteria**:
  - [ ] `AuthService` interface has: `sendOtp(phone)`, `verifyOtp(phone, code)`, `signOut()`, `getCurrentUser()`, `authStateChanges`, `restoreSession()`
  - [ ] No `signInAnonymously()` in AuthService interface or SupabaseAuthService
  - [ ] `sendOtp` validates E.164 before calling Supabase
  - [ ] `verifyOtp` returns `AuthUser` on success, throws typed error on failure
  - [ ] `restoreSession()` checks `session?.isExpired` (not just non-null)
  - [ ] `flutter analyze lib/features/auth/` passes

  **QA Scenarios**:

  ```
  Scenario: AuthService interface is clean
    Tool: Bash (grep)
    Preconditions: Task completed
    Steps:
      1. Search lib/features/auth/services/auth_service.dart for "anonymous", "signInAnonymously", "email", "password"
      2. Assert: Zero matches
    Expected Result: Interface has no anonymous or email methods
    Evidence: .sisyphus/evidence/task-6-clean-interface.txt

  Scenario: SupabaseAuthService compiles
    Tool: Bash
    Preconditions: Task completed
    Steps:
      1. Run: flutter analyze lib/features/auth/services/
      2. Assert: No errors
    Expected Result: All auth service files pass analysis
    Evidence: .sisyphus/evidence/task-6-analyze.txt
  ```

  **Commit**: YES
  - Message: `✨ feat(auth): implement phone OTP flow in SupabaseAuthService`
  - Files: `lib/features/auth/services/auth_service.dart`, `lib/features/auth/services/supabase_auth_service.dart`

- [ ] 7. Rewrite Boot Sequence (main.dart + gameCoordinatorProvider)

  **What to do**:
  - **Rewrite `lib/main.dart`**:
    - `main()`: `WidgetsFlutterBinding.ensureInitialized()` → `SupabaseBootstrap.initialize()` (**await it**, no longer fire-and-forget) → `runApp()`
    - **CRITICAL**: Attach `onAuthStateChange` listener BEFORE `Supabase.initialize()` (not after)
    - `EarthNovaApp.build()`: Route based on auth state:
      - `unauthenticated` / `otpSent` / `otpVerifying` → Login flow screens
      - `authenticated` + `!hasCompletedOnboarding` → OnboardingScreen
      - `authenticated` + `hasCompletedOnboarding` → TabShell (map)
      - `loading` → Hydration splash (NOT a state that resets game data)
    - Remove: blank scaffold for `onboarded == null`, remove `onboardingProvider` dependency
  - **Rewrite `lib/core/state/game_coordinator_provider.dart`**:
    - Remove `initializeAuth()` — auth is resolved BEFORE provider is accessed
    - Remove fire-and-forget async — provider receives auth state as input
    - Remove identity change listener (`ref.listen(authProvider)` that triggers hydrateAndStart)
    - Remove `signInAnonymously()` fallback
    - Remove conditional MockAuthService creation
    - Keep: `hydrateAndStart(userId)` — but called ONCE after login, not on every auth change
    - Keep: `rehydrateData(userId)` — loads from SQLite/Supabase
    - Keep: `startLoop()` — starts GPS + game loop
    - New flow: Provider is only created after auth is confirmed → hydrate → start → done
  - **Rewrite `lib/core/config/supabase_bootstrap.dart`**:
    - Remove 3s timeout fallback to mock — if Supabase fails, show error, don't silently degrade
    - Make `initialize()` return a result (success/failure) rather than silently swallowing errors
    - Add: check `session?.isExpired` at boot — expired session = show login screen

  **Must NOT do**:
  - Do NOT build UI screens (Tasks 10-13)
  - Do NOT implement phone OTP methods (Task 6)
  - Do NOT remove MockAuthService file yet (Task 9/18)
  - Do NOT add retry/backoff logic (Task 15 handles edge cases)

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Core architectural rewrite of the app's boot sequence and central coordinator. Highest-risk task.
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: Partially (with Task 8 and 9 after Task 6 completes)
  - **Parallel Group**: Wave 2
  - **Blocks**: Tasks 14, 15, 16 (everything downstream depends on new boot sequence)
  - **Blocked By**: Tasks 3 (AuthState model), 6 (new AuthService interface)

  **References**:

  **Pattern References**:
  - `lib/main.dart:15-58` — Current boot sequence to rewrite
  - `lib/core/state/game_coordinator_provider.dart:67-630` — Central coordinator to rewrite
  - `lib/core/config/supabase_bootstrap.dart` — Bootstrap to rewrite

  **API/Type References**:
  - `lib/features/auth/services/auth_service.dart` — New AuthService interface (from Task 6)
  - `lib/features/auth/models/auth_state.dart` — New AuthState model (from Task 3)

  **WHY Each Reference Matters**:
  - `main.dart` — Must understand current routing logic to replace it with auth-gated routing
  - `game_coordinator_provider.dart` — Must understand ALL the async operations to restructure them as sequential
  - `supabase_bootstrap.dart` — Must understand the 3s timeout and fallback logic to replace with strict error handling

  **Acceptance Criteria**:
  - [ ] `main()` awaits `SupabaseBootstrap.initialize()` before `runApp()`
  - [ ] `onAuthStateChange` listener attached BEFORE `Supabase.initialize()`
  - [ ] `gameCoordinatorProvider` has NO `initializeAuth()` method
  - [ ] `gameCoordinatorProvider` has NO `ref.listen(authProvider)` identity change listener
  - [ ] `gameCoordinatorProvider` has NO `signInAnonymously()` call
  - [ ] `gameCoordinatorProvider` has NO conditional MockAuthService creation
  - [ ] Boot sequence: `await supabase init` → check session → route (login or hydrate+map)
  - [ ] `flutter analyze` passes on main.dart and game_coordinator_provider.dart

  **QA Scenarios**:

  ```
  Scenario: No fire-and-forget async in boot
    Tool: Bash (grep)
    Preconditions: Task completed
    Steps:
      1. Search lib/main.dart for "initializeAuth" — should not exist
      2. Search lib/core/state/game_coordinator_provider.dart for "initializeAuth" — should not exist
      3. Search for "signInAnonymously" in both files — should not exist
    Expected Result: Zero matches for fire-and-forget patterns
    Evidence: .sisyphus/evidence/task-7-no-fire-forget.txt

  Scenario: Sequential boot compiles
    Tool: Bash
    Preconditions: Task completed
    Steps:
      1. Run: flutter analyze lib/main.dart lib/core/state/game_coordinator_provider.dart lib/core/config/supabase_bootstrap.dart
      2. Assert: No errors
    Expected Result: All rewritten files pass analysis
    Evidence: .sisyphus/evidence/task-7-analyze.txt
  ```

  **Commit**: YES
  - Message: `♻️ refactor(core): sequential boot sequence — no fire-and-forget async`
  - Files: `lib/main.dart`, `lib/core/state/game_coordinator_provider.dart`, `lib/core/config/supabase_bootstrap.dart`

- [ ] 8. Rewrite AuthNotifier (Phone-Specific, Remove Anonymous)

  **What to do**:
  - Rewrite `lib/features/auth/providers/auth_provider.dart`:
    - Remove `signIn(email, password)`, `signUp(email, password)`, `upgradeWithEmail(email, password)`
    - Remove `signInWithPhone()` (the old upgrade path)
    - Add `sendOtp(String phone)` — calls AuthService.sendOtp, transitions to `otpSent` state
    - Add `verifyOtp(String phone, String code)` — calls AuthService.verifyOtp, transitions to `authenticated`
    - Keep `signOut()` — transitions to `unauthenticated`
    - Ensure `loading` state is only used for UI indication, NOT for game state reset
    - State transitions: `unauthenticated` → `otpSent(phone)` → `authenticated(user)` or `error(message)`
  - Ensure the notifier follows Riverpod v3 `Notifier` pattern (not StateNotifier)

  **Must NOT do**:
  - Do NOT add UI code
  - Do NOT touch gameCoordinatorProvider

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Straightforward provider rewrite with clear state machine
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 7, 9)
  - **Parallel Group**: Wave 2
  - **Blocks**: Tasks 10, 11, 14 (UI screens and flow wire-up read auth provider)
  - **Blocked By**: Tasks 3 (AuthState model), 6 (new AuthService)

  **References**:

  **Pattern References**:
  - `lib/features/auth/providers/auth_provider.dart` — Current provider to rewrite
  - `lib/core/state/player_provider.dart` — Example of Riverpod v3 Notifier pattern

  **API/Type References**:
  - `lib/features/auth/models/auth_state.dart` — New AuthState (from Task 3)
  - `lib/features/auth/services/auth_service.dart` — New AuthService interface (from Task 6)

  **Acceptance Criteria**:
  - [ ] AuthNotifier has: `sendOtp(phone)`, `verifyOtp(phone, code)`, `signOut()`
  - [ ] No `signIn(email, password)`, `signUp`, `upgradeWithEmail`, `signInWithPhone`
  - [ ] Uses `Notifier` pattern (not `StateNotifier`)
  - [ ] `flutter analyze lib/features/auth/providers/` passes

  **QA Scenarios**:

  ```
  Scenario: AuthNotifier has only phone methods
    Tool: Bash (grep)
    Preconditions: Task completed
    Steps:
      1. Search auth_provider.dart for "signIn(", "signUp(", "upgradeWithEmail", "email", "password"
      2. Assert: Zero matches (except possibly in comments)
    Expected Result: Only phone OTP methods remain
    Evidence: .sisyphus/evidence/task-8-phone-only-notifier.txt
  ```

  **Commit**: YES (grouped with Task 9)
  - Message: `♻️ refactor(auth): phone-only AuthNotifier + remove anonymous paths`
  - Files: `lib/features/auth/providers/auth_provider.dart`

- [ ] 9. Remove Anonymous Auth Paths from Production Code

  **What to do**:
  - Search entire `lib/` for references to anonymous auth and remove them:
    - `signInAnonymously` — any calls or references
    - `MockAuthService` — any imports, instantiations, or conditional usage
    - `isAnonymous` / `anonymous` — any auth state checks
    - Conditional Supabase logic: `if (bootstrap.initialized)` branches that fall back to mock
  - In `gameCoordinatorProvider`: remove the `else → MockAuthService` branch
  - In `supabase_bootstrap.dart`: remove silent fallback to offline mode
  - In `auth_provider.dart`: remove any anonymous state handling
  - Do NOT delete `lib/features/auth/services/mock_auth_service.dart` yet — just remove all references to it. Task 18 handles file deletion.

  **Must NOT do**:
  - Do NOT delete files yet (that's Task 18)
  - Do NOT modify test files (that's Task 5/17)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Search-and-remove, no new logic
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 7, 8)
  - **Parallel Group**: Wave 2
  - **Blocks**: Task 18 (dead code removal)
  - **Blocked By**: Task 3 (AuthState model must be rewritten first)

  **References**:

  **Pattern References**:
  - `lib/core/state/game_coordinator_provider.dart` — Has conditional MockAuthService creation
  - `lib/core/config/supabase_bootstrap.dart` — Has silent fallback logic
  - `lib/features/auth/providers/auth_provider.dart` — May have anonymous references
  - `lib/features/sync/` — May reference auth conditional logic

  **Acceptance Criteria**:
  - [ ] `grep -r "signInAnonymously" lib/` returns zero results
  - [ ] `grep -r "MockAuthService" lib/` returns zero results (except the file itself which hasn't been deleted)
  - [ ] `grep -r "isAnonymous" lib/` returns zero results
  - [ ] `flutter analyze lib/` passes

  **QA Scenarios**:

  ```
  Scenario: No anonymous auth references in lib/
    Tool: Bash (grep)
    Preconditions: Task completed
    Steps:
      1. Run: grep -rn "signInAnonymously\|MockAuthService\|isAnonymous" lib/ --include="*.dart" | grep -v "mock_auth_service.dart"
      2. Assert: Zero matches (excluding the mock file itself)
    Expected Result: All anonymous auth references removed from production code
    Evidence: .sisyphus/evidence/task-9-no-anonymous.txt
  ```

  **Commit**: YES (grouped with Task 8)
  - Message: `♻️ refactor(auth): phone-only AuthNotifier + remove anonymous paths`

- [ ] 10. Build Phone Login Screen

  **What to do**:
  - Create `lib/features/auth/screens/phone_login_screen.dart`:
    - Full-screen layout with EarthNova branding (game-themed, dark background #0D1B2A)
    - Phone number input field with country code prefix (+1 default, or auto-detect)
    - "Continue" button — validates E.164 (using Task 2 utility), calls `authProvider.sendOtp(phone)`
    - Loading state while OTP is being sent
    - Error display (invalid phone, rate limited, network error)
    - On success: navigate to OTP verification screen (Task 11)
  - Use `ConsumerWidget` or `ConsumerStatefulWidget` (Riverpod v3 pattern)
  - Must work on both web and mobile
  - Keyboard type: phone number

  **Must NOT do**:
  - Do NOT implement OTP verification (that's Task 11)
  - Do NOT add country code picker package — just a simple text prefix for now
  - Do NOT over-engineer animations or transitions — clean, functional, game-themed

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: UI screen with game-themed design
  - **Skills**: [`frontend-ui-ux`]
    - `frontend-ui-ux`: Login screen needs polished design matching game aesthetic

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 11, 12, 13)
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 14 (flow wire-up)
  - **Blocked By**: Tasks 2 (phone validation), 8 (AuthNotifier with sendOtp)

  **References**:

  **Pattern References**:
  - `lib/features/map/map_screen.dart` — Example of ConsumerStatefulWidget in this codebase
  - `lib/shared/constants.dart` — Game color constants if any
  - `web/index.html` — Splash background color (#0D1B2A) for consistency

  **API/Type References**:
  - `lib/features/auth/providers/auth_provider.dart` — `authProvider.sendOtp(phone)` (from Task 8)
  - `lib/features/auth/utils/phone_validation.dart` — `isValidE164()`, `normalizePhone()` (from Task 2)
  - `lib/features/auth/models/auth_state.dart` — Watch for `otpSent`, `error` states

  **Acceptance Criteria**:
  - [ ] `phone_login_screen.dart` exists and compiles
  - [ ] Has phone input field with keyboard type `TextInputType.phone`
  - [ ] Validates E.164 before sending (shows inline error for invalid)
  - [ ] Shows loading indicator while OTP sends
  - [ ] Shows error message on failure (rate limit, network error)
  - [ ] Responsive layout works on mobile and web viewports

  **QA Scenarios**:

  ```
  Scenario: Login screen renders with phone input
    Tool: Playwright (web)
    Preconditions: App running in web, user not authenticated
    Steps:
      1. Navigate to app URL
      2. Assert: Login screen visible (not map, not blank)
      3. Assert: Phone number input field present
      4. Assert: "Continue" or "Send Code" button present
    Expected Result: Clean login screen with phone input
    Evidence: .sisyphus/evidence/task-10-login-screen.png

  Scenario: Invalid phone shows error
    Tool: Playwright (web)
    Preconditions: Login screen visible
    Steps:
      1. Enter "abc" in phone field
      2. Tap Continue button
      3. Assert: Error message visible (e.g., "Enter a valid phone number")
      4. Assert: No OTP sent (no navigation to OTP screen)
    Expected Result: Validation error shown, no API call
    Evidence: .sisyphus/evidence/task-10-invalid-phone-error.png
  ```

  **Commit**: YES (grouped with Task 11)
  - Message: `🎨 feat(ui): phone login + OTP verification screens`
  - Files: `lib/features/auth/screens/phone_login_screen.dart`

- [ ] 11. Build OTP Verification Screen

  **What to do**:
  - Create `lib/features/auth/screens/otp_verification_screen.dart`:
    - Receives phone number as parameter (from login screen)
    - Shows "Enter the code sent to +1XXXXXXXX" message
    - 6-digit code input (individual boxes or single field)
    - Auto-submit when 6 digits entered (or manual "Verify" button)
    - "Resend code" link with 60-second cooldown timer (countdown visible)
    - Loading state while verifying
    - Error display (wrong code, expired code, network error)
    - On success: `authProvider.verifyOtp(phone, code)` → navigate to onboarding or map
  - Use `ConsumerStatefulWidget` for timer state

  **Must NOT do**:
  - Do NOT implement navigation logic (that's Task 14)
  - Do NOT add SMS auto-fill (nice-to-have, not MVP)

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: UI screen with timer logic and game-themed design
  - **Skills**: [`frontend-ui-ux`]

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 10, 12, 13)
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 14 (flow wire-up)
  - **Blocked By**: Tasks 2 (phone validation), 8 (AuthNotifier with verifyOtp)

  **References**:

  **Pattern References**:
  - `lib/features/auth/screens/phone_login_screen.dart` — Sibling screen for consistent design (from Task 10)

  **API/Type References**:
  - `lib/features/auth/providers/auth_provider.dart` — `authProvider.verifyOtp(phone, code)` (from Task 8)
  - `lib/features/auth/models/auth_state.dart` — Watch for `authenticated`, `error` states

  **Acceptance Criteria**:
  - [ ] `otp_verification_screen.dart` exists and compiles
  - [ ] Shows phone number the code was sent to
  - [ ] Has 6-digit code input
  - [ ] Resend button with visible 60s countdown timer
  - [ ] Shows loading while verifying, error on failure

  **QA Scenarios**:

  ```
  Scenario: OTP screen shows phone and code input
    Tool: Playwright (web)
    Preconditions: User entered valid phone on login screen
    Steps:
      1. Navigate to OTP screen (or trigger via login flow)
      2. Assert: Phone number displayed (masked or full)
      3. Assert: Code input field present
      4. Assert: Resend button present (disabled with countdown)
    Expected Result: OTP screen with correct layout
    Evidence: .sisyphus/evidence/task-11-otp-screen.png

  Scenario: Wrong OTP shows error
    Tool: Playwright (web)
    Preconditions: OTP screen visible
    Steps:
      1. Enter "999999" (wrong code)
      2. Tap Verify (or wait for auto-submit)
      3. Assert: Error message visible (e.g., "Invalid code")
    Expected Result: Error shown, stays on OTP screen
    Evidence: .sisyphus/evidence/task-11-wrong-otp.png
  ```

  **Commit**: YES (grouped with Task 10)
  - Message: `🎨 feat(ui): phone login + OTP verification screens`
  - Files: `lib/features/auth/screens/otp_verification_screen.dart`

- [ ] 12. Build Hydration/Loading Screen

  **What to do**:
  - Create `lib/features/auth/screens/loading_screen.dart`:
    - Full-screen loading display shown between successful login and map
    - Game-themed (dark background, animated globe or logo, "Loading your world..." text)
    - Shown while `hydrateAndStart(userId)` runs (fetching data from Supabase + SQLite)
    - On hydration complete: navigate to onboarding (first time) or map (returning user)
    - Timeout: if hydration takes >15s, show retry button
    - This replaces the current `_LoadingSplash` in main.dart

  **Must NOT do**:
  - Do NOT implement hydration logic (that's in gameCoordinatorProvider from Task 7)
  - Do NOT add complex animations — simple, clean loading indicator

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: [`frontend-ui-ux`]

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 10, 11, 13)
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 14 (flow wire-up)
  - **Blocked By**: Task 7 (boot sequence determines when loading screen shows)

  **References**:

  **Pattern References**:
  - `lib/main.dart` — Current `_LoadingSplash` widget (lines ~60-80) to replace
  - `web/index.html` — Splash design (#0D1B2A background) for consistency

  **Acceptance Criteria**:
  - [ ] `loading_screen.dart` exists and compiles
  - [ ] Shows loading indicator and "Loading your world..." text
  - [ ] Has 15s timeout with retry button
  - [ ] Consistent dark theme (#0D1B2A)

  **QA Scenarios**:

  ```
  Scenario: Loading screen appears between login and map
    Tool: Playwright (web)
    Preconditions: User successfully verified OTP
    Steps:
      1. After OTP verification succeeds
      2. Assert: Loading screen visible (not login, not map yet)
      3. Wait for hydration to complete
      4. Assert: Map screen appears
    Expected Result: Smooth transition: OTP → Loading → Map
    Evidence: .sisyphus/evidence/task-12-loading-screen.png
  ```

  **Commit**: YES (grouped with Task 13)
  - Message: `🎨 feat(ui): hydration loading + onboarding screens`
  - Files: `lib/features/auth/screens/loading_screen.dart`

- [ ] 13. Build Post-Login Onboarding Flow

  **What to do**:
  - Create `lib/features/auth/screens/onboarding_screen.dart`:
    - Shown ONCE per account, after first login
    - 1-3 screens: game concept intro, GPS permission request, "Let's explore!" CTA
    - PageView with dot indicators for multiple screens
    - "Get Started" button on final screen → set `hasCompletedOnboarding = true` → navigate to map
    - Request location permission during onboarding (if not already granted)
    - Skip button for returning users who somehow see it again
  - Update `PlayerNotifier` to expose `markOnboardingComplete()` method that sets the flag and persists it

  **Must NOT do**:
  - Do NOT over-design — 1-3 simple screens with text and maybe an icon/illustration
  - Do NOT add tutorial gameplay — just intro and permission request

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: [`frontend-ui-ux`]

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 10, 11, 12)
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 14 (flow wire-up)
  - **Blocked By**: Tasks 4 (onboarding flag in player profile), 8 (AuthNotifier)

  **References**:

  **Pattern References**:
  - `lib/features/navigation/screens/onboarding_screen.dart` — Existing onboarding (if any) to replace
  - `lib/core/state/player_provider.dart` — PlayerNotifier for onboarding flag

  **API/Type References**:
  - `lib/core/models/player_state.dart` — `hasCompletedOnboarding` field (from Task 4)

  **Acceptance Criteria**:
  - [ ] `onboarding_screen.dart` exists and compiles
  - [ ] PageView with 1-3 screens and dot indicators
  - [ ] Requests location permission
  - [ ] "Get Started" sets `hasCompletedOnboarding = true` and navigates to map
  - [ ] Only shows for first-time users (checked via player profile flag)

  **QA Scenarios**:

  ```
  Scenario: First-time user sees onboarding after login
    Tool: Playwright (web)
    Preconditions: New user, just verified OTP, hasCompletedOnboarding = false
    Steps:
      1. After loading screen completes
      2. Assert: Onboarding screen visible (not map)
      3. Swipe/navigate through screens
      4. Tap "Get Started"
      5. Assert: Map screen appears
    Expected Result: Onboarding → Map transition
    Evidence: .sisyphus/evidence/task-13-onboarding-flow.png

  Scenario: Returning user skips onboarding
    Tool: Playwright (web)
    Preconditions: Returning user with cached session, hasCompletedOnboarding = true
    Steps:
      1. Open app
      2. Assert: Map screen appears directly (no onboarding)
    Expected Result: Straight to map, no onboarding flash
    Evidence: .sisyphus/evidence/task-13-skip-onboarding.png
  ```

  **Commit**: YES (grouped with Task 12)
  - Message: `🎨 feat(ui): hydration loading + onboarding screens`
  - Files: `lib/features/auth/screens/onboarding_screen.dart`

- [ ] 14. Wire Full Auth Flow (Login → OTP → Onboarding → Hydrate → Map)

  **What to do**:
  - Wire together all the pieces from Tasks 7-13 into a complete flow:
  - **In `main.dart`** (or a new router file):
    - Watch `authProvider` state to determine which screen to show
    - `unauthenticated` → `PhoneLoginScreen`
    - `otpSent(phone)` → `OtpVerificationScreen(phone: phone)`
    - `authenticated` → check `playerProvider.hasCompletedOnboarding`:
      - `false` → `OnboardingScreen`
      - `true` → `LoadingScreen` → (hydrate) → `TabShell`
    - Handle back navigation: OTP screen → back → login screen
  - **Navigation transitions**: Smooth, no flicker. Use `AnimatedSwitcher` or `Navigator.pushReplacement`
  - **Session restore flow**: App opens → check cached session → if valid + not expired → skip login, go straight to loading → hydrate → map
  - **Error recovery**: Auth error → show error on current screen → user can retry
  - Verify the COMPLETE flow end-to-end:
    1. Cold start (no session) → login → OTP → onboarding → loading → map
    2. Warm start (cached session) → loading → map
    3. Returning user (cached session + onboarded) → loading → map (fast)

  **Must NOT do**:
  - Do NOT add complex routing library (Navigator 2.0 / go_router) unless already in the project
  - Do NOT modify game logic or map rendering

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Integration task wiring multiple screens with state-driven navigation. Highest integration risk.
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO (depends on all Wave 3 tasks)
  - **Parallel Group**: Wave 4 (with Tasks 15, 16)
  - **Blocks**: Tasks 16, 17
  - **Blocked By**: Tasks 7, 8, 10, 11, 12, 13

  **References**:

  **Pattern References**:
  - `lib/main.dart` — Current routing logic to replace (EarthNovaApp.build)
  - `lib/features/navigation/screens/tab_shell.dart` — TabShell destination after auth

  **API/Type References**:
  - `lib/features/auth/providers/auth_provider.dart` — AuthState to watch
  - `lib/core/state/player_provider.dart` — `hasCompletedOnboarding` to check
  - `lib/features/auth/screens/` — All new screens (Tasks 10-13)

  **Acceptance Criteria**:
  - [ ] Cold start: no session → login screen → OTP → onboarding → loading → map
  - [ ] Warm start: cached session → loading → map (no login flash)
  - [ ] Error recovery: failed OTP → stays on OTP screen with error → can retry
  - [ ] Back navigation: OTP → back → login
  - [ ] No flicker or blank screens during transitions

  **QA Scenarios**:

  ```
  Scenario: Cold start — full login flow
    Tool: Playwright (web)
    Preconditions: Clear all browser storage (localStorage, IndexedDB)
    Steps:
      1. Navigate to app URL
      2. Assert: Login screen visible within 3s
      3. Enter test phone number (from Supabase test phones)
      4. Tap Continue
      5. Assert: OTP screen visible
      6. Enter test OTP (e.g., 000000)
      7. Assert: Loading screen visible briefly
      8. Assert: Onboarding screen visible (first-time user)
      9. Complete onboarding
      10. Assert: Map screen visible with fog rendering
    Expected Result: Complete flow in <15s, no blank screens, no errors
    Failure Indicators: Blank screen at any step, error message, map not rendering
    Evidence: .sisyphus/evidence/task-14-cold-start-flow.png

  Scenario: Warm start — cached session
    Tool: Playwright (web)
    Preconditions: User previously logged in (session in localStorage)
    Steps:
      1. Navigate to app URL
      2. Assert: Login screen does NOT appear
      3. Assert: Loading screen appears briefly
      4. Assert: Map screen visible within 5s
    Expected Result: Straight to map, no login screen flash
    Failure Indicators: Login screen flashes, progress reset, map blank
    Evidence: .sisyphus/evidence/task-14-warm-start.png

  Scenario: Page refresh — session persists
    Tool: Playwright (web)
    Preconditions: User authenticated, map visible
    Steps:
      1. Press F5 (refresh page)
      2. Wait for app to reload
      3. Assert: Map screen visible within 5s (no login screen)
      4. Assert: Player progress visible (cells observed > 0)
    Expected Result: Session survives refresh, progress intact
    Evidence: .sisyphus/evidence/task-14-refresh-persist.png
  ```

  **Commit**: YES
  - Message: `✨ feat(auth): wire full login → OTP → onboarding → map flow`
  - Files: `lib/main.dart`, possibly new router file
  - Pre-commit: `LD_LIBRARY_PATH=. flutter test`

- [ ] 15. Handle Offline + Edge Cases (Cached Session, Expired Session, Token Loss)

  **What to do**:
  - **Cached session, no network**: At boot, if session exists in local storage but network is unavailable:
    - Load session from cache → check `isExpired` → if valid, proceed to hydrate from SQLite only → map
    - If expired + no network → show login screen with "No internet" message and retry button
  - **Refresh token consumed but response lost**: If SDK fails to refresh and returns auth error:
    - Clear local session → redirect to login screen
    - Show friendly message: "Session expired. Please sign in again."
  - **PKCE code verifier loss (web)**: If `verifyOtp` fails with "Code verifier not found":
    - Show error: "Something went wrong. Please try again."
    - Redirect to login screen (re-enter phone, get new OTP)
  - **Network drops during OTP send/verify**: Show error with retry button, don't navigate away
  - **Supabase initialization failure**: Show error screen with retry button (not silent fallback to mock)
  - Add these error paths to the auth state machine

  **Must NOT do**:
  - Do NOT implement complex retry/backoff — simple retry buttons are sufficient
  - Do NOT add connectivity monitoring package — check network on-demand

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Multiple edge cases requiring careful state management and error handling
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Task 16)
  - **Parallel Group**: Wave 4
  - **Blocks**: Task 17
  - **Blocked By**: Task 7 (boot sequence)

  **References**:

  **Pattern References**:
  - `lib/core/state/game_coordinator_provider.dart` — Hydration logic (hydrateAndStart, rehydrateData)
  - `lib/core/config/supabase_bootstrap.dart` — Initialization error handling

  **External References**:
  - Supabase session refresh: https://supabase.com/docs/reference/dart/auth-refreshsession
  - Flutter web localStorage: standard `window.localStorage`

  **Acceptance Criteria**:
  - [ ] Offline with valid cached session → hydrate from SQLite → map works
  - [ ] Offline with expired session → login screen with "No internet" message
  - [ ] Token refresh failure → redirect to login with friendly message
  - [ ] Network drop during OTP → error with retry, stays on current screen
  - [ ] Supabase init failure → error screen with retry (not silent mock fallback)

  **QA Scenarios**:

  ```
  Scenario: Offline play with cached session
    Tool: Playwright (web)
    Preconditions: User authenticated with cached session
    Steps:
      1. Disconnect network (browser DevTools → Offline)
      2. Refresh page
      3. Assert: Map loads from cached data (not login screen)
      4. Assert: Can browse collection, view sanctuary
    Expected Result: App works offline with cached session
    Evidence: .sisyphus/evidence/task-15-offline-cached.png

  Scenario: Expired session with no network
    Tool: Playwright (web)
    Preconditions: Cached session that is expired, network offline
    Steps:
      1. Navigate to app
      2. Assert: Login screen shown (not map)
      3. Assert: "No internet" or "Session expired" message visible
      4. Assert: Retry button present
    Expected Result: Clear error message, not a blank screen
    Evidence: .sisyphus/evidence/task-15-expired-offline.png
  ```

  **Commit**: YES (grouped with Task 16)
  - Message: `🐛 fix(auth): offline session handling + map loading gate`

- [ ] 16. Fix Map Loading (Gate on Auth+Hydration, Remove Fog Race)

  **What to do**:
  - **The core fix**: Map screen should NEVER render before auth + hydration are complete
  - In the new architecture (from Task 7), the map only appears after:
    1. Auth is resolved (user ID known)
    2. Hydration is complete (data loaded from Supabase/SQLite)
    3. Game loop is started
  - This means the `opacity: 0` hack + 10s timeout in `map_screen.dart` should be unnecessary
  - **Changes to map_screen.dart**:
    - Remove the `MapVisibility()..hideMapContainer()` pattern (line 144)
    - Remove the 10s safety timeout for fog init (line 545)
    - Fog should initialize normally because game loop is already running and data is loaded
    - Keep fog initialization logic but remove the race-condition workarounds
  - **Verify**: Map renders immediately when shown (no blank/dark screen) because all data is ready
  - If fog init is still slow, add a lightweight loading indicator WITHIN the map screen (not hiding the entire map)

  **Must NOT do**:
  - Do NOT rewrite fog computation logic — just remove the workarounds for the race condition
  - Do NOT change map rendering, tile loading, or camera logic

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Requires understanding fog initialization and race condition removal, but changes are targeted
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Task 15)
  - **Parallel Group**: Wave 4
  - **Blocks**: Task 17
  - **Blocked By**: Tasks 7 (sequential boot), 14 (map only shown after hydration)

  **References**:

  **Pattern References**:
  - `lib/features/map/map_screen.dart:141-159` — initState with MapVisibility hack
  - `lib/features/map/map_screen.dart:540-608` — _initFogAndReveal with 10s timeout
  - `lib/features/map/utils/map_visibility.dart` — MapVisibility CSS opacity hack

  **WHY Each Reference Matters**:
  - `map_screen.dart:144` — The `MapVisibility()..hideMapContainer()` is the root cause of "map doesn't show". It was a workaround for the race condition; with sequential boot, it should be removable.
  - `map_screen.dart:545` — The 10s timeout is a safety net for fog init stalling. With data pre-loaded, fog should compute quickly.

  **Acceptance Criteria**:
  - [ ] No `MapVisibility..hideMapContainer()` workaround needed
  - [ ] No 10s fog init timeout needed
  - [ ] Map renders visually within 2s of being shown (after hydration)
  - [ ] Fog overlay appears correctly
  - [ ] `flutter analyze lib/features/map/` passes

  **QA Scenarios**:

  ```
  Scenario: Map loads without blank/dark screen
    Tool: Playwright (web)
    Preconditions: User authenticated, hydration complete
    Steps:
      1. Navigate to map tab
      2. Start timer
      3. Assert: Map tiles visible within 2s
      4. Assert: Fog overlay visible within 3s
      5. Assert: No blank/dark screen at any point
    Expected Result: Map renders immediately, fog appears shortly after
    Failure Indicators: Dark screen, 10s delay, fog not rendering
    Evidence: .sisyphus/evidence/task-16-map-loads.png

  Scenario: Map loads after page refresh
    Tool: Playwright (web)
    Preconditions: User authenticated, on map tab
    Steps:
      1. Press F5 (refresh)
      2. Wait for app to reload
      3. Assert: After loading screen → map visible within 3s
      4. Assert: No dark/blank screen
    Expected Result: Map renders on refresh without the "first visit" bug
    Evidence: .sisyphus/evidence/task-16-map-refresh.png
  ```

  **Commit**: YES (grouped with Task 15)
  - Message: `🐛 fix(auth): offline session handling + map loading gate`
  - Files: `lib/features/map/map_screen.dart`, possibly `lib/features/map/utils/map_visibility.dart`

- [ ] 17. Update/Fix Tests

  **What to do**:
  - Run `LD_LIBRARY_PATH=. flutter test` and catalog ALL failures
  - Fix each failure by category:
    - **Import errors**: Files importing deleted/renamed auth types → update imports
    - **MockAuthService references**: Replace with `FakeAuthService` from Task 5
    - **AuthState model changes**: Tests using old states (`initial`, anonymous) → update to new states
    - **gameCoordinatorProvider changes**: Tests expecting fire-and-forget async → update to new sequential flow
    - **New feature tests**: Add tests for:
      - Phone validation (if not already in Task 2)
      - AuthNotifier sendOtp/verifyOtp flow
      - Boot sequence routing (unauthenticated → login, authenticated → map)
      - Onboarding flag check
  - Target: ALL tests pass (`LD_LIBRARY_PATH=. flutter test`)

  **Must NOT do**:
  - Do NOT add Supabase integration tests (that's E2E, not unit tests)
  - Do NOT skip or delete tests that are failing — fix them
  - Do NOT add mockito/mocktail — maintain hand-written mock pattern

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Many test files to audit and fix, requires understanding of both old and new auth
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 18, 19)
  - **Parallel Group**: Wave 5
  - **Blocks**: F1-F4 (final verification needs passing tests)
  - **Blocked By**: Tasks 5, 14, 15, 16 (all code changes must be done before fixing tests)

  **References**:

  **Pattern References**:
  - `test/fixtures/auth_test_doubles.dart` — New test doubles (from Task 5)
  - `test/AGENTS.md` — Test conventions and patterns

  **Test References**:
  - `test/core/state/game_coordinator_provider_test.dart` — Most likely to need heavy changes
  - `test/features/auth/` — Auth-specific tests to rewrite
  - `test/integration/` — Integration suites that may use MockAuthService

  **Acceptance Criteria**:
  - [ ] `LD_LIBRARY_PATH=. flutter test` passes with zero failures
  - [ ] No test imports `mock_auth_service.dart`
  - [ ] New auth flow has test coverage (send OTP, verify OTP, routing)

  **QA Scenarios**:

  ```
  Scenario: All tests pass
    Tool: Bash
    Preconditions: All code changes from Tasks 1-16 complete
    Steps:
      1. Run: LD_LIBRARY_PATH=. flutter test
      2. Assert: Exit code 0
      3. Assert: All tests pass (capture count)
    Expected Result: 0 failures, test count close to 1373 (may differ due to removed/added tests)
    Evidence: .sisyphus/evidence/task-17-all-tests-pass.txt

  Scenario: No MockAuthService references in tests
    Tool: Bash (grep)
    Preconditions: Task completed
    Steps:
      1. Search test/ for "MockAuthService" (not FakeAuthService)
      2. Assert: Zero matches
    Expected Result: All test references migrated
    Evidence: .sisyphus/evidence/task-17-no-mock-refs.txt
  ```

  **Commit**: YES (grouped with Task 18)
  - Message: `♻️ refactor(auth): update tests + remove dead code`
  - Pre-commit: `LD_LIBRARY_PATH=. flutter test`

- [ ] 18. Remove All Dead Code

  **What to do**:
  - Delete `lib/features/auth/services/mock_auth_service.dart`
  - Delete old `lib/features/auth/screens/login_screen.dart` (replaced by new phone_login_screen.dart)
  - Remove any unused onboarding provider (`onboardingProvider` in main.dart if it exists)
  - Run `flutter analyze` — fix any "unused import" or "unused variable" warnings introduced by the rewrite
  - Search for any remaining references to deleted files — fix or remove
  - Clean up any TODO/FIXME comments that were resolved by this rewrite (especially the OTP TODOs at auth_service.dart:51, supabase_auth_service.dart:119)

  **Must NOT do**:
  - Do NOT remove code that's still in use
  - Do NOT remove test files (only production code cleanup)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 17, 19)
  - **Parallel Group**: Wave 5
  - **Blocks**: F1-F4
  - **Blocked By**: Task 9 (references already removed)

  **References**:

  **Files to delete**:
  - `lib/features/auth/services/mock_auth_service.dart`
  - `lib/features/auth/screens/login_screen.dart` (old, replaced)

  **Acceptance Criteria**:
  - [ ] `mock_auth_service.dart` deleted
  - [ ] Old `login_screen.dart` deleted
  - [ ] `flutter analyze` shows zero "unused" warnings from auth rewrite
  - [ ] No file in `lib/` references deleted files

  **QA Scenarios**:

  ```
  Scenario: Dead files removed
    Tool: Bash
    Preconditions: Task completed
    Steps:
      1. Assert: lib/features/auth/services/mock_auth_service.dart does NOT exist
      2. Run: flutter analyze lib/
      3. Assert: No unused import warnings related to auth
    Expected Result: Clean codebase with no dead auth code
    Evidence: .sisyphus/evidence/task-18-dead-code-removed.txt
  ```

  **Commit**: YES (grouped with Task 17)
  - Message: `♻️ refactor(auth): update tests + remove dead code`

- [ ] 19. Update Documentation

  **What to do**:
  - **Root AGENTS.md**:
    - Update "Quick Reference" table: remove MockAuthService mention
    - Update "Core Design Decisions": add decision 11 "Login required before gameplay" and decision 12 "Phone+OTP is sole auth method"
    - Update "Feature Template" auth section
    - Update "Conditional Supabase" section → "Required Supabase"
    - Remove "MockAuthService fallback" references
  - **`lib/features/auth/AGENTS.md`** (create if doesn't exist):
    - Document new auth architecture: phone+OTP only, no anonymous
    - Document boot sequence: check session → login → hydrate → map
    - Document auth state machine: unauthenticated → otpSent → authenticated
    - Document offline behavior: cached session, expired session handling
  - **`docs/architecture.md`** (if exists):
    - Update auth layer description
  - **`docs/state.md`** (if exists):
    - Update authProvider description (new states, new methods)
    - Remove references to MockAuthService
  - **`lib/core/AGENTS.md`**:
    - Update gameCoordinatorProvider description (no more fire-and-forget async)

  **Must NOT do**:
  - Do NOT create new docs files beyond what's needed
  - Do NOT add narrative fluff — telegraphic style per project conventions

  **Recommended Agent Profile**:
  - **Category**: `writing`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 17, 18)
  - **Parallel Group**: Wave 5
  - **Blocks**: F1-F4
  - **Blocked By**: Task 14 (need complete flow to document)

  **References**:

  **Files to update**:
  - `AGENTS.md` (root) — sections: Quick Reference, Core Design Decisions, Feature Template, Conditional Supabase
  - `lib/core/AGENTS.md` — gameCoordinatorProvider section
  - `docs/architecture.md`, `docs/state.md` — auth sections

  **Acceptance Criteria**:
  - [ ] Root AGENTS.md has no "MockAuthService" or "signInAnonymously" references
  - [ ] Root AGENTS.md has new design decisions about login-required and phone+OTP
  - [ ] Auth-specific AGENTS.md exists with current architecture
  - [ ] docs/ files updated to reflect new auth

  **QA Scenarios**:

  ```
  Scenario: No stale auth references in docs
    Tool: Bash (grep)
    Preconditions: Task completed
    Steps:
      1. Search AGENTS.md and docs/ for "MockAuthService", "signInAnonymously", "anonymous sign-in"
      2. Assert: Zero matches
    Expected Result: All documentation reflects new auth architecture
    Evidence: .sisyphus/evidence/task-19-docs-updated.txt
  ```

  **Commit**: YES
  - Message: `📝 docs: update auth architecture documentation`
  - Files: `AGENTS.md`, `lib/core/AGENTS.md`, `lib/features/auth/AGENTS.md`, `docs/architecture.md`, `docs/state.md`

---

## Final Verification Wave (MANDATORY — after ALL implementation tasks)

> 4 review agents run in PARALLEL. ALL must APPROVE. Rejection → fix → re-run.

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists (read file, curl endpoint, run command). For each "Must NOT Have": search codebase for forbidden patterns — reject with file:line if found. Check evidence files exist in .sisyphus/evidence/. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run `flutter analyze` + `LD_LIBRARY_PATH=. flutter test`. Review all changed files for: `as dynamic`, unchecked casts, empty catches, `debugPrint` in prod, commented-out code, unused imports. Check for AI slop: excessive comments, over-abstraction, generic variable names. Verify Riverpod v3 Notifier pattern used correctly (no StateNotifier).
  Output: `Analyze [PASS/FAIL] | Tests [N pass/N fail] | Files [N clean/N issues] | VERDICT`

- [ ] F3. **Real Manual QA** — `unspecified-high` (+ `playwright` skill for web)
  Start from clean state (clear browser storage). Execute EVERY QA scenario from EVERY task. Test full flow: app open → login screen → phone input → OTP → onboarding → map renders → play → close → reopen → cached session → map. Test offline: disable network → verify cached session → play → reconnect → verify sync. Test edge cases: wrong OTP, expired OTP, network drop during OTP. Save all evidence to `.sisyphus/evidence/final-qa/`.
  Output: `Scenarios [N/N pass] | Integration [N/N] | Edge Cases [N tested] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", read actual diff. Verify 1:1 — everything in spec was built, nothing beyond spec was built. Check "Must NOT do" compliance — search for `signInAnonymously`, `MockAuthService`, `AuthState.loading()` state resets. Detect cross-task contamination. Flag unaccounted changes.
  Output: `Tasks [N/N compliant] | Contamination [CLEAN/N issues] | Unaccounted [CLEAN/N files] | VERDICT`

---

## Commit Strategy

| Task(s) | Commit Message | Pre-commit |
|---------|---------------|------------|
| 1 | `🔧 chore(auth): configure Supabase phone auth + test phone numbers` | — |
| 2 | `✨ feat(auth): add E.164 phone number validation utility` | `LD_LIBRARY_PATH=. flutter test test/features/auth/` |
| 3 | `♻️ refactor(auth): rewrite AuthState model for phone-only login` | `flutter analyze` |
| 4 | `🗃️ feat(db): add hasCompletedOnboarding to player profile` | `LD_LIBRARY_PATH=. flutter test test/core/` |
| 5 | `✅ test(auth): create test auth doubles replacing MockAuthService` | `LD_LIBRARY_PATH=. flutter test` |
| 6 | `✨ feat(auth): implement phone OTP flow in SupabaseAuthService` | `LD_LIBRARY_PATH=. flutter test test/features/auth/` |
| 7 | `♻️ refactor(core): sequential boot sequence — no fire-and-forget async` | `flutter analyze` |
| 8-9 | `♻️ refactor(auth): phone-only AuthNotifier + remove anonymous paths` | `flutter analyze` |
| 10-11 | `🎨 feat(ui): phone login + OTP verification screens` | `LD_LIBRARY_PATH=. flutter test` |
| 12-13 | `🎨 feat(ui): hydration loading + onboarding screens` | `LD_LIBRARY_PATH=. flutter test` |
| 14 | `✨ feat(auth): wire full login → OTP → onboarding → map flow` | `LD_LIBRARY_PATH=. flutter test` |
| 15-16 | `🐛 fix(auth): offline session handling + map loading gate` | `LD_LIBRARY_PATH=. flutter test` |
| 17-18 | `♻️ refactor(auth): update tests + remove dead code` | `LD_LIBRARY_PATH=. flutter test` |
| 19 | `📝 docs: update auth architecture documentation` | — |

---

## Success Criteria

### Verification Commands
```bash
flutter analyze                    # Expected: zero new warnings
LD_LIBRARY_PATH=. flutter test     # Expected: all tests pass (count may differ from 1373)
```

### Final Checklist
- [ ] App opens → login screen (no anonymous play)
- [ ] Phone + OTP login works on web AND mobile
- [ ] Returning user with cached session → map (no login flash)
- [ ] First-time user sees onboarding once
- [ ] Offline play works with cached session
- [ ] No progress reset on any auth transition
- [ ] No `signInAnonymously` in codebase
- [ ] No `MockAuthService` in `lib/`
- [ ] No fire-and-forget `initializeAuth()` in gameCoordinatorProvider
- [ ] All tests pass
- [ ] Docs updated (root AGENTS.md, core AGENTS.md, auth AGENTS.md, docs/)
