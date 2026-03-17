# Calendar Feature

Time-based game state: seasons, time-of-day (future), and daily schedule (future). Consolidated from `features/seasonal/`.

---

## Current Scope

- **Season** (`Summer` / `Winter`): Drives species availability. 80% year-round, 10% summer-only, 10% winter-only.
- `SeasonNotifier` and `seasonProvider` live in `core/state/` (global infrastructure provider).
- `Season.fromDate(DateTime)` in `core/models/` — month-based: May–Oct = summer, Nov–Apr = winter.

## Providers

- `seasonProvider`: `NotifierProvider<SeasonNotifier, Season>` — current season, initialized from `DateTime.now()` on startup.

## Future Scope (Not Started)

- Time-of-day (day/night) — nocturnal species variants
- Daily schedule — time-gated encounters, NPC availability

---

## Conventions

- No southern hemisphere support — seasons are hardcoded to northern hemisphere month ranges.
- Boundary months (May, November) are inclusive to the new season.
- Season changes don't affect already-discovered items — only affects spawn pool for new cells.

---

## Gotchas

- Formerly `features/seasonal/`. Renamed to `calendar/` to accommodate future time-of-day + schedule features.
- `SeasonNotifier.build()` uses `DateTime.now()` — in tests, override via `ProviderContainer` override or use a fixed date.
