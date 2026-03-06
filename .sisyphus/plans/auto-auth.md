# Auto-Auth: Seamless Anonymous-First Authentication

## TL;DR

> **Quick Summary**: Wire up Supabase anonymous-to-email account upgrade with a progress-gated prompt (5 species), persistent save-progress banner, OAuth scaffolding (Google + Apple), and a basic Settings screen — all without disrupting the current zero-friction anonymous flow.
> 
> **Deliverables**:
> - `isAnonymous` field on `UserProfile` + `AuthState` computed property
> - `upgradeWithEmail()` and `linkOAuthIdentity()` on `AuthService` interface + both implementations
> - `AuthNotifier.upgradeWithEmail()` and `linkOAuth()` public methods
> - `UpgradePromptNotifier` — triggers one-time bottom sheet at 5 species
> - `SaveProgressBanner` widget — persistent on Home/Pack tabs until upgraded
> - `UpgradeBottomSheet` — email + OAuth sign-in options
> - `SettingsScreen` — profile display + sign-out (gear icon in TabShell)
> - New constant `kUpgradePromptThreshold = 5` in `constants.dart`
> - Supabase dashboard prerequisites documented
> - Updated tests for all new logic
> 
> **Estimated Effort**: Medium
> **Parallel Execution**: YES — 3 waves
> **Critical Path**: Task 1 (model) → Task 2 (service) → Task 3 (notifier) → Task 5 (prompt) → Task 6 (banner) → Task 7 (bottom sheet) → Task 10 (integration test)

---

## Context

### Original Request
"I want to auto-create accounts for users and remember who they are. I'd like for the account creation to save their progress to be a natural step in the app once they get some progress."

### Interview Summary
**Key Discussions**:
- **Trigger**: After 5 species collected → show "save your progress" prompt (one-time bottom sheet)
- **Dismissal**: Persistent banner on Home/Pack tabs — always visible until user upgrades (no "don't show again")
- **Sign-in methods**: Email + Google + Apple (full suite, but OAuth providers need external console setup)
- **Settings screen**: Gear icon → basic profile display + sign-out
- **OAuth prereqs**: Neither Apple Developer nor Google Cloud Console configured yet — code wired, setup documented

**Research Findings**:
- Anonymous sign-in already works (`AuthNotifier._initializeAuth()` → `signInAnonymously()`)
- Supabase JWT persists in local storage — users already survive page reloads
- `SupabasePersistence` already syncs to Supabase keyed by `userId` — UUID preservation is critical
- `supabase_flutter: ^2.12.0` supports `updateUser()` and `linkIdentity()` for anonymous-to-email upgrade
- `collectionProvider` starts empty in `build()` — **needs hydration check** for 5-species trigger on cold start
- Anonymous users have `email: ''` — no `isAnonymous` flag exists yet

### Metis Review
**Identified Gaps** (addressed):
- **UUID preservation**: Must use `updateUser()` / `linkIdentity()`, NOT `signUp()` (which creates a new UUID and orphans data)
- **`isAnonymous` field missing**: Added to `UserProfile` model — anon users currently indistinguishable from email users except `email: ''`
- **Cold start hydration**: `collectionProvider.build()` returns empty state — if collection isn't hydrated from SQLite before the prompt trigger evaluates, it will never fire. Plan includes hydration verification.
- **Sign-out danger for anonymous users**: Sign-out destroys the anonymous UUID permanently. Must warn or block for anon users.
- **Supabase gate**: All upgrade UI must be gated behind `supabaseBootstrapProvider.initialized` — no upgrade prompts when running `MockAuthService`
- **`supabase_flutter` API verification**: `^2.12.0` confirms `updateUser()` and `linkIdentity()` are available

---

## Work Objectives

### Core Objective
Add seamless anonymous-to-email account upgrade with zero disruption to the current frictionless anonymous flow, triggered naturally after the player has progress worth saving.

### Concrete Deliverables
- Modified: `user_profile.dart`, `auth_service.dart`, `supabase_auth_service.dart`, `mock_auth_service.dart`, `auth_provider.dart`, `auth_state.dart`, `tab_shell.dart`, `sanctuary_screen.dart`, `pack_screen.dart`, `constants.dart`
- New: `upgrade_prompt_provider.dart`, `save_progress_banner.dart`, `upgrade_bottom_sheet.dart`, `settings_screen.dart`
- New: prerequisite documentation for Supabase dashboard + OAuth console setup
- New/modified tests for all changed and new files

### Definition of Done
- [ ] Anonymous users see NO upgrade UI until 5 species collected
- [ ] At 5 species, a bottom sheet appears once offering email/Google/Apple sign-in
- [ ] After dismissal, persistent banner visible on Home and Pack tabs
- [ ] Email upgrade preserves UUID (same user ID before and after)
- [ ] Google/Apple OAuth buttons present but non-functional without external setup (documented)
- [ ] Settings screen accessible via gear icon, shows profile + sign-out
- [ ] Sign-out for anonymous users shows destructive-action warning
- [ ] All existing tests pass (`flutter test`)
- [ ] `flutter analyze` reports 0 issues

### Must Have
- UUID preserved across upgrade (`updateUser()` / `linkIdentity()`, NOT `signUp()`)
- `isAnonymous` field on `UserProfile` for all conditional UI
- Upgrade UI gated behind `supabaseBootstrapProvider.initialized`
- One-time bottom sheet at 5 species, then persistent banner
- Settings screen with profile + sign-out
- Destructive sign-out warning for anonymous users

### Must NOT Have (Guardrails)
- MUST NOT use `signUp()` for anonymous-to-email upgrade — this creates a new UUID and orphans all existing data
- MUST NOT allow sign-out without warning for anonymous users — UUID is permanently lost
- MUST NOT build email verification screens — V1 shows "Check your email" message only
- MUST NOT build data merge logic for email-conflict cases
- MUST NOT add profile editing to Settings screen
- MUST NOT modify `SupabasePersistence`, `collectionProvider`, `playerProvider`, fog/map/discovery systems
- MUST NOT show upgrade UI when Supabase is not configured (`MockAuthService` fallback)
- MUST NOT use `StateNotifier` — Riverpod v3 `Notifier` pattern only
- MUST NOT add dependencies — use existing `supabase_flutter` APIs only

---

## Verification Strategy

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: YES (flutter_test, 1004 passing tests)
- **Automated tests**: YES (Tests-after — add tests alongside implementation)
- **Framework**: flutter_test (hand-written mocks, no mockito/mocktail)

### QA Policy
Every task MUST include agent-executed QA scenarios.
Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

- **Frontend/UI**: Use Playwright — Navigate web build, interact with upgrade flow, screenshot
- **Unit tests**: Use Bash — `LD_LIBRARY_PATH=. flutter test {path}`
- **Analysis**: Use Bash — `flutter analyze`

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately — model + interface + constant):
├── Task 1: UserProfile isAnonymous + AuthState computed property [quick]
├── Task 2: AuthService interface upgrade methods + both implementations [deep]
└── Task 3: Add kUpgradePromptThreshold constant [quick]

Wave 2 (After Wave 1 — notifier + UI components, MAX PARALLEL):
├── Task 4: AuthNotifier upgrade methods [unspecified-high]
├── Task 5: UpgradePromptNotifier (5-species trigger) [unspecified-high]
├── Task 6: SaveProgressBanner widget [visual-engineering]
├── Task 7: UpgradeBottomSheet widget [visual-engineering]
├── Task 8: SettingsScreen + gear icon in TabShell [visual-engineering]
└── Task 9: Supabase dashboard prerequisite docs [writing]

Wave 3 (After Wave 2 — integration + wiring):
├── Task 10: Wire upgrade flow end-to-end [deep]
└── Task 11: Update roadmap.md with auth initiative [quick]

