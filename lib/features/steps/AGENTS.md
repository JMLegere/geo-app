# Steps Feature

Pedometer-based exploration. Counts steps and uses step thresholds to unlock exploration bonuses (future).

---

## Architecture

- `StepService` — abstract interface. Conditional import: `step_service_native.dart` (real pedometer via `pedometer_2`) vs `step_service_web.dart` (stub returning zero).
- `stepProvider`: `NotifierProvider<StepNotifier, StepState>` — accumulated step count for current session.
- `StepState`: Immutable. `todaySteps`, `sessionSteps`, `isAvailable`.
- `StepRecap` — widget showing session step count summary.

---

## Platform Handling

| Platform | Implementation | Notes |
|----------|---------------|-------|
| iOS / Android | `step_service_native.dart` | Uses `pedometer_2` package. Requires motion permission. |
| Web | `step_service_web.dart` | Stub — always returns 0. `isAvailable = false`. |

Conditional import via `dart:io` check in `step_service.dart`.

---

## Conventions

- Step counts are session-relative (reset on app restart) — not day-cumulative.
- Steps do NOT directly trigger game events yet — provider exists as input infrastructure for future step-gated encounters.
- `StepNotifier.build()` calls `StepService.start()` and subscribes to the step stream.
- Always check `StepState.isAvailable` before showing step-related UI (hide on web).

---

## Gotchas

- `pedometer_2` requires `NSMotionUsageDescription` in iOS Info.plist.
- On Android, `ACTIVITY_RECOGNITION` permission must be granted at runtime.
- Web stub always emits `isAvailable: false` — do not show step UI on web.

See /AGENTS.md for project-wide rules.
