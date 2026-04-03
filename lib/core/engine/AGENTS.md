# core/engine

`GameCoordinator` — central game logic. Pure Dart, no Flutter, no Riverpod. (Formerly `core/game/`.)

**Key rules:**
- ALL game logic uses `playerPosition` (rubber-band, 60fps), NOT `rawGpsPosition` (1Hz GPS).
- Game tick throttled to ~10Hz (every 6th frame). First call always executes immediately.
- Outputs via callbacks only — no direct Riverpod writes. Wired by `gameCoordinatorProvider`.
- `onRawGpsUpdate` stream uses `sync: true` broadcast controller.
- Discovery: rolls intrinsic affix via `StatsService`, creates `ItemInstance` with UUID. Rolls `weightGrams` when `AnimalSize` enrichment is available.

See /lib/core/AGENTS.md for full engine API and dual-position model details.