Wave FINAL (After ALL tasks — independent review, 4 parallel):
├── Task F1: Plan compliance audit (oracle)
├── Task F2: Code quality review (unspecified-high)
├── Task F3: Real manual QA (unspecified-high)
└── Task F4: Scope fidelity check (deep)
```

### Dependency Matrix

| Task | Depends On | Blocks |
|------|-----------|--------|
| 1 | — | 2, 4, 5, 6, 7, 8 |
| 2 | 1 | 4, 7, 10 |
| 3 | — | 5 |
| 4 | 1, 2 | 7, 10 |
| 5 | 1, 3 | 6, 10 |
| 6 | 1, 5 | 10 |
| 7 | 1, 2, 4 | 10 |
| 8 | 1 | 10 |
| 9 | — | — |
| 10 | 4, 5, 6, 7, 8 | F1-F4 |
| 11 | — | — |
| F1-F4 | 10, 11 | — |

### Agent Dispatch Summary

- **Wave 1**: **3** — T1 → `quick`, T2 → `deep`, T3 → `quick`
- **Wave 2**: **6** — T4 → `unspecified-high`, T5 → `unspecified-high`, T6 → `visual-engineering`, T7 → `visual-engineering`, T8 → `visual-engineering`, T9 → `writing`
- **Wave 3**: **2** — T10 → `deep`, T11 → `quick`
- **FINAL**: **4** — F1 → `oracle`, F2 → `unspecified-high`, F3 → `unspecified-high`, F4 → `deep`

---

## TODOs

### Wave 1 — Model + Interface + Constants (Start Immediately)

- [ ] 1. Add `isAnonymous` to UserProfile + AuthState computed property

  **What to do**:
  - Add `bool isAnonymous` field to `UserProfile` constructor, `copyWith()`, `toJson()`, `fromJson()`, `==`, `hashCode`, `toString()`
  - Default `isAnonymous: false` for backward compatibility
  - Update `AuthState` to add computed getter: `bool get isAnonymous => user?.isAnonymous ?? false`
  - Update `SupabaseAuthService.signInAnonymously()` to set `isAnonymous: true` on the returned `UserProfile`
  - Update `MockAuthService.signInAnonymously()` to set `isAnonymous: true` on the returned `UserProfile`
  - Update `SupabaseAuthService.getCurrentUser()` to derive `isAnonymous` from `_auth.currentUser?.isAnonymous ?? false` (Supabase User has this field)
  - Update `SupabaseAuthService.authStateChanges` stream mapping to include `isAnonymous` from `session.user.isAnonymous`
  - Write tests for: `UserProfile` with `isAnonymous: true/false`, `AuthState.isAnonymous` getter, `copyWith` preserves field, `toJson`/`fromJson` round-trip

  **Must NOT do**:
  - Do not change `AuthState.isLoggedIn` behavior (guest + authenticated = logged in)
  - Do not add any UI code

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Model field addition + test updates — straightforward, well-scoped
  - **Skills**: `[]`
  - **Skills Evaluated but Omitted**:
    - `frontend-ui-ux`: No UI work in this task

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Task 3)
  - **Parallel Group**: Wave 1 (with Tasks 2, 3)
  - **Blocks**: Tasks 2, 4, 5, 6, 7, 8
  - **Blocked By**: None (can start immediately)

  **References**:

  **Pattern References**:
  - `lib/features/auth/models/user_profile.dart` — Full file, add `isAnonymous` field following existing field pattern (id, email, displayName, createdAt)
  - `lib/features/auth/models/auth_state.dart` — Add `isAnonymous` computed getter near existing `isLoggedIn` and `isGuest` getters (lines 62-66)

  **API/Type References**:
  - `lib/features/auth/services/supabase_auth_service.dart:87-105` — `signInAnonymously()` — set `isAnonymous: true` in returned UserProfile
  - `lib/features/auth/services/supabase_auth_service.dart:119-133` — `getCurrentUser()` — derive `isAnonymous` from Supabase `User.isAnonymous`
  - `lib/features/auth/services/supabase_auth_service.dart:145-160` — `authStateChanges` — include `isAnonymous` from `session.user.isAnonymous`
  - `lib/features/auth/services/mock_auth_service.dart:80-91` — `signInAnonymously()` — set `isAnonymous: true`

  **Test References**:
  - `test/features/auth/` — Existing auth test directory (create `user_profile_test.dart` and `auth_state_test.dart` if they don't exist)

  **External References**:
  - Supabase `User` class has `bool? isAnonymous` field — available in `supabase_flutter: ^2.12.0`

  **Acceptance Criteria**:
  - [ ] `UserProfile(id: 'x', email: '', isAnonymous: true, createdAt: now)` compiles and `isAnonymous == true`
  - [ ] `UserProfile(id: 'x', email: 'a@b.com', createdAt: now).isAnonymous == false` (default)
  - [ ] `AuthState.authenticated(anonProfile).isAnonymous == true`
  - [ ] `AuthState.authenticated(emailProfile).isAnonymous == false`
  - [ ] `toJson()` → `fromJson()` round-trip preserves `isAnonymous`
  - [ ] `LD_LIBRARY_PATH=. flutter test test/features/auth/` → all pass
  - [ ] `flutter analyze` → 0 issues

  **QA Scenarios**:

  ```
  Scenario: UserProfile isAnonymous field works correctly
    Tool: Bash
    Preconditions: Flutter environment activated
    Steps:
      1. Run `LD_LIBRARY_PATH=. flutter test test/features/auth/ --reporter expanded`
      2. Verify test output contains "isAnonymous" test cases passing
    Expected Result: All auth model tests pass, including isAnonymous tests
    Failure Indicators: Test failures mentioning isAnonymous, compile errors
    Evidence: .sisyphus/evidence/task-1-user-profile-tests.txt

  Scenario: Existing tests still pass after model change
    Tool: Bash
    Preconditions: Flutter environment activated
    Steps:
      1. Run `LD_LIBRARY_PATH=. flutter test`
      2. Verify exit code 0
      3. Run `flutter analyze`
      4. Verify 0 issues
    Expected Result: All 1004+ existing tests pass, 0 analysis issues
    Failure Indicators: Non-zero exit code, test failures, analysis warnings
    Evidence: .sisyphus/evidence/task-1-full-test-suite.txt
  ```

  **Commit**: YES
  - Message: `♻️ refactor(auth): add isAnonymous field to UserProfile and AuthState`
  - Files: `lib/features/auth/models/user_profile.dart`, `lib/features/auth/models/auth_state.dart`, `lib/features/auth/services/supabase_auth_service.dart`, `lib/features/auth/services/mock_auth_service.dart`, test files
  - Pre-commit: `LD_LIBRARY_PATH=. flutter test && flutter analyze`

- [ ] 2. Add upgrade methods to AuthService interface + both implementations

  **What to do**:
  - Add to `AuthService` abstract class:
    - `Future<UserProfile> upgradeWithEmail({required String email, required String password, String? displayName})` — upgrades anonymous user to email account
    - `Future<UserProfile> linkOAuthIdentity({required String provider})` — links OAuth provider (Google/Apple) to anonymous account
  - Implement in `SupabaseAuthService`:
    - `upgradeWithEmail()`: Call `_auth.updateUser(UserAttributes(email: email, password: password, data: {'display_name': displayName}))`. Return updated `UserProfile` with `isAnonymous: false`.
    - `linkOAuthIdentity()`: Call `_auth.linkIdentity(OAuthProvider.values.firstWhere((p) => p.name == provider))`. Return updated `UserProfile`. Note: this opens an OAuth popup/redirect — the auth state change listener handles the result.
  - Implement in `MockAuthService`:
    - `upgradeWithEmail()`: Validate email format, set `_currentUser` to updated profile with `isAnonymous: false`, emit on stream. Return new profile.
    - `linkOAuthIdentity()`: Set `_currentUser` with `isAnonymous: false`, emit. Return new profile.
  - Write tests for both implementations:
    - Mock: `upgradeWithEmail` changes `isAnonymous` from true to false, preserves `id`
    - Mock: `upgradeWithEmail` throws `AuthException` if email invalid
    - Mock: `upgradeWithEmail` throws `AuthException` if not currently anonymous
    - Mock: `linkOAuthIdentity` changes `isAnonymous` from true to false, preserves `id`

  **Must NOT do**:
  - MUST NOT use `signUp()` for upgrade — this creates a new UUID
  - Do not add email verification screens or flows
  - Do not handle email-conflict merge scenarios

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Touches 3 files with subtle Supabase API contract (updateUser vs signUp is the critical distinction)
  - **Skills**: `[]`
  - **Skills Evaluated but Omitted**:
    - `frontend-ui-ux`: No UI work

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Task 3, after Task 1)
  - **Parallel Group**: Wave 1 (but depends on Task 1)
  - **Blocks**: Tasks 4, 7, 10
  - **Blocked By**: Task 1 (needs `isAnonymous` on UserProfile)

  **References**:

  **Pattern References**:
  - `lib/features/auth/services/auth_service.dart` — Full file, existing interface contract. Add new methods after `signInAnonymously()` (line 44)
  - `lib/features/auth/services/supabase_auth_service.dart:31-56` — `signUp()` method — this is the ANTI-PATTERN. Upgrade MUST NOT follow this pattern. Use `updateUser()` instead.
  - `lib/features/auth/services/supabase_auth_service.dart:87-105` — `signInAnonymously()` — understand the UserProfile construction pattern to reuse in upgrade return
  - `lib/features/auth/services/mock_auth_service.dart:80-91` — `signInAnonymously()` — mock anon profile creation pattern to follow for mock upgrade

  **API/Type References**:
  - Supabase `GoTrueClient.updateUser(UserAttributes)` — updates current user's email/password without creating new UUID
  - Supabase `GoTrueClient.linkIdentity(OAuthProvider)` — links OAuth provider to existing anonymous account
  - `UserAttributes(email:, password:, data:)` — Supabase user attribute update payload

  **External References**:
  - Supabase anonymous auth upgrade docs: https://supabase.com/docs/guides/auth/auth-anonymous#convert-an-anonymous-user-to-a-permanent-user
  - `supabase_flutter: ^2.12.0` — `updateUser()` and `linkIdentity()` available

  **Acceptance Criteria**:
  - [ ] `AuthService` interface compiles with new abstract methods
  - [ ] `SupabaseAuthService` compiles with `upgradeWithEmail()` using `updateUser()` (NOT `signUp()`)
  - [ ] `SupabaseAuthService` compiles with `linkOAuthIdentity()` using `linkIdentity()`
  - [ ] `MockAuthService.upgradeWithEmail()` preserves `id` and sets `isAnonymous: false`
  - [ ] `MockAuthService.upgradeWithEmail()` throws `AuthException` for invalid email
  - [ ] `MockAuthService.linkOAuthIdentity()` preserves `id` and sets `isAnonymous: false`
  - [ ] `grep -r 'signUp' lib/features/auth/services/supabase_auth_service.dart` shows NO `signUp` calls in upgrade methods
  - [ ] `LD_LIBRARY_PATH=. flutter test test/features/auth/` → all pass
  - [ ] `flutter analyze` → 0 issues

  **QA Scenarios**:

  ```
  Scenario: Mock upgrade preserves user ID
    Tool: Bash
    Preconditions: Flutter environment activated
    Steps:
      1. Run `LD_LIBRARY_PATH=. flutter test test/features/auth/ --reporter expanded`
      2. Verify tests for upgradeWithEmail confirm id preservation
      3. Verify tests for linkOAuthIdentity confirm id preservation
    Expected Result: All upgrade tests pass with id unchanged before/after
    Failure Indicators: Test failures showing id mismatch, AuthException in happy path
    Evidence: .sisyphus/evidence/task-2-upgrade-tests.txt

  Scenario: No signUp() used in upgrade path (CRITICAL)
    Tool: Bash
    Preconditions: Task 2 implementation complete
    Steps:
      1. Run `grep -n 'signUp\|sign_up' lib/features/auth/services/supabase_auth_service.dart`
      2. Verify signUp only appears in the original `signUp()` method (lines ~31-56), NOT in upgradeWithEmail or linkOAuthIdentity
      3. Run `grep -n 'updateUser' lib/features/auth/services/supabase_auth_service.dart`
      4. Verify updateUser appears in upgradeWithEmail method
    Expected Result: signUp confined to original method, updateUser used in upgrade
    Failure Indicators: signUp call found inside upgrade methods
    Evidence: .sisyphus/evidence/task-2-no-signup-in-upgrade.txt
  ```

  **Commit**: YES
  - Message: `✨ feat(auth): add upgradeWithEmail and linkOAuthIdentity to AuthService`
  - Files: `lib/features/auth/services/auth_service.dart`, `lib/features/auth/services/supabase_auth_service.dart`, `lib/features/auth/services/mock_auth_service.dart`, test files
  - Pre-commit: `LD_LIBRARY_PATH=. flutter test && flutter analyze`

- [ ] 3. Add `kUpgradePromptThreshold` constant

  **What to do**:
  - Add `const int kUpgradePromptThreshold = 5;` to `lib/shared/constants.dart` in a new "// Auth & Upgrade" section after the "// Logging" section
  - Add doc comment: `/// Number of collected species that triggers the "save your progress" upgrade prompt.`

  **Must NOT do**:
  - Do not add any other constants
  - Do not modify existing constants

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single-line addition to constants file
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 1, 2)
  - **Parallel Group**: Wave 1
  - **Blocks**: Task 5
  - **Blocked By**: None (can start immediately)

  **References**:

  **Pattern References**:
  - `lib/shared/constants.dart:131-143` — Logging section pattern — add new section after this with same doc comment style

  **Acceptance Criteria**:
  - [ ] `kUpgradePromptThreshold == 5` compiles
  - [ ] `flutter analyze` → 0 issues

  **QA Scenarios**:

  ```
  Scenario: Constant exists and compiles
    Tool: Bash
    Preconditions: None
    Steps:
      1. Run `grep -n 'kUpgradePromptThreshold' lib/shared/constants.dart`
      2. Verify output shows `const int kUpgradePromptThreshold = 5;`
      3. Run `flutter analyze`
      4. Verify 0 issues
    Expected Result: Constant found with value 5, no analysis issues
    Failure Indicators: Grep returns nothing, analyze shows errors
    Evidence: .sisyphus/evidence/task-3-constant-check.txt
  ```

  **Commit**: YES
  - Message: `🔧 chore: add kUpgradePromptThreshold constant`
  - Files: `lib/shared/constants.dart`
  - Pre-commit: `flutter analyze`

