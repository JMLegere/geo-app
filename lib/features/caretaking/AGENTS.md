# Caretaking Feature

Daily visit streaks and sanctuary feeding loop. Tracks player engagement over consecutive days.

---

## Architecture

- `CaretakingService` — Pure Dart. Computes streak updates from last-visit timestamps.
- `CaretakingNotifier` / `caretakingProvider`: `NotifierProvider<CaretakingNotifier, CaretakingState>` — manages daily streak state. Reads `playerProvider` for current streak; writes back via `ref.read(playerProvider.notifier)` (bidirectional sync pattern).
- `CaretakingState`: Immutable. Fields: `currentStreak`, `longestStreak`, `lastVisitDate`, `visitedToday`.

---

## Daily Streak Logic

- Streak increments when player opens the app on a new calendar day (UTC).
- Streak breaks if player misses a day.
- `CaretakingService.evaluate(lastVisit, now)` → `StreakResult` (continued, broken, started, unchanged).
- **Bidirectional sync**: `caretakingProvider` reads `playerProvider` for initial streak, then writes streak updates back to `playerProvider` (which persists to SQLite).

---

## File Map

```
caretaking/
├── models/
│   └── caretaking_state.dart
├── providers/
│   └── caretaking_provider.dart
└── services/
    └── caretaking_service.dart
```

---

## Gotchas

- Streak is stored in `LocalPlayerProfileTable` — `caretakingProvider` and `playerProvider` both touch this field. Use `ref.read(playerProvider.notifier).updateStreak()` from `CaretakingNotifier` (never directly).
- Sanctuary feeding (orb production) is a future feature — `caretakingProvider` today only tracks visit streaks.
- All streak timestamps are UTC — never use local time.

See /AGENTS.md for project-wide rules.
