# Auth Feature

Identity, authentication state, and upgrade prompts. Conditionally backed by Supabase (phone OTP) or `MockAuthService` (no credentials).

---

## Architecture

**Services (2 implementations of `AuthService`):**
- `MockAuthService` — always returns a hardcoded anonymous user. Used when `SUPABASE_URL` is not supplied.
- `SupabaseAuthService` — phone OTP via Supabase. Anonymous sign-in on first launch, upgrades to phone-verified on OTP confirmation.

**Providers:**
- `authProvider`: `NotifierProvider<AuthNotifier, AuthState>` — current auth state (loading, anonymous, authenticated, error).
- `upgradePromptProvider`: `NotifierProvider<UpgradePromptNotifier, UpgradePromptState>` — controls the "Save Progress" upgrade bottom sheet.

**Models:**
- `AuthState`: Immutable. Fields: `status` (AuthStatus enum), `userId`, `isAnonymous`, `displayName`, `error`.
- `UserProfile`: Display name, userId, `isAnonymous`, `phoneNumber` (nullable).

---

## Auth Flow

```
App launch → MockAuthService (no Supabase)  →  authProvider.status = authenticated (anonymous)
App launch → SupabaseAuthService            →  anonymous sign-in → status = authenticated (isAnonymous: true)
User taps "Save Progress"                   →  upgradePromptProvider shows bottom sheet
User enters phone                           →  SupabaseAuthService.sendOtp()
User enters OTP code                        →  SupabaseAuthService.verifyOtp() → status = authenticated (isAnonymous: false)
```

---

## Conditional Supabase

Auth service selection is compile-time: `String.fromEnvironment('SUPABASE_URL')`.
- Empty → `MockAuthService`
- Non-empty → `SupabaseAuthService`

`SupabasePersistence` (in `features/sync/`) is also null when Supabase not configured — sync screen shows "not configured".

---

## Screens

- `LoadingScreen` — shown while auth initializes. Navigates to `OnboardingScreen` (first run) or `TabShell` (returning user).
- `LoginScreen` — phone number entry.
- `OtpVerificationScreen` — OTP code entry with countdown timer.
- `SettingsScreen` — shows user ID, sign-out, debug log card.

---

## Gotchas

- `authProvider` must be `watched` before `gameCoordinatorProvider` — game coordinator reads `authProvider` for userId.
- `upgradePromptProvider` is shown as a modal bottom sheet from `SaveProgressBanner` widget; it does NOT navigate.
- `phone_validation.dart` contains E.164 normalization — always use this before passing phone numbers to Supabase.
- `DebugLogCard` (in `SettingsScreen`) renders `ObservabilityBuffer` log entries — dev/debug only.

See /AGENTS.md for project-wide rules.