---

### Wave 2 — Notifier + UI Components (After Wave 1)

- [ ] 4. Add upgrade methods to AuthNotifier

  **What to do**:
  - Add `Future<void> upgradeWithEmail({required String email, required String password, String? displayName})` to `AuthNotifier`:
    - Guard: if `_authService == null` return
    - Guard: if `!state.isAnonymous` return (already upgraded)
    - Set `state = AuthState.loading()`
    - Call `_authService!.upgradeWithEmail(email: email, password: password, displayName: displayName)`
    - On success: set `state = AuthState.authenticated(upgradedUser)` — the returned UserProfile should have `isAnonymous: false`
    - On `AuthException`: set `state = AuthState.error(e.message)`
  - Add `Future<void> linkOAuth({required String provider})` to `AuthNotifier`:
    - Guard: if `_authService == null` return
    - Guard: if `!state.isAnonymous` return
    - Call `_authService!.linkOAuthIdentity(provider: provider)`
    - On `AuthException`: set `state = AuthState.error(e.message)`
    - Note: OAuth flow is async (popup/redirect) — the `_listenToAuthChanges` listener handles the state transition
  - Add `Future<void> signOutWithWarning()` to `AuthNotifier`:
    - If `state.isAnonymous`: throw `AuthException('Cannot sign out anonymous user — data will be lost')` (or set error state)
    - If not anonymous: call existing `signOut()`
  - Write tests with hand-written mock `AuthService`:
    - `upgradeWithEmail` transitions state correctly
    - `upgradeWithEmail` on non-anonymous user is no-op
    - `signOutWithWarning` blocks anonymous sign-out
    - `linkOAuth` calls service correctly

  **Must NOT do**:
  - Do not call `signUp()` anywhere in upgrade flow
  - Do not modify existing `signUp()`, `signIn()`, `signOut()`, `continueAsGuest()` methods
  - Do not add UI

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Riverpod Notifier state transitions with async gaps — needs careful `ref.mounted` guards
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 5, 6, 7, 8, 9 — after Wave 1)
  - **Parallel Group**: Wave 2
  - **Blocks**: Tasks 7, 10
  - **Blocked By**: Tasks 1, 2

  **References**:

  **Pattern References**:
  - `lib/features/auth/providers/auth_provider.dart:132-151` — Existing `signUp()` method — follow same error handling pattern (try/catch AuthException → error state). BUT do not call `service.signUp()` — call `service.upgradeWithEmail()` instead.
  - `lib/features/auth/providers/auth_provider.dart:96-106` — `_signInAnonymouslyWithFallback()` — shows pattern of try/catch with `ref.mounted` guard after async gap
  - `lib/features/auth/providers/auth_provider.dart:78-92` — `_listenToAuthChanges()` — this listener auto-updates state when OAuth redirect completes

  **API/Type References**:
  - `lib/features/auth/services/auth_service.dart` — New methods: `upgradeWithEmail()`, `linkOAuthIdentity()` (from Task 2)
  - `lib/features/auth/models/auth_state.dart` — `AuthState.isAnonymous` getter (from Task 1)

  **Test References**:
  - `test/features/auth/` — Follow existing test patterns. Use `ProviderContainer` with hand-written mock `AuthService`. Use `addTearDown(container.dispose)`.
  - `test/AGENTS.md` — Test conventions: `ProviderContainer`, hand-written mocks, `setUp()`/`tearDown()`

  **Acceptance Criteria**:
  - [ ] `authProvider.notifier.upgradeWithEmail(email: 'a@b.com', password: '123456')` transitions from anonymous → authenticated with `isAnonymous: false`
  - [ ] `authProvider.notifier.upgradeWithEmail(...)` on non-anonymous user is no-op (state unchanged)
  - [ ] `authProvider.notifier.signOutWithWarning()` sets error state for anonymous users
  - [ ] `authProvider.notifier.signOutWithWarning()` calls `signOut()` for non-anonymous users
  - [ ] `LD_LIBRARY_PATH=. flutter test test/features/auth/` → all pass
  - [ ] `flutter analyze` → 0 issues

  **QA Scenarios**:

  ```
  Scenario: Upgrade transitions state correctly
    Tool: Bash
    Preconditions: Flutter environment activated
    Steps:
      1. Run `LD_LIBRARY_PATH=. flutter test test/features/auth/ --reporter expanded`
      2. Check test output for "upgradeWithEmail" and "linkOAuth" test cases
    Expected Result: All notifier upgrade tests pass
    Failure Indicators: Test failures in upgrade state transitions
    Evidence: .sisyphus/evidence/task-4-notifier-tests.txt

  Scenario: No signUp in auth_provider.dart upgrade methods
    Tool: Bash
    Preconditions: Task 4 complete
    Steps:
      1. Run `grep -n 'service.signUp\|_authService.*signUp' lib/features/auth/providers/auth_provider.dart`
      2. Verify signUp only appears in the original `signUp()` method (lines ~132-151)
    Expected Result: signUp not used in any upgrade method
    Failure Indicators: signUp call found in upgradeWithEmail or linkOAuth
    Evidence: .sisyphus/evidence/task-4-no-signup-in-notifier.txt
  ```

  **Commit**: YES
  - Message: `✨ feat(auth): add upgrade methods to AuthNotifier`
  - Files: `lib/features/auth/providers/auth_provider.dart`, test files
  - Pre-commit: `LD_LIBRARY_PATH=. flutter test && flutter analyze`

