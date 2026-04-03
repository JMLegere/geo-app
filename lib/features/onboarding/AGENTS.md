# Onboarding Feature

First-run welcome flow. Shown once to new users before the main TabShell.

---

## Architecture

- `onboardingProvider`: `NotifierProvider<OnboardingNotifier, OnboardingState>` — tracks whether onboarding is complete. Persists via `SharedPreferences`.
- `OnboardingState`: `isComplete`, `currentPage`.
- `OnboardingScreen` — multi-page swipeable welcome flow.
- `OnboardingPage` — single page widget (emoji, title, body text).

---

## Flow

```
App launch → authProvider settled → LoadingScreen reads onboardingProvider
  → isComplete: false → navigate to OnboardingScreen
  → user swipes through pages → taps "Start Exploring"
  → onboardingProvider.markComplete() → navigate to TabShell
  → isComplete: true on subsequent launches → skip to TabShell
```

---

## Conventions

- Onboarding completion state persists to `SharedPreferences` key `onboarding_complete`.
- Onboarding pages are hardcoded in `OnboardingScreen` (not data-driven).
- Do NOT show onboarding if user returns after app update — check `SharedPreferences`, not version.

---

## File Map

```
onboarding/
├── providers/
│   └── onboarding_provider.dart
├── screens/
│   └── onboarding_screen.dart
└── widgets/
    └── onboarding_page.dart
```

See /AGENTS.md for project-wide rules.