- [ ] 5. Create UpgradePromptNotifier (5-species trigger)

  **What to do**:
  - Create `lib/features/auth/providers/upgrade_prompt_provider.dart`:
    - `UpgradePromptState`: immutable class with fields:
      - `bool hasBeenShown` — whether bottom sheet was shown this session
      - `bool shouldShow` — computed: `totalCollected >= threshold && isAnonymous && supabaseInitialized && !hasBeenShown`
      - `bool showBanner` — computed: `totalCollected >= threshold && isAnonymous && supabaseInitialized` (always true after threshold, regardless of hasBeenShown)
    - `UpgradePromptNotifier extends Notifier<UpgradePromptState>`:
      - In `build()`: watch `collectionProvider` for `totalCollected`, watch `authProvider` for `isAnonymous`, read `supabaseBootstrapProvider` for `initialized`
      - Compute `shouldShow` and `showBanner` reactively
      - `void markShown()` — sets `hasBeenShown: true` (called after bottom sheet displayed)
    - `upgradePromptProvider = NotifierProvider<UpgradePromptNotifier, UpgradePromptState>(...)`
  - **CRITICAL: Collection hydration check** — `collectionProvider.build()` returns empty `CollectionState()`. If collection isn't hydrated from SQLite before the prompt notifier evaluates, the threshold check will always see 0. The notifier must handle this gracefully — it will fire correctly once `collectionProvider` is populated by the discovery flow. Document this behavior.
  - Write tests:
    - Prompt does NOT fire when collection < 5
    - Prompt fires when collection reaches 5 and user is anonymous and supabase initialized
    - Prompt does NOT fire when user is already upgraded (not anonymous)
    - Prompt does NOT fire when supabase is not initialized (MockAuthService)
    - `markShown()` prevents `shouldShow` but `showBanner` remains true
    - `showBanner` is false when user upgrades (no longer anonymous)

  **Must NOT do**:
  - Do not modify `collectionProvider` — it's read-only from this task's perspective
  - Do not persist `hasBeenShown` to SQLite — session-level state is fine (re-shows after app restart if still anonymous)
  - Do not add UI widgets

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Reactive Riverpod Notifier watching multiple providers with computed state
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 4, 6, 7, 8, 9)
  - **Parallel Group**: Wave 2
  - **Blocks**: Tasks 6, 10
  - **Blocked By**: Tasks 1, 3

  **References**:

  **Pattern References**:
  - `lib/features/discovery/providers/discovery_provider.dart` — Dual notifier pattern (state + notification) — similar reactive watching of collection state
  - `lib/features/achievements/providers/achievement_provider.dart` — Achievement evaluation triggered by state changes — similar threshold-based trigger pattern

  **API/Type References**:
  - `lib/core/state/collection_provider.dart` — `CollectionState.totalCollected` (line 10) — the count to check against threshold
  - `lib/features/auth/providers/auth_provider.dart` — `authProvider` — watch for `isAnonymous`
  - `lib/core/state/supabase_bootstrap_provider.dart` — `supabaseBootstrapProvider` — gate behind `initialized`
  - `lib/shared/constants.dart` — `kUpgradePromptThreshold` (from Task 3)

  **Test References**:
  - `test/features/achievements/` — Achievement provider tests use `ProviderContainer` with overridden providers — follow same pattern
  - Provide mock collection state with controlled `totalCollected` count

  **Acceptance Criteria**:
  - [ ] `upgradePromptProvider.shouldShow == false` when `totalCollected < 5`
  - [ ] `upgradePromptProvider.shouldShow == true` when `totalCollected >= 5 && isAnonymous && supabaseInitialized && !hasBeenShown`
  - [ ] `upgradePromptProvider.shouldShow == false` when `isAnonymous == false`
  - [ ] `upgradePromptProvider.showBanner == true` when `totalCollected >= 5 && isAnonymous && supabaseInitialized`
  - [ ] `upgradePromptProvider.showBanner == false` when user upgrades (not anonymous)
  - [ ] `markShown()` sets `shouldShow = false` but `showBanner = true`
  - [ ] `LD_LIBRARY_PATH=. flutter test test/features/auth/` → all pass
  - [ ] `flutter analyze` → 0 issues

  **QA Scenarios**:

  ```
  Scenario: Prompt triggers at correct threshold
    Tool: Bash
    Preconditions: Flutter environment activated
    Steps:
      1. Run `LD_LIBRARY_PATH=. flutter test test/features/auth/ --reporter expanded`
      2. Verify tests for threshold boundary (4 species = no prompt, 5 species = prompt)
      3. Verify tests for supabase gate (not initialized = no prompt)
      4. Verify tests for anonymous gate (not anonymous = no prompt)
    Expected Result: All threshold and gate tests pass
    Failure Indicators: Prompt fires at wrong threshold, fires without supabase
    Evidence: .sisyphus/evidence/task-5-prompt-trigger-tests.txt

  Scenario: Banner persists after bottom sheet dismissal
    Tool: Bash
    Preconditions: Flutter environment activated
    Steps:
      1. Run `LD_LIBRARY_PATH=. flutter test test/features/auth/ --reporter expanded`
      2. Verify test: after markShown(), shouldShow == false but showBanner == true
    Expected Result: Banner state correctly decoupled from bottom sheet state
    Failure Indicators: showBanner incorrectly false after markShown()
    Evidence: .sisyphus/evidence/task-5-banner-persistence-tests.txt
  ```

  **Commit**: YES (grouped with Task 6)
  - Message: `✨ feat(auth): add upgrade prompt trigger and save-progress banner`
  - Files: `lib/features/auth/providers/upgrade_prompt_provider.dart`, test files
  - Pre-commit: `LD_LIBRARY_PATH=. flutter test && flutter analyze`

- [ ] 6. Create SaveProgressBanner widget

  **What to do**:
  - Create `lib/features/auth/widgets/save_progress_banner.dart`:
    - `SaveProgressBanner extends ConsumerWidget`
    - Watches `upgradePromptProvider.showBanner`
    - If `showBanner == false`: return `SizedBox.shrink()` (renders nothing)
    - If `showBanner == true`: render a horizontal banner widget:
      - Uses `FrostedGlassContainer` with `isNotification: true` for consistent design system usage
      - Icon: shield/cloud/save icon (e.g., `Icons.cloud_upload_outlined`)
      - Text: "Save your progress" (primary) + "Sign in to keep your discoveries" (subtitle)
      - CTA: "Sign In" button (outlined, compact)
      - Tap CTA or banner → opens `UpgradeBottomSheet` (from Task 7)
    - Use design tokens: `Spacing`, `Radii`, `ComponentSizes`
    - Widget test: renders when `showBanner == true`, hidden when false

  **Must NOT do**:
  - Do not persist banner state
  - Do not add dismiss/close button (banner always visible until upgrade)
  - Do not modify `FrostedGlassContainer`

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: UI widget with design system integration
  - **Skills**: `[frontend-ui-ux]`
    - `frontend-ui-ux`: Design-aware widget construction with proper spacing and visual hierarchy

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 4, 7, 8, 9)
  - **Parallel Group**: Wave 2
  - **Blocks**: Task 10
  - **Blocked By**: Tasks 1, 5

  **References**:

  **Pattern References**:
  - `lib/shared/widgets/frosted_glass_container.dart` — FrostedGlassContainer with `isNotification: true` — use for banner styling
  - `lib/features/achievements/widgets/achievement_toast.dart` — If exists, similar notification-style widget pattern
  - `lib/shared/design_tokens.dart` — `Spacing`, `Radii`, `ComponentSizes` — use for all measurements

  **API/Type References**:
  - `lib/features/auth/providers/upgrade_prompt_provider.dart` — `upgradePromptProvider` with `showBanner` field (from Task 5)

  **Test References**:
  - Widget tests: `testWidgets()` with `MaterialApp` wrapper and `ProviderScope` overrides

  **Acceptance Criteria**:
  - [ ] `SaveProgressBanner` renders when `upgradePromptProvider.showBanner == true`
  - [ ] `SaveProgressBanner` renders `SizedBox.shrink()` when `showBanner == false`
  - [ ] Uses `FrostedGlassContainer` (grep verification)
  - [ ] Uses design tokens (no magic numbers)
  - [ ] Widget test passes
  - [ ] `flutter analyze` → 0 issues

  **QA Scenarios**:

  ```
  Scenario: Banner renders with correct content
    Tool: Bash
    Preconditions: Flutter environment activated
    Steps:
      1. Run `LD_LIBRARY_PATH=. flutter test test/features/auth/ --reporter expanded`
      2. Verify widget test: banner contains "Save your progress" text
      3. Verify widget test: banner contains "Sign In" button
    Expected Result: Widget tests pass with correct content
    Failure Indicators: Widget not found, wrong text content
    Evidence: .sisyphus/evidence/task-6-banner-widget-tests.txt

  Scenario: Banner hidden when showBanner is false
    Tool: Bash
    Preconditions: Flutter environment activated
    Steps:
      1. Run `LD_LIBRARY_PATH=. flutter test test/features/auth/ --reporter expanded`
      2. Verify widget test: SizedBox.shrink rendered when showBanner == false
    Expected Result: Banner not visible when user already upgraded
    Failure Indicators: Banner still visible after upgrade
    Evidence: .sisyphus/evidence/task-6-banner-hidden-tests.txt
  ```

  **Commit**: YES (grouped with Task 5)
  - Message: `✨ feat(auth): add upgrade prompt trigger and save-progress banner`
  - Files: `lib/features/auth/widgets/save_progress_banner.dart`, test files

- [ ] 7. Create UpgradeBottomSheet widget

  **What to do**:
  - Create `lib/features/auth/widgets/upgrade_bottom_sheet.dart`:
    - `UpgradeBottomSheet` — a modal bottom sheet widget (shown via `showModalBottomSheet()`)
    - Static helper: `static Future<void> show(BuildContext context)` — wraps `showModalBottomSheet()`
    - Layout (top to bottom):
      - Header: "Save Your Progress" title + "Keep your discoveries safe" subtitle
      - Email upgrade section:
        - Email text field (`TextEditingController`)
        - Password text field (obscured)
        - Optional display name text field
        - "Create Account" primary button → calls `ref.read(authProvider.notifier).upgradeWithEmail(...)`
      - Divider with "or" text
      - OAuth buttons section:
        - Google sign-in button (outlined, full-width) → calls `ref.read(authProvider.notifier).linkOAuth(provider: 'google')`
        - Apple sign-in button (outlined, full-width) → calls `ref.read(authProvider.notifier).linkOAuth(provider: 'apple')`
        - If OAuth not configured (can check via try/catch): show disabled state with "Requires setup" subtitle
      - "Not now" text button at bottom → dismiss sheet
    - Listen to `authProvider` — if state transitions to `authenticated` with `isAnonymous: false`, auto-close the sheet
    - Show error message from `authState.errorMessage` if present
    - Use design tokens throughout
  - Widget tests:
    - Renders email field, password field, "Create Account" button
    - Renders Google and Apple buttons
    - Shows error message when auth state has error
    - Tapping "Not now" dismisses

  **Must NOT do**:
  - Do not add email verification flow (just show "Check your email" snackbar if needed)
  - Do not add form validation beyond basic email format
  - Do not handle email-already-exists conflict (Supabase returns error, display it)
  - Do not add loading spinners beyond auth state loading indicator

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: Form-heavy UI widget with multiple input fields and button states
  - **Skills**: `[frontend-ui-ux]`
    - `frontend-ui-ux`: Form design, bottom sheet UX, button states

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 5, 6, 8, 9)
  - **Parallel Group**: Wave 2
  - **Blocks**: Task 10
  - **Blocked By**: Tasks 1, 2, 4

  **References**:

  **Pattern References**:
  - `lib/features/auth/screens/login_screen.dart` — Existing login form — reference for form field styling, BUT this screen will NOT be modified. New bottom sheet is a separate widget.
  - `lib/features/auth/widgets/auth_button.dart` — Existing auth button widget — reuse if appropriate for Google/Apple buttons
  - `lib/shared/design_tokens.dart` — `Spacing`, `Radii` — all measurements

  **API/Type References**:
  - `lib/features/auth/providers/auth_provider.dart` — `authProvider.notifier.upgradeWithEmail()`, `linkOAuth()` (from Task 4)
  - `lib/features/auth/models/auth_state.dart` — `AuthState.errorMessage`, `AuthState.isAnonymous`

  **External References**:
  - Flutter `showModalBottomSheet()` API

  **Acceptance Criteria**:
  - [ ] `UpgradeBottomSheet.show(context)` opens a modal bottom sheet
  - [ ] Sheet contains email field, password field, display name field
  - [ ] Sheet contains "Create Account" button that calls `upgradeWithEmail()`
  - [ ] Sheet contains Google and Apple OAuth buttons
  - [ ] "Not now" button dismisses the sheet
  - [ ] Error message displayed when `authState.errorMessage` is set
  - [ ] Uses design tokens (no magic numbers)
  - [ ] Widget tests pass
  - [ ] `flutter analyze` → 0 issues

  **QA Scenarios**:

  ```
  Scenario: Bottom sheet renders all sign-in options
    Tool: Bash
    Preconditions: Flutter environment activated
    Steps:
      1. Run `LD_LIBRARY_PATH=. flutter test test/features/auth/ --reporter expanded`
      2. Verify widget test: email field, password field, display name field present
      3. Verify widget test: "Create Account" button present
      4. Verify widget test: Google and Apple buttons present
      5. Verify widget test: "Not now" button present
    Expected Result: All form elements render correctly
    Failure Indicators: Missing form fields, missing buttons
    Evidence: .sisyphus/evidence/task-7-bottom-sheet-tests.txt

  Scenario: Error state displayed in bottom sheet
    Tool: Bash
    Preconditions: Flutter environment activated
    Steps:
      1. Run `LD_LIBRARY_PATH=. flutter test test/features/auth/ --reporter expanded`
      2. Verify widget test: error message visible when authState has error
    Expected Result: Error message renders when auth operation fails
    Failure Indicators: Error message not visible
    Evidence: .sisyphus/evidence/task-7-error-state-tests.txt
  ```

  **Commit**: YES
  - Message: `✨ feat(auth): add upgrade bottom sheet with email and OAuth options`
  - Files: `lib/features/auth/widgets/upgrade_bottom_sheet.dart`, test files
  - Pre-commit: `LD_LIBRARY_PATH=. flutter test && flutter analyze`

- [ ] 8. Create SettingsScreen + gear icon in TabShell

  **What to do**:
  - Create `lib/features/auth/screens/settings_screen.dart`:
    - `SettingsScreen extends ConsumerWidget`
    - AppBar: "Settings" title, back button
    - Profile section (Card or FrostedGlassContainer):
      - Avatar circle with first letter of display name (or `Icons.person` for anonymous)
      - Display name (or "Explorer" for anonymous)
      - Email (or "Anonymous account" for anonymous)
      - If anonymous: "Upgrade your account" button → opens `UpgradeBottomSheet`
    - Sign out section:
      - "Sign Out" button (destructive styling: red text)
      - If anonymous: show warning dialog before sign-out ("You will lose all progress. This cannot be undone. Are you sure?") with "Cancel" and "Sign Out Anyway" buttons
      - If not anonymous: regular sign-out confirmation ("Are you sure you want to sign out?")
      - On confirm: call `authProvider.notifier.signOut()` (for non-anonymous) or show the warning (for anonymous)
    - App info section:
      - Version number (can be placeholder "v0.1.0")
    - Use design tokens throughout
  - Modify `lib/features/navigation/screens/tab_shell.dart`:
    - Add gear icon to the AppBar or as a floating action on the current tab (simplest: add an `actions: [IconButton(icon: Icon(Icons.settings), onPressed: ...)]` to the Scaffold appBar)
    - BUT TabShell currently has no AppBar — the child screens have their own AppBars
    - **Simplest approach**: Add a settings gear icon to the `SanctuaryScreen` AppBar (Home tab) since it already has an AppBar with the trophy icon for achievements. Add similarly to `PackScreen` if it has an AppBar.
    - Navigate to SettingsScreen via `Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))`
  - Widget tests:
    - SettingsScreen renders profile info for anonymous user
    - SettingsScreen renders profile info for email user
    - Sign-out button shows warning for anonymous user
    - Sign-out button shows simple confirm for email user
    - Gear icon visible in SanctuaryScreen AppBar

  **Must NOT do**:
  - Do not add profile editing (name, email changes)
  - Do not add account deletion
  - Do not add theme toggle or other settings
  - Do not modify SanctuaryScreen layout beyond adding gear icon to AppBar

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: Full screen UI with conditional rendering, dialogs, and navigation
  - **Skills**: `[frontend-ui-ux]`
    - `frontend-ui-ux`: Screen layout, profile card design, dialog UX

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 4, 5, 6, 7, 9)
  - **Parallel Group**: Wave 2
  - **Blocks**: Task 10
  - **Blocked By**: Task 1

  **References**:

  **Pattern References**:
  - `lib/features/sanctuary/screens/sanctuary_screen.dart:39-90` — AppBar with actions (trophy icon for achievements) — add gear icon following same pattern
  - `lib/features/achievements/screens/achievement_screen.dart` — Screen navigation pattern (pushed via `Navigator.push`)
  - `lib/features/pack/screens/pack_screen.dart` — Check if PackScreen has an AppBar to add gear icon to

  **API/Type References**:
  - `lib/features/auth/providers/auth_provider.dart` — `authProvider` for user profile and sign-out
  - `lib/features/auth/models/auth_state.dart` — `AuthState.isAnonymous`, `AuthState.user`
  - `lib/features/auth/models/user_profile.dart` — `UserProfile.displayName`, `UserProfile.email`, `UserProfile.isAnonymous`
  - `lib/features/auth/widgets/upgrade_bottom_sheet.dart` — `UpgradeBottomSheet.show(context)` (from Task 7)

  **Test References**:
  - Widget test with `ProviderScope` overrides for `authProvider` state

  **Acceptance Criteria**:
  - [ ] SettingsScreen renders "Explorer" and "Anonymous account" for anonymous users
  - [ ] SettingsScreen renders display name and email for upgraded users
  - [ ] "Upgrade your account" button visible only for anonymous users
  - [ ] Sign-out shows destructive warning dialog for anonymous users
  - [ ] Sign-out shows simple confirmation for non-anonymous users
  - [ ] Gear icon visible in SanctuaryScreen AppBar → navigates to SettingsScreen
  - [ ] Widget tests pass
  - [ ] `flutter analyze` → 0 issues

  **QA Scenarios**:

  ```
  Scenario: Settings screen shows correct profile for anonymous user
    Tool: Bash
    Preconditions: Flutter environment activated
    Steps:
      1. Run `LD_LIBRARY_PATH=. flutter test test/features/auth/ --reporter expanded`
      2. Verify widget test: "Explorer" text visible for anonymous user
      3. Verify widget test: "Anonymous account" text visible
      4. Verify widget test: "Upgrade your account" button visible
    Expected Result: Anonymous profile renders correctly
    Failure Indicators: Missing profile info, missing upgrade button
    Evidence: .sisyphus/evidence/task-8-settings-anonymous-tests.txt

  Scenario: Anonymous sign-out warning dialog
    Tool: Bash
    Preconditions: Flutter environment activated
    Steps:
      1. Run `LD_LIBRARY_PATH=. flutter test test/features/auth/ --reporter expanded`
      2. Verify widget test: tapping "Sign Out" for anonymous user shows warning dialog
      3. Verify widget test: warning dialog contains "lose all progress" text
      4. Verify widget test: "Cancel" button dismisses dialog without sign-out
    Expected Result: Warning dialog prevents accidental anonymous sign-out
    Failure Indicators: No warning shown, sign-out happens without confirmation
    Evidence: .sisyphus/evidence/task-8-signout-warning-tests.txt
  ```

  **Commit**: YES
  - Message: `✨ feat(auth): add settings screen with profile and sign-out`
  - Files: `lib/features/auth/screens/settings_screen.dart`, `lib/features/sanctuary/screens/sanctuary_screen.dart`, possibly `lib/features/pack/screens/pack_screen.dart`, test files
  - Pre-commit: `LD_LIBRARY_PATH=. flutter test && flutter analyze`

- [ ] 9. Document Supabase dashboard and OAuth prerequisites

  **What to do**:
  - Create `docs/auth-prerequisites.md`:
    - **Supabase Dashboard Setup**:
      - Enable anonymous auth: Authentication → Providers → Anonymous Sign-In → Enable
      - Verify RLS policies: `profiles`, `cell_progress`, `collected_species` tables should allow read/write for `auth.uid()`
      - Verify email auth enabled (should be on by default)
    - **Google OAuth Setup** (for future):
      - Google Cloud Console → Credentials → OAuth 2.0 Client ID
      - Authorized redirect URI: `https://<project-ref>.supabase.co/auth/v1/callback`
      - Add client ID to Supabase Dashboard → Authentication → Providers → Google
      - Note: Google sign-in button will be non-functional until this is configured
    - **Apple OAuth Setup** (for future):
      - Apple Developer Program membership required
      - Create App ID with "Sign in with Apple" capability
      - Create Services ID with web domain + redirect URL
      - Add to Supabase Dashboard → Authentication → Providers → Apple
      - Note: Apple sign-in button will be non-functional until this is configured
    - **Dart define variables**:
      - Document that `SUPABASE_URL` and `SUPABASE_ANON_KEY` must be supplied via `--dart-define` for any auth to work
      - Reference existing `Dockerfile` which has these hardcoded (note: production should use env vars)
  - Update `docs/INDEX.md` to reference new `auth-prerequisites.md`

  **Must NOT do**:
  - Do not configure any external services
  - Do not modify Dockerfile or deployment config
  - Do not add environment variable management

  **Recommended Agent Profile**:
  - **Category**: `writing`
    - Reason: Pure documentation task
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES (with all Wave 2 tasks — no code dependencies)
  - **Parallel Group**: Wave 2
  - **Blocks**: None
  - **Blocked By**: None (can start immediately, but grouped in Wave 2 for organizational clarity)

  **References**:

  **Pattern References**:
  - `docs/tech-stack.md` — Existing doc format and style — follow same structure
  - `docs/INDEX.md` — Reading guide — add entry for new doc

  **API/Type References**:
  - `Dockerfile` — Contains hardcoded `SUPABASE_URL` and `SUPABASE_ANON_KEY` values — reference (don't modify)
  - `lib/core/config/supabase_config.dart` — Shows how dart-define values are consumed

  **External References**:
  - Supabase anonymous auth docs: https://supabase.com/docs/guides/auth/auth-anonymous
  - Supabase Google OAuth: https://supabase.com/docs/guides/auth/social-login/auth-google
  - Supabase Apple OAuth: https://supabase.com/docs/guides/auth/social-login/auth-apple

  **Acceptance Criteria**:
  - [ ] `docs/auth-prerequisites.md` exists and covers Supabase, Google, Apple setup
  - [ ] `docs/INDEX.md` references the new doc
  - [ ] No code files modified
  - [ ] `flutter analyze` → 0 issues (no Dart changes)

  **QA Scenarios**:

  ```
  Scenario: Prerequisites doc exists and is comprehensive
    Tool: Bash
    Preconditions: None
    Steps:
      1. Run `cat docs/auth-prerequisites.md`
      2. Verify it contains sections for: Supabase Dashboard, Google OAuth, Apple OAuth, Dart define variables
      3. Run `grep -c 'auth-prerequisites' docs/INDEX.md`
      4. Verify count >= 1 (referenced in INDEX)
    Expected Result: Doc exists with all 4 sections, INDEX references it
    Failure Indicators: Missing file, missing sections, not referenced in INDEX
    Evidence: .sisyphus/evidence/task-9-prereq-doc-check.txt
  ```

  **Commit**: YES
  - Message: `📝 docs: add Supabase and OAuth setup prerequisites`
  - Files: `docs/auth-prerequisites.md`, `docs/INDEX.md`

---

### Wave 3 — Integration + Wiring (After Wave 2)

- [ ] 10. Wire upgrade flow end-to-end

  **What to do**:
  - **SanctuaryScreen** (`lib/features/sanctuary/screens/sanctuary_screen.dart`):
    - Add `SaveProgressBanner` widget between the summary row and habitat sections
    - Watch `upgradePromptProvider.shouldShow` — when it transitions to `true`, show `UpgradeBottomSheet.show(context)` and then call `ref.read(upgradePromptProvider.notifier).markShown()`
    - Use `ref.listen` for the one-time bottom sheet trigger (not `ref.watch` in build)
  - **PackScreen** (`lib/features/pack/screens/pack_screen.dart`):
    - Add `SaveProgressBanner` widget at top of the screen (above filter bar or progress bar)
    - Same `ref.listen` for one-time bottom sheet trigger
  - **Integration test** — create `test/integration/upgrade_flow_test.dart`:
    - Set up `ProviderContainer` with mock providers
    - Simulate: collection grows from 0 → 5 species
    - Verify: `upgradePromptProvider.shouldShow` transitions to `true`
    - Simulate: `markShown()` called
    - Verify: `shouldShow == false`, `showBanner == true`
    - Simulate: `upgradeWithEmail()` succeeds
    - Verify: `isAnonymous == false`, `showBanner == false`
  - **Ensure TabShell still works** — no modification to TabShell needed beyond what Task 8 does (gear icon in child screens)
  - **Verify Supabase gate** — write test that when `supabaseBootstrapProvider.initialized == false`, NO upgrade UI appears anywhere

  **Must NOT do**:
  - Do not modify `collectionProvider`, `playerProvider`, fog/map/discovery systems
  - Do not change how species are collected
  - Do not modify the discovery flow
  - Do not add new routes to `main.dart` (SettingsScreen is navigated via `Navigator.push` from within screens)

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Wiring across 4+ files, integration tests, cross-provider reactive behavior
  - **Skills**: `[frontend-ui-ux]`
    - `frontend-ui-ux`: Ensuring banner placement looks correct within existing screen layouts

  **Parallelization**:
  - **Can Run In Parallel**: NO (depends on all Wave 2 outputs)
  - **Parallel Group**: Wave 3 (sequential)
  - **Blocks**: F1-F4
  - **Blocked By**: Tasks 4, 5, 6, 7, 8

  **References**:

  **Pattern References**:
  - `lib/features/sanctuary/screens/sanctuary_screen.dart:27-36` — `initState()` with `addPostFrameCallback` + `ref.read` — use `ref.listen` for upgrade prompt trigger in same pattern location
  - `lib/features/pack/screens/pack_screen.dart` — Where to insert banner in the widget tree
  - `lib/features/discovery/providers/discovery_provider.dart` — `ref.listen` pattern for one-time event triggers

  **API/Type References**:
  - `lib/features/auth/providers/upgrade_prompt_provider.dart` — `upgradePromptProvider`, `shouldShow`, `showBanner`, `markShown()` (from Task 5)
  - `lib/features/auth/widgets/save_progress_banner.dart` — `SaveProgressBanner` (from Task 6)
  - `lib/features/auth/widgets/upgrade_bottom_sheet.dart` — `UpgradeBottomSheet.show(context)` (from Task 7)
  - `lib/features/auth/screens/settings_screen.dart` — `SettingsScreen` (from Task 8)

  **Test References**:
  - `test/integration/` — 5 existing integration test suites — follow pattern for offline workflow round-trips

  **Acceptance Criteria**:
  - [ ] `SaveProgressBanner` visible on SanctuaryScreen when conditions met
  - [ ] `SaveProgressBanner` visible on PackScreen when conditions met
  - [ ] Bottom sheet auto-triggers once at 5 species (via `ref.listen`)
  - [ ] After dismissal, banner remains but bottom sheet doesn't re-trigger
  - [ ] After upgrade, banner disappears from both screens
  - [ ] When Supabase not initialized, NO upgrade UI appears on any screen
  - [ ] Integration tests pass
  - [ ] `LD_LIBRARY_PATH=. flutter test` → all pass (1004+ tests)
  - [ ] `flutter analyze` → 0 issues

  **QA Scenarios**:

  ```
  Scenario: Full upgrade flow — anonymous to email
    Tool: Bash
    Preconditions: Flutter environment activated
    Steps:
      1. Run `LD_LIBRARY_PATH=. flutter test test/integration/upgrade_flow_test.dart --reporter expanded`
      2. Verify test: collection grows 0→5, shouldShow becomes true
      3. Verify test: markShown() sets shouldShow false, showBanner true
      4. Verify test: upgradeWithEmail succeeds, isAnonymous becomes false
      5. Verify test: showBanner becomes false after upgrade
    Expected Result: Complete flow passes in integration test
    Failure Indicators: State transition failures, wrong boolean values
    Evidence: .sisyphus/evidence/task-10-integration-test.txt

  Scenario: Supabase gate — no upgrade UI without Supabase
    Tool: Bash
    Preconditions: Flutter environment activated
    Steps:
      1. Run `LD_LIBRARY_PATH=. flutter test test/integration/upgrade_flow_test.dart --reporter expanded`
      2. Verify test: with supabaseBootstrapProvider.initialized == false, shouldShow and showBanner are always false
    Expected Result: No upgrade UI when Supabase not configured
    Failure Indicators: showBanner true without Supabase
    Evidence: .sisyphus/evidence/task-10-supabase-gate-test.txt

  Scenario: All existing tests still pass
    Tool: Bash
    Preconditions: Flutter environment activated
    Steps:
      1. Run `LD_LIBRARY_PATH=. flutter test`
      2. Verify exit code 0
      3. Run `flutter analyze`
      4. Verify 0 issues
    Expected Result: All 1004+ existing tests pass plus new tests
    Failure Indicators: Non-zero exit code, test count regression
    Evidence: .sisyphus/evidence/task-10-full-suite.txt
  ```

  **Commit**: YES
  - Message: `✨ feat(auth): wire upgrade flow end-to-end`
  - Files: `lib/features/sanctuary/screens/sanctuary_screen.dart`, `lib/features/pack/screens/pack_screen.dart`, `test/integration/upgrade_flow_test.dart`
  - Pre-commit: `LD_LIBRARY_PATH=. flutter test && flutter analyze`

- [ ] 11. Update roadmap.md with auth initiative

  **What to do**:
  - Add new initiative to `docs/roadmap.md` as "Initiative 0.5: Authentication & Account System" (numbered before Initiative 1 since it's foundational infra):
    - OR add as a project under Initiative 13 (Infrastructure) as "Project 13.6: Authentication & Account Upgrade" — **choose this option** since auth is infrastructure
  - Add under Initiative 13:
    ```
    ### Project 13.6: Authentication & Account Upgrade — In Progress
    - [x] Anonymous auto-login on app launch (Supabase anonymous auth)
    - [x] Session persistence across reloads (JWT in local storage)
    - [x] isAnonymous field on UserProfile model
    - [x] upgradeWithEmail() and linkOAuthIdentity() on AuthService
    - [x] 5-species upgrade prompt trigger
    - [x] Save-progress banner on Home/Pack tabs
    - [x] Upgrade bottom sheet (email + Google + Apple options)
    - [x] Settings screen with profile and sign-out
    - [x] Destructive sign-out warning for anonymous users
    - [x] Supabase/OAuth prerequisites documented
    - [ ] Google OAuth external setup (manual, documented)
    - [ ] Apple OAuth external setup (manual, documented)
    - [ ] Email verification flow (v2)
    - [ ] Account deletion (v2)
    ```
  - Update Priority Guidance table to note auth is shipped

  **Must NOT do**:
  - Do not change existing initiative numbering
  - Do not modify status of unrelated items

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Documentation update — append to existing file
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Task 10 — no code dependencies)
  - **Parallel Group**: Wave 3
  - **Blocks**: F1-F4 (part of final verification baseline)
  - **Blocked By**: None (can reference plan tasks as "[x]" since they'll be done by Wave 3)

  **References**:

  **Pattern References**:
  - `docs/roadmap.md:298-329` — Initiative 13: Infrastructure section — add Project 13.6 after 13.5

  **Acceptance Criteria**:
  - [ ] `docs/roadmap.md` contains "Project 13.6: Authentication & Account Upgrade"
  - [ ] Project items accurately reflect what was built
  - [ ] Priority Guidance table updated
  - [ ] No other initiatives modified

  **QA Scenarios**:

  ```
  Scenario: Roadmap updated correctly
    Tool: Bash
    Preconditions: None
    Steps:
      1. Run `grep -c '13.6' docs/roadmap.md`
      2. Verify count >= 1
      3. Run `grep 'Authentication.*Account.*Upgrade' docs/roadmap.md`
      4. Verify match found
    Expected Result: New project section exists in roadmap
    Failure Indicators: Section not found, wrong numbering
    Evidence: .sisyphus/evidence/task-11-roadmap-check.txt
  ```

  **Commit**: YES
  - Message: `📝 docs: add auth initiative to roadmap`
  - Files: `docs/roadmap.md`

---

## Final Verification Wave

> 4 review agents run in PARALLEL. ALL must APPROVE. Rejection → fix → re-run.

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists (read file, curl endpoint, run command). For each "Must NOT Have": search codebase for forbidden patterns — reject with file:line if found. Check evidence files exist in .sisyphus/evidence/. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run `flutter analyze` + `LD_LIBRARY_PATH=. flutter test`. Review all changed files for: `as dynamic`, `@override` without `super`, empty catches, `print()` in prod, commented-out code, unused imports. Check AI slop: excessive comments, over-abstraction, generic names (data/result/item/temp). Verify Riverpod v3 `Notifier` pattern used (not `StateNotifier`).
  Output: `Analyze [PASS/FAIL] | Tests [N pass/N fail] | Files [N clean/N issues] | VERDICT`

- [ ] F3. **Real Manual QA** — `unspecified-high` (+ `playwright` skill)
  Start from clean state. Execute EVERY QA scenario from EVERY task — follow exact steps, capture evidence. Test cross-task integration (upgrade flow end-to-end, settings after upgrade, banner disappearance). Test edge cases: dismiss bottom sheet, re-open app after dismiss, sign-out as anonymous. Save to `.sisyphus/evidence/final-qa/`.
  Output: `Scenarios [N/N pass] | Integration [N/N] | Edge Cases [N tested] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", read actual diff (git log/diff). Verify 1:1 — everything in spec was built (no missing), nothing beyond spec was built (no creep). Check "Must NOT do" compliance. Detect cross-task contamination: Task N touching Task M's files. Flag unaccounted changes.
  Output: `Tasks [N/N compliant] | Contamination [CLEAN/N issues] | Unaccounted [CLEAN/N files] | VERDICT`

---

## Commit Strategy

| After Task(s) | Message | Files |
|---------------|---------|-------|
| 1 | `♻️ refactor(auth): add isAnonymous field to UserProfile and AuthState` | `user_profile.dart`, `auth_state.dart` |
| 2 | `✨ feat(auth): add upgradeWithEmail and linkOAuthIdentity to AuthService` | `auth_service.dart`, `supabase_auth_service.dart`, `mock_auth_service.dart` |
| 3 | `🔧 chore: add kUpgradePromptThreshold constant` | `constants.dart` |
| 4 | `✨ feat(auth): add upgrade methods to AuthNotifier` | `auth_provider.dart` |
| 5, 6 | `✨ feat(auth): add upgrade prompt trigger and save-progress banner` | `upgrade_prompt_provider.dart`, `save_progress_banner.dart` |
| 7 | `✨ feat(auth): add upgrade bottom sheet with email and OAuth options` | `upgrade_bottom_sheet.dart` |
| 8 | `✨ feat(auth): add settings screen with profile and sign-out` | `settings_screen.dart`, `tab_shell.dart` |
| 9 | `📝 docs: add Supabase and OAuth setup prerequisites` | docs file |
| 10 | `✨ feat(auth): wire upgrade flow end-to-end` | modified screens, providers |
| 11 | `📝 docs: add auth initiative to roadmap` | `roadmap.md` |

---

## Success Criteria

### Verification Commands
```bash
eval "$(~/.local/bin/mise activate bash)"
flutter analyze                          # Expected: 0 issues
LD_LIBRARY_PATH=. flutter test           # Expected: all pass (1004+ tests)
```

### Final Checklist
- [ ] Anonymous users auto-sign-in on launch (existing behavior preserved)
- [ ] No upgrade UI visible until 5 species collected
- [ ] Bottom sheet appears once at 5 species with email + Google + Apple options
- [ ] Persistent banner on Home/Pack tabs after dismissal
- [ ] Email upgrade preserves UUID — verified by checking `user.id` before/after
- [ ] Google/Apple buttons present but show "setup required" state
- [ ] Settings screen accessible via gear icon
- [ ] Sign-out for anonymous users shows warning dialog
- [ ] `flutter analyze` → 0 issues
- [ ] `flutter test` → all pass
- [ ] No `signUp()` calls in upgrade flow (grep verification)
- [ ] No `StateNotifier` in new code (grep verification)
